use crate::kafka_types::DuplicateDetectionScope;
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::hash::{BuildHasherDefault, Hasher};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Mutex;

pub type MessageFingerprint = [u8; 16];

pub const FINGERPRINT_SHARD_COUNT: usize = 16;
pub const DEFAULT_FINGERPRINTS_PER_SHARD: usize = 114_688;
pub const DEFAULT_FINGERPRINT_LIMIT: usize =
    FINGERPRINT_SHARD_COUNT * DEFAULT_FINGERPRINTS_PER_SHARD;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FingerprintOutcome {
    New,
    Seen,
    Untracked,
}

/// Pass-through hasher for 128-bit SHA-256-derived fingerprints.
/// Avoids SipHash on the hot path because the input bytes are already uniform.
#[derive(Default)]
pub struct FingerprintHasher(u64);

impl Hasher for FingerprintHasher {
    #[inline]
    fn finish(&self) -> u64 {
        self.0
    }

    #[inline]
    fn write(&mut self, bytes: &[u8]) {
        if bytes.len() >= 8 {
            self.0 = u64::from_le_bytes([
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            ]);
        } else {
            let mut buf = [0u8; 8];
            buf[..bytes.len()].copy_from_slice(bytes);
            self.0 = u64::from_le_bytes(buf);
        }
    }
}

type ShardSet = HashSet<MessageFingerprint, BuildHasherDefault<FingerprintHasher>>;

/// Thread-safe, memory-bounded set of message fingerprints shared across scan workers.
pub struct BoundedFingerprintSet {
    shards: [Mutex<ShardSet>; FINGERPRINT_SHARD_COUNT],
    per_shard_cap: usize,
    tracked: AtomicI64,
    untracked: AtomicI64,
}

impl Default for BoundedFingerprintSet {
    fn default() -> Self {
        Self::new()
    }
}

impl BoundedFingerprintSet {
    pub fn new() -> Self {
        Self::with_per_shard_cap(DEFAULT_FINGERPRINTS_PER_SHARD)
    }

    pub fn with_per_shard_cap(per_shard_cap: usize) -> Self {
        Self {
            shards: std::array::from_fn(|_| Mutex::new(ShardSet::default())),
            per_shard_cap,
            tracked: AtomicI64::new(0),
            untracked: AtomicI64::new(0),
        }
    }

    pub fn insert(&self, fp: MessageFingerprint) -> FingerprintOutcome {
        let shard_idx = (fp[0] & 0x0f) as usize;
        let mut guard = self.shards[shard_idx]
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        if guard.contains(&fp) {
            return FingerprintOutcome::Seen;
        }
        if guard.len() >= self.per_shard_cap {
            drop(guard);
            self.untracked.fetch_add(1, Ordering::Relaxed);
            return FingerprintOutcome::Untracked;
        }
        guard.insert(fp);
        drop(guard);
        self.tracked.fetch_add(1, Ordering::Relaxed);
        FingerprintOutcome::New
    }

    pub fn tracked(&self) -> i64 {
        self.tracked.load(Ordering::Relaxed)
    }

    pub fn untracked(&self) -> i64 {
        self.untracked.load(Ordering::Relaxed)
    }

    pub fn limit(&self) -> i64 {
        (FINGERPRINT_SHARD_COUNT * self.per_shard_cap) as i64
    }
}

