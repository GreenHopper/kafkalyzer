# Design

## Context

See `proposal.md` for motivation. Currently, Kafkalyzer has multiple file export workflows (message export in JSON/CSV/ZIP, topic analysis report export, script exports, run archive exports, and cluster/settings backups). These workflows rely on `FilePicker.saveFile` to prompt for a target path, write data synchronously or asynchronously, and then show a static `SnackBar` with localized success text. If the user cancels the file dialog, some workflows still report success. Furthermore, once exported, the user has no direct affordance to open the file or view its location in their desktop file manager.

## Goals / Non-Goals

**Goals:**
- Provide a unified, desktop-friendly `FileOpenerService` with cross-platform support for Linux, macOS, and Windows.
- Provide dual interactive actions—**"Open File"** and **"Show in Folder"**—on export completion notifications.
- Ensure all export entry points return the saved file path (or `null` on cancellation) and suppress false-positive notifications on cancellation.
- Keep UI consistent and fully localized across all export locations using `package:material_ui/material_ui.dart` and `AppLocalizations`.

**Non-Goals:**
- In-app file viewer or editor for exported archives or CSV files (opening uses the host OS default applications).
- Custom desktop file manager or embedded file tree navigator.
- Mobile/Web platform file system operations (Kafkalyzer is a desktop application).

## Decisions

### 1. Dedicated `FileOpenerService`
- **Choice:** Create a dedicated `FileOpenerService` registered in `getIt` rather than ad-hoc `Process.run` calls in widget classes.
- **Rationale:** Centralizes platform-specific execution, path sanitization, and error handling. Facilitates unit and widget testing via dependency injection and fakes/mocks.
- **Alternatives Considered:**
  - *Direct `url_launcher` in UI widgets:* `url_launcher` supports `launchUrl(Uri.file(path))` for opening files, but lacks native support for highlighting/selecting a file within its parent directory on Windows (`explorer.exe /select,`) and macOS (`open -R`).
  - *External pub package like `open_file`:* Adding unnecessary third-party dependencies when native Dart `dart:io` (`Process.run`) and `url_launcher` (already a dependency) reliably cover Linux, macOS, and Windows.

### 2. Platform Command Strategy for File and Folder Operations
- **File Opening:**
  - Use `url_launcher`'s `launchUrl(Uri.file(filePath))` as the primary launcher with fallback to OS commands (`open` on macOS, `xdg-open` on Linux, `start` / `explorer.exe` on Windows).
- **Folder / Reveal Operation:**
  - **macOS:** `Process.run('open', ['-R', filePath])` (reveals and highlights the file in Finder).
  - **Windows:** `Process.run('explorer.exe', ['/select,', filePath])` (reveals and highlights the file in Windows Explorer).
  - **Linux:** Attempt opening parent directory via `Process.run('xdg-open', [directoryPath])` or DBus `org.freedesktop.FileManager1.ShowItems`.
- **Validation:** Check `File(filePath).existsSync()` or `Directory(parentPath).existsSync()` before executing commands to provide clear user feedback if the target was deleted or moved.

### 3. Unified Completion Notification Affordance
- **Choice:** Create a reusable notification helper (e.g. `showExportSuccessSnackBar(BuildContext context, {required String message, required String filePath})` in a shared notification helper or as part of `FileOpenerService`).
- **Rationale:** SnackBar in Flutter natively only allows a single `SnackBarAction`. However, a custom `content` widget containing a `Row` with the success text and two compact `TextButton` widgets allows both "Open" and "Show in Folder" actions without cluttering the screen or requiring modal dialogs.
- **Alternatives Considered:**
  - *Modal Dialog:* Interrupts user workflow and requires explicit dismissal.
  - *Single action on SnackBar ("Open Folder" only):* Forces user to double-click file in explorer instead of immediately opening it.

### 4. Return Types of Export Services
- **Choice:** Update `MessageExportService.exportMessages` and `exportMessagesCsv` to return `Future<String?>` (the saved file path, or `null` if cancelled).
- **Rationale:** Allows calling views (`MessagesView`) to distinguish cancellation from successful export and receive the saved file path needed for opening actions.

## Risks / Trade-offs

- **[Risk]** Host system default application fails to open or file manager process exits with non-zero exit code (e.g., headless Linux or missing xdg-open).
  → **Mitigation:** Wrap process executions in `try/catch` blocks, check exit codes where applicable, and surface a localized error SnackBar if opening fails.
- **[Risk]** File paths with special characters or spaces on Windows causing command argument issues.
  → **Mitigation:** Use `Process.run` with list arguments (which handles argument quoting properly) rather than shell string concatenation.
- **[Risk]** SnackBar duration may be too brief for the user to decide between "Open" and "Show in Folder".
  → **Mitigation:** Set the export success SnackBar duration to a generous interval (e.g., 6–8 seconds) so users have ample time to click an action.
