# Tasks

Prerequisites: `restore-tls-verification`, `harden-local-storage-and-imports` and `fix-result-view-defects` are
merged first (see proposal). Group 2 works on the `create_config` produced by `restore-tls-verification`.

## 1. Spikes

- [ ] 1.1 Spike the forwarding logger in a scratch branch: a global `log::Log` in the bridge crate holding a
      `Mutex<Option<StreamSink<…>>>`, fed by `log::warn!` from a `std::thread::spawn` thread and by librdkafka (connect
      to an unreachable broker so `DefaultClientContext::log` fires), plus a second `init` call (Dart hot restart).
      Verify: records arrive in Dart in both cases, the second init replaces the sink without error, the code compiles
      with frb 2.11.1 (`StreamSink` is `Send` behind the mutex), and the result is noted in design.md D1.
- [x] 1.2 Spike `AdvancedFileOutput` (logger 2.6.2) in a unit test with a temp dir: fixed `latestFileName`,
      `maxFileSizeKB`, `maxRotatedFilesCount: 3`, restart behaviour (append to or rotate the existing file), and file
      names of rotated files on Linux. Verify: the test shows that at most 1 + 3 files exist after writing 5× the
      limit; the decision (use it vs. the own writer in D3) and the restart behaviour are written into design.md D3 and
      Open Questions are updated.
- [x] 1.3 Record RED evidence for the headless stdout defect: `flutter build linux --debug`, then
      `build/linux/x64/debug/bundle/kafkalyzer --help > out.txt`. Verify: `out.txt` contains `DEBUG: main() started`
      (expected today). Keep the command for task 6.4.
- [ ] 1.4 Spike the release panic path on Linux: a temporary bridge function that panics, a release build, and the
      D2 hook appending to a temp file. Verify: the line is in the file after the process aborts. Remove the temporary
      function afterwards.

## 2. Rust: `kafkalyzer-kafka` logs through `log`

