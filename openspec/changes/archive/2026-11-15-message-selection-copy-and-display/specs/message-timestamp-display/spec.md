# Spec Delta

## Purpose

Defines how Kafka message timestamps are shown and copied in the result views: one global, persisted choice between
local time and UTC, a visible zone, a detail tooltip and unambiguous ISO-8601 text when copying.

## ADDED Requirements

### Requirement: Global Local or UTC Time Display Setting
The app SHALL offer one global setting that shows Kafka message timestamps either in local time or in UTC. The default SHALL be local time. The setting SHALL be persisted locally, restored on start, and a change SHALL apply at once to every open result view, including script run results.

#### Scenario: Switch to UTC
- **WHEN** the user switches the time display to UTC
- **THEN** every message timestamp in table, timeline, diff metadata and inspector SHALL be shown in UTC without reopening the view

#### Scenario: Setting survives a restart
- **WHEN** the user selected UTC and restarts the app
- **THEN** message timestamps SHALL be shown in UTC

#### Scenario: Stored value is unreadable
- **WHEN** the stored setting is missing or has an unknown value
- **THEN** the app SHALL use local time

### Requirement: Time Display Toggle in the Results Toolbar
The results toolbar SHALL contain a control that switches the global time display between local time and UTC. Its tooltip SHALL name the mode it switches to.

#### Scenario: Toggle from the toolbar
- **WHEN** the time display is local and the user activates the toolbar control
- **THEN** the global time display SHALL become UTC

### Requirement: Visible Time Zone
The active time display mode SHALL be visible where message timestamps are listed: the Timestamp column header SHALL name the mode ("UTC" or "Local"), and the inspector's timestamp SHALL carry a zone suffix (`UTC` or the local UTC offset of that instant).

#### Scenario: Column header names the zone
- **WHEN** the time display is UTC
- **THEN** the Timestamp column header SHALL include "UTC"

#### Scenario: Inspector shows the local offset
- **WHEN** the time display is local and the local zone is UTC+02:00 at the message's instant
- **THEN** the inspector timestamp SHALL end with `+02:00`

### Requirement: Timestamp Detail Tooltip
Hovering a message timestamp in the table, the timeline, the diff metadata or the inspector SHALL show a tooltip with the ISO-8601 time in UTC, the ISO-8601 time with local offset, the epoch milliseconds, the time relative to now and the timestamp type when it is known.

#### Scenario: Tooltip content
- **WHEN** the user hovers the timestamp of a message with epoch milliseconds `1768812660123` and type CreateTime
- **THEN** the tooltip SHALL show `2026-01-19T08:51:00.123Z`, the same instant with local offset, `1768812660123`, a relative time and "CreateTime"

#### Scenario: Timestamp type unknown
- **WHEN** the timestamp type of a message is not known (for example a message from an imported file)
- **THEN** the tooltip SHALL omit the type line or mark it as unknown, and SHALL NOT guess a type

### Requirement: ISO-8601 in Copied Timestamps
Every copy action that includes a message timestamp SHALL write it as ISO-8601 with milliseconds and zone (`Z` in UTC mode, the local offset in local mode), never as a locale-formatted date.

#### Scenario: Copy metadata in UTC mode
- **WHEN** the time display is UTC and the user copies the metadata of a message with epoch milliseconds `1768812660123`
- **THEN** the copied timestamp SHALL be `2026-01-19T08:51:00.123Z`

### Requirement: Timestamp Type From Consumed Messages
Each consumed message SHALL carry the timestamp type reported by the broker (CreateTime, LogAppendTime or not available) without additional broker requests. A message whose timestamp is not available SHALL be shown as "no timestamp" instead of a date derived from 0.

#### Scenario: Message without broker timestamp
- **WHEN** a consumed message reports no timestamp
- **THEN** its timestamp SHALL be shown as "no timestamp" and SHALL NOT be shown as 1970-01-01

#### Scenario: Reading the type stays read-only
- **WHEN** messages are consumed with timestamp types
- **THEN** no request other than the existing read-only consumption SHALL be sent to the broker
