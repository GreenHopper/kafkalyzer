//! MCP protocol surface: catalogue, dispatch, CLI, handler.

pub mod catalog;
pub mod cli;
pub mod dispatch;
pub mod handler;

pub use catalog::{registered_tools, DATA_FLOW_STATEMENT};
pub use cli::{parse_args, version_string, CliAction};
pub use dispatch::{run_blocking, signal_cancel, DispatchGate};
pub use handler::McpServer;
