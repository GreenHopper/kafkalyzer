import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KafkaMetadataService', () {
    test('can be instantiated', () {
      final service = KafkaMetadataService();
      expect(service, isNotNull);
    });

    test('functions exist (methods cannot be called without backend)', () {
      final service = KafkaMetadataService();
      // We just verify that the class structure is as expected implicitly by calling
      // these expectations. We can't actually call the methods as they call FFI.
      expect(service.validateConnection, isNotNull);
      expect(service.fetchTopics, isNotNull);
    });
  });
}
