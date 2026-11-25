import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/headless_profiles.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';

const Object _copyWithUnset = Object();

/// Outcome of syncing shared profiles to the headless allowlist file/keyring.
class SharedProfilesStatus {
  const SharedProfilesStatus.ok()
    : failed = const [],
      fileError = null,
      bridgeError = null;

  const SharedProfilesStatus.failed({
    this.failed = const [],
    this.fileError,
    this.bridgeError,
  });

  final List<SharedProfileFailure> failed;
  final String? fileError;
  final String? bridgeError;

  bool get isOk => failed.isEmpty && fileError == null && bridgeError == null;
}

/// Normalises a cluster profile name for case- and whitespace-insensitive
/// uniqueness comparisons.
String normalizeProfileName(String name) => name.trim().toLowerCase();

enum ImportConflictAction { replace, rename, skip }

class ImportConflictChoice {
  final ImportConflictAction action;
  final String? newName;

  const ImportConflictChoice.replace()
    : action = ImportConflictAction.replace,
      newName = null;

  const ImportConflictChoice.rename(String this.newName)
    : action = ImportConflictAction.rename;

  const ImportConflictChoice.skip()
    : action = ImportConflictAction.skip,
      newName = null;
}

class ImportSummary {
  final int imported;
  final int replaced;
  final int renamed;
  final int skipped;

  const ImportSummary({
    required this.imported,
    required this.replaced,
    required this.renamed,
    required this.skipped,
  });

  int get totalAddedOrUpdated => imported + replaced + renamed;
}

class MergeImportResult {
  final List<ClusterProfile> clusters;
  final ImportSummary summary;

  const MergeImportResult({required this.clusters, required this.summary});
}

typedef ImportConflictResolver =
    Future<ImportConflictChoice?> Function(
      ClusterProfile imported,
      String suggestedName,
    );

/// Merges [imported] profiles into [existing], invoking [resolve] for every
/// case/whitespace-insensitive name collision (including duplicates within
/// [imported]). Returns `null` if the user cancels.
Future<MergeImportResult?> mergeImportedProfiles(
  List<ClusterProfile> existing,
  List<ClusterProfile> imported,
  ImportConflictResolver resolve,
) async {
  final merged = List<ClusterProfile>.from(existing);
  final usedNames = merged.map((c) => normalizeProfileName(c.name)).toSet();

  String suggestUniqueName(String baseName) {
    final trimmed = baseName.trim().isEmpty ? 'Cluster' : baseName.trim();
    var candidate = '$trimmed (imported)';
    if (!usedNames.contains(normalizeProfileName(candidate))) {
      return candidate;
    }
    var n = 2;
    while (true) {
      candidate = '$trimmed (imported $n)';
      if (!usedNames.contains(normalizeProfileName(candidate))) {
        return candidate;
      }
      n++;
    }
  }

  var importedCount = 0;
  var replacedCount = 0;
  var renamedCount = 0;
  var skippedCount = 0;

  for (final raw in imported) {
    // Imports never carry sharing state across machines (design D5).
    final item = raw.copyWith(headlessShared: null);
    final norm = normalizeProfileName(item.name);
    final existingIdx = merged.indexWhere(
      (c) => normalizeProfileName(c.name) == norm,
    );

    if (existingIdx == -1) {
      merged.add(item);
      usedNames.add(norm);
      importedCount++;
    } else {
      final choice = await resolve(item, suggestUniqueName(item.name));
      if (choice == null) {
        return null;
      }
      switch (choice.action) {
        case ImportConflictAction.replace:
          merged[existingIdx] = item;
          replacedCount++;
        case ImportConflictAction.rename:
          final newName = (choice.newName ?? '').trim();
          merged.add(item.copyWith(name: newName));
          usedNames.add(normalizeProfileName(newName));
          renamedCount++;
        case ImportConflictAction.skip:
          skippedCount++;
      }
    }
  }

  return MergeImportResult(
    clusters: merged,
    summary: ImportSummary(
      imported: importedCount,
      replaced: replacedCount,
      renamed: renamedCount,
      skipped: skippedCount,
    ),
  );
}

class ClusterService {
  static const String _storageKey = 'cluster_profiles';
  static const String _migratedKey = 'credentials_migrated_to_keyring_v1';

  final SecureStorageService _storage;
  StoreStatus _storeStatus = const StoreStatus.ok();
  List<dynamic> _rawUnreadable = const [];
  String? _backupWrittenForRaw;
  String? _lastBackupPath;

  /// Latest headless shared-profiles sync result for the UI.
  final ValueNotifier<SharedProfilesStatus> sharedProfilesStatus =
      ValueNotifier(const SharedProfilesStatus.ok());

