import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_config_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/config/topic_config_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';
import 'package:material_ui/material_ui.dart';

class _FakeTopicConfigService implements TopicConfigService {
  final List<(String, String)> fetchCalls = [];
  Future<TopicConfigSnapshot> Function(ClusterProfile profile, String topic)?
  onFetch;
  TopicConfigDiff Function(TopicConfigSnapshot left, TopicConfigSnapshot right)?
  onDiff;

  @override
  Future<TopicConfigSnapshot> fetchTopicConfig({
    required ClusterProfile profile,
    required String topic,
  }) {
    fetchCalls.add((profile.name, topic));
    return onFetch!(profile, topic);
  }

  @override
  TopicConfigDiff diffTopicConfigs({
    required TopicConfigSnapshot left,
    required TopicConfigSnapshot right,
  }) {
    if (onDiff != null) {
      return onDiff!(left, right);
    }
    if (left.availability != TopicConfigAvailability.available ||
        right.availability != TopicConfigAvailability.available) {
      final source = left.availability == TopicConfigAvailability.available
          ? left.entries
          : right.entries;
      return TopicConfigDiff(
        rows: [
          for (final e in source)
            TopicConfigDiffRow(
              name: e.name,
              left: left.availability == TopicConfigAvailability.available
                  ? e
                  : null,
              right: right.availability == TopicConfigAvailability.available
                  ? e
                  : null,
              status: TopicConfigDiffStatus.unknown,
              nonDefault: !e.isDefault,
            ),
        ],
        differenceCount: null,
      );
    }
    final leftMap = {for (final e in left.entries) e.name: e};
    final rightMap = {for (final e in right.entries) e.name: e};
    final names = {...leftMap.keys, ...rightMap.keys}.toList()..sort();
    var diffs = 0;
    final rows = <TopicConfigDiffRow>[];
    for (final name in names) {
      final l = leftMap[name];
      final r = rightMap[name];
      if (l != null && r != null) {
        final same = l.value == r.value;
        if (!same) diffs++;
        rows.add(
          TopicConfigDiffRow(
            name: name,
            left: l,
            right: r,
            status: same
                ? TopicConfigDiffStatus.equal
                : TopicConfigDiffStatus.different,
            nonDefault: !l.isDefault || !r.isDefault,
          ),
        );
      }
    }
    return TopicConfigDiff(rows: rows, differenceCount: diffs);
  }
}

ClusterProfile _profile(
  String name, {
  TlsVerification tlsVerification = TlsVerification.enabled,
}) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: tlsVerification,
);

