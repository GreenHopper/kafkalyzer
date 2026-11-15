//! Structural JSON diff engine for comparing two JSON payloads.
//!
//! Produces a flat, deterministically ordered list of [`DiffEntry`] values
//! using the canonical L7 path grammar from [`crate::json_path`].

use std::collections::{HashMap, HashSet};
use std::fmt;

use serde::de::{DeserializeSeed, Deserializer, MapAccess, SeqAccess, Visitor};
use serde::ser::{SerializeMap, SerializeSeq};
use serde::{Deserialize, Serialize, Serializer};

use crate::json_path::{build_canonical_path, FieldPath};

const OBJECT_INDEX_THRESHOLD: usize = 8;

/// Kind of structural difference at a path.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DiffKind {
    Added,
    Removed,
    Changed,
}

/// Which side failed to parse as valid JSON.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InvalidJsonSide {
    Old,
    New,
    Both,
}

/// A single structural difference between two JSON documents.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiffEntry {
    pub path: String,
    pub segments: Vec<String>,
    pub kind: DiffKind,
    #[serde(default)]
    pub old: Option<String>,
    #[serde(default)]
    pub new: Option<String>,
}

/// Options controlling [`diff_json`].
#[derive(Debug, Clone, Default)]
pub struct DiffOptions {
    pub ignore_paths: Vec<String>,
    pub max_entries: Option<usize>,
}

/// Result of comparing two JSON documents.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DiffOutcome {
    Diff {
        entries: Vec<DiffEntry>,
        total: usize,
        hidden: usize,
        truncated: bool,
    },
    InvalidJson {
        side: InvalidJsonSide,
    },
}

#[derive(Debug, Clone)]
enum Node {
    Null,
    Bool(bool),
    Number(serde_json::Number),
    String(String),
    Array(Vec<Node>),
    Object(Vec<(String, Node)>),
}

struct NodeVisitor;

impl<'de> Visitor<'de> for NodeVisitor {
    type Value = Node;

    fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("any valid JSON value")
    }

    fn visit_unit<E: serde::de::Error>(self) -> Result<Node, E> {
        Ok(Node::Null)
    }

    fn visit_bool<E: serde::de::Error>(self, v: bool) -> Result<Node, E> {
        Ok(Node::Bool(v))
    }

    fn visit_i64<E: serde::de::Error>(self, v: i64) -> Result<Node, E> {
        Ok(Node::Number(v.into()))
    }

    fn visit_u64<E: serde::de::Error>(self, v: u64) -> Result<Node, E> {
        Ok(Node::Number(v.into()))
    }

    fn visit_f64<E: serde::de::Error>(self, v: f64) -> Result<Node, E> {
        Ok(serde_json::Number::from_f64(v)
            .map(Node::Number)
            .unwrap_or(Node::Null))
    }

    fn visit_str<E: serde::de::Error>(self, v: &str) -> Result<Node, E> {
        Ok(Node::String(v.to_owned()))
    }

    fn visit_string<E: serde::de::Error>(self, v: String) -> Result<Node, E> {
        Ok(Node::String(v))
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Node, A::Error> {
        let mut items = Vec::with_capacity(seq.size_hint().unwrap_or(0));
        while let Some(elem) = seq.next_element_seed(NodeSeed)? {
            items.push(elem);
        }
        Ok(Node::Array(items))
    }

    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Node, A::Error> {
        let mut entries: Vec<(String, Node)> = Vec::with_capacity(map.size_hint().unwrap_or(0));
        let mut index: Option<HashMap<String, usize>> = None;
        while let Some((k, v)) =
            map.next_entry_seed(std::marker::PhantomData::<String>, NodeSeed)?
        {
            if let Some(ref mut idx_map) = index {
                if let Some(&pos) = idx_map.get(&k) {
                    entries[pos].1 = v;
                } else {
                    let pos = entries.len();
                    idx_map.insert(k.clone(), pos);
                    entries.push((k, v));
                }
            } else if let Some(pos) = entries.iter().position(|(ek, _)| ek == &k) {
                entries[pos].1 = v;
            } else {
                entries.push((k, v));
                if entries.len() > OBJECT_INDEX_THRESHOLD {
                    index = Some(
                        entries
                            .iter()
                            .enumerate()
                            .map(|(i, (ek, _))| (ek.clone(), i))
                            .collect(),
                    );
                }
            }
        }
        Ok(Node::Object(entries))
    }
}

