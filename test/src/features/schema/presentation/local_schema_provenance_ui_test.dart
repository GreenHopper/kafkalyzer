import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations_de.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/features/schema/presentation/local_schema_error_formatter.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('describeLocalDecodeError', () {
    test('maps every LocalDecodeErrorKindDto in EN and DE', () {
      final en = AppLocalizationsEn();
      final de = AppLocalizationsDe();
      for (final kind in LocalDecodeErrorKindDto.values) {
        final msgEn = describeLocalDecodeError(en, kind, 'DETAIL_TOKEN');
        final msgDe = describeLocalDecodeError(de, kind, 'DETAIL_TOKEN');
        expect(msgEn, contains('DETAIL_TOKEN'));
        expect(msgDe, contains('DETAIL_TOKEN'));
        expect(msgEn, isNot(equals('DETAIL_TOKEN')));
        expect(msgDe, isNot(equals('DETAIL_TOKEN')));
      }
    });
  });

  group('MessageMetadataCard local schema badges', () {
    testWidgets('shows K: local and V: local badges on decoded messages', (
      tester,
    ) async {
      final msg = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: PlatformInt64Util.from(1),
        timestamp: PlatformInt64Util.from(1700000000000),
        key: 'k1',
        payload: '{"id":1}',
        keyLocalSchema: const LocalSchemaUseDto(
          fileName: 'key.avsc',
          format: LocalSchemaFormatDto.avro,
          framing: FramingDto.auto,
        ),
        valueLocalSchema: const LocalSchemaUseDto(
          fileName: 'val.proto',
          format: LocalSchemaFormatDto.protobufSource,
          messageType: 'Order',
          framing: FramingDto.auto,
        ),
      );

      await tester.pumpWidget(_wrap(MessageMetadataCard(message: msg)));
      await tester.pumpAndSettle();

      expect(find.text('K: local'), findsOneWidget);
      expect(find.text('V: local'), findsOneWidget);
    });

    testWidgets('shows V: local ! when local decode error is present', (
      tester,
    ) async {
      final msg = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: PlatformInt64Util.from(2),
        timestamp: PlatformInt64Util.from(1700000000000),
        payload: 'raw',
        valueLocalSchema: const LocalSchemaUseDto(
          fileName: 'val.avsc',
          format: LocalSchemaFormatDto.avro,
          framing: FramingDto.prefixed,
          error: LocalSchemaErrorDto(
            kind: LocalDecodeErrorKindDto.missingPrefix,
            detail: 'no 0x00',
          ),
        ),
      );

      await tester.pumpWidget(_wrap(MessageMetadataCard(message: msg)));
      await tester.pumpAndSettle();

      expect(find.text('V: local !'), findsOneWidget);
    });
  });
}
