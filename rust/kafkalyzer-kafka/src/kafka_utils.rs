use kafkalyzer_core::kafka_types::ClusterProfile;
use openssl::pkcs12::Pkcs12;
pub use rdkafka::config::ClientConfig;
use std::fs::File;
use std::io::Read;

pub fn murmur2(data: &[u8]) -> u32 {
    let length = data.len();
    let seed: u32 = 0x9747b28c;
    let multiplier: u32 = 0x5bd1e995;
    let rotation: i32 = 24;

    let mut hash_value: u32 = seed ^ (length as u32);
    let length4 = length / 4;

    for i in 0..length4 {
        let i4 = i * 4;
        let mut block_value: u32 = (data[i4] as u32)
            + ((data[i4 + 1] as u32) << 8)
            + ((data[i4 + 2] as u32) << 16)
            + ((data[i4 + 3] as u32) << 24);
        block_value = block_value.wrapping_mul(multiplier);
        block_value ^= block_value >> rotation;
        block_value = block_value.wrapping_mul(multiplier);

        hash_value = hash_value.wrapping_mul(multiplier);
        hash_value ^= block_value;
    }

    match length % 4 {
        3 => {
            hash_value ^= (data[(length & !3) + 2] as u32) << 16;
            hash_value ^= (data[(length & !3) + 1] as u32) << 8;
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        2 => {
            hash_value ^= (data[(length & !3) + 1] as u32) << 8;
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        1 => {
            hash_value ^= data[length & !3] as u32;
            hash_value = hash_value.wrapping_mul(multiplier);
        }
        _ => {}
    }

    hash_value ^= hash_value >> 13;
    hash_value = hash_value.wrapping_mul(multiplier);
    hash_value ^= hash_value >> 15;
    hash_value
}

pub fn to_positive(number: u32) -> u32 {
    number & 0x7fffffff
}

// ... (imports)

fn init_providers() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        let mut legacy_loaded = false;

        // Fix for Windows: OpenSSL modules path is often hardcoded.
        // Try to load by ABSOLUTE PATH first to bypass the search logic.
        if let Ok(exe_path) = std::env::current_exe() {
            if let Some(exe_dir) = exe_path.parent() {
                let modules_path = exe_dir.join("ossl-modules");

                // 1. Set Env Var (still good practice)
                if modules_path.exists() {
                    if let Some(s) = modules_path.to_str() {
                        std::env::set_var("OPENSSL_MODULES", s);
                        log::debug!("Set OPENSSL_MODULES to: {}", s);
                    }
                }

                // 2. Try loading by Absolute Path
                let legacy_dll = modules_path.join("legacy.dll");
                if legacy_dll.exists() {
                    if let Some(dll_path_str) = legacy_dll.to_str() {
                        log::debug!(
                            "Attempting to load legacy provider from path: {}",
                            dll_path_str
                        );
                        let params =
                            openssl::provider::Provider::try_load(None, dll_path_str, true);
                        match &params {
                            Ok(_) => {
                                legacy_loaded = true;
                                log::debug!("Success: Legacy provider loaded from absolute path.");
                                // Prevent unloading
                                if let Ok(p) = params {
                                    std::mem::forget(p);
                                }
                            }
                            Err(e) => {
                                log::warn!("Failed to load legacy provider from path: {}", e);
                            }
                        }
                    }
                }
            }
        }

        if !legacy_loaded {
            log::debug!("Fallback: Loading 'legacy' provider by name...");
            let legacy = openssl::provider::Provider::try_load(None, "legacy", true);
            match &legacy {
                Ok(_) => log::debug!("Legacy OpenSSL provider loaded successfully (by name)."),
                Err(e) => log::warn!("Failed to load Legacy OpenSSL provider (by name): {}", e),
            }
            if let Ok(p) = legacy {
                std::mem::forget(p);
            }
        }

        let def = openssl::provider::Provider::try_load(None, "default", true);
        if let Ok(p) = def {
            std::mem::forget(p);
        }
    });
}