struct NodeSeed;

impl<'de> DeserializeSeed<'de> for NodeSeed {
    type Value = Node;

    fn deserialize<D: Deserializer<'de>>(self, deserializer: D) -> Result<Node, D::Error> {
        deserializer.deserialize_any(NodeVisitor)
    }
}

impl<'de> Deserialize<'de> for Node {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        deserializer.deserialize_any(NodeVisitor)
    }
}

impl Serialize for Node {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        match self {
            Node::Null => serializer.serialize_unit(),
            Node::Bool(b) => serializer.serialize_bool(*b),
            Node::Number(n) => n.serialize(serializer),
            Node::String(s) => serializer.serialize_str(s),
            Node::Array(items) => {
                let mut seq = serializer.serialize_seq(Some(items.len()))?;
                for item in items {
                    seq.serialize_element(item)?;
                }
                seq.end()
            }
            Node::Object(entries) => {
                let mut map = serializer.serialize_map(Some(entries.len()))?;
                for (k, v) in entries {
                    map.serialize_entry(k, v)?;
                }
                map.end()
            }
        }
    }
}

fn to_compact_json(node: &Node) -> String {
    serde_json::to_string(node).unwrap_or_default()
}

fn numbers_equal(a: &serde_json::Number, b: &serde_json::Number) -> bool {
    if a == b {
        return true;
    }
    if let (Some(ia), Some(ib)) = (a.as_i64(), b.as_i64()) {
        return ia == ib;
    }
    if let (Some(ua), Some(ub)) = (a.as_u64(), b.as_u64()) {
        return ua == ub;
    }
    if let (Some(fa), Some(fb)) = (a.as_f64(), b.as_f64()) {
        return fa == fb;
    }
    false
}

fn nodes_equal(a: &Node, b: &Node) -> bool {
    match (a, b) {
        (Node::Null, Node::Null) => true,
        (Node::Bool(x), Node::Bool(y)) => x == y,
        (Node::Number(x), Node::Number(y)) => numbers_equal(x, y),
        (Node::String(x), Node::String(y)) => x == y,
        (Node::Array(x), Node::Array(y)) => {
            x.len() == y.len() && x.iter().zip(y.iter()).all(|(xa, yb)| nodes_equal(xa, yb))
        }
        (Node::Object(x), Node::Object(y)) => {
            if x.len() != y.len() {
                return false;
            }
            if y.len() <= OBJECT_INDEX_THRESHOLD {
                x.iter()
                    .all(|(k, v)| y.iter().any(|(yk, yv)| yk == k && nodes_equal(v, yv)))
            } else {
                let map: HashMap<&str, &Node> = y.iter().map(|(k, v)| (k.as_str(), v)).collect();
                x.iter()
                    .all(|(k, v)| map.get(k.as_str()).is_some_and(|yv| nodes_equal(v, yv)))
            }
        }
        _ => false,
    }
}

struct DiffCollector<'a> {
    ignore_prefixes: Vec<Vec<String>>,
    max_entries: Option<usize>,
    entries: Vec<DiffEntry>,
    total: usize,
    hidden: usize,
    truncated: bool,
    path_buf: Vec<String>,
    _marker: std::marker::PhantomData<&'a ()>,
}

impl<'a> DiffCollector<'a> {
    fn new(options: &DiffOptions) -> Self {
        let ignore_prefixes = options
            .ignore_paths
            .iter()
            .filter_map(|p| FieldPath::parse(p).map(|fp| fp.tokens().to_vec()))
            .collect();
        Self {
            ignore_prefixes,
            max_entries: options.max_entries,
            entries: Vec::new(),
            total: 0,
            hidden: 0,
            truncated: false,
            path_buf: Vec::new(),
            _marker: std::marker::PhantomData,
        }
    }

