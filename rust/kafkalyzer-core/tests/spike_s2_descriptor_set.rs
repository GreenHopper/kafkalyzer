use protofish::context::Context as ProtoContext;
use protofish::decode::{MessageValue, Value};
use std::collections::HashMap;

const DESCRIPTOR_PROTO_SUBSET: &str = r#"
syntax = "proto3";
package google.protobuf;

message FileDescriptorSet {
  repeated FileDescriptorProto file = 1;
}

message FileDescriptorProto {
  string name = 1;
  string package = 2;
  repeated string dependency = 3;
  repeated DescriptorProto message_type = 4;
  repeated EnumDescriptorProto enum_type = 5;
  repeated FieldDescriptorProto extension = 7;
  string syntax = 12;
}

message DescriptorProto {
  string name = 1;
  repeated FieldDescriptorProto field = 2;
  repeated DescriptorProto nested_type = 3;
  repeated EnumDescriptorProto enum_type = 4;
  repeated FieldDescriptorProto extension = 6;
  MessageOptions options = 7;
  repeated OneofDescriptorProto oneof_decl = 8;
}

message MessageOptions {
  bool map_entry = 7;
}

message OneofDescriptorProto {
  string name = 1;
}

message FieldDescriptorProto {
  enum Type {
    TYPE_UNKNOWN = 0;
    TYPE_DOUBLE = 1;
    TYPE_FLOAT = 2;
    TYPE_INT64 = 3;
    TYPE_UINT64 = 4;
    TYPE_INT32 = 5;
    TYPE_FIXED64 = 6;
    TYPE_FIXED32 = 7;
    TYPE_BOOL = 8;
    TYPE_STRING = 9;
    TYPE_GROUP = 10;
    TYPE_MESSAGE = 11;
    TYPE_BYTES = 12;
    TYPE_UINT32 = 13;
    TYPE_ENUM = 14;
    TYPE_SFIXED32 = 15;
    TYPE_SFIXED64 = 16;
    TYPE_SINT32 = 17;
    TYPE_SINT64 = 18;
  }
  enum Label {
    LABEL_UNKNOWN = 0;
    LABEL_OPTIONAL = 1;
    LABEL_REQUIRED = 2;
    LABEL_REPEATED = 3;
  }
  string name = 1;
  string extendee = 2;
  int32 number = 3;
  Label label = 4;
  Type type = 5;
  string type_name = 6;
  string default_value = 7;
  int32 oneof_index = 9;
  bool proto3_optional = 17;
}

message EnumDescriptorProto {
  string name = 1;
  repeated EnumValueDescriptorProto value = 2;
}

message EnumValueDescriptorProto {
  string name = 1;
  int32 number = 2;
}
"#;

fn get_str(msg: &MessageValue, num: u64) -> Option<&str> {
    msg.fields
        .iter()
        .find(|f| f.number == num)
        .and_then(|f| match &f.value {
            Value::String(s) => Some(s.as_str()),
            _ => None,
        })
}

fn get_int(msg: &MessageValue, num: u64) -> Option<i64> {
    msg.fields
        .iter()
        .find(|f| f.number == num)
        .and_then(|f| match &f.value {
            Value::Int32(v) => Some(i64::from(*v)),
            Value::Int64(v) => Some(*v),
            Value::Enum(e) => Some(e.value),
            _ => None,
        })
}

fn get_bool(msg: &MessageValue, num: u64) -> bool {
    msg.fields
        .iter()
        .any(|f| f.number == num && matches!(f.value, Value::Bool(true)))
}

fn get_msgs(msg: &MessageValue, num: u64) -> Vec<&MessageValue> {
    msg.fields
        .iter()
        .filter(|f| f.number == num)
        .filter_map(|f| match &f.value {
            Value::Message(m) => Some(m.as_ref()),
            _ => None,
        })
        .collect()
}

