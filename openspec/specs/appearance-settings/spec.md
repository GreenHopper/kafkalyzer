# appearance-settings Specification

## Purpose

Lets the user choose how the application looks and reads: theme mode, UI language and text size. The choices are persisted locally, applied without a restart, and restored before the first frame on the next start.

## Requirements

### Requirement: Theme Mode Choice
The Settings page SHALL offer the theme modes System, Light and Dark. System SHALL follow the operating system's brightness and react when it changes. The default SHALL be System; a theme choice stored by an earlier version (light or dark) SHALL be kept. A change SHALL apply at once and be persisted.

#### Scenario: Follow the operating system
- **WHEN** the theme mode is System and the operating system switches to a dark appearance
- **THEN** the application SHALL switch to the dark theme without a restart

#### Scenario: Explicit choice survives a restart
- **WHEN** the user selects Light and restarts the application
- **THEN** the application SHALL start with the light theme

#### Scenario: Choice from an earlier version
- **WHEN** an earlier version stored "dark" and no theme mode of this version is stored
- **THEN** the theme mode SHALL be Dark

### Requirement: Quick Theme Toggle in the Navigation Rail
The theme button in the navigation rail SHALL switch to the opposite of the brightness currently shown and store that as an explicit Light or Dark mode. Its tooltip SHALL name the mode it switches to.

#### Scenario: Toggle while following a dark system theme
- **WHEN** the theme mode is System, the dark theme is shown, and the user activates the rail theme button
- **THEN** the theme mode SHALL become Light and the Settings page SHALL show Light as selected

### Requirement: No Theme Flash at Startup
The application SHALL read the stored appearance choices before it renders its first frame, so the first frame already uses the stored theme, language and text size.

#### Scenario: Light theme stored
- **WHEN** the stored theme mode is Light and the application starts
- **THEN** no frame SHALL be rendered with the dark theme

### Requirement: UI Language Choice
The Settings page SHALL offer the languages System, English and Deutsch. System SHALL use the operating system language when it is supported and English otherwise. Language names SHALL be shown in their own language. A change SHALL apply at once to all visible text and to locale-dependent number and date formatting, and SHALL be persisted.

#### Scenario: Switch to German on an English system
- **WHEN** the operating system language is English and the user selects Deutsch
- **THEN** the user interface SHALL be shown in German without a restart

#### Scenario: Unsupported system language
- **WHEN** the language is System and the operating system language is French
- **THEN** the user interface SHALL be shown in English

### Requirement: Text Size Choice
The Settings page SHALL offer a text size factor between 80 % and 150 %, default 100 %. The factor SHALL be applied on top of the operating system's text scaling to all text in the application at once, and SHALL be persisted.

#### Scenario: Larger text
- **WHEN** the user selects 125 %
- **THEN** text in all views SHALL be drawn 1.25 times the size it has at 100 %, without a restart

#### Scenario: Text size survives a restart
- **WHEN** the user selected 125 % and restarts the application
- **THEN** the application SHALL start with a text size of 125 %

### Requirement: Tolerant Reading of Stored Appearance Values
A stored appearance value that is missing, has the wrong type, is unknown or lies outside its range, for example after a configuration import or a downgrade, SHALL be ignored, and the default SHALL be used. Reading it SHALL NOT fail the startup, and the stored value SHALL NOT be rewritten until the user changes the setting.

#### Scenario: Imported configuration contains an invalid text size
- **WHEN** the stored text size factor is 7.0
- **THEN** the application SHALL start with 100 % text size

#### Scenario: Unknown language code
- **WHEN** the stored language is "fr"
- **THEN** the language SHALL be System
