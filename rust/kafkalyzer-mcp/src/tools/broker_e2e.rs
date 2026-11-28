//! Ignored handler tests against the compose broker.
//! Run via `scripts/kafka_integration_tests.sh`.

#![cfg(test)]

use super::analyze_topic::{kafka_analyze_topic, AnalyzeLimitFrom};
use super::calculate_partition::kafka_calculate_partition;
use super::consume_messages::kafka_consume_messages;
use super::get_consumer_lag::kafka_get_consumer_lag;
use super::get_schema::kafka_get_schema;
use super::inspect_lagging_message::kafka_inspect_lagging_message;
use super::list_clusters::kafka_list_clusters;
use super::list_consumer_groups::kafka_list_consumer_groups;
use super::list_schemas::kafka_list_schemas;
use super::list_topics::kafka_list_topics;
use super::messages::ConsumePosition;
use super::search_messages::{kafka_search_messages, SearchMessagesRequest};
use super::test_connection::kafka_test_connection;
use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::limits::Limits;
use crate::shape::CappedText;
use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
use serde::Serialize;
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

const MARKER_SECRET: &str = "mcp-it-marker-secret-DO-NOT-LEAK";
const CLUSTER: &str = "it-local";

struct Fixture {
    dir: PathBuf,
    store: MemorySecretStore,
    clusters: Clusters,
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.dir);
    }
}

fn setup() -> Fixture {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-broker-e2e-{nanos}"));
    fs::create_dir_all(&dir).unwrap();
    let path = dir.join("shared-profiles.json");
    let store = MemorySecretStore::new();
    let report = write_shared(
        &path,
        &store,
        &[SharedProfileInput {
            profile: ClusterProfile {
                name: CLUSTER.into(),
                bootstrap_servers: "localhost:9094".into(),
                security_protocol: Some("PLAINTEXT".into()),
                sasl_password: Some(MARKER_SECRET.into()),
                ..ClusterProfile::default()
            },
            environment_label: Some("it".into()),
        }],
    );
    assert!(report.file_error.is_none(), "{:?}", report.file_error);
    Fixture {
        dir,
        store,
        clusters: Clusters::new(&path, None::<String>),
    }
}

fn ctx<'a>(fix: &'a Fixture, limits: Limits) -> ToolContext<'a> {
    ToolContext {
        clusters: &fix.clusters,
        store: &fix.store,
        limits,
        cancel: Arc::new(AtomicBool::new(false)),
    }
}

fn assert_no_marker<T: Serialize>(label: &str, value: &T) {
    let json = serde_json::to_string(value).expect(label);
    assert!(
        !json.contains(MARKER_SECRET),
        "{label} leaked marker secret: {json}"
    );
}

fn assert_no_marker_err(label: &str, err: &ToolError) {
    let msg = err.message();
    assert!(
        !msg.contains(MARKER_SECRET),
        "{label} error leaked marker: {msg}"
    );
}

fn assert_capped(label: &str, text: &CappedText, max: usize) {
    assert!(
        text.text.len() <= max,
        "{label} text len {} exceeds cap {max}",
        text.text.len()
    );
    if let Some(orig) = text.original_size {
        assert!(orig > max, "{label} original_size {orig} should exceed cap");
    }
}

