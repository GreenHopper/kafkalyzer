import 'dart:convert';
import 'dart:io';

import 'package:kafkalyzer/src/services/gcs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TestGcsService extends GcsService {
  final http.Client _mockClient;

  TestGcsService(this._mockClient);

  @override
  Future<http.Client?> getAuthClient() async {
    return _mockClient;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GcsService', () {
    test('listFiles returns list of files from GCS', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() ==
            'https://storage.googleapis.com/storage/v1/b/test-bucket/o?prefix=test-prefix&alt=json') {
          return http.Response(
            jsonEncode({
              'items': [
                {'name': 'test-prefix/file1.txt'},
                {'name': 'test-prefix/file2.json'},
                {'name': 'test-prefix/'}, // Folder should be ignored
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = TestGcsService(mockClient);
      final files = await service.listFiles('test-bucket', 'test-prefix');

      expect(files.length, 2);
      expect(files, contains('/test-prefix/file1.txt'));
      expect(files, contains('/test-prefix/file2.json'));
    });

    test('downloadFile downloads content to file', () async {
      // Create a temporary file
      final tempDir = Directory.systemTemp.createTempSync('gcs_test_');
      final savePath = '${tempDir.path}/downloaded.txt';
      final content = 'Hello GCS';

      final mockClient = MockClient((request) async {
        if (request.url.toString() ==
            'https://storage.googleapis.com/storage/v1/b/test-bucket/o/test-file.txt?alt=media') {
          return http.Response(
            content,
            200,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = TestGcsService(mockClient);
      await service.downloadFile('test-bucket', 'test-file.txt', savePath);

      final downloadedFile = File(savePath);
      expect(downloadedFile.existsSync(), isTrue);
      expect(downloadedFile.readAsStringSync(), content);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    test(
      'downloadFile builds correct url for object with leading slash',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('gcs_test_slash_');
        final savePath = '${tempDir.path}/downloaded.txt';

        final mockClient = MockClient((request) async {
          // Expects no double slash
          if (request.url.toString().contains('/test-file.txt?')) {
            return http.Response(
              'content',
              200,
              headers: {'content-type': 'text/plain; charset=utf-8'},
            );
          }
          return http.Response('Not Found ${request.url.toString()}', 404);
        });

        final service = TestGcsService(mockClient);
        // Pass object with leading slash
        await service.downloadFile('test-bucket', '/test-file.txt', savePath);

        expect(File(savePath).readAsStringSync(), 'content');
        tempDir.deleteSync(recursive: true);
      },
    );
  });
}
