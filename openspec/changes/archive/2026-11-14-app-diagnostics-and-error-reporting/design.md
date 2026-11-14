# Design

## Context

See proposal.md (Why) and the specs `app-diagnostics`, `keyboard-shortcuts` and `app-version-display` (delta) for
the behaviour. These are the facts in the code that shape the approach (checked by reading the code, not at runtime):

- `lib/main.dart`: `ensureInitialized` → `KafkalyzerRustLib.init()` → `setupDependencyInjection()` → headless
  branch (`--script`, `script`, `--help`, `-h` → `HeadlessScriptRunner.runCli`) → settings, version, Velopack,
  `cleanupHistory()` (fire-and-forget) → `runApp`. None of these steps is guarded, and no error handler is installed.
  Four `debugPrint('DEBUG: …')` lines run before the headless branch. `debugPrint` also prints in release builds,
  so `kafkalyzer --script … --json` gets these lines on stdout ahead of the JSON.
- `dependency_injection.dart` registers `Logger()`. In logger 2.6.2 the defaults are `DevelopmentFilter`, which
  logs **nothing** when asserts are off (release builds), `PrettyPrinter`, and `ConsoleOutput`, which writes to
  stdout. Five services also create a `Logger()` fallback of their own. 52 `debugPrint` calls remain in 9 files,
  several of them in services that prerequisite changes also edit.
- The installed logger 2.6.2 includes `AdvancedFileOutput` (buffered, size-based rotation, `maxRotatedFilesCount`,
  immediate flush for warning and above).
- Rust: `log = "0.4"` is a dependency of the bridge crate and `kafkalyzer-kafka`, but no logger is ever installed.
  `env_logger` is declared and never used. `api::init_app()` (which would call frb's `setup_default_user_utils`,
  installing an `oslog` logger on macOS) is never called: `executeRustInitializers()` is empty and nothing in Dart
  calls `initApp()`. rdkafka's `DefaultClientContext::log` emits through `log` with target `librdkafka`, so its
  records currently disappear.
- `kafka_utils.rs`: `init_providers(&mut Option<File>)` and `create_config` open `temp_dir()/rust_debug_v2.log`
  twice per call (lines ~153 and ~324). They write the bootstrap servers, protocol, truststore/keystore paths,
  the executable path and OpenSSL provider results. `kafka_consumer.rs` uses `println!`/`eprintln!` (pause
  failures, "all partitions done", Schema Registry warnings, `log_to_dart`, and a Fast Trace line that **prints
  the message key**). These go to the process stdout, which is the headless report stream.
- `[profile.release] panic = "abort"`, so frb cannot turn a Rust panic into a Dart exception in release builds.
- Shortcuts are bound in four places: `CallbackShortcuts` in `explorer_view.dart` (Ctrl/Cmd+B, Ctrl/Cmd+G),
  `script_manager_view.dart` (Ctrl/Cmd+B) and `message_inspector_panel.dart` (Enter, Shift+Enter, Escape), and a
  global `HardwareKeyboard` handler in `messages_view.dart` (J/K/↑/↓/F/Escape, with the private
  `_isTextInputFocused()` guard). `F1` and `?` are unused.
- `FileOpenerService.showInFolder` already reveals files per platform. `UpdateService.defaultRepositoryUrl` holds the
  repository URL. `MainLayout` already hosts a SnackBar driven by a `ValueNotifier` (update notice). The same
  pattern is reused for error notices.
- Repo root: `logs/` holds downloaded GitHub Actions run logs and `tests.log` is a redirected `flutter test` output.
  Both are ignored by git (`/logs`, `*.log`) and no code writes to them. They are not touched by this change.

## Goals / Non-Goals

**Goals:**
- One pipeline that every log record goes through: Dart `logger`, `debugPrint`, Rust `log`, librdkafka. Redaction
  happens once, at its end.
- Error capture that works in release builds and never makes things worse: a failing handler, log or clipboard
  must not crash the app or loop.
