<!-- markdownlint-disable MD041 -->
## Context

See `proposal.md` for background and motivation.

The initial implementation of topic content analysis identified top-level JSON/Avro fields and tracked up to 5 values only for a subset of predefined categorical keywords. Users need a comprehensive and interactive Top 10 values per field breakdown across all discovered structured fields to quickly analyze data distributions, frequent status codes, enum values, and customer IDs.

## Goals / Non-Goals

**Goals:**

- Track and rank the top 10 most frequent values for all scalar fields (strings, numbers, booleans) in native Rust.
- Provide an interactive Flutter Field Value Explorer allowing users to select any discovered field to view its Top 10 values with visual distribution bars, occurrence counts, and copy shortcuts.
- Keep in-memory aggregation bounded in Rust (capping value tracking to 200 distinct values per field) to prevent memory bloat on high-cardinality fields (e.g. UUIDs or timestamps).
- Provide search filtering for discovered field names.
- Ensure full localization across English and German (`app_en.arb`, `app_de.arb`).

**Non-Goals:**

- Nested JSON path query engine or JSONPath evaluation (focuses on top-level and first-tier structured message attributes).
- Long-term historical database persistence.

## Decisions

### 1. Universal Scalar Value Tracking vs Categorical-Only Filter

- **Decision**: Remove the restriction that only tracks fields matching `is_categorical_field`. Instead, track top values for all scalar fields (string, number, boolean) while limiting string length to 80 chars and per-field map size to 200 entries.
- **Rationale**: Real-world Kafka payloads have diverse domain field names (`region`, `countryCode`, `sku`, `currency`, `gateway`, etc.) that benefit from top-value analysis without needing to anticipate every possible field name.
- **Alternatives Considered**:
  - *Hardcoding more keywords*: Fragile and misses custom business domain fields.

### 2. Interactive Two-Pane / Expandable Field Explorer in Flutter

- **Decision**: Implement an interactive Field Value Explorer in the analysis view: a field list on the left with search filtering and an expanded Top 10 Values detail card on the right (or expandable accordion on narrower screens).
- **Rationale**: Displays the full Top 10 list with exact counts, percentages, and copy buttons cleanly without cluttering the main overview dashboard.

### 3. Top-K Selection in Rust

- **Decision**: In Rust's `to_report()`, sort each field's value map descending by count, take the top 10, and compute `percentage = (value_count / field_occurrence_count) * 100.0`.
- **Rationale**: Computes accurate percentages relative to how often the field actually appeared in the topic.

## Risks / Trade-offs

- **[Risk] High-cardinality fields (e.g. unique UUIDs, random IDs) creating large HashMaps** → **Mitigation**: Cap value map to 200 entries per field in Rust. Once 200 distinct values are tracked, new distinct values are ignored in the top-K tracker.
- **[Risk] Long string values causing UI overflow** → **Mitigation**: Truncate preview strings in Rust and provide full tooltip and one-click copy in the Flutter UI.

## Migration Plan

- Non-breaking update.
- Updated report structures and UI components maintain compatibility with existing controllers.
