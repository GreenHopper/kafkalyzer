//! Schema provenance helpers: reading the registry schema id from the
//! Confluent wire format.
//!
//! A Schema Registry encoded message starts with the magic byte `0x00` followed
//! by a big-endian `u32` schema id. Everything else (plain JSON, text, binary)
//! carries no id, so provenance stays unresolved for those messages.

/// Returns the schema id from a Schema Registry wire-format payload.
pub fn wire_schema_id(bytes: &[u8]) -> Option<u32> {
    if bytes.len() >= 5 && bytes[0] == 0 {
        Some(u32::from_be_bytes([bytes[1], bytes[2], bytes[3], bytes[4]]))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::wire_schema_id;

    /// Captured Confluent wire-format payload: magic byte, id 42, then an Avro
    /// record body (zig-zag encoded "1").
    const CONFLUENT_AVRO_ID_42: &[u8] = &[0x00, 0x00, 0x00, 0x00, 0x2a, 0x02, 0x00];

    #[test]
    fn wire_format_payload_yields_the_schema_id() {
        assert_eq!(wire_schema_id(CONFLUENT_AVRO_ID_42), Some(42));
    }

    #[test]
    fn plain_json_payload_has_no_schema_id() {
        assert_eq!(wire_schema_id(br#"{"id": 7}"#), None);
    }

    #[test]
    fn payload_shorter_than_the_header_has_no_schema_id() {
        assert_eq!(wire_schema_id(&[0x00, 0x00, 0x00]), None);
    }

    #[test]
    fn ids_above_the_magic_byte_range_survive() {
        let payload = [0x00, 0x00, 0x01, 0x00, 0x00, 0x02];
        assert_eq!(wire_schema_id(&payload), Some(65536));
    }
}