- Shortcut catalogue as a small, static, testable API that sibling changes extend by adding entries.

**Non-Goals:**
- Making the catalogue the dispatcher. Views keep their `CallbackShortcuts`/handlers and only read key
  combinations from it.
- Structured (JSON) log format, log viewer, remote sinks.
- Redacting arbitrary free text beyond the listed patterns. Payload exclusion is enforced at the call sites.

## Decisions

### D1 — Rust records reach the file by forwarding through a bridge stream, not through a Rust file appender

The bridge crate installs a `log::Log` implementation once (`OnceLock`). It forwards each enabled record as a
`RustLogRecord { level, target, message, timestamp_ms }` DTO through a `StreamSink<RustLogRecord>` that Dart passes
in `init_rust_logging(sink, max_level, log_file_path)`. Dart writes the records through the same `Logger`
as its own records.

- Why: one writer owns the file, the rotation and the redaction, so "one rotating file" holds by construction, and
  the redaction is written and tested once in Dart. Headless mode works the same way because it runs in the same
  process.
- Alternative: a Rust file appender writing into the app-support directory passed at init. Two writers would share
  one file with independent rotation (rename races, interleaved partial lines, two rotation policies). The other
  choice, a second file `rust.log`, contradicts the requirement. The redaction would also have to exist twice
  (Rust and Dart) or move into `kafkalyzer-core` and be called per Dart record across the bridge, which the
  bridge-call rule forbids.
- Details: the sink sits in a `Mutex<Option<…>>`. A repeated `init_rust_logging` call (Dart hot restart) replaces
  it and does not fail on the already-installed global logger. A failed `add` (closed sink) clears the sink. The
  logger never logs about its own failure (no recursion). Messages are cut to 4,096 bytes in Rust before crossing
  the bridge. `log::set_max_level` is taken from `max_level`, so disabled levels cost nothing. The function also
  deletes the legacy `temp_dir()/rust_debug_v2.log`, using the same `temp_dir()` that wrote it. Records are only
  enabled at info level and above by default, and nothing is logged per Kafka message, so the per-record FFI post
  is acceptable. No batching is added.
- Layering: logger and DTO live in `rust/src/api/diagnostics.rs` (bridge crate, because it needs frb's
  `StreamSink`). `kafkalyzer-kafka` and `kafkalyzer-core` only use `log` macros. The logger uses `sink.add(…)` and
  must not contain `.send(` (read-only gate pattern).
- `init_app`/`setup_default_user_utils` stay unused. Calling it would install a competing global logger on macOS.

### D2 — Native fatal errors: panic hook appends one line directly

`init_rust_logging` chains a panic hook that first forwards an error record and then synchronously appends one
line (`<UTC> FATAL [rust:panic] <file:line> <message ≤ 200 chars>`) to `log_file_path` with an append-mode open.
With `panic = "abort"` the process ends right after, so the forwarded record may never be written, and the
direct append is the only reliable trace. This is the one exception to "Dart is the only writer". It writes a single
small line at most once per process, so a collision with rotation is unlikely and costs at most that line. The
truncated panic message is not redacted (Rust has no redaction). This is acceptable because the code under our
control never panics with credentials. Recorded as a risk.

### D3 — Dart pipeline: logger defaults, one shared output, a redacting printer

`lib/src/services/diagnostics/app_logging.dart` configures once, before anything else logs:
- `Logger.defaultFilter = ProductionFilter`, `Logger.level` = info in release and debug otherwise. The environment
  variable `KAFKALYZER_LOG_LEVEL` (`debug|info|warning|error`) overrides it and is passed to Rust as `max_level`.
- `Logger.defaultPrinter` = `RedactingLinePrinter`: one line per record,
  `<ISO-8601 UTC> <LEVEL> [<origin>] <message>` plus redacted error/stack lines. The origin is `dart` or
  `rust:<target>`.
