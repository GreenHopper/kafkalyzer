import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;

/// Localized display name for a [api.SchemaKindDto].
String schemaKindLabel(
  AppLocalizations? l10n,
  api.SchemaKindDto kind, {
  String? otherName,
}) {
  switch (kind) {
    case api.SchemaKindDto.avro:
      return l10n?.schemaTypeAvro ?? 'Avro';
    case api.SchemaKindDto.protobuf:
      return l10n?.schemaTypeProtobuf ?? 'Protobuf';
    case api.SchemaKindDto.json:
      return l10n?.schemaTypeJson ?? 'JSON Schema';
    case api.SchemaKindDto.other:
      final trimmed = otherName?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
      return l10n?.schemaTypeGeneric ?? 'Schema';
  }
}

/// File extension (without leading dot) for saving a schema of [kind].
String schemaFileExtension(api.SchemaKindDto kind) {
  switch (kind) {
    case api.SchemaKindDto.avro:
      return 'avsc';
    case api.SchemaKindDto.json:
      return 'json';
    case api.SchemaKindDto.protobuf:
      return 'proto';
    case api.SchemaKindDto.other:
      return 'txt';
  }
}

/// Computes the localized schema badge label for a topic given its key/value
/// [SchemaTypeState]s and whether the subject list itself failed to load.
String topicSchemaBadgeLabel(
  AppLocalizations? l10n, {
  required SchemaTypeState? keyState,
  required SchemaTypeState? valueState,
  required bool subjectListFailed,
}) {
  if (subjectListFailed) {
    return l10n?.schemaTypeUnknown ?? 'Schema (unknown)';
  }

  final keyLabel = _stateLabel(l10n, keyState);
  final valueLabel = _stateLabel(l10n, valueState);

  if (keyLabel != null && valueLabel != null) {
    if (keyLabel == valueLabel) return keyLabel;
    return l10n?.schemaTypeMixed(keyLabel, valueLabel) ??
        '$keyLabel / $valueLabel';
  }
  if (valueLabel != null) return valueLabel;
  if (keyLabel != null) return keyLabel;

  if (keyState is SchemaTypeFailed || valueState is SchemaTypeFailed) {
    return l10n?.schemaTypeUnknown ?? 'Schema (unknown)';
  }
  return l10n?.schemaTypeGeneric ?? 'Schema';
}

String? _stateLabel(AppLocalizations? l10n, SchemaTypeState? state) {
  if (state is SchemaTypeKnown) {
    return schemaKindLabel(l10n, state.kind, otherName: state.otherName);
  }
  return null;
}
