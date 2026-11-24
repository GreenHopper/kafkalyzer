import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:mockito/mockito.dart';

import '../rust/api/rust_mocks.mocks.dart';

void main() {
  late MockKafkalyzerRustLibApi mockApi;

  setUpAll(() {
    mockApi = MockKafkalyzerRustLibApi();
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  test('ClusterProfileTools delegates all profile-tool calls', () async {
    when(
      mockApi.crateApiProfileToolsValidateBootstrapServers(value: ''),
    ).thenReturn(const [
      BootstrapServerIssue(entry: '', kind: BootstrapServerIssueKind.noEntries),
    ]);
    when(
      mockApi.crateApiProfileToolsValidateExtraProperties(text: 'x'),
    ).thenReturn([
      ExtraPropertyIssue(
        line: BigInt.one,
        key: 'x',
        kind: ExtraPropertyIssueKind.syntax,
      ),
    ]);
    when(mockApi.crateApiProfileToolsAllowedExtraProperties()).thenReturn(
      const [AllowedExtraProperty(key: 'client.id', valueHint: 'text')],
    );
    when(
      mockApi.crateApiProfileToolsParseClientProperties(content: 'a=b'),
    ).thenAnswer(
      (_) async => const ClientPropertiesPreview(
        profile: ClusterProfile(
          name: '',
          bootstrapServers: '',
          tlsVerification: TlsVerification.enabled,
        ),
        extraProperties: '',
        skipped: [],
      ),
    );

    const tools = ClusterProfileTools();
    expect(tools.validateBootstrapServers(''), hasLength(1));
    expect(tools.validateExtraProperties('x'), hasLength(1));
    expect(tools.allowedExtraProperties().first.key, 'client.id');
    final preview = await tools.parseClientProperties('a=b');
    expect(preview.extraProperties, '');

    // Top-level wrappers used by callers that skip the class.
    expect(rustValidateBootstrapServers(value: ''), hasLength(1));
    expect(rustValidateExtraProperties(text: 'x'), hasLength(1));
    expect(rustAllowedExtraProperties().first.key, 'client.id');
    expect(
      (await rustParseClientProperties(content: 'a=b')).extraProperties,
      '',
    );
  });
}
