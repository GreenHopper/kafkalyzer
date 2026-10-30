import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'DuplicateDetailsDialog displays decoded payload, metadata, and handles actions',
    (tester) async {
      int? navigatedPartition;
      int? navigatedOffset;

      const duplicate = TopDuplicateOccurrence(
        count: 42,
        percentage: 12.5,
        key: 'user-key-123',
        payloadPreview: '{"COR_ID":"COR-999","status":"ACTIVE"}',
        samplePartition: 3,
        sampleOffset: 4567,
        sampleTimestampMs: 1730000000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DuplicateDetailsDialog(
              duplicate: duplicate,
              rank: 1,
              scope: DuplicateDetectionScope.payloadOnly,
              onNavigateToMessage: (p, o) {
                navigatedPartition = p;
                navigatedOffset = o;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title and Subtitle
      expect(find.text('Duplicate Message Details'), findsOneWidget);
      expect(find.text('Rank #1 • 42 occurrences (12.5%)'), findsOneWidget);

      // Verify Metadata
      expect(find.text('Partition 3 • Offset 4567'), findsOneWidget);
      expect(find.text('Payload (Value)'), findsOneWidget);

      // Verify Key
      expect(find.text('user-key-123'), findsOneWidget);

      // Verify pretty-printed payload content is rendered
      expect(find.textContaining('"COR_ID": "COR-999"'), findsOneWidget);
      expect(find.textContaining('"status": "ACTIVE"'), findsOneWidget);

      // Test Copy Payload
      final copyButtons = find.byIcon(Icons.copy_rounded);
      expect(copyButtons, findsNWidgets(2)); // 1 for key, 1 for payload
      await tester.tap(copyButtons.last);
      await tester.pump();
      expect(find.text('Payload copied to clipboard'), findsOneWidget);

      // Test Navigate to Message
      final openInMessagesButton = find.text('Open in Messages');
      expect(openInMessagesButton, findsOneWidget);
      await tester.tap(openInMessagesButton);
      await tester.pumpAndSettle();

      expect(navigatedPartition, 3);
      expect(navigatedOffset, 4567);
    },
  );

  testWidgets(
    'DuplicateDetailsDialog triggers onNavigateToTarget for filter and jump actions',
    (tester) async {
      DuplicateNavigationTarget? capturedTarget;

      const duplicate = TopDuplicateOccurrence(
        count: 12,
        percentage: 5.0,
        key: 'cor-id-12345',
        payloadPreview: '{"name": "test"}',
        samplePartition: 1,
        sampleOffset: 9999,
        sampleTimestampMs: 1730000000000,
      );

      Widget buildApp() {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => DuplicateDetailsDialog(
                      duplicate: duplicate,
                      rank: 2,
                      scope: DuplicateDetectionScope.keyAndPayload,
                      onNavigateToTarget: (target) {
                        capturedTarget = target;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Open dialog and test Filter action
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final filterButton = find.text('Filter in Messages');
      final jumpButton = find.text('Jump to Sample');

      expect(filterButton, findsOneWidget);
      expect(jumpButton, findsOneWidget);

      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(capturedTarget, isNotNull);
      expect(capturedTarget!.key, equals('cor-id-12345'));
      expect(capturedTarget!.filterOccurrences, isTrue);
      expect(capturedTarget!.samplePartition, equals(1));
      expect(capturedTarget!.sampleOffset, equals(9999));
      expect(capturedTarget!.count, equals(12));

      // Open dialog again and test Jump action
      capturedTarget = null;
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jump to Sample'));
      await tester.pumpAndSettle();

      expect(capturedTarget, isNotNull);
      expect(capturedTarget!.filterOccurrences, isFalse);
      expect(capturedTarget!.samplePartition, equals(1));
      expect(capturedTarget!.sampleOffset, equals(9999));
    },
  );
}