- [x] 2.1 In `kafka_utils.rs` remove both `temp_dir()/rust_debug_v2.log` opens and the `Option<File>` parameter of
      `init_providers`. Turn every `writeln!(f, …)` into a `log::debug!` (provider loading, bundled CA lookup,
      truststore/keystore location) or `log::warn!` (PKCS#12 decode/parse failures, missing keystore file), and never
      log a password. Turn `println!("Using bundled CA cert…")` into `log::info!`. Verify:
      `rg -n "rust_debug|OpenOptions|temp_dir|println!" rust/kafkalyzer-kafka/src/kafka_utils.rs` is empty and
      `cargo test -p kafkalyzer-kafka` passes (including the `create_config` tests from `restore-tls-verification`).
- [x] 2.2 In `kafka_consumer.rs` replace `eprintln!`/`println!` with `log` macros (`warn!` for pause failures and
      Schema Registry subject errors, `debug!` for "all partitions done" and `log_to_dart`). The Fast Trace line logs
      topic, partition count and the computed partition, **without the key**. Verify:
      `rg -n "println!|eprintln!" rust/kafkalyzer-kafka/src rust/kafkalyzer-core/src` is empty and
      `cargo test -p kafkalyzer-kafka` passes.

## 3. Rust bridge crate: forwarding logger and bridge regeneration

- [x] 3.1 Add `rust/src/api/diagnostics.rs` (registered in `api/mod.rs`): DTO `RustLogRecord { level: RustLogLevel,
      target, message, timestamp_ms }`, enum `RustLogLevel { Error, Warn, Info, Debug, Trace }`, and
      `init_rust_logging(sink: StreamSink<RustLogRecord>, max_level: RustLogLevel, log_file_path: String)`. It installs
      the logger once (`OnceLock`), replaces the sink on re-init, sets `log::set_max_level`, cuts messages to 4,096 bytes,
      drops the sink on a failed `add`, chains the D2 panic hook (≤ 200-char message, append to `log_file_path`) and
      deletes `std::env::temp_dir()/rust_debug_v2.log` if present. Use `sink.add`, never `.send(`. Verify: unit tests
      for truncation, level mapping, the legacy-file deletion (temp dir override via a helper taking the dir) and the
      panic-line formatter pass with `cargo test -p rust_lib_kafkalyzer`.
- [x] 3.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `initRustLogging`
      and `RustLogRecord` appear in `lib/src/rust/api/diagnostics.dart`, the checked-in mocks are regenerated, and
      `flutter analyze` reports no new issues.

## 4. Dart: logging pipeline, redaction, error reporter

- [x] 4.1 Write `lib/src/services/diagnostics/redaction.dart` (`redact`, patterns compiled once, 4,096-char
      truncation with a marker) test-first. Verify: `test/src/services/diagnostics/redaction_test.dart` covers each
      credential key used in `create_config` and `schema_registry.rs` (`sasl.password`, `ssl.key.password`,
      `ssl.keystore.password`, `ssl.truststore.password`, `basic.auth.user.info`, `sasl.jaas.config`),
      `Authorization: Bearer`, PEM private key blocks, URL user info, JSON-style keys, truncation, and an untouched
      harmless line. It fails before the implementation and passes after.
- [x] 4.2 Write `lib/src/services/diagnostics/app_logging.dart`: `AppLogging.init({required bool headless})` that
      never throws. It sets `Logger.defaultFilter/defaultPrinter/defaultOutput` and `Logger.level` (release info,
      otherwise debug, overridable by `KAFKALYZER_LOG_LEVEL`), opens the shared file output in
      `<appSupport>/logs/kafkalyzer.log` (falling back to a no-op output with `fileLogPath == null`), adds console
      output in debug GUI runs and stderr output (warning and above) in headless runs, reassigns `debugPrint`, exposes
      `attachRust(Stream<RustLogRecord>)` (maps level, origin `rust:<target>`) and has `resetForTest()`. Verify:
      `app_logging_test.dart` with a temp dir and injected stderr/stdout sinks shows that a Dart record and a fake
      Rust record land in the same file with UTC timestamp, level and origin, that a secret is masked, that headless
      mode writes nothing to the stdout sink and writes warning and above to the stderr sink, and that an unwritable
      directory yields `fileLogPath == null` without throwing.
- [x] 4.3 Write `lib/src/services/diagnostics/error_reporter.dart` (`ErrorReporter` ChangeNotifier: ring buffer of 20
      redacted `ErrorRecord`s, `pendingNotice` with a 10 s throttle per type+message, feeding from
      `Logger.addLogListener` for error level). Register it in `dependency_injection.dart`. Verify: unit tests for
      buffer cap, throttle (50 identical in 10 s → one notice, 50 buffered records capped at 20), the notice after
      the window expires, and `FormatException` formatting without `source`.
- [x] 4.4 Write `lib/src/services/diagnostics/diagnostics_report.dart` (pure `DiagnosticsReport.build`) per design
      D7. Verify: unit tests for connected profile (no host, profile name, user name, path or secret in the output),
      no profile, `unknown` fields, and no recent errors.

## 5. en + de ARB

- [x] 5.1 Add keys to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for: error SnackBar text and "Details" action,
      error details dialog title, "Copy details", copy confirmation and copy failure, startup failure screen
      (title, body, log path label, "unavailable"), Settings Diagnostics section (title, log path label, "Open log
      folder", "Copy diagnostics", log-folder error with path placeholder, file logging unavailable), "unknown",
      About button and dialog texts (repository, log folder, data folder, output folder, legalese, link failure),
      "Keyboard shortcuts" button and overview title, context names, one description per catalogue entry, and
      special-key names. Verify: `flutter gen-l10n` succeeds and both ARB files have the same key set (`jq 'keys'` diff
      is empty).

## 6. Dart: global handlers, startup screen, headless separation

- [x] 6.1 Add `lib/src/services/diagnostics/error_handlers.dart` (`installErrorHandlers({required bool headless,
      required ErrorReporter reporter})`): `FlutterError.onError` (still calls `presentError` in debug; silent errors
      at debug level only), `PlatformDispatcher.instance.onError` (returns `true`), handler bodies in `try/catch`,
      and in headless mode stderr plus `exit(3)` through an injectable exit function. Verify: unit tests drive both
      handlers and assert the log record, the reporter notice and the headless exit code 3.
- [x] 6.2 Add `lib/src/ui/startup_error_app.dart` (standalone `MaterialApp`, ARB strings, "Copy details",
      "Open log folder" through a directly constructed `FileOpenerService`, log path or "unavailable"). Verify: widget
      tests for rendering, copy (mock clipboard channel) and the unavailable-log case.
- [x] 6.3 Restructure `lib/main.dart` per design D6: pure `isHeadlessInvocation(args)`, `AppLogging.init` and the
      handlers first, everything up to `UpdateService.initialize` inside `try/catch` → `StartupErrorApp` (GUI) or
      stderr plus exit 3 (headless), `initRustLogging` attached right after `KafkalyzerRustLib.init()`, and the
      `DEBUG:` lines removed. Verify: unit test for `isHeadlessInvocation`, plus `flutter test
      test/src/features/scripting/` still passes.
- [x] 6.4 Show uncaught-error notices in `MainLayout`: listen to `ErrorReporter.pendingNotice` (same pattern as the
      update notifier, post-frame), SnackBar with "Details" → `ErrorDetailsDialog` (selectable redacted text, "Copy
      details" with confirmation or failure message). Verify: `main_layout_test.dart` gains tests for notice → SnackBar,
      details dialog and copy. Rerun the 1.3 command on a fresh debug build and check that stdout contains only
      the help text.

## 7. Dart: Settings → Diagnostics and About

- [x] 7.1 Add the Diagnostics section to `settings_view.dart` (log path or "unavailable", "Open log folder" via
      `FileOpenerService.showInFolder` with an error SnackBar on `false`, "Copy diagnostics" with confirmation).
      Verify: widget test `test/src/features/settings/settings_diagnostics_test.dart` with a mocked
      `FileOpenerService` covers success, failure and copy.
- [x] 7.2 Add "About Kafkalyzer" to the About section: `showAboutDialog` with version, legalese, repository link
      (`url_launcher`, failure SnackBar), selectable log, data and output paths ("unknown" on failure), and the built-in
      licences button. Verify: widget test opens the dialog, finds version, repository link and three path rows, and
      opens the licence page.

## 8. Dart: keyboard-shortcut catalogue and overview

- [x] 8.1 Add `lib/src/ui/shortcuts/app_shortcuts.dart` (`ShortcutContext`, `ShortcutKey`, `ShortcutEntry`,
      `AppShortcuts` with the entries listed in the `keyboard-shortcuts` spec, `all`) and a doc comment on how sibling
      changes register entries. Verify: `test/src/ui/shortcuts/app_shortcuts_test.dart` checks unique ids, no
      activator collision within a context or with `global`, non-empty `en` and `de` labels, and that the check fails
      for a deliberately conflicting test entry.
- [x] 8.2 Move `_isTextInputFocused` from `messages_view.dart` to `lib/src/ui/focus_utils.dart`. Switch the
      `CallbackShortcuts` in `explorer_view.dart`, `script_manager_view.dart` and `message_inspector_panel.dart`, and
      the key comparisons in `messages_view.dart`, to catalogue entries. Verify: the existing messages view, inspector,
      explorer and script manager widget tests pass unchanged.
- [x] 8.3 Add `ShortcutOverviewDialog` (grouped by context, platform-aware `⌘`/`Ctrl` rendering, localized key
      names) and the `F1`/`?` `HardwareKeyboard` handler in `MainLayout` (`?` via `event.character`, ignored while
      text is focused, no second dialog, inactive under another modal route), plus a "Keyboard shortcuts" button in
      Settings → About. Verify: widget tests for F1 opening, `?` in a `TextField` inserting the character, `?` outside
      text opening, no double open, and macOS vs. Linux rendering via `debugDefaultTargetPlatformOverride`.

## 9. Final verification

- [x] 9.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`. Verify:
      all pass without new warnings.
- [x] 9.2 `dart format .`, `flutter analyze`, `flutter test`. Verify: no analyzer issues and all tests green.
- [x] 9.3 `scripts/check_read_only.sh`. Verify: passes unchanged (no new exception).
- [x] 9.4 Payload/secret review: `git diff` the change for every logger, `log::` or `debugPrint` call that receives
      `KafkaMessage` key/value/header fields or profile secrets. Verify: none found; result noted in the PR description.
- [ ] 9.5 Manual check on Linux (debug and release bundle): an uncaught error triggered from a debug action shows the
      SnackBar and details. Renaming the native library shows the startup failure screen. `kafkalyzer.log` contains
      Dart and `rust:librdkafka` lines after connecting to an unreachable broker. `/tmp/rust_debug_v2.log` is gone
      after start. `kafkalyzer --script <s> --cluster <c> --json | jq .` parses. F1 and `?` behave as specified.
      Verify: observations noted in the PR description.
