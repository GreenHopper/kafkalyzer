use kafkalyzer_core::json_diff::{diff_json, DiffKind, DiffOptions, DiffOutcome, InvalidJsonSide};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JsonDiffRequest {
    pub old_json: String,
    pub new_json: String,
    pub ignore_paths: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JsonDiffKind {
    Added,
    Removed,
    Changed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JsonDiffInvalidSide {
    Old,
    New,
    Both,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JsonDiffEntry {
    pub path: String,
    pub segments: Vec<String>,
    pub kind: JsonDiffKind,
    pub old_value: Option<String>,
    pub new_value: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JsonDiffResult {
    pub entries: Vec<JsonDiffEntry>,
    pub total: u32,
    pub hidden: u32,
    pub truncated: bool,
    pub invalid_side: Option<JsonDiffInvalidSide>,
}

/// Compare a batch of JSON document pairs off the UI thread.
pub fn diff_json_batch(
    requests: Vec<JsonDiffRequest>,
    max_entries: Option<u32>,
) -> Vec<JsonDiffResult> {
    let max_entries = max_entries.map(|m| m as usize);
    requests
        .into_iter()
        .map(|req| {
            let opts = DiffOptions {
                ignore_paths: req.ignore_paths,
                max_entries,
            };
            match diff_json(&req.old_json, &req.new_json, &opts) {
                DiffOutcome::Diff {
                    entries,
                    total,
                    hidden,
                    truncated,
                } => JsonDiffResult {
                    entries: entries
                        .into_iter()
                        .map(|e| JsonDiffEntry {
                            path: e.path,
                            segments: e.segments,
                            kind: match e.kind {
                                DiffKind::Added => JsonDiffKind::Added,
                                DiffKind::Removed => JsonDiffKind::Removed,
                                DiffKind::Changed => JsonDiffKind::Changed,
                            },
                            old_value: e.old,
                            new_value: e.new,
                        })
                        .collect(),
                    total: total.min(u32::MAX as usize) as u32,
                    hidden: hidden.min(u32::MAX as usize) as u32,
                    truncated,
                    invalid_side: None,
                },
                DiffOutcome::InvalidJson { side } => JsonDiffResult {
                    entries: Vec::new(),
                    total: 0,
                    hidden: 0,
                    truncated: false,
                    invalid_side: Some(match side {
                        InvalidJsonSide::Old => JsonDiffInvalidSide::Old,
                        InvalidJsonSide::New => JsonDiffInvalidSide::New,
                        InvalidJsonSide::Both => JsonDiffInvalidSide::Both,
                    }),
                },
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn batch_preserves_order_applies_ignore_and_cap() {
        let results = diff_json_batch(
            vec![
                JsonDiffRequest {
                    old_json: r#"{"a":1,"ts":10}"#.to_string(),
                    new_json: r#"{"a":2,"ts":20}"#.to_string(),
                    ignore_paths: vec!["ts".to_string()],
                },
                JsonDiffRequest {
                    old_json: r#"{"x":1,"y":2,"z":3}"#.to_string(),
                    new_json: r#"{"x":9,"y":9,"z":9}"#.to_string(),
                    ignore_paths: vec![],
                },
                JsonDiffRequest {
                    old_json: "not json".to_string(),
                    new_json: "{}".to_string(),
                    ignore_paths: vec![],
                },
            ],
            Some(2),
        );

        assert_eq!(results.len(), 3);

        assert_eq!(results[0].entries.len(), 1);
        assert_eq!(results[0].entries[0].path, "a");
        assert_eq!(results[0].hidden, 1);
        assert!(!results[0].truncated);
        assert_eq!(results[0].invalid_side, None);

        assert_eq!(results[1].entries.len(), 2);
        assert_eq!(results[1].total, 3);
        assert!(results[1].truncated);

        assert_eq!(results[2].invalid_side, Some(JsonDiffInvalidSide::Old));
        assert!(results[2].entries.is_empty());
    }
}
