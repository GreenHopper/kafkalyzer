import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:path/path.dart' as p;

void main() {
  group('parseStoredList', () {
    test(
      'parses valid entries and preserves unreadable ones verbatim',
      () async {
        final raw = jsonEncode([
          {'name': 'one'},
          'corrupt-entry',
          {'name': 'two'},
        ]);

        final result = await parseStoredList<String>(raw, (entry) async {
          if (entry is Map && entry['name'] is String) {
            return entry['name'] as String;
          }
          throw const FormatException('Invalid entry');
        });

        expect(result.storeUnreadable, isFalse);
        expect(result.items, ['one', 'two']);
        expect(result.rawUnreadable, ['corrupt-entry']);
      },
    );

    test(
      'flags storeUnreadable when top level is invalid JSON or not a list',
      () async {
        final truncated = await parseStoredList<String>(
          '[{"name": "a"',
          (entry) async => entry.toString(),
        );
        expect(truncated.storeUnreadable, isTrue);

        final notAList = await parseStoredList<String>(
          '{"not": "a list"}',
          (entry) async => entry.toString(),
        );
        expect(notAList.storeUnreadable, isTrue);
      },
    );
  });

  group('writeStoreBackup', () {
    test('writes raw content to backups directory and returns path', () async {
      final tempDir = Directory.systemTemp.createTempSync('kafkalyzer_backup_');
      try {
        final raw = '[{"broken';
        final path = await writeStoreBackup(
          'cluster_profiles',
          raw,
          supportDirProvider: () async => tempDir,
        );

        expect(path, isNotNull);
        expect(p.isWithin(p.join(tempDir.path, 'backups'), path!), isTrue);
        expect(File(path).readAsStringSync(), raw);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns null when backup write fails', () async {
      final path = await writeStoreBackup(
        'cluster_profiles',
        'raw',
        supportDirProvider: () async =>
            throw const FileSystemException('denied'),
      );
      expect(path, isNull);
    });
  });
}
