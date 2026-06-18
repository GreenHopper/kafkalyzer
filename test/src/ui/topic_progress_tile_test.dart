import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopicProgressTile', () {
    testWidgets('renders pending status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicProgressTile(
              topic: 'topic-test',
              status: StepStatus.pending,
            ),
          ),
        ),
      );

      expect(find.text('topic-test'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders running status with progress and estimated time', (
      tester,
    ) async {
      // scanned = 1000, total = 5000 -> remaining = 4000.
      // We want estimatedRemaining to be 2m 15s (135 seconds = 135000 ms).
      // elapsed = remainingMs * scanned / remaining = 135000 * 1000 / 4000 = 33750 ms.
      final progress = SearchProgress(
        1000,
        5000,
        startTime: DateTime.now().subtract(const Duration(milliseconds: 33750)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicProgressTile(
              topic: 'topic-test',
              status: StepStatus.running,
              progress: progress,
            ),
          ),
        ),
      );

      expect(find.text('topic-test'), findsOneWidget);
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Estimated remaining matches 4000 (5000 - 1000) remaining (~2m 15s)
      // 5000 - 1000 = 4000 -> formatted as 4.000.
      expect(find.text('4.000 remaining (~2m 15s)'), findsOneWidget);
    });

    testWidgets('renders completed status with match counts', (tester) async {
      final progress = SearchProgress(1234567, 1234567);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicProgressTile(
              topic: 'topic-test',
              status: StepStatus.completed,
              progress: progress,
              matchCount: 15,
            ),
          ),
        ),
      );

      expect(find.text('topic-test'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('15 matches found (1.234.567 scanned)'), findsOneWidget);
    });

    testWidgets('renders error status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicProgressTile(
              topic: 'topic-test',
              status: StepStatus.error,
            ),
          ),
        ),
      );

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('renders extraSubtitle and custom trailing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicProgressTile(
              topic: 'topic-test',
              status: StepStatus.pending,
              extraSubtitle: Text('Extra Subtitle Text'),
              trailing: Text('Custom Trailing'),
            ),
          ),
        ),
      );

      expect(find.text('Extra Subtitle Text'), findsOneWidget);
      expect(find.text('Custom Trailing'), findsOneWidget);
    });

    testWidgets('formats estimated durations correctly across scales', (
      tester,
    ) async {
      final durations = [
        const Duration(days: 2, hours: 3),
        const Duration(hours: 4, minutes: 5),
        const Duration(minutes: 6, seconds: 7),
        const Duration(seconds: 8),
      ];

      final expectedTexts = ['2d 3h', '4h 5m', '6m 7s', '8s'];

      for (int i = 0; i < durations.length; i++) {
        // scanned = 10000, total = 10100 -> remaining = 100.
        // elapsed = duration * (scanned / remaining) = duration * 100.
        final progress = SearchProgress(
          10000,
          10100,
          startTime: DateTime.now().subtract(durations[i] * 100),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopicProgressTile(
                topic: 'topic-$i',
                status: StepStatus.running,
                progress: progress,
              ),
            ),
          ),
        );

        expect(
          find.text('100 remaining (~${expectedTexts[i]})'),
          findsOneWidget,
        );
      }
    });
  });
}
