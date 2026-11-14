import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/diagnostics/diagnostics_report.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';

void main() {
  test(
    'builds report with connected profile without leaking host, name, user, path, or secret',
    () {
      const profile = ClusterProfile(
        name: 'Prod Sensitive Name',
        bootstrapServers:
            'secret-broker-1.internal:9093, secret-broker-2.internal:9093',
        securityProtocol: 'SASL_SSL',
        saslUsername: 'alice_user',
        saslPassword: 'super_secret_password',
        mechanism: 'SCRAM-SHA-512',
        sslTruststoreLocation: '/home/alice/ca.pem',
        sslKeystoreLocation: '/home/alice/client.p12',
        schemaRegistryUrl: 'https://registry.internal:8081',
        schemaRegistryPassword: 'sr_secret_password',
        tlsVerification: TlsVerification.enabled,
      );

      final report = DiagnosticsReport.build(
        appVersion: '1.2.3+4',
        osName: 'linux',
        osVersion: '6.8.0',
        locale: 'en',
        logPath: '/home/alice/.local/share/kafkalyzer/logs/kafkalyzer.log',
        activeProfile: profile,
        recentErrors: [
          ErrorRecord(
            timestampUtc: DateTime.utc(2026, 11, 14, 10, 0, 0),
            origin: 'dart',
            type: 'StateError',
            message: 'failed cleanly',
            stackLines: const [],
          ),
        ],
      );

      expect(report, contains('App Version: 1.2.3+4'));
      expect(report, contains('Security Protocol: SASL_SSL'));
      expect(report, contains('SASL Mechanism: SCRAM-SHA-512'));
      expect(report, contains('TLS Verification: enabled'));
      expect(report, contains('Schema Registry Configured: yes'));
      expect(report, contains('Truststore Configured: yes'));
      expect(report, contains('Keystore Configured: yes'));
      expect(report, contains('Bootstrap Server Count: 2'));
      expect(report, contains('Recent Errors (1):'));

      expect(report, isNot(contains('Prod Sensitive Name')));
      expect(report, isNot(contains('secret-broker-1')));
      expect(report, isNot(contains('alice_user')));
      expect(report, isNot(contains('super_secret_password')));
      expect(report, isNot(contains('sr_secret_password')));
      expect(report, isNot(contains('/home/alice/ca.pem')));
      expect(report, isNot(contains('registry.internal')));
    },
  );

  test('handles no profile, unknown fields, and no recent errors', () {
    final report = DiagnosticsReport.build(
      appVersion: null,
      osName: '',
      osVersion: null,
      locale: null,
      logPath: null,
      activeProfile: null,
      recentErrors: const [],
    );

    expect(report, contains('App Version: unknown'));
    expect(report, contains('OS: unknown (unknown)'));
    expect(report, contains('Locale: unknown'));
    expect(report, contains('Log File: unavailable'));
    expect(report, contains('Active Profile: none'));
    expect(report, contains('Recent Errors: none'));
  });
}
