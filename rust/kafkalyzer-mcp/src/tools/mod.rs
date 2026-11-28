//! MCP tool handlers. Each function maps domain results to this crate's output shapes.

mod analyze_topic;
mod broker_e2e;
mod calculate_partition;
mod consume_messages;
mod get_consumer_lag;
mod get_schema;
mod inspect_lagging_message;
mod list_clusters;
mod list_consumer_groups;
mod list_schemas;
mod list_topics;
mod messages;
mod schema_errors;
mod search_messages;
mod test_connection;

pub use analyze_topic::{kafka_analyze_topic, AnalyzeLimitFrom, AnalyzeTopicOutput};
pub use calculate_partition::{kafka_calculate_partition, CalculatePartitionOutput};
pub use consume_messages::{kafka_consume_messages, ConsumeMessagesOutput};
pub use get_consumer_lag::{kafka_get_consumer_lag, GetConsumerLagOutput};
pub use get_schema::{kafka_get_schema, GetSchemaOutput};
pub use inspect_lagging_message::{kafka_inspect_lagging_message, InspectLaggingMessageOutput};
pub use list_clusters::{kafka_list_clusters, ClusterInfo, ListClustersOutput};
pub use list_consumer_groups::{kafka_list_consumer_groups, ListConsumerGroupsOutput};
pub use list_schemas::{kafka_list_schemas, ListSchemasOutput};
pub use list_topics::{kafka_list_topics, ListTopicsOutput};
pub use messages::{parse_position, ConsumePosition};
pub use search_messages::{kafka_search_messages, SearchMessagesOutput, SearchMessagesRequest};
pub use test_connection::{kafka_test_connection, TestConnectionOutput};

use std::sync::atomic::AtomicBool;
use std::sync::Arc;

use kafkalyzer_profiles::SecretStore;

use crate::clusters::{ClusterError, Clusters};
use crate::limits::Limits;
use crate::shape::redact;

/// Shared dependencies for every tool call.
pub struct ToolContext<'a> {
    pub clusters: &'a Clusters,
    pub store: &'a dyn SecretStore,
    pub limits: Limits,
    /// Set by the server when the MCP client cancels the call.
    pub cancel: Arc<AtomicBool>,
}

/// Handler-level error (mapped to MCP tool errors by the server layer).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ToolError {
    Cluster(ClusterError),
    Message(String),
}

impl ToolError {
    pub fn message(&self) -> String {
        match self {
            ToolError::Cluster(e) => e.message(),
            ToolError::Message(m) => m.clone(),
        }
    }

    pub fn redact_with(self, profile: &kafkalyzer_core::kafka_types::ClusterProfile) -> Self {
        match self {
            ToolError::Message(m) => ToolError::Message(redact(&m, profile)),
            other => other,
        }
    }
}

impl From<ClusterError> for ToolError {
    fn from(value: ClusterError) -> Self {
        ToolError::Cluster(value)
    }
}
