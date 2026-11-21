# controller-state-lifetime Specification

## Purpose

Defines how long each piece of application state lives, which of it is shared for the whole session and which belongs to a single view, and what the user must therefore see again after navigating or reopening a view.

## Requirements

### Requirement: Destination state survives navigation

Application state that a destination presents SHALL remain available when the user leaves that destination for another one and returns, for the whole session in which it was produced.

#### Scenario: Return to a destination with results

- **WHEN** the user runs a topic search in Explorer, switches to Consumer Lag, and returns to Explorer
- **THEN** the search results, selected tab and scroll-independent selections of that search SHALL be presented again unchanged
- **AND** no re-request of the underlying data SHALL be required to show them

#### Scenario: Background sessions keep their state

- **WHEN** several search tab sessions are open, the user visits another destination, and returns
- **THEN** every tab session SHALL show the state it had when the user left, not only the active one

#### Scenario: Work continues while its screen is not shown

- **WHEN** an analysis or stream is running and the user navigates away before it finishes
- **THEN** the work SHALL continue and its result or failure SHALL be visible when the user returns

#### Scenario: The underlying source failed

- **WHEN** the user returns to a destination whose last load failed or whose data became unavailable
- **THEN** the destination SHALL show the failure or an unknown state
- **AND** it SHALL NOT present an empty result list as if the load had succeeded

### Requirement: View-scoped state is released with the view

State that exists only for one dialog, panel or single run SHALL be released when that view is dismissed, and a fresh instance of the view SHALL start without the previous instance's draft values.

#### Scenario: Dialog dismissed during a pending lookup

- **WHEN** the user closes a dialog while a lookup it started is still running and the lookup later completes
- **THEN** no result, notification or state update from that lookup SHALL be presented for the dismissed dialog
- **AND** no follow-up action of that lookup SHALL be performed

#### Scenario: Dialog reopened after cancellation

- **WHEN** the user closes a dialog with unsubmitted entries and opens it again
- **THEN** the dialog SHALL show its default state rather than the discarded draft

#### Scenario: Dismissal while a run is in flight

- **WHEN** the user dismisses a run view while its run is still in flight and the run subsequently fails
- **THEN** the failure SHALL be reported to the session's diagnostics and SHALL NOT appear as a completed result

### Requirement: One value per session-wide fact

A fact that is presented in more than one place — the active cluster, the selected destination, a stored setting — SHALL have exactly one value for the session, and a change made through any of those places SHALL be visible in all of them.

#### Scenario: Same fact in two places

- **WHEN** the user selects a cluster in one destination and opens another destination that shows the active cluster
- **THEN** both SHALL show the same cluster without a further user action

#### Scenario: Fact is unset

- **WHEN** no cluster is active and two places show the active cluster
- **THEN** both SHALL show the unset state, and neither SHALL substitute a previously active cluster or a made-up default

### Requirement: Session-wide state is an enumerated set

Application state that outlives the view that produced it SHALL be limited to a single named set, and a change that adds an item to that set SHALL state which user-visible fact requires it to outlive that view.

#### Scenario: Change adds cross-destination state

- **WHEN** a change makes new state visible across two destinations
- **THEN** that change SHALL name the state in the enumerated set and the user-visible fact that requires it

#### Scenario: Change needs no session-wide state

- **WHEN** a change's state is only read inside the view that produced it
- **THEN** that state SHALL stay scoped to that view and SHALL NOT be added to the enumerated set

### Requirement: State ownership does not change cluster or registry access

Changing which component holds application state SHALL NOT change which read-only requests a user action produces, and SHALL NOT weaken how a denied or unavailable read is presented.

#### Scenario: Same action after re-scoping

- **WHEN** the user performs an action that reads cluster or Schema Registry data before and after the state re-scoping
- **THEN** the same set of describe-only read requests SHALL be issued
- **AND** no producing, committing or mutating operation SHALL be introduced

#### Scenario: Read is denied by permissions

- **WHEN** a re-scoped component performs a describe or read that the broker denies
- **THEN** the affected item SHALL still be presented as not readable
- **AND** it SHALL NOT be presented as absent or as an empty collection
