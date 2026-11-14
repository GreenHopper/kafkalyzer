# complete-ui-localization-and-discoverability Specification

## Purpose

Provides comprehensive UI localization across topic details, cluster configuration dialogs, schema viewer, message views, and json trees, along with clear discoverability for tree row actions.

## Requirements

### Requirement: Comprehensive UI Localization Across Topic, Cluster, Schema, and Message Views
All user-facing action labels, dialog headers, field labels, tooltips, validation messages, and empty states in `TopicDetailView`, `ClusterConfigDialog`, `ClusterBasicInfoForm`, `ClusterSslForm`, `ClusterSaslForm`, `SchemaViewerDialog`, and `MessagesView` SHALL be retrieved from `AppLocalizations` (`app_en.arb` and `app_de.arb`) without hardcoded English text. The same SHALL apply to every other screen, dialog, menu, notification and file dialog of the graphical application.

#### Scenario: Rendering TopicDetailView in German locale
- **WHEN** the user opens `TopicDetailView` with locale set to `de`
- **THEN** action buttons ("Stream", "Stop", "Schema"), progress label ("Scan Progress"), and tooltips ("Clear Messages") SHALL render in German

#### Scenario: Rendering Cluster Configuration and Security Forms in German locale
- **WHEN** the user opens `ClusterConfigDialog` with locale set to `de`
- **THEN** the dialog title, footer action buttons ("Cancel", "Save" / "Add"), security protocol field, SSL form headers and labels, SASL mechanism options and credential labels, and URL validation messages SHALL render in German

#### Scenario: Rendering SchemaViewerDialog and MessagesView in German locale
- **WHEN** the user views `SchemaViewerDialog` or an empty `MessagesView` with locale set to `de`
- **THEN** the schema viewer title, navigation tooltips, error states, and empty messages placeholders SHALL render in German

#### Scenario: Message table header and column filter dialog in German locale
- **WHEN** the user opens the column filter dialog of the message table with locale set to `de`
- **THEN** the column titles, the dialog title, the input hint, the "Clear" and "Apply" actions and the "Hide column" tooltip SHALL render in German

#### Scenario: Payload viewers in German locale
- **WHEN** the user views a message payload in the raw, tree or hex view with locale set to `de`
- **THEN** the Raw/Tree switch, the copy action and its confirmation, the empty-binary notice and the hex copy action with its progress and confirmation notices SHALL render in German

#### Scenario: Script workspace in German locale
- **WHEN** the user opens the script editor, the step editor, the parameter values dialog, the run history, a run's details or the schemas view with locale set to `de`
- **THEN** their titles, field labels, table headers, actions, tooltips, confirmations and notices SHALL render in German

#### Scenario: Explorer, cluster overview and quick jump in German locale
- **WHEN** the user views the cluster overview, the topic selection dialog, the topic search fields or the quick-jump dialog with locale set to `de`
- **THEN** section titles such as "Available Topics", placeholders such as "Optional metadata registry", field labels and the "No cluster selected" error SHALL render in German

#### Scenario: Technical identifiers stay untranslated
- **WHEN** the UI shows a protocol or mechanism name (for example `SASL_SSL`, `SCRAM-SHA-512`), a date format pattern, a Schema Registry subject name or a product name
- **THEN** that identifier SHALL be shown verbatim in every locale

---

### Requirement: Discoverable Row Actions in SmartVirtualJsonTree
`SmartVirtualJsonTree` SHALL provide clear visual affordances and localized tooltips for row actions, including an intuitive pin icon (`Icons.push_pin_outlined`) for pinning JSON paths as columns and localized feedback for value copying.

#### Scenario: Pinning a JSON path to column in SmartVirtualJsonTree
- **WHEN** the user hovers over or views a JSON row that supports column pinning
- **THEN** a clear pin icon button (`Icons.push_pin_outlined`) SHALL be displayed with a localized tooltip ("Pin as column" / "Als Spalte anheften")
- **AND** clicking the button SHALL trigger the `onPinToColumn` callback with the normalized JSON path

