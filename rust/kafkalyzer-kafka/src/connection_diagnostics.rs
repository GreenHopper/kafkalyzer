use std::error::Error as _;
use std::io::ErrorKind;
use std::net::SocketAddr;
use std::time::{Duration, Instant};

use anyhow::Result;
use kafkalyzer_core::bootstrap::{parse_single_entry, BootstrapIssueKind, HostPort};
use kafkalyzer_core::connection_diagnostics::{
    derive_diagnosis, redact, remaining, CapturedLine, DiagnosisHint, DiagnosisReport,
    MetadataProbeOutcome, NotCheckedReason, RegistryProbeOutcome, ServerCheck, StepState,
    DNS_TIMEOUT, METADATA_TIMEOUT, REGISTRY_TIMEOUT, TCP_TIMEOUT, TOTAL_BUDGET,
};
use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_core::tls::{classify_tls_failure, TlsFailureClassification};
use rdkafka::config::RDKafkaLogLevel;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::error::KafkaError;
use tokio::net::TcpStream;

use crate::kafka_consumer::shared_runtime;
use crate::kafka_metadata::ProbeClientContext;
use crate::kafka_utils::create_config;
use crate::schema_registry::schema_registry_client_builder;

/// Diagnoses a cluster profile in 5 read-only stages within `TOTAL_BUDGET`.
pub fn diagnose_connection(profile: ClusterProfile) -> Result<DiagnosisReport> {
    let start = Instant::now();
    let deadline = start + TOTAL_BUDGET;

    let (servers, network_budget_exhausted, metadata_probe, registry_probe) = shared_runtime()
        .block_on(async {
            let net_and_kafka = async {
                let (servers, net_budget_exhausted) = probe_network(&profile, deadline).await;
                let any_connected = servers.iter().any(|s| s.tcp == StepState::Ok);
                let metadata = if !any_connected {
                    MetadataProbeOutcome::NotRun(NotCheckedReason::PreviousStageFailed)
                } else if let Some(rem) = remaining(deadline, Instant::now()) {
                    probe_kafka_metadata(&profile, rem.min(METADATA_TIMEOUT)).await
                } else {
                    MetadataProbeOutcome::NotRun(NotCheckedReason::BudgetExhausted)
                };
                (servers, net_budget_exhausted, metadata)
            };

            let ((servers, net_budget_exhausted, metadata), registry) =
                tokio::join!(net_and_kafka, probe_schema_registry(&profile, deadline),);
            (servers, net_budget_exhausted, metadata, registry)
        });

    let uses_tls = profile.uses_tls();
    let proto = profile.effective_security_protocol();
    let uses_sasl = proto.to_ascii_uppercase().contains("SASL")
        || profile
            .sasl_username
            .as_deref()
            .is_some_and(|u| !u.trim().is_empty());

    let elapsed_ms = start.elapsed().as_millis() as u64;
    let mut report = derive_diagnosis(
        servers,
        network_budget_exhausted,
        metadata_probe,
        registry_probe,
        uses_tls,
        uses_sasl,
        elapsed_ms,
    );

    redact_report(&mut report, &profile);
    Ok(report)
}

fn collect_secrets(profile: &ClusterProfile) -> Vec<&str> {
    [
        profile.sasl_password.as_deref(),
        profile.ssl_keystore_password.as_deref(),
        profile.ssl_truststore_password.as_deref(),
        profile.ssl_pem_key_password.as_deref(),
        profile.sasl_oauthbearer_token.as_deref(),
        profile.schema_registry_password.as_deref(),
    ]
    .into_iter()
    .flatten()
    .filter(|s| !s.is_empty())
    .collect()
}

fn redact_report(report: &mut DiagnosisReport, profile: &ClusterProfile) {
    let secrets = collect_secrets(profile);
    if secrets.is_empty() {
        return;
    }

    for line in &mut report.unattributed {
        *line = redact(line, &secrets);
    }
    for stage in &mut report.stages {
        if let Some(raw) = &mut stage.raw {
            *raw = redact(raw, &secrets);
        }
        for server in &mut stage.servers {
            if let Some(raw) = &mut server.raw {
                *raw = redact(raw, &secrets);
            }
        }
    }
}

