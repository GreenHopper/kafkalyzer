use crate::api::kafka_types::{ClusterProfile, TopicAnalysisOptions, TopicAnalysisProgress};
use crate::frb_generated::StreamSink;
use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

pub async fn analyze_topic_content(
    profile: ClusterProfile,
    topic: String,
    max_messages: Option<i64>,
    sample_from_latest: bool,
    sink: StreamSink<TopicAnalysisProgress>,
) -> Result<()> {
    analyze_topic_content_with_options(
        profile,
        topic,
        TopicAnalysisOptions {
            max_messages,
            sample_from_latest,
            value_filter: None,
            duplicate_scope: None,
        },
        sink,
    )
    .await
}

pub async fn analyze_topic_content_with_options(
    profile: ClusterProfile,
    topic: String,
    options: TopicAnalysisOptions,
    sink: StreamSink<TopicAnalysisProgress>,
) -> Result<()> {
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let sink_clone = sink.clone();
    let cancel_flag = Arc::new(AtomicBool::new(false));
    let cancel_flag_task = cancel_flag.clone();

    tokio::spawn(async move {
        while let Some(progress) = rx.recv().await {
            let bridge_progress = TopicAnalysisProgress::from(progress);
            if sink_clone.add(bridge_progress).is_err() {
                // Client cancelled or disconnected
                cancel_flag_task.store(true, Ordering::Relaxed);
                break;
            }
        }
    });

    let kafka_sink = kafkalyzer_kafka::kafka_consumer::StreamSink::new(tx);
    let domain_profile = profile.to_domain();
    let domain_options = options.to_domain();

    tokio::task::spawn_blocking(move || {
        kafkalyzer_kafka::kafka_analyzer::analyze_topic_content(
            domain_profile,
            topic,
            domain_options,
            kafka_sink,
            cancel_flag,
        )
    })
    .await?
}
