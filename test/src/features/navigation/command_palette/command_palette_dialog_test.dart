import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/command_palette_dialog.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/palette_sources.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final en = AppLocalizationsEn();
  const prod = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'b:9092',
    tlsVerification: TlsVerification.enabled,
  );

  PaletteSnapshot makeSnapshot({
    void Function(String)? onTopic,
    void Function(MainDestination)? onDest,
  }) {
    return PaletteSnapshot(
      l10n: en,
      clusters: const [prod],
      activeProfile: prod,
      topics: const [
        TopicMetadata(
          name: 'orders.a',
          partitionCount: 3,
          replicationFactor: 1,
        ),
        TopicMetadata(
          name: 'orders.b',
          partitionCount: 3,
          replicationFactor: 1,
        ),
        TopicMetadata(
          name: 'orders.c',
          partitionCount: 3,
          replicationFactor: 1,
        ),
      ],
      openTopicNames: const {},
      consumerGroupIds: null,
      scripts: const [],
      onSelectDestination: onDest ?? (_) {},
      onOpenCluster: (_) async {},
      onOpenTopic: (t) => onTopic?.call(t.name),
      onOpenConsumerGroup: (_) {},
      onOpenScript: (_) {},
    );
  }

  Widget buildHost(PaletteSnapshot snapshot, {FocusNode? priorFocus}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextField(focusNode: priorFocus),
              ElevatedButton(
                onPressed: () => CommandPaletteDialog.show(
                  context,
                  snapshotOverride: snapshot,
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('filters, navigates with arrows, and Enter runs third entry', (
    tester,
  ) async {
    String? openedTopic;
    await tester.pumpWidget(
      buildHost(makeSnapshot(onTopic: (t) => openedTopic = t)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Consumer groups appear after Consumer Lag has loaded them.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, 'orders');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(openedTopic, 'orders.c');
    expect(find.byType(CommandPaletteDialog), findsNothing);
  });

  testWidgets('Escape closes with no action and restores prior focus', (
    tester,
  ) async {
    final priorFocus = FocusNode();
    addTearDown(priorFocus.dispose);
    String? openedTopic;

    await tester.pumpWidget(
      buildHost(
        makeSnapshot(onTopic: (t) => openedTopic = t),
        priorFocus: priorFocus,
      ),
    );
    await tester.pumpAndSettle();

    priorFocus.requestFocus();
    await tester.pump();
    expect(priorFocus.hasFocus, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(openedTopic, isNull);
    expect(priorFocus.hasFocus, isTrue);
  });

  testWidgets('no results shows message and Enter does nothing', (
    tester,
  ) async {
    String? openedTopic;
    await tester.pumpWidget(
      buildHost(makeSnapshot(onTopic: (t) => openedTopic = t)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'zzzzzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching results'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
    expect(openedTopic, isNull);
  });
}
