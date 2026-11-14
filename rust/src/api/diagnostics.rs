use std::fs::OpenOptions;
use std::io::Write;
use std::panic::PanicHookInfo;
use std::path::Path;
use std::sync::{Mutex, OnceLock};

use chrono::Utc;

use crate::frb_generated::StreamSink;

const MAX_LOG_MESSAGE_BYTES: usize = 4096;
const MAX_PANIC_MESSAGE_CHARS: usize = 200;
const LEGACY_DEBUG_LOG_NAME: &str = "rust_debug_v2.log";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RustLogLevel {
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RustLogRecord {
    pub level: RustLogLevel,
    pub target: String,
    pub message: String,
    pub timestamp_ms: i64,
}

struct ForwardingLogger {
    sink: Mutex<Option<StreamSink<RustLogRecord>>>,
}

impl ForwardingLogger {
    const fn new() -> Self {
        Self {
            sink: Mutex::new(None),
        }
    }

    fn set_sink(&self, new_sink: StreamSink<RustLogRecord>) {
        if let Ok(mut guard) = self.sink.lock() {
            *guard = Some(new_sink);
        }
    }
}

impl log::Log for ForwardingLogger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        metadata.level() <= log::max_level()
    }

    fn log(&self, record: &log::Record) {
        if !self.enabled(record.metadata()) {
            return;
        }
        let item = RustLogRecord {
            level: map_log_level(record.level()),
            target: record.target().to_string(),
            message: truncate_utf8(&record.args().to_string(), MAX_LOG_MESSAGE_BYTES),
            timestamp_ms: Utc::now().timestamp_millis(),
        };

        if let Ok(mut guard) = self.sink.lock() {
            if let Some(sink) = guard.as_ref() {
                if sink.add(item).is_err() {
                    *guard = None;
                }
            }
        }
    }

    fn flush(&self) {}
}

static LOGGER: ForwardingLogger = ForwardingLogger::new();
static LOGGER_INSTALLED: OnceLock<()> = OnceLock::new();
static PANIC_HOOK_INSTALLED: OnceLock<()> = OnceLock::new();
static PANIC_LOG_PATH: Mutex<Option<String>> = Mutex::new(None);

pub fn init_rust_logging(
    sink: StreamSink<RustLogRecord>,
    max_level: RustLogLevel,
    log_file_path: String,
) {
    LOGGER.set_sink(sink);
    LOGGER_INSTALLED.get_or_init(|| {
        let _ = log::set_logger(&LOGGER);
    });
    log::set_max_level(map_level_filter(max_level));

    if let Ok(mut guard) = PANIC_LOG_PATH.lock() {
        *guard = if log_file_path.trim().is_empty() {
            None
        } else {
            Some(log_file_path)
        };
    }

    PANIC_HOOK_INSTALLED.get_or_init(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            handle_panic(info);
            previous(info);
        }));
    });

    delete_legacy_debug_log_in(&std::env::temp_dir());
}

fn handle_panic(info: &PanicHookInfo<'_>) {
    let location = info
        .location()
        .map(|loc| format!("{}:{}", loc.file(), loc.line()));
    let payload = if let Some(s) = info.payload().downcast_ref::<&str>() {
        (*s).to_string()
    } else if let Some(s) = info.payload().downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic payload".to_string()
    };

    log::error!(
        target: "panic",
        "{}",
        format_panic_body(location.as_deref(), &payload)
    );

    if let Ok(guard) = PANIC_LOG_PATH.lock() {
        if let Some(path) = guard.as_deref() {
            let line = format_panic_line(location.as_deref(), &payload);
            if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
                let _ = writeln!(file, "{line}");
                let _ = file.flush();
            }
        }
    }
}

pub(crate) fn map_log_level(level: log::Level) -> RustLogLevel {
    match level {
        log::Level::Error => RustLogLevel::Error,
        log::Level::Warn => RustLogLevel::Warn,
        log::Level::Info => RustLogLevel::Info,
        log::Level::Debug => RustLogLevel::Debug,
        log::Level::Trace => RustLogLevel::Trace,
    }
}

