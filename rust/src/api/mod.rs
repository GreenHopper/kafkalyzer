pub mod avro_utils;
pub mod kafka_analyzer;
pub mod kafka_consumer;
pub mod kafka_metadata;
pub mod kafka_types;
pub mod kafka_utils;
pub mod schema_registry;

pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
