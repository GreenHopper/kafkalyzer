import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterProfile', () {
    test('equality and hashCode', () {
      const profile1 = ClusterProfile(
        name: 'test',
        bootstrapServers: 'localhost:9092',
        saslUsername: 'user',
        saslPassword: 'password',
        mechanism: 'PLAIN',
        securityProtocol: 'SASL_SSL',
        schemaRegistryUrl: 'http://schema',
        sslKeystoreLocation: 'key.jks',
        sslKeystorePassword: 'pass',
        sslTruststoreLocation: 'trust.jks',
        sslTruststorePassword: 'pass',
      );

      const profile2 = ClusterProfile(
        name: 'test',
        bootstrapServers: 'localhost:9092',
        saslUsername: 'user',
        saslPassword: 'password',
        mechanism: 'PLAIN',
        securityProtocol: 'SASL_SSL',
        schemaRegistryUrl: 'http://schema',
        sslKeystoreLocation: 'key.jks',
        sslKeystorePassword: 'pass',
        sslTruststoreLocation: 'trust.jks',
        sslTruststorePassword: 'pass',
      );

      expect(profile1 == profile1, isTrue);
      expect(profile1, equals(profile2));
      expect(profile1.hashCode, equals(profile2.hashCode));
      // Not equal to different type is handled by Dart's strong typing, 
      // testing it directly causes linter warnings.

      // Mutate each field
      expect(
        profile1 ==
            const ClusterProfile(
              name: 'other',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9093',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user2',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password2',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'SCRAM-SHA-256',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'PLAINTEXT',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema2',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key2.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass2',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust2.jks',
              sslTruststorePassword: 'pass',
            ),
        isFalse,
      );

      expect(
        profile1 ==
            const ClusterProfile(
              name: 'test',
              bootstrapServers: 'localhost:9092',
              saslUsername: 'user',
              saslPassword: 'password',
              mechanism: 'PLAIN',
              securityProtocol: 'SASL_SSL',
              schemaRegistryUrl: 'http://schema',
              sslKeystoreLocation: 'key.jks',
              sslKeystorePassword: 'pass',
              sslTruststoreLocation: 'trust.jks',
              sslTruststorePassword: 'pass2',
            ),
        isFalse,
      );
    });
  });

  group('TopicPartitionLag', () {
    test('equality and hashCode', () {
      const lag1 = TopicPartitionLag(
        topic: 'topic1',
        partition: 0,
        logEndOffset: 100,
        currentOffset: 80,
        lag: 20,
      );

      const lag2 = TopicPartitionLag(
        topic: 'topic1',
        partition: 0,
        logEndOffset: 100,
        currentOffset: 80,
        lag: 20,
      );

      expect(lag1 == lag1, isTrue);
      expect(lag1, equals(lag2));
      expect(lag1.hashCode, equals(lag2.hashCode));
      // Not equal to different type is handled by Dart's strong typing, 
      // testing it directly causes linter warnings.

      expect(
        lag1 ==
            const TopicPartitionLag(
              topic: 'topic2',
              partition: 0,
              logEndOffset: 100,
              currentOffset: 80,
              lag: 20,
            ),
        isFalse,
      );

      expect(
        lag1 ==
            const TopicPartitionLag(
              topic: 'topic1',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 80,
              lag: 20,
            ),
        isFalse,
      );

      expect(
        lag1 ==
            const TopicPartitionLag(
              topic: 'topic1',
              partition: 0,
              logEndOffset: 101,
              currentOffset: 80,
              lag: 20,
            ),
        isFalse,
      );

      expect(
        lag1 ==
            const TopicPartitionLag(
              topic: 'topic1',
              partition: 0,
              logEndOffset: 100,
              currentOffset: 81,
              lag: 20,
            ),
        isFalse,
      );

      expect(
        lag1 ==
            const TopicPartitionLag(
              topic: 'topic1',
              partition: 0,
              logEndOffset: 100,
              currentOffset: 80,
              lag: 21,
            ),
        isFalse,
      );
    });
  });

  group('ConsumerGroupLag', () {
    test('equality and hashCode', () {
      const partLag = TopicPartitionLag(
        topic: 'topic1',
        partition: 0,
        logEndOffset: 10,
        currentOffset: 5,
        lag: 5,
      );

      const groupLag1 = ConsumerGroupLag(
        groupId: 'g1',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [partLag],
        membersCount: 2,
        topicsCount: 1,
      );

      const groupLag2 = ConsumerGroupLag(
        groupId: 'g1',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [partLag],
        membersCount: 2,
        topicsCount: 1,
      );

      expect(groupLag1 == groupLag1, isTrue);
      expect(groupLag1, equals(groupLag2));
      expect(groupLag1.hashCode, equals(groupLag2.hashCode));
      // Not equal to different type is handled by Dart's strong typing, 
      // testing it directly causes linter warnings.

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g2',
              state: 'Stable',
              protocolType: 'consumer',
              partitionLags: [partLag],
              membersCount: 2,
              topicsCount: 1,
            ),
        isFalse,
      );

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g1',
              state: 'PreparingRebalance',
              protocolType: 'consumer',
              partitionLags: [partLag],
              membersCount: 2,
              topicsCount: 1,
            ),
        isFalse,
      );

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g1',
              state: 'Stable',
              protocolType: 'connect',
              partitionLags: [partLag],
              membersCount: 2,
              topicsCount: 1,
            ),
        isFalse,
      );

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g1',
              state: 'Stable',
              protocolType: 'consumer',
              partitionLags: [],
              membersCount: 2,
              topicsCount: 1,
            ),
        isFalse,
      );

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g1',
              state: 'Stable',
              protocolType: 'consumer',
              partitionLags: [partLag],
              membersCount: 3,
              topicsCount: 1,
            ),
        isFalse,
      );

      expect(
        groupLag1 ==
            const ConsumerGroupLag(
              groupId: 'g1',
              state: 'Stable',
              protocolType: 'consumer',
              partitionLags: [partLag],
              membersCount: 2,
              topicsCount: 2,
            ),
        isFalse,
      );
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
