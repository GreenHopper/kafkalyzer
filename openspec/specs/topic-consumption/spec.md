# topic-consumption Specification

## Purpose

Provides a fast, responsive message consumption pipeline with early empty-topic detection, consolidated watermark inspection, and prompt EOF termination for bounded reads.

## Requirements

### Requirement: Fast Empty Topic Detection

The message consumer SHALL detect empty topics and exhausted offset ranges during initial partition watermark inspection and terminate immediately when not in live streaming mode (`run_forever = false`).

#### Scenario: Opening an empty topic with earliest start strategy

- **WHEN** message consumption begins for a topic where all assigned partitions have a high watermark equal to the low watermark (e.g. `0 == 0`)
- **AND** `run_forever` is `false`
- **THEN** the consumer emits an initial progress indicator `__PROGRESS__:0:0`
- **AND** the consumer immediately emits `__EOF__` without entering the poll loop or sleeping
- **AND** the entire operation completes in under 100ms

#### Scenario: Requesting offset range beyond available messages

- **WHEN** message consumption begins with a `start_offset` or `start_timestamp` that resolves to greater than or equal to the high watermark on all assigned partitions
- **AND** `run_forever` is `false`
- **THEN** the consumer emits `__PROGRESS__:0:0` and `__EOF__` immediately without waiting for poll timeouts

### Requirement: Zero-Delay Consumer Initialization

The system SHALL NOT execute arbitrary sleep or fixed-iteration polling delays during consumer creation, assignment, or seek setup.

#### Scenario: Immediate partition assignment without blocking stabilization loops

- **WHEN** the consumer assigns target topic partitions
- **THEN** the consumer does not execute fixed-iteration blocking sleep loops (e.g. 20 x 100ms or 5 x 100ms)
- **AND** proceeds directly to watermark resolution and seeking

### Requirement: Consolidated Watermark Resolution

The consumer SHALL query partition low and high watermarks in a single pass during setup, reusing the retrieved watermarks for both start offset clamping and end offset calculation.

#### Scenario: Single-pass watermark lookup per partition

- **WHEN** setting up start and end offset boundaries for a topic
- **THEN** the consumer fetches partition watermarks at most once per partition
- **AND** uses the resolved high watermarks to determine total messages to scan and termination bounds

### Requirement: Responsive Poll Loop and EOF Termination

When consuming messages in bounded mode (`run_forever = false`), the consumer SHALL promptly detect when all partitions have reached their end boundaries.

#### Scenario: Poll timeout on exhausted partitions

- **WHEN** the consumer poll returns `None` or `PartitionEOF` while all partitions have reached their target end offsets
- **AND** `run_forever` is `false`
- **THEN** the consumer evaluates completion without requiring a 1-second delay
- **AND** emits `__EOF__` and exits the polling loop immediately

### Requirement: Fair Result Limit Across Partitions

When a result limit of $N$ matching messages is configured and more than one partition is assigned, the consumer SHALL distribute that limit across assigned partitions as evenly as possible, rather than filling the entire limit from whichever partition delivers first. Unused quota from partitions that have no (further) matching messages in the selected offset or time range SHALL be redistributed to remaining active partitions until the global limit is reached or all assigned partitions are exhausted. The global limit $N$ remains a hard ceiling on total emitted matches.

#### Scenario: Even distribution when all partitions have enough matches

- **WHEN** message consumption begins on a topic with $P$ assigned partitions ($P > 1$)
- **AND** a result limit of $N$ matching messages is configured
- **AND** each assigned partition has at least $\lceil N / P \rceil$ matching messages in the selected range
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL emit at most $N$ matching messages in total
- **AND** the count of matching messages emitted per partition SHALL differ by at most 1
- **AND** every assigned partition SHALL contribute at least $\lfloor N / P \rfloor$ matching messages

#### Scenario: Redistributing unused quota from empty partitions

