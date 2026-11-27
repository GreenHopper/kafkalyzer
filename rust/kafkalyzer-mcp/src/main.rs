//! kafkalyzer MCP stdio server entry point (design D6/D8).

use std::io::{self, Write};
use std::process::ExitCode;

use kafkalyzer_mcp::server::{parse_args, version_string, CliAction, McpServer};
use kafkalyzer_profiles::default_path;
use rmcp::{transport::stdio, ServiceExt};

fn main() -> ExitCode {
    let mut argv = std::env::args();
    let _bin = argv.next();
    match parse_args(argv) {
        Ok(CliAction::Version) => {
            println!("{}", version_string());
            ExitCode::SUCCESS
        }
        Ok(CliAction::Help) => {
            print!("{}", kafkalyzer_mcp::server::cli::help_text());
            ExitCode::SUCCESS
        }
        Ok(CliAction::Run(cli)) => match run_server(cli.clusters) {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => {
                let _ = writeln!(io::stderr(), "kafkalyzer-mcp: {e}");
                ExitCode::from(1)
            }
        },
        Err(msg) => {
            let _ = writeln!(io::stderr(), "kafkalyzer-mcp: {msg}");
            let _ = writeln!(
                io::stderr(),
                "Try 'kafkalyzer-mcp --help' for more information."
            );
            ExitCode::from(2)
        }
    }
}

#[tokio::main]
async fn run_server(clusters: Vec<String>) -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    let path = default_path()?;
    log::info!("shared profiles path: {}", path.display());
    let server = McpServer::new(path, clusters);
    let service = server.serve(stdio()).await?;
    // Closed stdin ends the transport; waiting returns when the peer disconnects.
    service.waiting().await?;
    Ok(())
}

fn init_logging() {
    let mut builder = env_logger::Builder::from_env(
        env_logger::Env::default().filter_or("KAFKALYZER_MCP_LOG", "warn"),
    );
    builder.target(env_logger::Target::Stderr);
    let _ = builder.try_init();
}
