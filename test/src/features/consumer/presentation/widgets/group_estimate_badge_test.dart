import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/consumer/domain/consumer_lag_estimate.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/widgets/group_estimate_badge.dart';

void main() {
  Widget buildBadge({
    int? delta,
    String formattedDelta = '',
    ConsumerLagEstimate? estimate,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return GroupEstimateBadge(
              delta: delta,
              formattedDelta: formattedDelta,
              estimate: estimate,
              l10n: AppLocalizations.of(context)!,
            );
          },
        ),
      ),
    );
  }

  group('GroupEstimateBadge', () {
    testWidgets('renders "-" when delta and estimate are null', (tester) async {
      await tester.pumpWidget(buildBadge());
      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('renders caughtUp state with green styling', (tester) async {
      const estimate = ConsumerLagEstimate(
        status: LagProcessingStatus.caughtUp,
      );

      await tester.pumpWidget(buildBadge(estimate: estimate));
      expect(find.text('Caught up'), findsOneWidget);
    });

    testWidgets('renders draining state with ETA prefix and tooltip', (
      tester,
    ) async {
      const estimate = ConsumerLagEstimate(
        status: LagProcessingStatus.draining,
        ratePerSecond: 25.0,
        estimatedTimeToClear: Duration(minutes: 3, seconds: 15),
        observedLagDelta: -100,
        elapsedDuration: Duration(seconds: 4),
      );

      await tester.pumpWidget(
        buildBadge(delta: -100, formattedDelta: '-100', estimate: estimate),
      );

      expect(find.text('ETA: ~3m 15s'), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Rate: 25.0 msg/s'));
      expect(tooltip.message, contains('Delta: -100'));
      expect(tooltip.message, contains('4.0s'));
    });

    testWidgets('renders accumulating state when backlog is growing', (
      tester,
    ) async {
      const estimate = ConsumerLagEstimate(
        status: LagProcessingStatus.accumulating,
        ratePerSecond: -10.0,
        observedLagDelta: 50,
        elapsedDuration: Duration(seconds: 5),
      );

      await tester.pumpWidget(
        buildBadge(delta: 50, formattedDelta: '+50', estimate: estimate),
      );

      expect(find.text('Backlog growing'), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Backlog growing'));
    });

    testWidgets('renders stalled state when lag is unchanging', (tester) async {
      const estimate = ConsumerLagEstimate(
        status: LagProcessingStatus.stalled,
        ratePerSecond: 0.0,
        observedLagDelta: 0,
        elapsedDuration: Duration(seconds: 5),
      );

      await tester.pumpWidget(
        buildBadge(delta: 0, formattedDelta: '0', estimate: estimate),
      );

      expect(find.text('Stalled'), findsOneWidget);
    });

    testWidgets('renders localized German texts when locale is de', (
      tester,
    ) async {
      const estimate = ConsumerLagEstimate(
        status: LagProcessingStatus.draining,
        ratePerSecond: 10.0,
        estimatedTimeToClear: Duration(seconds: 45),
        observedLagDelta: -50,
        elapsedDuration: Duration(seconds: 5),
      );

      await tester.pumpWidget(
        buildBadge(
          delta: -50,
          formattedDelta: '-50',
          estimate: estimate,
          locale: const Locale('de'),
        ),
      );

      expect(find.text('Dauer: < 1m'), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Rate: 10.0 Nachr./s'));
      expect(tooltip.message, contains('Dauer: < 1m'));
    });
  });
}
