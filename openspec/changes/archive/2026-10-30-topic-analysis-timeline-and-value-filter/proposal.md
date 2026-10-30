# Proposal

## Why

The topic analysis currently folds every message timestamp into 24 hour-of-day buckets (UTC). That shows *when during a day* a topic is busy, but it cannot answer the operational questions users actually ask during an incident: "Did this topic receive unusually many messages in the last hours?" and "How did the volume develop day by day?". In addition, the field statistics only cover top-level payload fields and only the Top 10 values, so a user cannot find out how often a specific value (e.g. `status = FAILED`, or a value inside a map such as `attributes.region = EU`) occurs, nor how that share compares to the rest of the topic or how it develops over time.

## What Changes

- **Recent production timeline**: the analysis records message counts per absolute clock hour. After a scan the user sees the message count per hour for a selectable recent window (6 / 12 / 24 / 48 / 72 h, default 24 h, switchable without rescanning), shown in the computer's local time zone.
- **Unusual-increase detection**: each hour in the recent window is compared with the average of the same clock hour on up to 7 preceding days; hours that are clearly above that baseline are highlighted. Hours without baseline data are marked as such.
- **Coverage awareness**: the report records the moment from which the scanned data is complete (relevant for "sample last N messages" scopes), and the timeline shows when the selected window is only partially covered.
- **Daily distribution**: a per-day view lists weekday, date and message count for every day in the scanned range (local time zone).
- **Field value filter before the scan**: the user can restrict the analysis to a field path (canonical field-path syntax, including nested/map paths such as `attributes.region`) and an exact value. The full report still describes all scanned messages; an additional "filter matches" section shows the match count, its share of all scanned messages, its share of messages that carry the field, and the match timeline (recent hours and per day) next to the total.
- **Field value drill-down after the scan**: from the field value explorer the user can select a discovered value (including nested fields) to see its count and share immediately, and can start a re-scan with that value pre-set as filter to get exact counts and the timeline.
- **Nested field statistics**: field frequency analysis descends into nested JSON objects / Avro records and maps, reporting each nested field under its field path; the report indicates when a field's distinct-value tracking was capped so counts are labelled approximate.
- **Export/import**: exported analysis files include the hourly timeline, coverage information and the filter result. The file format version is raised; files written by older versions remain importable, with the new sections marked as unavailable.
- Existing behaviour is kept: the 24h hour-of-day chart, the existing `analyze_topic_content` bridge function and the report comparison stay unchanged.

## Capabilities

### New Capabilities

- `topic-production-timeline`: Recent-hours production view with baseline comparison and anomaly highlighting, per-day distribution with weekday and date, local-time presentation and data-coverage indication for topic analysis reports.
- `topic-analysis-value-filter`: Restricting a topic analysis to a field path and value (before the scan or from discovered values after the scan), reporting match count, relative shares and match timeline alongside the unfiltered report.

### Modified Capabilities

- `topic-content-analysis`: "Value Structure and Field Frequency Analysis" changes from top-level-only fields to nested field paths (objects and maps) and adds an approximate-count indicator when distinct-value tracking is capped.
- `topic-analysis-export-import`: "Export an analysis report to a portable file" must include the hourly timeline, coverage and filter result; a new requirement keeps files of the previous format version importable with the new sections marked unavailable.

## Impact

- **Rust core (`kafkalyzer-core`)**: new domain types (hour buckets, value filter, filter result, analysis options), new optional report fields with `serde(default)`, a field-path lookup that distinguishes "absent" from "null" in `json_path`, and a helper that renders a nested field path in the canonical syntax.
- **Rust Kafka (`kafkalyzer-kafka`)**: `AnalyzerAccumulator` gains an hourly timeline map, coverage tracking, recursive field flattening and filter-match accumulation; `analyze_topic_content` accepts an options struct (old signature kept as wrapper).
- **Bridge (`rust_lib_kafkalyzer`)**: new bridge structs and a new `analyze_topic_content_with_options` function; the existing `analyze_topic_content` stays signature-compatible. `flutter_rust_bridge` code must be regenerated.
- **Flutter**: `TopicAnalysisController` (filter state, re-scan with filter), new pure timeline computation in a domain file, new widgets (recent production chart, daily distribution, filter input, filter match summary), `FieldValueExplorer` drill-down action, `TopicAnalysisReportFile` v2, new `.arb` strings (en/de).
- **Tests**: Rust accumulator unit tests, Dart unit tests for timeline/baseline computation and file v1/v2 import, widget tests for the new sections.
- No new dependencies.
