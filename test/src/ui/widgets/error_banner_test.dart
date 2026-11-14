import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'Copy puts title and detail on mocked clipboard and shows confirmation',
    (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
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
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorBanner(
              title: 'Connection failed',
              detail: 'Broker unreachable on port 9092',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(copiedText, 'Connection failed\nBroker unreachable on port 9092');
      expect(find.text('Copied to clipboard'), findsOneWidget);
    },
  );

  testWidgets('Failing clipboard channel shows failure notice', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_error', message: 'Denied');
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
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ErrorBanner(title: 'Connection failed', detail: 'Detail'),
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(find.text('Failed to copy to clipboard'), findsOneWidget);
  });

  testWidgets('Dismiss callback fires when close button is tapped', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ErrorBanner(
            title: 'Connection failed',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
