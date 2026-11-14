import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';

/// Formats a [DecodeKind] into a localized label.
String decodeKindLabel(AppLocalizations? l10n, DecodeKind kind) {
  switch (kind) {
    case DecodeKind.json:
      return l10n?.decodeAsJson ?? 'JSON';
    case DecodeKind.base64:
      return l10n?.decodeAsBase64 ?? 'Base64';
    case DecodeKind.gzip:
      return l10n?.decodeAsGzip ?? 'gzip';
  }
}

/// Formats a [DecodeError] into a localized message.
String decodeErrorMessage(
  AppLocalizations? l10n,
  DecodeError error, {
  int? limit,
}) {
  final limitMib = (limit ?? 0) ~/ (1024 * 1024);
  switch (error) {
    case DecodeError.invalidJson:
      return l10n?.decodeErrorInvalidJson ?? 'Not valid JSON';
    case DecodeError.invalidBase64:
      return l10n?.decodeErrorInvalidBase64 ?? 'Not valid Base64';
    case DecodeError.notGzip:
      return l10n?.decodeErrorNotGzip ?? 'Not a gzip stream';
    case DecodeError.corruptGzip:
      return l10n?.decodeErrorCorruptGzip ?? 'Corrupt gzip data';
    case DecodeError.inputTooLarge:
      return l10n?.decodeErrorInputTooLarge(limitMib) ??
          'Input exceeds $limitMib MiB limit';
    case DecodeError.outputTooLarge:
      return l10n?.decodeErrorOutputTooLarge(limitMib) ??
          'Decoded output exceeds $limitMib MiB limit';
  }
}

/// Formats a [Uint8List] / `List<int>` as a lowercase space-separated hex preview.
String formatHexBytes(List<int> bytes, {int? maxBytes}) {
  final count = maxBytes != null && bytes.length > maxBytes
      ? maxBytes
      : bytes.length;
  final sb = StringBuffer();
  for (var i = 0; i < count; i++) {
    if (i > 0) sb.write(' ');
    sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  if (maxBytes != null && bytes.length > maxBytes) {
    sb.write(' …');
  }
  return sb.toString();
}
