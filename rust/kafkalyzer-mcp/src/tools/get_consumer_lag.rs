use kafkalyzer_core::kafka_types::{
    ClusterProfile, ConsumerGroupLag, PartitionLagStatus, TopicPartitionLag,
};
use kafkalyzer_kafka::kafka_metadata::fetch_consumer_group_lag;
use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::shape::ResultMeta;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LagStatusOut {
    Known,
    NoCommit,
    Unknown,
}

impl From<PartitionLagStatus> for LagStatusOut {
    fn from(status: PartitionLagStatus) -> Self {
        match status {
            PartitionLagStatus::Known => Self::Known,
            PartitionLagStatus::NoCommit => Self::NoCommit,
            PartitionLagStatus::Unknown => Self::Unknown,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct PartitionLagOut {
    pub topic: String,
    pub partition: i32,
    pub status: LagStatusOut,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lag: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_offset: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub log_end_offset: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct GetConsumerLagOutput {
    pub group_id: String,
    pub state: String,
    pub partitions: Vec<PartitionLagOut>,
    /// Sum of lag over partitions with status `known` only.
    pub total_lag: i64,
    /// True when any partition is not `known` (no_commit or unknown).
    pub total_incomplete: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lag_error: Option<String>,
    pub meta: ResultMeta,
}

fn map_partition(p: TopicPartitionLag) -> PartitionLagOut {
    let status = LagStatusOut::from(p.status);
    match status {
        LagStatusOut::Known => PartitionLagOut {
            topic: p.topic,
            partition: p.partition,
            status,
            lag: Some(p.lag),
            current_offset: Some(p.current_offset),
            log_end_offset: Some(p.log_end_offset),
            error: p.error,
        },
        LagStatusOut::NoCommit => PartitionLagOut {
            topic: p.topic,
            partition: p.partition,
            status,
            lag: None,
            current_offset: None,
            log_end_offset: Some(p.log_end_offset),
            error: p.error,
        },
        LagStatusOut::Unknown => PartitionLagOut {
            topic: p.topic,
            partition: p.partition,
            status,
            lag: None,
            current_offset: None,
            log_end_offset: None,
            error: p.error,
        },
    }
}

pub fn map_consumer_lag(
    lag: ConsumerGroupLag,
    limits: &crate::limits::Limits,
) -> GetConsumerLagOutput {
    let partitions: Vec<PartitionLagOut> =
        lag.partition_lags.into_iter().map(map_partition).collect();
    let total_lag: i64 = partitions
        .iter()
        .filter_map(|p| match p.status {
            LagStatusOut::Known => p.lag,
            _ => None,
        })
        .sum();
    let total_incomplete = partitions
        .iter()
        .any(|p| !matches!(p.status, LagStatusOut::Known));
    GetConsumerLagOutput {
        group_id: lag.group_id,
        state: lag.state,
        partitions,
        total_lag,
        total_incomplete,
        lag_error: lag.lag_error,
        meta: ResultMeta::new(limits),
    }
}

pub fn kafka_get_consumer_lag(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    group_id: &str,
) -> Result<GetConsumerLagOutput, ToolError> {
    kafka_get_consumer_lag_with(ctx, cluster, group_id, |profile, gid| {
        fetch_consumer_group_lag(profile, gid).map_err(|e| e.to_string())
    })
}

pub fn kafka_get_consumer_lag_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    group_id: &str,
    fetch: F,
) -> Result<GetConsumerLagOutput, ToolError>
where
    F: FnOnce(ClusterProfile, String) -> Result<ConsumerGroupLag, String>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let lag = fetch(profile.clone(), group_id.to_string())
        .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;
    Ok(map_consumer_lag(lag, &ctx.limits))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::limits::Limits;

    fn part(
        topic: &str,
        partition: i32,
        status: PartitionLagStatus,
        lag: i64,
        error: Option<&str>,
    ) -> TopicPartitionLag {
        TopicPartitionLag {
            topic: topic.into(),
            partition,
            log_end_offset: 100,
            current_offset: if matches!(status, PartitionLagStatus::Known) {
                100 - lag
            } else {
                -1
            },
            lag,
            status,
            error: error.map(str::to_string),
        }
    }

    #[test]
    fn lag_total_incomplete_with_unknown_partitions() {
        let lag = ConsumerGroupLag {
            group_id: "g".into(),
            state: "Stable".into(),
            protocol_type: "consumer".into(),
            partition_lags: vec![
                part("orders", 0, PartitionLagStatus::Known, 5, None),
                part("orders", 1, PartitionLagStatus::NoCommit, 0, None),
                part(
                    "orders",
                    2,
                    PartitionLagStatus::Unknown,
                    0,
                    Some("not authorized"),
                ),
            ],
            members_count: 1,
            topics_count: 1,
            members: vec![],
            unassigned_partitions: vec![],
            lag_error: None,
            ownership_known: true,
        };
        let out = map_consumer_lag(lag, &Limits::defaults());
        assert_eq!(out.total_lag, 5);
        assert!(out.total_incomplete);
        assert_eq!(out.partitions[0].lag, Some(5));
        assert_eq!(out.partitions[1].status, LagStatusOut::NoCommit);
        assert_eq!(out.partitions[1].lag, None);
        assert_eq!(out.partitions[2].status, LagStatusOut::Unknown);
        assert_eq!(out.partitions[2].error.as_deref(), Some("not authorized"));
    }

    #[test]
    fn all_known_is_complete() {
        let lag = ConsumerGroupLag {
            group_id: "g".into(),
            state: "Stable".into(),
            protocol_type: "consumer".into(),
            partition_lags: vec![part("t", 0, PartitionLagStatus::Known, 3, None)],
            members_count: 1,
            topics_count: 1,
            members: vec![],
            unassigned_partitions: vec![],
            lag_error: None,
            ownership_known: true,
        };
        let out = map_consumer_lag(lag, &Limits::defaults());
        assert_eq!(out.total_lag, 3);
        assert!(!out.total_incomplete);
    }
}