pub fn create_config(profile: &ClusterProfile) -> ClientConfig {
    init_providers();
    let mut config = ClientConfig::new();
    config.set("bootstrap.servers", &profile.bootstrap_servers);
    if profile.ssl_verification_disabled {
        config.set("ssl.endpoint.identification.algorithm", "none");
        config.set("enable.ssl.certificate.verification", "false");
    } else {
        config.set("ssl.endpoint.identification.algorithm", "https");
        config.set("enable.ssl.certificate.verification", "true");
    }

    config.set("security.protocol", &profile.effective_security_protocol());

    if let Some(mechanism) = &profile.mechanism {
        config.set("sasl.mechanism", mechanism);

        if mechanism.eq_ignore_ascii_case("GSSAPI") {
            if let Some(service_name) = &profile.sasl_kerberos_service_name {
                config.set("sasl.kerberos.service.name", service_name);
            }
            if let Some(keytab) = &profile.sasl_kerberos_keytab {
                config.set("sasl.kerberos.keytab", keytab);
            }
            if let Some(principal) = &profile.sasl_kerberos_principal {
                config.set("sasl.kerberos.principal", principal);
            }
            if let Some(krb5_conf) = &profile.sasl_kerberos_conf {
                std::env::set_var("KRB5_CONFIG", krb5_conf);
            }
        } else if mechanism.eq_ignore_ascii_case("OAUTHBEARER") {
            if let Some(token) = &profile.sasl_oauthbearer_token {
                config.set("sasl.oauthbearer.config", token);
            }
        }
    }

    if let Some(username) = &profile.sasl_username {
        config.set("sasl.username", username);
    }

    if let Some(password) = &profile.sasl_password {
        config.set("sasl.password", password);
    }

    // PEM mTLS client certificate configuration
    if let Some(cert_loc) = &profile.ssl_pem_certificate_location {
        config.set("ssl.certificate.location", cert_loc);
    }
    if let Some(key_loc) = &profile.ssl_pem_key_location {
        config.set("ssl.key.location", key_loc);
    }
    if let Some(key_pass) = &profile.ssl_pem_key_password {
        config.set("ssl.key.password", key_pass);
    }

    if let Some(location) = &profile.ssl_keystore_location {
        if location.to_lowercase().ends_with(".p12") || location.to_lowercase().ends_with(".pfx") {
            let password = profile.ssl_keystore_password.as_deref().unwrap_or("");

            // Replaced expect with Result handling/logging
            if let Ok(mut file) = File::open(location) {
                let mut p12_bytes = vec![];
                if file.read_to_end(&mut p12_bytes).is_ok() {
                    match Pkcs12::from_der(&p12_bytes) {
                        Ok(p12_builder) => {
                            match p12_builder.parse2(password) {
                                Ok(p12) => {
                                    // 1. Extract Private Key
                                    if let Some(pkey) = p12.pkey {
                                        if let Ok(pem_bytes) = pkey.private_key_to_pem_pkcs8() {
                                            if let Ok(pem_string) = String::from_utf8(pem_bytes) {
                                                config.set("ssl.key.pem", &pem_string);
                                            }
                                        }
                                    }

                                    // 2. Extract Certificate Chain
                                    let mut all_pem = String::new();
                                    if let Some(cert) = p12.cert {
                                        if let Ok(pem_bytes) = cert.to_pem() {
                                            if let Ok(pem) = String::from_utf8(pem_bytes) {
                                                all_pem.push_str(&pem);
                                                all_pem.push('\n');
                                            }
                                        }
                                    }
                                    if let Some(stack) = p12.ca {
                                        for cert in stack {
                                            if let Ok(pem_bytes) = cert.to_pem() {
                                                if let Ok(pem) = String::from_utf8(pem_bytes) {
                                                    all_pem.push_str(&pem);
                                                    all_pem.push('\n');
                                                }
                                            }
                                        }
                                    }
                                    if !all_pem.trim().is_empty() {
                                        config.set("ssl.certificate.pem", &all_pem);
                                    }
                                }
                                Err(e) => {
                                    log::warn!("PKCS12 parse error: {}", e);
                                }
                            }
                        }
                        Err(e) => {
                            log::warn!("PKCS12 decode error: {}", e);
                        }
                    }
                } else {
                    log::warn!("Failed to read keystore file via read_to_end.");
                }
            } else {
                log::warn!("Keystore file not found or unreadable: {}", location);
            }

            // Fallback: If we failed to set the key PEM (parsing failed), let rdkafka try to load the P12 directly.
            // This is critical if manual parsing fails (e.g. on Linux without configured providers).
            if config.get("ssl.key.pem").is_none() {
                log::debug!(
                    "Manual P12 parsing failed or produced no key. Falling back to letting rdkafka load the P12."
                );
                config.set("ssl.keystore.location", location);
                if let Some(password) = &profile.ssl_keystore_password {
                    config.set("ssl.keystore.password", password);
                }
            } else {
                // Manual parsing succeeded. We do NOT set location/password to avoid rdkafka conflict/double-loading.
                // But we DO need to ensure the certificate chain is set.

                // If we have a key but no certificate chain from P12 (unlikely but possible), we might be in trouble.
                // But the Truststore logic handles CA. The keystore logic handles Client Cert.
                // p12.cert and p12.ca should have populated ssl.certificate.pem.
            }
        } else {
            // Standard PEM handling
            config.set("ssl.keystore.location", location);

            if let Some(password) = &profile.ssl_keystore_password {
                config.set("ssl.keystore.password", password);
            }
        }
    }

    // Note: If we handled P12, we extracted unencrypted key PEM, so we don't need to set ssl.keystore.password.
    // The ELSE block above handles setting password for non-P12 cases.
    /*
    Original block was:
    if let Some(password) = &profile.ssl_keystore_password { ... }
    We removed it from top level and put it inside the ELSE (non-P12) block.
    */
    log::debug!(
        "Creating Kafka config: protocol={:?}, truststore={:?}",
        profile.security_protocol,
        profile.ssl_truststore_location
    );

    // Harden check: treat empty string as None
    let truststore_loc = match &profile.ssl_truststore_location {
        Some(s) if !s.trim().is_empty() => Some(s.clone()),
        _ => None,
    };

    if let Some(location) = truststore_loc {
        log::debug!("User provided truststore: {}", location);
        // Check if it's a P12 file
        if location.to_lowercase().ends_with(".p12") || location.to_lowercase().ends_with(".pfx") {
            let password = profile.ssl_truststore_password.as_deref().unwrap_or("");

            // Read P12 file
            if let Ok(mut file) = File::open(&location) {
                let mut p12_bytes = vec![];
                if file.read_to_end(&mut p12_bytes).is_ok() {
                    // Parse P12
                    match Pkcs12::from_der(&p12_bytes) {
                        Ok(p12_builder) => match p12_builder.parse2(password) {
                            Ok(p12) => {
                                let mut all_pem = String::new();

                                if let Some(cert) = p12.cert {
                                    if let Ok(pem_bytes) = cert.to_pem() {
                                        if let Ok(pem) = String::from_utf8(pem_bytes) {
                                            all_pem.push_str(&pem);
                                            all_pem.push('\n');
                                        }
                                    }
                                }

                                if let Some(stack) = p12.ca {
                                    for cert in stack {
                                        if let Ok(pem_bytes) = cert.to_pem() {
                                            if let Ok(pem) = String::from_utf8(pem_bytes) {
                                                all_pem.push_str(&pem);
                                                all_pem.push('\n');
                                            }
                                        }
                                    }
                                }

                                if !all_pem.trim().is_empty() {
                                    config.set("ssl.ca.pem", &all_pem);
                                }
                            }
                            Err(e) => {
                                log::warn!("P12 Parse Error: {}", e);
                                log::debug!("Attempting fallback to bundled CA...");
                            }
                        },
                        Err(e) => {
                            log::warn!("P12 DER Error: {}", e);
                            log::debug!("Attempting fallback to bundled CA...");
                        }
                    }
                } else {
                    log::warn!("Failed to read truststore file: {}", location);
                }
            } else {
                log::warn!("Truststore file not found: {}", location);
            }
        } else {
            // Standard PEM file
            config.set("ssl.ca.location", &location);
        }
    }

    #[cfg(windows)]
    {
        // Check if CA location was set. If not (e.g. no truststore or P12 failure), try fallback.
        let ca_configured =
            config.get("ssl.ca.location").is_some() || config.get("ssl.ca.pem").is_some();

        if !ca_configured {
            // Default fallback to 'cacert.pem' in the same directory as the executable on Windows.
            if let Ok(exe_path) = std::env::current_exe() {
                if let Some(exe_dir) = exe_path.parent() {
                    let ca_path = exe_dir.join("cacert.pem");

                    log::debug!("Checking for bundled CA at: {:?}", ca_path);

                    if ca_path.exists() {
                        if let Some(s) = ca_path.to_str() {
                            log::info!("Using bundled CA cert at: {}", s);
                            config.set("ssl.ca.location", s);
                        }
                    } else {
                        log::debug!("Bundled CA NOT found.");
                    }
                }
            }
        }
    }
    // Note: ssl.truststore.password is used above for P12 parsing, but if it's not P12 (PEM), librdkafka doesn't use a password for CA location usually.
    // If user provided a password but used PEM, it might be for a PEM Key, but that's keystore.
    // So we don't set ssl.truststore.password property on config because it doesn't exist for librdkafka.

    log::debug!("Kafka config created.");

    config
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_config_verifies_tls_by_default() {
        for security_protocol in [None, Some("SSL".to_string()), Some("SASL_SSL".to_string())] {
            let profile = ClusterProfile {
                name: "test".to_string(),
                bootstrap_servers: "broker:9093".to_string(),
                security_protocol,
                ssl_truststore_location: Some("/tmp/ca.pem".to_string()),
                ..Default::default()
            };
            let config = create_config(&profile);
            assert_eq!(
                config.get("enable.ssl.certificate.verification"),
                Some("true")
            );
            assert_eq!(
                config.get("ssl.endpoint.identification.algorithm"),
                Some("https")
            );
        }
    }

    #[test]
    fn create_config_disables_verification_only_when_profile_opts_out() {
        let profile = ClusterProfile {
            name: "insecure".to_string(),
            bootstrap_servers: "broker:9093".to_string(),
            security_protocol: Some("SASL_SSL".to_string()),
            ssl_verification_disabled: true,
            ..Default::default()
        };
        let config = create_config(&profile);
        assert_eq!(
            config.get("enable.ssl.certificate.verification"),
            Some("false")
        );
        assert_eq!(
            config.get("ssl.endpoint.identification.algorithm"),
            Some("none")
        );
    }

    #[cfg(not(windows))]
    #[test]
    fn create_config_does_not_set_ca_location_without_truststore_on_non_windows() {
        let profile = ClusterProfile {
            name: "linux".to_string(),
            bootstrap_servers: "broker:9093".to_string(),
            security_protocol: Some("SSL".to_string()),
            ..Default::default()
        };
        let config = create_config(&profile);
        assert_eq!(config.get("ssl.ca.location"), None);
    }
}
