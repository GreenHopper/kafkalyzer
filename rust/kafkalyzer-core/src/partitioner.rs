/// Computes the 32-bit murmur2 hash matching Apache Kafka's Java `Utils.murmur2`.
pub fn murmur2(data: &[u8]) -> u32 {
    let length = data.len();
    let seed: u32 = 0x9747b28c;
    let multiplier: u32 = 0x5bd1e995;
    let rotation: i32 = 24;

    let mut hash_value: u32 = seed ^ (length as u32);
    let length4 = length / 4;

    for i in 0..length4 {
        let i4 = i * 4;
        let mut block_value: u32 = (data[i4] as u32)
            + ((data[i4 + 1] as u32) << 8)
            + ((data[i4 + 2] as u32) << 16)
            + ((data[i4 + 3] as u32) << 24);
        block_value = block_value.wrapping_mul(multiplier);
        block_value ^= block_value >> rotation;
        block_value = block_value.wrapping_mul(multiplier);

        hash_value = hash_value.wrapping_mul(multiplier);
        hash_value ^= block_value;
    }

    match length % 4 {
        3 => {
            hash_value ^= (data[(length & !3) + 2] as u32) << 16;
            hash_value ^= (data[(length & !3) + 1] as u32) << 8;
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        2 => {
            hash_value ^= (data[(length & !3) + 1] as u32) << 8;
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        1 => {
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        _ => {}
    }

    hash_value ^= hash_value >> 13;
    hash_value = hash_value.wrapping_mul(multiplier);
    hash_value ^= hash_value >> 15;
    hash_value
}

/// Clears the sign bit, matching Apache Kafka's Java `Utils.toPositive`.
pub fn to_positive(number: u32) -> u32 {
    number & 0x7fffffff
}

/// Predicts the target partition using Kafka's Java default partitioner formula.
///
/// Returns `None` when `partition_count <= 0`.
pub fn default_partition(key: &[u8], partition_count: i32) -> Option<i32> {
    if partition_count <= 0 {
        return None;
    }
    let partition = (to_positive(murmur2(key)) % (partition_count as u32)) as i32;
    Some(partition)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn murmur2_matches_kafka_reference_vectors() {
        // From Apache Kafka UtilsTest.testMurmur2 (signed 32-bit int values cast to i32)
        assert_eq!(murmur2(b"21") as i32, -973932308);
        assert_eq!(murmur2(b"foobar") as i32, -790332482);
        assert_eq!(murmur2(b"a-little-bit-long-string") as i32, -985981536);
        assert_eq!(murmur2(b"a-little-bit-longer-string") as i32, -1486304829);
        assert_eq!(
            murmur2(b"lkjh234lh9fiuh90y23oiuhsafujhadof229phr9h19h89h8") as i32,
            -58897971
        );
        assert_eq!(murmur2(b"abc") as i32, 479470107);
    }

    #[test]
    fn default_partition_handles_non_positive_counts() {
        assert_eq!(default_partition(b"order-1", 0), None);
        assert_eq!(default_partition(b"order-1", -1), None);
    }

    #[test]
    fn default_partition_matches_java_formula_and_utf8() {
        for n in [1_i32, 3, 12, 64] {
            for key in ["order-4711", "foobar", "", "ü-key"] {
                let expected = ((murmur2(key.as_bytes()) & 0x7fffffff) % (n as u32)) as i32;
                let actual = default_partition(key.as_bytes(), n);
                assert_eq!(actual, Some(expected));
                let p = actual.unwrap();
                assert!(p >= 0 && p < n);
            }
        }
        // Explicitly verify non-ASCII UTF-8 bytes match string .as_bytes()
        assert_eq!(
            default_partition("ü-key".as_bytes(), 12),
            default_partition(&[0xc3, 0xbc, b'-', b'k', b'e', b'y'], 12)
        );
    }
}
