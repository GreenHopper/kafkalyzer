# Proposal

## Why

The duplicate detection in topic analysis accurately measures message redundancy and aggregates occurrences, but represents structured messages encoded with Schema Registry wire format (Avro, Protobuf) or non-UTF-8 binary as raw byte previews such as `[Binary 0x00000014fa185796]`. This deprives users of any actionable insight into the actual semantic payload of the duplicated messages. Providing decoded payload previews and an interactive duplicate message inspector is essential for users to diagnose which domain records are being redundantly produced.

## What Changes

- **Decoded Duplicate Previews in Analyzer Engine**: When recording duplicate message samples in `AnalyzerAccumulator`, use the decoded payload value (from Schema Registry Avro/Protobuf or parsed JSON) rather than falling back immediately to raw hex byte representation.
- **Top Duplicate Message Inspection Dialog**: Add a drill-down details dialog in the UI when clicking on a duplicate row or info icon. The dialog displays:
  - Exact coordinates: Partition, Offset, and Timestamp.
  - Key (with quick copy action).
  - Occurrence frequency and percentage share of total scanned messages.
  - Full decoded payload formatted as readable JSON/text with syntax formatting and copy-to-clipboard action.
- **Direct Navigation to Message View**: Provide an action in the inspection dialog to jump directly to the sample offset in the topic's "Messages" view when connected to a live cluster.
- **Safe Fallback**: If Schema Registry decoding is unavailable or the payload is arbitrary binary, maintain clear indicator representations (`[Binary 0x...]`) without failing analysis.

## Capabilities

### New Capabilities
*(None)*

### Modified Capabilities
- `topic-duplicate-detection`: Update the `Top Duplicated Messages Ranking` and `Duplicate Analysis Dashboard Presentation` requirements to mandate decoded payload representation and interactive details drill-down.

## Impact

- `rust/kafkalyzer-kafka/src/kafka_analyzer.rs`: Leverage `parsed_payload` when generating sample previews during duplicate accumulation.
- `lib/src/features/topic/presentation/widgets/analysis/duplicate_analysis_view.dart`: Add duplicate details dialog with formatted payload display, copy actions, and message navigation.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`: Add localization entries for duplicate inspection dialog and actions.
