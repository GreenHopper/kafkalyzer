import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_header.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_search_bar.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/view_mode_switcher.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const run = ScriptRun(
    id: 'run-1',
    scriptName: 'Test Script',
    timestamp: 1695888000000,
    parameters: {},
    status: ScriptRunStatus.completed,
    path: '/tmp/run-1',
  );

  testWidgets('renders run context without search or view mode switchers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScriptRunHeader(
            run: run,
            timelineMode: 'topic',
            onTimelineModeChanged: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Run Details'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('By Topic'), findsOneWidget);
    expect(find.byType(ViewModeSwitcher), findsNothing);
    expect(find.byType(MessageSearchBar), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
  });

  testWidgets('toggles run overview sidebar via header button', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var sidebarVisible = true;
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ScriptRunHeader(
                run: run,
                timelineMode: 'topic',
                onTimelineModeChanged: (_) {},
                onBack: () {},
                isSidebarVisible: sidebarVisible,
                onToggleSidebar: () {
                  setState(() {
                    sidebarVisible = !sidebarVisible;
                    toggleCount++;
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('script_run_toggle_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('script_run_toggle_sidebar')));
    await tester.pumpAndSettle();

    expect(toggleCount, 1);
    expect(sidebarVisible, isFalse);
  });
}
