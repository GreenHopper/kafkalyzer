import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/topic_selection_tree.dart';

void main() {
  Widget createWidgetUnderTest({
    required List<TopicSelectionStepNode> steps,
    required Map<String, Set<String>> selectedTopics,
    required Function(String, String) onTopicToggle,
    required Function(String, bool) onStepToggle,
    required VoidCallback onClearSelection,
    Widget? otherResultsNode,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: TopicSelectionTree(
            steps: steps,
            selectedTopics: selectedTopics,
            onTopicToggle: onTopicToggle,
            onStepToggle: onStepToggle,
            onClearSelection: onClearSelection,
            otherResultsNode: otherResultsNode,
          ),
        ),
      ),
    );
  }

  final testSteps = [
    const TopicSelectionStepNode(
      id: 'step-1',
      name: 'Step One',
      totalMatches: 25,
      topics: [
        TopicSelectionTopicNode(topic: 'topic-a', count: 10, examined: 100),
        TopicSelectionTopicNode(topic: 'topic-b', count: 15, examined: 200),
      ],
    ),
  ];

  testWidgets(
    'renders all messages tile, steps, topics and triggers callbacks',
    (WidgetTester tester) async {
      String toggledStepId = "";
      bool stepSelectAll = false;
      String toggledTopicStepId = "";
      String toggledTopicName = "";
      bool cleared = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          steps: testSteps,
          selectedTopics: {
            'step-1': {'topic-a'},
          },
          onTopicToggle: (stepId, topic) {
            toggledTopicStepId = stepId;
            toggledTopicName = topic;
          },
          onStepToggle: (stepId, selectAll) {
            toggledStepId = stepId;
            stepSelectAll = selectAll;
          },
          onClearSelection: () => cleared = true,
        ),
      );

      // Verify Show All Tile
      expect(find.text('All Messages'), findsOneWidget);
      await tester.tap(find.text('All Messages'));
      expect(cleared, isTrue);

      // Verify Step Node
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('25 matches'), findsOneWidget);

      // Verify Topic Nodes
      expect(find.text('topic-a'), findsOneWidget);
      expect(find.text('100 scanned'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      expect(find.text('topic-b'), findsOneWidget);
      expect(find.text('200 scanned'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // Toggle topic
      await tester.tap(find.text('topic-b'));
      expect(toggledTopicStepId, 'step-1');
      expect(toggledTopicName, 'topic-b');

      // Toggle step
      await tester.tap(find.byIcon(Icons.remove_circle_outlined));
      expect(toggledStepId, 'step-1');
      expect(
        stepSelectAll,
        isTrue,
      ); // It was partially selected, so it toggles to true
    },
  );

  testWidgets('renders otherResultsNode and global topics', (
    WidgetTester tester,
  ) async {
    final stepsWithGlobal = [
      const TopicSelectionStepNode(
        id: 'step-2',
        name: 'Step Two',
        totalMatches: 5,
        topics: [
          TopicSelectionTopicNode(
            topic: 'global-topic',
            count: 5,
            isGlobal: true,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(
        steps: stepsWithGlobal,
        selectedTopics: {},
        onTopicToggle: (_, _) {},
        onStepToggle: (_, _) {},
        onClearSelection: () {},
        otherResultsNode: const Text('OTHER RESULTS CONTAINER'),
      ),
    );

    expect(find.text('global-topic (Global)'), findsOneWidget);
    expect(find.text('OTHER RESULTS CONTAINER'), findsOneWidget);
  });
}
