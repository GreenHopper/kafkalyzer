import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/storage_notice_banner.dart';
import 'package:material_ui/material_ui.dart';

class _StubClusterController extends ChangeNotifier
    implements ClusterListController {
  StoreStatus _status;
  bool discarded = false;

  _StubClusterController(this._status);

  @override
  StoreStatus get storeStatus => _status;

  @override
  Future<void> discardUnreadable() async {
    discarded = true;
    _status = const StoreStatus.ok();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubScriptController extends ChangeNotifier implements ScriptController {
  StoreStatus _status;
  bool discarded = false;

  _StubScriptController(this._status);

  @override
  StoreStatus get storeStatus => _status;

  @override
  Future<void> discardUnreadable() async {
    discarded = true;
    _status = const StoreStatus.ok();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {});

  Widget buildBanner({
    required ValueNotifier<bool> keyringUnavailable,
    required _StubClusterController clusterController,
    required _StubScriptController scriptController,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StorageNoticeBanner(
          keyringUnavailableOverride: keyringUnavailable,
          clusterControllerOverride: clusterController,
          scriptControllerOverride: scriptController,
        ),
      ),
    );
  }

  group('StorageNoticeBanner', () {
    testWidgets('is hidden when everything is ok', (tester) async {
      await tester.pumpWidget(
        buildBanner(
          keyringUnavailable: ValueNotifier<bool>(false),
          clusterController: _StubClusterController(const StoreStatus.ok()),
          scriptController: _StubScriptController(const StoreStatus.ok()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.key_off_outlined), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('shows keyring unavailable notice without dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          keyringUnavailable: ValueNotifier<bool>(true),
          clusterController: _StubClusterController(const StoreStatus.ok()),
          scriptController: _StubScriptController(const StoreStatus.ok()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('System keyring is unavailable.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.key_off_outlined), findsOneWidget);
    });

    testWidgets(
      'shows unreadable profile store notice with backup, copy, and confirmed discard',
      (tester) async {
        final clusterController = _StubClusterController(
          const StoreStatus.unreadable('/tmp/backups/cluster_profiles.json'),
        );
        await tester.pumpWidget(
          buildBanner(
            keyringUnavailable: ValueNotifier<bool>(false),
            clusterController: clusterController,
            scriptController: _StubScriptController(const StoreStatus.ok()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Saved cluster profiles could not be read'),
          findsOneWidget,
        );
        expect(
          find.textContaining('/tmp/backups/cluster_profiles.json'),
          findsOneWidget,
        );
        expect(find.text('Copy backup path'), findsOneWidget);

        await tester.tap(find.text('Discard unreadable data'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('permanently delete the unreadable stored data'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Discard unreadable data'),
        );
        await tester.pumpAndSettle();

        expect(clusterController.discarded, isTrue);
        expect(
          find.textContaining('Saved cluster profiles could not be read'),
          findsNothing,
        );
      },
    );

    testWidgets('shows unreadable script store notice when backup failed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          keyringUnavailable: ValueNotifier<bool>(false),
          clusterController: _StubClusterController(const StoreStatus.ok()),
          scriptController: _StubScriptController(
            const StoreStatus.unreadable(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Saved scripts could not be read'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No backup file could be written.'),
        findsOneWidget,
      );
      expect(find.text('Copy backup path'), findsNothing);
    });

    testWidgets('shows partially unreadable and duplicate profile notices', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          keyringUnavailable: ValueNotifier<bool>(false),
          clusterController: _StubClusterController(
            const StoreStatus.partiallyUnreadable(
              2,
              duplicateNames: ['Prod', 'Staging'],
            ),
          ),
          scriptController: _StubScriptController(
            const StoreStatus.partiallyUnreadable(1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 unreadable saved cluster_profiles entries'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 unreadable saved saved_scripts_v1 entry'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Duplicate cluster profile names detected: Prod, Staging.',
        ),
        findsOneWidget,
      );
    });
  });
}
