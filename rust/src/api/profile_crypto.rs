use kafkalyzer_core::profile_crypto::{
    decrypt_with_passphrase, encrypt_with_passphrase, ProfileCryptoError,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BundleCryptoErrorKind {
    WrongPassphrase,
    NotPassphraseEncrypted,
    Corrupt,
    ExcessiveWork,
    PassphraseTooShort,
    Internal,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BundleCryptoResult {
    pub data: Option<Vec<u8>>,
    pub error: Option<BundleCryptoErrorKind>,
    pub message: Option<String>,
}

impl From<ProfileCryptoError> for BundleCryptoErrorKind {
    fn from(err: ProfileCryptoError) -> Self {
        match err {
            ProfileCryptoError::WrongPassphrase => BundleCryptoErrorKind::WrongPassphrase,
            ProfileCryptoError::NotPassphraseEncrypted => {
                BundleCryptoErrorKind::NotPassphraseEncrypted
            }
            ProfileCryptoError::Corrupt => BundleCryptoErrorKind::Corrupt,
            ProfileCryptoError::ExcessiveWork => BundleCryptoErrorKind::ExcessiveWork,
            ProfileCryptoError::PassphraseTooShort => BundleCryptoErrorKind::PassphraseTooShort,
        }
    }
}

pub fn encrypt_bundle_with_passphrase(
    plaintext: Vec<u8>,
    passphrase: String,
) -> BundleCryptoResult {
    match encrypt_with_passphrase(&plaintext, &passphrase) {
        Ok(data) => BundleCryptoResult {
            data: Some(data),
            error: None,
            message: None,
        },
        Err(err) => BundleCryptoResult {
            data: None,
            error: Some(err.into()),
            message: Some(err.to_string()),
        },
    }
}

pub fn decrypt_bundle_with_passphrase(
    ciphertext: Vec<u8>,
    passphrase: String,
) -> BundleCryptoResult {
    match decrypt_with_passphrase(&ciphertext, &passphrase) {
        Ok(data) => BundleCryptoResult {
            data: Some(data),
            error: None,
            message: None,
        },
        Err(err) => BundleCryptoResult {
            data: None,
            error: Some(err.into()),
            message: Some(err.to_string()),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_every_core_error_variant() {
        assert_eq!(
            BundleCryptoErrorKind::from(ProfileCryptoError::WrongPassphrase),
            BundleCryptoErrorKind::WrongPassphrase
        );
        assert_eq!(
            BundleCryptoErrorKind::from(ProfileCryptoError::NotPassphraseEncrypted),
            BundleCryptoErrorKind::NotPassphraseEncrypted
        );
        assert_eq!(
            BundleCryptoErrorKind::from(ProfileCryptoError::Corrupt),
            BundleCryptoErrorKind::Corrupt
        );
        assert_eq!(
            BundleCryptoErrorKind::from(ProfileCryptoError::ExcessiveWork),
            BundleCryptoErrorKind::ExcessiveWork
        );
        assert_eq!(
            BundleCryptoErrorKind::from(ProfileCryptoError::PassphraseTooShort),
            BundleCryptoErrorKind::PassphraseTooShort
        );
    }
}
