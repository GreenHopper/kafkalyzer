import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocalSchemaSide { key, value }

enum LocalSchemaAssignmentState {
  usable,
  fileNotFound,
  fileUnreadable,
  schemaInvalid,
  messageTypeMissing,
  changed,
  unknown,
}

class LocalSchemaStateResult {
  final LocalSchemaAssignmentState state;
  final LocalSchemaInfo? info;
  final LocalSchemaErrorDto? error;

  const LocalSchemaStateResult({required this.state, this.info, this.error});
}

class StoredTopicLocalSchemas {
  final LocalSchemaAssignmentDto? key;
  final LocalSchemaAssignmentDto? value;
  final bool unreadable;
  final String? unreadableReason;

  const StoredTopicLocalSchemas({
    this.key,
    this.value,
    this.unreadable = false,
    this.unreadableReason,
  });

  bool get hasAny => key != null || value != null;

  LocalSchemaAssignmentDto? forSide(LocalSchemaSide side) =>
      side == LocalSchemaSide.key ? key : value;
}

typedef InspectLocalSchemaFn =
    Future<LocalSchemaInfo> Function({
      required String path,
      LocalSchemaFormatDto? format,
      String? messageType,
    });

class LocalSchemaAssignmentService extends ChangeNotifier {
  static const String _keyPrefix = 'local_schema_assignments_';

  final Future<SharedPreferences> Function() _prefsProvider;
  final InspectLocalSchemaFn _inspect;
  final Map<String, LocalSchemaStateResult> _stateCache = {};

  LocalSchemaAssignmentService({
    SharedPreferences? prefs,
    Future<SharedPreferences> Function()? prefsProvider,
    InspectLocalSchemaFn? inspectFn,
  }) : _prefsProvider =
           prefsProvider ??
           (prefs != null ? () async => prefs : SharedPreferences.getInstance),
       _inspect = inspectFn ?? inspectLocalSchema;

  static String storageKey(String clusterId, String topic) =>
      '$_keyPrefix${clusterId}_$topic';

  static String _cacheKey(
    String clusterId,
    String topic,
    LocalSchemaSide side,
  ) => '${storageKey(clusterId, topic)}:${side.name}';

