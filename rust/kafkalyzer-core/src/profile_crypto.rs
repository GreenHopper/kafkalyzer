use std::fmt;
use std::io::{Read, Write};

use age::secrecy::SecretString;
use age::{DecryptError, Decryptor, Encryptor};

pub const MIN_PASSPHRASE_CHARS: usize = 12;
pub const AGE_HEADER_PREFIX: &[u8] = b"age-encryption.org/v1\n";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfileCryptoError {
    WrongPassphrase,
    NotPassphraseEncrypted,
    Corrupt,
    ExcessiveWork,
    PassphraseTooShort,
}

impl fmt::Display for ProfileCryptoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ProfileCryptoError::WrongPassphrase => write!(f, "Wrong passphrase"),
            ProfileCryptoError::NotPassphraseEncrypted => {
                write!(f, "Bundle is not passphrase-encrypted")
            }
            ProfileCryptoError::Corrupt => write!(f, "Encrypted bundle is corrupt or unsupported"),
            ProfileCryptoError::ExcessiveWork => {
                write!(f, "Encrypted bundle requires excessive scrypt work")
            }
            ProfileCryptoError::PassphraseTooShort => {
                write!(
                    f,
                    "Passphrase must be at least {MIN_PASSPHRASE_CHARS} characters"
                )
            }
        }
    }
}

impl std::error::Error for ProfileCryptoError {}

pub fn is_age_encrypted(bytes: &[u8]) -> bool {
    bytes.starts_with(AGE_HEADER_PREFIX)
}

pub fn encrypt_with_passphrase(
    plaintext: &[u8],
    passphrase: &str,
) -> Result<Vec<u8>, ProfileCryptoError> {
    if passphrase.chars().count() < MIN_PASSPHRASE_CHARS {
        return Err(ProfileCryptoError::PassphraseTooShort);
    }
    let secret = SecretString::from(passphrase.to_owned());
    let encryptor = Encryptor::with_user_passphrase(secret);
    let mut output = Vec::new();
    let mut writer = encryptor
        .wrap_output(&mut output)
        .map_err(|_| ProfileCryptoError::Corrupt)?;
    writer
        .write_all(plaintext)
        .map_err(|_| ProfileCryptoError::Corrupt)?;
    writer.finish().map_err(|_| ProfileCryptoError::Corrupt)?;
    Ok(output)
}

pub fn decrypt_with_passphrase(
    ciphertext: &[u8],
    passphrase: &str,
) -> Result<Vec<u8>, ProfileCryptoError> {
    if !is_age_encrypted(ciphertext) {
        return Err(ProfileCryptoError::Corrupt);
    }
    let secret = SecretString::from(passphrase.to_owned());
    let decryptor = Decryptor::new(ciphertext).map_err(map_decrypt_error)?;
    if !decryptor.is_scrypt() {
        return Err(ProfileCryptoError::NotPassphraseEncrypted);
    }
    let identity = age::scrypt::Identity::new(secret);
    let mut reader = decryptor
        .decrypt(std::iter::once(&identity as &dyn age::Identity))
        .map_err(map_decrypt_error)?;
    let mut plaintext = Vec::new();
    reader
        .read_to_end(&mut plaintext)
        .map_err(|_| ProfileCryptoError::Corrupt)?;
    Ok(plaintext)
}

