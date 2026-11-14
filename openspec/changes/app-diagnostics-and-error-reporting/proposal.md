# Proposal

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.25 `app-diagnostics-and-error-reporting`,
finding A6 (§2.4), gap "Anwendung: keine globale Fehlerbehandlung, kein sichtbares Log" (§2.4 C), phase 1a (§6.1).

## Why

In the packaged app nobody sees an error that escapes a `try/catch`: `lib/main.dart` installs no
`FlutterError.onError`, `PlatformDispatcher.onError` or guarded zone, and a failing startup step (e.g. the native
library not loading) leaves an empty window. The only log the app actually writes to disk is Rust's
`rust_debug_v2.log` in the temp directory (A6), which grows without bound, records bootstrap addresses and file
paths, and is appended twice per `create_config`. Everything else is lost. The `logger` package uses its default
`DevelopmentFilter`, which drops every record in release builds, and its default `ConsoleOutput`, which prints to
stdout. Rust `log` records, including librdkafka's, go nowhere because no Rust logger is installed. Users and
maintainers therefore have no evidence to work from when something goes wrong.

## What Changes

- Global error handling: framework (`FlutterError.onError`), platform (`PlatformDispatcher.onError`) and zone
  errors are logged and shown to the user as a SnackBar with a "Details" dialog that has a "Copy details" action.
  Identical errors are throttled.
- Startup error screen: if a startup step fails (native library, DI, settings, version), a localized error screen
  with "Copy details" and "Open log folder" replaces the empty window.
- One rotating log file `kafkalyzer.log` in `<application support>/logs/` (size-capped, bounded number of rotated
  generations) for Dart and Rust. Rust `log` records, including librdkafka's, are forwarded to Dart through a
  bridge stream. A Rust panic hook writes one line directly to the same file before the process aborts. Every
  record is redacted (credentials, keys, tokens, URL user info) and truncated. Payloads (message keys, values and
  header values) are never logged.
- Removal of `rust_debug_v2.log`: the ad-hoc file appends in `kafka_utils.rs` become `log` records, and the old
  temp file is deleted once at startup. The `println!`/`eprintln!` calls in `kafkalyzer-kafka` become `log` records.
  The Fast Trace line that printed the message key loses the key.
- Headless mode (`--script`) keeps stdout for the JSON or text report only. The `DEBUG:` `debugPrint` lines in
  `main.dart`, logger console output and Rust `println!` no longer reach stdout. Warnings and errors also go to
  stderr. An uncaught error ends the run with exit code 3.
- Settings → Diagnostics: "Open log folder" (reuses `FileOpenerService.showInFolder`) and "Copy diagnostics"
  (app version, OS and version, locale, log path, active profile without secrets or host names, recent errors).
- An About dialog (version, licences via the Flutter licence page, repository link, storage locations), reachable
  from Settings.
- A central keyboard-shortcut catalogue (`AppShortcuts`). This change owns it. Existing shortcuts are
  registered there and their bindings read from it. A localized overview opens with `F1` or `?` (`?` is ignored
  while a text field has focus). Sibling changes register their shortcuts in the same catalogue.

## Capabilities

### New Capabilities
- `app-diagnostics`: global error capture and user notification, the startup error screen, the single redacted
  rotating log for Dart and Rust, headless output separation, and Settings → Diagnostics (open log folder, copy
  diagnostics).
- `keyboard-shortcuts`: the central shortcut catalogue as the single source of truth for key bindings and their
  labels, plus the `F1`/`?` overview. This is a separate capability so that later changes (5.4 command palette,
  5.27 message selection) can add requirements without growing `app-diagnostics`. This deviates from the roadmap,
  which lists only `app-diagnostics`.

### Modified Capabilities
- `app-version-display`: ADDED requirement "About Dialog" (version, licences, repository link, storage locations).
  The existing requirement is unchanged.

## Impact

- **Rust:** `rust/kafkalyzer-kafka/src/kafka_utils.rs` (file appends → `log` macros), `kafka_consumer.rs`
  (`println!`/`eprintln!` → `log`); new `rust/src/api/diagnostics.rs` (forwarding logger, panic hook, bridge
  function `init_rust_logging`, DTO `RustLogRecord`). No new crates: `log` is already a dependency, and
  `env_logger` stays unused.
- **Bridge:** one new stream function and one DTO, added alongside the existing API. Regenerated
  `frb_generated.*` and the checked-in mocks.
- **Dart:** `lib/main.dart` (guarded startup, handlers, headless separation), `lib/src/dependency_injection.dart`
  (logger defaults), new `lib/src/services/diagnostics/` (log setup, redaction, error reporter, diagnostics
  report), `lib/src/ui/main_layout.dart` (error SnackBar, shortcut overview), `lib/src/app.dart`,
  `settings_view.dart` (Diagnostics section, About button), the three existing `CallbackShortcuts` sites,
  en+de ARB.
- **Dependencies:** none added. The installed `logger` 2.6.2 (`AdvancedFileOutput`), `path_provider`,
  `url_launcher`, `package_info_plus` and Flutter's `showAboutDialog`/`showLicensePage` cover everything.
- **Read-only impact:** no new Kafka or Schema Registry calls. `scripts/check_read_only.sh` must pass unchanged.
  The Rust logger uses `StreamSink::add`, not `.send(`.
- **Prerequisites (implemented first):** `restore-tls-verification` (rewrites `create_config` and adds the probe's
  `ClientContext`; this change then converts the remaining debug-file appends in its result and does not touch TLS
  policy), `harden-local-storage-and-imports` and `fix-result-view-defects` (both replace some `debugPrint` calls
  with `logger` in files this change does not edit; with this change those records reach the log file).
  `harden-read-only-gate` and `fix-consumer-lag-accuracy` do not overlap.
- **Coordination with siblings:** 5.4 `command-palette` and 5.27 `message-selection-copy-and-display` register their
  shortcuts in `AppShortcuts`. 5.31 shows other settings next to the new Diagnostics section. Hard-coded strings
  outside this change's new UI stay with 5.32.

## Non-Goals

- Crash reporting or telemetry sent off the machine, automatic upload of logs, or a "send report" service.
- An in-app log viewer, log level UI, or a "verbose logging" toggle (developers can use the `KAFKALYZER_LOG_LEVEL`
  environment variable, see design).
- Native crash dumps (minidumps) for faults inside librdkafka/OpenSSL C code.
- A custom `ErrorWidget` for build failures after startup (errors are still reported through the global handler).
- Staged connection diagnostics and librdkafka `debug` contexts (5.3 `connection-diagnostics`); TLS policy and the
  "insecure" marker (`restore-tls-verification`).
- Converting every remaining `debugPrint` call by hand. They are routed into the logger globally instead.
- Remapping or adding shortcuts beyond `F1`/`?`. Command palette shortcuts belong to 5.4.