    fn is_ignored(&self) -> bool {
        if self.path_buf.is_empty() {
            return false;
        }
        self.ignore_prefixes.iter().any(|prefix| {
            !prefix.is_empty()
                && self.path_buf.len() >= prefix.len()
                && self.path_buf[..prefix.len()] == prefix[..]
        })
    }

    fn record(&mut self, kind: DiffKind, old: Option<&Node>, new: Option<&Node>) {
        if self.is_ignored() {
            self.hidden += 1;
            return;
        }
        self.total += 1;
        if self
            .max_entries
            .is_some_and(|cap| self.entries.len() >= cap)
        {
            self.truncated = true;
            return;
        }
        let segments = self.path_buf.clone();
        let path = build_canonical_path(&segments);
        self.entries.push(DiffEntry {
            path,
            segments,
            kind,
            old: old.map(to_compact_json),
            new: new.map(to_compact_json),
        });
    }

    fn diff(&mut self, old: &Node, new: &Node) {
        match (old, new) {
            (Node::Object(oa), Node::Object(ob)) => self.diff_objects(oa, ob),
            (Node::Array(aa), Node::Array(ab)) => self.diff_arrays(aa, ab),
            _ => {
                if !nodes_equal(old, new) {
                    self.record(DiffKind::Changed, Some(old), Some(new));
                }
            }
        }
    }

    fn diff_objects(&mut self, oa: &[(String, Node)], ob: &[(String, Node)]) {
        if ob.len() <= OBJECT_INDEX_THRESHOLD && oa.len() <= OBJECT_INDEX_THRESHOLD {
            for (k, va) in oa {
                self.path_buf.push(k.clone());
                if let Some((_, vb)) = ob.iter().find(|(kb, _)| kb == k) {
                    self.diff(va, vb);
                } else {
                    self.record(DiffKind::Removed, Some(va), None);
                }
                self.path_buf.pop();
            }
            for (k, vb) in ob {
                if !oa.iter().any(|(ka, _)| ka == k) {
                    self.path_buf.push(k.clone());
                    self.record(DiffKind::Added, None, Some(vb));
                    self.path_buf.pop();
                }
            }
        } else {
            let map_b: HashMap<&str, &Node> = ob.iter().map(|(k, v)| (k.as_str(), v)).collect();
            for (k, va) in oa {
                self.path_buf.push(k.clone());
                if let Some(vb) = map_b.get(k.as_str()) {
                    self.diff(va, vb);
                } else {
                    self.record(DiffKind::Removed, Some(va), None);
                }
                self.path_buf.pop();
            }
            let set_a: HashSet<&str> = oa.iter().map(|(k, _)| k.as_str()).collect();
            for (k, vb) in ob {
                if !set_a.contains(k.as_str()) {
                    self.path_buf.push(k.clone());
                    self.record(DiffKind::Added, None, Some(vb));
                    self.path_buf.pop();
                }
            }
        }
    }

    fn diff_arrays(&mut self, aa: &[Node], ab: &[Node]) {
        let min_len = aa.len().min(ab.len());
        let mut prefix = 0;
        while prefix < min_len && nodes_equal(&aa[prefix], &ab[prefix]) {
            prefix += 1;
        }
        let mut suffix = 0;
        while suffix < (min_len - prefix)
            && nodes_equal(&aa[aa.len() - 1 - suffix], &ab[ab.len() - 1 - suffix])
        {
            suffix += 1;
        }

        let rem_a = &aa[prefix..aa.len() - suffix];
        let rem_b = &ab[prefix..ab.len() - suffix];
        // shortcut: positional pairing of the remaining middle slice instead of
        // O(n*m) LCS; can be replaced later without changing the entry model.
        let paired = rem_a.len().min(rem_b.len());
        for i in 0..paired {
            self.path_buf.push((prefix + i).to_string());
            self.diff(&rem_a[i], &rem_b[i]);
            self.path_buf.pop();
        }
        for (i, node) in rem_a.iter().enumerate().skip(paired) {
            self.path_buf.push((prefix + i).to_string());
            self.record(DiffKind::Removed, Some(node), None);
            self.path_buf.pop();
        }
        for (i, node) in rem_b.iter().enumerate().skip(paired) {
            self.path_buf.push((prefix + i).to_string());
            self.record(DiffKind::Added, None, Some(node));
            self.path_buf.pop();
        }
    }
}

