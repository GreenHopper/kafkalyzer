import 'dart:convert';
import 'dart:typed_data';

import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';

/// Binary header prefix of every `age` v1 encrypted file (`age-encryption.org/v1\n`).
final List<int> ageHeaderPrefix = utf8.encode('age-encryption.org/v1\n');

/// ZIP local file header magic bytes (`PK\x03\x04`).
const List<int> zipMagicBytes = [0x50, 0x4B, 0x03, 0x04];

/// Returns `true` when [bytes] starts with the `age` v1 header prefix.
bool isAgeEncrypted(List<int> bytes) {
  if (bytes.length < ageHeaderPrefix.length) return false;
  for (var i = 0; i < ageHeaderPrefix.length; i++) {
    if (bytes[i] != ageHeaderPrefix[i]) return false;
  }
  return true;
}

/// Returns `true` when [bytes] starts with the standard ZIP magic header.
bool isZipBytes(List<int> bytes) {
  if (bytes.length < zipMagicBytes.length) return false;
  for (var i = 0; i < zipMagicBytes.length; i++) {
    if (bytes[i] != zipMagicBytes[i]) return false;
  }
  return true;
}

typedef PassphrasePrompt =
    Future<String?> Function({required bool previousAttemptFailed});

enum EncryptedBundleFailure {
  corrupt,
  unsupported,
  tooExpensive,
  passphraseTooShort,
  internal,
}

class EncryptedBundleException implements Exception {
  final EncryptedBundleFailure kind;
  final String? message;

  const EncryptedBundleException(this.kind, {this.message});

  @override
  String toString() => 'EncryptedBundleException($kind)';
}

/// Encrypts [plaintext] bytes with [passphrase] using `age` via the Rust bridge.
Future<Uint8List> encryptBundle(List<int> plaintext, String passphrase) async {
  final result = await encryptBundleWithPassphrase(
    plaintext: plaintext,
    passphrase: passphrase,
  );
  if (result.error == null && result.data != null) {
    return result.data!;
  }
  throw EncryptedBundleException(
    _mapFailure(result.error),
    message: result.message,
  );
}

/// Decrypts [bytes] if they carry the `age` header, prompting via [prompt].
///
/// Returns `null` if the user cancels the passphrase prompt. Returns [bytes]
/// unchanged when [bytes] is not `age`-encrypted.
Future<List<int>?> decryptIfEncrypted(
  List<int> bytes,
  PassphrasePrompt prompt,
) async {
  if (!isAgeEncrypted(bytes)) {
    return bytes;
  }

  var previousAttemptFailed = false;
  while (true) {
    final passphrase = await prompt(
      previousAttemptFailed: previousAttemptFailed,
    );
    if (passphrase == null) {
      return null;
    }

    final result = await decryptBundleWithPassphrase(
      ciphertext: bytes,
      passphrase: passphrase,
    );
    if (result.error == null && result.data != null) {
      return result.data!;
    }
    if (result.error == BundleCryptoErrorKind.wrongPassphrase) {
      previousAttemptFailed = true;
      continue;
    }
    throw EncryptedBundleException(
      _mapFailure(result.error),
      message: result.message,
    );
  }
}

EncryptedBundleFailure _mapFailure(BundleCryptoErrorKind? error) {
  return switch (error) {
    BundleCryptoErrorKind.notPassphraseEncrypted =>
      EncryptedBundleFailure.unsupported,
    BundleCryptoErrorKind.excessiveWork => EncryptedBundleFailure.tooExpensive,
    BundleCryptoErrorKind.passphraseTooShort =>
      EncryptedBundleFailure.passphraseTooShort,
    BundleCryptoErrorKind.internal => EncryptedBundleFailure.internal,
    BundleCryptoErrorKind.corrupt ||
    BundleCryptoErrorKind.wrongPassphrase ||
    null => EncryptedBundleFailure.corrupt,
  };
}