  StoreStatus get storeStatus => _storeStatus;

  ClusterService({SecureStorageService? secureStorage})
    : _storage =
          secureStorage ??
          (getIt.isRegistered<SecureStorageService>()
              ? getIt<SecureStorageService>()
              : SecureStorageService());

  List<String> _findDuplicateNames(List<ClusterProfile> clusters) {
    final counts = <String, int>{};
    for (final c in clusters) {
      final norm = normalizeProfileName(c.name);
      counts[norm] = (counts[norm] ?? 0) + 1;
    }
    final duplicates = <String>[];
    final seen = <String>{};
    for (final c in clusters) {
      final norm = normalizeProfileName(c.name);
      if ((counts[norm] ?? 0) > 1 && seen.add(norm)) {
        duplicates.add(c.name.trim());
      }
    }
    return duplicates;
  }

  void _updateStatus(List<ClusterProfile> clusters, List<dynamic> unreadable) {
    final dups = _findDuplicateNames(clusters);
    if (unreadable.isNotEmpty) {
      _storeStatus = StoreStatus.partiallyUnreadable(
        unreadable.length,
        duplicateNames: dups,
      );
    } else {
      _storeStatus = StoreStatus.ok(duplicateNames: dups);
    }
  }

  Future<String?> _ensureBackup(String rawJson) async {
    if (_backupWrittenForRaw != rawJson) {
      _lastBackupPath = await writeStoreBackup(_storageKey, rawJson);
      _backupWrittenForRaw = rawJson;
    }
    return _lastBackupPath;
  }

  Map<String, String?> _extractSecrets(ClusterProfile profile) => {
    'saslPassword': profile.saslPassword,
    'schemaRegistryPassword': profile.schemaRegistryPassword,
    'sslKeystorePassword': profile.sslKeystorePassword,
    'sslTruststorePassword': profile.sslTruststorePassword,
    'sslPemKeyPassword': profile.sslPemKeyPassword,
    'saslOauthbearerToken': profile.saslOauthbearerToken,
  };