/// Computes a compact 128-bit collision-resistant fingerprint for duplicate message detection.
pub fn compute_message_fingerprint(
    scope: DuplicateDetectionScope,
    key_bytes: Option<&[u8]>,
    payload_bytes: Option<&[u8]>,
) -> MessageFingerprint {
    let mut hasher = Sha256::new();
    match scope {
        DuplicateDetectionScope::PayloadOnly => match payload_bytes {
            None => hasher.update([0x00]),
            Some(payload) => {
                hasher.update([0x01]);
                hasher.update(payload);
            }
        },
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
        let fp_tomb1 =
            compute_message_fingerprint(DuplicateDetectionScope::PayloadOnly, Some(b"key1"), None);
        let fp_tomb2 =
            compute_message_fingerprint(DuplicateDetectionScope::PayloadOnly, Some(b"key2"), None);
        let fp_empty = compute_message_fingerprint(
            DuplicateDetectionScope::PayloadOnly,
            Some(b"key1"),
            Some(b""),
        );
        assert_eq!(fp_tomb1, fp_tomb2);
        assert_ne!(fp_tomb1, fp_empty);
    }

    #[test]
    fn bounded_set_transitions_new_to_seen_for_repeated_fingerprint() {
        let set = BoundedFingerprintSet::with_per_shard_cap(16);
        let fp = [0x42u8; 16];
        assert_eq!(set.insert(fp), FingerprintOutcome::New);
        assert_eq!(set.insert(fp), FingerprintOutcome::Seen);
        assert_eq!(set.tracked(), 1);
        assert_eq!(set.untracked(), 0);
    }

    #[test]
    fn bounded_set_enforces_limit_and_counts_untracked() {
        let set = BoundedFingerprintSet::with_per_shard_cap(10);
        assert_eq!(set.limit(), 160);
        for i in 0u64..(160 + 10_000) {
            let mut fp = [0u8; 16];
            // Distribute uniformly across all 16 shards and keep distinctness
            fp[0] = (i % 16) as u8;
            fp[1..9].copy_from_slice(&(i / 16).to_le_bytes());
            let _ = set.insert(fp);
        }
        assert_eq!(set.tracked(), 160);
        assert_eq!(set.untracked(), 10_000);
        // Existing fingerprint is still recognized as Seen, not Untracked
        let mut first = [0u8; 16];
        first[0] = 0;
        first[1..9].copy_from_slice(&0u64.to_le_bytes());
        assert_eq!(set.insert(first), FingerprintOutcome::Seen);
        assert_eq!(set.untracked(), 10_000);
    }

    #[test]
    fn bounded_set_concurrent_same_fingerprint_yields_exactly_one_new() {
        use std::sync::Arc;
        let set = Arc::new(BoundedFingerprintSet::new());
        let fp = [0xABu8; 16];
        let handles: Vec<_> = (0..8)
            .map(|_| {
                let s = Arc::clone(&set);
                std::thread::spawn(move || s.insert(fp))
            })
            .collect();
        let outcomes: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();
        let new_count = outcomes
            .iter()
            .filter(|o| **o == FingerprintOutcome::New)
            .count();
        let seen_count = outcomes
            .iter()
            .filter(|o| **o == FingerprintOutcome::Seen)
            .count();
        assert_eq!(new_count, 1);
        assert_eq!(seen_count, 7);
    }

    #[test]
    #[ignore]
    fn spike_1_2_benchmark_sharded_vs_per_thread() {
        use std::sync::Arc;
        use std::time::Instant;

        const THREADS: usize = 8;
        const PER_THREAD: usize = 1_250_000; // 10M total

        fn gen_fps(seed_offset: u64, count: usize) -> Vec<MessageFingerprint> {
            let mut state =
                0x9E37_79B9_7F4A_7C15u64 ^ seed_offset.wrapping_mul(0xBF58_476D_1CE4_E5B9);
            let mut out = Vec::with_capacity(count);
            for _ in 0..count {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                let a = state.to_le_bytes();
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                let b = state.to_le_bytes();
                let mut fp = [0u8; 16];
                fp[..8].copy_from_slice(&a);
                fp[8..].copy_from_slice(&b);
                out.push(fp);
            }
            out
        }

        let batches: Vec<Vec<MessageFingerprint>> = (0..THREADS)
            .map(|t| gen_fps(t as u64 + 1, PER_THREAD))
            .collect();

        // Step (b) consumes `batches` by value and the threads need owned
        // batches, so the copy is taken here, outside the measured region.
        let shared_batches = batches.clone();

        // (a) Shared 16-shard BoundedFingerprintSet
        let shared = Arc::new(BoundedFingerprintSet::with_per_shard_cap(1_000_000));
        let t0 = Instant::now();
        let handles: Vec<_> = shared_batches
            .into_iter()
            .map(|batch| {
                let s = Arc::clone(&shared);
                std::thread::spawn(move || {
                    for fp in batch {
                        let _ = s.insert(fp);
                    }
                })
            })
            .collect();
        for h in handles {
            h.join().unwrap();
        }
        let shared_dur = t0.elapsed();

        // (b) Per-thread HashSet
        let t1 = Instant::now();
        let handles: Vec<_> = batches
            .into_iter()
            .map(|batch| {
                std::thread::spawn(move || {
                    let mut set = HashSet::new();
                    for fp in batch {
                        set.insert(fp);
                    }
                    set.len()
                })
            })
            .collect();
        let mut total = 0usize;
        for h in handles {
            total += h.join().unwrap();
        }
        let per_thread_dur = t1.elapsed();

        println!(
            "Spike 1.2 (8 threads, 10M fps): shared_16_shards={shared_dur:?} (tracked={}), per_thread={per_thread_dur:?} (total={total})",
            shared.tracked()
        );
    }
}
