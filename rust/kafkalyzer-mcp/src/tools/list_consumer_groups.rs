use kafkalyzer_core::kafka_types::{ClusterProfile, ConsumerGroupLag};
use kafkalyzer_kafka::kafka_metadata::fetch_consumer_groups;
use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::shape::{ResultMeta, StopReason};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ConsumerGroupInfo {
    pub group_id: String,
    pub state: String,
    pub members_count: i32,
    pub topics_count: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ListConsumerGroupsOutput {
    pub groups: Vec<ConsumerGroupInfo>,
    pub total: usize,
    pub meta: ResultMeta,
}

pub fn map_consumer_groups(
    groups: Vec<ConsumerGroupLag>,
    max_entries: usize,
    limits: &crate::limits::Limits,
) -> ListConsumerGroupsOutput {
    let total = groups.len();
    let mut mapped: Vec<ConsumerGroupInfo> = groups
        .into_iter()
        .map(|g| ConsumerGroupInfo {
            group_id: g.group_id,
            state: g.state,
            members_count: g.members_count,
            topics_count: g.topics_count,
        })
        .collect();
    let truncated = total > max_entries;
    if truncated {
        mapped.truncate(max_entries);
    }
    let mut meta = ResultMeta::new(limits);
    if truncated {
        meta.stop_reason = Some(StopReason::MessageLimit);
        meta.notes
            .push(format!("list truncated to {max_entries} of {total} groups"));
    }
    ListConsumerGroupsOutput {
        groups: mapped,
        total,
        meta,
    }
}

pub fn kafka_list_consumer_groups(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
) -> Result<ListConsumerGroupsOutput, ToolError> {
    kafka_list_consumer_groups_with(ctx, cluster, |profile| {
        fetch_consumer_groups(profile).map_err(|e| e.to_string())
    })
}

pub fn kafka_list_consumer_groups_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    fetch: F,
) -> Result<ListConsumerGroupsOutput, ToolError>
where
    F: FnOnce(ClusterProfile) -> Result<Vec<ConsumerGroupLag>, String>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let groups = fetch(profile.clone())
        .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;
    Ok(map_consumer_groups(
        groups,
        ctx.limits.max_list_entries,
        &ctx.limits,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::limits::Limits;
    use kafkalyzer_core::kafka_types::ConsumerGroupLag;

    fn group(id: &str) -> ConsumerGroupLag {
        ConsumerGroupLag {
            group_id: id.into(),
            state: "Stable".into(),
            protocol_type: "consumer".into(),
            partition_lags: vec![],
            members_count: 1,
            topics_count: 1,
            members: vec![],
            unassigned_partitions: vec![],
            lag_error: None,
            ownership_known: true,
        }
    }

    #[test]
    fn list_cap_with_total() {
        let groups: Vec<_> = (0..10).map(|i| group(&format!("g-{i}"))).collect();
        let limits = Limits {
            max_list_entries: 3,
            ..Limits::defaults()
        };
        let out = map_consumer_groups(groups, 3, &limits);
        assert_eq!(out.total, 10);
        assert_eq!(out.groups.len(), 3);
        assert_eq!(out.meta.stop_reason, Some(StopReason::MessageLimit));
    }
}