TopicConfigEntry _entry(
  String name,
  String? value, {
  TopicConfigSource source = TopicConfigSource.dynamicTopic,
  bool isDefault = false,
  bool isSensitive = false,
}) => TopicConfigEntry(
  name: name,
  value: value,
  source: source,
  isDefault: isDefault,
  isSensitive: isSensitive,
  isReadOnly: false,
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1100, height: 700, child: child)),
);

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('shows loading indicator while fetching', (tester) async {
    final completer = Completer<TopicConfigSnapshot>();
    final service = _FakeTopicConfigService()
      ..onFetch = (_, _) => completer.future;
    final controller = TopicConfigController(
      service: service,
      leftProfile: _profile('prod'),
      leftTopic: 'orders',
    );
    controller.ensureLoaded();

    await tester.pumpWidget(_wrap(TopicConfigView(controller: controller)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    completer.complete(
      const TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [],
      ),
    );
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets(
    'renders rows in order, sensitive placeholder without value, unknown source, and non-default toggle',
    (tester) async {
      final service = _FakeTopicConfigService()
        ..onFetch = (_, topic) async => TopicConfigSnapshot(
          topic: topic,
          availability: TopicConfigAvailability.available,
          entries: [
            _entry(
              'cleanup.policy',
              'compact',
              source: TopicConfigSource.unknown,
              isDefault: false,
            ),
            _entry(
              'retention.ms',
              '604800000',
              source: TopicConfigSource.default_,
              isDefault: true,
            ),
            _entry(
              'ssl.key.password',
              null,
              source: TopicConfigSource.staticBroker,
              isDefault: false,
              isSensitive: true,
            ),
          ],
        );
      final controller = TopicConfigController(
        service: service,
        leftProfile: _profile(
          'prod',
          tlsVerification: TlsVerification.disabled,
        ),
        leftTopic: 'orders',
      );
      await controller.refresh();

      await tester.pumpWidget(_wrap(TopicConfigView(controller: controller)));
      await tester.pumpAndSettle();

      // Insecure TLS badge on disabled-TLS side
      expect(find.byType(InsecureTlsBadge), findsOneWidget);

      // Order check: cleanup.policy above retention.ms above ssl.key.password
      final cleanupY = tester.getTopLeft(find.text('cleanup.policy')).dy;
      final retentionY = tester.getTopLeft(find.text('retention.ms')).dy;
      final sslY = tester.getTopLeft(find.text('ssl.key.password')).dy;
      expect(cleanupY, lessThan(retentionY));
      expect(retentionY, lessThan(sslY));

      // Sensitive placeholder & unknown source label
      expect(find.text(l10n.topicConfigPlaceholderSensitive), findsOneWidget);
      expect(find.text(l10n.topicConfigSourceUnknown), findsOneWidget);

      // Non-default toggle hides retention.ms (isDefault: true) and keeps overrides
      await tester.tap(find.text(l10n.topicConfigNonDefaultToggle));
      await tester.pumpAndSettle();

      expect(find.text('cleanup.policy'), findsOneWidget);
      expect(find.text('ssl.key.password'), findsOneWidget);
      expect(find.text('retention.ms'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('shows not authorized message and retries on tap', (
    tester,
  ) async {
    var attempt = 0;
    final service = _FakeTopicConfigService()
      ..onFetch = (_, topic) async {
        attempt++;
        if (attempt == 1) {
          return TopicConfigSnapshot(
            topic: topic,
            availability: TopicConfigAvailability.notAuthorized,
            entries: const [],
          );
        }
        return TopicConfigSnapshot(
          topic: topic,
          availability: TopicConfigAvailability.available,
          entries: [_entry('retention.ms', '60000')],
        );
      };
    final controller = TopicConfigController(
      service: service,
      leftProfile: _profile('prod'),
      leftTopic: 'orders',
    );
    await controller.refresh();

    await tester.pumpWidget(_wrap(TopicConfigView(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text(l10n.topicConfigUnavailableNotAuthorized), findsOneWidget);
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('retention.ms'), findsOneWidget);
    expect(attempt, 2);
    controller.dispose();
  });

  testWidgets(
    'comparison with one unreadable side shows unknown and no difference count, and differences filter keeps equal-override rows',
    (tester) async {
      final leftProfile = _profile('prod');
      final rightProfile = _profile(
        'staging',
        tlsVerification: TlsVerification.disabled,
      );
      var rightAuthorized = false;

      final service = _FakeTopicConfigService()
        ..onFetch = (profile, topic) async {
          if (profile.name == 'prod') {
            return TopicConfigSnapshot(
              topic: topic,
              availability: TopicConfigAvailability.available,
              entries: [
                _entry('cleanup.policy', 'compact', isDefault: false),
                _entry(
                  'retention.ms',
                  '604800000',
                  source: TopicConfigSource.default_,
                  isDefault: true,
                ),
                _entry('segment.bytes', '1048576', isDefault: false),
              ],
            );
          }
          if (!rightAuthorized) {
            return TopicConfigSnapshot(
              topic: topic,
              availability: TopicConfigAvailability.notAuthorized,
              entries: const [],
            );
          }
          return TopicConfigSnapshot(
            topic: topic,
            availability: TopicConfigAvailability.available,
            entries: [
              _entry('cleanup.policy', 'compact', isDefault: false),
              _entry(
                'retention.ms',
                '604800000',
                source: TopicConfigSource.default_,
                isDefault: true,
              ),
              _entry('segment.bytes', '2097152', isDefault: false),
            ],
          );
        };

      final controller = TopicConfigController(
        service: service,
        leftProfile: leftProfile,
        leftTopic: 'orders',
      );
      await controller.refresh();
      await controller.startComparison(rightProfile, 'orders');

      await tester.pumpWidget(_wrap(TopicConfigView(controller: controller)));
      await tester.pumpAndSettle();

      // One unreadable side: shows unknown status, no difference count, and insecure badge on right
      expect(find.text(l10n.topicConfigDifferencesUnknown), findsOneWidget);
      expect(find.text(l10n.topicConfigStatusUnknown), findsWidgets);
      expect(find.byType(InsecureTlsBadge), findsOneWidget);

      // Now retry right side -> becomes authorized
      rightAuthorized = true;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text(l10n.topicConfigDifferencesCount(1)), findsOneWidget);

      // Toggle differences filter: hides equal-default (retention.ms), keeps equal-override (cleanup.policy) and different (segment.bytes)
      await tester.tap(find.text(l10n.topicConfigDiffToggle));
      await tester.pumpAndSettle();

      expect(find.text('cleanup.policy'), findsOneWidget);
      expect(find.text('segment.bytes'), findsOneWidget);
      expect(find.text('retention.ms'), findsNothing);
      controller.dispose();
    },
  );
}
