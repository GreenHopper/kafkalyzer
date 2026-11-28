//! MCP `ServerHandler`: list tools, dispatch via blocking gate.

use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

use kafkalyzer_profiles::{KeyringSecretStore, SecretStore};
use rmcp::model::{
    CallToolRequestParams, CallToolResponse, CallToolResult, ContentBlock, ListToolsResult,
    PaginatedRequestParams, ServerCapabilities, ServerConfig, Tool,
};
use rmcp::service::RequestContext;
use rmcp::{ErrorData as McpError, RoleServer, ServerHandler};
use serde::Serialize;
use serde_json::Value;

use super::catalog::{
    self, AnalyzeTopicInput, CalculatePartitionInput, ClusterOnlyInput, ConsumeMessagesInput,
    GetLagInput, GetSchemaInput, InspectLaggingInput, ListClustersInput, ListGroupsInput,
    ListSchemasInput, ListTopicsInput, SearchMessagesInput,
};
use super::dispatch::{run_blocking, signal_cancel, DispatchGate};
use crate::clusters::Clusters;
use crate::limits::{resolve, LimitRequest, Limits};
use crate::tools::{
    kafka_analyze_topic, kafka_calculate_partition, kafka_consume_messages, kafka_get_consumer_lag,
    kafka_get_schema, kafka_inspect_lagging_message, kafka_list_clusters,
    kafka_list_consumer_groups, kafka_list_schemas, kafka_list_topics, kafka_search_messages,
    kafka_test_connection, parse_position, AnalyzeLimitFrom, SearchMessagesRequest, ToolContext,
    ToolError,
};

pub struct McpServer {
    profiles_path: PathBuf,
    restrict_to: Vec<String>,
    gate: DispatchGate,
}

impl McpServer {
    pub fn new(profiles_path: PathBuf, restrict_to: Vec<String>) -> Self {
        Self {
            profiles_path,
            restrict_to,
            gate: DispatchGate::with_defaults(),
        }
    }
}

impl ServerHandler for McpServer {
    fn get_info(&self) -> ServerConfig {
        ServerConfig::new(ServerCapabilities::builder().enable_tools().build()).with_instructions(
            "kafkalyzer MCP server: read-only Kafka inspection over shared profiles.".to_string(),
        )
    }

    fn get_tool(&self, name: &str) -> Option<Tool> {
        catalog::registered_tools()
            .into_iter()
            .find(|t| t.name.as_ref() == name)
    }

    async fn list_tools(
        &self,
        _request: Option<PaginatedRequestParams>,
        _context: RequestContext<RoleServer>,
    ) -> Result<ListToolsResult, McpError> {
        Ok(ListToolsResult::with_all_items(catalog::registered_tools()))
    }

    async fn call_tool(
        &self,
        request: CallToolRequestParams,
        context: RequestContext<RoleServer>,
    ) -> Result<CallToolResponse, McpError> {
        let name = request.name.to_string();
        let args = request.arguments.unwrap_or_default();
        let cancel = Arc::new(AtomicBool::new(false));
        let cancel_watch = Arc::clone(&cancel);
        let ct = context.ct.clone();
        tokio::spawn(async move {
            ct.cancelled().await;
            signal_cancel(&cancel_watch);
        });

        let sem = self.gate.semaphore();
        let profiles_path = self.profiles_path.clone();
        let restrict_to = self.restrict_to.clone();

        let result = run_blocking(sem, Arc::clone(&cancel), move |cancel| {
            let clusters = Clusters::new(profiles_path, restrict_to);
            let store = KeyringSecretStore::new();
            dispatch_tool(&name, &args, &clusters, &store, cancel)
        })
        .await
        .unwrap_or_else(tool_error);

        Ok(result.into())
    }
}

fn tool_ok<T: Serialize>(value: &T) -> CallToolResult {
    match serde_json::to_string(value) {
        Ok(text) => CallToolResult::success(vec![ContentBlock::text(text)]),
        Err(e) => tool_error(format!("failed to serialise tool result: {e}")),
    }
}

fn tool_error(message: impl Into<String>) -> CallToolResult {
    CallToolResult::error(vec![ContentBlock::text(message.into())])
}

fn map_err(err: ToolError) -> CallToolResult {
    tool_error(err.message())
}

fn decode<T: serde::de::DeserializeOwned>(
    args: &serde_json::Map<String, Value>,
) -> Result<T, String> {
    serde_json::from_value(Value::Object(args.clone())).map_err(|e| e.to_string())
}