- `Logger.defaultOutput` = a shared delegating output whose `init`/`destroy` are no-ops. It forwards to the single
  `AdvancedFileOutput(path: <appSupport>/logs, latestFileName: 'kafkalyzer.log', maxFileSizeKB: 5120,
  maxRotatedFilesCount: 3)`, which is opened once. In debug GUI runs it also writes to the console. In headless
  runs it also writes warning and above to **stderr** and never to stdout.
- `debugPrint` is reassigned to log at debug level through the same logger. This routes the remaining
  52 calls without editing their files, so the files that prerequisite changes edit are not touched.
- Because the defaults change globally, the existing `getIt<Logger>()` and the five `Logger()` fallbacks write to
  the file without being edited. DI keeps registering `Logger()`.
- If the log directory cannot be created, the file output is replaced by a no-op output and `AppLogging.fileLogPath`
  is `null`. Settings and the startup screen then show "unavailable".
- Alternative: a hand-written rotating writer (~80 lines). Rejected unless spike 1.2 shows `AdvancedFileOutput`
  does not keep the rotated-file count bounded or cannot use a fixed active file name. (Spike 1.2 confirmed
  `AdvancedFileOutput` with `latestFileName: 'kafkalyzer.log'`, `maxFileSizeKB`, and `maxRotatedFilesCount: 3` keeps
  at most 1 + 3 files, rotating to `YYYY-MM-DD-HH-mm-ss-SSS.log` on `init()` when the existing file exceeds the limit.)

### D4 — Redaction and payload exclusion

`redact(String)` is a pure Dart function in `lib/src/services/diagnostics/redaction.dart`. Its regex patterns are
compiled once:
- `key = value` / `key: value` / JSON `"key": "value"` for keys matching
  `password|passwd|secret|token|api[._-]?key|sasl\.password|ssl\.key\.password|ssl\.(key|trust)store\.password|
  basic\.auth\.user\.info|sasl\.jaas\.config` (case-insensitive) → value `***`
- `Authorization: <scheme> <cred>` and `Bearer <token>` → `***`
- `-----BEGIN [A-Z ]*PRIVATE KEY-----…-----END …-----` → `[private key redacted]`
- URL user info `scheme://user:pass@` → `scheme://***@`
- the result is truncated to 4,096 characters plus a ` …[truncated]` marker.

The printer applies it to the message, the error text and each stack line. It also feeds the error-details and
diagnostics texts. A `FormatException`'s `source` (which can echo payload JSON) is not included: only
`message` and `offset` are formatted.

Payloads cannot be recognised by pattern. They are excluded at the call sites: the Fast Trace line drops the key,
and no new log call receives a `KafkaMessage` key, value or header value. Review rule in tasks: grep the diff for
log calls that receive message fields.

- Layer: Dart, not `kafkalyzer-core`. The only caller is the Dart log pipeline. A core version would need a bridge
  call per record. If the MCP server (phase 4) needs redaction later, it gets its own Rust version.

### D5 — Error capture

- `FlutterError.onError`: log it (unless `details.silent`, which is logged at debug only) and report it. In debug builds,
  also call `FlutterError.presentError` so the red-screen and console behaviour stays the same.
- `PlatformDispatcher.instance.onError`: log, report, return `true`. This covers uncaught errors of the root zone,
  so no `runZonedGuarded` is needed (it caused zone-mismatch warnings with `ensureInitialized` in Flutter ≥ 3.10).
  This is the "zone" part of the roadmap requirement.
- `ErrorReporter` (DI singleton, `ChangeNotifier`): keeps a ring buffer of the last 20 redacted `ErrorRecord`s
  (UTC time, origin, type, message, top 20 stack lines). It is fed by the handlers and by `Logger.addLogListener`
  for every error-level record (Dart and Rust). A separate `ValueNotifier<ErrorRecord?> pendingNotice` is set only
  for **uncaught** errors, at most once per 10 s per `type+message` signature. Caught errors are already reported
  by their own UI (L5).
