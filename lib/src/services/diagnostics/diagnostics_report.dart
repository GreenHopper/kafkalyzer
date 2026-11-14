import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';

class DiagnosticsReport {
  DiagnosticsReport._();

  static String build({
    required String? appVersion,
    required String? osName,
    required String? osVersion,
    required String? locale,
    required String? logPath,
    required ClusterProfile? activeProfile,
    required List<ErrorRecord> recentErrors,
  }) {
    String fieldOrUnknown(String? value) =>
        (value == null || value.trim().isEmpty) ? 'unknown' : value.trim();

    final buffer = StringBuffer()
      ..writeln('Kafkalyzer Diagnostics Report')
      ..writeln('App Version: ${fieldOrUnknown(appVersion)}')
      ..writeln('OS: ${fieldOrUnknown(osName)} (${fieldOrUnknown(osVersion)})')
      ..writeln('Locale: ${fieldOrUnknown(locale)}')
      ..writeln(
        'Log File: ${(logPath == null || logPath.trim().isEmpty) ? 'unavailable' : logPath.trim()}',
      )
      ..writeln();

    if (activeProfile == null) {
      buffer.writeln('Active Profile: none');
    } else {
      final serverCount = activeProfile.bootstrapServers
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .length;
      final hasRegistry =
          activeProfile.schemaRegistryUrl != null &&
          activeProfile.schemaRegistryUrl!.trim().isNotEmpty;
      final hasTruststore =
          activeProfile.sslTruststoreLocation != null &&
          activeProfile.sslTruststoreLocation!.trim().isNotEmpty;
      final hasKeystore =
          (activeProfile.sslKeystoreLocation != null &&
              activeProfile.sslKeystoreLocation!.trim().isNotEmpty) ||
          (activeProfile.sslPemCertificateLocation != null &&
              activeProfile.sslPemCertificateLocation!.trim().isNotEmpty);

      buffer
        ..writeln('Active Profile Summary:')
        ..writeln('  Security Protocol: ${activeProfile.securityProtocol}')
        ..writeln('  SASL Mechanism: ${activeProfile.mechanism ?? 'none'}')
        ..writeln('  TLS Verification: ${activeProfile.tlsVerification.name}')
        ..writeln('  Schema Registry Configured: ${hasRegistry ? 'yes' : 'no'}')
        ..writeln('  Truststore Configured: ${hasTruststore ? 'yes' : 'no'}')
        ..writeln('  Keystore Configured: ${hasKeystore ? 'yes' : 'no'}')
        ..writeln('  Bootstrap Server Count: $serverCount');
    }

    buffer.writeln();
    if (recentErrors.isEmpty) {
      buffer.writeln('Recent Errors: none');
    } else {
      buffer.writeln('Recent Errors (${recentErrors.length}):');
      for (final err in recentErrors) {
        buffer.writeln(
          '- [${err.timestampUtc.toIso8601String()}] [${err.origin}] ${err.type}: ${err.message}',
        );
      }
    }

    return buffer.toString().trimRight();
  }
}