  Future<void> discardUnreadable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_migratedKey);
    _rawUnreadable = const [];
    _backupWrittenForRaw = null;
    _lastBackupPath = null;
    _storeStatus = const StoreStatus.ok();
    await _syncSharedProfiles(const []);
  }

  Future<void> _syncSharedProfiles(List<ClusterProfile> clusters) async {
    try {
      final result = await syncSharedProfiles(
        request: SharedProfilesSyncRequest(profiles: clusters),
      );
      if (result.failed.isEmpty &&
          (result.fileError == null || result.fileError!.isEmpty)) {
        sharedProfilesStatus.value = const SharedProfilesStatus.ok();
      } else {
        sharedProfilesStatus.value = SharedProfilesStatus.failed(
          failed: result.failed,
          fileError: result.fileError,
        );
      }
    } catch (e) {
      sharedProfilesStatus.value = SharedProfilesStatus.failed(
        bridgeError: e.toString(),
      );
    }
  }

  Future<List<ClusterProfile>> loadClusters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      _rawUnreadable = const [];
      _backupWrittenForRaw = null;
      _lastBackupPath = null;
      _storeStatus = const StoreStatus.ok();
      return [];
    }
    final isMigrated = prefs.getBool(_migratedKey) ?? false;

    final parsed = await parseStoredList<ClusterProfile>(
      jsonString,
      (entry) => deserializeClusterProfile(json: jsonEncode(entry)),
    );

    if (parsed.storeUnreadable) {
      final backupPath = await _ensureBackup(jsonString);
      _storeStatus = StoreStatus.unreadable(backupPath);
      throw StoredDataUnreadableException(_storageKey, backupPath: backupPath);
    }

    _backupWrittenForRaw = null;
    _lastBackupPath = null;
    _rawUnreadable = List<dynamic>.from(parsed.rawUnreadable);

    final clusters = <ClusterProfile>[];
    final keepPlaintext = <bool>[];
    var allMigrated = true;
    var anyStripped = false;

    for (final profile in parsed.items) {
      var strippedThisProfile = false;
      if (!isMigrated) {
        final plaintextSecrets = _extractSecrets(profile);
        final hasPlaintext = plaintextSecrets.values.any(
          (v) => v != null && v.isNotEmpty,
        );
        if (hasPlaintext) {
          final ok = await _storage.saveClusterSecrets(
            profile.name,
            plaintextSecrets,
          );
          if (ok) {
            strippedThisProfile = true;
            anyStripped = true;
          } else {
            allMigrated = false;
          }
        }
      }
      keepPlaintext.add(!strippedThisProfile && !isMigrated);

      final secrets = await _storage.getClusterSecrets(profile.name);
      clusters.add(profile.withSecrets(secrets));
    }

    if (!isMigrated) {
      if (anyStripped) {
        final encoded = <String>[];
        for (var i = 0; i < parsed.items.length; i++) {
          final toEncode = keepPlaintext[i]
              ? parsed.items[i]
              : parsed.items[i].sanitized();
          encoded.add(await serializeClusterProfile(profile: toEncode));
        }
        for (final raw in _rawUnreadable) {
          encoded.add(jsonEncode(raw));
        }
        await prefs.setString(_storageKey, '[${encoded.join(',')}]');
      }
      if (allMigrated) {
        await prefs.setBool(_migratedKey, true);
      }
    }

    _updateStatus(clusters, _rawUnreadable);
    return clusters;
  }

  Future<bool> saveClusters(List<ClusterProfile> clusters) async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getString(_storageKey);
    final currentNames = <String>{};
    final unreadableNames = <String>{};
    List<ClusterProfile> oldReadableProfiles = const [];

    if (existingJson != null) {
      final parsed = await parseStoredList<ClusterProfile>(
        existingJson,
        (entry) => deserializeClusterProfile(json: jsonEncode(entry)),
      );
      if (parsed.storeUnreadable) {
        final backupPath = await _ensureBackup(existingJson);
        _storeStatus = StoreStatus.unreadable(backupPath);
        throw StoredDataUnreadableException(
          _storageKey,
          backupPath: backupPath,
        );
      }
      oldReadableProfiles = parsed.items;
      _rawUnreadable = List<dynamic>.from(parsed.rawUnreadable);
      for (final raw in _rawUnreadable) {
        if (raw is Map && raw['name'] is String) {
          unreadableNames.add(raw['name'] as String);
        }
      }
    } else {
      _rawUnreadable = const [];
    }

    var allWritesOk = true;
    for (final cluster in clusters) {
      currentNames.add(cluster.name);
      final ok = await _storage.saveClusterSecrets(
        cluster.name,
        _extractSecrets(cluster),
      );
      if (!ok) {
        allWritesOk = false;
      }
    }

    // Clean up removed/renamed clusters from secure storage only when every
    // write succeeded, and never delete secrets for unreadable raw entries.
    if (allWritesOk) {
      for (final oldProfile in oldReadableProfiles) {
        if (!currentNames.contains(oldProfile.name) &&
            !unreadableNames.contains(oldProfile.name)) {
          await _storage.deleteClusterSecrets(oldProfile.name);
        }
      }
    }

    // The Rust codec owns the field set, so a profile field added later is
    // persisted without touching Dart. Never write secrets into preferences.
    final encoded = <String>[];
    for (final cluster in clusters) {
      encoded.add(await serializeClusterProfile(profile: cluster.sanitized()));
    }
    for (final raw in _rawUnreadable) {
      encoded.add(jsonEncode(raw));
    }
    await prefs.setString(_storageKey, '[${encoded.join(',')}]');
    if (allWritesOk) {
      await prefs.setBool(_migratedKey, true);
    }

    _updateStatus(clusters, _rawUnreadable);
    await _syncSharedProfiles(clusters);
    return allWritesOk;
  }
}

extension ClusterProfileExtension on ClusterProfile {
  ClusterProfile sanitized() {
    return ClusterProfile(
      name: name,
      bootstrapServers: bootstrapServers,
      saslUsername: saslUsername,
      saslPassword: null,
      mechanism: mechanism,
      securityProtocol: securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation,
      sslKeystorePassword: null,
      sslTruststoreLocation: sslTruststoreLocation,
      sslTruststorePassword: null,
      schemaRegistryUsername: schemaRegistryUsername,
      schemaRegistryPassword: null,
      saslKerberosServiceName: saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab,
      saslKerberosPrincipal: saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf,
      saslOauthbearerToken: null,
      sslPemCertificateLocation: sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation,
      sslPemKeyPassword: null,
      tlsVerification: tlsVerification,
      environmentLabel: environmentLabel,
      environmentColor: environmentColor,
      extraProperties: extraProperties,
      headlessShared: headlessShared,
    );
  }

