import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_selection_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:material_ui/material_ui.dart';

const _orders = TopicMetadata(
  name: 'orders',
  partitionCount: 3,
  replicationFactor: 1,
);
const _payments = TopicMetadata(
  name: 'payments',
  partitionCount: 1,
  replicationFactor: 1,
);
const _internal = TopicMetadata(
  name: '_schemas',
  partitionCount: 1,
  replicationFactor: 1,
);
const _stream = TopicMetadata(
  name: 'orders-changelog',
  partitionCount: 1,
  replicationFactor: 1,
);

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: home,
  );
}

Future<dynamic> _openDialog(
  WidgetTester tester, {
  required List<TopicMetadata> topics,
  bool multiSelect = true,
  List<String> initialSelection = const [],
}) async {
  dynamic result;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<dynamic>(
                  context: context,
                  builder: (_) => TopicSelectionDialog(
                    topics: topics,
                    multiSelect: multiSelect,
                    initialSelection: initialSelection,
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
  return result;
}

void main() {
  testWidgets('filters by search query', (tester) async {
    await _openDialog(tester, topics: [_orders, _payments]);

    await tester.enterText(find.byType(TextField), 'pay');
    await tester.pumpAndSettle();

    expect(find.text('payments'), findsOneWidget);
    expect(find.text('orders'), findsNothing);
  });

  testWidgets('hides internal topics until toggle enabled', (tester) async {
    await _openDialog(tester, topics: [_orders, _internal, _stream]);

    expect(find.text('orders'), findsOneWidget);
    expect(find.text('_schemas'), findsNothing);
    expect(find.text('orders-changelog'), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('_schemas'), findsOneWidget);
  });

  testWidgets('multi-select confirm returns selected topics', (tester) async {
    dynamic result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<TopicMetadata>>(
                    context: context,
                    builder: (_) => const TopicSelectionDialog(
                      topics: [_orders, _payments],
                      multiSelect: true,
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

    await tester.tap(find.text('orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Select (1)'));
    await tester.pumpAndSettle();

    expect(result, isA<List<TopicMetadata>>());
    expect(
      (result as List<TopicMetadata>).map((t) => t.name),
      equals(['orders']),
    );
  });

  testWidgets('cancel leaves caller without a new selection', (tester) async {
    Object? result = 'sentinel';
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<TopicMetadata>>(
                    context: context,
                    builder: (_) => const TopicSelectionDialog(
                      topics: [_orders],
                      multiSelect: true,
                      initialSelection: ['orders'],
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

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
