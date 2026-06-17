pub mod kafka_types;
pub mod kafka_utils;
pub mod kafka_metadata;
pub mod kafka_consumer;
pub mod schema_registry;
pub mod avro_utils;



pub use kafkalyzer_kafka::kafka_utils::ClientConfig;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
