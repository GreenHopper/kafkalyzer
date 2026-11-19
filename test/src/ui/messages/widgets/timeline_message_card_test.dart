import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

void main() {
  Widget createWidgetUnderTest({
    required KafkaMessage message,
    required VoidCallback onTap,
    String? searchPhrase,
    Widget? customContent,
    List<MapEntry<String, String>>? extractedValues,
    bool showPayloadPreview = true,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: TimelineMessageCard(
          message: message,
          onTap: onTap,
          searchPhrase: searchPhrase,
          customContent: customContent,
          extractedValues: extractedValues,
          showPayloadPreview: showPayloadPreview,
        ),
      ),
    );
  }

  bool findTextInRichText(Widget widget, String text) {
    if (widget is RichText) {
      final plainText = widget.text.toPlainText();
      return plainText.contains(text);
    }
    return false;
  }

  testWidgets('renders key, payload and responds to tap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-message-key',
      payload: 'this is a secret message payload text',
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(message: msg, onTap: () => tapped = true),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'my-message-key')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => findTextInRichText(w, 'this is a secret message payload text'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Card));
    expect(tapped, isTrue);
  });

  testWidgets('renders extracted values if present', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        message: msg,
        onTap: () {},
        extractedValues: [
          const MapEntry('username', 'bob'),
          const MapEntry('action', 'login'),
        ],
      ),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'username: bob')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'action: login')),
      findsOneWidget,
    );
  });

  testWidgets('renders customContent instead of payload preview', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-key',
      payload: 'ignored payload',
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        message: msg,
        onTap: () {},
        customContent: const Text('CUSTOM CONTENT SHOWN'),
      ),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'my-key')),
      findsOneWidget,
    );
    expect(find.text('CUSTOM CONTENT SHOWN'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'ignored payload')),
      findsNothing,
    );
  });

  testWidgets('renders TombstoneWidget when payload is null', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-key',
      payload: null,
      timestamp: 1234567,
    );

    await tester.pumpWidget(createWidgetUnderTest(message: msg, onTap: () {}));

    expect(find.byType(TombstoneWidget), findsOneWidget);
  });

  testWidgets('filters null fields in JSON payload preview', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-key',
      payload: '{"id": 42, "emptyField": null, "name": "Kafka"}',
      timestamp: 1234567,
    );

    await tester.pumpWidget(createWidgetUnderTest(message: msg, onTap: () {}));

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'emptyField')),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'name')),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders spaced syntax-tinted JSON preview with AppFonts.robotoMono, WCAG AA contrast in dark/light and selected states, and search highlight',
    (tester) async {
      const msg = KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 100,
        key: 'order-42',
        payload: '{"city":"Paris","count":3,"active":true}',
        timestamp: 1234567,
      );

      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final isSelected in [false, true]) {
          final theme = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: brightness,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.15),
                  ),
                  child: TimelineMessageCard(
                    message: msg,
                    onTap: () {},
                    searchPhrase: 'Par',
                    isSelected: isSelected,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final previewRichText = tester
              .widgetList<RichText>(find.byType(RichText))
              .firstWhere(
                (r) => r.text.toPlainText().contains('"city": "Paris"'),
              );

          expect(
            previewRichText.text.toPlainText(),
            '{"city": "Paris", "count": 3, "active": true}',
          );
          expect(previewRichText.textScaler, const TextScaler.linear(1.15));

          final rootSpan = previewRichText.text as TextSpan;
          expect(rootSpan.style?.fontFamily, AppFonts.robotoMono().fontFamily);
          expect(rootSpan.style?.height, greaterThanOrEqualTo(1.35));

          final cs = theme.colorScheme;
          final baseSurface = theme.cardTheme.color ?? cs.surfaceContainerLow;
          final cardBg = isSelected
              ? Color.alphaBlend(
                  cs.primaryContainer.withValues(
                    alpha: brightness == Brightness.dark ? 0.45 : 0.65,
                  ),
                  baseSurface,
                )
              : baseSurface;

          bool foundHighlightedSubstring = false;
          for (final child in rootSpan.children!.cast<TextSpan>()) {
            final text = child.text ?? '';
            if (text.trim().isEmpty) continue;
            if (text == 'Par') {
              foundHighlightedSubstring = true;
              expect(child.style?.backgroundColor, isNotNull);
              final ratio = TextPreviewUtils.contrastRatio(
                child.style!.color!,
                child.style!.backgroundColor!,
              );
              expect(ratio, greaterThanOrEqualTo(4.5));
            } else {
              final ratio = TextPreviewUtils.contrastRatio(
                child.style!.color!,
                cardBg,
              );
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason:
                    'Token "$text" in $brightness (selected=$isSelected) had contrast $ratio (fg=${child.style!.color}, bg=$cardBg, themeBg=${theme.colorScheme.surfaceContainerLow})',
              );
            }
          }
          expect(foundHighlightedSubstring, isTrue);
        }
      }
    },
  );
}