fn dispatch_tool(
    name: &str,
    args: &serde_json::Map<String, Value>,
    clusters: &Clusters,
    store: &dyn SecretStore,
    cancel: Arc<AtomicBool>,
) -> CallToolResult {
    match name {
        "kafka_list_clusters" => {
            let _: ListClustersInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let ctx = ToolContext {
                clusters,
                store,
                limits: Limits::defaults(),
                cancel,
            };
            match kafka_list_clusters(&ctx) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_test_connection" => {
            let input: ClusterOnlyInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let ctx = ToolContext {
                clusters,
                store,
                limits: Limits::defaults(),
                cancel,
            };
            match kafka_test_connection(&ctx, input.cluster.as_deref()) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_list_topics" => {
            let input: ListTopicsInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let limits = resolve(&LimitRequest {
                max_list_entries: input.max_list_entries,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_list_topics(
                &ctx,
                input.cluster.as_deref(),
                input.name_filter.as_deref(),
                input.include_internal.unwrap_or(false),
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_list_consumer_groups" => {
            let input: ListGroupsInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let limits = resolve(&LimitRequest {
                max_list_entries: input.max_list_entries,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_list_consumer_groups(&ctx, input.cluster.as_deref()) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_get_consumer_lag" => {
            let input: GetLagInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let ctx = ToolContext {
                clusters,
                store,
                limits: Limits::defaults(),
                cancel,
            };
            match kafka_get_consumer_lag(&ctx, input.cluster.as_deref(), &input.group_id) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_calculate_partition" => {
            let input: CalculatePartitionInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let ctx = ToolContext {
                clusters,
                store,
                limits: Limits::defaults(),
                cancel,
            };
            match kafka_calculate_partition(
                &ctx,
                input.cluster.as_deref(),
                &input.topic,
                &input.key,
                input.include_internal.unwrap_or(false),
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_consume_messages" => {
            let input: ConsumeMessagesInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let position = match parse_position(input.position.as_deref()) {
                Ok(p) => p,
                Err(e) => return map_err(e),
            };
            let limits = resolve(&LimitRequest {
                max_messages: input.max_messages,
                time_budget_secs: input.time_budget_secs,
                max_text_bytes: input.max_text_bytes,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_consume_messages(
                &ctx,
                input.cluster.as_deref(),
                &input.topic,
                position,
                input.partition,
                input.include_internal.unwrap_or(false),
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_search_messages" => {
            let input: SearchMessagesInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let position = match parse_position(input.position.as_deref()) {
                Ok(p) => p,
                Err(e) => return map_err(e),
            };
            let limits = resolve(&LimitRequest {
                max_messages: input.max_messages,
                time_budget_secs: input.time_budget_secs,
                max_text_bytes: input.max_text_bytes,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            let filter_type = input.filter_type.as_deref().unwrap_or("contains");
            match kafka_search_messages(
                &ctx,
                SearchMessagesRequest {
                    cluster: input.cluster.as_deref(),
                    topics: &input.topics,
                    pattern: &input.pattern,
                    filter_type,
                    search_scope: input.search_scope.as_deref(),
                    filter_field: input.filter_field.as_deref(),
                    position,
                    include_internal: input.include_internal.unwrap_or(false),
                },
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_inspect_lagging_message" => {
            let input: InspectLaggingInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let limits = resolve(&LimitRequest {
                time_budget_secs: input.time_budget_secs,
                max_text_bytes: input.max_text_bytes,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_inspect_lagging_message(
                &ctx,
                input.cluster.as_deref(),
                &input.group_id,
                &input.topic,
                input.partition,
                input.include_internal.unwrap_or(false),
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_analyze_topic" => {
            let input: AnalyzeTopicInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let limit_from = match input.limit_from.as_deref() {
                None | Some("") | Some("newest") => AnalyzeLimitFrom::Newest,
                Some("oldest") => AnalyzeLimitFrom::Oldest,
                Some(other) => {
                    return tool_error(format!(
                        "unknown limit_from '{other}'; expected newest or oldest"
                    ));
                }
            };
            let limits = resolve(&LimitRequest {
                max_analysed_messages: input.max_analysed_messages,
                time_budget_secs: input.time_budget_secs,
                max_text_bytes: input.max_text_bytes,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_analyze_topic(
                &ctx,
                input.cluster.as_deref(),
                &input.topic,
                limit_from,
                input.include_internal.unwrap_or(false),
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_list_schemas" => {
            let input: ListSchemasInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let limits = resolve(&LimitRequest {
                max_list_entries: input.max_list_entries,
                ..Default::default()
            });
            let ctx = ToolContext {
                clusters,
                store,
                limits,
                cancel,
            };
            match kafka_list_schemas(&ctx, input.cluster.as_deref()) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        "kafka_get_schema" => {
            let input: GetSchemaInput = match decode(args) {
                Ok(v) => v,
                Err(e) => return tool_error(e),
            };
            let ctx = ToolContext {
                clusters,
                store,
                limits: Limits::defaults(),
                cancel,
            };
            match kafka_get_schema(
                &ctx,
                input.cluster.as_deref(),
                &input.subject,
                input.version,
            ) {
                Ok(out) => tool_ok(&out),
                Err(e) => map_err(e),
            }
        }
        other => tool_error(format!("unknown tool '{other}'")),
    }
}
