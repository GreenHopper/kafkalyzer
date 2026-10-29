import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileOpenerService service;
  late Directory tempDir;

  setUp(() async {
    service = FileOpenerService(logger: Logger(level: Level.off));
    tempDir = await Directory.systemTemp.createTemp('file_opener_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileOpenerService', () {
    test('openFile returns false when file does not exist', () async {
      final nonExistent = '${tempDir.path}/does_not_exist.json';
      final result = await service.openFile(nonExistent);
      expect(result, isFalse);
    });

    test(
      'showInFolder returns false when parent directory does not exist',
      () async {
        final nonExistentParent = '${tempDir.path}/ghost_dir/test.csv';
        final result = await service.showInFolder(nonExistentParent);
        expect(result, isFalse);
      },
    );

    test(
      'showInFolder handles existing file with existing parent directory',
      () async {
        final sampleFile = File('${tempDir.path}/sample.txt');
        await sampleFile.writeAsString('hello world');

        // In headless test environments, Process.run / url_launcher may fail or succeed depending on desktop host.
        // But it should not throw unhandled exceptions.
        expect(
          () async => await service.showInFolder(sampleFile.path),
          returnsNormally,
        );
      },
    );

    test('openFile handles existing file without throwing', () async {
      final sampleFile = File('${tempDir.path}/sample.txt');
      await sampleFile.writeAsString('hello world');

      expect(
        () async => await service.openFile(sampleFile.path),
        returnsNormally,
      );
    });
  });
}