fn scalar_type_name(t: i64) -> Option<&'static str> {
    Some(match t {
        1 => "double",
        2 => "float",
        3 => "int64",
        4 => "uint64",
        5 => "int32",
        6 => "fixed64",
        7 => "fixed32",
        8 => "bool",
        9 => "string",
        12 => "bytes",
        13 => "uint32",
        15 => "sfixed32",
        16 => "sfixed64",
        17 => "sint32",
        18 => "sint64",
        _ => return None,
    })
}

fn field_type_str(f: &MessageValue) -> Result<String, String> {
    let ftype = get_int(f, 5).unwrap_or(0);
    if ftype == 10 {
        let name = get_str(f, 1).unwrap_or("<unknown>");
        return Err(format!("Unsupported proto2 group field '{name}'"));
    }
    if let Some(scalar) = scalar_type_name(ftype) {
        return Ok(scalar.to_string());
    }
    if ftype == 11 || ftype == 14 {
        let tn = get_str(f, 6).unwrap_or("");
        return Ok(tn.trim_start_matches('.').to_string());
    }
    Err(format!("Unsupported field type id {ftype}"))
}

fn emit_enum(e: &MessageValue, indent: &str, out: &mut String) {
    let name = get_str(e, 1).unwrap_or("UnknownEnum");
    out.push_str(&format!("{indent}enum {name} {{\n"));
    for v in get_msgs(e, 2) {
        let vn = get_str(v, 1).unwrap_or("UNKNOWN");
        let vnum = get_int(v, 2).unwrap_or(0);
        out.push_str(&format!("{indent}  {vn} = {vnum};\n"));
    }
    out.push_str(&format!("{indent}}}\n"));
}

fn is_map_entry(msg: &MessageValue) -> Option<(String, String)> {
    let opts = get_msgs(msg, 7).into_iter().next()?;
    if !get_bool(opts, 7) {
        return None;
    }
    let fields = get_msgs(msg, 2);
    let key_f = fields.iter().find(|f| get_int(f, 3) == Some(1))?;
    let val_f = fields.iter().find(|f| get_int(f, 3) == Some(2))?;
    let kt = field_type_str(key_f).ok()?;
    let vt = field_type_str(val_f).ok()?;
    Some((kt, vt))
}

fn emit_message(
    msg: &MessageValue,
    scope: &str,
    indent: &str,
    out: &mut String,
) -> Result<(), String> {
    if !get_msgs(msg, 6).is_empty() {
        let name = get_str(msg, 1).unwrap_or("<unknown>");
        return Err(format!("Unsupported extension in message '{name}'"));
    }
    let name = get_str(msg, 1).unwrap_or("UnknownMessage");
    let full_scope = if scope.is_empty() {
        name.to_string()
    } else {
        format!("{scope}.{name}")
    };
    out.push_str(&format!("{indent}message {name} {{\n"));
    let inner_indent = format!("{indent}  ");

    for e in get_msgs(msg, 4) {
        emit_enum(e, &inner_indent, out);
    }

    let mut map_entries: HashMap<String, (String, String)> = HashMap::new();
    for nested in get_msgs(msg, 3) {
        let nname = get_str(nested, 1).unwrap_or("Nested");
        if let Some((kt, vt)) = is_map_entry(nested) {
            map_entries.insert(format!("{full_scope}.{nname}"), (kt, vt));
        } else {
            emit_message(nested, &full_scope, &inner_indent, out)?;
        }
    }

    let oneofs: Vec<String> = get_msgs(msg, 8)
        .into_iter()
        .map(|o| get_str(o, 1).unwrap_or("oneof").to_string())
        .collect();
    let mut oneof_fields: HashMap<usize, Vec<&MessageValue>> = HashMap::new();

    for f in get_msgs(msg, 2) {
        let proto3_opt = get_bool(f, 17);
        if !proto3_opt {
            if let Some(oi) = get_int(f, 9) {
                if let Ok(oi_u) = usize::try_from(oi) {
                    if oi_u < oneofs.len() {
                        oneof_fields.entry(oi_u).or_default().push(f);
                        continue;
                    }
                }
            }
        }
        let fname = get_str(f, 1).unwrap_or("field");
        let fnum = get_int(f, 3).unwrap_or(1);
        let label = get_int(f, 4).unwrap_or(1);
        let ftype_str = field_type_str(f)?;
        if label == 3 {
            if let Some((kt, vt)) = map_entries.get(&ftype_str) {
                out.push_str(&format!(
                    "{inner_indent}map<{kt}, {vt}> {fname} = {fnum};\n"
                ));
                continue;
            }
            out.push_str(&format!(
                "{inner_indent}repeated {ftype_str} {fname} = {fnum};\n"
            ));
        } else {
            out.push_str(&format!("{inner_indent}{ftype_str} {fname} = {fnum};\n"));
        }
    }

    for (oi, oname) in oneofs.iter().enumerate() {
        if let Some(fields) = oneof_fields.get(&oi) {
            out.push_str(&format!("{inner_indent}oneof {oname} {{\n"));
            for f in fields {
                let fname = get_str(f, 1).unwrap_or("field");
                let fnum = get_int(f, 3).unwrap_or(1);
                let ftype_str = field_type_str(f)?;
                out.push_str(&format!("{inner_indent}  {ftype_str} {fname} = {fnum};\n"));
            }
            out.push_str(&format!("{inner_indent}}}\n"));
        }
    }

    out.push_str(&format!("{indent}}}\n"));
    Ok(())
}

