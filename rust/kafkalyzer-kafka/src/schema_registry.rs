use anyhow::Result;
use kafkalyzer_core::kafka_types::ClusterProfile;
use tokio::runtime::Runtime;
use std::io::Read;

fn build_schema_registry_client(profile: &ClusterProfile) -> Result<reqwest::Client> {
    let mut builder = reqwest::Client::builder();

    // 1. SSL Truststore Configuration
    if let Some(truststore_path) = &profile.ssl_truststore_location {
        if !truststore_path.trim().is_empty() {
            if let Ok(mut file) = std::fs::File::open(truststore_path) {
                let mut cert_bytes = vec![];
                if file.read_to_end(&mut cert_bytes).is_ok() {
                    if let Ok(cert) = reqwest::Certificate::from_pem(&cert_bytes) {
                        builder = builder.add_root_certificate(cert);
                    }
                }
            }
        }
    }

    // 2. SSL Keystore Configuration (mTLS)
    if let Some(keystore_path) = &profile.ssl_keystore_location {
        if !keystore_path.trim().is_empty() && (keystore_path.to_lowercase().ends_with(".p12") || keystore_path.to_lowercase().ends_with(".pfx")) {
            let password = profile.ssl_keystore_password.as_deref().unwrap_or("");
            if let Ok(mut file) = std::fs::File::open(keystore_path) {
                let mut pkcs12_bytes = vec![];
                if file.read_to_end(&mut pkcs12_bytes).is_ok() {
                    if let Ok(identity) = reqwest::Identity::from_pkcs12_der(&pkcs12_bytes, password) {
                        builder = builder.identity(identity);
                    }
                }
            }
        }
    } else if let (Some(cert_path), Some(key_path)) = (&profile.ssl_pem_certificate_location, &profile.ssl_pem_key_location) {
        if let (Ok(cert_bytes), Ok(key_bytes)) = (std::fs::read(cert_path), std::fs::read(key_path)) {
            if let Ok(identity) = reqwest::Identity::from_pkcs8_pem(&cert_bytes, &key_bytes) {
                builder = builder.identity(identity);
            }
        }
    }

    Ok(builder.build()?)
}

pub fn fetch_subjects(profile: ClusterProfile) -> Result<Vec<String>> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let subjects = rt.block_on(async {
        let client = build_schema_registry_client(&profile)?;
        let mut req = client.get(format!("{}/subjects", url));
        if let (Some(username), Some(password)) = (&profile.schema_registry_username, &profile.schema_registry_password) {
            req = req.basic_auth(username, Some(password));
        }
        let resp = req
            .send()
            .await?
            .json::<Vec<String>>()
            .await?;
        Ok::<Vec<String>, anyhow::Error>(resp)
    })?;

    Ok(subjects)
}

pub fn fetch_schema(profile: ClusterProfile, subject: String) -> Result<String> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let schema_str = rt.block_on(async {
        let client = build_schema_registry_client(&profile)?;
        let mut req = client.get(format!("{}/subjects/{}/versions/latest", url, subject));
        if let (Some(username), Some(password)) = (&profile.schema_registry_username, &profile.schema_registry_password) {
            req = req.basic_auth(username, Some(password));
        }
        let resp = req
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;

        // Extract "schema" field
        if let Some(schema) = resp.get("schema") {
            if let Some(s) = schema.as_str() {
                return Ok::<String, anyhow::Error>(s.to_string());
            }
        }
        Err(anyhow::anyhow!("Schema not found in response"))
    })?;

    Ok(schema_str)
}
