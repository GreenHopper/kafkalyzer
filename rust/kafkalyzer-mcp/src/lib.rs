//! kafkalyzer MCP stdio server — tool handlers and protocol helpers.
//!
//! Broker I/O goes through `kafkalyzer-kafka`; shared profiles through
//! `kafkalyzer-profiles`. This crate must not depend on `rdkafka`, `reqwest`,
//! or `flutter_rust_bridge`.

pub mod clusters;
pub mod limits;
pub mod server;
pub mod shape;
pub mod tools;
