# Design

## Context

See proposal.md (Why). Verified state of the code:

- **Theme:** `ThemeController` (`lib/src/theme_controller.dart`) holds one `ThemeMode`. It starts as `dark`, loads
  the bool key `theme_mode` asynchronously in its constructor (default `false` → light) and then notifies. Users
  without a stored value therefore see a dark first frame and then light: the flash. Used by `app.dart`,
  `main_layout.dart` (rail toggle, `isDarkMode`), DI and `test/src/ui/main_layout_test.dart`.
- **Language:** `MaterialApp.router` sets no `locale:`, so the platform locale is used. Locale-dependent
  formatting already reads `Localizations.localeOf(context)` (`date_format_utils.dart`, `consumer_lag_view.dart`),
  so a `locale:` switch reaches it.
- **Settings page** (`settings_view.dart:127-276`): `FutureBuilder<SharedPreferences>` with a new
  `SharedPreferences.getInstance()` future in every build. Four `TextEditingController`s are recreated in every
  builder call and never disposed. Number fields store any `int.tryParse` result (negative values included). The
  helper text `"Default: 30"` is hard-coded.
- **Consumers of the number settings** read the raw preference without a range check:
  `consumer_lag_view.dart:139` (`consumer_max_concurrent_queries`; 0 would block every lag query) and
  `script_runner.dart:1046` (`scripting_max_run_history`; `<= 0` turns cleanup off, an undocumented
  "keep all"). `SettingsService.lagWarnThreshold()` already clamps negative values to 0.
- **Result limit 200** is hard-coded in `ActiveConnectionController.streamTopicWithDefaults`
  (`active_connection_controller.dart:172`) and in `TopicDetailView` (`_maxResultsController` initial `"200"`,
  `:164`; fallback and minimum in the jump-to-duplicate path, `:103-104`). `TopicSearchPreset` (`'200'` default and
  `fromJson` fallback) and `ScriptStepEditor` (`"200"` prefill) keep their own values (spec: saved searches and
  steps keep their limits).
- **Config export/import** writes every preference and restores every key unchanged
  (`settings_service.dart` `importConfiguration`). Imported appearance and number values may therefore have any
  value or type.
- **Window:** no window plugin in `pubspec.yaml`. Runners hard-code 1280×720 (Linux `gtk_window_set_default_size`,
  Windows `origin(10,10)`/`size(1280,720)`, macOS nib frame). Nothing stores geometry. Linux and Windows show the
  window on the first Flutter frame (`my_application.cc:19`, `flutter_window.cpp:30`); macOS shows it from the nib.
- **Updates:** `UpdateService.isEnvironmentSupported` requires an initialized Velopack and `$APPIMAGE` on Linux.
  Otherwise `checkForUpdates` returns `unsupportedEnvironment`, and the dialog shows a releases link without
  looking up any version. `runBackgroundCheck` publishes `ValueNotifier<UpdateInfo?>` (Velopack type), which
  `MainLayout` turns into a snackbar. In `UpdateDialog` the downloading state has no actions, and
  `barrierDismissible: false`, so it cannot be left. `dispose` cancels the Dart subscription only.