pub(crate) fn map_level_filter(level: RustLogLevel) -> log::LevelFilter {
    match level {
        RustLogLevel::Error => log::LevelFilter::Error,
        RustLogLevel::Warn => log::LevelFilter::Warn,
        RustLogLevel::Info => log::LevelFilter::Info,
        RustLogLevel::Debug => log::LevelFilter::Debug,
        RustLogLevel::Trace => log::LevelFilter::Trace,
    }
}

pub(crate) fn truncate_utf8(input: &str, max_bytes: usize) -> String {
    if input.len() <= max_bytes {
        return input.to_string();
    }
    let mut end = max_bytes;
    while end > 0 && !input.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}...[truncated]", &input[..end])
}

pub(crate) fn delete_legacy_debug_log_in(dir: &Path) {
    let legacy = dir.join(LEGACY_DEBUG_LOG_NAME);
    if legacy.exists() {
        let _ = std::fs::remove_file(legacy);
    }
}

fn format_panic_body(location: Option<&str>, payload: &str) -> String {
    let loc = location.unwrap_or("unknown");
    let single_line = payload.replace(['\n', '\r'], " ");
    let truncated: String = single_line.chars().take(MAX_PANIC_MESSAGE_CHARS).collect();
    format!("{loc} {truncated}")
}

pub(crate) fn format_panic_line(location: Option<&str>, payload: &str) -> String {
    let ts = Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
    let body = format_panic_body(location, payload);
    format!("{ts} FATAL [rust:panic] {body}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_log_levels_and_filters() {
        assert_eq!(map_log_level(log::Level::Error), RustLogLevel::Error);
        assert_eq!(map_log_level(log::Level::Warn), RustLogLevel::Warn);
        assert_eq!(map_log_level(log::Level::Info), RustLogLevel::Info);
        assert_eq!(map_log_level(log::Level::Debug), RustLogLevel::Debug);
        assert_eq!(map_log_level(log::Level::Trace), RustLogLevel::Trace);

        assert_eq!(
            map_level_filter(RustLogLevel::Error),
            log::LevelFilter::Error
        );
        assert_eq!(map_level_filter(RustLogLevel::Warn), log::LevelFilter::Warn);
        assert_eq!(map_level_filter(RustLogLevel::Info), log::LevelFilter::Info);
        assert_eq!(
            map_level_filter(RustLogLevel::Debug),
            log::LevelFilter::Debug
        );
        assert_eq!(
            map_level_filter(RustLogLevel::Trace),
            log::LevelFilter::Trace
        );
    }

    #[test]
    fn truncates_utf8_safely_at_byte_limit() {
        assert_eq!(truncate_utf8("hello", 10), "hello");

        let multi = "ä".repeat(3000); // 6000 bytes
        let out = truncate_utf8(&multi, 4096);
        assert!(out.ends_with("...[truncated]"));
        let prefix = out.strip_suffix("...[truncated]").unwrap();
        assert!(prefix.len() <= 4096);
        assert!(std::str::from_utf8(prefix.as_bytes()).is_ok());
    }

    #[test]
    fn deletes_legacy_debug_log_if_present() {
        let dir = std::env::temp_dir().join(format!(
            "kafkalyzer_diag_test_{}",
            Utc::now().timestamp_nanos_opt().unwrap_or(0)
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let legacy = dir.join(LEGACY_DEBUG_LOG_NAME);
        std::fs::write(&legacy, b"old debug").unwrap();
        assert!(legacy.exists());

        delete_legacy_debug_log_in(&dir);
        assert!(!legacy.exists());

        // Calling again when absent is a safe no-op
        delete_legacy_debug_log_in(&dir);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn formats_panic_line_with_utc_fatal_and_200_char_cap() {
        let long_msg = format!("line1\n{}", "a".repeat(300));
        let formatted = format_panic_line(Some("src/lib.rs:42"), &long_msg);
        assert!(formatted.contains("FATAL [rust:panic] src/lib.rs:42 "));
        assert!(!formatted.contains('\n'));
        let body = formatted.split("src/lib.rs:42 ").nth(1).unwrap();
        assert_eq!(body.chars().count(), 200);
    }
}
