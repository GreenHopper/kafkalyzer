import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:path/path.dart' as p;

void main() {
  const rootDir = '/tmp/kafkalyzer_target';

  group('safeArchiveTarget', () {
    test('rejects unsafe paths', () {
      const unsafeEntries = [
        '../x',
        'a/../../x',
        r'..\x',
        '/etc/x',
        r'\x',
        r'C:\x',
        'C:x',
        r'\\server\share\x',
        '',
        'foo\x00bar',
        '.',
        '..',
        './',
      ];

      for (final entry in unsafeEntries) {
        expect(
          safeArchiveTarget(rootDir, entry),
          isNull,
          reason: 'Expected "$entry" to be rejected',
        );
      }
    });

    test('accepts valid relative and nested paths', () {
      expect(
        safeArchiveTarget(rootDir, 'files/a.jks'),
        equals(p.normalize(p.join(rootDir, 'files', 'a.jks'))),
      );
      expect(
        safeArchiveTarget(rootDir, 'step1/out.json'),
        equals(p.normalize(p.join(rootDir, 'step1', 'out.json'))),
      );
    });
  });

  group('isSafePathSegment', () {
    test('rejects traversal, separators, empty, dots, and control chars', () {
      expect(isSafePathSegment(''), isFalse);
      expect(isSafePathSegment('.'), isFalse);
      expect(isSafePathSegment('..'), isFalse);
      expect(isSafePathSegment('a/b'), isFalse);
      expect(isSafePathSegment(r'a\b'), isFalse);
      expect(isSafePathSegment('../../outside'), isFalse);
      expect(isSafePathSegment('C:foo'), isFalse);
      expect(isSafePathSegment('foo\x00bar'), isFalse);
      expect(isSafePathSegment('foo\nbar'), isFalse);
    });

    test('accepts valid single segments', () {
      expect(isSafePathSegment('My_Test_Script_12345'), isTrue);
      expect(isSafePathSegment('run-2026-11-14'), isTrue);
    });
  });

  group('safePathSegment', () {
    test('sanitizes unsafe names and preserves safe ones', () {
      expect(safePathSegment('..'), equals('_'));
      expect(safePathSegment('.'), equals('_'));
      expect(safePathSegment(''), equals('_'));
      expect(safePathSegment('a/b'), equals('a_b'));
      expect(safePathSegment('name. '), equals('name'));
      expect(safePathSegment('CON'), equals('_CON'));
      expect(safePathSegment('con.txt'), equals('_con.txt'));
      expect(safePathSegment('My Test Script'), equals('My_Test_Script'));
    });
  });

  group('planArchiveExtraction', () {
    test('rejects symlink entries', () {
      final archive = Archive()
        ..addFile(ArchiveFile.symlink('link', '/etc/passwd'));

      expect(
        () => planArchiveExtraction(archive, rootDir),
        throwsA(isA<UnsafeArchiveEntryException>()),
      );
    });

    test(
      'checks directory entries and ignored entries and throws before returning plan',
      () {
        final bytes = utf8.encode('ok');
        final archive = Archive()
          ..addFile(ArchiveFile('files/good.jks', bytes.length, bytes))
          ..addFile(ArchiveFile.directory('step1/'))
          ..addFile(ArchiveFile('ignored/ok.txt', bytes.length, bytes))
          ..addFile(ArchiveFile('../evil.txt', bytes.length, bytes));

        expect(
          () => planArchiveExtraction(
            archive,
            rootDir,
            select: (name) => name.startsWith('files/'),
          ),
          throwsA(
            isA<UnsafeArchiveEntryException>().having(
              (e) => e.entryName,
              'entryName',
              '../evil.txt',
            ),
          ),
        );

        final badDirArchive = Archive()
          ..addFile(ArchiveFile('files/good.jks', bytes.length, bytes))
          ..addFile(ArchiveFile.directory('../../bad_dir/'));

        expect(
          () => planArchiveExtraction(badDirArchive, rootDir),
          throwsA(isA<UnsafeArchiveEntryException>()),
        );
      },
    );

    test('plans valid entries', () {
      final bytes = utf8.encode('ok');
      final archive = Archive()
        ..addFile(ArchiveFile('files/a.jks', bytes.length, bytes))
        ..addFile(ArchiveFile('step1/out.json', bytes.length, bytes));

      final plan = planArchiveExtraction(archive, rootDir);
      expect(plan.length, equals(2));
      expect(
        plan.values,
        containsAll([
          p.normalize(p.join(rootDir, 'files', 'a.jks')),
          p.normalize(p.join(rootDir, 'step1', 'out.json')),
        ]),
      );
    });
  });
}
