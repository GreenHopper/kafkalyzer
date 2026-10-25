//! Bounded, deterministic sampling of message sizes for percentile reporting.
//!
//! Scanning a large topic must not keep one entry per message in memory, so the
//! percentiles are computed from a fixed-size sample while min, max and count
//! stay exact. The sample is chosen by hashing `(partition, offset)`: the same
//! scanned messages always produce the same sample, so two runs of the same scan
//! report the same numbers.

use serde::{Deserialize, Serialize};
use std::collections::BinaryHeap;

/// p50, p95 and p99 of the sampled message sizes, in bytes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct SizePercentiles {
    pub p50: i64,
    pub p95: i64,
    pub p99: i64,
}

/// Sampler holding at most [`SizeSample::LIMIT`] sizes, chosen by hash priority.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SizeSample {
    /// `(priority, size)` pairs; the heap keeps the lowest priorities, so the
    /// largest priority sits on top and is the first to be dropped.
    entries: BinaryHeap<(u64, i64)>,
    count: i64,
    min: i64,
    max: i64,
    total: i64,
}

impl SizeSample {
    pub const LIMIT: usize = 10_000;

    /// Add one message. Count, min, max and total stay exact for every message,
    /// only the percentile sample is bounded.
    pub fn record(&mut self, partition: i32, offset: i64, size: i64) {
        let priority = priority_of(partition, offset);
        if self.count == 0 {
            self.min = size;
            self.max = size;
        } else {
            self.min = self.min.min(size);
            self.max = self.max.max(size);
        }
        self.count += 1;
        self.total += size;

        if self.entries.len() < Self::LIMIT {
            self.entries.push((priority, size));
        } else if let Some(&top) = self.entries.peek() {
            if priority < top.0 {
                self.entries.pop();
                self.entries.push((priority, size));
            }
        }
    }

    /// Merge a worker accumulator: union the samples, then trim back to the limit.
    pub fn merge(&mut self, other: SizeSample) {
        if other.count == 0 {
            return;
        }
        if self.count == 0 {
            self.min = other.min;
            self.max = other.max;
        } else {
            self.min = self.min.min(other.min);
            self.max = self.max.max(other.max);
        }
        self.count += other.count;
        self.total += other.total;
        for entry in other.entries.into_iter() {
            if self.entries.len() < Self::LIMIT {
                self.entries.push(entry);
            } else if let Some(&top) = self.entries.peek() {
                if entry.0 < top.0 {
                    self.entries.pop();
                    self.entries.push(entry);
                }
            }
        }
    }

    /// True when more messages were seen than the sample can hold, so the
    /// percentiles describe a sample and not the whole scan.
    pub fn estimated(&self) -> bool {
        self.count > Self::LIMIT as i64
    }

    pub fn count(&self) -> i64 {
        self.count
    }

    pub fn min(&self) -> i64 {
        self.min
    }

    pub fn max(&self) -> i64 {
        self.max
    }

    pub fn mean(&self) -> i64 {
        if self.count == 0 {
            0
        } else {
            self.total / self.count
        }
    }

    /// Nearest-rank percentiles of the sample. Percentiles of one message equal
    /// that message's size, and they always sit between min and max.
    pub fn percentiles(&self) -> Option<SizePercentiles> {
        if self.entries.is_empty() {
            return None;
        }
        let mut sizes: Vec<i64> = self.entries.iter().map(|(_, size)| *size).collect();
        sizes.sort_unstable();
        Some(SizePercentiles {
            p50: rank_at(&sizes, 0.50),
            p95: rank_at(&sizes, 0.95),
            p99: rank_at(&sizes, 0.99),
        })
    }
}

fn rank_at(sorted: &[i64], fraction: f64) -> i64 {
    // Nearest-rank: the smallest size whose rank reaches the requested fraction.
    let rank = (sorted.len() as f64 * fraction).ceil() as usize;
    sorted[rank.max(1).saturating_sub(1).min(sorted.len() - 1)]
}

