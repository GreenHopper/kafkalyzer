use anyhow::Result;
use kafkalyzer_core::connection_diagnostics as core;

use crate::api::kafka_types::ClusterProfile;

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
    NotChecked,
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
    RegistryHttpError,
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
    pub not_checked_reason: Option<NotCheckedReason>,
    pub hint: Option<DiagnosisHint>,
    pub http_status: Option<u16>,
    pub raw: Option<String>,
    pub servers: Vec<ServerCheck>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConnectionDiagnosis {
    pub outcome: DiagnosisOutcome,
    pub stages: Vec<StageResult>,
    pub unattributed: Vec<String>,
    pub elapsed_ms: u64,
}

impl From<core::DiagnosisOutcome> for DiagnosisOutcome {
    fn from(value: core::DiagnosisOutcome) -> Self {
        match value {
            core::DiagnosisOutcome::Ok => Self::Ok,
            core::DiagnosisOutcome::Failed => Self::Failed,
            core::DiagnosisOutcome::FailedStageUnknown => Self::FailedStageUnknown,
        }
    }
}

impl From<core::DiagnosisStage> for DiagnosisStage {
    fn from(value: core::DiagnosisStage) -> Self {
        match value {
            core::DiagnosisStage::Network => Self::Network,
            core::DiagnosisStage::Tls => Self::Tls,
            core::DiagnosisStage::Authentication => Self::Authentication,
            core::DiagnosisStage::Metadata => Self::Metadata,
            core::DiagnosisStage::SchemaRegistry => Self::SchemaRegistry,
        }
    }
}

impl From<core::NotCheckedReason> for NotCheckedReason {
    fn from(value: core::NotCheckedReason) -> Self {
        match value {
            core::NotCheckedReason::PreviousStageFailed => Self::PreviousStageFailed,
            core::NotCheckedReason::BudgetExhausted => Self::BudgetExhausted,
        }
    }
}

fn map_stage_state(value: core::StageState) -> (StageState, Option<NotCheckedReason>) {
    match value {
        core::StageState::Ok => (StageState::Ok, None),
        core::StageState::Failed => (StageState::Failed, None),
        core::StageState::NotChecked(r) => (StageState::NotChecked, Some(r.into())),
        core::StageState::NotApplicable => (StageState::NotApplicable, None),
        core::StageState::Undetermined => (StageState::Undetermined, None),
    }
}

impl From<core::StepState> for StepState {
    fn from(value: core::StepState) -> Self {
        match value {
            core::StepState::Ok => Self::Ok,
            core::StepState::Failed => Self::Failed,
            core::StepState::NotChecked => Self::NotChecked,
        }
    }
}

fn map_hint(value: core::DiagnosisHint) -> (DiagnosisHint, Option<u16>) {
    match value {
        core::DiagnosisHint::InvalidEntry => (DiagnosisHint::InvalidEntry, None),
        core::DiagnosisHint::HostUnknown => (DiagnosisHint::HostUnknown, None),
        core::DiagnosisHint::ConnectionRefused => (DiagnosisHint::ConnectionRefused, None),
        core::DiagnosisHint::ConnectTimeout => (DiagnosisHint::ConnectTimeout, None),
        core::DiagnosisHint::CertificateRejected => (DiagnosisHint::CertificateRejected, None),
        core::DiagnosisHint::TlsHandshakeFailed => (DiagnosisHint::TlsHandshakeFailed, None),
        core::DiagnosisHint::ProtocolMismatch => (DiagnosisHint::ProtocolMismatch, None),
        core::DiagnosisHint::AuthenticationFailed => (DiagnosisHint::AuthenticationFailed, None),
        core::DiagnosisHint::MechanismRejected => (DiagnosisHint::MechanismRejected, None),
        core::DiagnosisHint::NotAuthorized => (DiagnosisHint::NotAuthorized, None),
        core::DiagnosisHint::RequestTimeout => (DiagnosisHint::RequestTimeout, None),
        core::DiagnosisHint::RegistryUnreachable => (DiagnosisHint::RegistryUnreachable, None),
        core::DiagnosisHint::RegistryUnauthorized => (DiagnosisHint::RegistryUnauthorized, None),
        core::DiagnosisHint::RegistryHttpError(s) => (DiagnosisHint::RegistryHttpError, Some(s)),
        core::DiagnosisHint::Generic => (DiagnosisHint::Generic, None),
    }
}