- **WHEN** message consumption begins with a result limit of $N$ across $P$ assigned partitions ($P > 1$)
- **AND** one or more partitions have no matching messages in the selected offset or time range
- **AND** the remaining partitions collectively have enough matching messages to fill $N$
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL still emit up to $N$ matching messages from the partitions that have matches
- **AND** SHALL NOT leave unused quota stranded on empty partitions

#### Scenario: Single-partition selection keeps full limit on that partition

- **WHEN** the user explicitly selects a single partition
- **AND** a result limit of $N$ is configured
- **THEN** the consumer SHALL apply the full limit $N$ to that partition alone
- **AND** SHALL NOT attempt cross-partition redistribution

#### Scenario: Unlimited reads are unchanged

- **WHEN** no result limit is configured
- **THEN** the consumer SHALL continue reading across all assigned partitions until stop conditions are met
- **AND** SHALL NOT enforce per-partition match quotas

### Requirement: Tail Offset Resolution for Latest Start Strategy

The message consumer SHALL support starting consumption from the tail of a topic by computing partition start offsets from watermarks and the configured result limit. When multiple partitions are assigned and a limit of $N$ matching messages is configured, each assigned partition's start offset SHALL be resolved using that partition's share of $N$ (as evenly as possible across $P$ partitions), not the full global limit $N$ on every partition. When a single partition is assigned, the full limit $N$ SHALL be used for that partition's tail seek.

#### Scenario: Consuming latest messages from an inactive topic with bounded end

- **WHEN** message consumption begins on a topic with start strategy set to `Latest`
- **AND** a limit of $N$ messages (e.g. 200) is configured
- **AND** $P$ partitions are assigned ($P > 1$)
- **AND** `run_forever` is `false` (Stop condition `End`)
- **THEN** the consumer SHALL resolve the start offset for each assigned partition to `max(low_watermark, high_watermark - share_p)` where `share_p` is that partition's even share of $N$ (floor/ceil split so shares sum to $N$)
- **AND** seek each assigned partition to its resolved start offset
- **AND** poll and emit matching messages under the fair per-partition quotas until the global limit $N$ or partition high watermarks are reached
- **AND** emit `__EOF__` and terminate when the high watermarks or the result limit is reached

#### Scenario: Consuming latest messages with a single selected partition

- **WHEN** message consumption begins with start strategy set to `Latest`
- **AND** a limit of $N$ messages is configured
- **AND** exactly one partition is assigned
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL resolve that partition's start offset to `max(low_watermark, high_watermark - N)`
- **AND** emit up to $N$ matching messages from that partition

#### Scenario: Consuming latest messages on an empty topic

- **WHEN** message consumption begins with start strategy set to `Latest` on a topic where `low_watermark == high_watermark` across all partitions
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL compute `total_to_scan` as `0`
- **AND** immediately emit `__PROGRESS__:0:0` and `__EOF__` without entering polling delays

#### Scenario: Consuming latest messages in live streaming mode

- **WHEN** message consumption begins with start strategy set to `Latest` and `run_forever` set to `true` (Stop condition `Stream`)
- **AND** a limit of $N$ messages is configured
- **AND** $P$ partitions are assigned ($P > 1$)
- **THEN** the consumer SHALL seek each assigned partition to `max(low_watermark, high_watermark - share_p)` using that partition's even share of $N`
- **AND** emit existing tail messages under fair per-partition quotas up to high watermark, while continuing to poll and emit newly produced messages in real time

### Requirement: Pre-compiled Filter Evaluation

The consumer SHALL pre-compile all configured regular expressions, search terms and the filter expression prior to entering the message consumption loop and evaluate them without allocating or compiling new regex instances or parsing the expression per message. The consumer SHALL NOT substitute substring matching for a pattern that failed to compile; an uncompilable pattern or an invalid filter expression SHALL prevent the scan from running instead of producing degraded results.

#### Scenario: Consuming with regex filters
- **WHEN** message consumption begins with `filter_type` set to `Regex` and one or more filter terms provided
- **THEN** the consumer compiles each filter term into a reusable regular expression once during setup
- **AND** matches each incoming message against the pre-compiled expressions without compiling regular expressions inside the message loop

