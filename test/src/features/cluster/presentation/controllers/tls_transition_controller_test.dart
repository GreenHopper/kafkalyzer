import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClusterService extends ClusterService {
  List<ClusterProfile> stored = [];

  @override
  Future<List<ClusterProfile>> loadClusters() async => List.of(stored);

  @override
  Future<bool> saveClusters(List<ClusterProfile> clusters) async {
    stored = List.of(clusters);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClusterService fakeService;
  late ClusterListController listController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeService = _FakeClusterService();
    getIt.registerSingleton<ClusterService>(fakeService);
    listController = ClusterListController();
    await Future<void>.delayed(Duration.zero);
  });

  ClusterProfile makeProfile(
    String name, {
    TlsVerification tls = TlsVerification.unreviewed,
  }) => ClusterProfile(
    name: name,
    bootstrapServers: 'broker:9093',
    securityProtocol: 'SSL',
    tlsVerification: tls,
  );

  group('TlsTransitionController', () {
    test('NoTls and Verified mark unreviewed profiles as enabled', () async {
      await listController.addCluster(makeProfile('plain'));
      await listController.addCluster(makeProfile('valid-tls'));

      final controller = TlsTransitionController(
        clusterListProvider: () => listController,
        probeFn: (profile) async {
          if (profile.name == 'plain') {
            return const TlsProbeResult(outcome: TlsProbeOutcome.noTls);
          }
          return const TlsProbeResult(outcome: TlsProbeOutcome.verified);
        },
      );

      await controller.runStartupSweep();

      expect(
        listController.clusters[0].tlsVerification,
        TlsVerification.enabled,
      );
      expect(
        listController.clusters[1].tlsVerification,
        TlsVerification.enabled,
      );
      expect(controller.pendingDecisions, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TlsTransitionController.transitionPrefKey), isTrue);
    });

    test('Inconclusive leaves profile unreviewed', () async {
      await listController.addCluster(makeProfile('offline'));

      final controller = TlsTransitionController(
        clusterListProvider: () => listController,
        probeFn: (_) async => const TlsProbeResult(
          outcome: TlsProbeOutcome.inconclusive,
          message: 'Connection refused',
        ),
      );

      await controller.runStartupSweep();

      expect(
        listController.clusters.first.tlsVerification,
        TlsVerification.unreviewed,
      );
      expect(controller.pendingDecisions, isEmpty);
    });

    test('flag prevents second startup sweep', () async {
      SharedPreferences.setMockInitialValues({
        TlsTransitionController.transitionPrefKey: true,
      });
      await listController.addCluster(makeProfile('still-unreviewed'));

      var probeCalls = 0;
      final controller = TlsTransitionController(
        clusterListProvider: () => listController,
        probeFn: (_) async {
          probeCalls++;
          return const TlsProbeResult(outcome: TlsProbeOutcome.verified);
        },
      );

      await controller.runStartupSweep();

      expect(probeCalls, 0);
      expect(
        listController.clusters.first.tlsVerification,
        TlsVerification.unreviewed,
      );
    });

    test(
      'CertificateRejected queues decisions FIFO and persists user choice',
      () async {
        await listController.addCluster(makeProfile('self-signed-1'));
        await listController.addCluster(makeProfile('self-signed-2'));

        final controller = TlsTransitionController(
          clusterListProvider: () => listController,
          probeFn: (p) async => TlsProbeResult(
            outcome: TlsProbeOutcome.certificateRejected,
            message: 'unknown ca for ${p.name}',
          ),
        );

        await controller.runStartupSweep();
        expect(controller.pendingDecisions, hasLength(2));
        expect(controller.currentDecision?.profile.name, 'self-signed-1');

        await controller.resolveDecision(
          controller.currentDecision!,
          keepVerificationEnabled: true,
        );
        expect(
          listController.clusters[0].tlsVerification,
          TlsVerification.enabled,
        );
        expect(controller.currentDecision?.profile.name, 'self-signed-2');

        await controller.resolveDecision(
          controller.currentDecision!,
          keepVerificationEnabled: false,
        );
        expect(
          listController.clusters[1].tlsVerification,
          TlsVerification.disabled,
        );
        expect(controller.pendingDecisions, isEmpty);
      },
    );

    test('deduplicates in-flight probes per profile name', () async {
      final profile = makeProfile('dedup');
      await listController.addCluster(profile);

      var probeCalls = 0;
      final completer = Completer<TlsProbeResult>();
      final controller = TlsTransitionController(
        clusterListProvider: () => listController,
        probeFn: (_) {
          probeCalls++;
          return completer.future;
        },
      );

      final f1 = controller.resolveBeforeConnect(profile);
      final f2 = controller.resolveBeforeConnect(profile);
      expect(probeCalls, 1);

      completer.complete(
        const TlsProbeResult(outcome: TlsProbeOutcome.verified),
      );
      final results = await Future.wait([f1, f2]);
      expect(results[0].profile.tlsVerification, TlsVerification.enabled);
      expect(results[1].profile.tlsVerification, TlsVerification.enabled);
    });

    test(
      'drops result when profile is deleted while probe is in flight',
      () async {
        final profile = makeProfile('ephemeral');
        await listController.addCluster(profile);

        final completer = Completer<TlsProbeResult>();
        final controller = TlsTransitionController(
          clusterListProvider: () => listController,
          probeFn: (_) => completer.future,
        );

        final f = controller.resolveBeforeConnect(profile);
        await listController.deleteCluster(0);
        expect(listController.clusters, isEmpty);

        completer.complete(
          const TlsProbeResult(outcome: TlsProbeOutcome.verified),
        );
        final res = await f;
        expect(listController.clusters, isEmpty);
        expect(res.profile.tlsVerification, TlsVerification.enabled);
      },
    );
  });
}
