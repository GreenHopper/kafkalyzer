import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/parameter_values_dialog.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: home,
  );
}

void main() {
  Future<void> wideSurface(WidgetTester tester) async {
    final view = tester.view;
    view.physicalSize = const Size(900, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  testWidgets('search narrows values and confirm returns selection', (
    tester,
  ) async {
    await wideSurface(tester);
    Set<String>? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Set<String>>(
                    context: context,
                    builder: (_) => const ParameterValuesDialog(
                      parameterName: 'region',
                      values: ['eu-west', 'us-east', 'ap-south'],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'eu');
    await tester.pumpAndSettle();
    expect(find.text('eu-west'), findsOneWidget);
    expect(find.text('us-east'), findsNothing);

    await tester.tap(find.text('eu-west'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply (1)'));
    await tester.pumpAndSettle();

    expect(result, equals({'eu-west'}));
  });

  testWidgets('empty filter shows no values; cancel returns null', (
    tester,
  ) async {
    await wideSurface(tester);
    Object? result = 'sentinel';
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Set<String>>(
                    context: context,
                    builder: (_) => const ParameterValuesDialog(
                      parameterName: 'region',
                      values: ['eu-west', 'us-east'],
                      initiallySelected: {'eu-west'},
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('eu-west'), findsNothing);
    expect(find.text('us-east'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('select all matches adds filtered values', (tester) async {
    await wideSurface(tester);
    Set<String>? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Set<String>>(
                    context: context,
                    builder: (_) => const ParameterValuesDialog(
                      parameterName: 'region',
                      values: ['eu-west', 'eu-central', 'us-east'],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'eu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All Matches'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply (2)'));
    await tester.pumpAndSettle();

    expect(result, equals({'eu-west', 'eu-central'}));
  });
}
