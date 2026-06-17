use apache_avro::types::Value;
use apache_avro::Schema;
use apache_avro::schema::Name;
use serde_json::json;
use num_bigint::BigInt;
use regex::Regex;
use std::collections::HashMap;

pub fn extract_named_schemas<'a>(schema: &'a Schema, map: &mut HashMap<Name, &'a Schema>) {
    match schema {
        Schema::Record(r) => {
            if !map.contains_key(&r.name) {
                map.insert(r.name.clone(), schema);
                for field in &r.fields {
                    extract_named_schemas(&field.schema, map);
                }
            }
        },
        Schema::Enum(e) => {
             if !map.contains_key(&e.name) {
                map.insert(e.name.clone(), schema);
            }
        },
        Schema::Fixed(f) => {
             if !map.contains_key(&f.name) {
                map.insert(f.name.clone(), schema);
            }
        },
        Schema::Array(a) => extract_named_schemas(&a.items, map),
        Schema::Map(m) => extract_named_schemas(&m.types, map),
        Schema::Union(u) => {
            for variant in u.variants() {
                extract_named_schemas(variant, map);
            }
        },
        // Decimal does not have a name itself, but its inner might (Fixed)
        Schema::Decimal(d) => extract_named_schemas(&d.inner, map),
        _ => {}
    }
}