  Future<StoredTopicLocalSchemas> getForTopic(
    String clusterId,
    String topic,
  ) async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(storageKey(clusterId, topic));
    if (raw == null || raw.trim().isEmpty) {
      return const StoredTopicLocalSchemas();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const StoredTopicLocalSchemas(
          unreadable: true,
          unreadableReason: 'Expected JSON object',
        );
      }
      final keyJson = decoded['key'];
      final valJson = decoded['value'];
      final keyDto = keyJson == null
          ? null
          : _assignmentFromJson(keyJson as Map<String, dynamic>);
      final valDto = valJson == null
          ? null
          : _assignmentFromJson(valJson as Map<String, dynamic>);
      return StoredTopicLocalSchemas(key: keyDto, value: valDto);
    } catch (e) {
      return StoredTopicLocalSchemas(
        unreadable: true,
        unreadableReason: e.toString(),
      );
    }
  }

  Future<void> saveSide(
    String clusterId,
    String topic,
    LocalSchemaSide side,
    LocalSchemaAssignmentDto assignment,
  ) async {
    final existing = await getForTopic(clusterId, topic);
    final nextKey = side == LocalSchemaSide.key
        ? assignment
        : (existing.unreadable ? null : existing.key);
    final nextVal = side == LocalSchemaSide.value
        ? assignment
        : (existing.unreadable ? null : existing.value);
    await _writeTopic(clusterId, topic, nextKey, nextVal);
    _stateCache.remove(_cacheKey(clusterId, topic, side));
    notifyListeners();
  }

  Future<void> removeSide(
    String clusterId,
    String topic,
    LocalSchemaSide side,
  ) async {
    final existing = await getForTopic(clusterId, topic);
    if (existing.unreadable) {
      final prefs = await _prefsProvider();
      await prefs.remove(storageKey(clusterId, topic));
      _stateCache.remove(_cacheKey(clusterId, topic, LocalSchemaSide.key));
      _stateCache.remove(_cacheKey(clusterId, topic, LocalSchemaSide.value));
      notifyListeners();
      return;
    }
    final nextKey = side == LocalSchemaSide.key ? null : existing.key;
    final nextVal = side == LocalSchemaSide.value ? null : existing.value;
    await _writeTopic(clusterId, topic, nextKey, nextVal);
    _stateCache.remove(_cacheKey(clusterId, topic, side));
    notifyListeners();
  }

  Future<void> _writeTopic(
    String clusterId,
    String topic,
    LocalSchemaAssignmentDto? key,
    LocalSchemaAssignmentDto? value,
  ) async {
    final prefs = await _prefsProvider();
    final storage = storageKey(clusterId, topic);
    if (key == null && value == null) {
      await prefs.remove(storage);
      return;
    }
    final payload = <String, dynamic>{
      if (key != null) 'key': _assignmentToJson(key),
      if (value != null) 'value': _assignmentToJson(value),
    };
    await prefs.setString(storage, jsonEncode(payload));
  }

  Future<TopicLocalSchemasDto?> scanOptionsFor(
    String clusterId,
    String topic,
  ) async {
    final stored = await getForTopic(clusterId, topic);
    if (stored.unreadable || !stored.hasAny) {
      return null;
    }
    return TopicLocalSchemasDto(key: stored.key, value: stored.value);
  }

  void invalidateStateCache(
    String clusterId,
    String topic, [
    LocalSchemaSide? side,
  ]) {
    if (side != null) {
      _stateCache.remove(_cacheKey(clusterId, topic, side));
    } else {
      _stateCache.remove(_cacheKey(clusterId, topic, LocalSchemaSide.key));
      _stateCache.remove(_cacheKey(clusterId, topic, LocalSchemaSide.value));
    }
  }

  Future<LocalSchemaStateResult> stateFor(
    String clusterId,
    String topic,
    LocalSchemaSide side, {
    bool refresh = false,
  }) async {
    final cKey = _cacheKey(clusterId, topic, side);
    if (!refresh && _stateCache.containsKey(cKey)) {
      return _stateCache[cKey]!;
    }
    final stored = await getForTopic(clusterId, topic);
    final assignment = stored.forSide(side);
    if (assignment == null) {
      const res = LocalSchemaStateResult(
        state: LocalSchemaAssignmentState.unknown,
      );
      _stateCache[cKey] = res;
      return res;
    }
    try {
      final info = await _inspect(
        path: assignment.path,
        format: assignment.format,
        messageType: assignment.messageType,
      );
      final res = _classifyInfo(assignment, info);
      _stateCache[cKey] = res;
      return res;
    } catch (_) {
      const res = LocalSchemaStateResult(
        state: LocalSchemaAssignmentState.unknown,
      );
      _stateCache[cKey] = res;
      return res;
    }
  }

  Future<void> confirmChanged(
    String clusterId,
    String topic,
    LocalSchemaSide side,
  ) async {
    final stored = await getForTopic(clusterId, topic);
    final assignment = stored.forSide(side);
    if (assignment == null) return;
    final stateRes = await stateFor(clusterId, topic, side, refresh: true);
    final newSha = stateRes.info?.sha256Hex;
    if (stateRes.info?.error != null || newSha == null) {
      return;
    }
    final updated = LocalSchemaAssignmentDto(
      path: assignment.path,
      format: assignment.format,
      messageType: assignment.messageType,
      framing: assignment.framing,
      mode: assignment.mode,
      expectedSha256: newSha,
    );
    await saveSide(clusterId, topic, side, updated);
  }

  LocalSchemaStateResult _classifyInfo(
    LocalSchemaAssignmentDto assignment,
    LocalSchemaInfo info,
  ) {
    final err = info.error;
    if (err != null) {
      final state = switch (err.kind) {
        LocalDecodeErrorKindDto.fileNotFound =>
          LocalSchemaAssignmentState.fileNotFound,
        LocalDecodeErrorKindDto.fileUnreadable ||
        LocalDecodeErrorKindDto.fileTooLarge =>
          LocalSchemaAssignmentState.fileUnreadable,
        LocalDecodeErrorKindDto.messageTypeNotFound =>
          LocalSchemaAssignmentState.messageTypeMissing,
        LocalDecodeErrorKindDto.schemaInvalid ||
        LocalDecodeErrorKindDto.unsupportedProto2 ||
        LocalDecodeErrorKindDto.unresolvedImport =>
          LocalSchemaAssignmentState.schemaInvalid,
        _ => LocalSchemaAssignmentState.schemaInvalid,
      };
      return LocalSchemaStateResult(state: state, info: info, error: err);
    }
    if (assignment.expectedSha256 != null &&
        info.sha256Hex != null &&
        assignment.expectedSha256 != info.sha256Hex) {
      return LocalSchemaStateResult(
        state: LocalSchemaAssignmentState.changed,
        info: info,
      );
    }
    return LocalSchemaStateResult(
      state: LocalSchemaAssignmentState.usable,
      info: info,
    );
  }

  static Map<String, dynamic> _assignmentToJson(LocalSchemaAssignmentDto a) => {
    'path': a.path,
    'format': a.format.name,
    if (a.messageType != null) 'messageType': a.messageType,
    'framing': a.framing.name,
    'mode': a.mode.name,
    if (a.expectedSha256 != null) 'expectedSha256': a.expectedSha256,
  };

  static LocalSchemaAssignmentDto _assignmentFromJson(Map<String, dynamic> m) {
    final path = m['path'] as String;
    final format = LocalSchemaFormatDto.values.byName(m['format'] as String);
    final framing = m['framing'] != null
        ? FramingDto.values.byName(m['framing'] as String)
        : FramingDto.auto;
    final mode = m['mode'] != null
        ? LocalSchemaModeDto.values.byName(m['mode'] as String)
        : LocalSchemaModeDto.fallback;
    return LocalSchemaAssignmentDto(
      path: path,
      format: format,
      messageType: m['messageType'] as String?,
      framing: framing,
      mode: mode,
      expectedSha256: m['expectedSha256'] as String?,
    );
  }
}
