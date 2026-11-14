# Proposal

## Why

Roadmap §5.31 (`appearance-window-and-update-settings`), findings §2.4 C ("Anwendung"): the Settings page has no
theme, language or text-size choice, the window forgets its size and position, number fields accept any value, and
installs that cannot update themselves are never told that a newer version exists (open since
`feature-gap-analysis.md` C9). A running update download cannot be cancelled. The code also shows defects: the app
starts dark and then switches to light (theme flash), and the update progress bar stays at 0 % until the download
has finished.

## What Changes

- **Appearance section** in Settings: theme (System / Light / Dark), language (System / English / Deutsch), text
  size, and the local/UTC time display control. The time setting and its notifier belong to
  `message-selection-copy-and-display` (§5.27, capability `message-timestamp-display`); this change only places
  its control here. The theme is loaded before the first frame, so the startup flash goes away. The rail button
  stays as a quick light/dark toggle.
- **General section**: a new **default result limit** (default 200) replaces the hard-coded `maxResults: 200` in
  `streamTopicWithDefaults` and the `"200"` initial value in `TopicDetailView`. Every number field is checked
  against a range, shows an inline error and stores only valid values. Stored or imported values outside the range
  are ignored and the default is used. The buffer-limit field of `live-tail-controls` (§5.29) sits in this section
  and keeps its own validation.
- **Reset to defaults** per settings section (Appearance, General), with a confirmation. It never touches profiles,
  secrets, scripts or saved searches.
- **Window state**: size, position and maximized state are saved while the app runs and restored on the next start.
  A position that is no longer on any screen falls back to a centred window. This needs a window plugin
  (`window_manager`, checked in a spike first).
- **Update notice for installs without self-update** (deb/tar/snap builds, unpackaged runs): a read-only HTTPS GET
  to the GitHub Releases API finds the latest release. The manual check and the startup check then show
  "version X available" with a link to the release page. A failed check is never shown as "up to date".
- **Cancellable download**: the downloading state gets a Cancel action. velopack 1.2.0 cannot abort a transfer. So
  Cancel stops tracking it, and the package is never applied without a new confirmation. The vendored fork turns
  off Velopack's "apply on startup" to make that hold. The progress forwarding in the fork is also fixed, as the
  existing spec already requires (fix, no new requirement).
- Implementation fixes without spec change: Settings `TextEditingController`s are no longer recreated on every
  build and are disposed.

## Capabilities

### New Capabilities
- `appearance-settings`: theme mode, UI language and text size: choice, persistence, startup without a flash,
  tolerant reading of stored values.
- `window-state-persistence`: saving and restoring window size, position and maximized state, with an off-screen
  fallback and platform limits (no position on Wayland).

### Modified Capabilities
- `ergonomic-settings-and-cluster-onboarding`: the settings layout requirement gets titled sections in a fixed
  order (Appearance first). New requirements: validated number settings, a configurable default result limit, and
  reset to defaults per section.
- `auto-update`: *Environment-Aware Update Capability* now checks the latest release for installs without
  self-update. *Automated Startup Update Check* covers those installs. *Download and Progress Tracking* gets
  cancellation and keeps the real-time progress the spec already requires.

## Impact

- **Read-only impact:** no new Kafka or Schema Registry calls. One new outbound request: an unauthenticated
  `GET https://api.github.com/repos/GreenHopper/kafkalyzer/releases/latest`. It runs only where Velopack cannot
  update the app, on startup (not in debug builds) and when the user checks manually. Velopack already queries the
  same API in packaged installs. `scripts/check_read_only.sh` passes unchanged (the Dart code uses `http.get`, not
  `.send(`).
- **Dart:** `lib/src/theme_controller.dart` is replaced by `lib/src/services/appearance_settings.dart`.
  Also changed: `lib/src/app.dart` (`themeMode`, `locale`, text scale), `lib/main.dart` (load appearance and window
  state before `runApp`, after the headless branch), `lib/src/ui/main_layout.dart` (rail toggle, update snackbar),
  `lib/src/services/settings_service.dart` (number setting descriptors, default result limit, reset),
  `settings_view.dart`, `update_service.dart` (GitHub release check, download state, cancel), `update_dialog.dart`,
  `active_connection_controller.dart`, `topic_detail_view.dart`, `consumer_lag_view.dart`, `script_runner.dart`
  (validated reads). New `lib/src/services/window_state_service.dart`. en + de ARB.
- **Dependencies:** `window_manager` (pulls in `screen_retriever`) as a new desktop plugin. This changes the
  generated plugin lists for Linux/Windows/macOS and may need small runner edits (decided in the spike). `http`
  is already a dependency.
- **Vendored fork** `packages/velopack_flutter/rust`: progress forwarding thread is started before the download;
  `set_auto_apply_on_startup(false)`. No bridge API change, no codegen. `KAFKALYZER_PATCHES.md` updated.
- **Rust workspace `rust/`:** untouched, no bridge regeneration.

**Prerequisites:** `message-selection-copy-and-display` (§5.27) must be merged before the time display control
can be added; the other parts do not depend on it. `harden-local-storage-and-imports` (§5.22) changes
`SettingsService.importConfiguration`; this change reloads its notifiers after an import, in the same place
`live-tail-controls` (§5.29) does. Coordinates with `app-diagnostics-and-error-reporting` (§5.25: Diagnostics
section position, startup error screen must still show the window) and `live-tail-controls` (§5.29: buffer-limit
field position and its reset).

**Follow-up hook:** once the window plugin is in, `cluster-profile-ergonomics` (§5.26) can put the environment tag
into the native window title (`windowManager.setTitle`). That stays §5.26 scope and is not done here.

**Non-goals:**
- Custom colour themes, accent colours, density or font choice.
- More languages than English and German.
- A setting to turn off the startup update check, update channels, or self-update for deb/snap packages.
- Aborting the transfer inside Velopack (no cancellation hook in velopack 1.2.0).
- Multiple windows or several active clusters (§7); a custom window frame or title bar.
- Accessibility sweep and leftover hard-coded strings (§5.32), the shortcut catalogue (§5.25), the window-title
  environment tag (§5.26).