pub fn convert_avro_value(value: &Value, schema: Option<&Schema>, resolved_schemas: &HashMap<Name, &Schema>) -> Result<serde_json::Value, anyhow::Error> {
    // Resolve top-level Ref if present
    let schema = if let Some(Schema::Ref { name }) = schema {
         resolved_schemas.get(name).copied().or(schema)
    } else {
        schema
    };

    match value {
        Value::Null => Ok(serde_json::Value::Null),
        Value::Boolean(b) => Ok(serde_json::Value::Bool(*b)),
        Value::Int(i) => Ok(json!(i)),
        Value::Long(l) => Ok(json!(l)),
        Value::Float(f) => Ok(json!(f)),
        Value::Double(d) => Ok(json!(d)),
        Value::String(s) => Ok(serde_json::Value::String(s.clone())),
        
        // Complex Types
        Value::Bytes(b) => {
             Ok(json!(format!("0x{}", hex::encode(b))))
        },
        Value::Fixed(_, b) => {
             Ok(json!(format!("0x{}", hex::encode(b))))
        },
        Value::Enum(_index, symbol) => {
            Ok(serde_json::Value::String(symbol.clone()))
        },
        Value::Union(index, v) => {
            let sub_schema = if let Some(Schema::Union(union_schema)) = schema {
                 union_schema.variants().get(*index as usize)
            } else {
                None
            };
            convert_avro_value(v, sub_schema, resolved_schemas)
        },
        Value::Array(items) => {
            let item_schema = if let Some(Schema::Array(array_schema)) = schema {
                Some(array_schema.items.as_ref())
            } else {
                None
            };
            let vec: Result<Vec<_>, _> = items.iter().map(|i| convert_avro_value(i, item_schema, resolved_schemas)).collect();
            Ok(serde_json::Value::Array(vec?))
        },
        Value::Map(items) => {
            let value_schema = if let Some(Schema::Map(map_schema)) = schema {
                Some(map_schema.types.as_ref())
            } else {
                None
            };
            let mut map = serde_json::Map::new();
            for (k, v) in items {
                map.insert(k.clone(), convert_avro_value(v, value_schema, resolved_schemas)?);
            }
            Ok(serde_json::Value::Object(map))
        },
        Value::Record(fields) => {
            let mut map = serde_json::Map::new();
            for (k, v) in fields {
                let field_schema = if let Some(Schema::Record(record_schema)) = schema {
                    record_schema.fields.iter().find(|f| f.name == *k).map(|f| &f.schema)
                } else {
                    None
                };
                
                // If field_schema is a Ref, it will be resolved in the recursive call
                // because we added resolution at the top of the function.
                // However, passing it as is is fine.
                map.insert(k.clone(), convert_avro_value(v, field_schema, resolved_schemas)?);
            }
            Ok(serde_json::Value::Object(map))
        },
        
        // Logical Types
        Value::Date(days) => Ok(json!(days)),
        Value::TimeMillis(millis) => Ok(json!(millis)),
        Value::TimeMicros(micros) => Ok(json!(micros)),
        Value::TimestampMillis(ts) => Ok(json!(ts)),
        Value::TimestampMicros(ts) => Ok(json!(ts)),
        // Add missing variants for completeness
        Value::TimestampNanos(ts) => Ok(json!(ts)),
        Value::LocalTimestampMillis(ts) => Ok(json!(ts)),
        Value::LocalTimestampMicros(ts) => Ok(json!(ts)),
        Value::LocalTimestampNanos(ts) => Ok(json!(ts)),
        
        // Handle BigDecimal if present
        Value::BigDecimal(d) => Ok(serde_json::Value::String(d.to_string())),

        Value::Duration(d) => {
             // Duration is 12 bytes: 4 months, 4 days, 4 millis.
             let debug = format!("{:?}", d);
             // Debug format: Duration { months: Months(1), days: Days(2), millis: Millis(3) }
             let re = Regex::new(r"months:\s*\w+\((\d+)\),\s*days:\s*\w+\((\d+)\),\s*millis:\s*\w+\((\d+)\)").unwrap();
             if let Some(caps) = re.captures(&debug) {
                 let months = caps[1].parse::<u32>().unwrap_or(0);
                 let days = caps[2].parse::<u32>().unwrap_or(0);
                 let millis = caps[3].parse::<u32>().unwrap_or(0);
                 Ok(json!({
                     "months": months,
                     "days": days,
                     "millis": millis
                 }))
             } else {
                 Ok(serde_json::Value::String(debug))
             }
        },
        
        Value::Uuid(u) => Ok(serde_json::Value::String(u.to_string())),
        
        Value::Decimal(d) => {
            let scale = if let Some(Schema::Decimal(decimal_schema)) = schema {
                decimal_schema.scale
            } else {
                0
            };

            let big_int = BigInt::from(d.clone());
            let string_val = big_int.to_string();
            
            if scale > 0 {
                let is_negative = string_val.starts_with('-');
                let sign = if is_negative { "-" } else { "" };
                let plain_digits = if is_negative { &string_val[1..] } else { &string_val };
                
                let len = plain_digits.len();
                let scale_usize = scale as usize;
                
                if len > scale_usize {
                    // Insert decimal point
                    let split_idx = len - scale_usize;
                    let (int_part, frac_part) = plain_digits.split_at(split_idx);
                    Ok(json!(format!("{}{}.{}", sign, int_part, frac_part)))
                } else {
                    // Pad with zeros
                    let zeros = "0".repeat(scale_usize - len);
                    Ok(json!(format!("{}0.{}{}", sign, zeros, plain_digits)))
                }
            } else {
                Ok(json!(string_val))
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use apache_avro::{Days, Duration, Millis, Months, Schema, schema::DecimalSchema, schema::Name};

    #[test]
    fn test_primitives() {
        let map = HashMap::new();
        assert_eq!(convert_avro_value(&Value::Null, None, &map).unwrap(), serde_json::Value::Null);
        assert_eq!(convert_avro_value(&Value::Boolean(true), None, &map).unwrap(), json!(true));
        assert_eq!(convert_avro_value(&Value::Int(123), None, &map).unwrap(), json!(123));
        assert_eq!(convert_avro_value(&Value::Long(1234567890123), None, &map).unwrap(), json!(1234567890123u64));
        assert_eq!(convert_avro_value(&Value::String("foo".to_string()), None, &map).unwrap(), json!("foo"));
    }

    #[test]
    fn test_bytes_fixed() {
        let map = HashMap::new();
        let bytes = vec![1, 2, 3];
        assert_eq!(convert_avro_value(&Value::Bytes(bytes.clone()), None, &map).unwrap(), json!("0x010203"));
        assert_eq!(convert_avro_value(&Value::Fixed(3, bytes), None, &map).unwrap(), json!("0x010203"));
    }

    #[test]
    fn test_enum() {
        let map = HashMap::new();
        assert_eq!(convert_avro_value(&Value::Enum(1, "SYMBOL".to_string()), None, &map).unwrap(), json!("SYMBOL"));
    }
    
    #[test]
    fn test_duration() {
        let map = HashMap::new();
        let d = Duration::new(Months::new(1), Days::new(2), Millis::new(3));
        let json = convert_avro_value(&Value::Duration(d), None, &map).unwrap();
        assert_eq!(json, json!({ "months": 1, "days": 2, "millis": 3 }));
    }
    
    #[test]
    fn test_decimal_no_schema() {
        let map = HashMap::new();
        // Construct Decimal manually: 123
        // In 0.17, Decimal::from(bytes) uses BigInt::from_signed_bytes_be
        // 0x7B = 123
        let decimal = Value::Decimal(apache_avro::Decimal::from(vec![0x7B]));
        let json = convert_avro_value(&decimal, None, &map).unwrap();
        assert_eq!(json, json!("123")); 
    }
    
    #[test]
    fn test_decimal_with_schema() {
        let map = HashMap::new();
        // 12345, scale 2 -> 123.45
        // 12345 = 0x3039
        let decimal = Value::Decimal(apache_avro::Decimal::from(vec![0x30, 0x39]));
        let schema = Schema::Decimal(DecimalSchema {
            precision: 10,
            scale: 2,
            inner: Box::new(Schema::Bytes),
        });
        
        let json = convert_avro_value(&decimal, Some(&schema), &map).unwrap();
        assert_eq!(json, json!("123.45"));
    }

    #[test]
    fn test_decimal_with_schema_small_value() {
        let map = HashMap::new();
        // 5, scale 2 -> 0.05
        let decimal = Value::Decimal(apache_avro::Decimal::from(vec![0x05]));
        let schema = Schema::Decimal(DecimalSchema {
            precision: 10,
            scale: 2,
            inner: Box::new(Schema::Bytes),
        });
        
        let json = convert_avro_value(&decimal, Some(&schema), &map).unwrap();
        assert_eq!(json, json!("0.05"));
    }
    
    #[test]
    fn test_decimal_with_schema_negative() {
        let map = HashMap::new();
        // -123: 0xFF85 (two's complement 8-bit? No BigInt uses min bytes)
        // 123 = 0x7B
        // -123 = ...
        // Let's use BigInt proper to be sure what bytes we give
        let val = BigInt::from(-123);
        let bytes = val.to_signed_bytes_be();
        let decimal = Value::Decimal(apache_avro::Decimal::from(bytes));
        
        let schema = Schema::Decimal(DecimalSchema {
            precision: 10,
            scale: 2,
            inner: Box::new(Schema::Bytes),
        });
        // -123, scale 2 -> -1.23
        
        let json = convert_avro_value(&decimal, Some(&schema), &map).unwrap();
        assert_eq!(json, json!("-1.23"));
    }


    #[test]
    fn test_nested() {
        let map = HashMap::new();
        let rec = Value::Record(vec![
            ("id".to_string(), Value::Int(1)),
            ("val".to_string(), Value::String("a".to_string()))
        ]);
        // Schema needed? Test without first
        let json = convert_avro_value(&rec, None, &map).unwrap();
        assert_eq!(json, json!({"id": 1, "val": "a"}));
    }
    
    #[test]
    fn test_nested_with_decimal_in_record() {
        let map = HashMap::new();
        // Record { d: Decimal(12345) } scale 2
        let decimal = Value::Decimal(apache_avro::Decimal::from(vec![0x30, 0x39]));
        let rec = Value::Record(vec![
            ("d".to_string(), decimal)
        ]);
        
        let decimal_schema = Schema::Decimal(DecimalSchema {
             precision: 5,
             scale: 2,
             inner: Box::new(Schema::Bytes)
        });
        
        let record_schema = Schema::Record(apache_avro::schema::RecordSchema {
             name: Name::new("test").unwrap(),
             aliases: None,
             doc: None,
             fields: vec![
                 apache_avro::schema::RecordField {
                     name: "d".to_string(),
                     doc: None,
                     default: None,
                     schema: decimal_schema,
                     order: apache_avro::schema::RecordFieldOrder::Ascending,
                     position: 0,
                     custom_attributes: Default::default(),
                     aliases: None,
                 }
             ],
             lookup: Default::default(),
             attributes: Default::default(),
        });

        let json = convert_avro_value(&rec, Some(&record_schema), &map).unwrap();
        assert_eq!(json, json!({"d": "123.45"}));
    }
    #[test]
    fn test_decimal_ref_resolution() {
        // Define "Money" schema with a decimal field
        let decimal_schema = Schema::Decimal(DecimalSchema {
             precision: 5,
             scale: 2,
             inner: Box::new(Schema::Bytes),
        });
        
        // Define a named record "Money"
        let money_schema = Schema::Record(apache_avro::schema::RecordSchema {
             name: Name::new("Money").unwrap(),
             aliases: None,
             doc: None,
             fields: vec![
                 apache_avro::schema::RecordField {
                     name: "value".to_string(),
                     doc: None,
                     default: None,
                     schema: decimal_schema.clone(),
                     order: apache_avro::schema::RecordFieldOrder::Ascending,
                     position: 0,
                     custom_attributes: Default::default(),
                     aliases: None,
                 }
             ],
             lookup: Default::default(),
             attributes: Default::default(),
        });

        // Populate map with "Money"
        let mut map = HashMap::new();
        // We need the schema to live long enough
        map.insert(Name::new("Money").unwrap(), &money_schema);

        // Define a field that uses "Money" via Ref
        let ref_schema = Schema::Ref { name: Name::new("Money").unwrap() };
        
        // The value is a Record matching "Money" structure: { "value": Decimal(12345) }
        let decimal_val = Value::Decimal(apache_avro::Decimal::from(vec![0x30, 0x39])); // 12345
        let record_val = Value::Record(vec![
            ("value".to_string(), decimal_val)
        ]);
        
        // Convert using the Ref schema
        let json = convert_avro_value(&record_val, Some(&ref_schema), &map).expect("Should convert ref");
        
        // Should decode to object with formatted decimal: { "value": "123.45" }
        assert_eq!(json, json!({"value": "123.45"}));
    }
}
