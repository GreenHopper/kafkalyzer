import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/ui/smart_tree/copyable_node_text.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_composite_badge.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_virtual_json_tree.dart';

void main() {
  group('SmartVirtualJsonTree', () {
    testWidgets('renders primitive fields and syntax colors', (tester) async {
      final json = {
        'username': 'bob',
        'score': 100,
        'verified': true,
        'extra': null,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('username: '), findsOneWidget);
      expect(find.text('"bob"'), findsOneWidget);
      expect(find.text('score: '), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('verified: '), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
      expect(find.text('extra: '), findsOneWidget);
      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('clicking chevron expands and collapses nested object', (
      tester,
    ) async {
      final json = {
        'settings': {
          'theme': {'mode': 'dark'},
          'notifications': false,
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: json,
                autoExpandSingleItemCollections: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 'root.settings' is collapsed
      expect(find.text('settings: '), findsOneWidget);
      expect(find.text('{ 2 keys }'), findsOneWidget);
      expect(find.text('theme: '), findsNothing);

      // Tap chevron to expand
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Now expanded
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('theme: '), findsOneWidget);
      expect(find.text('{ 1 key }'), findsOneWidget);
      expect(find.text('notifications: '), findsOneWidget);
      expect(find.text('false'), findsOneWidget);

      // Tap chevron to collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('notifications: '), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders inline SmartCompositeBadge for semantic objects', (
      tester,
    ) async {
      final json = {
        'order': 42,
        'customer': {'id': 1042, 'name': 'Acme Corp'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SmartCompositeBadge), findsOneWidget);
      expect(find.text('1042 • Acme Corp'), findsOneWidget);
    });

    testWidgets('reports match count and highlights search matches', (
      tester,
    ) async {
      int matchCount = 0;
      final json = {
        'server': {'host': 'production-broker', 'port': 9092},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: json,
                searchQuery: 'production',
                onMatchCountChanged: (count) {
                  matchCount = count;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(matchCount, 1);
      // Ancestor 'server' was auto-expanded
      expect(find.text('host: '), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets(
      'renders collapsedRange placeholder and tapping it expands hidden items',
      (tester) async {
        final items = List.generate(20, (i) => {'id': i, 'title': 'Task $i'});
        final json = {'leistungen': items};

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 800,
                child: SmartVirtualJsonTree(
                  json: json,
                  searchQuery: 'Task 10',
                  enableContextWindowing: true,
                  contextRadius: 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find collapsed range placeholder
        expect(find.textContaining('9 hidden items'), findsOneWidget);
        expect(find.textContaining('8 hidden items'), findsOneWidget);

        // Tap on the first collapsed placeholder to expand it
        await tester.tap(find.textContaining('9 hidden items'));
        await tester.pumpAndSettle();

        // Now the 9 items from range 0..8 should be expanded
        expect(find.textContaining('9 hidden items'), findsNothing);
        expect(find.text('[0]: '), findsOneWidget);
      },
    );

    testWidgets(
      'renders array match context badge and toggle button switches view mode',
      (tester) async {
        final items = List.generate(20, (i) => {'id': i, 'name': 'Item $i'});
        final json = {'items': items};

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 800,
                child: SmartVirtualJsonTree(
                  json: json,
                  searchQuery: 'Item 10',
                  enableContextWindowing: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify array match badge is present
        expect(find.textContaining('1 matches (Focus: ±1)'), findsOneWidget);
        expect(find.text('Show all 20'), findsOneWidget);

        // Tap 'Show all 20' to expand all
        await tester.tap(find.text('Show all 20'));
        await tester.pumpAndSettle();

        // Now toggle changes to 'Focus matches (±1)' and collapsed range placeholders disappear
        expect(find.text('Focus matches (±1)'), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz), findsNothing);

        // Tap 'Focus matches (±1)' to return to context windowing
        await tester.tap(find.text('Focus matches (±1)'));
        await tester.pumpAndSettle();

        expect(find.text('Show all 20'), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz), findsWidgets);
      },
    );

    testWidgets(
      'jumpToMatch centers target row and applies active match indicator',
      (tester) async {
        final key = GlobalKey<SmartVirtualJsonTreeState>();
        final json = {
          'items': [
            {'id': 1, 'name': 'Target A'},
            {'id': 2, 'name': 'Target B'},
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: SmartVirtualJsonTree(
                  key: key,
                  json: json,
                  searchQuery: 'Target',
                  enableContextWindowing: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Programmatic jump to match 0
        key.currentState?.jumpToMatch(0);
        await tester.pumpAndSettle();

        // Active target indicator 🎯 should be rendered
        expect(find.text('🎯'), findsOneWidget);
      },
    );

    testWidgets(
      'renders compound breadcrumb key when enableIndentationFlattening is true',
      (tester) async {
        final json = {
          'transport': {
            'order': {'code': 'XYZ-999'},
          },
        };

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: SmartVirtualJsonTree(
                  json: json,
                  enableIndentationFlattening: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should display compound breadcrumb 'transport › order'
        expect(find.textContaining('transport'), findsOneWidget);
        expect(find.textContaining('order'), findsOneWidget);
        expect(find.textContaining('›'), findsOneWidget);
      },
    );

    testWidgets('formats ISO-8601 timestamps with clock icon and tooltip', (
      tester,
    ) async {
      final json = {'createdAt': '2026-09-29T19:00:00+01:00'};

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets(
      'renders compact list as composite badge and shows items in popover',
      (tester) async {
        final json = {
          'aktionsKategorien': ['ENTLADESTELLE'],
        };

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: SmartVirtualJsonTree(json: json),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should render compact badge on a single line
        expect(find.byType(SmartCompositeBadge), findsOneWidget);
        expect(find.byIcon(Icons.list_alt), findsOneWidget);

        // Tap on the badge to pin and display popover
        await tester.tap(find.byType(SmartCompositeBadge));
        await tester.pumpAndSettle();

        // Popover should show index row '[0]' and 'ENTLADESTELLE'
        expect(find.text('[0]'), findsOneWidget);
        expect(find.text('ENTLADESTELLE'), findsOneWidget);
      },
    );

    testWidgets(
      'search query matching compact list badge highlights and jumps to match',
      (tester) async {
        final GlobalKey<SmartVirtualJsonTreeState> key =
            GlobalKey<SmartVirtualJsonTreeState>();
        final json = {
          'order': {
            'aktionsKategorien': ['ENTLADESTELLE'],
            'other': 'regular_value',
          },
        };

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: SmartVirtualJsonTree(
                  key: key,
                  json: json,
                  searchQuery: 'ENTLADE',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The ancestor 'order' should be auto-expanded and compact badge rendered
        expect(find.byType(SmartCompositeBadge), findsOneWidget);
        expect(find.byIcon(Icons.list_alt), findsOneWidget);

        // Stepper jump to match
        key.currentState?.jumpToMatch(0);
        await tester.pumpAndSettle();

        expect(find.text('🎯'), findsOneWidget);
      },
    );

    test(
      'copyableNodeText serializes Map/List as pretty JSON and scalars as plain text',
      () {
        expect(
          copyableNodeText({
            'b': 2,
            'a': [1, true],
          }),
          const JsonEncoder.withIndent('  ').convert({
            'b': 2,
            'a': [1, true],
          }),
        );
        expect(
          copyableNodeText(['x', 42]),
          const JsonEncoder.withIndent('  ').convert(['x', 42]),
        );
        expect(copyableNodeText('hello'), 'hello');
        expect(copyableNodeText(42), '42');
        expect(copyableNodeText(null), 'null');
      },
    );

    testWidgets('copying a nested Map node copies valid pretty JSON', (
      tester,
    ) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final nested = {'id': 1042, 'name': 'Acme'};
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: {'customer': nested},
                autoExpandSingleItemCollections: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy).first);
      await tester.pump();

      expect(copiedText, isNotNull);
      expect(jsonDecode(copiedText!), nested);
      expect(copiedText, const JsonEncoder.withIndent('  ').convert(nested));
    });

    testWidgets(
      'decodes JSON string inline, hides pin/filter in decoded subtree, and clears via Show original only',
      (tester) async {
        final pinned = <String>[];
        final filtered = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: SmartVirtualJsonTree(
                  json: {'payload': '{"innerKey": 99}', 'other': 'ok'},
                  onPinToColumn: pinned.add,
                  onFilterByField: filtered.add,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Originally 2 rows have pin & filter buttons
        expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));
        expect(find.byIcon(Icons.filter_alt_outlined), findsNWidgets(2));

        // Open Decode as… menu on first string row ('payload')
        await tester.tap(find.byIcon(Icons.transform).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON').last);
        await tester.pumpAndSettle();

        // Decoded subtree is visible
        expect(find.text('innerKey: '), findsOneWidget);
        expect(find.text('99'), findsOneWidget);
        // Pin and filter buttons are NOT added for decoded child rows
        expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));
        expect(find.byIcon(Icons.filter_alt_outlined), findsNWidgets(2));

        // Clear via 'Show original only' tooltip close icon on the chip
        await tester.tap(find.byTooltip('Show original only').first);
        await tester.pumpAndSettle();

        expect(find.text('innerKey: '), findsNothing);
      },
    );

    testWidgets(
      'chains Base64 -> gzip -> JSON and renders binary row with copy as hex',
      (tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final gzBytes = gzip.encode(utf8.encode('{"msg":"hi"}'));
        final b64 = base64Encode(gzBytes);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: SmartVirtualJsonTree(json: {'blob': b64}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Decode blob as Base64 -> binary row
        await tester.tap(find.byIcon(Icons.transform).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Base64').last);
        await tester.pumpAndSettle();

        expect(find.text('${gzBytes.length} bytes'), findsOneWidget);
        expect(find.byTooltip('Copy as hex'), findsOneWidget);

        // Copy as hex
        await tester.tap(find.byTooltip('Copy as hex'));
        await tester.pump();
        expect(copiedText, isNotNull);
        expect(copiedText!.startsWith('1f 8b'), isTrue);

        // Chain decode binary row as gzip -> text -> JSON
        await tester.tap(find.byIcon(Icons.transform).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('gzip').last);
        await tester.pumpAndSettle();

        expect(find.text('"{"msg":"hi"}"'), findsOneWidget);
      },
    );

    testWidgets(
      'shows dismissible decode error and clears decodes when json changes',
      (tester) async {
        Map<String, dynamic> currentJson = {'bad': 'not-json'};

        late StateSetter setOuterState;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    width: 700,
                    height: 400,
                    child: SmartVirtualJsonTree(json: currentJson),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.transform).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON').last);
        await tester.pumpAndSettle();

        expect(find.text('Not valid JSON'), findsOneWidget);

        // Dismiss error
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pumpAndSettle();
        expect(find.text('Not valid JSON'), findsNothing);

        // Decode again then change json -> error cleared
        await tester.tap(find.byIcon(Icons.transform).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON').last);
        await tester.pumpAndSettle();
        expect(find.text('Not valid JSON'), findsOneWidget);

        setOuterState(() {
          currentJson = {'bad': 'other'};
        });
        await tester.pumpAndSettle();
        expect(find.text('Not valid JSON'), findsNothing);
      },
    );

    testWidgets(
      'right-click context menu on string row opens Decode as… and decodes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: SmartVirtualJsonTree(json: {'payload': '{"ctx": 42}'}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final target = find.textContaining('"{"ctx": 42}"');
        await tester.tap(target, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('JSON'), findsOneWidget);
        await tester.tap(find.text('JSON'));
        await tester.pumpAndSettle();

        expect(find.text('ctx: '), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
      },
    );

    testWidgets(
      'epoch tooltip renders on plausible epoch and reacts to TimeDisplaySettings; not on 42 or 3.5',
      (tester) async {
        final settings = TimeDisplaySettings();
        if (getIt.isRegistered<TimeDisplaySettings>()) {
          getIt.unregister<TimeDisplaySettings>();
        }
        getIt.registerSingleton<TimeDisplaySettings>(settings);
        addTearDown(() {
          if (getIt.isRegistered<TimeDisplaySettings>()) {
            getIt.unregister<TimeDisplaySettings>();
          }
          settings.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: SmartVirtualJsonTree(
                  json: {'ts': 1700000000000, 'small': 42, 'dbl': 3.5},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 1 Tooltip for 'ts', none for 'small' or 'dbl'
        final tooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .where(
              (t) => (t.message ?? '').contains('Assumed unit: milliseconds'),
            );
        expect(tooltips.length, 1);
        expect(tooltips.first.message!.startsWith('Local:'), isTrue);

        // Switch to UTC mode
        settings.value = TimeDisplayMode.utc;
        await tester.pumpAndSettle();

        final utcTooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .where(
              (t) => (t.message ?? '').contains('Assumed unit: milliseconds'),
            );
        expect(utcTooltips.length, 1);
        expect(utcTooltips.first.message!.startsWith('UTC:'), isTrue);
      },
    );
  });
}
