use anyhow::Result;
use kafkalyzer_core::kafka_types::{ClusterProfile, MessageSchema};
use std::collections::HashMap;
use std::io::Read;
use std::sync::{LazyLock, Mutex};
use tokio::runtime::Runtime;

/// Subject and version behind a Schema Registry id. Answers come from
/// `GET /schemas/ids/{id}/versions`; a scan must not ask per message, so every
/// answer — including "could not be resolved" — is cached for the session.
static PROVENANCE_CACHE: LazyLock<Mutex<HashMap<u32, MessageSchema>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// Registry requests made for provenance, counted per schema id. A scan must
/// resolve each id once, so this stays at 1 while messages of that schema stream past.
static PROVENANCE_LOOKUPS: LazyLock<Mutex<HashMap<u32, u32>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub fn provenance_lookups_for(schema_id: u32) -> u32 {
    PROVENANCE_LOOKUPS
        .lock()
        .ok()
        .and_then(|counts| counts.get(&schema_id).copied())
        .unwrap_or(0)
}

#[derive(Clone)]
pub struct SchemaProvenance {
    base_url: String,
    username: Option<String>,
    password: Option<String>,
    client: reqwest::Client,
}

impl SchemaProvenance {
    pub fn from_profile(profile: &ClusterProfile) -> Option<Self> {
        let url = profile.schema_registry_url.as_deref()?.trim();
        if url.is_empty() {
            return None;
        }
        let base_url = if url.starts_with("http://") || url.starts_with("https://") {
            url.to_string()
        } else {
            format!("http://{url}")
        };
        Some(Self {
            base_url,
            username: profile.schema_registry_username.clone(),
            password: profile.schema_registry_password.clone(),
            client: build_schema_registry_client(profile).ok()?,
        })
    }

    pub fn resolve(&self, runtime: &Runtime, schema_id: u32) -> MessageSchema {
        if let Ok(guard) = PROVENANCE_CACHE.lock() {
            if let Some(cached) = guard.get(&schema_id) {
                return cached.clone();
            }
        }
        let resolved = runtime.block_on(self.fetch(schema_id));
        if let Ok(mut guard) = PROVENANCE_CACHE.lock() {
            guard.insert(schema_id, resolved.clone());
        }
        resolved
    }

    async fn fetch(&self, schema_id: u32) -> MessageSchema {
        if let Ok(mut counts) = PROVENANCE_LOOKUPS.lock() {
            *counts.entry(schema_id).or_insert(0) += 1;
        }
        let unresolved = || MessageSchema {
            schema_id,
            subject: None,
            version: None,
        };
        let mut request = self.client.get(format!(
            "{}/schemas/ids/{}/versions",
            self.base_url, schema_id
        ));
        if let (Some(username), Some(password)) = (&self.username, &self.password) {
            request = request.basic_auth(username, Some(password));
        }
        let Ok(response) = request.send().await else {
            return unresolved();
        };
        let entries = match response.json::<serde_json::Value>().await {
            Ok(value) => value,
            Err(_) => return unresolved(),
        };
        parse_versions_response(entries, schema_id)
    }
}

/// Reads the first `subject`/`version` pair out of a
/// `GET /schemas/ids/{id}/versions` response body.
fn parse_versions_response(body: serde_json::Value, schema_id: u32) -> MessageSchema {
    match body.as_array().and_then(|list| list.first()) {
        Some(entry) => MessageSchema {
            schema_id,
            subject: entry
                .get("subject")
                .and_then(|value| value.as_str())
                .map(str::to_string),
            version: entry
                .get("version")
                .and_then(|value| value.as_i64())
                .map(|value| value as i32),
        },
        None => MessageSchema {
            schema_id,
            subject: None,
            version: None,
        },
    }
}

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
        if !keystore_path.trim().is_empty()
            && (keystore_path.to_lowercase().ends_with(".p12")
                || keystore_path.to_lowercase().ends_with(".pfx"))
        {
            let password = profile.ssl_keystore_password.as_deref().unwrap_or("");
            if let Ok(mut file) = std::fs::File::open(keystore_path) {
                let mut pkcs12_bytes = vec![];
                if file.read_to_end(&mut pkcs12_bytes).is_ok() {
                    if let Ok(identity) =
                        reqwest::Identity::from_pkcs12_der(&pkcs12_bytes, password)
                    {
                        builder = builder.identity(identity);
                    }
                }
            }
        }
    } else if let (Some(cert_path), Some(key_path)) = (
        &profile.ssl_pem_certificate_location,
        &profile.ssl_pem_key_location,
    ) {
        if let (Ok(cert_bytes), Ok(key_bytes)) = (std::fs::read(cert_path), std::fs::read(key_path))
        {
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
        if let (Some(username), Some(password)) = (
            &profile.schema_registry_username,
            &profile.schema_registry_password,
        ) {
            req = req.basic_auth(username, Some(password));
        }
        let resp = req.send().await?.json::<Vec<String>>().await?;
        Ok::<Vec<String>, anyhow::Error>(resp)
    })?;

    Ok(subjects)
}