fn descriptor_set_to_proto3_sources(bytes: &[u8]) -> Result<Vec<String>, String> {
    let desc_ctx = ProtoContext::parse([DESCRIPTOR_PROTO_SUBSET]).map_err(|e| e.to_string())?;
    let fds_ref = desc_ctx
        .get_message("google.protobuf.FileDescriptorSet")
        .ok_or_else(|| "FileDescriptorSet missing".to_string())?
        .self_ref;
    let fds = desc_ctx.decode(fds_ref, bytes);
    let mut sources = Vec::new();
    for file in get_msgs(&fds, 1) {
        if !get_msgs(file, 7).is_empty() {
            let fname = get_str(file, 1).unwrap_or("<unknown>");
            return Err(format!("Unsupported top-level extensions in '{fname}'"));
        }
        let pkg = get_str(file, 2).unwrap_or("");
        let mut src = String::from("syntax = \"proto3\";\n");
        if !pkg.is_empty() {
            src.push_str(&format!("package {pkg};\n"));
        }
        for e in get_msgs(file, 5) {
            emit_enum(e, "", &mut src);
        }
        for m in get_msgs(file, 4) {
            emit_message(m, pkg, "", &mut src)?;
        }
        sources.push(src);
    }
    Ok(sources)
}

#[test]
fn spike_s2_descriptor_set_option_a() {
    let multi_bytes = include_bytes!("fixtures/orders_multi.desc");
    let sources = descriptor_set_to_proto3_sources(multi_bytes).unwrap();
    assert_eq!(sources.len(), 2);
    assert!(sources[1].contains("map<string, int64> attrs = 3;"));
    assert!(sources[1].contains("oneof extra"));

    let parse_sources: Vec<String> = sources
        .iter()
        .map(|s| kafkalyzer_core::schema_model::rewrite_proto_maps(s).0)
        .collect();
    let ctx = ProtoContext::parse(&parse_sources).unwrap();
    let order = ctx.get_message("acme.orders.Order").unwrap();
    assert!(order.get_field_by_name("total").is_some());
    assert!(order.get_field_by_name("attrs").is_some());
    assert!(ctx.get_message("acme.orders.Order.Line").is_some());
    assert!(ctx.get_message("acme.common.Money").is_some());

    // Proto2 fixture
    let legacy_bytes = include_bytes!("fixtures/legacy_proto2.desc");
    let legacy_sources = descriptor_set_to_proto3_sources(legacy_bytes).unwrap();
    let legacy_ctx = ProtoContext::parse(&legacy_sources).unwrap();
    let legacy_msg = legacy_ctx.get_message("acme.legacy.LegacyEvent").unwrap();
    assert!(legacy_msg.get_field_by_name("event_id").is_some());
    assert!(legacy_msg.get_field_by_name("retries").is_some());
}