pub(crate) async fn probe_network(
    profile: &ClusterProfile,
    deadline: Instant,
) -> (Vec<ServerCheck>, bool) {
    let entries: Vec<&str> = profile
        .bootstrap_servers
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();

    if entries.is_empty() {
        return (
            vec![ServerCheck {
                entry: String::new(),
                dns: StepState::Failed,
                addresses: Vec::new(),
                tcp: StepState::NotChecked,
                connected_address: None,
                hint: Some(DiagnosisHint::InvalidEntry),
                raw: Some("No bootstrap server entries provided".to_string()),
            }],
            false,
        );
    }

    if remaining(deadline, Instant::now()).is_none() {
        return (Vec::new(), true);
    }

    let handles: Vec<_> = entries
        .into_iter()
        .map(|entry| {
            let owned = entry.to_string();
            tokio::spawn(async move {
                match parse_single_entry(&owned) {
                    Ok(hp) => probe_single_server(hp, deadline).await,
                    Err(issue) => ServerCheck {
                        entry: issue.entry,
                        dns: StepState::Failed,
                        addresses: Vec::new(),
                        tcp: StepState::NotChecked,
                        connected_address: None,
                        hint: Some(DiagnosisHint::InvalidEntry),
                        raw: Some(format_bootstrap_issue(issue.kind)),
                    },
                }
            })
        })
        .collect();

    let mut results = Vec::with_capacity(handles.len());
    for handle in handles {
        if let Ok(check) = handle.await {
            results.push(check);
        }
    }
    (results, false)
}

fn format_bootstrap_issue(kind: BootstrapIssueKind) -> String {
    match kind {
        BootstrapIssueKind::NoEntries => "No bootstrap server entries provided".to_string(),
        BootstrapIssueKind::MissingPort => "Missing :port in bootstrap server entry".to_string(),
        BootstrapIssueKind::InvalidPort => "Port must be between 1 and 65535".to_string(),
        BootstrapIssueKind::InvalidHost => "Invalid host in bootstrap server entry".to_string(),
        BootstrapIssueKind::SchemeNotAllowed => {
            "Protocol scheme (://) is not allowed in bootstrap servers".to_string()
        }
    }
}

async fn probe_single_server(hp: HostPort, deadline: Instant) -> ServerCheck {
    let entry = hp.raw.clone();
    let Some(rem) = remaining(deadline, Instant::now()) else {
        return ServerCheck {
            entry,
            dns: StepState::NotChecked,
            addresses: Vec::new(),
            tcp: StepState::NotChecked,
            connected_address: None,
            hint: Some(DiagnosisHint::ConnectTimeout),
            raw: Some("Time budget exhausted before DNS lookup".to_string()),
        };
    };

    let dns_budget = rem.min(DNS_TIMEOUT);
    let target = (hp.host.as_str(), hp.port);
    let lookup_res = tokio::time::timeout(dns_budget, tokio::net::lookup_host(target)).await;

    let addrs: Vec<SocketAddr> = match lookup_res {
        Ok(Ok(iter)) => iter.collect(),
        Ok(Err(e)) => {
            return ServerCheck {
                entry,
                dns: StepState::Failed,
                addresses: Vec::new(),
                tcp: StepState::NotChecked,
                connected_address: None,
                hint: Some(DiagnosisHint::HostUnknown),
                raw: Some(e.to_string()),
            };
        }
        Err(_) => {
            return ServerCheck {
                entry,
                dns: StepState::Failed,
                addresses: Vec::new(),
                tcp: StepState::NotChecked,
                connected_address: None,
                hint: Some(DiagnosisHint::ConnectTimeout),
                raw: Some(format!(
                    "DNS lookup timed out after {}ms",
                    dns_budget.as_millis()
                )),
            };
        }
    };

    if addrs.is_empty() {
        return ServerCheck {
            entry,
            dns: StepState::Failed,
            addresses: Vec::new(),
            tcp: StepState::NotChecked,
            connected_address: None,
            hint: Some(DiagnosisHint::HostUnknown),
            raw: Some("DNS lookup returned no addresses".to_string()),
        };
    }

    let addr_strings: Vec<String> = addrs.iter().map(|a| a.to_string()).collect();
    let step_deadline = Instant::now() + TCP_TIMEOUT;
    let effective_tcp_deadline = step_deadline.min(deadline);

    let mut last_hint = DiagnosisHint::ConnectTimeout;
    let mut last_raw = None;

    for addr in addrs {
        let Some(tcp_rem) = remaining(effective_tcp_deadline, Instant::now()) else {
            last_hint = DiagnosisHint::ConnectTimeout;
            last_raw.get_or_insert_with(|| format!("TCP connect timed out on port {}", hp.port));
            break;
        };

        match tokio::time::timeout(tcp_rem, TcpStream::connect(addr)).await {
            Ok(Ok(stream)) => {
                drop(stream);
                return ServerCheck {
                    entry,
                    dns: StepState::Ok,
                    addresses: addr_strings,
                    tcp: StepState::Ok,
                    connected_address: Some(addr.to_string()),
                    hint: None,
                    raw: None,
                };
            }
            Ok(Err(e)) => {
                if e.kind() == ErrorKind::ConnectionRefused {
                    last_hint = DiagnosisHint::ConnectionRefused;
                } else {
                    last_hint = DiagnosisHint::ConnectTimeout;
                }
                last_raw = Some(e.to_string());
            }
            Err(_) => {
                last_hint = DiagnosisHint::ConnectTimeout;
                last_raw = Some(format!(
                    "TCP connect to {addr} timed out after {}ms",
                    tcp_rem.as_millis()
                ));
            }
        }
    }

    ServerCheck {
        entry,
        dns: StepState::Ok,
        addresses: addr_strings,
        tcp: StepState::Failed,
        connected_address: None,
        hint: Some(last_hint),
        raw: last_raw,
    }
}