#### Scenario: Uncompilable pattern does not degrade to substring matching
- **WHEN** a scan is requested with `filter_type` set to `Regex` and a pattern that is not a valid regular expression
- **THEN** the scan SHALL NOT start and no messages SHALL be returned as if the filter had matched
- **AND** no regular expression SHALL be compiled inside the message loop as a fallback

#### Scenario: Filter expression compiled once
- **WHEN** a scan is requested with a filter expression containing `matches` conditions and timestamp literals
- **THEN** the expression SHALL be parsed and its regular expressions and timestamps converted once before the first poll
- **AND** no parsing or regular-expression compilation SHALL happen inside the message loop

#### Scenario: Invalid filter expression stops the scan before reading
- **WHEN** a scan is requested with a filter expression that is not valid
- **THEN** the scan SHALL fail before any message is read, reporting the error and its position
- **AND** the failure SHALL be shown as an error, not as an empty result

### Requirement: Cached Schema Registry Resolution

The consumer SHALL cache schema metadata and decoded schemas in memory across messages and across consecutive consumption sessions on the same cluster, resolving schema IDs without synchronous blocking network lookups on cached hits.

#### Scenario: Consuming schema-encoded messages with known schema ID

- **WHEN** a message with Confluent wire format is received and its schema ID has been previously resolved in the current cluster session
- **THEN** the consumer resolves the schema from the local in-memory cache
- **AND** decodes the payload without executing blocking runtime calls or HTTP requests to the Schema Registry

### Requirement: Throttled UI State Emission and Amortized Buffering

The Flutter message streaming layer SHALL buffer messages from native Rust streams, for the single-topic stream and for every multi-topic search target, and dispatch UI state notifications at most once every 50ms to 100ms, delivering the last pending batch within one such interval. Adding a message, and dropping the oldest one at the buffer limit, SHALL take amortized $O(1)$ time without shifting the retained messages.

#### Scenario: High-throughput message streaming to UI

- **WHEN** Kafka messages arrive across the FFI stream at sustained throughput exceeding 100 messages per second
- **THEN** the UI controller buffers incoming messages and triggers state notifications at a throttled cadence between 50ms and 100ms
- **AND** does not invoke `notifyListeners()` on every individual message
- **AND** adds incoming messages without $O(N)$ list prepending shifts

#### Scenario: Last batch before a quiet period is delivered

- **WHEN** a multi-topic search target or the single-topic stream receives a burst of messages and then no further message for several seconds
- **THEN** every message of the burst SHALL be visible to the UI no later than 100ms after it arrived
- **AND** the UI SHALL NOT wait for a later message or for the end of the stream to show them

#### Scenario: Dropping the oldest message at the buffer limit does not shift the buffer

- **WHEN** the buffer holds as many messages as the buffer limit allows
- **AND** 10,000 further matching messages arrive
- **THEN** each arrival SHALL replace the oldest retained message in constant time
- **AND** the remaining retained messages SHALL NOT be moved or copied per arriving message

### Requirement: Result Buffer Honors Configured Limit

The streaming layer SHALL retain the matching messages of a session, for the single-topic stream and each multi-topic search target, up to the smaller of the result limit and the message buffer limit setting. At the buffer limit the oldest messages SHALL be dropped in arrival order and the view SHALL show how many were dropped. Messages MUST NOT be dropped silently or at a fixed ceiling. Retained messages SHALL stay available for display and export; match counts SHALL report all received matches.

#### Scenario: Unlimited consumption retains more than 1000 matches

- **WHEN** message consumption runs with no result limit configured and a buffer limit of 50,000
- **AND** 1,500 matching messages are delivered before the stream ends
- **THEN** the in-session message buffer SHALL contain all 1,500 delivered matching messages
- **AND** message export for that session SHALL include all retained matching messages
- **AND** no dropped-messages indicator SHALL be shown

#### Scenario: Configured limit above 1000 retains up to N matches

- **WHEN** message consumption runs with a result limit of $N$ where $1000 < N \le$ the buffer limit
- **AND** at least $N$ matching messages are available in the selected range
- **THEN** the in-session message buffer SHALL retain $N$ matching messages
- **AND** SHALL NOT drop matching messages solely because more than 1000 were received

