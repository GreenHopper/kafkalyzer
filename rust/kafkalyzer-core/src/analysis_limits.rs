use crate::duplicate_fingerprint::DEFAULT_FINGERPRINT_LIMIT;
use crate::size_stats::SizeSample;
use serde::{Deserialize, Serialize};

pub const MAX_TRACKED_FIELDS: usize = 500;
pub const MAX_REPORTED_FIELDS: usize = 100;
pub const MAX_VALUES_PER_FIELD: usize = 200;
pub const MAX_LISTED_VALUES: usize = 10;
pub const MAX_FIELD_DEPTH: usize = 5;
pub const MAX_VALUE_CHARS: usize = 80;
pub const MAX_TRACKED_KEYS: usize = 10_000;
pub const MAX_LISTED_KEYS: usize = 20;
pub const MAX_SIZE_SAMPLE: usize = SizeSample::LIMIT;
pub const MAX_TRACKED_FINGERPRINTS: usize = DEFAULT_FINGERPRINT_LIMIT;
pub const MAX_DUPLICATE_SAMPLES: usize = 1_000;
pub const MAX_LISTED_DUPLICATES: usize = 20;
pub const MAX_PREVIEW_CHARS: usize = 4_000;
pub const TIMELINE_PAST_DAYS: i64 = 366;
pub const TIMELINE_FUTURE_HOURS: i64 = 24;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AnalysisLimitKind {
    TrackedFields,
    ListedFields,
    ValuesPerField,
    ListedValuesPerField,
    FieldDepth,
    ValueDisplayChars,
    TrackedKeys,
    ListedKeys,
    SizePercentileSample,
    TrackedFingerprints,
    DuplicateSamples,
    ListedDuplicates,
    PreviewChars,
    TimelineWindowDays,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalysisLimit {
    pub kind: AnalysisLimitKind,
    pub limit: i64,
    pub reached: bool,
}
