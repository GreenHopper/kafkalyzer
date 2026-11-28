//! Tool catalogue: names, descriptions, and derived input schemas (task 5.1).

use rmcp::handler::server::common::schema_for_input;
use rmcp::model::Tool;
use rmcp::schemars;
use serde::Deserialize;

use crate::limits::{
    CEILING_MAX_ANALYSED_MESSAGES, CEILING_MAX_MESSAGES, CEILING_MAX_TEXT_BYTES, CEILING_TIME_SECS,
    DEFAULT_MAX_ANALYSED_MESSAGES, DEFAULT_MAX_MESSAGES, DEFAULT_MAX_TEXT_BYTES, DEFAULT_TIME_SECS,
};

/// Spec: returned data becomes part of the conversation → sent to the model provider.
pub const DATA_FLOW_STATEMENT: &str = "Returned data becomes part of the conversation and is therefore sent to the provider of the client's language model.";

fn limits_blurb() -> String {
    format!(
        "Default limits: {DEFAULT_MAX_MESSAGES} returned messages / {DEFAULT_MAX_ANALYSED_MESSAGES} analysed / {DEFAULT_TIME_SECS}s / {DEFAULT_MAX_TEXT_BYTES}B text; \
         ceilings: {CEILING_MAX_MESSAGES} / {CEILING_MAX_ANALYSED_MESSAGES} / {CEILING_TIME_SECS}s / {CEILING_MAX_TEXT_BYTES}B."
    )
}

fn describe(extra: &str) -> String {
    format!("{DATA_FLOW_STATEMENT} {} {}", limits_blurb(), extra)
}

/// Property names that must never appear (tailing / write).
pub const FORBIDDEN_PARAM_NAMES: &[&str] = &[
    "run_forever",
    "produce",
    "commit",
    "create",
    "delete",
    "alter",
    "reset_offsets",
    "write",
    "tail",
    "follow",
    "append",
];

macro_rules! input {
    ($name:ident { $($field:tt)* }) => {
        #[derive(Debug, Clone, Deserialize, schemars::JsonSchema)]
        pub struct $name {
            $($field)*
        }
    };
}

#[derive(Debug, Clone, Deserialize, schemars::JsonSchema)]
pub struct ListClustersInput {}

input!(ClusterOnlyInput {
    /// Shared cluster name; required when more than one cluster is shared.
    #[serde(default)]
    pub cluster: Option<String>,
});

input!(ListTopicsInput {
    #[serde(default)]
    pub cluster: Option<String>,
    /// Case-insensitive substring filter on topic name.
    #[serde(default)]
    pub name_filter: Option<String>,
    #[serde(default)]
    pub include_internal: Option<bool>,
    #[serde(default)]
    pub max_list_entries: Option<usize>,
});

input!(ListGroupsInput {
    #[serde(default)]
    pub cluster: Option<String>,
    #[serde(default)]
    pub max_list_entries: Option<usize>,
});

input!(GetLagInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub group_id: String,
});

input!(CalculatePartitionInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub topic: String,
    pub key: String,
    #[serde(default)]
    pub include_internal: Option<bool>,
});

input!(ConsumeMessagesInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub topic: String,
    /// oldest | newest | offset:<n> | timestamp:<ms>
    #[serde(default)]
    pub position: Option<String>,
    #[serde(default)]
    pub partition: Option<i32>,
    #[serde(default)]
    pub include_internal: Option<bool>,
    #[serde(default)]
    pub max_messages: Option<usize>,
    #[serde(default)]
    pub time_budget_secs: Option<u64>,
    #[serde(default)]
    pub max_text_bytes: Option<usize>,
});

input!(SearchMessagesInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub topics: Vec<String>,
    pub pattern: String,
    /// contains | exact | regex
    #[serde(default)]
    pub filter_type: Option<String>,
    /// key | value | both
    #[serde(default)]
    pub search_scope: Option<String>,
    #[serde(default)]
    pub filter_field: Option<String>,
    #[serde(default)]
    pub position: Option<String>,
    #[serde(default)]
    pub include_internal: Option<bool>,
    #[serde(default)]
    pub max_messages: Option<usize>,
    #[serde(default)]
    pub time_budget_secs: Option<u64>,
    #[serde(default)]
    pub max_text_bytes: Option<usize>,
});

input!(InspectLaggingInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub group_id: String,
    pub topic: String,
    pub partition: i32,
    #[serde(default)]
    pub include_internal: Option<bool>,
    #[serde(default)]
    pub time_budget_secs: Option<u64>,
    #[serde(default)]
    pub max_text_bytes: Option<usize>,
});

input!(AnalyzeTopicInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub topic: String,
    /// newest | oldest
    #[serde(default)]
    pub limit_from: Option<String>,
    #[serde(default)]
    pub include_internal: Option<bool>,
    #[serde(default)]
    pub max_analysed_messages: Option<usize>,
    #[serde(default)]
    pub time_budget_secs: Option<u64>,
    #[serde(default)]
    pub max_text_bytes: Option<usize>,
});

input!(ListSchemasInput {
    #[serde(default)]
    pub cluster: Option<String>,
    #[serde(default)]
    pub max_list_entries: Option<usize>,
});

input!(GetSchemaInput {
    #[serde(default)]
    pub cluster: Option<String>,
    pub subject: String,
    #[serde(default)]
    pub version: Option<i32>,
});

