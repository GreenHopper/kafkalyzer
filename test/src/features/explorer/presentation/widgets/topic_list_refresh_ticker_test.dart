import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/topic_list_refresh_ticker.dart';

class _TickerProbe extends StatefulWidget {
  const _TickerProbe();

  @override
  State<_TickerProbe> createState() => _TickerProbeState();
}

class _TickerProbeState extends State<_TickerProbe> {
  int ticks = 0;
  late final TopicListRefreshTicker _ticker = TopicListRefreshTicker();

  @override
  void initState() {
    super.initState();
    _ticker.start(() => setState(() => ticks++));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text('ticks: $ticks'),
  );
}

void main() {
  testWidgets('repaints once the interval has elapsed', (tester) async {
    await tester.pumpWidget(const _TickerProbe());

    expect(find.text('ticks: 0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 29));
    expect(find.text('ticks: 0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ticks: 1'), findsOneWidget);
  });

  testWidgets('cancelling disposes the ticker without a pending timer', (
    tester,
  ) async {
    await tester.pumpWidget(const _TickerProbe());
    await tester.pumpWidget(const SizedBox.shrink());

    // A timer left running after dispose makes flutter_test fail here.
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('ticks: 0'), findsNothing);
  });
}