#[test]
#[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
fn handlers_against_compose_broker() {
    let fix = setup();
    let limits = Limits::defaults();
    let max_text = limits.max_text_bytes;
    let c = ctx(&fix, limits.clone());

    // 1. list_clusters
    let clusters = kafka_list_clusters(&c).expect("list_clusters");
    assert_eq!(clusters.clusters.len(), 1);
    assert_eq!(clusters.clusters[0].name, CLUSTER);
    assert_no_marker("list_clusters", &clusters);

    // 2. test_connection
    let conn = kafka_test_connection(&c, Some(CLUSTER)).expect("test_connection");
    assert!(conn.reachable, "broker should be reachable: {:?}", conn);
    assert_no_marker("test_connection", &conn);

    // 3. list_topics
    let topics =
        kafka_list_topics(&c, Some(CLUSTER), Some("lag-spike"), false).expect("list_topics");
    assert!(
        topics.topics.iter().any(|t| t.name == "lag-spike"),
        "lag-spike missing: {:?}",
        topics.topics
    );
    assert_no_marker("list_topics", &topics);

    // 4. list_consumer_groups
    let groups = kafka_list_consumer_groups(&c, Some(CLUSTER)).expect("list_groups");
    assert!(
        groups.groups.iter().any(|g| g.group_id == "lag-spike-g"),
        "lag-spike-g missing"
    );
    assert_no_marker("list_groups", &groups);

    // 5. get_consumer_lag
    let lag = kafka_get_consumer_lag(&c, Some(CLUSTER), "lag-spike-g").expect("lag");
    assert!(lag.partitions.iter().any(|p| p.topic == "lag-spike"));
    assert_no_marker("get_consumer_lag", &lag);

    // 6. calculate_partition
    let part = kafka_calculate_partition(&c, Some(CLUSTER), "lag-spike", "k0", false)
        .expect("calculate_partition");
    assert!(part.partition >= 0);
    assert_no_marker("calculate_partition", &part);

    // 7. consume_messages (oversize fixture → value capped)
    let consumed = kafka_consume_messages(
        &c,
        Some(CLUSTER),
        "spike-oversize-33k",
        ConsumePosition::Oldest,
        None,
        false,
    )
    .expect("consume oversize");
    assert_eq!(consumed.messages.len(), 1);
    let value = consumed.messages[0].value.as_ref().expect("oversize value");
    assert_capped("oversize value", value, max_text);
    assert_no_marker("consume_messages", &consumed);

    // 8. search_messages
    let search = kafka_search_messages(
        &c,
        SearchMessagesRequest {
            cluster: Some(CLUSTER),
            topics: &["lag-spike".to_string()],
            pattern: "msg-1",
            filter_type: "contains",
            search_scope: Some("value"),
            filter_field: None,
            position: ConsumePosition::Oldest,
            include_internal: false,
        },
    )
    .expect("search_messages");
    assert!(!search.messages.is_empty());
    for m in &search.messages {
        if let Some(v) = &m.value {
            assert_capped("search value", v, max_text);
        }
        if let Some(k) = &m.key {
            assert_capped("search key", k, max_text);
        }
    }
    assert_no_marker("search_messages", &search);

    // 9. inspect_lagging_message on lag-spike p2 (committed 100, end 150)
    let inspect =
        kafka_inspect_lagging_message(&c, Some(CLUSTER), "lag-spike-g", "lag-spike", 2, false)
            .expect("inspect_lagging");
    assert_eq!(inspect.committed_offset, Some(100));
    let msg = inspect
        .message
        .as_ref()
        .expect("expected a lagging message");
    assert_eq!(msg.partition, 2);
    assert!(msg.offset >= 100);
    assert_no_marker("inspect_lagging", &inspect);

    // 10. analyze_topic (empty fixture — fast)
    let analysis = kafka_analyze_topic(
        &c,
        Some(CLUSTER),
        "spike-t-000",
        AnalyzeLimitFrom::Newest,
        false,
    )
    .expect("analyze_topic");
    assert_eq!(analysis.total_messages, 0);
    assert!(!analysis.partial);
    assert_no_marker("analyze_topic", &analysis);

    // 11–12. schema tools (no registry on compose → distinct not-configured error)
    let schemas_err = kafka_list_schemas(&c, Some(CLUSTER)).expect_err("list_schemas");
    assert!(
        schemas_err
            .message()
            .contains("no Schema Registry is configured"),
        "{}",
        schemas_err.message()
    );
    assert_no_marker_err("list_schemas", &schemas_err);

    let get_err =
        kafka_get_schema(&c, Some(CLUSTER), "orders-value", None).expect_err("get_schema");
    assert!(
        get_err
            .message()
            .contains("no Schema Registry is configured"),
        "{}",
        get_err.message()
    );
    assert_no_marker_err("get_schema", &get_err);

    // Internal topic refused before broker I/O
    let internal = kafka_consume_messages(
        &c,
        Some(CLUSTER),
        "__consumer_offsets",
        ConsumePosition::Oldest,
        None,
        false,
    )
    .expect_err("internal");
    assert!(internal.message().contains("internal"));
    assert_no_marker_err("internal", &internal);
}