#### Scenario: Copying a value to clipboard
- **WHEN** the user clicks the copy icon on a JSON row
- **THEN** the value SHALL be copied to the clipboard and a localized confirmation snackbar ("Value copied to clipboard" / "Wert in die Zwischenablage kopiert") SHALL be displayed

### Requirement: Language-Neutral Widget Logic
The GUI SHALL choose every user-facing text through the localization catalogue. It SHALL NOT compare the active language code to pick a text. A locale without its own catalogue SHALL get the English text on every screen, never a mix of languages.

#### Scenario: Consumer lag controls in German locale
- **WHEN** the user opens Consumer Lag with locale set to `de`
- **THEN** the state and refresh-interval filters, the table headers, the KPI cards, the loading texts and the partition table labels SHALL render in German from the catalogue

#### Scenario: Unsupported system locale
- **WHEN** the operating system locale is `fr`
- **THEN** every screen, including Consumer Lag, SHALL render the English texts

### Requirement: Localized Messages From Background Operations
Errors and notices that come from non-widget code, such as a failed cluster connection or a rejected analysis input, SHALL be shown with a localized text for their kind. Where a raw cause exists, it SHALL be shown unchanged below that text. Titles of file open and save dialogs SHALL be in the active language.

#### Scenario: Connection refused in German locale
- **WHEN** connecting to a cluster fails because the broker refuses the connection and the locale is `de`
- **THEN** the error box SHALL show the German "connection refused" text and the first line of the raw client error

#### Scenario: Unclassified connection failure
- **WHEN** connecting fails with an error that matches no known kind
- **THEN** the error box SHALL show a localized generic "connection failed" text together with the first line of the raw error, never an empty message

#### Scenario: Analysis validation in German locale
- **WHEN** the user starts a field analysis with an empty field path, or requests a re-scan without a previous scope, and the locale is `de`
- **THEN** the analysis view SHALL show the matching German validation message

#### Scenario: File dialog titles
- **WHEN** the user exports or imports a configuration, exports messages or a topic analysis, or saves a run archive or schema markdown with locale set to `de`
- **THEN** the file dialog title SHALL be German

### Requirement: Consistent Translation Catalogues
The English and German catalogues SHALL contain the same keys. Each key SHALL appear only once per catalogue and SHALL have one meaning. A key's placeholders SHALL be the same in both languages and SHALL be declared in the English template. An automated test SHALL fail when any of these rules is broken.

#### Scenario: Missing translation
- **WHEN** a key exists in the English catalogue but not in the German one
- **THEN** the catalogue test SHALL fail and name the key

#### Scenario: Duplicate key
- **WHEN** a catalogue defines the same key twice
- **THEN** the catalogue test SHALL fail and name the key and the catalogue

#### Scenario: Placeholder mismatch
- **WHEN** the German text of a key uses a placeholder that the English text does not use, or the English template does not declare a placeholder that it uses
- **THEN** the catalogue test SHALL fail and name the key and the placeholder

#### Scenario: Same words, different meanings
- **WHEN** the script result diff and the schema version diff both find no differences
- **THEN** each SHALL show its own text, and the message inspector search counter and the script run match summary SHALL each use their own wording

### Requirement: Guard Against Hard-coded User-facing Text
An automated test SHALL scan the GUI source and fail when a text literal containing words is used as displayed text, tooltip, label, hint, title, notification content or semantic label, or when code compares the active language code. A finding SHALL be accepted only through a reviewed allowlist entry with a reason. Allowlist entries that no longer match SHALL also fail the test.

#### Scenario: New hard-coded label
- **WHEN** a developer adds a button whose label is an English literal
- **THEN** the guard test SHALL fail and report the file, the line and the literal

#### Scenario: Allowlisted technical identifier
- **WHEN** a dropdown shows the literal `SASL_SSL` and the allowlist contains that file and literal with a reason
- **THEN** the guard test SHALL pass

#### Scenario: Stale allowlist entry
- **WHEN** an allowlisted literal is removed from the source
- **THEN** the guard test SHALL fail and name the stale entry