#### Scenario: Configured limit still caps retention

- **WHEN** message consumption runs with a result limit of $N$
- **AND** more than $N$ matching messages would otherwise be available
- **THEN** the in-session message buffer SHALL retain at most $N$ matching messages
- **AND** consumption SHALL stop once $N$ matching messages have been received

#### Scenario: Buffer limit drops the oldest messages with a visible count

- **WHEN** a live stream runs with no result limit and a buffer limit of 1,000
- **AND** 1,250 matching messages have been received
- **THEN** the buffer SHALL retain the 1,000 most recently received messages
- **AND** the topic view SHALL show that 250 oldest messages were dropped
- **AND** the match count SHALL show 1,250 received matches

#### Scenario: Result limit above the buffer limit

- **WHEN** message consumption runs with a result limit of 80,000 and a buffer limit of 50,000
- **AND** 80,000 matching messages are available
- **THEN** consumption SHALL continue until 80,000 matching messages have been received
- **AND** the buffer SHALL retain the newest 50,000 and the view SHALL show that 30,000 oldest messages were dropped

#### Scenario: Multi-topic search target has no silent ceiling

- **WHEN** a script or multi-topic search target receives 6,000 matching messages with a buffer limit of 5,000
- **THEN** that target SHALL retain the newest 5,000 messages
- **AND** its topic progress entry SHALL show 6,000 matches and that 1,000 oldest messages were dropped
- **AND** a target receiving 3,000 matching messages SHALL retain all 3,000 and show no dropped count

#### Scenario: New session resets the dropped count

- **WHEN** messages were dropped in a previous session of a topic tab
- **AND** the user starts a new stream or clears the messages
- **THEN** the dropped count SHALL be reset to zero and the indicator SHALL be hidden

#### Scenario: Stream error after drops keeps the count

- **WHEN** a live stream fails with an error after messages were dropped
- **THEN** the retained messages and the dropped count SHALL stay visible next to the error

### Requirement: Non-Blocking Consumer Disk Logging

When message logging to an output directory is enabled, the search and consumption pipeline SHALL persist log entries asynchronously without executing synchronous blocking file I/O operations on the Flutter main UI isolate.

#### Scenario: Logging consumer events to disk

- **WHEN** a log message is received from the consumer stream while file logging is enabled
- **THEN** the log entry is written asynchronously using non-blocking I/O
- **AND** does not block frame rendering on the Flutter UI isolate

### Requirement: Preset-Based Scan Mode Selector

The topic search configuration SHALL provide four primary scan mode presets ("Latest N Messages", "Live Tail Stream", "Time Range", and "Offset / Earliest") that automatically configure consumer start and stop strategies without requiring manual configuration of independent start and stop matrices.

#### Scenario: Selecting "Latest N Messages" preset
- **WHEN** the user selects the "Latest N Messages" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `latest`
- **AND** the consumer SHALL stop upon reaching partition high watermarks or the result limit

#### Scenario: Selecting "Live Tail Stream" preset
- **WHEN** the user selects the "Live Tail Stream" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `stream`
- **AND** the consumer SHALL continue polling for newly arriving messages until manually stopped

#### Scenario: Selecting "Time Range" preset
- **WHEN** the user selects the "Time Range" scan mode preset
- **THEN** the search bar SHALL display start and end timestamp input controls
- **AND** consumption SHALL be bounded between the specified timestamps

#### Scenario: Selecting "Offset / Earliest" preset
- **WHEN** the user selects the "Offset / Earliest" scan mode preset
- **THEN** the search bar SHALL display offset selection controls with options for earliest or explicit custom partition offsets

---

### Requirement: Progressive Disclosure for Advanced Topic Search Filters

