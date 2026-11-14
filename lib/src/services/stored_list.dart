import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of parsing a JSON-list preference store entry by entry.
class StoredListParse<T> {
  final List<T> items;
  final List<dynamic> rawUnreadable;
  final bool storeUnreadable;

  const StoredListParse({
    required this.items,
    required this.rawUnreadable,
    required this.storeUnreadable,
  });
}

/// Thrown when a preference store's top-level value is not a readable JSON
/// list, or when a mutation is attempted while the store is in that state.
class StoredDataUnreadableException implements Exception {
  final String store;
  final String? backupPath;
  final Object? cause;

  const StoredDataUnreadableException(
    this.store, {
    this.backupPath,
    this.cause,
  });

  @override
  String toString() =>
      'Stored data unreadable for $store'
      '${backupPath != null ? ' (backup: $backupPath)' : ''}';
}

enum StoreHealth { ok, partiallyUnreadable, unreadable }

/// Observable health state of a stored list (profiles or scripts).
class StoreStatus {
  final StoreHealth health;
  final int unreadableCount;
  final String? backupPath;
  final List<String> duplicateNames;

  const StoreStatus.ok({this.duplicateNames = const []})
    : health = StoreHealth.ok,
      unreadableCount = 0,
      backupPath = null;

  const StoreStatus.partiallyUnreadable(
    this.unreadableCount, {
    this.duplicateNames = const [],
  }) : health = StoreHealth.partiallyUnreadable,
       backupPath = null;

  const StoreStatus.unreadable(this.backupPath)
    : health = StoreHealth.unreadable,
      unreadableCount = 0,
      duplicateNames = const [];

  bool get isUnreadable => health == StoreHealth.unreadable;
  bool get isPartiallyUnreadable => health == StoreHealth.partiallyUnreadable;
  bool get hasDuplicates => duplicateNames.isNotEmpty;
  bool get isOk => health == StoreHealth.ok && duplicateNames.isEmpty;
}

/// Decodes [rawJson] as a JSON list and parses each element via [parseEntry].
///
/// Elements that fail to parse are preserved verbatim in [StoredListParse.rawUnreadable].
/// If [rawJson] is not valid JSON or does not decode to a JSON list,
/// [StoredListParse.storeUnreadable] is `true`.
Future<StoredListParse<T>> parseStoredList<T>(
  String? rawJson,
  Future<T> Function(dynamic entry) parseEntry,
) async {
  if (rawJson == null) {
    return StoredListParse<T>(
      items: const [],
      rawUnreadable: const [],
      storeUnreadable: false,
    );
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(rawJson);
  } catch (_) {
    return StoredListParse<T>(
      items: const [],
      rawUnreadable: const [],
      storeUnreadable: true,
    );
  }

  if (decoded is! List) {
    return StoredListParse<T>(
      items: const [],
      rawUnreadable: const [],
      storeUnreadable: true,
    );
  }

  final items = <T>[];
  final rawUnreadable = <dynamic>[];
  for (final entry in decoded) {
    try {
      items.add(await parseEntry(entry));
    } catch (_) {
      rawUnreadable.add(entry);
    }
  }

  return StoredListParse<T>(
    items: items,
    rawUnreadable: rawUnreadable,
    storeUnreadable: false,
  );
}

/// Writes [rawContent] to `<applicationSupportDir>/backups/<key>-<yyyyMMdd-HHmmss>.json`.
///
/// Returns the backup file path on success, or `null` if writing fails.
Future<String?> writeStoreBackup(
  String key,
  String rawContent, {
  Future<Directory> Function()? supportDirProvider,
}) async {
  try {
    final supportDir = supportDirProvider != null
        ? await supportDirProvider()
        : await getApplicationSupportDirectory();
    final backupsDir = Directory(p.join(supportDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final file = File(p.join(backupsDir.path, '$key-$stamp.json'));
    await file.writeAsString(rawContent);
    return file.path;
  } catch (_) {
    return null;
  }
}
