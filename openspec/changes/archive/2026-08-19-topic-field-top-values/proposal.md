<!-- markdownlint-disable MD041 -->
## Why

While the topic content analysis engine detects top-level JSON/Avro fields, users need to drill into specific fields to understand the most common values (Top 10 values per field), their occurrence counts, and percentage distribution. This provides immediate insights into domain data distributions, categorical skew, status frequencies, and dominant business entities.

## What Changes

- **Backend Aggregation Enhancement (Rust)**:
  - Track the top 10 most frequent values for all discovered structured fields (strings, numbers, booleans) during scanning, bounded per field.
  - Return up to 10 top values per field along with occurrence counts and percentage shares.
- **Frontend Field Value Explorer (Flutter)**:
  - Extend the structured field frequency UI into an interactive Top 10 Field Value list / table.
  - Allow users to select/expand any field to view its Top 10 values with visual distribution bars, exact counts, and copy actions.
  - Provide search/filtering across discovered field names.
- **Localization**:
  - Add localized strings for the Top 10 field values list, distinct value indicators, and field search.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities

- `topic-content-analysis`: Extend value structure and field analysis to track and display the top 10 values per field with interactive drill-down and frequency percentages.

## Impact

- **Backend (Rust)**: Update `rust/kafkalyzer-kafka/src/kafka_analyzer.rs` to track up to 10 values per field across all structured fields with bounded top-K map retention.
- **Bridge Layer**: Re-generate or verify `FieldOccurrence` and `FieldValueOccurrence` structures.
- **Frontend (Flutter)**: Update `lib/src/features/topic/presentation/widgets/analysis/key_and_field_distribution_view.dart` (or dedicated field values component) to provide an interactive Top 10 values per field explorer.
- **Localization**: Update `app_en.arb` and `app_de.arb`.
