import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/actionable_topic_empty_state.dart';

void main() {
  Widget buildWidget({VoidCallback? onFetch, bool isStreaming = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ActionableTopicEmptyState(
          onFetch: onFetch,
          isStreaming: isStreaming,
        ),
      ),
    );
  }

  testWidgets('renders empty state card with CTA and tip when not streaming', (
    tester,
  ) async {
    bool fetchCalled = false;
    await tester.pumpWidget(
      buildWidget(
        onFetch: () {
          fetchCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
    expect(find.text('No messages loaded yet'), findsOneWidget);
    expect(find.text('Fetch Latest 200 Messages'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);

    await tester.tap(find.text('Fetch Latest 200 Messages'));
    await tester.pump();
    expect(fetchCalled, isTrue);
  });

  testWidgets('renders loading state when isStreaming is true', (tester) async {
    await tester.pumpWidget(buildWidget(isStreaming: true));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading messages from Kafka...'), findsOneWidget);
    expect(find.text('Fetch Latest 200 Messages'), findsNothing);
  });
}
