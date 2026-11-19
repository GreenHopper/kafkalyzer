## ADDED Requirements

### Requirement: Diff Ignore-List Control in the Results Toolbar

While the diff view is active, the results toolbar SHALL render the "Ignored fields (n)" control inline next to the
view-mode switcher instead of in a separate row above the timeline. When results span more than one topic, the topic
selector for the ignore list SHALL sit next to the button in the toolbar, and when the stored ignore list is unreadable,
the toolbar SHALL show an inline warning. In all other view modes the ignore-list control SHALL NOT be shown.

#### Scenario: Diff view shows ignored fields in toolbar
- **WHEN** the user switches `MessagesView` to Diff mode (`diff`) on a single topic with 2 ignored fields
- **THEN** the results toolbar SHALL show "Ignored fields (2)" inline with the view-mode switcher
- **AND** no extra row or divider SHALL be rendered between the results toolbar and the diff timeline

#### Scenario: Switching away from Diff mode hides the control
- **WHEN** the user switches from Diff mode to Table or Timeline mode
- **THEN** the "Ignored fields" control SHALL NOT be rendered in the toolbar

#### Scenario: Multi-topic diff results
- **WHEN** the loaded messages in Diff mode belong to two or more topics
- **THEN** a compact topic selector SHALL appear in the results toolbar next to the "Ignored fields (n)" button
- **AND** selecting a topic SHALL update the shown count and the dialog target to that topic's ignore list

#### Scenario: Unreadable ignore list warning in toolbar
- **WHEN** the stored ignore list of the active topic is unreadable while Diff mode is shown
- **THEN** the toolbar SHALL show a warning indicator with the localized warning message next to the "Ignored fields" button
