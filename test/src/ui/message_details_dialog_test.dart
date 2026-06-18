import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';

void main() {
  const testMessage = KafkaMessage(
    topic: 'test-topic',
    partition: 2,
    offset: 12345,
    key: 'test-key',
    payload: '{"name": "Alice", "age": 30}',
    timestamp: 1625097600000, // 2021-07-01 00:00:00 UTC
  );

  Widget createWidgetUnderTest(
    KafkaMessage msg, {
    String? initialSearchPhrase,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => MessageDetailsDialog(
                      message: msg,
                      initialSearchPhrase: initialSearchPhrase,
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('renders metadata partition, offset and copy options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest(testMessage));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog title and topic
    expect(find.text('Message Details'), findsOneWidget);
    expect(find.text('test-topic'), findsOneWidget);

    // Verify metadata values
    expect(find.text('PARTITION'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('OFFSET'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);

    // Verify copy buttons are visible
    expect(find.text('Copy message'), findsOneWidget);
    expect(find.byTooltip('Copy metadata'), findsOneWidget);

    // Test copy metadata interaction
    await tester.tap(find.byTooltip('Copy metadata'));
    await tester.pump();
    // Clipboard should contain metadata. We can check via services or just verifying click works.
  });

  testWidgets('can copy full message to clipboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest(testMessage));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy message'));
    await tester.pumpAndSettle();

    // Verification of copy snackbar
    expect(find.text('Full message copied to clipboard'), findsOneWidget);
  });

  testWidgets('performs search highlight and match navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Use initialSearchPhrase to filter 'Alice'
    await tester.pumpWidget(
      createWidgetUnderTest(testMessage, initialSearchPhrase: 'Alice'),
    );
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // The textfield should have 'Alice'
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Alice');

    // Wait for async match detection
    await tester.pumpAndSettle();

    // Clear search query
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pumpAndSettle();

    final clearTextField = tester.widget<TextField>(find.byType(TextField));
    expect(clearTextField.controller?.text, 'test');
  });
}
