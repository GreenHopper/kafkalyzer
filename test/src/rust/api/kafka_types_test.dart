import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterProfile', () {
    test('equality and hashCode', () {
      final profile1 = const ClusterProfile(
        name: 'test',
        bootstrapServers: 'localhost:9092',
        saslUsername: 'user',
        saslPassword: 'password',
      );

      final profile2 = const ClusterProfile(
        name: 'test',
        bootstrapServers: 'localhost:9092',
        saslUsername: 'user',
        saslPassword: 'password',
      );

      final profile3 = const ClusterProfile(
        name: 'other',
        bootstrapServers: 'localhost:9093',
      );

      expect(profile1, equals(profile2));
      expect(profile1.hashCode, equals(profile2.hashCode));
      expect(profile1, isNot(equals(profile3)));
    });

    test('supports all optional fields', () {
      final profile = const ClusterProfile(
        name: 'full',
        bootstrapServers: 'localhost',
        saslUsername: 'user',
        saslPassword: 'pass',
        mechanism: 'PLAIN',
        securityProtocol: 'SASL_SSL',
        schemaRegistryUrl: 'http://schema',
        sslKeystoreLocation: 'key.jks',
        sslKeystorePassword: 'pass',
        sslTruststoreLocation: 'trust.jks',
        sslTruststorePassword: 'pass',
      );

      expect(profile.name, 'full');
      expect(profile.mechanism, 'PLAIN');
      expect(profile.securityProtocol, 'SASL_SSL');
    });
  });

  group('FilterType', () {
    test('values check', () {
      expect(FilterType.values.length, 3);
      expect(FilterType.contains, isNotNull);
      expect(FilterType.regex, isNotNull);
      expect(FilterType.exact, isNotNull);
    });
  });

  group('SearchScope', () {
    test('values check', () {
      expect(FilterType.values.length, 3);
      expect(SearchScope.key, isNotNull);
      expect(SearchScope.value, isNotNull);
      expect(SearchScope.both, isNotNull);
    });
  });
}
