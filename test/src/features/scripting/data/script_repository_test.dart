import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const storageKey = 'saved_scripts_v1';

  Script makeScript(String id, String name) => Script(id: id, name: name);

  group('ScriptRepository', () {
    test('returns empty list when store is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ScriptRepository();

      expect(await repo.getScripts(), isEmpty);
      expect(repo.storeStatus.isOk, isTrue);
    });

    test(
      'preserves unreadable entries verbatim across save and delete',
      () async {
        final good = makeScript('s1', 'good-script').toJson();
        final badEntry = {'id': 'corrupt', 'name': 12345};
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode([good, badEntry]),
        });

        final repo = ScriptRepository();
        final scripts = await repo.getScripts();
        expect(scripts.map((s) => s.id), ['s1']);
        expect(repo.storeStatus.health, StoreHealth.partiallyUnreadable);
        expect(repo.storeStatus.unreadableCount, 1);

        await repo.saveScript(makeScript('s2', 'second-script'));
        final prefs = await SharedPreferences.getInstance();
        final afterSave = jsonDecode(prefs.getString(storageKey)!) as List;
        expect(afterSave, hasLength(3));
        expect(afterSave.last, badEntry);

        await repo.deleteScript('s1');
        final afterDelete = jsonDecode(prefs.getString(storageKey)!) as List;
        expect(afterDelete, hasLength(2));
        expect(afterDelete.last, badEntry);
      },
    );

    test(
      'throws StoredDataUnreadableException on corrupt store and writes backup without overwriting store',
      () async {
        const corruptRaw = '{not valid json';
        SharedPreferences.setMockInitialValues({storageKey: corruptRaw});

        final repo = ScriptRepository();

        await expectLater(
          repo.getScripts(),
          throwsA(isA<StoredDataUnreadableException>()),
        );
        expect(repo.storeStatus.isUnreadable, isTrue);
        if (repo.storeStatus.backupPath != null) {
          final backupFile = File(repo.storeStatus.backupPath!);
          expect(backupFile.readAsStringSync(), corruptRaw);
          addTearDown(() async {
            if (await backupFile.exists()) {
              await backupFile.delete();
            }
          });
        }

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(storageKey), corruptRaw);

        // discardUnreadable clears the corrupt store and resets status.
        await repo.discardUnreadable();
        expect(repo.storeStatus.isOk, isTrue);
        expect(prefs.getString(storageKey), isNull);
        expect(await repo.getScripts(), isEmpty);
      },
    );
  });
}
