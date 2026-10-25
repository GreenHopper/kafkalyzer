import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/navigation/widgets/quick_jump_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const clusterA = ClusterProfile(
    name: 'prod-kafka',
    bootstrapServers: 'localhost:9092',
  );
  const clusterB = ClusterProfile(
    name: 'staging-kafka',
    bootstrapServers: 'localhost:9093',
  );

  Widget createWidget({
    List<ClusterProfile>? clusters,
    ClusterProfile? currentCluster,
    Future<void> Function(
      ClusterProfile cluster,
      String topic,
      int? partition,
      int? offset,
      String? filter,
    )? onJump,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuickJumpDialog(
          availableClusters: clusters ?? [clusterA, clusterB],
          currentCluster: currentCluster ?? clusterA,
          onJump: onJump,
        ),
      ),
    );
  }

  group('QuickJumpDialog', () {
    testWidgets('renders input field and jump button starts disabled',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_jump_input_field')), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('quick_jump_submit_button')),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('typing invalid reference URI shows error message',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('quick_jump_input_field')),
        'https://invalid.com/test',
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid reference URI format'), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('quick_jump_submit_button')),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('typing valid reference parses topic, partition, offset, filter and enables jump',
        (tester) async {
      ClusterProfile? jumpedCluster;
      String? jumpedTopic;
      int? jumpedPartition;
      int? jumpedOffset;
      String? jumpedFilter;

      await tester.pumpWidget(
        createWidget(
          onJump: (c, t, p, o, f) async {
            jumpedCluster = c;
            jumpedTopic = t;
            jumpedPartition = p;
            jumpedOffset = o;
            jumpedFilter = f;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('quick_jump_input_field')),
        'kafkalyzer://open?cluster=prod-kafka&topic=orders&partition=2&offset=1042&filter=failed',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Topic: orders'), findsOneWidget);
      expect(find.textContaining('Partition: 2'), findsOneWidget);
      expect(find.textContaining('Offset: 1042'), findsOneWidget);
      expect(find.textContaining('Filter: failed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_jump_submit_button')));
      await tester.pumpAndSettle();

      expect(jumpedCluster?.name, equals('prod-kafka'));
      expect(jumpedTopic, equals('orders'));
      expect(jumpedPartition, equals(2));
      expect(jumpedOffset, equals(1042));
      expect(jumpedFilter, equals('failed'));
    });

    testWidgets('unknown cluster in reference prompts cluster dropdown selection',
        (tester) async {
      ClusterProfile? jumpedCluster;

      await tester.pumpWidget(
        createWidget(
          onJump: (c, t, p, o, f) async {
            jumpedCluster = c;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('quick_jump_input_field')),
        'kafkalyzer://open?cluster=unknown-cluster&topic=payments',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Cluster 'unknown-cluster' not found in configuration"),
        findsOneWidget,
      );
      expect(find.byKey(const Key('quick_jump_cluster_dropdown')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_jump_submit_button')));
      await tester.pumpAndSettle();

      expect(jumpedCluster, isNotNull);
      expect(jumpedCluster?.name, equals('prod-kafka'));
    });
  });
}
