import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/startup_error_app.dart';

void main() {
  testWidgets(
    'renders startup error, copies redacted details, and handles unavailable log',
    (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        StartupErrorApp(
          error: StateError('Failed to load lib sasl.password=secret123'),
          logPath: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kafkalyzer could not start'), findsOneWidget);
      expect(find.text('Log file: unavailable'), findsOneWidget);
      expect(find.textContaining('sasl.password=***'), findsOneWidget);
      expect(find.textContaining('secret123'), findsNothing);

      await tester.tap(find.text('Copy details'));
      await tester.pumpAndSettle();
      expect(copiedText, contains('sasl.password=***'));
      expect(copiedText, isNot(contains('secret123')));
      expect(find.text('Error details copied to clipboard'), findsOneWidget);

      await tester.tap(find.text('Open log folder'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open log folder at unavailable'),
        findsOneWidget,
      );
    },
  );
}