The topic search bar SHALL default to a compact, single-row primary control layout. The fetch filter field SHALL offer `Search Scope: Key | Value | Both` and `Filter Type: Contains | Regex | Exact` through a compact inline menu inside the field that always shows the current choice. The remaining parameters (`Field`, `Partition`, `Fast Trace` and `Expression`) SHALL be reachable through a single "More filters" button that opens a popover overlaying the results instead of pushing them down. The button SHALL show the number of active parameters. While the popover is closed, any non-default parameter SHALL be visibly summarized as removable or clickable filter chips in the compact bar.

#### Scenario: Initial display in collapsed mode
- **WHEN** a topic view is opened
- **THEN** the search bar SHALL occupy a single row containing the scan mode, the limit, the fetch filter field with its scope and type menu, and the "More filters" button
- **AND** the `Field`, `Partition`, `Fast Trace` and `Expression` controls SHALL be hidden

#### Scenario: Scope and type visible in the field
- **WHEN** the user sets the scope to `Key` and the type to `Exact`
- **THEN** the fetch filter field SHALL show "Key · Exact" (localized) in its inline menu without opening any panel
- **AND** the fetch filter field's placeholder SHALL name the selected scope

#### Scenario: Expanding advanced filters
- **WHEN** the user activates the "More filters" button
- **THEN** a popover with `Field`, `Partition`, `Fast Trace` with its partition preview, and the expression editor SHALL open below the button
- **AND** the message list and an active stream SHALL keep their position and SHALL NOT be pushed down

#### Scenario: Closing more filters
- **WHEN** the popover is open and the user presses Escape, clicks outside it or activates the button again
- **THEN** the popover SHALL close and its entered values SHALL be kept

#### Scenario: Active filter count
- **WHEN** a partition filter and a filter expression are set
- **THEN** the "More filters" button SHALL show the count 2, conveyed by text and not by colour alone

#### Scenario: Non-default filter chips when collapsed
- **WHEN** the user has configured a partition filter (e.g. Partition `3`) and closes the popover
- **THEN** compact chips displaying the active values (e.g. `Partition: 3`) SHALL appear in the compact search bar
- **AND** clicking a chip or its removal icon SHALL allow quick editing or clearing of the parameter

#### Scenario: Active expression chip when collapsed
- **WHEN** the user has entered a filter expression and closes the popover
- **THEN** a chip SHALL show the expression's canonical text, shortened with an ellipsis when long and complete in its tooltip
- **AND** the chip SHALL indicate an invalid expression by an icon and text, not by colour alone
- **AND** clicking the chip SHALL open the popover with the expression editor and its removal icon SHALL clear the expression

#### Scenario: Popover on a small window
- **WHEN** the window is too low to show the whole popover below the button
- **THEN** the popover content SHALL scroll within the visible window area and its controls SHALL stay reachable

#### Scenario: Restored session and saved search
- **WHEN** a tab session or saved search with field, type, scope, partition, Fast Trace and expression values is restored
- **THEN** every value SHALL be applied unchanged and reflected in the inline menu, the button count and the chips

---

### Requirement: Filter Pattern Validation Feedback

The search configuration SHALL validate a regular-expression filter term before a scan starts and whenever the term changes, and SHALL report an invalid pattern to the user in the active UI language at the input that caused it.

#### Scenario: Invalid pattern blocks the scan
- **WHEN** the user enters the filter term `orders[` with filter type `Regex` and triggers the scan
- **THEN** the scan SHALL be refused
- **AND** the filter input SHALL show a localized inline error naming the invalid term
- **AND** the inline scope and type menu of the field SHALL indicate the invalid state by an icon, not by colour alone

#### Scenario: Valid pattern produces no validation message
- **WHEN** the user enters a syntactically valid regular expression and triggers the scan
- **THEN** the scan SHALL start and no validation error SHALL be shown

### Requirement: Compact Scan Bounds Row

When the scan mode needs bounds (Time Range or Offset / Earliest), the search bar SHALL show them in one additional row
directly below the primary row. Relative time presets SHALL be offered through one menu per bound instead of rows of
preset chips. The row SHALL wrap onto a second line only when the pane is too narrow for both bounds.

