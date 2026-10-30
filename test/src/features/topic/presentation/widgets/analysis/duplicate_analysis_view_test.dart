import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/duplicate_analysis_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows unavailable state when result is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DuplicateAnalysisView(result: null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Duplicate analysis is not available for this report.'),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when topDuplicates is empty', (tester) async {
    const result = DuplicateAnalysisResult(
      scope: DuplicateDetectionScope.payloadOnly,
      totalMessages: 500,
      uniqueMessages: 500,
      duplicateMessages: 0,
      duplicateRate: 0.0,
      topDuplicates: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DuplicateAnalysisView(result: result)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Duplicated Messages'), findsOneWidget);
    expect(
      find.text('No duplicate messages detected in this scan.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders duplicate table and copy interaction when duplicates present',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const result = DuplicateAnalysisResult(
        scope: DuplicateDetectionScope.payloadOnly,
        totalMessages: 1000,
        uniqueMessages: 700,
        duplicateMessages: 300,
        duplicateRate: 30.0,
        topDuplicates: [
          TopDuplicateOccurrence(
            count: 250,
            percentage: 25.0,
            key: 'user-42',
            payloadPreview: '{"event":"heartbeat","status":"ok"}',
            samplePartition: 2,
            sampleOffset: 12345,
            sampleTimestampMs: 1730000000000,
          ),
          TopDuplicateOccurrence(
            count: 50,
            percentage: 5.0,
            key: null,
            payloadPreview: '{"event":"ping"}',
            samplePartition: 0,
            sampleOffset: 999,
            sampleTimestampMs: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DuplicateAnalysisView(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Top Duplicated Messages'), findsOneWidget);
      expect(find.text('250 (25.0%)'), findsOneWidget);
      expect(find.text('user-42'), findsOneWidget);
      expect(find.text('{"event":"heartbeat","status":"ok"}'), findsOneWidget);
      expect(find.text('Partition 2, Offset 12345'), findsOneWidget);

      // Verify key copy button
      expect(find.byTooltip('Copy key'), findsOneWidget);

      // Verify payload copy button
      final copyPayloadButtons = find.byTooltip('Copy payload');
      expect(copyPayloadButtons, findsNWidgets(2));

      await tester.tap(copyPayloadButtons.first);
      await tester.pump();
      expect(find.text('Payload copied to clipboard'), findsOneWidget);

      // Verify opening duplicate details dialog
      final infoButtons = find.byTooltip('View duplicate details');
      expect(infoButtons, findsNWidgets(2));

      await tester.tap(infoButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Message Details'), findsOneWidget);
      expect(find.textContaining('Rank #1'), findsOneWidget);
    },
  );

  testWidgets(
    'forwards onNavigateToTarget when clicking action in details dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DuplicateNavigationTarget? capturedTarget;

      const result = DuplicateAnalysisResult(
        scope: DuplicateDetectionScope.payloadOnly,
        totalMessages: 50,
        uniqueMessages: 40,
        duplicateMessages: 10,
        duplicateRate: 20.0,
        topDuplicates: [
          TopDuplicateOccurrence(
            count: 10,
            percentage: 20.0,
            key: 'item-99',
            payloadPreview: '{"test": 1}',
            samplePartition: 1,
            sampleOffset: 555,
            sampleTimestampMs: 1730000000000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DuplicateAnalysisView(
              result: result,
              onNavigateToTarget: (target) => capturedTarget = target,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('View duplicate details'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter in Messages'));
      await tester.pumpAndSettle();

      expect(capturedTarget, isNotNull);
      expect(capturedTarget!.key, 'item-99');
      expect(capturedTarget!.filterOccurrences, isTrue);
      expect(capturedTarget!.count, 10);
    },
  );
}
