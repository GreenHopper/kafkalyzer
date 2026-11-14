import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
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

  final fakeAgeBytes = Uint8List.fromList([
    ...utf8.encode('age-encryption.org/v1\n'),
    1,
    2,
    3,
  ]);

  test('plain ZIP and JSON bytes pass through without prompting', () async {
    var prompted = false;
    final zipBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2]);
    final jsonBytes = utf8.encode('[{"name":"local"}]');

    expect(
      await decryptIfEncrypted(zipBytes, ({
        required previousAttemptFailed,
      }) async {
        prompted = true;
        return 'ignored';
      }),
      zipBytes,
    );
    expect(
      await decryptIfEncrypted(jsonBytes, ({
        required previousAttemptFailed,
      }) async {
        prompted = true;
        return 'ignored';
      }),
      jsonBytes,
    );
    expect(prompted, isFalse);
  });

  test(
    'wrong then correct passphrase prompts twice with previousAttemptFailed',
    () async {
      final plaintext = Uint8List.fromList(utf8.encode('decrypted-zip'));
      when(
        mockApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
          ciphertext: fakeAgeBytes,
          passphrase: 'wrong',
        ),
      ).thenAnswer(
        (_) async => const BundleCryptoResult(
          error: BundleCryptoErrorKind.wrongPassphrase,
          message: 'Wrong passphrase',
        ),
      );
      when(
        mockApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
          ciphertext: fakeAgeBytes,
          passphrase: 'correct-passphrase',
        ),
      ).thenAnswer((_) async => BundleCryptoResult(data: plaintext));

      final failedFlags = <bool>[];
      var callCount = 0;
      final result = await decryptIfEncrypted(fakeAgeBytes, ({
        required previousAttemptFailed,
      }) async {
        failedFlags.add(previousAttemptFailed);
        callCount++;
        return callCount == 1 ? 'wrong' : 'correct-passphrase';
      });

      expect(result, plaintext);
      expect(failedFlags, [false, true]);
    },
  );

  test('cancel returns null without calling bridge', () async {
    final result = await decryptIfEncrypted(
      fakeAgeBytes,
      ({required previousAttemptFailed}) async => null,
    );
    expect(result, isNull);
    verifyNever(
      mockApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
        ciphertext: anyNamed('ciphertext'),
        passphrase: anyNamed('passphrase'),
      ),
    );
  });

  test(
    'corrupt result throws EncryptedBundleException without second prompt',
    () async {
      when(
        mockApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
          ciphertext: fakeAgeBytes,
          passphrase: 'pass',
        ),
      ).thenAnswer(
        (_) async => const BundleCryptoResult(
          error: BundleCryptoErrorKind.corrupt,
          message: 'Corrupt',
        ),
      );

      var promptCount = 0;
      await expectLater(
        () => decryptIfEncrypted(fakeAgeBytes, ({
          required previousAttemptFailed,
        }) async {
          promptCount++;
          return 'pass';
        }),
        throwsA(
          isA<EncryptedBundleException>().having(
            (e) => e.kind,
            'kind',
            EncryptedBundleFailure.corrupt,
          ),
        ),
      );
      expect(promptCount, 1);
    },
  );
}