- **Vendored `packages/velopack_flutter/rust/src/api/velopack.rs`** (velopack 1.2.0):
  `check_and_download_updates_with_progress` calls the blocking `um.download_updates(&updates, Some(sx))` and only
  then starts the thread that forwards `rx` to the `StreamSink`. All progress events are buffered and arrive after
  the transfer, so the bar sits at 0 % and then jumps to 100 %. That breaks the existing spec ("streams the
  download progress from 0% to 100%"). velopack 1.2.0 has no cancellation hook: `download_updates` reads to EOF,
  and failed progress sends are ignored. `init_app` runs `VelopackApp::build().run()`, whose `auto_apply` defaults
  to `true`, so a downloaded but unapplied package is applied on the next start without asking.
- **Release packaging** (`.github/workflows/build.yml`): CI publishes only Velopack artifacts (AppImage, macOS,
  Windows). deb/tar are not built in CI. A `snap/snapcraft.yaml` exists but is not in CI. Builds without
  self-update are therefore self-built tar/deb, a snap, or `flutter run`. CI dev builds have versions like
  `1.4.0-dev123.abc1234+123`. `flutter run` reports the pubspec version `1.0.0+1`.

## Goals / Non-Goals

**Goals:**
- Appearance values are read before `runApp`. Each persisted value has exactly one owner that reads, validates
  and writes it.
- One table of number-setting descriptors (key, default, min, max). The Settings field and every consumer use it.
- Window geometry with a debounced save and a restore before the window is shown.
- Honest cancel semantics within what velopack 1.2.0 allows.

**Non-Goals (design level):**
- No generic settings framework, no settings schema migration beyond the legacy theme key.
- No change to the bridge crate `rust/`, the `kafkalyzer-*` crates or any Kafka code path.
- No own HTTP download implementation replacing Velopack's.

## Decisions

### D1 — Layering: Dart only, plus a two-line patch in the vendored Velopack fork
Everything here is UI state, local preferences, window integration or an HTTPS GET for release metadata. None of
it has a second caller (MCP/headless do not show settings or update), so per the project rule nothing moves to
`kafkalyzer-core`. The GitHub release check stays in Dart (`package:http`, already a dependency): `kafkalyzer-kafka`
is the I/O crate for Kafka and the registry, and a bridge function for a single unauthenticated GET would add a DTO
and a codegen run for no gain. The only Rust edit is in `packages/velopack_flutter/rust` (D8). Its function
signatures stay unchanged, so neither bridge needs regenerating.

### D2 — `AppearanceSettings` replaces `ThemeController`
New `lib/src/services/appearance_settings.dart`: a `ChangeNotifier` with `themeMode` (`ThemeMode`), `locale`
(`Locale?`, `null` = system), and `textScale` (`double`, 0.8–1.5, default 1.0). It has `Future<void> load()`,
setters that persist and notify, `resetToDefaults()`, and `toggleBrightness(Brightness shown)` for the rail
button. Keys: `appearance_theme_mode` (`system|light|dark`), `appearance_locale` (`system|en|de`),
`appearance_text_scale` (double).
- **Legacy key:** if `appearance_theme_mode` is absent and `theme_mode` is a `bool`, `true` → dark and `false` →
  light. The legacy key is neither written nor deleted, so a downgrade still finds its last value. A
  never-toggled install gets System (decision: System is the right default for new installs. The visible change
  for an existing user who never toggled is light → OS brightness. Accepted, and mentioned in the release notes).
- **Tolerant reads:** `prefs.get(key)` plus a type check; wrong type, unknown or out of range → default, without
  rewriting. A small `_read<T>` helper, unit-tested.
- **Startup:** registered in DI. `main.dart` awaits `load()` after the headless branch and before `runApp`, next to
  `TimeDisplaySettings.load()` from §5.27. Until `load()` completes, the in-memory values are the defaults; nothing
  renders before then.
- `app.dart`: `themeMode: s.themeMode`, `locale: s.locale`, and `builder:` wraps the router child in
  `MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * s.textScale)))`. The
  user factor multiplies the OS factor (spec "on top of the operating system's text scaling").
- Rail button (`main_layout.dart`): reads `Theme.of(context).brightness` and calls `toggleBrightness`.
  `main_layout_test.dart` is adapted to the new keys and the legacy key.
- *Alternatives:* keep `ThemeController` and add locale/text scale to it. Rejected: the name would lie, and all
  three call sites change anyway. Store in `SettingsService`: rejected for the same reason §5.27 gives (async-only,
  no listeners).
- Text size UI: a `DropdownMenu` with the presets 80/90/100/110/125/150 %. Presets avoid a slider that rebuilds
  the whole app on every drag step. Stored values between presets (for example from an import) are kept if they are
  in range and shown as "custom".

### D3 — Number settings: one descriptor table in `SettingsService`
```dart
class IntSetting { final String key; final int defaultValue, min, max; }
static const maxRunHistory = IntSetting('scripting_max_run_history', 30, 0, 1000);   // 0 = keep all (existing)
static const maxConcurrentLagQueries = IntSetting('consumer_max_concurrent_queries', 5, 1, 20);
static const lagWarnThreshold = IntSetting(lagWarnThresholdKey, 0, 0, 1000000000000);
static const defaultResultLimit = IntSetting('default_result_limit', 200, 1, 100000);
int readInt(SharedPreferences p, IntSetting s);  // missing/wrong type/out of range → default, no rewrite
int? parseInt(String text, IntSetting s);        // field validation; null = invalid
Future<void> writeInt(IntSetting s, int v);      // asserts range
```
- `consumer_lag_view.dart` and `script_runner.dart` call `readInt`. `lagWarnThreshold()`/`setLagWarnThreshold()`
  keep their signatures and delegate. Keeping 0 for run history preserves the existing "keep all" behaviour: a
  range starting at 1 would turn a stored 0 into 30 and make the next cleanup delete runs.
- `defaultResultLimit` also gets a `ValueNotifier<int>` (same pattern as §5.29's `messageBufferLimit`), loaded in
  `initializeSettings()` and after `importConfiguration()`. `streamTopicWithDefaults` and `TopicDetailView`
  (initial text and the jump-to-duplicate minimum) read it synchronously. If §5.29 has landed, its
  `messageBufferLimit` may be moved onto `IntSetting` too, but only if that is a pure refactor. Its range and
  behaviour stay owned by §5.29.
- *Alternative:* a full typed settings model with freezed. Rejected: four ints do not justify codegen.

### D4 — Settings page structure and the controller fix
Sections, top to bottom: **Appearance** (theme `SegmentedButton`, language `DropdownMenu`, text size
`DropdownMenu`, time display `SegmentedButton` bound to §5.27's `TimeDisplaySettings`), **General** (output
directory, default result limit, then max run history | max concurrent lag queries in one row as the spec
requires, lag warning threshold, buffer limit from §5.29, restore tabs), **Configuration**, **Cluster
configuration**, **Diagnostics** (§5.25, between clusters and About), **About & updates**. Appearance and General
each have a section header with a `TextButton` "Reset to defaults", which opens a confirmation `AlertDialog`.
- The General content becomes a `StatefulWidget` (`_GeneralSettingsSection`). It loads `SharedPreferences` once in
  `initState`, owns its controllers and disposes them. Each number field is an `_IntSettingField(setting)` that
  validates with `parseInt` in `onChanged`, shows a localized `errorText` ("Enter a whole number from {min} to
  {max}"), writes only valid values, and shows the range and default in the helper text. This removes the
  per-build controller leak and the hard-coded `"Default: 30"`.
- Reset General: `writeInt` defaults for the four settings, restore tabs `true`, §5.29's
  `setMessageBufferLimit(default)` when present, and the output directory recomputed by the existing default logic
  of `initializeSettings()`. That logic is extracted into `defaultOutputDirectory()`, and the directory is created
  if missing. Then `MultiSearchController.loadDirectory()`. Reset Appearance:
  `AppearanceSettings.resetToDefaults()` + `TimeDisplaySettings` set to local. Neither touches profiles, secrets,
  scripts, searches or `window_state_v1`.
- *Alternative:* one global "reset all settings". Rejected: the roadmap asks for per-section reset, and a global
  reset invites deleting data by mistake.

### D5 — Window plugin: `window_manager` (spike S1 confirms)
`window_manager` (leanflutter, used with `screen_retriever` for display bounds) supports Linux (GTK3), Windows and
macOS. It offers bounds, maximize, a `WindowListener` for move/resize/maximize events, and `setTitle` (the §5.26
hook). New `lib/src/services/window_state_service.dart`:
- **Restore** (in `main.dart` after the headless branch, before `runApp`): `windowManager.ensureInitialized()`,
  read `window_state_v1` (JSON `{x, y, width, height, maximized}`, tolerant parse). Use
  `screen_retriever.getAllDisplays()` to check that at least a 100×50 px strip at the top of the saved rect is
  visible on some display; otherwise centre on the primary display. Clamp the size to ≥ 640×480 and ≤ the display's
  visible size. Then `setBounds`, `maximize()` if saved, and show (D5a). Each step is wrapped in `try/catch` that
  logs and continues, so the window always gets shown (spec: integration failure).
- **Save:** a `WindowListener` restarts a 500 ms `Timer` on `onWindowResize/Move/Maximize/Unmaximize`. When it
  fires, while not maximized, minimized or full screen, it stores `getBounds()` and `maximized=false`. While
  maximized it only sets `maximized=true` and keeps the last normal bounds. The debounce means a Velopack restart,
  a crash or a close loses at most the last 500 ms; no close interception (`setPreventClose`) is needed.
- **Wayland:** `Platform.isLinux && Platform.environment['WAYLAND_DISPLAY'] != null` (refined by S1, for example
  XWayland vs. native GDK backend) → position is neither stored nor set; size and maximized only.
- **D5a, show without a jump:** Linux/Windows already show on the first frame. Bounds set before `runApp` take
  effect before that. macOS shows from the nib and needs the plugin's hidden-at-launch pattern
  (`MainFlutterWindow`: `hiddenWindowAtLaunch()` override) plus an explicit `show()`. Exact runner edits per
  platform are an S1 output. If S1 shows Linux/Windows also need hidden start, the runner edit is the
  plugin-documented one.
- **Coordination with §5.25:** its `StartupErrorApp` path must still show the window. The window is shown in a
  `finally` of the restore step, before any later startup step can fail.
- **Velopack:** Velopack hooks (`VelopackApp::build().run()`) run inside `initializeVelopack` after the window
  exists. Hook-only launches (install/uninstall) exit in Rust before the user sees anything relevant. S1 checks
  that an AppImage/Windows-installer launch with the plugin still applies and restarts.
- *Alternatives:* (a) native code in all three runners writing geometry to a file. Rejected: three platform
  implementations plus a Dart channel for display bounds, which is more code than the plugin. (b)
  `bitsdojo_window`: replaces the window frame, so out of scope. (c) `window_size` (flutter-desktop-embedding):
  not published on pub.dev.

### D6 — Release lookup for installs without self-update
`UpdateService` gets an injectable `http.Client` and `String Function() currentVersion` (defaults:
`http.Client()`, `AppVersionHelper.version`). When the Velopack path ends in `unsupportedEnvironment`, it calls
`client.get(Uri.https('api.github.com', '/repos/GreenHopper/kafkalyzer/releases/latest'), headers: {Accept:
application/vnd.github+json, User-Agent: Kafkalyzer/<version>})` with a 10 s timeout. It never calls `.send(`,
which would trip the read-only gate.
- **Parse:** `tag_name`, `html_url`, `body`. `html_url` is accepted only if it starts with
  `https://github.com/GreenHopper/kafkalyzer/`, otherwise `releasesUrl` is used (trust boundary: the URL is opened
  in the browser). Non-200, 403/429 (rate limit), timeout or invalid JSON → `failed` with a message, never
  `upToDate`.
- **Compare:** `major.minor.patch` only. The pre-release and build suffix of the running version are dropped, so
  `1.4.0-dev123.abc+123` counts as 1.4.0: a dev build made after tag 1.4.0 is not told that 1.4.0 is newer. An
  unparsable running version or `DEV` → `latestKnown` (spec: running version unknown).
- **Result model:** `UpdateCheckStatus` gains `manualUpdateAvailable`, `manualUpToDate` and `latestKnown`.
  `UpdateCheckResult` gains `latestVersion`, `releaseUrl` and `releaseNotes`. The notifier becomes
  `ValueNotifier<AvailableUpdate?>` with `{String version; bool canAutoApply}`. `MainLayout` uses `version` for the
  existing snackbar; the action still opens `UpdateDialog`.
- **Background:** `runBackgroundCheck` skips the GitHub lookup when `kDebugMode` (`flutter run` would always
  report pubspec 1.0.0 as outdated) and publishes only `updateAvailable`/`manualUpdateAvailable`. Failures are only
  logged (existing spec).
- **Dialog:** new state `manualAvailable` (version chip, notes, actions Close + "Open release page"),
  `manualUpToDate` (reuses the up-to-date content plus a hint that updates are manual), `latestKnown`. The existing
  `unsupportedEnvironment` state remains for when even the lookup cannot run. The `error` state already has Retry +
  releases link.
- *Alternatives:* Atom feed `releases.atom` (no rate limit, but XML parsing for one field); bridge function in
  Rust. Rejected: see D1. The unauthenticated limit (60 requests/h per IP) is far above one call per start plus
  manual checks.

### D7 — Download ownership and cancel
The download moves from the dialog into `UpdateService`, which outlives the dialog: `ValueNotifier<DownloadState>`
with `idle | running(progress) | finished | failed(msg)` and a `cancelled` flag.
- `startDownload()`: if a transfer is running (also a cancelled one), clear `cancelled` and return; the dialog
  shows its progress (spec: no second transfer). Otherwise subscribe to `downloadWithProgress()` and keep the
  subscription until `onDone`. The subscription is never cancelled early, because the end of the stream is the only
  "transfer finished" signal.
- `cancelDownload()`: set `cancelled`. Events are ignored from then on; on `onDone`, the state goes to `idle`
  instead of `finished`. The dialog's Cancel button calls it, closes, and shows a SnackBar ("Download cancelled.
  The update will not be installed."). `applyAndRestart()` is offered only from `finished` and not cancelled.
- The dialog's `dispose` no longer cancels anything. Closing the app during a running transfer ends the process;
  Velopack resumes nothing, and the `.partial` file is cleaned up by Velopack on the next download.
- *Alternatives:* (a) real abort by reimplementing the download in the fork (own HTTP loop, checksum, lock,
  packages dir). Rejected: copies Velopack internals and their delta logic. (b) Run in a separate isolate and kill
  it. Rejected: flutter_rust_bridge runs Rust on its own thread pool, so killing a Dart isolate does not stop the
  Rust thread.

### D8 — Vendored fork patch (spike S2 confirms)
In `packages/velopack_flutter/rust/src/api/velopack.rs`:
1. Start the forwarding thread **before** `um.download_updates(...)`, so progress reaches Dart while the transfer
   runs. The sink is dropped when `sx` is dropped after the download, which ends the Dart stream.
2. `init_app`: `VelopackApp::build().set_auto_apply_on_startup(false).run()`. A downloaded package is then applied
   only by `updateAndRestart()`. This holds the existing "Apply Update and Restart … upon user confirmation"
   requirement and the new "cancelled package is not applied on the next start". A finished package is kept as
   "pending" by Velopack's cleanup and reused (`download_updates` skips existing files) when the user downloads
   again.

Both changes keep the bridge signatures, so the fork's generated code stays as it is. `KAFKALYZER_PATCHES.md`
lists the patch. Lock behaviour (a second `download_updates` while one holds the exclusive lock fails) cannot occur
because of D7.

## Risks / Trade-offs

- [`window_manager` does not build with Flutter 3.50 / material_ui setup, or misbehaves on one platform] → S1 runs
  first. Fallback: per-platform opt-out (`WindowStateService` becomes a no-op there and the runner default stays).
  The spec's integration-failure scenario already covers this at runtime.
- [Wayland detection wrong (XWayland reports positions that are not honoured)] → S1 measures. Worst case the
  position is ignored by the compositor, which is harmless.
- [Snap strict confinement blocks the plugin or the HTTPS call] → snap is not in CI. The `network` plug exists;
  S1 notes whether a snap build was tried. Failure shows as "lookup failed" (spec), not as up to date.
- [Default theme changes from light to System for users who never toggled] → accepted (D2), mentioned in the
  release notes.
- [Cancelled transfer keeps using bandwidth until it finishes] → stated in the design, not hidden. The user sees no
  further prompt. A real abort needs an upstream Velopack feature (open question).
- [Turning off Velopack auto-apply changes behaviour for users who downloaded and quit without restarting] → they
  are now asked again via the startup check (the package is reused, so no new download). This matches the existing
  spec ("upon user confirmation").
- [Text scale 150 % overflows dense layouts] → the cap is 150 %. Layout fixes at large scales belong to §5.32;
  `flutter test` covers no overflow at 150 % only for the Settings page.
- [GitHub API response format changes] → parsing is defensive; a failure is shown as a failure.

## Migration Plan

- No data migration. New keys are added; the legacy `theme_mode` is read once and left in place. Older versions
  ignore the new keys, so rollback is safe. A downgrade restores the hard-coded window size and the light/dark-only
  theme.
- Exported configurations now carry the new keys, which import validates through the tolerant reads.
- Release notes: default theme now follows the system, window position is remembered, and manual installs get an
  update hint.

## Open Questions

- Whether Velopack upstream accepts a cancellation hook for `download_updates`. It would turn D7's "detach" into a
  real abort without spec changes.
- Whether a snap build of the app is published at all; if not, the snap mention stays in the docs only.
