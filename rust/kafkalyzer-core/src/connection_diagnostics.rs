use std::collections::BTreeSet;
use std::time::{Duration, Instant};

use crate::tls::{classify_tls_failure, TlsFailureClassification};

pub const TOTAL_BUDGET: Duration = Duration::from_secs(25);
pub const DNS_TIMEOUT: Duration = Duration::from_secs(5);
pub const TCP_TIMEOUT: Duration = Duration::from_secs(5);
pub const METADATA_TIMEOUT: Duration = Duration::from_secs(10);
pub const REGISTRY_TIMEOUT: Duration = Duration::from_secs(10);

pub const REDACTED_PLACEHOLDER: &str = "[redacted]";

/// Returns the remaining duration before `deadline` at `now`, or `None` if exhausted.
pub fn remaining(deadline: Instant, now: Instant) -> Option<Duration> {
    if now >= deadline {
        None
    } else {
        Some(deadline.saturating_duration_since(now))
    }
}

/// Replaces every non-empty secret in `text` with `[redacted]`.
pub fn redact(text: &str, secrets: &[&str]) -> String {
    let mut non_empty: Vec<&str> = secrets.iter().copied().filter(|s| !s.is_empty()).collect();
    if non_empty.is_empty() || text.is_empty() {
        return text.to_string();
    }
    // Replace longest secrets first so a shorter secret never splits a longer one.
    non_empty.sort_by_key(|b| std::cmp::Reverse(b.len()));
    non_empty.dedup();

    let mut out = text.to_string();
    for secret in non_empty {
        if out.contains(secret) {
            out = out.replace(secret, REDACTED_PLACEHOLDER);
        }
    }
    out
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DiagnosisOutcome {
    Ok,
    Failed,
    FailedStageUnknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DiagnosisStage {
    Network,
    Tls,
    Authentication,
    Metadata,
    SchemaRegistry,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NotCheckedReason {
    PreviousStageFailed,
    BudgetExhausted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StageState {
    Ok,
    Failed,
    NotChecked(NotCheckedReason),
    NotApplicable,
    Undetermined,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StepState {
    Ok,
    Failed,
    NotChecked,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DiagnosisHint {
    InvalidEntry,
    HostUnknown,
    ConnectionRefused,
    ConnectTimeout,
    CertificateRejected,
    TlsHandshakeFailed,
    ProtocolMismatch,
    AuthenticationFailed,
    MechanismRejected,
    NotAuthorized,
    RequestTimeout,
    RegistryUnreachable,
    RegistryUnauthorized,
    RegistryHttpError(u16),
    Generic,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServerCheck {
    pub entry: String,
    pub dns: StepState,
    pub addresses: Vec<String>,
    pub tcp: StepState,
    pub connected_address: Option<String>,
    pub hint: Option<DiagnosisHint>,
    pub raw: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StageResult {
    pub stage: DiagnosisStage,
    pub state: StageState,
    pub hint: Option<DiagnosisHint>,
    pub raw: Option<String>,
    pub servers: Vec<ServerCheck>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiagnosisReport {
    pub outcome: DiagnosisOutcome,
    pub stages: [StageResult; 5],
    pub unattributed: Vec<String>,
    pub elapsed_ms: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum TlsEvidence {
    CertificateRejected,
    ProtocolMismatch,
    Handshake,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum AuthEvidence {
    Failed,
    Mechanism,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum EvidenceTag {
    Tls(TlsEvidence),
    Auth(AuthEvidence),
    Authorization,
}

/// Captured librdkafka error/log line with optional `RDKafkaErrorCode` integer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CapturedLine {
    pub code: Option<i32>,
    pub text: String,
}

const RDKAFKA_ERR_SSL: i32 = -181;
const RDKAFKA_ERR_AUTHENTICATION: i32 = -169;
const RDKAFKA_ERR_SASL_AUTHENTICATION_FAILED: i32 = 58;
const RDKAFKA_ERR_TOPIC_AUTHORIZATION_FAILED: i32 = 29;
const RDKAFKA_ERR_GROUP_AUTHORIZATION_FAILED: i32 = 30;
const RDKAFKA_ERR_CLUSTER_AUTHORIZATION_FAILED: i32 = 31;
const RDKAFKA_ERR_TRANSACTIONAL_ID_AUTHORIZATION_FAILED: i32 = 53;

/// Classifies captured librdkafka error/log lines and optional metadata error
/// into stage-level evidence tags.
pub fn classify_evidence(
    lines: &[CapturedLine],
    metadata_err: Option<&CapturedLine>,
) -> BTreeSet<EvidenceTag> {
    let mut tags = BTreeSet::new();

    let mut all: Vec<&CapturedLine> = lines.iter().collect();
    if let Some(m) = metadata_err {
        all.push(m);
    }

    for entry in all {
        let lower = entry.text.to_ascii_lowercase();

        // Authorization checks (MetadataFetch or global error)
        if matches!(
            entry.code,
            Some(
                RDKAFKA_ERR_TOPIC_AUTHORIZATION_FAILED
                    | RDKAFKA_ERR_GROUP_AUTHORIZATION_FAILED
                    | RDKAFKA_ERR_CLUSTER_AUTHORIZATION_FAILED
                    | RDKAFKA_ERR_TRANSACTIONAL_ID_AUTHORIZATION_FAILED
            )
        ) || lower.contains("cluster authorization failed")
            || lower.contains("topic authorization failed")
            || lower.contains("not authorized")
        {
            tags.insert(EvidenceTag::Authorization);
            continue;
        }

        // SASL / Authentication checks
        if matches!(
            entry.code,
            Some(RDKAFKA_ERR_AUTHENTICATION | RDKAFKA_ERR_SASL_AUTHENTICATION_FAILED)
        ) || lower.contains("sasl authentication error")
            || lower.contains("mechanism handshake failed")
        {
            if lower.contains("unsupported sasl mechanism")
                || lower.contains("not valid in current sasl state")
                || lower.contains("mechanism handshake failed")
            {
                tags.insert(EvidenceTag::Auth(AuthEvidence::Mechanism));
            } else {
                tags.insert(EvidenceTag::Auth(AuthEvidence::Failed));
            }
            continue;
        }

        // Protocol mismatch (SSL <-> PLAINTEXT)
        if lower.contains("connecting to a plaintext broker listener")
            || lower.contains("connecting to a ssl listener")
            || lower.contains("incorrect security.protocol")
            || lower.contains("wrong version number")
        {
            tags.insert(EvidenceTag::Tls(TlsEvidence::ProtocolMismatch));
            continue;
        }

        // Certificate / hostname verification via shared classifier
        if matches!(
            classify_tls_failure(std::slice::from_ref(&entry.text)),
            TlsFailureClassification::CertificateRejected(_)
        ) {
            tags.insert(EvidenceTag::Tls(TlsEvidence::CertificateRejected));
            continue;
        }

        // Generic TLS handshake / alert failure
        if entry.code == Some(RDKAFKA_ERR_SSL)
            || lower.contains("ssl handshake failed")
            || lower.contains("ssl/tls alert")
            || lower.contains("ssl routines")
            || lower.contains("ssl_error")
        {
            tags.insert(EvidenceTag::Tls(TlsEvidence::Handshake));
        }
    }

    tags
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MetadataProbeOutcome {
    Ok,
    Failed {
        lines: Vec<CapturedLine>,
        metadata_err: Option<CapturedLine>,
    },
    NotRun(NotCheckedReason),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RegistryProbeOutcome {
    NotApplicable,
    Ok,
    Failed { hint: DiagnosisHint, raw: String },
    NotChecked(NotCheckedReason),
}

/// Derives the complete 5-stage `DiagnosisReport` from probe outcomes.
pub fn derive_diagnosis(
    servers: Vec<ServerCheck>,
    network_budget_exhausted: bool,
    metadata_probe: MetadataProbeOutcome,
    registry_probe: RegistryProbeOutcome,
    uses_tls: bool,
    uses_sasl: bool,
    elapsed_ms: u64,
) -> DiagnosisReport {
    let network_stage = derive_network_stage(servers, network_budget_exhausted);

    let (tls_stage, auth_stage, metadata_stage, unattributed, kafka_unknown) =
        derive_kafka_stages(metadata_probe, uses_tls, uses_sasl);

    let registry_stage = match registry_probe {
        RegistryProbeOutcome::NotApplicable => StageResult {
            stage: DiagnosisStage::SchemaRegistry,
            state: StageState::NotApplicable,
            hint: None,
            raw: None,
            servers: Vec::new(),
        },
        RegistryProbeOutcome::Ok => StageResult {
            stage: DiagnosisStage::SchemaRegistry,
            state: StageState::Ok,
            hint: None,
            raw: None,
            servers: Vec::new(),
        },
        RegistryProbeOutcome::Failed { hint, raw } => StageResult {
            stage: DiagnosisStage::SchemaRegistry,
            state: StageState::Failed,
            hint: Some(hint),
            raw: Some(raw),
            servers: Vec::new(),
        },
        RegistryProbeOutcome::NotChecked(reason) => StageResult {
            stage: DiagnosisStage::SchemaRegistry,
            state: StageState::NotChecked(reason),
            hint: None,
            raw: None,
            servers: Vec::new(),
        },
    };

    let stages = [
        network_stage,
        tls_stage,
        auth_stage,
        metadata_stage,
        registry_stage,
    ];

    let outcome = if kafka_unknown {
        DiagnosisOutcome::FailedStageUnknown
    } else if stages.iter().any(|s| s.state == StageState::Failed) {
        DiagnosisOutcome::Failed
    } else {
        DiagnosisOutcome::Ok
    };

    DiagnosisReport {
        outcome,
        stages,
        unattributed,
        elapsed_ms,
    }
}

fn derive_network_stage(servers: Vec<ServerCheck>, budget_exhausted: bool) -> StageResult {
    if budget_exhausted && servers.is_empty() {
        return StageResult {
            stage: DiagnosisStage::Network,
            state: StageState::NotChecked(NotCheckedReason::BudgetExhausted),
            hint: Some(DiagnosisHint::ConnectTimeout),
            raw: None,
            servers,
        };
    }

    let all_ok = !servers.is_empty()
        && servers
            .iter()
            .all(|s| s.dns == StepState::Ok && s.tcp == StepState::Ok);

    if all_ok {
        StageResult {
            stage: DiagnosisStage::Network,
            state: StageState::Ok,
            hint: None,
            raw: None,
            servers,
        }
    } else {
        let first_fail = servers
            .iter()
            .find(|s| s.dns != StepState::Ok || s.tcp != StepState::Ok);
        StageResult {
            stage: DiagnosisStage::Network,
            state: StageState::Failed,
            hint: first_fail.and_then(|s| s.hint),
            raw: first_fail.and_then(|s| s.raw.clone()),
            servers,
        }
    }
}

fn derive_kafka_stages(
    metadata_probe: MetadataProbeOutcome,
    uses_tls: bool,
    uses_sasl: bool,
) -> (StageResult, StageResult, StageResult, Vec<String>, bool) {
    let na_or_ok_tls = if uses_tls {
        StageState::Ok
    } else {
        StageState::NotApplicable
    };
    let na_or_ok_auth = if uses_sasl {
        StageState::Ok
    } else {
        StageState::NotApplicable
    };

    match metadata_probe {
        MetadataProbeOutcome::Ok => (
            stage_with_state(DiagnosisStage::Tls, na_or_ok_tls, None, None),
            stage_with_state(DiagnosisStage::Authentication, na_or_ok_auth, None, None),
            stage_with_state(DiagnosisStage::Metadata, StageState::Ok, None, None),
            Vec::new(),
            false,
        ),
        MetadataProbeOutcome::NotRun(reason) => (
            stage_with_state(
                DiagnosisStage::Tls,
                if uses_tls {
                    StageState::NotChecked(reason)
                } else {
                    StageState::NotApplicable
                },
                None,
                None,
            ),
            stage_with_state(
                DiagnosisStage::Authentication,
                if uses_sasl {
                    StageState::NotChecked(reason)
                } else {
                    StageState::NotApplicable
                },
                None,
                None,
            ),
            stage_with_state(
                DiagnosisStage::Metadata,
                StageState::NotChecked(reason),
                None,
                None,
            ),
            Vec::new(),
            false,
        ),
        MetadataProbeOutcome::Failed {
            lines,
            metadata_err,
        } => {
            let tags = classify_evidence(&lines, metadata_err.as_ref());

            let mut raw_lines: Vec<String> = lines.iter().map(|l| l.text.clone()).collect();
            if let Some(m) = &metadata_err {
                if !m.text.trim().is_empty() && !raw_lines.contains(&m.text) {
                    raw_lines.push(m.text.clone());
                }
            }
            let primary_raw = raw_lines
                .first()
                .cloned()
                .or_else(|| metadata_err.map(|m| m.text));

            let has_tls = tags.iter().any(|t| matches!(t, EvidenceTag::Tls(_)));
            let has_auth = tags.iter().any(|t| matches!(t, EvidenceTag::Auth(_)));
            let has_authz = tags.iter().any(|t| matches!(t, EvidenceTag::Authorization));
            let stage_count = usize::from(has_tls) + usize::from(has_auth) + usize::from(has_authz);

            if stage_count != 1 {
                return (
                    stage_with_state(
                        DiagnosisStage::Tls,
                        if uses_tls {
                            StageState::Undetermined
                        } else {
                            StageState::NotApplicable
                        },
                        None,
                        None,
                    ),
                    stage_with_state(
                        DiagnosisStage::Authentication,
                        if uses_sasl {
                            StageState::Undetermined
                        } else {
                            StageState::NotApplicable
                        },
                        None,
                        None,
                    ),
                    stage_with_state(
                        DiagnosisStage::Metadata,
                        StageState::Undetermined,
                        None,
                        None,
                    ),
                    raw_lines,
                    true,
                );
            }

            if has_tls {
                let tls_hint = if tags.contains(&EvidenceTag::Tls(TlsEvidence::ProtocolMismatch)) {
                    DiagnosisHint::ProtocolMismatch
                } else if tags.contains(&EvidenceTag::Tls(TlsEvidence::CertificateRejected)) {
                    DiagnosisHint::CertificateRejected
                } else {
                    DiagnosisHint::TlsHandshakeFailed
                };
                return (
                    stage_with_state(
                        DiagnosisStage::Tls,
                        StageState::Failed,
                        Some(tls_hint),
                        primary_raw,
                    ),
                    stage_with_state(
                        DiagnosisStage::Authentication,
                        if uses_sasl {
                            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
                        } else {
                            StageState::NotApplicable
                        },
                        None,
                        None,
                    ),
                    stage_with_state(
                        DiagnosisStage::Metadata,
                        StageState::NotChecked(NotCheckedReason::PreviousStageFailed),
                        None,
                        None,
                    ),
                    Vec::new(),
                    false,
                );
            }

            if has_auth {
                let auth_hint = if tags.contains(&EvidenceTag::Auth(AuthEvidence::Mechanism)) {
                    DiagnosisHint::MechanismRejected
                } else {
                    DiagnosisHint::AuthenticationFailed
                };
                return (
                    stage_with_state(DiagnosisStage::Tls, na_or_ok_tls, None, None),
                    stage_with_state(
                        DiagnosisStage::Authentication,
                        StageState::Failed,
                        Some(auth_hint),
                        primary_raw,
                    ),
                    stage_with_state(
                        DiagnosisStage::Metadata,
                        StageState::NotChecked(NotCheckedReason::PreviousStageFailed),
                        None,
                        None,
                    ),
                    Vec::new(),
                    false,
                );
            }

            // Authorization
            (
                stage_with_state(DiagnosisStage::Tls, na_or_ok_tls, None, None),
                stage_with_state(DiagnosisStage::Authentication, na_or_ok_auth, None, None),
                stage_with_state(
                    DiagnosisStage::Metadata,
                    StageState::Failed,
                    Some(DiagnosisHint::NotAuthorized),
                    primary_raw,
                ),
                Vec::new(),
                false,
            )
        }
    }
}

fn stage_with_state(
    stage: DiagnosisStage,
    state: StageState,
    hint: Option<DiagnosisHint>,
    raw: Option<String>,
) -> StageResult {
    StageResult {
        stage,
        state,
        hint,
        raw,
        servers: Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse_fixture(contents: &str) -> CapturedLine {
        let trimmed = contents.trim();
        let (code_str, text) = trimmed
            .split_once('\t')
            .expect("fixture format: code\\ttext");
        CapturedLine {
            code: code_str.parse::<i32>().ok(),
            text: text.to_string(),
        }
    }

    fn ok_server(entry: &str) -> ServerCheck {
        ServerCheck {
            entry: entry.to_string(),
            dns: StepState::Ok,
            addresses: vec!["127.0.0.1:9092".to_string()],
            tcp: StepState::Ok,
            connected_address: Some("127.0.0.1:9092".to_string()),
            hint: None,
            raw: None,
        }
    }

    fn failed_server(entry: &str) -> ServerCheck {
        ServerCheck {
            entry: entry.to_string(),
            dns: StepState::Ok,
            addresses: vec!["127.0.0.1:9092".to_string()],
            tcp: StepState::Failed,
            connected_address: None,
            hint: Some(DiagnosisHint::ConnectionRefused),
            raw: Some("Connection refused".to_string()),
        }
    }

    #[test]
    fn remaining_handles_before_at_and_after_deadline() {
        let base = Instant::now();
        let deadline = base + Duration::from_secs(10);
        assert_eq!(remaining(deadline, base), Some(Duration::from_secs(10)));
        assert_eq!(remaining(deadline, deadline), None);
        assert_eq!(
            remaining(deadline, deadline + Duration::from_millis(1)),
            None
        );
    }

    #[test]
    fn redact_replaces_secrets_preserves_usernames_and_hosts() {
        assert_eq!(
            redact(
                "SASL failed for user alice on broker1:9092 with s3cr3t",
                &["s3cr3t"]
            ),
            "SASL failed for user alice on broker1:9092 with [redacted]"
        );
        assert_eq!(
            redact("pw1=abc pw2=abcdef", &["abc", "abcdef"]),
            "pw1=[redacted] pw2=[redacted]"
        );
        assert_eq!(redact("keep everything", &["", ""]), "keep everything");
        assert_eq!(redact("short=xy!", &["xy"]), "short=[redacted]!");
    }

    #[test]
    fn classifies_all_spike_fixtures_and_empty_input() {
        assert!(classify_evidence(&[], None).is_empty());

        let fixtures = [
            (
                include_str!("../tests/fixtures/connection_diagnostics/ssl_to_plaintext.txt"),
                EvidenceTag::Tls(TlsEvidence::ProtocolMismatch),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/plaintext_to_ssl.txt"),
                EvidenceTag::Tls(TlsEvidence::ProtocolMismatch),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/untrusted_ca.txt"),
                EvidenceTag::Tls(TlsEvidence::CertificateRejected),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/mtls_client_rejected.txt"),
                EvidenceTag::Tls(TlsEvidence::Handshake),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/wrong_plain_password.txt"),
                EvidenceTag::Auth(AuthEvidence::Failed),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/wrong_scram_password.txt"),
                EvidenceTag::Auth(AuthEvidence::Failed),
            ),
            (
                include_str!("../tests/fixtures/connection_diagnostics/unsupported_mechanism.txt"),
                EvidenceTag::Auth(AuthEvidence::Mechanism),
            ),
            (
                include_str!(
                    "../tests/fixtures/connection_diagnostics/sasl_to_non_sasl_listener.txt"
                ),
                EvidenceTag::Auth(AuthEvidence::Mechanism),
            ),
        ];

        for (raw, expected) in fixtures {
            let line = parse_fixture(raw);
            let tags = classify_evidence(&[line], None);
            assert!(
                tags.contains(&expected),
                "expected {expected:?} in {tags:?} for fixture {raw}"
            );
            assert_eq!(tags.len(), 1);
        }
    }

    #[test]
    fn derives_healthy_sasl_ssl_and_plaintext_profiles() {
        let report = derive_diagnosis(
            vec![ok_server("b1:9093")],
            false,
            MetadataProbeOutcome::Ok,
            RegistryProbeOutcome::Ok,
            true,
            true,
            120,
        );
        assert_eq!(report.outcome, DiagnosisOutcome::Ok);
        assert!(report.stages.iter().all(|s| s.state == StageState::Ok));

        let plain = derive_diagnosis(
            vec![ok_server("b1:9092")],
            false,
            MetadataProbeOutcome::Ok,
            RegistryProbeOutcome::NotApplicable,
            false,
            false,
            40,
        );
        assert_eq!(plain.outcome, DiagnosisOutcome::Ok);
        assert_eq!(plain.stages[0].state, StageState::Ok);
        assert_eq!(plain.stages[1].state, StageState::NotApplicable);
        assert_eq!(plain.stages[2].state, StageState::NotApplicable);
        assert_eq!(plain.stages[3].state, StageState::Ok);
        assert_eq!(plain.stages[4].state, StageState::NotApplicable);
    }

    #[test]
    fn derives_network_failures_and_partial_reachability() {
        let none_reachable = derive_diagnosis(
            vec![failed_server("b1:9092")],
            false,
            MetadataProbeOutcome::NotRun(NotCheckedReason::PreviousStageFailed),
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            50,
        );
        assert_eq!(none_reachable.outcome, DiagnosisOutcome::Failed);
        assert_eq!(none_reachable.stages[0].state, StageState::Failed);
        assert_eq!(
            none_reachable.stages[1].state,
            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
        );
        assert_eq!(
            none_reachable.stages[2].state,
            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
        );
        assert_eq!(
            none_reachable.stages[3].state,
            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
        );

        let partial = derive_diagnosis(
            vec![failed_server("bad:9092"), ok_server("good:9092")],
            false,
            MetadataProbeOutcome::Ok,
            RegistryProbeOutcome::NotApplicable,
            false,
            false,
            80,
        );
        assert_eq!(partial.outcome, DiagnosisOutcome::Failed);
        assert_eq!(partial.stages[0].state, StageState::Failed);
        assert_eq!(partial.stages[3].state, StageState::Ok);
    }

    #[test]
    fn derives_tls_sasl_acl_and_unknown_stage_cases() {
        let cert_fail = derive_diagnosis(
            vec![ok_server("b:9093")],
            false,
            MetadataProbeOutcome::Failed {
                lines: vec![parse_fixture(include_str!(
                    "../tests/fixtures/connection_diagnostics/untrusted_ca.txt"
                ))],
                metadata_err: None,
            },
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            100,
        );
        assert_eq!(cert_fail.outcome, DiagnosisOutcome::Failed);
        assert_eq!(cert_fail.stages[1].state, StageState::Failed);
        assert_eq!(
            cert_fail.stages[1].hint,
            Some(DiagnosisHint::CertificateRejected)
        );
        assert_eq!(
            cert_fail.stages[2].state,
            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
        );

        // Protocol mismatch on PLAINTEXT still marks TLS stage Failed
        let proto_mismatch = derive_diagnosis(
            vec![ok_server("b:9093")],
            false,
            MetadataProbeOutcome::Failed {
                lines: vec![parse_fixture(include_str!(
                    "../tests/fixtures/connection_diagnostics/plaintext_to_ssl.txt"
                ))],
                metadata_err: None,
            },
            RegistryProbeOutcome::NotApplicable,
            false,
            false,
            100,
        );
        assert_eq!(proto_mismatch.stages[1].state, StageState::Failed);
        assert_eq!(
            proto_mismatch.stages[1].hint,
            Some(DiagnosisHint::ProtocolMismatch)
        );

        // SASL failure implies TLS Ok
        let sasl_fail = derive_diagnosis(
            vec![ok_server("b:9094")],
            false,
            MetadataProbeOutcome::Failed {
                lines: vec![parse_fixture(include_str!(
                    "../tests/fixtures/connection_diagnostics/wrong_plain_password.txt"
                ))],
                metadata_err: None,
            },
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            100,
        );
        assert_eq!(sasl_fail.stages[1].state, StageState::Ok);
        assert_eq!(sasl_fail.stages[2].state, StageState::Failed);
        assert_eq!(
            sasl_fail.stages[2].hint,
            Some(DiagnosisHint::AuthenticationFailed)
        );

        // Authorization error -> Metadata failed
        let authz_fail = derive_diagnosis(
            vec![ok_server("b:9094")],
            false,
            MetadataProbeOutcome::Failed {
                lines: Vec::new(),
                metadata_err: Some(CapturedLine {
                    code: Some(RDKAFKA_ERR_CLUSTER_AUTHORIZATION_FAILED),
                    text: "Broker: Cluster authorization failed".to_string(),
                }),
            },
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            100,
        );
        assert_eq!(authz_fail.stages[1].state, StageState::Ok);
        assert_eq!(authz_fail.stages[2].state, StageState::Ok);
        assert_eq!(authz_fail.stages[3].state, StageState::Failed);
        assert_eq!(
            authz_fail.stages[3].hint,
            Some(DiagnosisHint::NotAuthorized)
        );

        // Timeout without evidence -> FailedStageUnknown + Undetermined
        let unknown = derive_diagnosis(
            vec![ok_server("b:9092")],
            false,
            MetadataProbeOutcome::Failed {
                lines: Vec::new(),
                metadata_err: Some(CapturedLine {
                    code: Some(-195),
                    text: "Local: Broker transport failure".to_string(),
                }),
            },
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            5000,
        );
        assert_eq!(unknown.outcome, DiagnosisOutcome::FailedStageUnknown);
        assert_eq!(unknown.stages[1].state, StageState::Undetermined);
        assert_eq!(unknown.stages[2].state, StageState::Undetermined);
        assert_eq!(unknown.stages[3].state, StageState::Undetermined);
        assert_eq!(
            unknown.unattributed,
            vec!["Local: Broker transport failure".to_string()]
        );

        // Contradicting TLS + Auth evidence -> FailedStageUnknown
        let conflict = derive_diagnosis(
            vec![ok_server("b:9094")],
            false,
            MetadataProbeOutcome::Failed {
                lines: vec![
                    parse_fixture(include_str!(
                        "../tests/fixtures/connection_diagnostics/untrusted_ca.txt"
                    )),
                    parse_fixture(include_str!(
                        "../tests/fixtures/connection_diagnostics/wrong_plain_password.txt"
                    )),
                ],
                metadata_err: None,
            },
            RegistryProbeOutcome::NotApplicable,
            true,
            true,
            100,
        );
        assert_eq!(conflict.outcome, DiagnosisOutcome::FailedStageUnknown);
        assert_eq!(conflict.unattributed.len(), 2);
    }

    #[test]
    fn derives_registry_failures_and_budget_exhaustion() {
        let reg_fail = derive_diagnosis(
            vec![ok_server("b:9092")],
            false,
            MetadataProbeOutcome::Ok,
            RegistryProbeOutcome::Failed {
                hint: DiagnosisHint::RegistryUnauthorized,
                raw: "HTTP 401".to_string(),
            },
            false,
            false,
            90,
        );
        assert_eq!(reg_fail.outcome, DiagnosisOutcome::Failed);
        assert_eq!(reg_fail.stages[3].state, StageState::Ok);
        assert_eq!(reg_fail.stages[4].state, StageState::Failed);
        assert_eq!(
            reg_fail.stages[4].hint,
            Some(DiagnosisHint::RegistryUnauthorized)
        );

        let budget = derive_diagnosis(
            vec![ok_server("b:9092")],
            false,
            MetadataProbeOutcome::NotRun(NotCheckedReason::BudgetExhausted),
            RegistryProbeOutcome::NotChecked(NotCheckedReason::BudgetExhausted),
            true,
            true,
            25000,
        );
        assert_eq!(
            budget.stages[1].state,
            StageState::NotChecked(NotCheckedReason::BudgetExhausted)
        );
        assert_eq!(
            budget.stages[4].state,
            StageState::NotChecked(NotCheckedReason::BudgetExhausted)
        );
    }
}
