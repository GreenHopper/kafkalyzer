import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';

/// Maps a [LocalDecodeErrorKindDto] and its detail string to a localized
/// user-facing description.
String describeLocalDecodeError(
  AppLocalizations l10n,
  LocalDecodeErrorKindDto kind,
  String detail,
) {
  switch (kind) {
    case LocalDecodeErrorKindDto.fileNotFound:
      return l10n.localDecodeErrorFileNotFound(detail);
    case LocalDecodeErrorKindDto.fileUnreadable:
      return l10n.localDecodeErrorFileUnreadable(detail);
    case LocalDecodeErrorKindDto.fileTooLarge:
      return l10n.localDecodeErrorFileTooLarge(detail);
    case LocalDecodeErrorKindDto.schemaInvalid:
      return l10n.localDecodeErrorSchemaInvalid(detail);
    case LocalDecodeErrorKindDto.unsupportedProto2:
      return l10n.localDecodeErrorUnsupportedProto2(detail);
    case LocalDecodeErrorKindDto.unresolvedImport:
      return l10n.localDecodeErrorUnresolvedImport(detail);
    case LocalDecodeErrorKindDto.messageTypeNotFound:
      return l10n.localDecodeErrorMessageTypeNotFound(detail);
    case LocalDecodeErrorKindDto.missingPrefix:
      return l10n.localDecodeErrorMissingPrefix(detail);
    case LocalDecodeErrorKindDto.unknownMessageIndex:
      return l10n.localDecodeErrorUnknownMessageIndex(detail);
    case LocalDecodeErrorKindDto.payloadMismatch:
      return l10n.localDecodeErrorPayloadMismatch(detail);
    case LocalDecodeErrorKindDto.trailingBytes:
      return l10n.localDecodeErrorTrailingBytes(detail);
    case LocalDecodeErrorKindDto.notJson:
      return l10n.localDecodeErrorNotJson(detail);
  }
}

/// Returns the localized display label for a [LocalSchemaFormatDto].
String localSchemaFormatLabel(
  AppLocalizations l10n,
  LocalSchemaFormatDto format,
) {
  switch (format) {
    case LocalSchemaFormatDto.avro:
      return l10n.localSchemaFormatAvro;
    case LocalSchemaFormatDto.protobufSource:
      return l10n.localSchemaFormatProtobufSource;
    case LocalSchemaFormatDto.protobufDescriptor:
      return l10n.localSchemaFormatProtobufDescriptor;
    case LocalSchemaFormatDto.jsonSchema:
      return l10n.localSchemaFormatJsonSchema;
  }
}