fn map_decrypt_error(err: DecryptError) -> ProfileCryptoError {
    match err {
        DecryptError::DecryptionFailed
        | DecryptError::KeyDecryptionFailed
        | DecryptError::NoMatchingKeys => ProfileCryptoError::WrongPassphrase,
        DecryptError::ExcessiveWork { .. } => ProfileCryptoError::ExcessiveWork,
        DecryptError::InvalidHeader
        | DecryptError::InvalidMac
        | DecryptError::UnknownFormat
        | DecryptError::Io(_) => ProfileCryptoError::Corrupt,
        _ => ProfileCryptoError::Corrupt,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn encrypt_fast_for_test(
        plaintext: &[u8],
        passphrase: &str,
    ) -> Result<Vec<u8>, ProfileCryptoError> {
        if passphrase.chars().count() < MIN_PASSPHRASE_CHARS {
            return Err(ProfileCryptoError::PassphraseTooShort);
        }
        let secret = SecretString::from(passphrase.to_owned());
        let mut recipient = age::scrypt::Recipient::new(secret);
        recipient.set_work_factor(1);
        let encryptor =
            Encryptor::with_recipients(std::iter::once(&recipient as &dyn age::Recipient))
                .expect("scrypt recipient");
        let mut output = Vec::new();
        let mut writer = encryptor.wrap_output(&mut output).unwrap();
        writer.write_all(plaintext).unwrap();
        writer.finish().unwrap();
        Ok(output)
    }

    #[test]
    fn round_trip_empty_single_byte_and_one_mib() {
        let passphrase = "correct horse battery staple";
        let one_mib = vec![0x5Au8; 1024 * 1024];
        for payload in [b"".as_slice(), b"x".as_slice(), one_mib.as_slice()] {
            let encrypted = encrypt_fast_for_test(payload, passphrase).unwrap();
            assert!(is_age_encrypted(&encrypted));
            let decrypted = decrypt_with_passphrase(&encrypted, passphrase).unwrap();
            assert_eq!(decrypted, payload);
        }
    }

    #[test]
    fn public_encrypt_and_decrypt_round_trip() {
        let passphrase = "correct horse battery staple";
        let payload = b"1 KiB test payload".repeat(60);
        let encrypted = encrypt_with_passphrase(&payload, passphrase).unwrap();
        assert!(is_age_encrypted(&encrypted));
        let decrypted = decrypt_with_passphrase(&encrypted, passphrase).unwrap();
        assert_eq!(decrypted, payload);
    }

    #[test]
    fn wrong_passphrase_returns_wrong_passphrase() {
        let encrypted = encrypt_fast_for_test(b"secret", "correct horse battery staple").unwrap();
        assert_eq!(
            decrypt_with_passphrase(&encrypted, "wrong passphrase here"),
            Err(ProfileCryptoError::WrongPassphrase)
        );
    }

    #[test]
    fn flipped_header_byte_returns_corrupt() {
        let mut encrypted =
            encrypt_fast_for_test(b"secret", "correct horse battery staple").unwrap();
        // Flip a byte inside the scrypt header line after the magic prefix
        let idx = AGE_HEADER_PREFIX.len() + 2;
        encrypted[idx] ^= 0x01;
        assert_eq!(
            decrypt_with_passphrase(&encrypted, "correct horse battery staple"),
            Err(ProfileCryptoError::Corrupt)
        );
    }

    #[test]
    fn truncated_payload_returns_corrupt() {
        let mut encrypted =
            encrypt_fast_for_test(b"secret payload data", "correct horse battery staple").unwrap();
        encrypted.truncate(encrypted.len() - 4);
        assert_eq!(
            decrypt_with_passphrase(&encrypted, "correct horse battery staple"),
            Err(ProfileCryptoError::Corrupt)
        );
    }

    #[test]
    fn non_age_bytes_return_corrupt() {
        assert_eq!(
            decrypt_with_passphrase(b"PK\x03\x04not-age", "correct horse battery staple"),
            Err(ProfileCryptoError::Corrupt)
        );
    }

    #[test]
    fn x25519_encrypted_file_returns_not_passphrase_encrypted() {
        let identity = age::x25519::Identity::generate();
        let recipient = identity.to_public();
        let encryptor =
            Encryptor::with_recipients(std::iter::once(&recipient as &dyn age::Recipient))
                .expect("x25519 recipient");
        let mut encrypted = Vec::new();
        let mut writer = encryptor.wrap_output(&mut encrypted).unwrap();
        writer.write_all(b"secret").unwrap();
        writer.finish().unwrap();

        assert_eq!(
            decrypt_with_passphrase(&encrypted, "correct horse battery staple"),
            Err(ProfileCryptoError::NotPassphraseEncrypted)
        );
    }

    #[test]
    fn passphrase_min_length_uses_unicode_scalar_count() {
        // 11 chars -> rejected
        assert_eq!(
            encrypt_with_passphrase(b"secret", "12345678901"),
            Err(ProfileCryptoError::PassphraseTooShort)
        );
        // 12 multi-byte chars (24 UTF-8 bytes, 12 Unicode chars) -> accepted
        let multibyte_12 = "üäöüßüäöüßüä";
        assert_eq!(multibyte_12.chars().count(), 12);
        let encrypted = encrypt_fast_for_test(b"secret", multibyte_12).unwrap();
        assert_eq!(
            decrypt_with_passphrase(&encrypted, multibyte_12).unwrap(),
            b"secret"
        );
    }
}
