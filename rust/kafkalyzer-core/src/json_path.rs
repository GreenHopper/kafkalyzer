//! Canonical field-path resolution for JSON payloads.
//!
//! This is the single authoritative path grammar used by projected table
//! columns, script extraction steps, and broker-side message filters.
//!
//! Accepted notations (all resolve identically for the same field):
//!
//! - dot notation: `order.customerId`
//! - positional index inside dots: `order.items.1.sku`
//! - bracket index: `order.items[1].sku`
//! - `$`-prefixed path: `$.order.items[1].sku`
//! - RFC 6901 JSON Pointer: `/order/items/1/sku` (keys escape as `~1` for `/`
//!   and `~0` for `~`, so the key `a/b` is written `/a~1b`)
//!
//! Recursive descent, wildcards and filter expressions are deliberately not
//! supported. A path that cannot be resolved yields `None`, which every caller
//! renders as an empty value.
//!
//! Returned values are text: JSON strings are returned without their quotes,
//! objects and arrays are returned as compact JSON, numbers and booleans as
//! their JSON literal. A JSON `null` yields `None`.

use serde_json::Value;

/// Split a user-supplied path into object keys and array indices.
///
/// Returns `None` for an empty path, which is never a meaningful field.
fn tokenize(path: &str) -> Option<Vec<String>> {
    let path = path.trim();
    if path.is_empty() {
        return None;
    }

    let tokens: Vec<String> = if let Some(pointer) = path.strip_prefix('/') {
        pointer.split('/').map(unescape_pointer_token).collect()
    } else {
        let dotted = path.strip_prefix('$').unwrap_or(path);
        split_dotted(dotted.strip_prefix('.').unwrap_or(dotted))
    };

    if tokens.is_empty() {
        None
    } else {
        Some(tokens)
    }
}

/// Split `a.b[0].c` into `["a", "b", "0", "c"]`.
fn split_dotted(dotted: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    for segment in dotted.split('.') {
        let mut name = String::new();
        let mut chars = segment.chars();
        while let Some(c) = chars.next() {
            if c != '[' {
                name.push(c);
                continue;
            }
            if !name.is_empty() {
                tokens.push(std::mem::take(&mut name));
            }
            let mut index = String::new();
            for c in chars.by_ref() {
                if c == ']' {
                    break;
                }
                index.push(c);
            }
            tokens.push(index);
        }
        if !name.is_empty() {
            tokens.push(name);
        }
    }
    tokens
}

fn unescape_pointer_token(token: &str) -> String {
    token.replace("~1", "/").replace("~0", "~")
}

fn get<'a>(value: &'a Value, tokens: &[String]) -> Option<&'a Value> {
    let mut current = value;
    for token in tokens {
        current = match current {
            // `Value::get(&str)` does not index arrays, so numeric tokens are
            // resolved here.
            Value::Array(items) => items.get(token.parse::<usize>().ok()?)?,
            Value::Object(map) => map.get(token.as_str())?,
            _ => return None,
        };
    }
    Some(current)
}

/// Format a resolved value the way every kafkalyzer consumer renders it.
fn render(value: &Value) -> Option<String> {
    match value {
        Value::String(s) => Some(s.clone()),
        Value::Null => None,
        Value::Number(n) => Some(n.to_string()),
        Value::Bool(b) => Some(b.to_string()),
        Value::Array(_) | Value::Object(_) => Some(value.to_string()),
    }
}

/// Resolve `path` inside an already parsed JSON document.
pub fn resolve_value(value: &Value, path: &str) -> Option<String> {
    let tokens = tokenize(path)?;
    render(get(value, &tokens)?)
}

/// Resolve `path` inside a JSON document given as text.
///
/// A payload that is not valid JSON never resolves a field.
pub fn resolve(payload: &str, path: &str) -> Option<String> {
    let value: Value = serde_json::from_str(payload).ok()?;
    resolve_value(&value, path)
}

/// Resolve every `path` for every `payload`.
///
/// The result is payload-major and flattened: entry `i * paths.len() + j`
/// belongs to `payloads[i]` and `paths[j]`. Callers pass a whole batch so the
/// bridge is crossed once per batch instead of once per cell.
pub fn resolve_batch(payloads: &[String], paths: &[String]) -> Vec<Option<String>> {
    payloads
        .iter()
        .flat_map(|payload| {
            let parsed = serde_json::from_str::<Value>(payload).ok();
            paths
                .iter()
                .map(move |path| parsed.as_ref().and_then(|value| resolve_value(value, path)))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const PAYLOAD: &str = r#"{"order":{"status":"shipped","items":[{"sku":"A-1"},{"sku":"B-2"}],"totals":{"net":9.5}},"flag":true,"nothing":null}"#;

    #[test]
    fn resolves_every_accepted_notation() {
        for path in [
            "order.status",
            "$.order.status",
            "/order/status",
            "order.items[1].sku",
            "order.items.1.sku",
            "$.order.items[1].sku",
            "/order/items/1/sku",
        ] {
            let expected = if path.contains("items") {
                "B-2"
            } else {
                "shipped"
            };
            assert_eq!(
                resolve(PAYLOAD, path).as_deref(),
                Some(expected),
                "path: {path}"
            );
        }
    }

    #[test]
    fn returns_scalars_and_compact_containers() {
        assert_eq!(resolve(PAYLOAD, "order.status").as_deref(), Some("shipped"));
        assert_eq!(resolve(PAYLOAD, "order.totals.net").as_deref(), Some("9.5"));
        assert_eq!(resolve(PAYLOAD, "flag").as_deref(), Some("true"));
        assert_eq!(
            resolve(PAYLOAD, "order.items[0]").as_deref(),
            Some(r#"{"sku":"A-1"}"#)
        );
    }

    #[test]
    fn missing_paths_null_and_non_json_yield_none() {
        assert_eq!(resolve(PAYLOAD, "order.missing"), None);
        assert_eq!(resolve(PAYLOAD, "order.items[7].sku"), None);
        assert_eq!(resolve(PAYLOAD, "nothing"), None);
        assert_eq!(resolve("<Binary Data>", "id"), None);
        assert_eq!(resolve(PAYLOAD, ""), None);
    }

    #[test]
    fn indexes_a_top_level_array() {
        let payload = r#"[{"sku":"X"},{"sku":"Y"}]"#;
        assert_eq!(resolve(payload, "[1].sku").as_deref(), Some("Y"));
        assert_eq!(resolve(payload, "0.sku").as_deref(), Some("X"));
    }

    #[test]
    fn pointer_notation_reaches_keys_that_dots_cannot() {
        let payload = r#"{"a/b":{"c~d":5}}"#;
        assert_eq!(resolve(payload, "/a~1b/c~0d").as_deref(), Some("5"));
    }

    #[test]
    fn batch_returns_one_entry_per_payload_and_path() {
        let payloads = vec![
            PAYLOAD.to_string(),
            r#"{"order":{"status":"new"}}"#.to_string(),
        ];
        let paths = vec!["order.status".to_string(), "order.missing".to_string()];

        let values = resolve_batch(&payloads, &paths);

        assert_eq!(
            values,
            vec![
                Some("shipped".to_string()),
                None,
                Some("new".to_string()),
                None,
            ]
        );
    }
}
