## MODIFIED Requirements

### Requirement: In-Inspector Value Search and Match Stepping
The inspector SHALL provide an in-inspector search interface allowing users to query strings within the active message payload, key, header keys and header values, displaying the summed match count of all these sources and enabling incremental jumping between matches across them, in Tree and Raw view mode.

#### Scenario: Search and match counting
- **WHEN** the user enters a search phrase into the in-inspector search field
- **THEN** the viewer SHALL highlight all occurrences of the phrase
- **AND** the search bar SHALL display the total number of matches found and the current match index (e.g. `1 / 5`)

#### Scenario: Jump between matches
- **WHEN** multiple matches exist for the current search phrase
- **AND** the user presses `Enter` or clicks the next match button
- **THEN** the viewer SHALL scroll and focus to the next matching node/text
- **WHEN** the user presses `Shift+Enter` or clicks the previous match button
- **THEN** the viewer SHALL scroll and focus to the previous matching node/text

#### Scenario: Matches in payload, key and headers are summed
- **WHEN** the phrase `1234` occurs twice in the payload, once in the key and once in a header value
- **THEN** the search bar SHALL show 4 matches in total
- **AND** matches SHALL be ordered payload first, then key, then each header in display order with its key before its value

#### Scenario: Stepping into another tab
- **WHEN** the Payload tab is shown, the current match is the last payload match and the user steps to the next match
- **THEN** the inspector SHALL switch to the `Key & Headers` tab and scroll the next match into view with the active-match emphasis
- **AND** stepping past the last match SHALL wrap to the first payload match and switch back to the Payload tab

#### Scenario: Jump to a match in Raw mode
- **WHEN** the source that holds the next match is shown in Raw mode
- **THEN** the Raw view SHALL scroll so that the focused match is visible

#### Scenario: Count does not depend on the visible tab
- **WHEN** the user types a phrase while the Payload tab is shown and the phrase also occurs in a header
- **THEN** the total SHALL include the header match without the user opening the `Key & Headers` tab

#### Scenario: Search still running
- **WHEN** the match count of at least one source is still being computed
- **THEN** the search bar SHALL show that the search is running and SHALL NOT show "No matches"