/// SplitMix64 of the message coordinates: deterministic across runs and cheap.
fn priority_of(partition: i32, offset: i64) -> u64 {
    let mut z =
        (offset as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ ((partition as u32 as u64) << 32);
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_of(sizes: &[i64]) -> SizeSample {
        let mut sample = SizeSample::default();
        for (offset, size) in sizes.iter().enumerate() {
            sample.record(0, offset as i64, *size);
        }
        sample
    }

    #[test]
    fn an_empty_sample_has_no_percentiles_and_zero_counts() {
        let sample = SizeSample::default();
        assert_eq!(sample.count(), 0);
        assert_eq!(sample.mean(), 0);
        assert!(sample.percentiles().is_none());
    }

    #[test]
    fn merging_into_an_empty_sample_keeps_the_other_extremes() {
        let mut empty = SizeSample::default();
        empty.merge(sample_of(&[10, 20, 900]));
        assert_eq!(empty.min(), 10);
        assert_eq!(empty.max(), 900);
        assert_eq!(empty.count(), 3);
    }

    #[test]
    fn a_set_below_the_limit_yields_exact_percentiles() {
        let sizes: Vec<i64> = (1..=100).collect();
        let sample = sample_of(&sizes);
        let percentiles = sample.percentiles().unwrap();
        assert_eq!(percentiles.p50, 50);
        assert_eq!(percentiles.p95, 95);
        assert_eq!(percentiles.p99, 99);
        assert!(!sample.estimated());
    }

    #[test]
    fn percentiles_of_one_message_are_that_size() {
        let sample = sample_of(&[4096]);
        let percentiles = sample.percentiles().unwrap();
        assert_eq!(percentiles.p50, 4096);
        assert_eq!(percentiles.p95, 4096);
        assert_eq!(percentiles.p99, 4096);
    }

    #[test]
    fn percentiles_stay_between_min_and_max() {
        let sample = sample_of(&[1, 500_000, 7, 90_000, 42, 3_000, 12]);
        let percentiles = sample.percentiles().unwrap();
        for value in [percentiles.p50, percentiles.p95, percentiles.p99] {
            assert!(value >= sample.min() && value <= sample.max(), "{value}");
        }
        assert_eq!(sample.min(), 1);
        assert_eq!(sample.max(), 500_000);
    }

    #[test]
    fn the_same_input_yields_the_same_sample() {
        let sizes: Vec<i64> = (0..50_000).map(|i| (i % 997) as i64).collect();
        let first = sample_of(&sizes).percentiles().unwrap();
        let second = sample_of(&sizes).percentiles().unwrap();
        assert_eq!(first, second);
    }

    #[test]
    fn a_scan_above_the_limit_is_reported_as_estimated() {
        let sample = sample_of(&(0..SizeSample::LIMIT as i64 + 1).collect::<Vec<i64>>());
        assert!(sample.estimated());
        assert!(sample.percentiles().is_some());
    }

    #[test]
    fn merging_two_workers_equals_one_worker_over_the_same_messages() {
        let messages: Vec<(i32, i64, i64)> = (0..30_000)
            .map(|i| ((i % 2) as i32, (i / 2) as i64, (i % 500) as i64 + 1))
            .collect();

        let mut single = SizeSample::default();
        for (partition, offset, size) in &messages {
            single.record(*partition, *offset, *size);
        }

        let mut left = SizeSample::default();
        let mut right = SizeSample::default();
        for (partition, offset, size) in &messages {
            if *partition == 0 {
                left.record(*partition, *offset, *size);
            } else {
                right.record(*partition, *offset, *size);
            }
        }
        left.merge(right);

        assert_eq!(single.count(), left.count());
        assert_eq!(single.min(), left.min());
        assert_eq!(single.max(), left.max());
        assert_eq!(single.mean(), left.mean());
        assert_eq!(single.percentiles(), left.percentiles());
    }

    #[test]
    fn a_merged_sample_never_exceeds_the_limit() {
        let mut left = sample_of(&(0..20_000i64).collect::<Vec<i64>>());
        let right = sample_of(&(0..20_000i64).collect::<Vec<i64>>());
        let right_count = right.count();
        left.merge(right);
        assert_eq!(left.count(), 40_000);
        assert!(left.entries.len() <= SizeSample::LIMIT);
        assert_eq!(right_count, 20_000);
        assert!(left.percentiles().is_some());
    }
}
