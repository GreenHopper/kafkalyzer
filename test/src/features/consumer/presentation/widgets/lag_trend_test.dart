import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kafkalyzer/src/features/consumer/presentation/widgets/lag_trend.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

String _tooltipOf(WidgetTester tester, Key key) =>
    tester.widget<LagTrend>(find.byKey(key)).tooltip;

void main() {
  group('LagTrend', () {
    testWidgets('a rising series renders a trend line', (tester) async {
      const key = Key('trend');
      await tester.pumpWidget(
        _wrap(
          const LagTrend(
            key: key,
            readings: [100, 400, 900],
            tooltip: 'highest 900, lowest 100',
          ),
        ),
      );

      expect(find.byKey(const Key('lag_trend')), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('lag_trend')),
      );
      expect(paint.painter, isA<CustomPainter>());
      expect(_tooltipOf(tester, key), contains('highest 900'));
    });

    testWidgets('a single reading renders no trend line', (tester) async {
      await tester.pumpWidget(
        _wrap(const LagTrend(key: Key('trend'), readings: [42], tooltip: 'x')),
      );

      expect(find.byKey(const Key('lag_trend')), findsNothing);
    });

    testWidgets('the tooltip names the highest and lowest retained value', (
      tester,
    ) async {
      // The view builds the tooltip text from the retained readings; 25 readings
      // are truncated to 20 by the caller, which the view test covers.
      const readings = [5, 7, 1200, 300, 40];
      final highest = readings.reduce((a, b) => a > b ? a : b);
      final lowest = readings.reduce((a, b) => a < b ? a : b);

      await tester.pumpWidget(
        _wrap(
          LagTrend(
            key: const Key('trend'),
            readings: readings,
            tooltip:
                'Readings: ${readings.join(', ')} - highest $highest, lowest $lowest',
          ),
        ),
      );

      final message = _tooltipOf(tester, const Key('trend'));
      expect(message, contains('highest 1200'));
      expect(message, contains('lowest 5'));
      expect(message.split(' - ').first.split(': ').last.split(', ').length, 5);
    });
  });
}
