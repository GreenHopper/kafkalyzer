# accessibility-baseline Specification

## Purpose

Defines the minimum accessibility every screen of the desktop GUI meets: labelled controls, usable hit areas,
readable text sizes, theme-based status colours with sufficient contrast, no colour-only states, and error boxes that
can be copied and closed.

## Requirements

### Requirement: Labelled Icon-only Controls
Every interactive control that shows only an icon SHALL have a localized tooltip that describes its action, and
assistive technologies SHALL receive the same text as its semantic label. Controls whose action depends on a state
(for example show/hide) SHALL describe the action that a click performs.

#### Scenario: Explorer sidebar refresh
- **WHEN** the user hovers the refresh icon of the Explorer topic list or reaches it with a screen reader
- **THEN** a localized tooltip and semantic label such as "Refresh topics" SHALL be available

#### Scenario: Message table header controls
- **WHEN** a screen reader reaches a column's filter icon or its remove/hide icon in the message table header
- **THEN** it SHALL announce a localized label that names the action and the column

#### Scenario: Tab close control
- **WHEN** the user hovers or focuses the close icon of a topic tab
- **THEN** the localized "Close tab" tooltip and semantic label SHALL be available, and the control SHALL be reachable by keyboard focus

### Requirement: Minimum Hit Area
Standalone icon buttons in toolbars, headers and dialogs SHALL keep the platform's default hit area, which is at least
40×40 logical pixels on desktop. Inline controls inside dense rows, such as table headers, tree rows, tabs, chips and
text field suffixes, SHALL have a hit area of at least 24×24 logical pixels, even when the icon is smaller.

#### Scenario: Dense table header icon
- **WHEN** the message table header shows a 14 px filter icon
- **THEN** the area that reacts to a click on that icon SHALL be at least 24×24 logical pixels

#### Scenario: Search field clear button
- **WHEN** a search field shows its clear icon
- **THEN** the clear control SHALL be at least 24×24 logical pixels, and SHALL be at least 40×40 when it is a standalone toolbar button

### Requirement: Minimum Text Size
No text in the GUI SHALL be rendered smaller than 11 logical pixels at the default text scale. Small text SHALL use the
theme's type roles, so that a changed text scale applies to it too.

#### Scenario: Tab and topic badges
- **WHEN** a topic tab or topic list item shows a DLQ, retry or partition badge
- **THEN** the badge text SHALL be at least 11 logical pixels

#### Scenario: Chart axis labels
- **WHEN** a production chart shows axis or bar labels
- **THEN** they SHALL be at least 11 logical pixels, and labels that would overlap SHALL be thinned out rather than shrunk

### Requirement: Theme-based Status Colours
Colours that express a status (success, warning, error, running, neutral or unknown) SHALL come from the active colour
scheme, not from fixed colour values. Text and icons in those colours SHALL meet the WCAG AA contrast ratio against
their background in both the light and the dark theme.

#### Scenario: Status in dark theme
- **WHEN** the dark theme is active and a message metadata card, a script run status or a consumer group state is shown
- **THEN** its text and icons SHALL meet the contrast ratio against their background, and no text SHALL use a fixed dark colour on a dark surface

#### Scenario: Theme switch
- **WHEN** the user switches between the light and the dark theme
- **THEN** status colours SHALL follow the new colour scheme without a restart

### Requirement: State Not Conveyed by Colour Alone
Every state that is shown by a colour SHALL also be shown by an icon, a text or a symbol that is visible without
hovering, and assistive technologies SHALL receive it as text.

#### Scenario: Skewed partition
- **WHEN** the partition balance view marks a partition as skewed
- **THEN** that row SHALL show a warning icon with a localized "skewed" label in addition to the bar colour

#### Scenario: Unusual production hour
- **WHEN** the recent production chart marks an hour as unusual
- **THEN** that bar SHALL carry a visible marker in addition to its colour, matching the marker used in its tooltip

### Requirement: Copyable and Dismissible Error Boxes
Every error box SHALL offer a localized "Copy" action that copies the full error text. An error banner that is shown
above other content SHALL also offer a localized close action that removes it until the next error. An error state
that replaces the content area SHALL keep its retry action where one exists.

#### Scenario: Close connection error
- **WHEN** a connection attempt failed and the Explorer shows the connection error banner
- **THEN** the user SHALL be able to close the banner, and it SHALL stay closed until a new connection error occurs

#### Scenario: Copy error text
- **WHEN** the user clicks "Copy" in an error box
- **THEN** the complete error text, including the raw cause, SHALL be placed on the clipboard and a localized confirmation SHALL be shown

#### Scenario: Clipboard unavailable
- **WHEN** writing to the clipboard fails
- **THEN** a localized failure notice SHALL be shown and the error box SHALL stay unchanged

### Requirement: Automated Accessibility Checks
Automated widget tests SHALL check a fixed list of core screens in the light and the dark theme. The checks SHALL be
that every tappable element has a label or tooltip, that every tappable element meets the 24×24 minimum, and that text
contrast meets WCAG AA. A failing check SHALL fail the test run.

#### Scenario: Regression in a core screen
- **WHEN** a change adds an icon-only button without a tooltip to a checked screen
- **THEN** the accessibility test for that screen SHALL fail and name the unlabelled element

#### Scenario: Dark-theme contrast regression
- **WHEN** a checked screen renders text with insufficient contrast in the dark theme
- **THEN** the dark-theme run of the accessibility test SHALL fail
