//! Default and ceiling limits for MCP tool calls (design D3).

use std::time::Duration;

/// Names reported in `limits.reduced` when a request was clamped to a ceiling.
pub mod names {
    pub const MAX_MESSAGES: &str = "max_messages";
    pub const MAX_ANALYSED_MESSAGES: &str = "max_analysed_messages";
    pub const TIME_BUDGET: &str = "time_budget";
    pub const MAX_TEXT_BYTES: &str = "max_text_bytes";
    pub const MAX_SCHEMA_BYTES: &str = "max_schema_bytes";
    pub const MAX_LIST_ENTRIES: &str = "max_list_entries";
    pub const MAX_SEARCH_TOPICS: &str = "max_search_topics";
    pub const MAX_RESULT_BYTES: &str = "max_result_bytes";
    pub const MAX_PARALLEL_CALLS: &str = "max_parallel_calls";
}

pub const DEFAULT_MAX_MESSAGES: usize = 20;
pub const CEILING_MAX_MESSAGES: usize = 100;

pub const DEFAULT_MAX_ANALYSED_MESSAGES: usize = 10_000;
pub const CEILING_MAX_ANALYSED_MESSAGES: usize = 100_000;

pub const DEFAULT_TIME_SECS: u64 = 15;
pub const CEILING_TIME_SECS: u64 = 60;

pub const DEFAULT_MAX_TEXT_BYTES: usize = 4_096;
pub const CEILING_MAX_TEXT_BYTES: usize = 32_768;

pub const DEFAULT_MAX_SCHEMA_BYTES: usize = 65_536;
pub const CEILING_MAX_SCHEMA_BYTES: usize = 65_536;

pub const DEFAULT_MAX_LIST_ENTRIES: usize = 500;
pub const CEILING_MAX_LIST_ENTRIES: usize = 500;

pub const DEFAULT_MAX_SEARCH_TOPICS: usize = 5;
pub const CEILING_MAX_SEARCH_TOPICS: usize = 5;

pub const DEFAULT_MAX_RESULT_BYTES: usize = 1_048_576;
pub const CEILING_MAX_RESULT_BYTES: usize = 1_048_576;

pub const DEFAULT_MAX_PARALLEL_CALLS: usize = 2;
pub const CEILING_MAX_PARALLEL_CALLS: usize = 2;

/// Optional overrides supplied by a tool call. Missing fields keep their defaults.
#[derive(Debug, Clone, Default)]
pub struct LimitRequest {
    pub max_messages: Option<usize>,
    pub max_analysed_messages: Option<usize>,
    pub time_budget_secs: Option<u64>,
    pub max_text_bytes: Option<usize>,
    pub max_schema_bytes: Option<usize>,
    pub max_list_entries: Option<usize>,
    pub max_search_topics: Option<usize>,
    pub max_result_bytes: Option<usize>,
    pub max_parallel_calls: Option<usize>,
}

/// Effective limits after applying defaults and ceilings.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Limits {
    pub max_messages: usize,
    pub max_analysed_messages: usize,
    pub time_budget: Duration,
    pub max_text_bytes: usize,
    pub max_schema_bytes: usize,
    pub max_list_entries: usize,
    pub max_search_topics: usize,
    pub max_result_bytes: usize,
    pub max_parallel_calls: usize,
    /// Limit names that were reduced from the request to the ceiling.
    pub reduced: Vec<&'static str>,
}

impl Limits {
    /// Defaults with an empty `reduced` list.
    pub fn defaults() -> Self {
        Self {
            max_messages: DEFAULT_MAX_MESSAGES,
            max_analysed_messages: DEFAULT_MAX_ANALYSED_MESSAGES,
            time_budget: Duration::from_secs(DEFAULT_TIME_SECS),
            max_text_bytes: DEFAULT_MAX_TEXT_BYTES,
            max_schema_bytes: DEFAULT_MAX_SCHEMA_BYTES,
            max_list_entries: DEFAULT_MAX_LIST_ENTRIES,
            max_search_topics: DEFAULT_MAX_SEARCH_TOPICS,
            max_result_bytes: DEFAULT_MAX_RESULT_BYTES,
            max_parallel_calls: DEFAULT_MAX_PARALLEL_CALLS,
            reduced: Vec::new(),
        }
    }
}

