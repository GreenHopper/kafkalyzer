import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/subject_browser_list.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:material_ui/material_ui.dart';

class _FakeBrowserRegistryService extends SchemaRegistryService {
  Future<List<String>> Function()? onFetchSubjects;
  Future<String> Function()? onFetchGlobalCompat;
  int associateCalls = 0;

  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) {
    return onFetchSubjects!();
  }

  @override
  Future<String> fetchGlobalCompatibility({required ClusterProfile profile}) {
    if (onFetchGlobalCompat != null) {
      return onFetchGlobalCompat!();
    }
    return Future.value('BACKWARD');
  }

  @override
  List<api.SubjectAssociationDto> associateSubjects({
    required List<String> subjects,
    required List<String> topics,
  }) {
    associateCalls++;
    final topicSet = topics.toSet();
    return [
      for (final s in subjects)
        if (s.endsWith('-value'))
          api.SubjectAssociationDto(
            subject: s,
            topic: s.substring(0, s.length - 6),
            side: api.TopicSideDto.value,
            onCluster: topicSet.contains(s.substring(0, s.length - 6)),
          )
        else if (s.endsWith('-key'))
          api.SubjectAssociationDto(
            subject: s,
            topic: s.substring(0, s.length - 4),
            side: api.TopicSideDto.key,
            onCluster: topicSet.contains(s.substring(0, s.length - 4)),
          )
        else
          api.SubjectAssociationDto(
            subject: s,
            topic: null,
            side: api.TopicSideDto.none,
            onCluster: false,
          ),
    ];
  }
}

const _profile = ClusterProfile(
  name: 'prod',
  bootstrapServers: 'b:9092',
  schemaRegistryUrl: 'https://sr.internal:8081',
  tlsVerification: TlsVerification.enabled,
);

const _noSrProfile = ClusterProfile(
  name: 'no-sr',
  bootstrapServers: 'b:9092',
  tlsVerification: TlsVerification.enabled,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Column(children: [child])),
  );
}

void main() {
  testWidgets('no registry configured shows settings action', (tester) async {
    var settingsOpened = false;
    final controller = SchemaController(
      registryService: _FakeBrowserRegistryService(),
    );

    await tester.pumpWidget(
      _wrap(
        SubjectBrowserList(
          profile: _noSrProfile,
          schemaController: controller,
          topicNames: const [],
          onSelectSubject: (_) {},
          onOpenClusterSettings: () => settingsOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No Schema Registry configured for this cluster.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('subject_browser_configure_registry')),
    );
    expect(settingsOpened, isTrue);
  });

  testWidgets('loading, error with retry, and refresh keeping old list', (
    tester,
  ) async {
    final service = _FakeBrowserRegistryService();
    var completer = Completer<List<String>>();
    service.onFetchSubjects = () => completer.future;
    final controller = SchemaController(registryService: service);

    await tester.pumpWidget(
      _wrap(
        SubjectBrowserList(
          profile: _profile,
          schemaController: controller,
          topicNames: const ['orders'],
          onSelectSubject: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Fail with 401
    completer.completeError(
      const api.SchemaRegistryErrorDto(
        kind: api.SchemaRegistryErrorKindDto.unauthorized,
        status: 401,
        detail: '401',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subjects: unknown'), findsOneWidget);
    expect(find.textContaining('username and password'), findsOneWidget);

    // Retry succeeds
    service.onFetchSubjects = () async => ['orders-value', 'legacy-key'];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Global compatibility: BACKWARD'), findsOneWidget);
    expect(find.text('orders-value'), findsOneWidget);
    expect(find.text('orders · Value'), findsOneWidget);
    expect(find.text('legacy (not on cluster) · Key'), findsOneWidget);

    // Refresh keeps old list visible while loading
    final refreshCompleter = Completer<List<String>>();
    service.onFetchSubjects = () => refreshCompleter.future;
    await tester.tap(find.byKey(const Key('subject_browser_refresh')));
    await tester.pump();
    expect(find.text('orders-value'), findsOneWidget);

    refreshCompleter.complete(['orders-value']);
    await tester.pumpAndSettle();
    expect(find.text('1 of 1'), findsOneWidget);
  });

  testWidgets('empty registry vs no-match filter and row tap', (tester) async {
    final service = _FakeBrowserRegistryService();
    service.onFetchSubjects = () async => const [];
    final controller = SchemaController(registryService: service);

    await tester.pumpWidget(
      _wrap(
        SubjectBrowserList(
          profile: _profile,
          schemaController: controller,
          topicNames: const [],
          onSelectSubject: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No subjects registered in Schema Registry.'),
      findsOneWidget,
    );

    // Now populate and test no-match + tap
    service.onFetchSubjects = () async => const ['orders-value'];
    final selected = <String>[];
    await tester.pumpWidget(
      _wrap(
        SubjectBrowserList(
          key: const ValueKey('populated'),
          profile: _profile,
          schemaController: controller,
          topicNames: const ['orders'],
          onSelectSubject: selected.add,
        ),
      ),
    );
    await controller.fetchSchemas(_profile, force: true);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('subject_browser_filter')),
      'nomatch',
    );
    await tester.pumpAndSettle();
    expect(find.text('No subjects match "nomatch".'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('subject_browser_filter')),
      'orders',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 1'), findsOneWidget);

    await tester.tap(find.text('orders-value'));
    expect(selected, ['orders-value']);
  });

  testWidgets(
    '10 000 subjects calls associateSubjects once and filtering does not call bridge',
    (tester) async {
      final service = _FakeBrowserRegistryService();
      final subjects = List.generate(10000, (i) => 'topic-$i-value');
      service.onFetchSubjects = () async => subjects;
      final controller = SchemaController(registryService: service);

      await tester.pumpWidget(
        _wrap(
          SubjectBrowserList(
            profile: _profile,
            schemaController: controller,
            topicNames: const ['topic-0', 'topic-42'],
            onSelectSubject: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.associateCalls, 1);
      expect(find.text('10000 of 10000'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('subject_browser_filter')),
        'topic-42-',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 10000'), findsOneWidget);
      expect(service.associateCalls, 1);
    },
  );
}
