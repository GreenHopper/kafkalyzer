import 'package:kafkalyzer/src/rust/api/profile_tools.dart';

/// Wraps the Rust `profile_tools` FFI functions so UI and controllers can
/// substitute a pure-Dart fake in widget and unit tests.
class ClusterProfileTools {
  const ClusterProfileTools();

  List<BootstrapServerIssue> validateBootstrapServers(String value) =>
      rustValidateBootstrapServers(value: value);

  List<ExtraPropertyIssue> validateExtraProperties(String text) =>
      rustValidateExtraProperties(text: text);

  List<AllowedExtraProperty> allowedExtraProperties() =>
      rustAllowedExtraProperties();

  Future<ClientPropertiesPreview> parseClientProperties(String content) =>
      rustParseClientProperties(content: content);
}

List<BootstrapServerIssue> rustValidateBootstrapServers({
  required String value,
}) => validateBootstrapServers(value: value);

List<ExtraPropertyIssue> rustValidateExtraProperties({required String text}) =>
    validateExtraProperties(text: text);

List<AllowedExtraProperty> rustAllowedExtraProperties() =>
    allowedExtraProperties();

Future<ClientPropertiesPreview> rustParseClientProperties({
  required String content,
}) => parseClientProperties(content: content);
