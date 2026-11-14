import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/consumer/application/consumer_group_directory.dart';

void main() {
  test(
    'returns null before recording and stores immutable list per cluster',
    () {
      final directory = ConsumerGroupDirectory();
      expect(directory.idsFor('prod'), isNull);

      directory.record('prod', ['group-a', 'group-b']);
      expect(directory.idsFor('prod'), ['group-a', 'group-b']);
      expect(directory.idsFor('staging'), isNull);

      directory.record('prod', ['group-c']);
      expect(directory.idsFor('prod'), ['group-c']);
    },
  );
}