async fn probe_kafka_metadata(profile: &ClusterProfile, timeout: Duration) -> MetadataProbeOutcome {
    let profile = profile.clone();
    let res = tokio::task::spawn_blocking(move || {
        let mut cfg = create_config(&profile);
        cfg.set_log_level(RDKafkaLogLevel::Warning);
        let ctx = ProbeClientContext::new();
        let consumer: BaseConsumer<ProbeClientContext> = match cfg.create_with_context(ctx) {
            Ok(c) => c,
            Err(e) => {
                return MetadataProbeOutcome::Failed {
                    lines: Vec::new(),
                    metadata_err: Some(CapturedLine {
                        code: None,
                        text: e.to_string(),
                    }),
                };
            }
        };

        let fetch_res = consumer.fetch_metadata(None, timeout);
        // Drain queued error/log callbacks on BaseConsumer before snapshotting.
        let _ = consumer.poll(Duration::from_millis(10));
        let lines = consumer.context().snapshot_captured();
        drop(consumer);

        match fetch_res {
            Ok(_) => MetadataProbeOutcome::Ok,
            Err(e) => {
                let code = match &e {
                    KafkaError::MetadataFetch(c) | KafkaError::Global(c) => Some(*c as i32),
                    _ => None,
                };
                MetadataProbeOutcome::Failed {
                    lines,
                    metadata_err: Some(CapturedLine {
                        code,
                        text: e.to_string(),
                    }),
                }
            }
        }
    })
    .await;

    match res {
        Ok(outcome) => outcome,
        Err(join_err) => MetadataProbeOutcome::Failed {
            lines: Vec::new(),
            metadata_err: Some(CapturedLine {
                code: None,
                text: join_err.to_string(),
            }),
        },
    }
}

pub(crate) async fn probe_schema_registry(
    profile: &ClusterProfile,
    deadline: Instant,
) -> RegistryProbeOutcome {
    let Some(raw_url) = profile.schema_registry_url.as_deref() else {
        return RegistryProbeOutcome::NotApplicable;
    };
    let base_url = raw_url.trim().trim_end_matches('/');
    if base_url.is_empty() {
        return RegistryProbeOutcome::NotApplicable;
    }

    let Some(rem) = remaining(deadline, Instant::now()) else {
        return RegistryProbeOutcome::NotChecked(NotCheckedReason::BudgetExhausted);
    };

    let timeout = rem.min(REGISTRY_TIMEOUT);
    let client = match schema_registry_client_builder(profile)
        .timeout(timeout)
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            return RegistryProbeOutcome::Failed {
                hint: DiagnosisHint::Generic,
                raw: e.to_string(),
            };
        }
    };

    let url = format!("{base_url}/subjects");
    let mut req = client.get(&url);
    if let Some(user) = profile
        .schema_registry_username
        .as_deref()
        .filter(|u| !u.is_empty())
    {
        req = req.basic_auth(user, profile.schema_registry_password.as_deref());
    }

    let send_res = req.send().await; // allow_read_only_exception: Schema Registry GET
    match send_res {
        Ok(resp) => {
            let status = resp.status();
            if status.is_success() {
                RegistryProbeOutcome::Ok
            } else if status.as_u16() == 401 || status.as_u16() == 403 {
                RegistryProbeOutcome::Failed {
                    hint: DiagnosisHint::RegistryUnauthorized,
                    raw: format!("HTTP {}", status.as_u16()),
                }
            } else {
                RegistryProbeOutcome::Failed {
                    hint: DiagnosisHint::RegistryHttpError(status.as_u16()),
                    raw: format!("HTTP {}", status.as_u16()),
                }
            }
        }
        Err(e) => classify_registry_reqwest_error(e),
    }
}