fn tool<T: schemars::JsonSchema + 'static>(name: &'static str, extra: &str) -> Tool {
    let schema = schema_for_input::<T>().expect("input schema");
    Tool::new(name, describe(extra), schema)
}

/// The twelve registered tools with descriptions and derived schemas.
pub fn registered_tools() -> Vec<Tool> {
    vec![
        tool::<ListClustersInput>(
            "kafka_list_clusters",
            "Lists shared clusters (name, environment, protocol, registry, TLS flag).",
        ),
        tool::<ClusterOnlyInput>(
            "kafka_test_connection",
            "Probes whether a shared cluster's broker is reachable.",
        ),
        tool::<ListTopicsInput>(
            "kafka_list_topics",
            "Lists topics with optional name filter; internal topics omitted unless requested.",
        ),
        tool::<ListGroupsInput>(
            "kafka_list_consumer_groups",
            "Lists consumer groups on the cluster.",
        ),
        tool::<GetLagInput>(
            "kafka_get_consumer_lag",
            "Returns per-partition lag for one consumer group.",
        ),
        tool::<CalculatePartitionInput>(
            "kafka_calculate_partition",
            "Computes the default partitioner assignment for a key on a topic.",
        ),
        tool::<ConsumeMessagesInput>(
            "kafka_consume_messages",
            "Reads messages from one topic from a chosen position (no consumer group, no commits).",
        ),
        tool::<SearchMessagesInput>(
            "kafka_search_messages",
            "Searches messages across topics with a contains/exact/regex filter (no commits).",
        ),
        tool::<InspectLaggingInput>(
            "kafka_inspect_lagging_message",
            "Returns the next unprocessed message for a group on one partition (no commits).",
        ),
        tool::<AnalyzeTopicInput>(
            "kafka_analyze_topic",
            "Analyses topic content (counts, sizes, key/field distributions); no value filter.",
        ),
        tool::<ListSchemasInput>("kafka_list_schemas", "Lists Schema Registry subjects."),
        tool::<GetSchemaInput>(
            "kafka_get_schema",
            "Fetches one subject's schema text (capped) by version or latest.",
        ),
    ]
}

pub fn collect_property_names(schema: &serde_json::Map<String, serde_json::Value>) -> Vec<String> {
    let mut names = Vec::new();
    collect_props(schema, &mut names);
    names
}

fn collect_props(obj: &serde_json::Map<String, serde_json::Value>, out: &mut Vec<String>) {
    if let Some(serde_json::Value::Object(props)) = obj.get("properties") {
        for (k, v) in props {
            out.push(k.clone());
            if let serde_json::Value::Object(child) = v {
                collect_props(child, out);
            }
        }
    }
    if let Some(serde_json::Value::Object(items)) = obj.get("items") {
        collect_props(items, out);
    }
    for key in ["anyOf", "oneOf", "allOf"] {
        if let Some(serde_json::Value::Array(arr)) = obj.get(key) {
            for v in arr {
                if let serde_json::Value::Object(child) = v {
                    collect_props(child, out);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twelve_tools_registered() {
        let tools = registered_tools();
        assert_eq!(tools.len(), 12);
        let mut names: Vec<_> = tools.iter().map(|t| t.name.to_string()).collect();
        names.sort();
        assert_eq!(
            names,
            vec![
                "kafka_analyze_topic",
                "kafka_calculate_partition",
                "kafka_consume_messages",
                "kafka_get_consumer_lag",
                "kafka_get_schema",
                "kafka_inspect_lagging_message",
                "kafka_list_clusters",
                "kafka_list_consumer_groups",
                "kafka_list_schemas",
                "kafka_list_topics",
                "kafka_search_messages",
                "kafka_test_connection",
            ]
        );
    }

    #[test]
    fn every_description_contains_data_flow_and_limits() {
        for tool in registered_tools() {
            let desc = tool.description.as_deref().unwrap_or("");
            assert!(
                desc.contains(DATA_FLOW_STATEMENT),
                "{} missing data flow statement",
                tool.name
            );
            assert!(
                desc.contains(&DEFAULT_MAX_MESSAGES.to_string())
                    && desc.contains(&CEILING_MAX_MESSAGES.to_string()),
                "{} missing limit defaults/ceilings: {desc}",
                tool.name
            );
        }
    }

    #[test]
    fn consume_description_has_data_flow_and_limits() {
        let tool = registered_tools()
            .into_iter()
            .find(|t| t.name == "kafka_consume_messages")
            .unwrap();
        let desc = tool.description.unwrap();
        assert!(desc.contains(DATA_FLOW_STATEMENT));
        assert!(desc.contains(&limits_blurb()));
    }

    #[test]
    fn no_schema_has_tailing_or_write_parameter() {
        for tool in registered_tools() {
            let names = collect_property_names(tool.input_schema.as_ref());
            for name in &names {
                let lower = name.to_ascii_lowercase();
                for forbidden in FORBIDDEN_PARAM_NAMES {
                    assert!(
                        !lower.contains(forbidden),
                        "{} has forbidden parameter {name}",
                        tool.name
                    );
                }
            }
        }
    }

    #[test]
    fn limits_blurb_matches_constants() {
        let blurb = limits_blurb();
        assert!(blurb.contains(&DEFAULT_MAX_MESSAGES.to_string()));
        assert!(blurb.contains(&CEILING_MAX_MESSAGES.to_string()));
    }
}
