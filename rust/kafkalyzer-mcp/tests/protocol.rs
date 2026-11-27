//! Protocol smoke test: handshake, tools/list, kafka_list_clusters, stdin close, unknown arg.

use std::process::Stdio;
use std::time::Duration;

use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;
use tokio::time::timeout;

const READ_TIMEOUT: Duration = Duration::from_secs(10);

fn bin() -> String {
    std::env::var("CARGO_BIN_EXE_kafkalyzer-mcp").unwrap_or_else(|_| {
        format!(
            "{}/target/debug/kafkalyzer-mcp",
            env!("CARGO_MANIFEST_DIR").replace("/kafkalyzer-mcp", "")
        )
    })
}

async fn send_json(
    writer: &mut (impl AsyncWriteExt + Unpin),
    value: &Value,
) -> std::io::Result<()> {
    let mut line = serde_json::to_string(value).unwrap();
    line.push('\n');
    writer.write_all(line.as_bytes()).await?;
    writer.flush().await
}

async fn read_json_with_id(
    reader: &mut BufReader<impl tokio::io::AsyncRead + Unpin>,
    want_id: &str,
) -> Value {
    let deadline = tokio::time::Instant::now() + READ_TIMEOUT;
    loop {
        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        let mut line = String::new();
        timeout(remaining, reader.read_line(&mut line))
            .await
            .expect("timeout waiting for response")
            .expect("read stdout");
        assert!(!line.is_empty(), "stdout closed before id {want_id}");
        let value: Value = serde_json::from_str(line.trim()).expect("json line");
        if value
            .get("id")
            .map(|v| v.to_string().trim_matches('"').to_string())
            == Some(want_id.to_string())
            || value.get("id") == Some(&json!(want_id.parse::<i64>().ok().unwrap_or(-1)))
            || value.get("id") == Some(&json!(want_id))
        {
            return value;
        }
        // Ignore notifications / unrelated responses.
    }
}

#[tokio::test]
async fn handshake_list_and_list_clusters_then_exit_on_stdin_close() {
    let tmp = std::env::temp_dir().join(format!(
        "kafkalyzer-mcp-protocol-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    std::fs::create_dir_all(&tmp).unwrap();

    let mut child = Command::new(bin())
        .env("XDG_CONFIG_HOME", &tmp)
        .env("HOME", &tmp)
        .env("KAFKALYZER_MCP_LOG", "off")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn kafkalyzer-mcp");

    let mut stdin = child.stdin.take().expect("stdin");
    let stdout = child.stdout.take().expect("stdout");
    let mut reader = BufReader::new(stdout);

    send_json(
        &mut stdin,
        &json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": { "name": "protocol-test", "version": "0.0.0" }
            }
        }),
    )
    .await
    .unwrap();
    let init = read_json_with_id(&mut reader, "1").await;
    assert!(init.get("result").is_some(), "initialize: {init}");

    send_json(
        &mut stdin,
        &json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }),
    )
    .await
    .unwrap();

    send_json(
        &mut stdin,
        &json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        }),
    )
    .await
    .unwrap();
    let listed = read_json_with_id(&mut reader, "2").await;
    let tools = listed["result"]["tools"].as_array().expect("tools array");
    assert_eq!(tools.len(), 12, "expected 12 tools, got {listed}");
    assert!(
        tools.iter().any(|t| t["name"] == "kafka_list_clusters"),
        "missing kafka_list_clusters"
    );

    send_json(
        &mut stdin,
        &json!({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "kafka_list_clusters",
                "arguments": {}
            }
        }),
    )
    .await
    .unwrap();
    let call = read_json_with_id(&mut reader, "3").await;
    let content = &call["result"]["content"][0]["text"];
    let body: Value = serde_json::from_str(content.as_str().expect("text")).unwrap();
    assert!(body["clusters"].is_array(), "list_clusters body: {body}");

    drop(stdin);
    let status = timeout(READ_TIMEOUT, child.wait())
        .await
        .expect("timeout waiting for exit")
        .expect("wait");
    assert!(status.success(), "exit status {status}");

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn unknown_argument_exits_2() {
    let output = std::process::Command::new(bin())
        .arg("--nope")
        .output()
        .expect("spawn");
    assert_eq!(output.status.code(), Some(2));
    let err = String::from_utf8_lossy(&output.stderr);
    assert!(err.contains("unknown"), "stderr: {err}");
}

#[test]
fn version_flag_prints_and_exits_0() {
    let output = std::process::Command::new(bin())
        .arg("--version")
        .output()
        .expect("spawn");
    assert!(output.status.success());
    let out = String::from_utf8_lossy(&output.stdout);
    assert!(!out.trim().is_empty());
}
