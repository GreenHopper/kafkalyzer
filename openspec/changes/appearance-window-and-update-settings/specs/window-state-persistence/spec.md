# Spec Delta

## Purpose

Keeps the main window where the user left it: size, position and maximized state are saved locally while the
application runs and restored on the next start, without placing the window outside the visible screens.

## ADDED Requirements

### Requirement: Save Window State While Running
The application SHALL save the main window's size, position and maximized state locally whenever the user resizes, moves, maximizes or restores it, at most a short moment after the change, so that the state survives a normal exit, an update restart and a crash. While the window is maximized, the size and position before maximizing SHALL be kept.

#### Scenario: Resize then quit
- **WHEN** the user resizes the window to 1600 × 900 and quits the application
- **THEN** the saved window size SHALL be 1600 × 900

#### Scenario: Maximized window keeps its normal size
- **WHEN** the window was 1400 × 800 and the user maximizes it
- **THEN** the saved state SHALL be maximized with a normal size of 1400 × 800

### Requirement: Restore Window State on Start
On start, the application SHALL show the main window with the saved size and position, and maximized when it was saved maximized. A restored size SHALL be no smaller than 640 × 480 and no larger than the screen it is shown on.

#### Scenario: Restore size and position
- **WHEN** the saved state is 1600 × 900 at position (100, 80), not maximized, and that area is on a connected screen
- **THEN** the application SHALL open a 1600 × 900 window at (100, 80)

#### Scenario: Restore maximized
- **WHEN** the saved state is maximized
- **THEN** the application SHALL open maximized, and un-maximizing SHALL return to the saved normal size

### Requirement: Off-Screen and Missing State Fallback
If no saved window state exists, the saved state cannot be read, or the saved position is not sufficiently visible on any connected screen, the application SHALL open the window centred on the primary screen, with the saved size clamped to that screen or with the default size of 1280 × 720.

#### Scenario: Monitor was disconnected
- **WHEN** the saved position lies on a second monitor that is no longer connected
- **THEN** the window SHALL open centred on the primary screen

#### Scenario: Saved state is unreadable
- **WHEN** the saved window state is corrupt
- **THEN** the window SHALL open with 1280 × 720 centred, and the application SHALL start normally

### Requirement: Platform Limits on Window Position
Where the platform does not let applications read or set window positions (Linux under Wayland), the application SHALL save and restore only the size and maximized state and leave placement to the platform. Failure of the window integration SHALL NOT prevent the window from being shown.

#### Scenario: Wayland session
- **WHEN** the application runs in a Linux Wayland session
- **THEN** size and maximized state SHALL be restored, and the position SHALL be chosen by the compositor

#### Scenario: Window integration fails
- **WHEN** restoring the window state fails with an error
- **THEN** the error SHALL be logged and the window SHALL be shown with the platform default size and position

### Requirement: Headless Runs Leave Window State Untouched
A headless script run SHALL neither read nor write the saved window state.

#### Scenario: Script run from the command line
- **WHEN** the application is started with `--script`
- **THEN** the saved window state SHALL be unchanged after the run
