import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Service managing sensitive credentials in the native OS keyring
/// with cluster-scoped keys and graceful fallback for headless/CI environments.
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Logger _logger;
  final Map<String, String> _inMemoryFallback = {};
  bool _useFallback = false;

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
  Future<void> write(String key, String value) async {
    if (_useFallback) {
      _inMemoryFallback[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      _logger.w(
        'Failed to write to OS keyring. Falling back to in-memory storage.',
        error: e,
      );
      _useFallback = true;
      _inMemoryFallback[key] = value;
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
      _useFallback = true;
      return _inMemoryFallback[key];
    }
  }

  /// Deletes a secret from the OS keyring.
  Future<void> delete(String key) async {
    if (_useFallback) {
      _inMemoryFallback.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      _logger.w('Failed to delete from OS keyring.', error: e);
      _inMemoryFallback.remove(key);
    }
  }

  /// Stores all non-empty sensitive fields of a cluster profile into the keyring.
  Future<void> saveClusterSecrets(
    String clusterName,
    Map<String, String?> secrets,
  ) async {
    for (final field in secretFields) {
      final val = secrets[field];
      final key = _buildKey(clusterName, field);
      if (val != null && val.isNotEmpty) {
        await write(key, val);
      } else {
        await delete(key);
      }
    }
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
