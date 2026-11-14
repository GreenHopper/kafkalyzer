import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';

void main() {
  group('classifyConnectionError', () {
    test('classifies BrokerTransportFailure as brokerTransport', () {
      final err = classifyConnectionError(
        Exception('BrokerTransportFailure: localhost:9092'),
      );
      expect(err.kind, ConnectionErrorKind.brokerTransport);
      expect(err.detail, isNotEmpty);
    });

    test('classifies Connection refused as connectionRefused', () {
      final err = classifyConnectionError(
        Exception('Connection refused (os error 111)'),
      );
      expect(err.kind, ConnectionErrorKind.connectionRefused);
      expect(err.detail, contains('Connection refused'));
    });

    test('extracts AnyhowException message as other with detail', () {
      final err = classifyConnectionError(
        Exception('AnyhowException(SASL handshake failed)\nstack trace'),
      );
      expect(err.kind, ConnectionErrorKind.other);
      expect(err.detail, 'SASL handshake failed');
    });

    test('classifies unknown error as other with non-empty first line', () {
      final err = classifyConnectionError(
        StateError('Something unexpected\nline 2'),
      );
      expect(err.kind, ConnectionErrorKind.other);
      expect(err.detail, 'Bad state: Something unexpected');
    });

    test('never returns empty detail for empty exception string', () {
      final err = classifyConnectionError('');
      expect(err.kind, ConnectionErrorKind.other);
      expect(err.detail, isNotEmpty);
    });
  });
}