/// Compare two JSON documents given as UTF-8 text.
pub fn diff_json(old: &str, new: &str, options: &DiffOptions) -> DiffOutcome {
    let parsed_old = serde_json::from_str::<Node>(old);
    let parsed_new = serde_json::from_str::<Node>(new);

    match (parsed_old, parsed_new) {
        (Err(_), Err(_)) => DiffOutcome::InvalidJson {
            side: InvalidJsonSide::Both,
        },
        (Err(_), Ok(_)) => DiffOutcome::InvalidJson {
            side: InvalidJsonSide::Old,
        },
        (Ok(_), Err(_)) => DiffOutcome::InvalidJson {
            side: InvalidJsonSide::New,
        },
        (Ok(old_node), Ok(new_node)) => {
            let mut collector = DiffCollector::new(options);
            collector.diff(&old_node, &new_node);
            DiffOutcome::Diff {
                entries: collector.entries,
                total: collector.total,
                hidden: collector.hidden,
                truncated: collector.truncated,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn changed_added_removed_in_document_order() {
        let out = diff_json(
            r#"{"a":1,"b":2,"c":3}"#,
            r#"{"a":1,"b":5,"d":4}"#,
            &DiffOptions::default(),
        );
        assert_eq!(
            out,
            DiffOutcome::Diff {
                entries: vec![
                    DiffEntry {
                        path: "b".to_string(),
                        segments: vec!["b".to_string()],
                        kind: DiffKind::Changed,
                        old: Some("2".to_string()),
                        new: Some("5".to_string()),
                    },
                    DiffEntry {
                        path: "c".to_string(),
                        segments: vec!["c".to_string()],
                        kind: DiffKind::Removed,
                        old: Some("3".to_string()),
                        new: None,
                    },
                    DiffEntry {
                        path: "d".to_string(),
                        segments: vec!["d".to_string()],
                        kind: DiffKind::Added,
                        old: None,
                        new: Some("4".to_string()),
                    },
                ],
                total: 3,
                hidden: 0,
                truncated: false,
            }
        );
    }

    #[test]
    fn equal_top_level_scalars_have_no_diffs() {
        let out = diff_json("42", "42", &DiffOptions::default());
        assert_eq!(
            out,
            DiffOutcome::Diff {
                entries: vec![],
                total: 0,
                hidden: 0,
                truncated: false,
            }
        );
    }

    #[test]
    fn mixed_top_level_types_emit_empty_path() {
        let out = diff_json(r#"{"a":1}"#, "[1,2]", &DiffOptions::default());
        assert_eq!(
            out,
            DiffOutcome::Diff {
                entries: vec![DiffEntry {
                    path: String::new(),
                    segments: vec![],
                    kind: DiffKind::Changed,
                    old: Some(r#"{"a":1}"#.to_string()),
                    new: Some("[1,2]".to_string()),
                }],
                total: 1,
                hidden: 0,
                truncated: false,
            }
        );
    }

    #[test]
    fn invalid_json_reports_side() {
        assert_eq!(
            diff_json("hello", "{}", &DiffOptions::default()),
            DiffOutcome::InvalidJson {
                side: InvalidJsonSide::Old
            }
        );
        assert_eq!(
            diff_json("{}", "hello", &DiffOptions::default()),
            DiffOutcome::InvalidJson {
                side: InvalidJsonSide::New
            }
        );
        assert_eq!(
            diff_json("hello", "world", &DiffOptions::default()),
            DiffOutcome::InvalidJson {
                side: InvalidJsonSide::Both
            }
        );
    }

    #[test]
    fn ignore_paths_and_cap() {
        let opts = DiffOptions {
            ignore_paths: vec![
                "".to_string(),
                "$.items[0].ts".to_string(),
                "/meta".to_string(),
                "a.b".to_string(),
            ],
            max_entries: Some(1),
        };
        let old = r#"{"items":[{"ts":1,"v":1}],"meta":{"x":1,"y":2},"a":{"b":1,"bc":1},"z":1}"#;
        let new = r#"{"items":[{"ts":2,"v":2}],"meta":{"x":9,"y":9},"a":{"b":2,"bc":2},"z":2}"#;
        let out = diff_json(old, new, &opts);
        match out {
            DiffOutcome::Diff {
                entries,
                total,
                hidden,
                truncated,
            } => {
                assert_eq!(hidden, 4); // items[0].ts, meta.x, meta.y, a.b
                assert_eq!(total, 3); // items[0].v, a.bc, z
                assert!(truncated);
                assert_eq!(entries.len(), 1);
                assert_eq!(entries[0].path, "/items/0/v");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn fixture_cases_match_diff_json() {
        let raw = std::fs::read_to_string(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../test/fixtures/json_diff/cases.json"
        ))
        .expect("read cases.json");
        let cases: Vec<serde_json::Value> = serde_json::from_str(&raw).expect("parse cases.json");
        for case in cases {
            let name = case["name"].as_str().unwrap();
            let old = case["old"].as_str().unwrap();
            let new = case["new"].as_str().unwrap();
            let expected: Vec<DiffEntry> = serde_json::from_value(case["entries"].clone())
                .unwrap_or_else(|e| {
                    panic!("case {name} missing/invalid entries: {e}");
                });
            match diff_json(old, new, &DiffOptions::default()) {
                DiffOutcome::Diff { entries, .. } => {
                    assert_eq!(entries, expected, "mismatch for fixture case {name}");
                }
                other => panic!("unexpected outcome for {name}: {other:?}"),
            }
        }
    }

    #[test]
    fn duplicate_key_replaced_in_place_and_order_kept() {
        let out = diff_json(
            r#"{"a":1,"b":2,"a":3}"#,
            r#"{"a":3,"b":9}"#,
            &DiffOptions::default(),
        );
        match out {
            DiffOutcome::Diff { entries, .. } => {
                assert_eq!(entries.len(), 1);
                assert_eq!(entries[0].path, "b");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn large_array_completes_quickly() {
        let a: Vec<usize> = (0..100_000).collect();
        let mut b = a.clone();
        b[50_000] = 999_999;
        let sa = serde_json::to_string(&a).unwrap();
        let sb = serde_json::to_string(&b).unwrap();
        let start = std::time::Instant::now();
        let out = diff_json(&sa, &sb, &DiffOptions::default());
        assert!(start.elapsed().as_secs_f64() < 2.0);
        match out {
            DiffOutcome::Diff { entries, .. } => {
                assert_eq!(entries.len(), 1);
                assert_eq!(entries[0].path, "/50000");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn fixture_paths_resolve_against_their_side() {
        let raw = include_str!("../../../test/fixtures/json_diff/cases.json");
        let cases: Vec<serde_json::Value> = serde_json::from_str(raw).unwrap();
        for case in cases {
            let old = case["old"].as_str().unwrap();
            let new = case["new"].as_str().unwrap();
            if let DiffOutcome::Diff { entries, .. } = diff_json(old, new, &DiffOptions::default())
            {
                for entry in entries {
                    if entry.path.is_empty() {
                        continue;
                    }
                    match entry.kind {
                        DiffKind::Added => {
                            assert!(
                                crate::json_path::resolve(new, &entry.path).is_some()
                                    || entry.new.as_deref() == Some("null"),
                                "path {} should resolve in new",
                                entry.path
                            );
                        }
                        DiffKind::Removed => {
                            assert!(
                                crate::json_path::resolve(old, &entry.path).is_some()
                                    || entry.old.as_deref() == Some("null"),
                                "path {} should resolve in old",
                                entry.path
                            );
                        }
                        DiffKind::Changed => {
                            assert!(
                                crate::json_path::resolve(old, &entry.path).is_some()
                                    || entry.old.as_deref() == Some("null"),
                                "path {} should resolve in old",
                                entry.path
                            );
                            assert!(
                                crate::json_path::resolve(new, &entry.path).is_some()
                                    || entry.new.as_deref() == Some("null"),
                                "path {} should resolve in new",
                                entry.path
                            );
                        }
                    }
                }
            }
        }
    }
}
