import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';

void main() {
  group('redact', () {
    test(
      'masks all credential properties from create_config and schema_registry',
      () {
        const keys = [
          'sasl.password',
          'ssl.key.password',
          'ssl.keystore.password',
          'ssl.truststore.password',
          'basic.auth.user.info',
          'sasl.jaas.config',
          'password',
          'passwd',
          'secret',
          'token',
          'api_key',
          'api-key',
          'api.key',
        ];

        for (final key in keys) {
          final eqInput = 'config $key=hunter2 next=ok';
          expect(
            redact(eqInput),
            isNot(contains('hunter2')),
            reason: 'eq $key',
          );
          expect(redact(eqInput), contains('$key=***'), reason: 'eq $key');

          final colonInput = 'config $key: supersecret';
          expect(
            redact(colonInput),
            isNot(contains('supersecret')),
            reason: 'colon $key',
          );
          expect(
            redact(colonInput),
            contains('$key: ***'),
            reason: 'colon $key',
          );

          final jsonInput = '{"$key": "my_secret_val", "other": "visible"}';
          expect(
            redact(jsonInput),
            isNot(contains('my_secret_val')),
            reason: 'json $key',
          );
          expect(
            redact(jsonInput),
            contains('"$key": "***"'),
            reason: 'json $key',
          );
          expect(redact(jsonInput), contains('"other": "visible"'));
        }
      },
    );

    test('masks quoted sasl.jaas.config values', () {
      const input =
          'sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="alice" password="s3cr3t";';
      final out = redact(input);
      expect(out, isNot(contains('s3cr3t')));
      expect(out, contains('sasl.jaas.config=***'));
    });

    test('masks Authorization headers and Bearer tokens', () {
      expect(
        redact('Header Authorization: Bearer abc.def.ghi failed'),
        'Header Authorization: *** failed',
      );
      expect(
        redact('Header Authorization: Basic dXNlcjpwYXNz failed'),
        'Header Authorization: *** failed',
      );
      expect(
        redact('Using Bearer my_jwt_token_123 for request'),
        'Using Bearer *** for request',
      );
    });

    test('masks PEM private key blocks', () {
      const pem = '''before
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA1234567890abcdef
-----END RSA PRIVATE KEY-----
after''';
      final out = redact(pem);
      expect(out, isNot(contains('MIIEowIBAAKCAQEA1234567890abcdef')));
      expect(out, contains('[private key redacted]'));
      expect(out, contains('before'));
      expect(out, contains('after'));
    });

    test('masks URL user info while preserving host and path', () {
      expect(
        redact(
          'Connecting to https://user:p4ssw0rd@registry.example.com:8081/subjects',
        ),
        'Connecting to https://***@registry.example.com:8081/subjects',
      );
    });

    test('truncates records longer than 4096 characters with marker', () {
      final longText = 'A' * 5000;
      final out = redact(longText);
      expect(out.length, lessThanOrEqualTo(4096));
      expect(out, endsWith(' …[truncated]'));
    });

    test('leaves harmless lines untouched', () {
      const line =
          '2026-11-14T12:00:00Z INFO [dart] Connected to topic orders (partitions=12)';
      expect(redact(line), line);
    });
  });
}
