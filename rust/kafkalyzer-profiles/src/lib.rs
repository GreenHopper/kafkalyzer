//! Shared cluster profiles for headless kafkalyzer binaries (MCP and friends).

mod path;
mod secret_field;
mod secret_store;
mod shared_profile;
mod sync;

pub use path::{default_path, default_path_with_env};
pub use secret_field::SecretField;
pub use secret_store::{KeyringSecretStore, MemorySecretStore, SecretStore, KEYRING_SERVICE};
pub use shared_profile::{
    split_secrets, SharedProfile, SharedProfilesFile, SHARED_PROFILES_VERSION,
};
pub use sync::{
    classify_store_error, read_shared, write_shared, ProfileReadError, SharedProfileInput,
    SyncFailureKind, SyncReport,
};