fn classify_registry_reqwest_error(err: reqwest::Error) -> RegistryProbeOutcome {
    if err.is_timeout() {
        return RegistryProbeOutcome::Failed {
            hint: DiagnosisHint::RequestTimeout,
            raw: err.to_string(),
        };
    }

    let mut chain = vec![err.to_string()];
    let mut cur: Option<&(dyn std::error::Error + 'static)> = err.source();
    while let Some(src) = cur {
        chain.push(src.to_string());
        cur = src.source();
    }

    let hint = match classify_tls_failure(&chain) {
        TlsFailureClassification::CertificateRejected(_) => DiagnosisHint::CertificateRejected,
        TlsFailureClassification::Inconclusive(_) => DiagnosisHint::RegistryUnreachable,
    };

    RegistryProbeOutcome::Failed {
        hint,
        raw: chain.join(": "),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::connection_diagnostics::{DiagnosisOutcome, DiagnosisStage, StageState};
    use rdkafka::client::ClientContext;
    use rdkafka::error::RDKafkaErrorCode;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    #[test]
    fn probe_client_context_records_error_code_and_log_without_forwarding() {
        let ctx = ProbeClientContext::new();
        ctx.error(
            KafkaError::Global(RDKafkaErrorCode::Authentication),
            "SASL failed",
        );
        ctx.log(RDKafkaLogLevel::Error, "FAIL", "handshake failed");

        let snap = ctx.snapshot_captured();
        assert_eq!(snap.len(), 2);
        assert_eq!(snap[0].code, Some(-169));
        assert_eq!(snap[0].text, "SASL failed");
        assert_eq!(snap[1].code, None);
        assert_eq!(snap[1].text, "FAIL: handshake failed");
    }

    #[test]
    fn stage1_probe_handles_ok_refused_unknown_and_malformed_offline() {
        shared_runtime().block_on(async {
            let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let open_port = listener.local_addr().unwrap().port();
            let accept_task = tokio::spawn(async move {
                let _ = listener.accept().await;
            });

            // Bind and immediately drop to get a closed port
            let closed_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let closed_port = closed_listener.local_addr().unwrap().port();
            drop(closed_listener);

            let profile = ClusterProfile {
                bootstrap_servers: format!(
                    "127.0.0.1:{open_port}, 127.0.0.1:{closed_port}, invalid.invalid:9092, bad_entry"
                ),
                ..Default::default()
            };

            let (checks, exhausted) =
                probe_network(&profile, Instant::now() + Duration::from_secs(10)).await;
            assert!(!exhausted);
            assert_eq!(checks.len(), 4);

            assert_eq!(checks[0].dns, StepState::Ok);
            assert_eq!(checks[0].tcp, StepState::Ok);

            assert_eq!(checks[1].dns, StepState::Ok);
            assert_eq!(checks[1].tcp, StepState::Failed);
            assert_eq!(checks[1].hint, Some(DiagnosisHint::ConnectionRefused));

            assert_eq!(checks[2].dns, StepState::Failed);
            assert_eq!(checks[2].tcp, StepState::NotChecked);
            assert_eq!(checks[2].hint, Some(DiagnosisHint::HostUnknown));

            assert_eq!(checks[3].dns, StepState::Failed);
            assert_eq!(checks[3].tcp, StepState::NotChecked);
            assert_eq!(checks[3].hint, Some(DiagnosisHint::InvalidEntry));

            let _ = accept_task.await;
        });
    }

    #[test]
    fn stage2_4_probe_fails_within_timeout_on_closed_port() {
        shared_runtime().block_on(async {
            let closed_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let port = closed_listener.local_addr().unwrap().port();
            drop(closed_listener);

            let profile = ClusterProfile {
                bootstrap_servers: format!("127.0.0.1:{port}"),
                security_protocol: Some("PLAINTEXT".to_string()),
                ..Default::default()
            };

            let outcome = probe_kafka_metadata(&profile, Duration::from_millis(600)).await;
            match outcome {
                MetadataProbeOutcome::Failed { lines, .. } => {
                    assert!(
                        lines.iter().any(|l| l.text.contains("Connection refused")),
                        "expected connection refused in {lines:?}"
                    );
                }
                other => panic!("expected Failed, got {other:?}"),
            }
        });
    }

    #[test]
    fn registry_probe_handles_200_401_timeout_and_unreachable() {
        shared_runtime().block_on(async {
            async fn spawn_http(status_line: &'static str, delay: Duration) -> u16 {
                let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
                let port = listener.local_addr().unwrap().port();
                tokio::spawn(async move {
                    if let Ok((mut sock, _)) = listener.accept().await {
                        let mut buf = [0u8; 512];
                        let _ = sock.read(&mut buf).await;
                        if !delay.is_zero() {
                            tokio::time::sleep(delay).await;
                        }
                        let resp = format!("{status_line}\r\nContent-Length: 2\r\n\r\n[]");
                        let _ = sock.write_all(resp.as_bytes()).await;
                    }
                });
                port
            }

            let p200 = spawn_http("HTTP/1.1 200 OK", Duration::ZERO).await;
            let res200 = probe_schema_registry(
                &ClusterProfile {
                    schema_registry_url: Some(format!("http://127.0.0.1:{p200}")),
                    ..Default::default()
                },
                Instant::now() + Duration::from_secs(5),
            )
            .await;
            assert_eq!(res200, RegistryProbeOutcome::Ok);

            let p401 = spawn_http("HTTP/1.1 401 Unauthorized", Duration::ZERO).await;
            let res401 = probe_schema_registry(
                &ClusterProfile {
                    schema_registry_url: Some(format!("http://127.0.0.1:{p401}")),
                    ..Default::default()
                },
                Instant::now() + Duration::from_secs(5),
            )
            .await;
            assert!(matches!(
                res401,
                RegistryProbeOutcome::Failed {
                    hint: DiagnosisHint::RegistryUnauthorized,
                    ..
                }
            ));

            let pslow = spawn_http("HTTP/1.1 200 OK", Duration::from_millis(400)).await;
            let restimeout = probe_schema_registry(
                &ClusterProfile {
                    schema_registry_url: Some(format!("http://127.0.0.1:{pslow}")),
                    ..Default::default()
                },
                Instant::now() + Duration::from_millis(80),
            )
            .await;
            assert!(matches!(
                restimeout,
                RegistryProbeOutcome::Failed {
                    hint: DiagnosisHint::RequestTimeout,
                    ..
                }
            ));

            let closed = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let closed_port = closed.local_addr().unwrap().port();
            drop(closed);
            let res_unreach = probe_schema_registry(
                &ClusterProfile {
                    schema_registry_url: Some(format!("http://127.0.0.1:{closed_port}")),
                    ..Default::default()
                },
                Instant::now() + Duration::from_secs(5),
            )
            .await;
            assert!(matches!(
                res_unreach,
                RegistryProbeOutcome::Failed {
                    hint: DiagnosisHint::RegistryUnreachable,
                    ..
                }
            ));
        });
    }

    #[test]
    fn diagnose_connection_redacts_secrets_and_respects_budget() {
        let closed = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let port = closed.local_addr().unwrap().port();
        drop(closed);

        let secret = "SuperSecretToken99";
        let report = diagnose_connection(ClusterProfile {
            bootstrap_servers: format!("127.0.0.1:{port}"),
            sasl_username: Some(secret.to_string()),
            sasl_password: Some(secret.to_string()),
            ..Default::default()
        })
        .unwrap();

        assert_eq!(report.outcome, DiagnosisOutcome::Failed);
        assert_eq!(report.stages[0].stage, DiagnosisStage::Network);
        assert_eq!(report.stages[0].state, StageState::Failed);
        assert_eq!(
            report.stages[1].state,
            StageState::NotChecked(NotCheckedReason::PreviousStageFailed)
        );
        let serialized = format!("{report:?}");
        assert!(!serialized.contains(secret));
    }
}
