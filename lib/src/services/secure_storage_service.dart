import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Service managing sensitive credentials in the native OS keyring
/// with cluster-scoped keys and graceful fallback for headless/CI environments.
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Logger _logger;
  final Map<String, String> _inMemoryFallback = {};
  bool _useFallback = false;

  /// Becomes `true` on the first OS keyring read/write/delete failure and stays
  /// `true` for the rest of the session.
  final ValueNotifier<bool> unavailable = ValueNotifier<bool>(false);

  /// Whether the OS keyring is still available (no fallback triggered).
  bool get isAvailable => !unavailable.value;

  void _markUnavailable() {
    _useFallback = true;
    if (!unavailable.value) {
      unavailable.value = true;
    }
  }

  static const List<String> secretFields = [
    'saslPassword',
    'schemaRegistryPassword',
    'sslKeystorePassword',
    'sslTruststorePassword',
    'sslPemKeyPassword',
    'saslOauthbearerToken',
  ];

  SecureStorageService({FlutterSecureStorage? storage, Logger? logger})
    : _storage = storage ?? const FlutterSecureStorage(),
      _logger = logger ?? Logger();

  String _buildKey(String clusterName, String field) =>
      'cluster_${clusterName}_$field';

  /// Writes a secret value for a given key to the OS keyring.
  /// Returns `true` if the write reached the OS keyring, `false` on fallback.
  Future<bool> write(String key, String value) async {
    if (_useFallback) {
      _inMemoryFallback[key] = value;
      return false;
    }
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      _logger.w(
        'Failed to write to OS keyring. Falling back to in-memory storage.',
        error: e,
      );
      _markUnavailable();
      _inMemoryFallback[key] = value;
      return false;
    }
  }

  /// Reads a secret value for a given key from the OS keyring.
  Future<String?> read(String key) async {
    if (_useFallback) {
      return _inMemoryFallback[key];
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      _logger.w(
        'Failed to read from OS keyring. Falling back to in-memory storage.',
        error: e,
      );
      _markUnavailable();
      return _inMemoryFallback[key];
    }
  }

  /// Deletes a secret from the OS keyring.
  /// Returns `true` if the delete reached the OS keyring, `false` on fallback.
  Future<bool> delete(String key) async {
    if (_useFallback) {
      _inMemoryFallback.remove(key);
      return false;
    }
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      _logger.w('Failed to delete from OS keyring.', error: e);
      _markUnavailable();
      _inMemoryFallback.remove(key);
      return false;
    }
  }

  /// Stores all non-empty sensitive fields of a cluster profile into the keyring.
  /// Returns `true` only if every write and delete operation reached the keyring.
  Future<bool> saveClusterSecrets(
    String clusterName,
    Map<String, String?> secrets,
  ) async {
    var allSucceeded = true;
    for (final field in secretFields) {
      final val = secrets[field];
      final key = _buildKey(clusterName, field);
      final ok = (val != null && val.isNotEmpty)
          ? await write(key, val)
          : await delete(key);
      if (!ok) {
        allSucceeded = false;
      }
    }
    return allSucceeded;
  }

  /// Retrieves all sensitive fields of a cluster profile from the keyring.
  Future<Map<String, String?>> getClusterSecrets(String clusterName) async {
    final result = <String, String?>{};
    for (final field in secretFields) {
      final key = _buildKey(clusterName, field);
      result[field] = await read(key);
    }
    return result;
  }

  /// Cleans up all sensitive fields for a deleted cluster.
  Future<void> deleteClusterSecrets(String clusterName) async {
    for (final field in secretFields) {
      final key = _buildKey(clusterName, field);
      await delete(key);
    }
  }
}