- `MainLayout` listens to `pendingNotice` like it does to the update notifier. It shows the SnackBar on a post-frame
  callback, so an error raised before mounting is shown once mounted. "Details" opens `ErrorDetailsDialog`
  (selectable text, "Copy details"). Errors thrown while building `MainLayout` itself are only logged. A custom
  `ErrorWidget` is a non-goal.
- The handlers are wrapped in `try/catch`. A failure inside a handler is written to stderr only, never re-reported.

### D6 — Guarded startup and the startup error screen

New order in `main()`:
1. `ensureInitialized`. Decide `headless` from `args` (the existing predicate, moved into a pure function).
2. `AppLogging.init(headless:)` (never throws), then install the D5 handlers.
3. `try` { `KafkalyzerRustLib.init()` → `init_rust_logging(...)` (stream listened to by `AppLogging`) →
   `setupDependencyInjection()` → headless branch → `initializeSettings()` → `AppVersionHelper.init()` →
   `UpdateService.initialize()` } `catch (e, st)` → log fatal → in GUI mode
   `runApp(StartupErrorApp(error: e, stack: st, logPath: AppLogging.fileLogPath))`, in headless mode write it to
   stderr and `exit(3)`.
4. `runBackgroundCheck()` and `cleanupHistory()` stay fire-and-forget. Their failures reach the D5 handler.

`StartupErrorApp` is a self-contained `MaterialApp` (theme, `AppLocalizations` delegates, no DI, no Rust). It
offers "Copy details" and "Open log folder" (`FileOpenerService(logger: …)` constructed directly, since DI may be
missing). The `DEBUG:` `debugPrint` lines are removed. In headless mode, the D5 handlers write to stderr and call
`exit(3)`. That is the existing "execution runtime failure" code of `HeadlessScriptRunner`.

### D7 — Diagnostics section and report

The Diagnostics section in `settings_view.dart` sits between the cluster list and About. It shows the log path
(or "unavailable") and has the buttons "Open log folder" (`showInFolder(<active log file>)`) and "Copy diagnostics".
`DiagnosticsReport.build(...)` is a pure function (unit-tested) over an input record: version, `Platform.operatingSystem`,
`Platform.operatingSystemVersion`, locale, log path, `ClusterProfile?` from `ActiveConnectionController.activeProfile`
and `ErrorReporter.recent`. The profile summary uses only protocol, SASL mechanism, TLS verification state (field
from `restore-tls-verification`), Schema Registry URL non-empty, truststore/keystore location non-empty, and the
count of comma-separated bootstrap entries. Excluding host and profile names is deliberate: the report is meant
to be pasted into tickets. Any field that throws or is empty → `unknown`.

### D8 — Keyboard-shortcut catalogue (API for 5.4 / 5.27)

`lib/src/ui/shortcuts/app_shortcuts.dart`:

```dart
enum ShortcutContext { global, explorer, scripts, messages, inspector, inspectorSearch }

class ShortcutEntry {
  const ShortcutEntry({required this.id, required this.context, required this.keys, required this.label});
  final String id;                         // stable, e.g. 'explorer.toggleSidebar'
  final ShortcutContext context;
  final List<ShortcutKey> keys;            // alternatives, e.g. J and ArrowDown
  final String Function(AppLocalizations) label;
  List<ShortcutActivator> get activators;  // expands primaryModifier to control AND meta (current behaviour)
}

class ShortcutKey { // primaryModifier = Ctrl on Linux/Windows, Cmd on macOS (both bound everywhere, as today)
  const ShortcutKey(this.key, {this.primaryModifier = false, this.shift = false, this.character});
}

abstract final class AppShortcuts {
  static final toggleExplorerSidebar = ShortcutEntry(...);
  // ... one static field per entry
  static final List<ShortcutEntry> all = [toggleExplorerSidebar, ...];
}
```

- Sibling changes register by adding a static entry and appending it to `all`, then binding with
  `{for (final a in AppShortcuts.x.activators) a: callback}`.
