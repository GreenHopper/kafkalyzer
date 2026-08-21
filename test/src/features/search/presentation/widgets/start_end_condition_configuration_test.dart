import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('StartConditionConfiguration', () {
    testWidgets('renders all start strategies and updates description', (
      tester,
    ) async {
      var strategy = MultiSearchStartStrategy.latest;
      final offsetController = TextEditingController();
      final timestampController = TextEditingController();

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return StartConditionConfiguration(
                startStrategy: strategy,
                onStartStrategyChanged: (newVal) {
                  setState(() {
                    strategy = newVal;
                  });
                },
                startOffsetController: offsetController,
                startTimestampController: timestampController,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect latest strategy helper description
      expect(
        find.text(
          'Start at the most recent messages (tail of topic according to limit)',
        ),
        findsOneWidget,
      );

      // Tap Earliest
      await tester.tap(find.text('Earliest'));
      await tester.pumpAndSettle();

      expect(strategy, MultiSearchStartStrategy.earliest);
      expect(
        find.text('Start reading from the oldest available message (offset 0)'),
        findsOneWidget,
      );
    });
  });

  group('EndConditionConfiguration', () {
    testWidgets('renders all end strategies and updates description', (
      tester,
    ) async {
      var strategy = MultiSearchEndStrategy.live;
      final offsetController = TextEditingController();
      final timestampController = TextEditingController();

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return EndConditionConfiguration(
                endStrategy: strategy,
                onEndStrategyChanged: (newVal) {
                  setState(() {
                    strategy = newVal;
                  });
                },
                endOffsetController: offsetController,
                endTimestampController: timestampController,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect live stream helper description
      expect(
        find.text('Continue listening indefinitely for newly arriving messages'),
        findsOneWidget,
      );

      // Tap End
      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();

      expect(strategy, MultiSearchEndStrategy.latest);
      expect(
        find.text(
          'Stop when reaching the current end of the topic (high watermark)',
        ),
        findsOneWidget,
      );
    });
  });
}
