use std::collections::{HashMap, HashSet};
use std::panic::{catch_unwind, AssertUnwindSafe};

use anyhow::{anyhow, Context as _, Result};
use protofish::context::{Context as ProtoContext, MessageInfo, Multiplicity, ValueType};
use regex::Regex;
use serde_json::Value;

use crate::json_path::build_canonical_path;

const MAX_DEPTH: usize = 32;
const MAX_ENTRIES: usize = 5_000;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SchemaKind {
    Avro,
    Protobuf,
    Json,
    Other(String),
}

impl SchemaKind {
    pub fn from_registry_type(raw: Option<&str>) -> Self {
        let Some(trimmed) = raw.map(str::trim).filter(|s| !s.is_empty()) else {
            return Self::Avro;
        };
        match trimmed.to_ascii_uppercase().as_str() {
            "AVRO" => Self::Avro,
            "PROTOBUF" => Self::Protobuf,
            "JSON" => Self::Json,
            _ => Self::Other(trimmed.to_string()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaReference {
    pub name: String,
    pub subject: String,
    pub version: i32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectSchema {
    pub subject: String,
    pub version: i32,
    pub id: i32,
    pub schema_type: SchemaKind,
    pub schema: String,
    pub references: Vec<SchemaReference>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolvedReference {
    pub name: String,
    pub kind: SchemaKind,
    pub schema: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FieldNote {
    Recursive,
    UnresolvedReference(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaFieldEntry {
    pub path: String,
    pub name: String,
    pub depth: u32,
    pub type_label: String,
    pub doc: Option<String>,
    pub optional: bool,
    pub repeated: bool,
    pub note: Option<FieldNote>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaFieldModel {
    pub kind: SchemaKind,
    pub root_name: Option<String>,
    pub messages: Vec<String>,
    pub fields: Vec<SchemaFieldEntry>,
    pub truncated: bool,
    pub unavailable_reason: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicSide {
    Key,
    Value,
    None,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectAssociation {
    pub subject: String,
    pub topic: Option<String>,
    pub side: TopicSide,
    pub on_cluster: bool,
}

/// Parses a Confluent Schema Registry `GET /subjects/{subject}/versions/{version}` JSON payload.
/// Missing `schemaType` defaults to `SchemaKind::Avro`.
pub fn parse_subject_schema(value: &Value) -> Result<SubjectSchema> {
    let obj = value
        .as_object()
        .ok_or_else(|| anyhow!("schema response is not a JSON object"))?;

    let subject = obj
        .get("subject")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| anyhow!("schema response missing 'subject'"))?
        .to_string();

    let version_raw = obj
        .get("version")
        .and_then(Value::as_i64)
        .ok_or_else(|| anyhow!("schema response missing integer 'version'"))?;
    let version = i32::try_from(version_raw).context("schema 'version' out of i32 range")?;

    let id_raw = obj
        .get("id")
        .and_then(Value::as_i64)
        .ok_or_else(|| anyhow!("schema response missing integer 'id'"))?;
    let id = i32::try_from(id_raw).context("schema 'id' out of i32 range")?;

    let schema = obj
        .get("schema")
        .and_then(Value::as_str)
        .ok_or_else(|| anyhow!("schema response missing 'schema'"))?
        .to_string();

    let schema_type = SchemaKind::from_registry_type(obj.get("schemaType").and_then(Value::as_str));

    let mut references = Vec::new();
    if let Some(refs_val) = obj.get("references") {
        let refs_arr = refs_val
            .as_array()
            .ok_or_else(|| anyhow!("schema 'references' is not an array"))?;
        for r in refs_arr {
            let robj = r
                .as_object()
                .ok_or_else(|| anyhow!("schema reference entry is not an object"))?;
            let name = robj
                .get("name")
                .and_then(Value::as_str)
                .ok_or_else(|| anyhow!("schema reference missing 'name'"))?
                .to_string();
            let ref_subject = robj
                .get("subject")
                .and_then(Value::as_str)
                .ok_or_else(|| anyhow!("schema reference missing 'subject'"))?
                .to_string();
            let ref_ver_raw = robj
                .get("version")
                .and_then(Value::as_i64)
                .ok_or_else(|| anyhow!("schema reference missing integer 'version'"))?;
            let ref_ver =
                i32::try_from(ref_ver_raw).context("reference 'version' out of i32 range")?;
            references.push(SchemaReference {
                name,
                subject: ref_subject,
                version: ref_ver,
            });
        }
    }

    Ok(SubjectSchema {
        subject,
        version,
        id,
        schema_type,
        schema,
        references,
    })
}

/// Parses a Confluent Schema Registry `/config` or `/config/{subject}` compatibility response.
/// Accepts either `compatibilityLevel` or `compatibility`.
pub fn parse_compatibility_level(value: &Value) -> Result<String> {
    let obj = value
        .as_object()
        .ok_or_else(|| anyhow!("compatibility response is not a JSON object"))?;
    let level = obj
        .get("compatibilityLevel")
        .or_else(|| obj.get("compatibility"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| anyhow!("compatibility response missing 'compatibilityLevel'"))?;
    Ok(level.to_string())
}

/// Derives candidate/matching topic names for a single subject using the `<topic>-key` / `<topic>-value` rule.
pub fn resolve_associated_topics_for_subject(
    subject: &str,
    available_topics: &[String],
) -> Vec<String> {
    let mut topics = Vec::new();
    if let Some(prefix) = subject
        .strip_suffix("-value")
        .or_else(|| subject.strip_suffix("-key"))
    {
        if !prefix.is_empty() {
            topics.push(prefix.to_string());
        }
    }
    for t in available_topics {
        if (t == subject || format!("{t}-value") == subject || format!("{t}-key") == subject)
            && !topics.contains(t)
        {
            topics.push(t.clone());
        }
    }
    topics
}

/// Batch-associates Schema Registry subject names with cluster topics using `<topic>-key` / `<topic>-value`.
pub fn associate_subjects(subjects: &[String], topics: &[String]) -> Vec<SubjectAssociation> {
    let topic_set: HashSet<&str> = topics.iter().map(String::as_str).collect();
    subjects
        .iter()
        .map(|subject| {
            let (topic, side) = if let Some(prefix) = subject.strip_suffix("-value") {
                if prefix.is_empty() {
                    (None, TopicSide::None)
                } else {
                    (Some(prefix.to_string()), TopicSide::Value)
                }
            } else if let Some(prefix) = subject.strip_suffix("-key") {
                if prefix.is_empty() {
                    (None, TopicSide::None)
                } else {
                    (Some(prefix.to_string()), TopicSide::Key)
                }
            } else {
                (None, TopicSide::None)
            };

            let on_cluster = topic.as_deref().is_some_and(|t| topic_set.contains(t));

            SubjectAssociation {
                subject: subject.clone(),
                topic,
                side,
                on_cluster,
            }
        })
        .collect()
}

/// Builds a type-aware, pre-order flat field model for Avro, JSON Schema, or proto3 Protobuf.
pub fn schema_fields(
    kind: SchemaKind,
    schema_text: &str,
    refs: &[ResolvedReference],
) -> SchemaFieldModel {
    match &kind {
        SchemaKind::Avro => build_avro_fields(schema_text, refs),
        SchemaKind::Json => build_json_schema_fields(schema_text, refs),
        SchemaKind::Protobuf => build_protobuf_fields(schema_text, refs),
        SchemaKind::Other(name) => SchemaFieldModel {
            kind: kind.clone(),
            root_name: None,
            messages: Vec::new(),
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some(format!("unsupported schema type: {name}")),
        },
    }
}

// ---------------------------------------------------------------------------
// Avro walker
// ---------------------------------------------------------------------------

const AVRO_PRIMITIVES: &[&str] = &[
    "null", "boolean", "int", "long", "float", "double", "bytes", "string",
];

fn build_avro_fields(schema_text: &str, refs: &[ResolvedReference]) -> SchemaFieldModel {
    let Ok(root_val) = serde_json::from_str::<Value>(schema_text) else {
        return SchemaFieldModel {
            kind: SchemaKind::Avro,
            root_name: None,
            messages: Vec::new(),
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some("invalid Avro JSON".to_string()),
        };
    };

    let mut named_types: HashMap<String, Value> = HashMap::new();
    for r in refs {
        if r.kind == SchemaKind::Avro {
            if let Ok(ref_val) = serde_json::from_str::<Value>(&r.schema) {
                collect_avro_named_types(&ref_val, None, &mut named_types);
            }
        }
    }
    collect_avro_named_types(&root_val, None, &mut named_types);

    let resolved_root = match &root_val {
        Value::String(name) => named_types.get(name).unwrap_or(&root_val),
        _ => &root_val,
    };

    let root_name = resolved_root
        .as_object()
        .and_then(|o| o.get("name"))
        .and_then(Value::as_str)
        .map(str::to_string);

    let mut fields_out = Vec::new();
    let mut truncated = false;
    let mut active_records = HashSet::new();
    if let Some(full) = resolved_root
        .as_object()
        .and_then(|o| avro_full_name(o, None))
    {
        active_records.insert(full);
    }

    if let Some(field_arr) = resolved_root
        .as_object()
        .and_then(|o| o.get("fields"))
        .and_then(Value::as_array)
    {
        walk_avro_record_fields(
            field_arr,
            &[],
            0,
            &named_types,
            &mut active_records,
            &mut fields_out,
            &mut truncated,
        );
    }

    SchemaFieldModel {
        kind: SchemaKind::Avro,
        root_name,
        messages: Vec::new(),
        fields: fields_out,
        truncated,
        unavailable_reason: None,
    }
}

fn avro_full_name(
    obj: &serde_json::Map<String, Value>,
    enclosing_ns: Option<&str>,
) -> Option<String> {
    let name = obj.get("name")?.as_str()?;
    if name.contains('.') {
        return Some(name.to_string());
    }
    let ns = obj
        .get("namespace")
        .and_then(Value::as_str)
        .or(enclosing_ns);
    Some(match ns {
        Some(n) if !n.is_empty() => format!("{n}.{name}"),
        _ => name.to_string(),
    })
}

fn collect_avro_named_types(
    val: &Value,
    enclosing_ns: Option<&str>,
    out: &mut HashMap<String, Value>,
) {
    match val {
        Value::Array(arr) => {
            for item in arr {
                collect_avro_named_types(item, enclosing_ns, out);
            }
        }
        Value::Object(obj) => {
            let ty = obj.get("type").and_then(Value::as_str);
            let ns = obj
                .get("namespace")
                .and_then(Value::as_str)
                .or(enclosing_ns);
            if matches!(ty, Some("record" | "enum" | "fixed")) {
                if let Some(short) = obj.get("name").and_then(Value::as_str) {
                    out.insert(short.to_string(), val.clone());
                }
                if let Some(full) = avro_full_name(obj, enclosing_ns) {
                    out.insert(full, val.clone());
                }
            }
            if let Some(fields) = obj.get("fields").and_then(Value::as_array) {
                for f in fields {
                    if let Some(ft) = f.get("type") {
                        collect_avro_named_types(ft, ns, out);
                    }
                }
            }
            if let Some(items) = obj.get("items") {
                collect_avro_named_types(items, ns, out);
            }
            if let Some(values) = obj.get("values") {
                collect_avro_named_types(values, ns, out);
            }
            if let Some(inner_type) = obj.get("type").filter(|t| !t.is_string()) {
                collect_avro_named_types(inner_type, ns, out);
            }
        }
        _ => {}
    }
}

fn walk_avro_record_fields(
    fields: &[Value],
    prefix: &[String],
    depth: usize,
    named_types: &HashMap<String, Value>,
    active_records: &mut HashSet<String>,
    out: &mut Vec<SchemaFieldEntry>,
    truncated: &mut bool,
) {
    if depth > MAX_DEPTH {
        *truncated = true;
        return;
    }
    for f in fields {
        if out.len() >= MAX_ENTRIES {
            *truncated = true;
            return;
        }
        let Some(obj) = f.as_object() else {
            continue;
        };
        let Some(name) = obj
            .get("name")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
        else {
            continue;
        };
        let doc = obj.get("doc").and_then(Value::as_str).map(str::to_string);
        let field_type = obj.get("type").unwrap_or(&Value::Null);

        let mut next_segments = prefix.to_vec();
        next_segments.push(name.to_string());
        let path = build_canonical_path(&next_segments);

        let (unwrapped, optional) = unwrap_avro_optional_union(field_type);
        let repeated = is_avro_array(unwrapped, named_types);
        let type_label = avro_type_label(field_type);

        let mut note = None;
        let child_record = resolve_avro_expandable(unwrapped, named_types, &mut note);

        if let Some((rec_key, _)) = &child_record {
            if active_records.contains(rec_key) {
                note = Some(FieldNote::Recursive);
            }
        }

        out.push(SchemaFieldEntry {
            path,
            name: name.to_string(),
            depth: depth as u32,
            type_label,
            doc,
            optional,
            repeated,
            note: note.clone(),
        });

        if note.is_none() {
            if let Some((rec_key, rec_fields)) = child_record {
                if depth + 1 > MAX_DEPTH {
                    *truncated = true;
                } else if active_records.insert(rec_key.clone()) {
                    walk_avro_record_fields(
                        &rec_fields,
                        &next_segments,
                        depth + 1,
                        named_types,
                        active_records,
                        out,
                        truncated,
                    );
                    active_records.remove(&rec_key);
                }
            }
        }
    }
}

fn unwrap_avro_optional_union(val: &Value) -> (&Value, bool) {
    if let Value::Array(branches) = val {
        let has_null = branches.iter().any(|b| {
            b.as_str() == Some("null") || b.get("type").and_then(Value::as_str) == Some("null")
        });
        let non_null: Vec<&Value> = branches
            .iter()
            .filter(|b| {
                b.as_str() != Some("null") && b.get("type").and_then(Value::as_str) != Some("null")
            })
            .collect();
        if has_null && non_null.len() == 1 {
            return (non_null[0], true);
        }
        return (val, has_null);
    }
    (val, false)
}

fn is_avro_array(val: &Value, named_types: &HashMap<String, Value>) -> bool {
    match val {
        Value::Object(o) => o.get("type").and_then(Value::as_str) == Some("array"),
        Value::String(s) => named_types
            .get(s)
            .is_some_and(|resolved| is_avro_array(resolved, named_types)),
        _ => false,
    }
}

fn resolve_avro_expandable(
    val: &Value,
    named_types: &HashMap<String, Value>,
    note: &mut Option<FieldNote>,
) -> Option<(String, Vec<Value>)> {
    match val {
        Value::String(name) => {
            if AVRO_PRIMITIVES.contains(&name.as_str()) {
                return None;
            }
            let Some(target) = named_types.get(name) else {
                *note = Some(FieldNote::UnresolvedReference(name.clone()));
                return None;
            };
            resolve_avro_expandable(target, named_types, note)
        }
        Value::Object(obj) => match obj.get("type").and_then(Value::as_str) {
            Some("record") => {
                let key = avro_full_name(obj, None)
                    .or_else(|| obj.get("name").and_then(Value::as_str).map(str::to_string))
                    .unwrap_or_else(|| "<record>".to_string());
                let fields = obj
                    .get("fields")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default();
                Some((key, fields))
            }
            Some("array") => obj
                .get("items")
                .and_then(|items| resolve_avro_expandable(items, named_types, note)),
            Some("map") => obj
                .get("values")
                .and_then(|values| resolve_avro_expandable(values, named_types, note)),
            _ => {
                if let Some(inner) = obj.get("type").filter(|t| !t.is_string()) {
                    resolve_avro_expandable(inner, named_types, note)
                } else {
                    None
                }
            }
        },
        Value::Array(branches) => {
            for b in branches {
                if b.as_str() == Some("null") {
                    continue;
                }
                if let Some(found) = resolve_avro_expandable(b, named_types, note) {
                    return Some(found);
                }
            }
            None
        }
        _ => None,
    }
}

fn avro_type_label(val: &Value) -> String {
    match val {
        Value::String(s) => s.clone(),
        Value::Array(branches) => {
            let parts: Vec<String> = branches.iter().map(avro_type_label).collect();
            parts.join(" | ")
        }
        Value::Object(obj) => {
            if let Some(logical) = obj.get("logicalType").and_then(Value::as_str) {
                return logical.to_string();
            }
            match obj.get("type").and_then(Value::as_str) {
                Some("record") | Some("enum") | Some("fixed") => obj
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or("record")
                    .to_string(),
                Some("array") => {
                    let item = obj
                        .get("items")
                        .map(avro_type_label)
                        .unwrap_or_else(|| "any".to_string());
                    format!("array<{item}>")
                }
                Some("map") => {
                    let v = obj
                        .get("values")
                        .map(avro_type_label)
                        .unwrap_or_else(|| "any".to_string());
                    format!("map<{v}>")
                }
                Some(prim) => prim.to_string(),
                None => obj
                    .get("type")
                    .map(avro_type_label)
                    .unwrap_or_else(|| "unknown".to_string()),
            }
        }
        _ => "unknown".to_string(),
    }
}

// ---------------------------------------------------------------------------
// JSON Schema walker
// ---------------------------------------------------------------------------

fn build_json_schema_fields(schema_text: &str, refs: &[ResolvedReference]) -> SchemaFieldModel {
    let Ok(root_val) = serde_json::from_str::<Value>(schema_text) else {
        return SchemaFieldModel {
            kind: SchemaKind::Json,
            root_name: None,
            messages: Vec::new(),
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some("invalid JSON Schema".to_string()),
        };
    };

    let mut docs: HashMap<String, Value> = HashMap::new();
    docs.insert(String::new(), root_val.clone());
    for r in refs {
        if r.kind == SchemaKind::Json {
            if let Ok(v) = serde_json::from_str::<Value>(&r.schema) {
                docs.insert(r.name.clone(), v);
            }
        }
    }

    let root_name = root_val
        .as_object()
        .and_then(|o| o.get("title"))
        .and_then(Value::as_str)
        .map(str::to_string);

    let mut fields_out = Vec::new();
    let mut truncated = false;
    let mut active_refs = HashSet::new();

    walk_json_schema_node(
        &root_val,
        "",
        &docs,
        &[],
        0,
        &mut active_refs,
        &mut fields_out,
        &mut truncated,
    );

    SchemaFieldModel {
        kind: SchemaKind::Json,
        root_name,
        messages: Vec::new(),
        fields: fields_out,
        truncated,
        unavailable_reason: None,
    }
}

#[allow(clippy::too_many_arguments)]
fn walk_json_schema_node(
    node: &Value,
    doc_key: &str,
    docs: &HashMap<String, Value>,
    prefix: &[String],
    depth: usize,
    active_refs: &mut HashSet<String>,
    out: &mut Vec<SchemaFieldEntry>,
    truncated: &mut bool,
) {
    if depth > MAX_DEPTH {
        *truncated = true;
        return;
    }
    let Some(obj) = node.as_object() else {
        return;
    };

    if let Some(ref_str) = obj.get("$ref").and_then(Value::as_str) {
        if let Some((target_doc_key, target_val, cycle_key)) =
            resolve_json_ref(ref_str, doc_key, docs)
        {
            if active_refs.insert(cycle_key.clone()) {
                walk_json_schema_node(
                    target_val,
                    target_doc_key,
                    docs,
                    prefix,
                    depth,
                    active_refs,
                    out,
                    truncated,
                );
                active_refs.remove(&cycle_key);
            }
        }
        return;
    }

    for combiner in ["allOf", "anyOf", "oneOf"] {
        if let Some(arr) = obj.get(combiner).and_then(Value::as_array) {
            for sub in arr {
                walk_json_schema_node(
                    sub,
                    doc_key,
                    docs,
                    prefix,
                    depth,
                    active_refs,
                    out,
                    truncated,
                );
            }
        }
    }

    let required: HashSet<&str> = obj
        .get("required")
        .and_then(Value::as_array)
        .map(|arr| arr.iter().filter_map(Value::as_str).collect())
        .unwrap_or_default();

    let Some(props) = obj.get("properties").and_then(Value::as_object) else {
        return;
    };

    for (prop_name, prop_schema) in props {
        if out.len() >= MAX_ENTRIES {
            *truncated = true;
            return;
        }
        let mut next_segments = prefix.to_vec();
        next_segments.push(prop_name.clone());
        let path = build_canonical_path(&next_segments);

        let mut note = None;
        let mut active_key_for_prop: Option<String> = None;
        let mut resolved_doc = doc_key;
        let mut resolved_schema = prop_schema;

        if let Some(ref_str) = prop_schema.get("$ref").and_then(Value::as_str) {
            match resolve_json_ref(ref_str, doc_key, docs) {
                Some((tdoc, tval, ckey)) => {
                    if active_refs.contains(&ckey) {
                        note = Some(FieldNote::Recursive);
                    } else {
                        resolved_doc = tdoc;
                        resolved_schema = tval;
                        active_key_for_prop = Some(ckey);
                    }
                }
                None => {
                    note = Some(FieldNote::UnresolvedReference(ref_str.to_string()));
                }
            }
        }

        let (type_label, type_allows_null, is_array) = json_schema_type_summary(resolved_schema);
        let optional =
            type_allows_null || (!required.is_empty() && !required.contains(prop_name.as_str()));
        let doc = prop_schema
            .get("description")
            .or_else(|| resolved_schema.get("description"))
            .and_then(Value::as_str)
            .map(str::to_string);

        out.push(SchemaFieldEntry {
            path,
            name: prop_name.clone(),
            depth: depth as u32,
            type_label,
            doc,
            optional,
            repeated: is_array,
            note: note.clone(),
        });

        if note.is_some() {
            continue;
        }

        let expand_target = if is_array {
            resolved_schema.get("items").unwrap_or(resolved_schema)
        } else {
            resolved_schema
        };

        // Also handle $ref inside `items`
        let mut item_cycle_key: Option<String> = None;
        let mut item_doc = resolved_doc;
        let mut final_target = expand_target;
        if is_array {
            if let Some(item_ref) = expand_target.get("$ref").and_then(Value::as_str) {
                match resolve_json_ref(item_ref, resolved_doc, docs) {
                    Some((tdoc, tval, ckey)) => {
                        if active_refs.contains(&ckey) {
                            if let Some(last) = out.last_mut() {
                                last.note = Some(FieldNote::Recursive);
                            }
                            continue;
                        }
                        item_doc = tdoc;
                        final_target = tval;
                        item_cycle_key = Some(ckey);
                    }
                    None => {
                        if let Some(last) = out.last_mut() {
                            last.note = Some(FieldNote::UnresolvedReference(item_ref.to_string()));
                        }
                        continue;
                    }
                }
            }
        }

        if has_json_expandable_children(final_target) {
            if depth + 1 > MAX_DEPTH {
                *truncated = true;
                continue;
            }
            if let Some(k) = &active_key_for_prop {
                active_refs.insert(k.clone());
            }
            if let Some(k) = &item_cycle_key {
                active_refs.insert(k.clone());
            }

            walk_json_schema_node(
                final_target,
                item_doc,
                docs,
                &next_segments,
                depth + 1,
                active_refs,
                out,
                truncated,
            );

            if let Some(k) = &item_cycle_key {
                active_refs.remove(k);
            }
            if let Some(k) = &active_key_for_prop {
                active_refs.remove(k);
            }
        }
    }
}

fn has_json_expandable_children(node: &Value) -> bool {
    let Some(obj) = node.as_object() else {
        return false;
    };
    obj.contains_key("properties")
        || obj.contains_key("$ref")
        || obj.contains_key("allOf")
        || obj.contains_key("anyOf")
        || obj.contains_key("oneOf")
}

fn resolve_json_ref<'a>(
    ref_str: &str,
    current_doc_key: &'a str,
    docs: &'a HashMap<String, Value>,
) -> Option<(&'a str, &'a Value, String)> {
    let (doc_part, ptr_part) = match ref_str.split_once('#') {
        Some((d, p)) => (d, p),
        None => (ref_str, ""),
    };

    let (target_key, doc_root): (&str, &Value) = if doc_part.is_empty() {
        (current_doc_key, docs.get(current_doc_key)?)
    } else {
        let (k, v) = docs.get_key_value(doc_part)?;
        (k.as_str(), v)
    };

    let target_val = if ptr_part.is_empty() || ptr_part == "/" {
        doc_root
    } else {
        let ptr = if ptr_part.starts_with('/') {
            ptr_part.to_string()
        } else {
            format!("/{ptr_part}")
        };
        doc_root.pointer(&ptr)?
    };

    let cycle_key = format!("{target_key}#{ptr_part}");
    Some((target_key, target_val, cycle_key))
}

fn json_schema_type_summary(schema: &Value) -> (String, bool, bool) {
    let Some(obj) = schema.as_object() else {
        return ("any".to_string(), false, false);
    };

    if let Some(ty) = obj.get("type") {
        match ty {
            Value::String(s) => {
                if s == "array" {
                    let item_label = obj
                        .get("items")
                        .map(|i| json_schema_type_summary(i).0)
                        .unwrap_or_else(|| "any".to_string());
                    return (format!("array<{item_label}>"), false, true);
                }
                return (s.clone(), s == "null", false);
            }
            Value::Array(arr) => {
                let mut types = Vec::new();
                let mut allows_null = false;
                let mut is_array = false;
                for item in arr {
                    if let Some(s) = item.as_str() {
                        if s == "null" {
                            allows_null = true;
                        } else {
                            if s == "array" {
                                is_array = true;
                            }
                            types.push(s.to_string());
                        }
                    }
                }
                let label = if types.is_empty() {
                    "null".to_string()
                } else {
                    types.join(" | ")
                };
                return (label, allows_null, is_array);
            }
            _ => {}
        }
    }

    if obj.contains_key("properties") {
        return ("object".to_string(), false, false);
    }
    if let Some(ref_str) = obj.get("$ref").and_then(Value::as_str) {
        let short = ref_str.rsplit('/').next().unwrap_or(ref_str);
        return (short.to_string(), false, false);
    }
    for combiner in ["oneOf", "anyOf", "allOf"] {
        if let Some(arr) = obj.get(combiner).and_then(Value::as_array) {
            let mut allows_null = false;
            let mut labels = Vec::new();
            for sub in arr {
                let (lbl, sub_null, _) = json_schema_type_summary(sub);
                if sub_null && lbl == "null" {
                    allows_null = true;
                } else {
                    labels.push(lbl);
                }
            }
            if !labels.is_empty() {
                return (labels.join(" | "), allows_null, false);
            }
        }
    }
    ("any".to_string(), false, false)
}

// ---------------------------------------------------------------------------
// Protobuf walker
// ---------------------------------------------------------------------------

/// Extracts a `SchemaFieldModel` for Protobuf from one or more `.proto` source strings,
/// optionally targeting a specific `message_name` (defaults to the first top-level message).
pub fn extract_protobuf_fields_from_sources(
    sources: &[String],
    message_name: Option<&str>,
) -> SchemaFieldModel {
    let mut messages = Vec::new();
    for src in sources {
        for m in scan_top_level_proto_messages(src) {
            if !messages.contains(&m) {
                messages.push(m);
            }
        }
    }
    let target_name = message_name
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(ToOwned::to_owned)
        .or_else(|| messages.first().cloned());

    let parse_sources: Vec<String> = sources.iter().map(|s| rewrite_proto_maps(s).0).collect();

    let parse_attempt = catch_unwind(AssertUnwindSafe(|| ProtoContext::parse(&parse_sources)));
    let ctx = match parse_attempt {
        Ok(Ok(ctx)) => ctx,
        Ok(Err(err)) => {
            return SchemaFieldModel {
                kind: SchemaKind::Protobuf,
                root_name: target_name,
                messages,
                fields: Vec::new(),
                truncated: false,
                unavailable_reason: Some(format!("Protobuf parse error: {err}")),
            };
        }
        Err(_) => {
            return SchemaFieldModel {
                kind: SchemaKind::Protobuf,
                root_name: target_name,
                messages,
                fields: Vec::new(),
                truncated: false,
                unavailable_reason: Some(
                    "Protobuf parser failed on unsupported syntax".to_string(),
                ),
            };
        }
    };

    let Some(first_msg_name) = target_name.as_deref() else {
        return SchemaFieldModel {
            kind: SchemaKind::Protobuf,
            root_name: None,
            messages,
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some("Protobuf schema contains no top-level message".to_string()),
        };
    };

    let Some(root_msg) = ctx.get_message(first_msg_name) else {
        let reason = format!("Protobuf message '{first_msg_name}' could not be resolved");
        return SchemaFieldModel {
            kind: SchemaKind::Protobuf,
            root_name: target_name,
            messages,
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some(reason),
        };
    };

    let mut fields_out = Vec::new();
    let mut truncated = false;
    let mut active_msgs = HashSet::new();
    active_msgs.insert(root_msg.full_name.clone());

    walk_proto_message(
        &ctx,
        root_msg,
        &[],
        1,
        &mut active_msgs,
        &mut fields_out,
        &mut truncated,
    );

    SchemaFieldModel {
        kind: SchemaKind::Protobuf,
        root_name: Some(root_msg.full_name.clone()),
        messages,
        fields: fields_out,
        truncated,
        unavailable_reason: None,
    }
}

fn build_protobuf_fields(schema_text: &str, refs: &[ResolvedReference]) -> SchemaFieldModel {
    let messages = scan_top_level_proto_messages(schema_text);
    let root_name = messages.first().cloned();

    let (rewritten_main, _) = rewrite_proto_maps(schema_text);
    let mut sources = Vec::new();
    for r in refs {
        if r.kind == SchemaKind::Protobuf {
            let (rewritten_ref, _) = rewrite_proto_maps(&r.schema);
            sources.push(rewritten_ref);
        }
    }
    sources.push(rewritten_main);

    let parse_attempt = catch_unwind(AssertUnwindSafe(|| ProtoContext::parse(&sources)));
    let ctx = match parse_attempt {
        Ok(Ok(ctx)) => ctx,
        Ok(Err(err)) => {
            return SchemaFieldModel {
                kind: SchemaKind::Protobuf,
                root_name,
                messages,
                fields: Vec::new(),
                truncated: false,
                unavailable_reason: Some(format!("Protobuf parse error: {err}")),
            };
        }
        Err(_) => {
            return SchemaFieldModel {
                kind: SchemaKind::Protobuf,
                root_name,
                messages,
                fields: Vec::new(),
                truncated: false,
                unavailable_reason: Some(
                    "Protobuf parser failed on unsupported syntax".to_string(),
                ),
            };
        }
    };

    let Some(first_msg_name) = root_name.as_deref() else {
        return SchemaFieldModel {
            kind: SchemaKind::Protobuf,
            root_name: None,
            messages,
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some("Protobuf schema contains no top-level message".to_string()),
        };
    };

    let Some(root_msg) = ctx.get_message(first_msg_name) else {
        let reason = format!("Protobuf message '{first_msg_name}' could not be resolved");
        return SchemaFieldModel {
            kind: SchemaKind::Protobuf,
            root_name,
            messages,
            fields: Vec::new(),
            truncated: false,
            unavailable_reason: Some(reason),
        };
    };

    let mut fields_out = Vec::new();
    let mut truncated = false;
    let mut active_msgs = HashSet::new();
    active_msgs.insert(root_msg.full_name.clone());

    walk_proto_message(
        &ctx,
        root_msg,
        &[],
        0,
        &mut active_msgs,
        &mut fields_out,
        &mut truncated,
    );

    SchemaFieldModel {
        kind: SchemaKind::Protobuf,
        root_name,
        messages,
        fields: fields_out,
        truncated,
        unavailable_reason: None,
    }
}

fn walk_proto_message(
    ctx: &ProtoContext,
    msg: &MessageInfo,
    prefix: &[String],
    depth: usize,
    active_msgs: &mut HashSet<String>,
    out: &mut Vec<SchemaFieldEntry>,
    truncated: &mut bool,
) {
    if depth > MAX_DEPTH {
        *truncated = true;
        return;
    }

    for field in msg.iter_fields() {
        if out.len() >= MAX_ENTRIES {
            *truncated = true;
            return;
        }
        let mut next_segments = prefix.to_vec();
        next_segments.push(field.name.clone());
        let path = build_canonical_path(&next_segments);

        let repeated = matches!(
            field.multiplicity,
            Multiplicity::Repeated | Multiplicity::RepeatedPacked
        );
        let optional =
            matches!(field.multiplicity, Multiplicity::Optional) || field.oneof.is_some();

        let (type_label, nested_msg) = match &field.field_type {
            ValueType::Message(msg_ref) => {
                let target = ctx.resolve_message(*msg_ref);
                (target.name.clone(), Some(target))
            }
            ValueType::Enum(enum_ref) => {
                let target = ctx.resolve_enum(*enum_ref);
                (target.name.clone(), None)
            }
            other => (proto_scalar_label(other).to_string(), None),
        };

        let mut note = None;
        if let Some(child) = nested_msg {
            if active_msgs.contains(&child.full_name) {
                note = Some(FieldNote::Recursive);
            }
        }

        out.push(SchemaFieldEntry {
            path,
            name: field.name.clone(),
            depth: depth as u32,
            type_label,
            doc: None,
            optional,
            repeated,
            note: note.clone(),
        });

        if note.is_none() {
            if let Some(child) = nested_msg {
                if depth + 1 > MAX_DEPTH {
                    *truncated = true;
                } else if active_msgs.insert(child.full_name.clone()) {
                    walk_proto_message(
                        ctx,
                        child,
                        &next_segments,
                        depth + 1,
                        active_msgs,
                        out,
                        truncated,
                    );
                    active_msgs.remove(&child.full_name);
                }
            }
        }
    }
}

fn proto_scalar_label(vt: &ValueType) -> &'static str {
    match vt {
        ValueType::Double => "double",
        ValueType::Float => "float",
        ValueType::Int32 => "int32",
        ValueType::Int64 => "int64",
        ValueType::UInt32 => "uint32",
        ValueType::UInt64 => "uint64",
        ValueType::SInt32 => "sint32",
        ValueType::SInt64 => "sint64",
        ValueType::Fixed32 => "fixed32",
        ValueType::Fixed64 => "fixed64",
        ValueType::SFixed32 => "sfixed32",
        ValueType::SFixed64 => "sfixed64",
        ValueType::Bool => "bool",
        ValueType::String => "string",
        ValueType::Bytes => "bytes",
        ValueType::Message(_) => "message",
        ValueType::Enum(_) => "enum",
    }
}

/// Strips `//` and `/* ... */` comments and string literals, returning `package` + top-level `message` names.
pub fn scan_top_level_proto_messages(source: &str) -> Vec<String> {
    let cleaned = strip_proto_comments_and_strings(source);
    let mut package_name: Option<String> = None;
    let mut messages = Vec::new();
    let mut depth: i32 = 0;

    let bytes = cleaned.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'{' => {
                depth += 1;
                i += 1;
            }
            b'}' => {
                depth = (depth - 1).max(0);
                i += 1;
            }
            _ if depth == 0 && (bytes[i].is_ascii_alphabetic() || bytes[i] == b'_') => {
                let start = i;
                while i < bytes.len()
                    && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'_' || bytes[i] == b'.')
                {
                    i += 1;
                }
                let word = &cleaned[start..i];
                if word == "package" {
                    while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                        i += 1;
                    }
                    let pstart = i;
                    while i < bytes.len() && bytes[i] != b';' && !bytes[i].is_ascii_whitespace() {
                        i += 1;
                    }
                    let pkg = cleaned[pstart..i].trim();
                    if !pkg.is_empty() && package_name.is_none() {
                        package_name = Some(pkg.to_string());
                    }
                } else if word == "message" {
                    while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                        i += 1;
                    }
                    let mstart = i;
                    while i < bytes.len() && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'_')
                    {
                        i += 1;
                    }
                    let mname = cleaned[mstart..i].trim();
                    if !mname.is_empty() {
                        let full = match &package_name {
                            Some(pkg) => format!("{pkg}.{mname}"),
                            None => mname.to_string(),
                        };
                        messages.push(full);
                    }
                }
            }
            _ => {
                i += 1;
            }
        }
    }
    messages
}

pub(crate) fn strip_proto_comments_and_strings(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let chars: Vec<char> = source.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '/' && i + 1 < chars.len() && chars[i + 1] == '/' {
            i += 2;
            while i < chars.len() && chars[i] != '\n' {
                i += 1;
            }
            out.push(' ');
        } else if chars[i] == '/' && i + 1 < chars.len() && chars[i + 1] == '*' {
            i += 2;
            while i + 1 < chars.len() && !(chars[i] == '*' && chars[i + 1] == '/') {
                i += 1;
            }
            i = (i + 2).min(chars.len());
            out.push(' ');
        } else if chars[i] == '"' || chars[i] == '\'' {
            let quote = chars[i];
            i += 1;
            while i < chars.len() {
                if chars[i] == '\\' {
                    i += 2;
                } else if chars[i] == quote {
                    i += 1;
                    break;
                } else {
                    i += 1;
                }
            }
            out.push(' ');
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

/// Rewrites `map<K, V> name = N;` into a repeated synthetic entry message because `protofish` 0.5.3
/// panics with `not implemented: Maps are not supported`.
pub fn rewrite_proto_maps(source: &str) -> (String, bool) {
    let re = Regex::new(
        r"map\s*<\s*([A-Za-z0-9_.]+)\s*,\s*([A-Za-z0-9_.]+)\s*>\s+([A-Za-z0-9_]+)\s*=\s*(\d+)\s*;",
    )
    .expect("valid map regex");
    let mut changed = false;
    let out = re.replace_all(source, |caps: &regex::Captures| {
        changed = true;
        let k = &caps[1];
        let v = &caps[2];
        let name = &caps[3];
        let num = &caps[4];
        format!("message __MapEntry_{name} {{ {k} key = 1; {v} value = 2; }} repeated __MapEntry_{name} {name} = {num};")
    });
    (out.into_owned(), changed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_subject_schema_handles_avro_protobuf_json_other_references_and_malformed() {
        let avro = json!({
            "subject": "orders-value",
            "version": 1,
            "id": 10,
            "schema": "{\"type\":\"record\",\"name\":\"Order\",\"fields\":[]}"
        });
        let parsed_avro = parse_subject_schema(&avro).unwrap();
        assert_eq!(parsed_avro.schema_type, SchemaKind::Avro);
        assert_eq!(parsed_avro.version, 1);
        assert_eq!(parsed_avro.id, 10);
        assert!(parsed_avro.references.is_empty());

        let proto = json!({
            "subject": "orders-value",
            "version": 3,
            "id": 77,
            "schemaType": "PROTOBUF",
            "schema": "syntax = \"proto3\"; message Order { int64 id = 1; }",
            "references": [
                {"name": "customer.proto", "subject": "customer-value", "version": 2}
            ]
        });
        let parsed_proto = parse_subject_schema(&proto).unwrap();
        assert_eq!(parsed_proto.schema_type, SchemaKind::Protobuf);
        assert_eq!(parsed_proto.references.len(), 1);
        assert_eq!(parsed_proto.references[0].name, "customer.proto");
        assert_eq!(parsed_proto.references[0].subject, "customer-value");
        assert_eq!(parsed_proto.references[0].version, 2);

        let json_schema = json!({
            "subject": "events-value",
            "version": 2,
            "id": 42,
            "schemaType": "JSON",
            "schema": "{\"type\":\"object\"}"
        });
        assert_eq!(
            parse_subject_schema(&json_schema).unwrap().schema_type,
            SchemaKind::Json
        );

        let other = json!({
            "subject": "custom-value",
            "version": 1,
            "id": 99,
            "schemaType": "THRIFT",
            "schema": "struct Foo {}"
        });
        assert_eq!(
            parse_subject_schema(&other).unwrap().schema_type,
            SchemaKind::Other("THRIFT".to_string())
        );

        let missing_id = json!({
            "subject": "orders-value",
            "version": 1,
            "schema": "{}"
        });
        assert!(parse_subject_schema(&missing_id).is_err());

        let missing_version = json!({
            "subject": "orders-value",
            "id": 1,
            "schema": "{}"
        });
        assert!(parse_subject_schema(&missing_version).is_err());
    }

    #[test]
    fn parse_compatibility_level_accepts_both_field_names() {
        assert_eq!(
            parse_compatibility_level(&json!({"compatibilityLevel": "BACKWARD"})).unwrap(),
            "BACKWARD"
        );
        assert_eq!(
            parse_compatibility_level(&json!({"compatibility": "FULL_TRANSITIVE"})).unwrap(),
            "FULL_TRANSITIVE"
        );
        assert!(parse_compatibility_level(&json!({})).is_err());
    }

    #[test]
    fn avro_walker_handles_ported_cases_references_recursion_and_limits() {
        // Ported from Dart parseSchemaFields: invalid JSON and empty {}
        let invalid = schema_fields(SchemaKind::Avro, "invalid json", &[]);
        assert!(invalid.unavailable_reason.is_some());
        assert!(invalid.fields.is_empty());

        let empty_obj = schema_fields(SchemaKind::Avro, "{}", &[]);
        assert!(empty_obj.unavailable_reason.is_none());
        assert!(empty_obj.fields.is_empty());

        // Basic fields + optional union + array of record + cross-reference named type
        let customer_ref = ResolvedReference {
            name: "customer.avsc".to_string(),
            kind: SchemaKind::Avro,
            schema: r#"{"type":"record","name":"Customer","namespace":"acme","fields":[{"name":"name","type":"string"}]}"#.to_string(),
        };
        let order_schema = r#"{
            "type": "record",
            "name": "Order",
            "namespace": "acme",
            "fields": [
                {"name": "id", "type": "long", "doc": "Order ID"},
                {"name": "customer", "type": ["null", "acme.Customer"]},
                {"name": "tags", "type": {"type": "array", "items": "string"}}
            ]
        }"#;
        let model = schema_fields(SchemaKind::Avro, order_schema, &[customer_ref]);
        assert_eq!(model.root_name.as_deref(), Some("Order"));
        let paths: Vec<_> = model.fields.iter().map(|f| f.path.as_str()).collect();
        assert_eq!(paths, vec!["id", "customer", "customer.name", "tags"]);
        assert!(model.fields[1].optional);
        assert!(model.fields[3].repeated);
        assert_eq!(model.fields[0].doc.as_deref(), Some("Order ID"));

        // Recursive Avro record
        let recursive = r#"{
            "type": "record",
            "name": "Node",
            "fields": [
                {"name": "value", "type": "string"},
                {"name": "children", "type": {"type": "array", "items": "Node"}}
            ]
        }"#;
        let rec_model = schema_fields(SchemaKind::Avro, recursive, &[]);
        assert_eq!(rec_model.fields.len(), 2);
        assert_eq!(rec_model.fields[1].path, "children");
        assert_eq!(rec_model.fields[1].note, Some(FieldNote::Recursive));
    }

    #[test]
    fn json_schema_walker_handles_nested_refs_cycles_allof_and_json_pointer_paths() {
        let customer_ref = ResolvedReference {
            name: "customer.json".to_string(),
            kind: SchemaKind::Json,
            schema: r#"{
                "type": "object",
                "properties": {
                    "name": {"type": "string"}
                }
            }"#
            .to_string(),
        };
        let main_schema = r##"{
            "title": "Order",
            "type": "object",
            "required": ["id"],
            "properties": {
                "id": {"type": "integer"},
                "customer": {"$ref": "customer.json"},
                "a.b": {"type": "string"},
                "missing": {"$ref": "unknown.json"},
                "selfRef": {"$ref": "#/$defs/Node"}
            },
            "allOf": [
                {
                    "properties": {
                        "extra": {"type": ["string", "null"]}
                    }
                }
            ],
            "$defs": {
                "Node": {
                    "type": "object",
                    "properties": {
                        "next": {"$ref": "#/$defs/Node"}
                    }
                }
            }
        }"##;
        let model = schema_fields(SchemaKind::Json, main_schema, &[customer_ref]);
        assert_eq!(model.root_name.as_deref(), Some("Order"));
        assert!(model.unavailable_reason.is_none());

        let by_name = |n: &str| model.fields.iter().find(|f| f.name == n).unwrap();
        assert_eq!(by_name("id").path, "id");
        assert!(!by_name("id").optional);
        assert_eq!(by_name("customer").path, "customer");
        assert_eq!(by_name("name").path, "customer.name");
        assert_eq!(by_name("a.b").path, "/a.b");
        assert_eq!(
            by_name("missing").note,
            Some(FieldNote::UnresolvedReference("unknown.json".to_string()))
        );
        assert_eq!(by_name("next").note, Some(FieldNote::Recursive));
        assert!(by_name("extra").optional);
    }

    #[test]
    fn proto_walker_handles_references_repeated_maps_enums_and_proto2_failure() {
        let customer_proto = r#"
            syntax = "proto3";
            package acme;
            message Customer {
                string name = 1;
            }
        "#;
        let order_proto = r#"
            syntax = "proto3";
            package acme;
            import "customer.proto";
            enum Status {
                STATUS_UNSPECIFIED = 0;
                STATUS_OK = 1;
            }
            message Order {
                message Line {
                    string sku = 1;
                }
                int64 id = 1;
                Customer customer = 2;
                repeated Line lines = 3;
                map<string, int32> counts = 4;
                Status status = 5;
                oneof payment {
                    string card = 6;
                }
            }
            message Secondary {
                string note = 1;
            }
        "#;

        let model = schema_fields(
            SchemaKind::Protobuf,
            order_proto,
            &[ResolvedReference {
                name: "customer.proto".to_string(),
                kind: SchemaKind::Protobuf,
                schema: customer_proto.to_string(),
            }],
        );
        assert!(
            model.unavailable_reason.is_none(),
            "{:?}",
            model.unavailable_reason
        );
        assert_eq!(model.root_name.as_deref(), Some("acme.Order"));
        assert_eq!(model.messages, vec!["acme.Order", "acme.Secondary"]);

        let paths: Vec<_> = model.fields.iter().map(|f| f.path.as_str()).collect();
        assert!(paths.contains(&"id"));
        assert!(paths.contains(&"customer.name"));
        assert!(paths.contains(&"lines.sku"));
        assert!(paths.contains(&"counts.key"));
        assert!(paths.contains(&"counts.value"));
        assert!(paths.contains(&"status"));
        assert!(paths.contains(&"card"));

        let lines = model.fields.iter().find(|f| f.path == "lines").unwrap();
        assert!(lines.repeated);

        // proto2 yields unavailable_reason without panic
        let proto2 = r#"syntax = "proto2"; message Legacy { required int32 id = 1; }"#;
        let proto2_model = schema_fields(SchemaKind::Protobuf, proto2, &[]);
        assert!(proto2_model.unavailable_reason.is_some());
        assert!(proto2_model.fields.is_empty());
    }

    #[test]
    fn spike_s2_protofish_capabilities() {
        let customer_proto = r#"
            syntax = "proto3";
            package acme;
            message Customer {
                string name = 1;
            }
        "#;
        let order_no_map = r#"
            syntax = "proto3";
            package acme;
            import "customer.proto";
            enum Status {
                STATUS_UNSPECIFIED = 0;
                STATUS_OK = 1;
            }
            message Order {
                message Line {
                    string sku = 1;
                }
                int64 id = 1;
                Customer customer = 2;
                repeated Line lines = 3;
                Status status = 5;
                oneof payment {
                    string card = 6;
                    string cash = 7;
                }
            }
        "#;
        let ctx = protofish::context::Context::parse([customer_proto, order_no_map])
            .expect("proto3 with reference should parse");
        let order = ctx.get_message("acme.Order").expect("acme.Order found");
        let field_names: Vec<_> = order.iter_fields().map(|f| f.name.as_str()).collect();
        assert!(field_names.contains(&"lines"));
        assert!(field_names.contains(&"card"));

        let with_map = r#"
            syntax = "proto3";
            message WithMap { map<string, int32> counts = 1; }
        "#;
        let map_res = std::panic::catch_unwind(|| protofish::context::Context::parse([with_map]));
        assert!(map_res.is_err(), "protofish 0.5.3 panics on map<>");

        let proto2 = r#"syntax = "proto2"; message Legacy { required int32 id = 1; }"#;
        assert!(protofish::context::Context::parse([proto2]).is_err());

        let wkt = r#"
            syntax = "proto3";
            import "google/protobuf/timestamp.proto";
            message Event { google.protobuf.Timestamp at = 1; }
        "#;
        assert!(protofish::context::Context::parse([wkt]).is_err());
    }

    #[test]
    fn associate_subjects_covers_key_value_none_missing_and_empty_topics() {
        let subjects = vec![
            "orders-value".to_string(),
            "orders-key".to_string(),
            "com.acme.Customer".to_string(),
            "legacy-value".to_string(),
        ];
        let topics = vec!["orders".to_string()];
        let res = associate_subjects(&subjects, &topics);
        assert_eq!(res.len(), 4);

        assert_eq!(res[0].topic.as_deref(), Some("orders"));
        assert_eq!(res[0].side, TopicSide::Value);
        assert!(res[0].on_cluster);

        assert_eq!(res[1].topic.as_deref(), Some("orders"));
        assert_eq!(res[1].side, TopicSide::Key);
        assert!(res[1].on_cluster);

        assert_eq!(res[2].topic, None);
        assert_eq!(res[2].side, TopicSide::None);
        assert!(!res[2].on_cluster);

        assert_eq!(res[3].topic.as_deref(), Some("legacy"));
        assert_eq!(res[3].side, TopicSide::Value);
        assert!(!res[3].on_cluster);

        let empty_res = associate_subjects(&subjects, &[]);
        assert!(empty_res.iter().all(|a| !a.on_cluster));
    }

    #[test]
    fn extract_protobuf_fields_supports_explicit_second_message_name() {
        let proto = r#"
syntax = "proto3";
package acme;

message First {
  string a = 1;
}

message Second {
  int64 b = 1;
  bool c = 2;
}
"#;
        let model = extract_protobuf_fields_from_sources(&[proto.to_string()], Some("acme.Second"));
        assert_eq!(model.root_name.as_deref(), Some("acme.Second"));
        let paths: Vec<&str> = model.fields.iter().map(|f| f.path.as_str()).collect();
        assert_eq!(paths, vec!["b", "c"]);
    }
}