#### Scenario: Time range on a laptop
- **WHEN** the user selects the "Time Range" scan mode in a pane 1000 logical pixels wide
- **THEN** start and end time SHALL be shown side by side in a single row, each with a preset menu
- **AND** no row of preset chips SHALL be shown

#### Scenario: Applying a preset
- **WHEN** the user picks "Last 1 hour" from the start time preset menu
- **THEN** the start time SHALL be set exactly as the former preset chip did

#### Scenario: Narrow pane
- **WHEN** the pane is narrower than both bound inputs together
- **THEN** the end bound SHALL move onto a second line and both inputs SHALL remain fully usable

#### Scenario: Invalid bound
- **WHEN** the entered end time lies before the start time or cannot be parsed
- **THEN** the affected input SHALL show a localized inline error and the scan SHALL NOT start

### Requirement: Distinct Labels for Fetch-Time and Loaded-Message Filtering

The fetch filter field in the search bar and the in-memory filter of the results toolbar SHALL be labelled so that
users can tell them apart: the fetch filter SHALL name that it is applied while reading from the topic, and SHALL show
a tooltip explaining that it limits which messages are fetched.

#### Scenario: Both fields visible
- **WHEN** a topic view with 200 loaded messages is shown
- **THEN** the search bar field SHALL carry a localized label that it filters while fetching, with an explanatory tooltip
- **AND** the results toolbar field SHALL keep stating that it filters the 200 loaded messages

#### Scenario: German UI
- **WHEN** the UI language is German
- **THEN** both labels and the tooltip SHALL be rendered from German localized strings

### Requirement: Match Diagnostics Without Payload Echo

Scan diagnostics for a filter match SHALL identify the match by topic, partition, offset and the matched filter term, or the marker `expression` for a match that only a filter expression decided, and SHALL NOT stream message payload or key content as a diagnostic record to the user interface.

#### Scenario: Large payloads do not inflate diagnostics
- **WHEN** a scan with a filter term matches many messages whose payloads exceed 100 KB each
- **THEN** each match diagnostic SHALL contain topic, partition, offset and filter term only
- **AND** no diagnostic record SHALL contain the matched payload or key text

#### Scenario: Matched content stays visible in the results
- **WHEN** a message is returned by a filtered scan
- **THEN** its full payload SHALL remain available in the message table and in the message inspector

#### Scenario: Expression match diagnostics
- **WHEN** a scan with only a filter expression matches a message
- **THEN** the match diagnostic SHALL contain topic, partition, offset and the marker `expression`, not the expression text or any field value
- **AND** the canonical expression text SHALL be logged once when the scan starts

### Requirement: Consumption Criteria Named Per Request

A message-consumption request SHALL carry each of its criteria exactly once and identified by name rather than by position: topic and partition selection, start and end bounds, filter terms, filter field, filter type, search scope, structured filter expression with its variables, result limit, live mode, tail start and the locally supplied schemas. A criterion the request does not carry SHALL keep its documented default.

#### Scenario: Optional criterion omitted

- **WHEN** a consumption request supplies no structured filter expression and no tail start
- **THEN** the run SHALL behave as before with structured filtering off and tail start off
- **AND** the emitted messages SHALL be the same set as with those criteria explicitly set to their defaults

#### Scenario: Two criteria share a type

- **WHEN** a request carries two criteria of the same value type, for example a start bound and a filter field
- **THEN** each criterion SHALL be applied to the purpose its name identifies
- **AND** exchanging the two values without exchanging their names SHALL NOT be representable in a well-formed request

#### Scenario: Criterion recorded before this change is replayed

- **WHEN** a saved search or script step stored by an earlier version is run again
- **THEN** its stored criteria SHALL resolve to one request carrying those same criteria
- **AND** the run SHALL emit the same result set as it did for the same cluster and topic before the change
- **AND** a stored criterion that can no longer be understood SHALL be reported and SHALL NOT be dropped silently

#### Scenario: A criterion refers to a partition that is not readable

- **WHEN** the request selects a partition whose read is denied by cluster permissions
- **THEN** the run SHALL report that partition as not readable
- **AND** it SHALL NOT present the outcome as an empty result or a zero count
