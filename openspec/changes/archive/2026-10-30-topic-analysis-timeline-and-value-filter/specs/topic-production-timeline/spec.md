# Spec Delta

## Purpose

Shows how a topic's message production developed over recent hours and per calendar day, so a user can recognise unusual volume increases without inspecting individual messages.

## ADDED Requirements

### Requirement: Hourly Production Timeline Recording

A topic analysis SHALL count scanned messages per absolute clock hour (not per hour-of-day) and store these counts in the report, together with the moment the scan refers to.

#### Scenario: Messages counted per absolute hour

- **WHEN** a scan covers 30 messages produced on 2026-10-29 between 14:00 and 14:59 and 20 messages produced on 2026-10-30 between 14:00 and 14:59
- **THEN** the report SHALL contain two separate hourly counts of 30 and 20 for those two clock hours
- **AND** the existing hour-of-day distribution SHALL still report 50 messages for hour 14

#### Scenario: Messages without valid timestamp

- **WHEN** scanned messages have no valid timestamp (timestamp <= 0)
- **THEN** they SHALL NOT appear in the hourly timeline
- **AND** they SHALL remain counted in the existing "unknown timestamp" category

#### Scenario: Timestamps far outside the scan moment

- **WHEN** a message timestamp lies more than 366 days before or more than 1 day after the scan moment
- **THEN** the message SHALL NOT be placed into the hourly timeline
- **AND** the report SHALL show the number of messages outside the timeline range

### Requirement: Recent Hours Production View

After a scan the system SHALL show the message count per clock hour for a recent window ending at the scan moment. The user SHALL be able to choose 6, 12, 24, 48 or 72 hours (default 24) without rescanning.

#### Scenario: Default window after a scan

- **WHEN** a scan completes
- **THEN** the system SHALL show one bar per clock hour for the 24 hours ending at the scan moment, including hours with zero messages
- **AND** the total message count of the window SHALL be shown

#### Scenario: Switching the window

- **WHEN** the user switches the window from 24 to 72 hours on a completed report
- **THEN** the view SHALL show 72 hourly bars computed from the stored report
- **AND** no new scan SHALL be started

#### Scenario: Imported report uses its own scan moment

- **WHEN** the user views an imported report that was scanned three days ago
- **THEN** the recent window SHALL end at the scan moment recorded in that report, not at the current time

### Requirement: Baseline Comparison and Anomaly Highlighting

For each hour in the recent window the system SHALL show a baseline: the average count of the same clock hour on up to 7 preceding days covered by the scan. An hour SHALL be highlighted as unusual when its count is at least twice the baseline and exceeds it by at least 10 messages.

#### Scenario: Unusual hour highlighted

- **WHEN** the hour 09:00–09:59 today has 900 messages and the same hour on the 7 preceding days averaged 300 messages
- **THEN** the hour SHALL be highlighted as unusual
- **AND** its detail SHALL show the count, the baseline and the relative difference (+200 %)

#### Scenario: Normal fluctuation not highlighted

- **WHEN** an hour has 380 messages and its baseline is 300 messages
- **THEN** the hour SHALL NOT be highlighted

#### Scenario: Small absolute numbers not highlighted

- **WHEN** an hour has 6 messages and its baseline is 2 messages
- **THEN** the hour SHALL NOT be highlighted

#### Scenario: No baseline available

- **WHEN** the scan does not cover any preceding day for an hour in the window
- **THEN** that hour SHALL be shown without a baseline and marked as "no comparison data"
- **AND** it SHALL NOT be highlighted

### Requirement: Daily Production Distribution

The system SHALL show the message count per calendar day for every day in the scanned range, each entry with weekday, date and count, ordered from newest to oldest day.

#### Scenario: Daily rows

- **WHEN** a scan covers messages produced on Monday 2026-10-26 (1200 messages) and Tuesday 2026-10-27 (1500 messages)
- **THEN** the daily distribution SHALL list "Tuesday, 2026-10-27: 1500" before "Monday, 2026-10-26: 1200", using the localized weekday name and date format

#### Scenario: Days without messages inside the range

- **WHEN** the scanned range contains a day without any message between two days with messages
- **THEN** that day SHALL be listed with a count of 0

#### Scenario: Visual comparison of days

- **WHEN** the daily distribution is shown
- **THEN** each day SHALL show a bar proportional to its count relative to the busiest day in the range

### Requirement: Local Time Presentation

The recent hours view and the daily distribution SHALL present hours, weekdays and dates in the local time zone of the computer running the application, and SHALL label the time zone used.

#### Scenario: Local day boundaries

- **WHEN** the computer runs in time zone UTC+01:00 and a message was produced at 2026-10-29T23:30Z
- **THEN** the message SHALL be counted for Friday 2026-10-30 in the daily distribution and for the hour 00:00–00:59 in the recent hours view

#### Scenario: Time zone label

- **WHEN** the recent hours view or the daily distribution is shown
- **THEN** the view SHALL display the name or offset of the local time zone

### Requirement: Timeline Coverage Indication

The report SHALL record from which moment on the scanned data is complete. When the selected recent window or a listed day starts before that moment, the system SHALL mark it as partially covered instead of presenting missing data as low volume.

#### Scenario: Sampled scan does not cover the window

- **WHEN** the user scanned only the last 10,000 messages and these reach back 5 hours, and the 24-hour window is selected
- **THEN** the view SHALL indicate that only the last 5 hours of the window are covered by the scan
- **AND** hours before the coverage start SHALL be visually distinguished from hours with zero messages

#### Scenario: Partially covered day

- **WHEN** the coverage start lies within a day of the daily distribution
- **THEN** that day SHALL be marked as partially covered

#### Scenario: Full scan

- **WHEN** a full scan of all retained messages completes
- **THEN** no part of the timeline SHALL be marked as partially covered

### Requirement: Timeline Unavailable For Older Reports

When a report does not contain hourly timeline data (for example an imported file of an earlier format version), the recent hours view and the daily distribution SHALL show a localized "not available for this report" notice instead of empty charts.

#### Scenario: Importing an older report

- **WHEN** the user imports a report file of the previous format version
- **THEN** the recent hours view and the daily distribution SHALL show the "not available" notice
- **AND** all other report sections SHALL render normally
