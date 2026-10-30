use crate::kafka_types::DuplicateDetectionScope;
use sha2::{Digest, Sha256};

pub type MessageFingerprint = [u8; 16];

/// Computes a compact 128-bit collision-resistant fingerprint for duplicate message detection.
pub fn compute_message_fingerprint(
    scope: DuplicateDetectionScope,
    key_bytes: Option<&[u8]>,
    payload_bytes: Option<&[u8]>,
) -> MessageFingerprint {
    let mut hasher = Sha256::new();
    match scope {
        DuplicateDetectionScope::PayloadOnly => {
            match payload_bytes {
                None => hasher.update([0x00]),
                Some(payload) => {
                    hasher.update([0x01]);
                    hasher.update(payload);
                }
            }
        }
        DuplicateDetectionScope::KeyAndPayload => {
            match key_bytes {
                None => hasher.update([0x00]),
                Some(key) => {
                    hasher.update([0x01]);
                    hasher.update((key.len() as u64).to_le_bytes());
                    hasher.update(key);
                }
            }
            match payload_bytes {
                None => hasher.update([0x00]),
                Some(payload) => {
                    hasher.update([0x01]);
                    hasher.update(payload);
                }
            }
        }
    }
    let full_hash = hasher.finalize();
    let mut truncated = [0u8; 16];
    truncated.copy_from_slice(&full_hash[..16]);
    truncated
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn payload_only_matches_identical_payloads_with_different_keys() {
        let fp1 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key1"),
            Some(b"{\"status\":\"FAILED\"}"),
        );
        let fp2 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key2"),
            Some(b"{\"status\":\"FAILED\"}"),
        );
        let fp3 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            None,
            Some(b"{\"status\":\"FAILED\"}"),
        );
        assert_eq!(fp1, fp2);
        assert_eq!(fp2, fp3);
    }

    #[test]
    fn payload_only_distinguishes_different_payloads() {
        let fp1 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            None,
            Some(b"{\"status\":\"FAILED\"}"),
        );
        let fp2 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            None,
            Some(b"{\"status\":\"SUCCESS\"}"),
        );
        assert_ne!(fp1, fp2);
    }

    #[test]
    fn key_and_payload_distinguishes_different_keys_with_identical_payload() {
        let fp1 = compute_message_fingerprint(
            DuplicateDetectionScope::KeyAndPayload,
            Some(b"order-1"),
            Some(b"{\"action\":\"cancel\"}"),
        );
        let fp2 = compute_message_fingerprint(
            DuplicateDetectionScope::KeyAndPayload,
            Some(b"order-2"),
            Some(b"{\"action\":\"cancel\"}"),
        );
        let fp3 = compute_message_fingerprint(
            DuplicateDetectionScope::KeyAndPayload,
            Some(b"order-1"),
            Some(b"{\"action\":\"cancel\"}"),
        );
        assert_ne!(fp1, fp2);
        assert_eq!(fp1, fp3);
    }

    #[test]
    fn key_and_payload_framing_prevents_concatenation_ambiguity() {
        // "ab" + "c" vs "a" + "bc"
        let fp1 = compute_message_fingerprint(
            DuplicateDetectionScope::KeyAndPayload,
            Some(b"ab"),
            Some(b"c"),
        );
        let fp2 = compute_message_fingerprint(
            DuplicateDetectionScope::KeyAndPayload,
            Some(b"a"),
            Some(b"bc"),
        );
        assert_ne!(fp1, fp2);
    }

    #[test]
    fn handles_tombstones_correctly() {
        let fp_tomb1 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key1"),
            None,
        );
        let fp_tomb2 = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key2"),
            None,
        );
        let fp_empty = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key1"),
            Some(b""),
        );
        assert_eq!(fp_tomb1, fp_tomb2);
        assert_ne!(fp_tomb1, fp_empty);
    }
}