- `test/src/ui/shortcuts/app_shortcuts_test.dart` checks unique ids, no activator collision inside a context or
  between a context and `global`, and a non-empty label for both `en` and `de` (via `lookupAppLocalizations`). This
  enforces the catalogue rules.
- The three `CallbackShortcuts` sites switch to catalogue activators. The `messages_view` handler compares
  `event.logicalKey` against the catalogue entries' keys instead of literals. Behaviour is unchanged
  (`messages_view_test`/`main_layout_test` must stay green).
- `F1`/`?`: `MainLayout` registers a `HardwareKeyboard` handler, the same focus-independent pattern as
  `messages_view`. `F1` always opens the overview. `?` is matched by `event.character == '?'`, which works on any
  layout (Shift+ß on German keyboards), and is ignored while a text input has focus. `_isTextInputFocused` moves to
  `lib/src/ui/focus_utils.dart` and is used by both. The handler does nothing while the overview is open or while
  another modal route is on top.
- `ShortcutOverviewDialog` groups `AppShortcuts.all` by context. Key rendering is platform-aware (`⌘B` on macOS,
  `Ctrl+B` otherwise), and key names come from ARB. Settings → About has a "Keyboard shortcuts" button.
- Alternative: a runtime `ShortcutRegistry` with register/unregister. Rejected: no shortcut is dynamic today, and a
  static list is checkable in a unit test without pumping widgets.

### D9 — About dialog

The About section in `settings_view.dart` gains "About Kafkalyzer". It calls Flutter's `showAboutDialog`
(`material_ui`) with `applicationVersion: AppVersionHelper.version` and `applicationLegalese` (licence line and
read-only notice), and its children are the repository link (`url_launcher`, `UpdateService.defaultRepositoryUrl`)
and three path rows: log folder, `getApplicationSupportDirectory()` and `general_default_output_dir`. Each path row
is selectable, with "unknown" on failure. The built-in "View licences" button opens `showLicensePage`. No new
package is needed.

## Risks / Trade-offs

- [Forwarded Rust records are lost when the process aborts or the Dart isolate is gone] → the panic line is
  written directly (D2). Errors in Dart flush immediately (`AdvancedFileOutput` flushes warning and above at once).
- [Two processes (GUI plus a headless run) append to the same file and rotate independently] → append mode keeps
  lines whole. A rotation by one process can make the other continue in a renamed file until its next rotation. This
  is accepted and recorded in a `shortcut:` comment, because concurrent GUI and CLI runs are rare.
- [Redaction misses an unknown secret format] → mitigated by the key list plus call-site rules. The redaction unit
  test covers every librdkafka/Schema Registry credential property name used in `create_config` and
  `schema_registry.rs`.
- [librdkafka floods warnings (broker down, reconnect every backoff)] → the file size is bounded by rotation.
  Recent errors are bounded at 20, and the notification is only for uncaught Dart errors, so the UI is not flooded.
- [Changing the global `Logger` defaults alters output in tests] → tests that construct `Logger()` do not call
  `AppLogging.init`, so they keep the package defaults. `AppLogging` has a `resetForTest()`.
- [`debugPrint` override swallows Flutter framework debug output in debug runs] → in debug GUI runs the shared
  output also writes to the console, so nothing visible is lost.
- [Unredacted panic message] → truncated to 200 characters. Panics with secrets are not expected in our code.

## Migration Plan

- First start after the upgrade: `rust_debug_v2.log` is deleted from the temp directory and the `logs` folder is
  created. No settings or profile data changes, and nothing needs migrating back.
- Rollback: reverting the change is safe. The `logs` folder stays behind and is harmless.

## Open Questions

- Settled by spike 1.2: `AdvancedFileOutput` rotates an existing `kafkalyzer.log` on `init()` when it exceeds
  `maxFileSizeKB` (creating `YYYY-MM-DD-HH-mm-ss-SSS.log` and keeping at most 3 rotated files plus `kafkalyzer.log`),
  and otherwise appends to it.
