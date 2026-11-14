import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';

typedef TlsProbeFn = Future<TlsProbeResult> Function(ClusterProfile profile);

class TlsConnectResolution {
  final ClusterProfile profile;
  final bool blockedByCertificateRejection;
  final String? errorMessage;

  const TlsConnectResolution({
    required this.profile,
    this.blockedByCertificateRejection = false,
    this.errorMessage,
  });
}

class TlsTransitionDecision {
  final ClusterProfile profile;
  final String? errorMessage;
  final Completer<TlsConnectResolution> _completer = Completer();

  TlsTransitionDecision({required this.profile, this.errorMessage});

  Future<TlsConnectResolution> get future => _completer.future;
}

class TlsTransitionController extends ChangeNotifier {
  static const String transitionPrefKey = 'tls_verification_transition_v1';

  final TlsProbeFn _probeFn;
  final ClusterListController? Function() _clusterListProvider;
  final Future<SharedPreferences> Function() _prefsProvider;

  final Map<String, Future<TlsProbeResult>> _inFlightProbes = {};
  final List<TlsTransitionDecision> _pendingDecisions = [];
  bool _sweepRunning = false;

  TlsTransitionController({
    TlsProbeFn? probeFn,
    ClusterListController? Function()? clusterListProvider,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _probeFn =
           probeFn ?? ((profile) => probeTlsVerification(profile: profile)),
       _clusterListProvider =
           clusterListProvider ??
           (() => getIt.isRegistered<ClusterListController>()
               ? getIt<ClusterListController>()
               : null),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  List<TlsTransitionDecision> get pendingDecisions =>
      List.unmodifiable(_pendingDecisions);

  TlsTransitionDecision? get currentDecision =>
      _pendingDecisions.isEmpty ? null : _pendingDecisions.first;

  Future<TlsProbeResult> _probeDeduped(ClusterProfile profile) {
    final existing = _inFlightProbes[profile.name];
    if (existing != null) return existing;

    final future = _probeFn(profile).whenComplete(() {
      _inFlightProbes.remove(profile.name);
    });
    _inFlightProbes[profile.name] = future;
    return future;
  }

  Future<ClusterProfile> _persistVerificationByName(
    String profileName,
    ClusterProfile fallbackProfile,
    TlsVerification target,
  ) async {
    final listController = _clusterListProvider();
    if (listController != null) {
      final idx = listController.clusters.indexWhere(
        (c) => c.name == profileName,
      );
      if (idx == -1) {
        // Profile was deleted while probe/dialog was in flight; drop persistence.
        return fallbackProfile.copyWith(tlsVerification: target);
      }
      final updated = listController.clusters[idx].copyWith(
        tlsVerification: target,
      );
      await listController.updateCluster(idx, updated);
      return updated;
    }
    return fallbackProfile.copyWith(tlsVerification: target);
  }

  TlsTransitionDecision _enqueueDecision(
    ClusterProfile profile,
    String? errorMessage,
  ) {
    final existing = _pendingDecisions
        .cast<TlsTransitionDecision?>()
        .firstWhere(
          (d) => d?.profile.name == profile.name,
          orElse: () => null,
        );
    if (existing != null) return existing;

    final decision = TlsTransitionDecision(
      profile: profile,
      errorMessage: errorMessage,
    );
    _pendingDecisions.add(decision);
    notifyListeners();
    return decision;
  }

  Future<void> resolveDecision(
    TlsTransitionDecision decision, {
    required bool keepVerificationEnabled,
  }) async {
    _pendingDecisions.remove(decision);
    notifyListeners();

    final target = keepVerificationEnabled
        ? TlsVerification.enabled
        : TlsVerification.disabled;
    final updated = await _persistVerificationByName(
      decision.profile.name,
      decision.profile,
      target,
    );
    if (!decision._completer.isCompleted) {
      decision._completer.complete(
        TlsConnectResolution(
          profile: updated,
          blockedByCertificateRejection: keepVerificationEnabled,
          errorMessage: keepVerificationEnabled ? decision.errorMessage : null,
        ),
      );
    }
  }

  void dismissDecision(TlsTransitionDecision decision) {
    _pendingDecisions.remove(decision);
    notifyListeners();
    if (!decision._completer.isCompleted) {
      decision._completer.complete(
        TlsConnectResolution(
          profile: decision.profile,
          blockedByCertificateRejection: true,
          errorMessage: decision.errorMessage,
        ),
      );
    }
  }

  Future<void> runStartupSweep() async {
    if (_sweepRunning) return;
    _sweepRunning = true;
    try {
      final prefs = await _prefsProvider();
      if (prefs.getBool(transitionPrefKey) == true) {
        return;
      }

      final listController = _clusterListProvider();
      if (listController == null) return;

      final candidates = listController.clusters
          .where((c) => c.tlsVerification == TlsVerification.unreviewed)
          .toList();

      for (final profile in candidates) {
        // Re-check it still exists and is still unreviewed.
        final currentIdx = listController.clusters.indexWhere(
          (c) => c.name == profile.name,
        );
        if (currentIdx == -1) continue;
        final current = listController.clusters[currentIdx];
        if (current.tlsVerification != TlsVerification.unreviewed) continue;

        final result = await _probeDeduped(current);
        switch (result.outcome) {
          case TlsProbeOutcome.noTls:
          case TlsProbeOutcome.verified:
            await _persistVerificationByName(
              current.name,
              current,
              TlsVerification.enabled,
            );
          case TlsProbeOutcome.certificateRejected:
            _enqueueDecision(current, result.message);
          case TlsProbeOutcome.inconclusive:
            // Leave unreviewed so connect() can probe again later.
            break;
        }
      }

      await prefs.setBool(transitionPrefKey, true);
    } finally {
      _sweepRunning = false;
    }
  }

  Future<TlsConnectResolution> resolveBeforeConnect(
    ClusterProfile profile,
  ) async {
    if (profile.tlsVerification != TlsVerification.unreviewed) {
      return TlsConnectResolution(profile: profile);
    }

    final result = await _probeDeduped(profile);
    switch (result.outcome) {
      case TlsProbeOutcome.noTls:
      case TlsProbeOutcome.verified:
        final updated = await _persistVerificationByName(
          profile.name,
          profile,
          TlsVerification.enabled,
        );
        return TlsConnectResolution(profile: updated);
      case TlsProbeOutcome.inconclusive:
        return TlsConnectResolution(profile: profile);
      case TlsProbeOutcome.certificateRejected:
        final decision = _enqueueDecision(profile, result.message);
        return decision.future;
    }
  }

  Future<ClusterProfile> markVerifiedIfUnreviewed(
    ClusterProfile profile,
  ) async {
    if (profile.tlsVerification != TlsVerification.unreviewed) {
      return profile;
    }
    return _persistVerificationByName(
      profile.name,
      profile,
      TlsVerification.enabled,
    );
  }
}