/// Fetches a schema of a subject. `version` selects an exact version, `None`
/// asks for the latest one. A message records the version it was written with,
/// so the inspector can show that version instead of only the current one.
pub fn fetch_schema(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> Result<String> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let schema_str = rt.block_on(async {
        let client = build_schema_registry_client(&profile)?;
        let endpoint = match version {
            Some(v) => format!("{}/subjects/{}/versions/{}", url, subject, v),
            None => format!("{}/subjects/{}/versions/latest", url, subject),
        };
        let mut req = client.get(endpoint);
        if let (Some(username), Some(password)) = (
            &profile.schema_registry_username,
            &profile.schema_registry_password,
        ) {
            req = req.basic_auth(username, Some(password));
        }
        let resp = req.send().await?.json::<serde_json::Value>().await?;

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

/// Version numbers registered for a subject, newest last as the Confluent
/// Registry returns them.
pub fn fetch_schema_versions(profile: ClusterProfile, subject: String) -> Result<Vec<i32>> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let versions = rt.block_on(async {
        let client = build_schema_registry_client(&profile)?;
        let mut req = client.get(format!("{}/subjects/{}/versions", url, subject));
        if let (Some(username), Some(password)) = (
            &profile.schema_registry_username,
            &profile.schema_registry_password,
        ) {
            req = req.basic_auth(username, Some(password));
        }
        let resp = req.send().await?.json::<Vec<i32>>().await?;
        Ok::<Vec<i32>, anyhow::Error>(resp)
    })?;

    Ok(versions)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn profile_with_registry(url: &str) -> ClusterProfile {
        ClusterProfile {
            name: "test".to_string(),
            bootstrap_servers: "localhost:9092".to_string(),
            schema_registry_url: Some(url.to_string()),
            ..Default::default()
        }
    }

    /// Captured Confluent Registry answer for `GET /schemas/ids/42/versions`.
    const VERSIONS_RESPONSE_ID_42: &str = r#"[{"subject":"orders-value","version":3,"id":42}]"#;

    #[test]
    fn versions_response_yields_subject_and_version() {
        let body: serde_json::Value = serde_json::from_str(VERSIONS_RESPONSE_ID_42).unwrap();
        let schema = parse_versions_response(body, 42);

        assert_eq!(schema.schema_id, 42);
        assert_eq!(schema.subject.as_deref(), Some("orders-value"));
        assert_eq!(schema.version, Some(3));
    }

    #[test]
    fn an_empty_versions_answer_leaves_the_schema_unresolved() {
        let schema = parse_versions_response(serde_json::json!([]), 42);

        assert_eq!(schema.schema_id, 42);
        assert_eq!(schema.subject, None);
        assert_eq!(schema.version, None);
    }

    #[test]
    fn a_profile_without_a_registry_url_has_no_provenance() {
        assert!(SchemaProvenance::from_profile(&ClusterProfile::default()).is_none());
        assert!(SchemaProvenance::from_profile(&profile_with_registry("")).is_none());
    }

    #[test]
    fn an_unreachable_registry_leaves_only_the_id() {
        let provenance =
            SchemaProvenance::from_profile(&profile_with_registry("http://127.0.0.1:1"))
                .expect("a registry url is set");

        let schema = provenance.resolve(&Runtime::new().unwrap(), 4242);

        assert_eq!(schema.schema_id, 4242);
        assert_eq!(schema.subject, None);
        assert_eq!(schema.version, None);
    }
}

#[cfg(test)]
mod provenance_cache_tests {
    use super::*;

    #[test]
    fn one_schema_id_is_resolved_once_for_the_whole_scan() {
        let provenance = SchemaProvenance::from_profile(&ClusterProfile {
            name: "test".to_string(),
            bootstrap_servers: "localhost:9092".to_string(),
            schema_registry_url: Some("http://127.0.0.1:1".to_string()),
            ..Default::default()
        })
        .expect("a registry url is set");
        let runtime = Runtime::new().unwrap();

        let first = provenance.resolve(&runtime, 9100);
        let second = provenance.resolve(&runtime, 9100);
        let third = provenance.resolve(&runtime, 9100);

        assert_eq!(first, second);
        assert_eq!(second, third);
        assert_eq!(
            provenance_lookups_for(9100),
            1,
            "three messages of the same schema must not ask the registry three times"
        );
    }
}