impl From<core::ServerCheck> for ServerCheck {
    fn from(value: core::ServerCheck) -> Self {
        Self {
            entry: value.entry,
            dns: value.dns.into(),
            addresses: value.addresses,
            tcp: value.tcp.into(),
            connected_address: value.connected_address,
            hint: value.hint.map(|h| map_hint(h).0),
            raw: value.raw,
        }
    }
}

impl From<core::StageResult> for StageResult {
    fn from(value: core::StageResult) -> Self {
        let (state, not_checked_reason) = map_stage_state(value.state);
        let (hint, http_status) = match value.hint {
            Some(h) => {
                let (mapped, status) = map_hint(h);
                (Some(mapped), status)
            }
            None => (None, None),
        };
        Self {
            stage: value.stage.into(),
            state,
            not_checked_reason,
            hint,
            http_status,
            raw: value.raw,
            servers: value.servers.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<core::DiagnosisReport> for ConnectionDiagnosis {
    fn from(value: core::DiagnosisReport) -> Self {
        Self {
            outcome: value.outcome.into(),
            stages: value.stages.into_iter().map(Into::into).collect(),
            unattributed: value.unattributed,
            elapsed_ms: value.elapsed_ms,
        }
    }
}

/// Runs a 5-stage read-only connection diagnosis on the given candidate profile.
pub fn diagnose_connection(profile: ClusterProfile) -> Result<ConnectionDiagnosis> {
    let report =
        kafkalyzer_kafka::connection_diagnostics::diagnose_connection(profile.to_domain())?;
    Ok(report.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_every_state_reason_and_hint_variant() {
        let states = [
            (core::StageState::Ok, (StageState::Ok, None)),
            (core::StageState::Failed, (StageState::Failed, None)),
            (
                core::StageState::NotChecked(core::NotCheckedReason::PreviousStageFailed),
                (
                    StageState::NotChecked,
                    Some(NotCheckedReason::PreviousStageFailed),
                ),
            ),
            (
                core::StageState::NotChecked(core::NotCheckedReason::BudgetExhausted),
                (
                    StageState::NotChecked,
                    Some(NotCheckedReason::BudgetExhausted),
                ),
            ),
            (
                core::StageState::NotApplicable,
                (StageState::NotApplicable, None),
            ),
            (
                core::StageState::Undetermined,
                (StageState::Undetermined, None),
            ),
        ];
        for (src, expected) in states {
            assert_eq!(map_stage_state(src), expected);
        }

        let hints = [
            (
                core::DiagnosisHint::InvalidEntry,
                (DiagnosisHint::InvalidEntry, None),
            ),
            (
                core::DiagnosisHint::HostUnknown,
                (DiagnosisHint::HostUnknown, None),
            ),
            (
                core::DiagnosisHint::ConnectionRefused,
                (DiagnosisHint::ConnectionRefused, None),
            ),
            (
                core::DiagnosisHint::ConnectTimeout,
                (DiagnosisHint::ConnectTimeout, None),
            ),
            (
                core::DiagnosisHint::CertificateRejected,
                (DiagnosisHint::CertificateRejected, None),
            ),
            (
                core::DiagnosisHint::TlsHandshakeFailed,
                (DiagnosisHint::TlsHandshakeFailed, None),
            ),
            (
                core::DiagnosisHint::ProtocolMismatch,
                (DiagnosisHint::ProtocolMismatch, None),
            ),
            (
                core::DiagnosisHint::AuthenticationFailed,
                (DiagnosisHint::AuthenticationFailed, None),
            ),
            (
                core::DiagnosisHint::MechanismRejected,
                (DiagnosisHint::MechanismRejected, None),
            ),
            (
                core::DiagnosisHint::NotAuthorized,
                (DiagnosisHint::NotAuthorized, None),
            ),
            (
                core::DiagnosisHint::RequestTimeout,
                (DiagnosisHint::RequestTimeout, None),
            ),
            (
                core::DiagnosisHint::RegistryUnreachable,
                (DiagnosisHint::RegistryUnreachable, None),
            ),
            (
                core::DiagnosisHint::RegistryUnauthorized,
                (DiagnosisHint::RegistryUnauthorized, None),
            ),
            (
                core::DiagnosisHint::RegistryHttpError(502),
                (DiagnosisHint::RegistryHttpError, Some(502)),
            ),
            (core::DiagnosisHint::Generic, (DiagnosisHint::Generic, None)),
        ];
        for (src, expected) in hints {
            assert_eq!(map_hint(src), expected);
        }
    }
}
