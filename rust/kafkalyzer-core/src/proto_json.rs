use protofish::context::Context;
use protofish::decode::{MessageValue, Value};

/// Converts a decoded `protofish::decode::MessageValue` into a `serde_json::Value` object.
pub fn convert_protofish_message(msg: &MessageValue, context: &Context) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    let message_info = context.resolve_message(msg.msg_ref);

    for field in &msg.fields {
        let field_name = message_info
            .get_field(field.number)
            .map(|f| f.name.clone())
            .unwrap_or_else(|| format!("field_{}", field.number));

        let json_val = convert_protofish_value(&field.value, context);
        map.insert(field_name, json_val);
    }
    serde_json::Value::Object(map)
}

/// Converts a decoded `protofish::decode::Value` into a `serde_json::Value`.
pub fn convert_protofish_value(val: &Value, context: &Context) -> serde_json::Value {
    match val {
        Value::Double(v) => serde_json::json!(v),
        Value::Float(v) => serde_json::json!(v),
        Value::Int32(v) => serde_json::json!(v),
        Value::Int64(v) => serde_json::json!(v),
        Value::UInt32(v) => serde_json::json!(v),
        Value::UInt64(v) => serde_json::json!(v),
        Value::SInt32(v) => serde_json::json!(v),
        Value::SInt64(v) => serde_json::json!(v),
        Value::Fixed32(v) => serde_json::json!(v),
        Value::Fixed64(v) => serde_json::json!(v),
        Value::SFixed32(v) => serde_json::json!(v),
        Value::SFixed64(v) => serde_json::json!(v),
        Value::Bool(v) => serde_json::json!(v),
        Value::String(v) => serde_json::Value::String(v.clone()),
        Value::Bytes(v) => serde_json::Value::String(format!("0x{}", hex::encode(v))),
        Value::Message(msg) => convert_protofish_message(msg, context),
        Value::Enum(ev) => {
            let enum_info = context.resolve_enum(ev.enum_ref);
            let name = enum_info
                .get_field_by_value(ev.value)
                .map(|f| f.name.clone())
                .unwrap_or_else(|| ev.value.to_string());
            serde_json::Value::String(name)
        }
        Value::Packed(arr) => {
            use protofish::decode::PackedArray;
            match arr {
                PackedArray::Double(v) => serde_json::json!(v),
                PackedArray::Float(v) => serde_json::json!(v),
                PackedArray::Int32(v) => serde_json::json!(v),
                PackedArray::Int64(v) => serde_json::json!(v),
                PackedArray::UInt32(v) => serde_json::json!(v),
                PackedArray::UInt64(v) => serde_json::json!(v),
                PackedArray::SInt32(v) => serde_json::json!(v),
                PackedArray::SInt64(v) => serde_json::json!(v),
                PackedArray::Fixed32(v) => serde_json::json!(v),
                PackedArray::Fixed64(v) => serde_json::json!(v),
                PackedArray::SFixed32(v) => serde_json::json!(v),
                PackedArray::SFixed64(v) => serde_json::json!(v),
                PackedArray::Bool(v) => serde_json::json!(v),
            }
        }
        Value::Incomplete(_, bytes) => {
            serde_json::Value::String(format!("Incomplete: 0x{}", hex::encode(bytes)))
        }
        Value::Unknown(uk) => {
            use protofish::decode::UnknownValue;
            match uk {
                UnknownValue::Varint(v) => serde_json::json!(v.to_string()),
                UnknownValue::Fixed64(v) => serde_json::json!(v),
                UnknownValue::VariableLength(v) => {
                    serde_json::Value::String(format!("0x{}", hex::encode(v)))
                }
                UnknownValue::Fixed32(v) => serde_json::json!(v),
                UnknownValue::Invalid(_, bytes) => {
                    serde_json::Value::String(format!("Invalid: 0x{}", hex::encode(bytes)))
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pins_json_for_scalars_repeated_packed_nested_enum_and_unknown_fields() {
        let proto = r#"
syntax = "proto3";
package test;

enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
}

message Child {
  string label = 1;
}

message Sample {
  string name = 1;
  int32 count = 2;
  bool flag = 3;
  repeated int32 nums = 4;
  Child child = 5;
  Status status = 6;
  repeated string tags = 7;
}
"#;
        let ctx = Context::parse([proto]).unwrap();
        let msg_ref = ctx.get_message("test.Sample").unwrap().self_ref;

        // Wire bytes:
        // 1: "abc" -> 0x0a 0x03 'a' 'b' 'c'
        // 2: 42 -> 0x10 0x2a
        // 3: true -> 0x18 0x01
        // 4 (packed): [10, 20] -> 0x22 0x02 0x0a 0x14
        // 5 (nested Child{label: "sub"}): 0x2a 0x05 0x0a 0x03 's' 'u' 'b'
        // 6 (enum ACTIVE=1): 0x30 0x01
        // 7 (repeated string): "t1" -> 0x3a 0x02 't' '1'
        // 99 (unknown varint 7): (99<<3)|0 = 792 -> varint [0x98, 0x06], value 0x07
        let wire: &[u8] = &[
            0x0a, 0x03, b'a', b'b', b'c', // field 1
            0x10, 0x2a, // field 2
            0x18, 0x01, // field 3
            0x22, 0x02, 0x0a, 0x14, // field 4 packed
            0x2a, 0x05, 0x0a, 0x03, b's', b'u', b'b', // field 5 nested
            0x30, 0x01, // field 6 enum
            0x3a, 0x02, b't', b'1', // field 7 repeated
            0x98, 0x06, 0x07, // field 99 unknown
        ];

        let decoded = ctx.decode(msg_ref, wire);
        let json = convert_protofish_message(&decoded, &ctx);

        assert_eq!(json["name"], "abc");
        assert_eq!(json["count"], 42);
        assert_eq!(json["flag"], true);
        assert_eq!(json["nums"], serde_json::json!([10, 20]));
        assert_eq!(json["child"], serde_json::json!({"label": "sub"}));
        assert_eq!(json["status"], "ACTIVE");
        assert_eq!(json["tags"], "t1");
        assert_eq!(json["field_99"], "7");
    }
}
