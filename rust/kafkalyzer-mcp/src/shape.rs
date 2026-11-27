//! Output shaping: text caps, result budget, secret redaction (design D1/D7).

use kafkalyzer_core::kafka_types::ClusterProfile;
use serde::Serialize;

use crate::limits::Limits;

pub const REDACTED: &str = "[redacted]";

/// Why a bounded scan or collect stopped.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StopReason {
    Complete,
    MessageLimit,
    TimeLimit,
    Cancelled,
    ResultBudget,
}

/// Text that may have been cut to a byte cap.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct CappedText {
    pub text: String,
    /// Present when `text` is shorter than the original UTF-8 length.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub original_size: Option<usize>,
}

/// Effective limits as reported on every tool result.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct LimitsReport {
    pub max_messages: usize,
    pub max_analysed_messages: usize,
    pub time_budget_secs: u64,
    pub max_text_bytes: usize,
    pub max_schema_bytes: usize,
    pub max_list_entries: usize,
    pub max_search_topics: usize,
    pub max_result_bytes: usize,
    pub max_parallel_calls: usize,
    pub reduced: Vec<&'static str>,
}

impl From<&Limits> for LimitsReport {
    fn from(l: &Limits) -> Self {
        Self {
            max_messages: l.max_messages,
            max_analysed_messages: l.max_analysed_messages,
            time_budget_secs: l.time_budget.as_secs(),
            max_text_bytes: l.max_text_bytes,
            max_schema_bytes: l.max_schema_bytes,
            max_list_entries: l.max_list_entries,
            max_search_topics: l.max_search_topics,
            max_result_bytes: l.max_result_bytes,
            max_parallel_calls: l.max_parallel_calls,
            reduced: l.reduced.clone(),
        }
    }
}

/// Common fields carried on tool results.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ResultMeta {
    pub limits: LimitsReport,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop_reason: Option<StopReason>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub notes: Vec<String>,
}

impl ResultMeta {
    pub fn new(limits: &Limits) -> Self {
        Self {
            limits: LimitsReport::from(limits),
            stop_reason: None,
            notes: Vec::new(),
        }
    }
}

/// Cuts `text` to at most `max_bytes` on a char boundary. Returns the kept
/// string and marks `original_size` when a cut happened.
pub fn cap_text(text: &str, max_bytes: usize) -> CappedText {
    let original = text.len();
    if original <= max_bytes {
        return CappedText {
            text: text.to_string(),
            original_size: None,
        };
    }
    let mut end = 0;
    for (idx, ch) in text.char_indices() {
        let next = idx + ch.len_utf8();
        if next > max_bytes {
            break;
        }
        end = next;
    }
    CappedText {
        text: text[..end].to_string(),
        original_size: Some(original),
    }
}

fn secret_values(profile: &ClusterProfile) -> Vec<&str> {
    [
        profile.sasl_password.as_deref(),
        profile.schema_registry_password.as_deref(),
        profile.ssl_keystore_password.as_deref(),
        profile.ssl_truststore_password.as_deref(),
        profile.ssl_pem_key_password.as_deref(),
        profile.sasl_oauthbearer_token.as_deref(),
    ]
    .into_iter()
    .flatten()
    .filter(|s| !s.is_empty())
    .collect()
}

/// Replace every occurrence of each non-empty secret value with [`REDACTED`].
pub fn redact(text: &str, profile: &ClusterProfile) -> String {
    let mut out = text.to_string();
    for secret in secret_values(profile) {
        if out.contains(secret) {
            out = out.replace(secret, REDACTED);
        }
    }
    out
}

/// Drop trailing entries until serialising `entries` as a JSON array fits in
/// `max_bytes`. Returns the kept prefix and whether anything was dropped.
pub fn fit_entries_to_budget<T: Serialize>(
    mut entries: Vec<T>,
    max_bytes: usize,
) -> (Vec<T>, bool) {
    let original_len = entries.len();
    while !entries.is_empty() {
        match serde_json::to_vec(&entries) {
            Ok(bytes) if bytes.len() <= max_bytes => {
                let truncated = entries.len() < original_len;
                return (entries, truncated);
            }
            Ok(_) | Err(_) => {
                entries.pop();
            }
        }
    }
    (entries, original_len > 0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::limits::Limits;

    #[test]
    fn cap_text_keeps_whole_characters_and_records_original() {
        let capped = cap_text("aé😂x", 4);
        assert!(capped.text.len() <= 4);
        assert!(capped.text.is_char_boundary(capped.text.len()));
        assert_eq!(capped.text, "aé");
        assert_eq!(capped.original_size, Some("aé😂x".len()));
    }

    #[test]
    fn cap_text_under_limit_has_no_original_size() {
        let capped = cap_text("hi", 10);
        assert_eq!(capped.text, "hi");
        assert_eq!(capped.original_size, None);
    }

    #[test]
    fn redact_replaces_secret_inside_error_text() {
        let profile = ClusterProfile {
            name: "prod".into(),
            bootstrap_servers: "localhost:9092".into(),
            sasl_password: Some("s3cr3t-value".into()),
            ..ClusterProfile::default()
        };
        let err = "auth failed for user with password s3cr3t-value at broker";
        let redacted = redact(err, &profile);
        assert!(!redacted.contains("s3cr3t-value"));
        assert!(redacted.contains(REDACTED));
        assert_eq!(
            redacted,
            "auth failed for user with password [redacted] at broker"
        );
    }

    #[test]
    fn redact_skips_empty_secrets() {
        let profile = ClusterProfile {
            sasl_password: Some(String::new()),
            ..ClusterProfile::default()
        };
        assert_eq!(redact("unchanged", &profile), "unchanged");
    }

    #[test]
    fn fit_entries_drops_from_end_to_meet_budget() {
        let entries: Vec<String> = (0..20)
            .map(|i| format!("entry-{i:04}-{}", "x".repeat(80)))
            .collect();
        let (kept, truncated) = fit_entries_to_budget(entries, 400);
        assert!(truncated);
        assert!(!kept.is_empty());
        let size = serde_json::to_vec(&kept).unwrap().len();
        assert!(size <= 400, "serialized size {size} exceeds budget");
    }

    #[test]
    fn fit_entries_untouched_when_under_budget() {
        let entries = vec!["a".to_string(), "b".to_string()];
        let (kept, truncated) = fit_entries_to_budget(entries.clone(), 1_048_576);
        assert!(!truncated);
        assert_eq!(kept, entries);
    }

    #[test]
    fn result_meta_carries_limits_report() {
        let limits = Limits::defaults();
        let meta = ResultMeta::new(&limits);
        assert_eq!(meta.limits.max_messages, 20);
        assert!(meta.stop_reason.is_none());
        assert!(meta.notes.is_empty());
    }
}