fn clamp_usize(
    requested: Option<usize>,
    default: usize,
    ceiling: usize,
    name: &'static str,
    reduced: &mut Vec<&'static str>,
) -> usize {
    match requested {
        None => default,
        Some(v) if v > ceiling => {
            reduced.push(name);
            ceiling
        }
        Some(v) => v,
    }
}

fn clamp_secs(
    requested: Option<u64>,
    default: u64,
    ceiling: u64,
    name: &'static str,
    reduced: &mut Vec<&'static str>,
) -> Duration {
    let secs = match requested {
        None => default,
        Some(v) if v > ceiling => {
            reduced.push(name);
            ceiling
        }
        Some(v) => v,
    };
    Duration::from_secs(secs)
}

/// Resolve request overrides against defaults and ceilings. Values above a
/// ceiling are reduced, not rejected.
pub fn resolve(request: &LimitRequest) -> Limits {
    let mut reduced = Vec::new();
    Limits {
        max_messages: clamp_usize(
            request.max_messages,
            DEFAULT_MAX_MESSAGES,
            CEILING_MAX_MESSAGES,
            names::MAX_MESSAGES,
            &mut reduced,
        ),
        max_analysed_messages: clamp_usize(
            request.max_analysed_messages,
            DEFAULT_MAX_ANALYSED_MESSAGES,
            CEILING_MAX_ANALYSED_MESSAGES,
            names::MAX_ANALYSED_MESSAGES,
            &mut reduced,
        ),
        time_budget: clamp_secs(
            request.time_budget_secs,
            DEFAULT_TIME_SECS,
            CEILING_TIME_SECS,
            names::TIME_BUDGET,
            &mut reduced,
        ),
        max_text_bytes: clamp_usize(
            request.max_text_bytes,
            DEFAULT_MAX_TEXT_BYTES,
            CEILING_MAX_TEXT_BYTES,
            names::MAX_TEXT_BYTES,
            &mut reduced,
        ),
        max_schema_bytes: clamp_usize(
            request.max_schema_bytes,
            DEFAULT_MAX_SCHEMA_BYTES,
            CEILING_MAX_SCHEMA_BYTES,
            names::MAX_SCHEMA_BYTES,
            &mut reduced,
        ),
        max_list_entries: clamp_usize(
            request.max_list_entries,
            DEFAULT_MAX_LIST_ENTRIES,
            CEILING_MAX_LIST_ENTRIES,
            names::MAX_LIST_ENTRIES,
            &mut reduced,
        ),
        max_search_topics: clamp_usize(
            request.max_search_topics,
            DEFAULT_MAX_SEARCH_TOPICS,
            CEILING_MAX_SEARCH_TOPICS,
            names::MAX_SEARCH_TOPICS,
            &mut reduced,
        ),
        max_result_bytes: clamp_usize(
            request.max_result_bytes,
            DEFAULT_MAX_RESULT_BYTES,
            CEILING_MAX_RESULT_BYTES,
            names::MAX_RESULT_BYTES,
            &mut reduced,
        ),
        max_parallel_calls: clamp_usize(
            request.max_parallel_calls,
            DEFAULT_MAX_PARALLEL_CALLS,
            CEILING_MAX_PARALLEL_CALLS,
            names::MAX_PARALLEL_CALLS,
            &mut reduced,
        ),
        reduced,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_match_design_d3() {
        let l = Limits::defaults();
        assert_eq!(l.max_messages, 20);
        assert_eq!(l.max_analysed_messages, 10_000);
        assert_eq!(l.time_budget, Duration::from_secs(15));
        assert_eq!(l.max_text_bytes, 4_096);
        assert_eq!(l.max_schema_bytes, 65_536);
        assert_eq!(l.max_list_entries, 500);
        assert_eq!(l.max_search_topics, 5);
        assert_eq!(l.max_result_bytes, 1_048_576);
        assert_eq!(l.max_parallel_calls, 2);
        assert!(l.reduced.is_empty());
    }

    #[test]
    fn ceilings_match_design_d3() {
        assert_eq!(CEILING_MAX_MESSAGES, 100);
        assert_eq!(CEILING_MAX_ANALYSED_MESSAGES, 100_000);
        assert_eq!(CEILING_TIME_SECS, 60);
        assert_eq!(CEILING_MAX_TEXT_BYTES, 32_768);
        assert_eq!(CEILING_MAX_SCHEMA_BYTES, 65_536);
        assert_eq!(CEILING_MAX_LIST_ENTRIES, 500);
        assert_eq!(CEILING_MAX_SEARCH_TOPICS, 5);
        assert_eq!(CEILING_MAX_RESULT_BYTES, 1_048_576);
        assert_eq!(CEILING_MAX_PARALLEL_CALLS, 2);
    }

    #[test]
    fn resolve_empty_request_is_defaults() {
        let l = resolve(&LimitRequest::default());
        assert_eq!(l, Limits::defaults());
    }

    #[test]
    fn resolve_accepts_values_at_or_below_ceiling() {
        let l = resolve(&LimitRequest {
            max_messages: Some(100),
            max_analysed_messages: Some(50_000),
            time_budget_secs: Some(60),
            max_text_bytes: Some(32_768),
            max_schema_bytes: Some(65_536),
            max_list_entries: Some(500),
            max_search_topics: Some(5),
            max_result_bytes: Some(1_048_576),
            max_parallel_calls: Some(2),
        });
        assert_eq!(l.max_messages, 100);
        assert_eq!(l.max_analysed_messages, 50_000);
        assert_eq!(l.time_budget, Duration::from_secs(60));
        assert_eq!(l.max_text_bytes, 32_768);
        assert!(l.reduced.is_empty());
    }

    #[test]
    fn resolve_reduces_every_limit_above_ceiling() {
        let l = resolve(&LimitRequest {
            max_messages: Some(10_000),
            max_analysed_messages: Some(1_000_000),
            time_budget_secs: Some(600),
            max_text_bytes: Some(1_000_000),
            max_schema_bytes: Some(1_000_000),
            max_list_entries: Some(10_000),
            max_search_topics: Some(50),
            max_result_bytes: Some(10_000_000),
            max_parallel_calls: Some(20),
        });
        assert_eq!(l.max_messages, CEILING_MAX_MESSAGES);
        assert_eq!(l.max_analysed_messages, CEILING_MAX_ANALYSED_MESSAGES);
        assert_eq!(l.time_budget, Duration::from_secs(CEILING_TIME_SECS));
        assert_eq!(l.max_text_bytes, CEILING_MAX_TEXT_BYTES);
        assert_eq!(l.max_schema_bytes, CEILING_MAX_SCHEMA_BYTES);
        assert_eq!(l.max_list_entries, CEILING_MAX_LIST_ENTRIES);
        assert_eq!(l.max_search_topics, CEILING_MAX_SEARCH_TOPICS);
        assert_eq!(l.max_result_bytes, CEILING_MAX_RESULT_BYTES);
        assert_eq!(l.max_parallel_calls, CEILING_MAX_PARALLEL_CALLS);
        assert_eq!(
            l.reduced,
            vec![
                names::MAX_MESSAGES,
                names::MAX_ANALYSED_MESSAGES,
                names::TIME_BUDGET,
                names::MAX_TEXT_BYTES,
                names::MAX_SCHEMA_BYTES,
                names::MAX_LIST_ENTRIES,
                names::MAX_SEARCH_TOPICS,
                names::MAX_RESULT_BYTES,
                names::MAX_PARALLEL_CALLS,
            ]
        );
    }

    #[test]
    fn resolve_below_default_is_kept() {
        let l = resolve(&LimitRequest {
            max_messages: Some(1),
            time_budget_secs: Some(1),
            max_text_bytes: Some(64),
            ..LimitRequest::default()
        });
        assert_eq!(l.max_messages, 1);
        assert_eq!(l.time_budget, Duration::from_secs(1));
        assert_eq!(l.max_text_bytes, 64);
        assert!(l.reduced.is_empty());
    }
}