  ClusterProfile withSecrets(Map<String, String?> secrets) {
    return ClusterProfile(
      name: name,
      bootstrapServers: bootstrapServers,
      saslUsername: saslUsername,
      saslPassword: secrets['saslPassword'] ?? saslPassword,
      mechanism: mechanism,
      securityProtocol: securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation,
      sslKeystorePassword:
          secrets['sslKeystorePassword'] ?? sslKeystorePassword,
      sslTruststoreLocation: sslTruststoreLocation,
      sslTruststorePassword:
          secrets['sslTruststorePassword'] ?? sslTruststorePassword,
      schemaRegistryUsername: schemaRegistryUsername,
      schemaRegistryPassword:
          secrets['schemaRegistryPassword'] ?? schemaRegistryPassword,
      saslKerberosServiceName: saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab,
      saslKerberosPrincipal: saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf,
      saslOauthbearerToken:
          secrets['saslOauthbearerToken'] ?? saslOauthbearerToken,
      sslPemCertificateLocation: sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation,
      sslPemKeyPassword: secrets['sslPemKeyPassword'] ?? sslPemKeyPassword,
      tlsVerification: tlsVerification,
      environmentLabel: environmentLabel,
      environmentColor: environmentColor,
      extraProperties: extraProperties,
      headlessShared: headlessShared,
    );
  }

  ClusterProfile copyWith({
    String? name,
    String? bootstrapServers,
    String? saslUsername,
    String? saslPassword,
    String? mechanism,
    String? securityProtocol,
    String? schemaRegistryUrl,
    String? sslKeystoreLocation,
    String? sslKeystorePassword,
    String? sslTruststoreLocation,
    String? sslTruststorePassword,
    String? schemaRegistryUsername,
    String? schemaRegistryPassword,
    String? saslKerberosServiceName,
    String? saslKerberosKeytab,
    String? saslKerberosPrincipal,
    String? saslKerberosConf,
    String? saslOauthbearerToken,
    String? sslPemCertificateLocation,
    String? sslPemKeyLocation,
    String? sslPemKeyPassword,
    TlsVerification? tlsVerification,
    String? environmentLabel,
    String? environmentColor,
    String? extraProperties,
    Object? headlessShared = _copyWithUnset,
  }) {
    return ClusterProfile(
      name: name ?? this.name,
      bootstrapServers: bootstrapServers ?? this.bootstrapServers,
      saslUsername: saslUsername ?? this.saslUsername,
      saslPassword: saslPassword ?? this.saslPassword,
      mechanism: mechanism ?? this.mechanism,
      securityProtocol: securityProtocol ?? this.securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl ?? this.schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation ?? this.sslKeystoreLocation,
      sslKeystorePassword: sslKeystorePassword ?? this.sslKeystorePassword,
      sslTruststoreLocation:
          sslTruststoreLocation ?? this.sslTruststoreLocation,
      sslTruststorePassword:
          sslTruststorePassword ?? this.sslTruststorePassword,
      schemaRegistryUsername:
          schemaRegistryUsername ?? this.schemaRegistryUsername,
      schemaRegistryPassword:
          schemaRegistryPassword ?? this.schemaRegistryPassword,
      saslKerberosServiceName:
          saslKerberosServiceName ?? this.saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab ?? this.saslKerberosKeytab,
      saslKerberosPrincipal:
          saslKerberosPrincipal ?? this.saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf ?? this.saslKerberosConf,
      saslOauthbearerToken: saslOauthbearerToken ?? this.saslOauthbearerToken,
      sslPemCertificateLocation:
          sslPemCertificateLocation ?? this.sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation ?? this.sslPemKeyLocation,
      sslPemKeyPassword: sslPemKeyPassword ?? this.sslPemKeyPassword,
      tlsVerification: tlsVerification ?? this.tlsVerification,
      environmentLabel: environmentLabel ?? this.environmentLabel,
      environmentColor: environmentColor ?? this.environmentColor,
      extraProperties: extraProperties ?? this.extraProperties,
      headlessShared: identical(headlessShared, _copyWithUnset)
          ? this.headlessShared
          : headlessShared as bool?,
    );
  }
}

/// Suggests a unique profile copy name for duplicating [sourceName].
///
/// Produces `"{sourceName} (copy)"`, then `"{sourceName} (copy 2)"`, `3`, ...
/// matching case-insensitively against [existingNames] via [normalizeProfileName].
String suggestCopyName(String sourceName, Iterable<String> existingNames) {
  final used = existingNames.map(normalizeProfileName).toSet();
  final base = sourceName.trim();
  final first = '$base (copy)';
  if (!used.contains(normalizeProfileName(first))) {
    return first;
  }
  var n = 2;
  while (true) {
    final candidate = '$base (copy $n)';
    if (!used.contains(normalizeProfileName(candidate))) {
      return candidate;
    }
    n++;
  }
}

/// Returns true when [profile] matches [query] case-insensitively across
/// profile name, environment label, or bootstrap servers.
bool matchesClusterFilter(ClusterProfile profile, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  if (profile.name.toLowerCase().contains(needle)) return true;
  if ((profile.environmentLabel ?? '').toLowerCase().contains(needle)) {
    return true;
  }
  if (profile.bootstrapServers.toLowerCase().contains(needle)) return true;
  return false;
}
