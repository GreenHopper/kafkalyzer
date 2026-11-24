import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/diff/json_diff_batcher.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:mockito/mockito.dart';

import '../../rust/api/rust_mocks.mocks.dart';

JsonDiffResult _emptyResult(int marker) => JsonDiffResult(
  entries: const [],
  total: marker,
  hidden: 0,
  truncated: false,
  invalidSide: null,
);

void main() {
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    reset(mockApi);
  });

  test('three requests in one turn coalesce into one bridge call', () async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenAnswer((invocation) async {
      final reqs =
          invocation.namedArguments[#requests] as List<JsonDiffRequest>;
      return List.generate(reqs.length, _emptyResult);
    });

    final batcher = JsonDiffBatcher();
    final f1 = batcher.enqueue(
      const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
    );
    final f2 = batcher.enqueue(
      const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
    );
    final f3 = batcher.enqueue(
      const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
    );

    final results = await Future.wait([f1, f2, f3]);
    expect(results.map((r) => r.total).toList(), [0, 1, 2]);
    verify(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: argThat(hasLength(3), named: 'requests'),
        maxEntries: null,
      ),
    ).called(1);
  });

  test(
    '60 requests in one turn split into two bridge calls (50 + 10)',
    () async {
      final batchSizes = <int>[];
      when(
        mockApi.crateApiJsonDiffDiffJsonBatch(
          requests: anyNamed('requests'),
          maxEntries: anyNamed('maxEntries'),
        ),
      ).thenAnswer((invocation) async {
        final reqs =
            invocation.namedArguments[#requests] as List<JsonDiffRequest>;
        batchSizes.add(reqs.length);
        return List.generate(reqs.length, _emptyResult);
      });

      final batcher = JsonDiffBatcher();
      final futures = List.generate(
        60,
        (_) => batcher.enqueue(
          const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
          maxEntries: 2000,
        ),
      );

      final results = await Future.wait(futures);
      expect(results, hasLength(60));
      expect(batchSizes, [50, 10]);
    },
  );

  test('a throwing bridge call fails all its futures', () async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenThrow(StateError('bridge failure'));

    final batcher = JsonDiffBatcher();
    final f1 = batcher.enqueue(
      const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
    );
    final f2 = batcher.enqueue(
      const JsonDiffRequest(oldJson: '{}', newJson: '{}', ignorePaths: []),
    );

    await expectLater(f1, throwsStateError);
    await expectLater(f2, throwsStateError);
  });
}
