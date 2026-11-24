use std::collections::{HashSet, VecDeque};
use std::error::Error as StdError;
use std::fmt;
use std::io::Read;
use std::sync::{LazyLock, Mutex};

use kafkalyzer_core::connection_diagnostics::REGISTRY_TIMEOUT;
use kafkalyzer_core::kafka_types::{ClusterProfile, MessageSchema, SchemaCompatibilityResult};
use kafkalyzer_core::schema_model::{
    parse_compatibility_level, parse_subject_schema, schema_fields, ResolvedReference,
    SchemaFieldModel, SubjectSchema,
};
use kafkalyzer_core::tls::{classify_tls_failure, TlsFailureClassification};
use tokio::runtime::Runtime;

const MAX_REFERENCE_FETCHES: usize = 50;
const MAX_ERROR_DETAIL_CHARS: usize = 500;
const MAX_RAW_BODY_CHARS: usize = 300;

/// Subject and version behind a Schema Registry id. Answers come from
/// `GET /schemas/ids/{id}/versions`; a scan must not ask per message, so every
/// answer — including "could not be resolved" — is cached for the session.
static PROVENANCE_CACHE: LazyLock<Mutex<HashMap<u32, MessageSchema>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// Registry requests made for provenance, counted per schema id. A scan must
/// resolve each id once, so this stays at 1 while messages of that schema stream past.
static PROVENANCE_LOOKUPS: LazyLock<Mutex<HashMap<u32, u32>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

use std::collections::HashMap;

pub fn provenance_lookups_for(schema_id: u32) -> u32 {
    PROVENANCE_LOOKUPS
        .lock()
        .ok()
        .and_then(|counts| counts.get(&schema_id).copied())
        .unwrap_or(0)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchemaRegistryErrorKind {
    NotConfigured,
    InvalidUrl,
    Unauthorized,
    Forbidden,
    NotFound,
    Timeout,
    Unreachable,
    CertificateRejected,
    HttpStatus,
    InvalidResponse,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaRegistryError {
    pub kind: SchemaRegistryErrorKind,
    pub status: Option<u16>,
    pub registry_error_code: Option<i64>,
    pub detail: String,
}

impl SchemaRegistryError {
    fn new(
        kind: SchemaRegistryErrorKind,
        status: Option<u16>,
        registry_error_code: Option<i64>,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            kind,
            status,
            registry_error_code,
            detail: truncate_chars(&detail.into(), MAX_ERROR_DETAIL_CHARS),
        }
    }
}

impl fmt::Display for SchemaRegistryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.status {
            Some(s) => write!(f, "{:?} (HTTP {}): {}", self.kind, s, self.detail),
            None => write!(f, "{:?}: {}", self.kind, self.detail),
        }
    }
}

impl StdError for SchemaRegistryError {}

fn truncate_chars(s: &str, max_chars: usize) -> String {
    if s.chars().count() <= max_chars {
        s.to_string()
    } else {
        let mut out: String = s.chars().take(max_chars).collect();
        out.push('…');
        out
    }
}

/// Normalises a configured Schema Registry URL: trims whitespace, drops trailing slashes,
/// preserves any path prefix, and prepends `http://` when no scheme is present.
pub fn normalize_registry_base_url(
    raw: &str,
) -> std::result::Result<reqwest::Url, SchemaRegistryError> {
    let trimmed = raw.trim().trim_end_matches('/');
    if trimmed.is_empty() {
        return Err(SchemaRegistryError::new(
            SchemaRegistryErrorKind::NotConfigured,
            None,
            None,
            "No Schema Registry URL configured",
        ));
    }
    let with_scheme = if trimmed.contains("://") {
        trimmed.to_string()
    } else {
        format!("http://{trimmed}")
    };
    let url = reqwest::Url::parse(&with_scheme).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidUrl,
            None,
            None,
            format!("Invalid Schema Registry URL: {e}"),
        )
    })?;
    if !url.has_host() || (url.scheme() != "http" && url.scheme() != "https") {
        return Err(SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidUrl,
            None,
            None,
            "Invalid Schema Registry URL: missing host or unsupported scheme",
        ));
    }
    Ok(url)
}

#[derive(Clone)]
pub struct RegistryEndpoint {
    base: reqwest::Url,
    auth: Option<(String, Option<String>)>,
    client: reqwest::Client,
}

impl RegistryEndpoint {
    pub fn from_profile(
        profile: &ClusterProfile,
    ) -> std::result::Result<Self, SchemaRegistryError> {
        let raw_url = profile
            .schema_registry_url
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .ok_or_else(|| {
                SchemaRegistryError::new(
                    SchemaRegistryErrorKind::NotConfigured,
                    None,
                    None,
                    "No Schema Registry URL configured",
                )
            })?;
        let base = normalize_registry_base_url(raw_url)?;
        let auth = profile
            .schema_registry_username
            .as_deref()
            .filter(|u| !u.is_empty())
            .map(|u| (u.to_string(), profile.schema_registry_password.clone()));
        let client = schema_registry_client_builder(profile)
            .timeout(REGISTRY_TIMEOUT)
            .build()
            .map_err(|e| {
                SchemaRegistryError::new(
                    SchemaRegistryErrorKind::InvalidUrl,
                    None,
                    None,
                    format!("Failed to build Schema Registry HTTP client: {e}"),
                )
            })?;
        Ok(Self { base, auth, client })
    }

    pub fn url(&self, segments: &[&str]) -> std::result::Result<reqwest::Url, SchemaRegistryError> {
        let mut url = self.base.clone();
        {
            let mut path_segments = url.path_segments_mut().map_err(|_| {
                SchemaRegistryError::new(
                    SchemaRegistryErrorKind::InvalidUrl,
                    None,
                    None,
                    "Schema Registry URL cannot be a base",
                )
            })?;
            path_segments.pop_if_empty();
            for seg in segments {
                path_segments.push(seg);
            }
        }
        Ok(url)
    }

    async fn get_json_async(
        &self,
        segments: &[&str],
        query: &[(&str, &str)],
    ) -> std::result::Result<serde_json::Value, SchemaRegistryError> {
        let mut url = self.url(segments)?;
        if !query.is_empty() {
            url.query_pairs_mut().extend_pairs(query.iter().copied());
        }
        let mut req = self.client.get(url);
        if let Some((user, pass)) = &self.auth {
            req = req.basic_auth(user, pass.as_deref());
        }
        let resp = req.send().await.map_err(map_reqwest_error)?; // allow_read_only_exception: Schema Registry GET
        parse_json_response(resp).await
    }

    pub fn get_json(
        &self,
        segments: &[&str],
        query: &[(&str, &str)],
    ) -> std::result::Result<serde_json::Value, SchemaRegistryError> {
        crate::kafka_consumer::shared_runtime().block_on(self.get_json_async(segments, query))
    }
}

async fn parse_json_response(
    resp: reqwest::Response,
) -> std::result::Result<serde_json::Value, SchemaRegistryError> {
    let status = resp.status();
    let body = resp.text().await.map_err(map_reqwest_error)?;
    if !status.is_success() {
        return Err(map_status_error(status, &body));
    }
    serde_json::from_str::<serde_json::Value>(&body).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidResponse,
            Some(status.as_u16()),
            None,
            format!("Invalid JSON response from Schema Registry: {e}"),
        )
    })
}

fn map_status_error(status: reqwest::StatusCode, body: &str) -> SchemaRegistryError {
    let code = status.as_u16();
    let kind = match code {
        401 => SchemaRegistryErrorKind::Unauthorized,
        403 => SchemaRegistryErrorKind::Forbidden,
        404 => SchemaRegistryErrorKind::NotFound,
        _ => SchemaRegistryErrorKind::HttpStatus,
    };

    let mut registry_error_code = None;
    let detail = if let Ok(val) = serde_json::from_str::<serde_json::Value>(body) {
        registry_error_code = val.get("error_code").and_then(serde_json::Value::as_i64);
        if let Some(msg) = val
            .get("message")
            .and_then(serde_json::Value::as_str)
            .map(str::trim)
            .filter(|s| !s.is_empty())
        {
            msg.to_string()
        } else {
            truncate_chars(body.trim(), MAX_RAW_BODY_CHARS)
        }
    } else {
        let trimmed = body.trim();
        if trimmed.is_empty() {
            status
                .canonical_reason()
                .unwrap_or("HTTP error")
                .to_string()
        } else {
            truncate_chars(trimmed, MAX_RAW_BODY_CHARS)
        }
    };

    SchemaRegistryError::new(kind, Some(code), registry_error_code, detail)
}

fn map_reqwest_error(err: reqwest::Error) -> SchemaRegistryError {
    let cleaned = err.without_url();
    if cleaned.is_timeout() {
        return SchemaRegistryError::new(
            SchemaRegistryErrorKind::Timeout,
            None,
            None,
            cleaned.to_string(),
        );
    }

    let mut chain = vec![cleaned.to_string()];
    let mut cur: Option<&(dyn StdError + 'static)> = cleaned.source();
    while let Some(src) = cur {
        chain.push(src.to_string());
        cur = src.source();
    }

    let kind = match classify_tls_failure(&chain) {
        TlsFailureClassification::CertificateRejected(_) => {
            SchemaRegistryErrorKind::CertificateRejected
        }
        TlsFailureClassification::Inconclusive(_) => SchemaRegistryErrorKind::Unreachable,
    };

    SchemaRegistryError::new(kind, None, None, chain.join(": "))
}

#[derive(Clone)]
pub struct SchemaProvenance {
    endpoint: RegistryEndpoint,
}

impl SchemaProvenance {
    pub fn from_profile(profile: &ClusterProfile) -> Option<Self> {
        let endpoint = RegistryEndpoint::from_profile(profile).ok()?;
        Some(Self { endpoint })
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
        let id_str = schema_id.to_string();
        match self
            .endpoint
            .get_json_async(&["schemas", "ids", &id_str, "versions"], &[])
            .await
        {
            Ok(entries) => parse_versions_response(entries, schema_id),
            Err(_) => MessageSchema {
                schema_id,
                subject: None,
                version: None,
            },
        }
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

pub(crate) fn schema_registry_client_builder(profile: &ClusterProfile) -> reqwest::ClientBuilder {
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

    if profile.ssl_verification_disabled {
        builder = builder
            .danger_accept_invalid_certs(true)
            .danger_accept_invalid_hostnames(true);
    }

    builder
}

pub fn fetch_subjects(
    profile: ClusterProfile,
) -> std::result::Result<Vec<String>, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    let val = endpoint.get_json(&["subjects"], &[])?;
    serde_json::from_value::<Vec<String>>(val).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidResponse,
            None,
            None,
            format!("Invalid subjects array: {e}"),
        )
    })
}

pub fn fetch_subject_schema(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> std::result::Result<SubjectSchema, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    fetch_subject_schema_with_endpoint(&endpoint, &subject, version)
}

fn fetch_subject_schema_with_endpoint(
    endpoint: &RegistryEndpoint,
    subject: &str,
    version: Option<i32>,
) -> std::result::Result<SubjectSchema, SchemaRegistryError> {
    let version_str = version
        .map(|v| v.to_string())
        .unwrap_or_else(|| "latest".to_string());
    let val = endpoint.get_json(&["subjects", subject, "versions", &version_str], &[])?;
    parse_subject_schema(&val).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidResponse,
            None,
            None,
            e.to_string(),
        )
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectSchemaView {
    pub schema: SubjectSchema,
    pub fields: SchemaFieldModel,
}

/// Fetches a subject version, resolves its references breadth-first (deduplicated by
/// `(subject, version)`, capped at 50 fetches), and builds the type-aware `SchemaFieldModel`.
pub fn fetch_subject_schema_view(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> std::result::Result<SubjectSchemaView, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    let schema = fetch_subject_schema_with_endpoint(&endpoint, &subject, version)?;

    let mut visited: HashSet<(String, i32)> = HashSet::new();
    visited.insert((schema.subject.clone(), schema.version));

    let mut queue: VecDeque<(String, String, i32)> = VecDeque::new();
    for r in &schema.references {
        if visited.insert((r.subject.clone(), r.version)) {
            queue.push_back((r.name.clone(), r.subject.clone(), r.version));
        }
    }

    let mut resolved_refs = Vec::new();
    let mut fetch_count = 0usize;
    while let Some((ref_name, ref_subject, ref_ver)) = queue.pop_front() {
        if fetch_count >= MAX_REFERENCE_FETCHES {
            break;
        }
        fetch_count += 1;
        if let Ok(ref_schema) =
            fetch_subject_schema_with_endpoint(&endpoint, &ref_subject, Some(ref_ver))
        {
            for child in &ref_schema.references {
                if visited.insert((child.subject.clone(), child.version)) {
                    queue.push_back((child.name.clone(), child.subject.clone(), child.version));
                }
            }
            resolved_refs.push(ResolvedReference {
                name: ref_name,
                kind: ref_schema.schema_type,
                schema: ref_schema.schema,
            });
        }
    }

    let fields = schema_fields(schema.schema_type.clone(), &schema.schema, &resolved_refs);
    Ok(SubjectSchemaView { schema, fields })
}

/// Fetches a schema of a subject. `version` selects an exact version, `None`
/// asks for the latest one. A message records the version it was written with,
/// so the inspector can show that version instead of only the current one.
pub fn fetch_schema(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> std::result::Result<String, SchemaRegistryError> {
    Ok(fetch_subject_schema(profile, subject, version)?.schema)
}

/// Version numbers registered for a subject, newest last as the Confluent
/// Registry returns them.
pub fn fetch_schema_versions(
    profile: ClusterProfile,
    subject: String,
) -> std::result::Result<Vec<i32>, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    let val = endpoint.get_json(&["subjects", &subject, "versions"], &[])?;
    serde_json::from_value::<Vec<i32>>(val).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidResponse,
            None,
            None,
            format!("Invalid versions array: {e}"),
        )
    })
}

pub fn fetch_global_compatibility(
    profile: ClusterProfile,
) -> std::result::Result<String, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    let val = endpoint.get_json(&["config"], &[])?;
    parse_compatibility_level(&val).map_err(|e| {
        SchemaRegistryError::new(
            SchemaRegistryErrorKind::InvalidResponse,
            None,
            None,
            e.to_string(),
        )
    })
}

/// Fetches subject-level compatibility. Any HTTP 404 (e.g. error code 40408) means the subject
/// inherits the global configuration and returns `Ok(None)`.
pub fn fetch_subject_compatibility(
    profile: ClusterProfile,
    subject: String,
) -> std::result::Result<Option<String>, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    match endpoint.get_json(&["config", &subject], &[]) {
        Ok(val) => parse_compatibility_level(&val).map(Some).map_err(|e| {
            SchemaRegistryError::new(
                SchemaRegistryErrorKind::InvalidResponse,
                None,
                None,
                e.to_string(),
            )
        }),
        Err(err) if err.kind == SchemaRegistryErrorKind::NotFound => Ok(None),
        Err(err) => Err(err),
    }
}

/// Parses the JSON body returned by Confluent Schema Registry's `/compatibility` endpoint.
pub fn parse_compatibility_response(val: serde_json::Value) -> SchemaCompatibilityResult {
    let is_compatible = val
        .get("is_compatible")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let mut messages = Vec::new();
    if let Some(msgs) = val.get("messages").and_then(|v| v.as_array()) {
        for m in msgs {
            if let Some(s) = m.as_str() {
                messages.push(s.to_string());
            }
        }
    }
    SchemaCompatibilityResult {
        is_compatible,
        messages,
    }
}

/// Checks whether a draft schema is compatible with a subject version in the Schema Registry.
/// This is a read-only query that does not register or mutate schemas.
pub fn check_schema_compatibility(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
    schema: String,
) -> std::result::Result<SchemaCompatibilityResult, SchemaRegistryError> {
    let endpoint = RegistryEndpoint::from_profile(&profile)?;
    let version_str = version
        .map(|v| v.to_string())
        .unwrap_or_else(|| "latest".to_string());
    let url = endpoint.url(&[
        "compatibility",
        "subjects",
        &subject,
        "versions",
        &version_str,
    ])?;

    let val = crate::kafka_consumer::shared_runtime().block_on(async {
        let mut req = endpoint
            .client
            .post(url) // allow_read_only_exception: Schema Registry compatibility check, stores nothing
            .header("Content-Type", "application/vnd.schemaregistry.v1+json");
        if let Some((user, pass)) = &endpoint.auth {
            req = req.basic_auth(user, pass.as_deref());
        }
        let body = serde_json::json!({ "schema": schema });
        let resp = req.json(&body).send().await.map_err(map_reqwest_error)?; // allow_read_only_exception: reqwest HTTP
        parse_json_response(resp).await
    })?;

    Ok(parse_compatibility_response(val))
}

/// Derives and matches associated Kafka topics for a Schema Registry subject.
pub fn resolve_associated_topics_for_subject(
    subject: &str,
    available_topics: &[String],
) -> Vec<String> {
    kafkalyzer_core::schema_model::resolve_associated_topics_for_subject(subject, available_topics)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;

    fn profile_with_registry(url: &str) -> ClusterProfile {
        ClusterProfile {
            name: "test".to_string(),
            bootstrap_servers: "localhost:9092".to_string(),
            schema_registry_url: Some(url.to_string()),
            ..Default::default()
        }
    }

    fn spawn_stub_server(
        responses: Vec<(String, String)>,
    ) -> (String, std::sync::Arc<std::sync::atomic::AtomicUsize>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let hits = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let hits_clone = hits.clone();
        std::thread::spawn(move || {
            for (status_line, body) in responses {
                if let Ok((mut stream, _)) = listener.accept() {
                    hits_clone.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                    let mut buf = [0u8; 2048];
                    let _ = stream.read(&mut buf);
                    let resp = format!(
                        "HTTP/1.1 {status_line}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = stream.write_all(resp.as_bytes());
                }
            }
        });
        (format!("http://{addr}"), hits)
    }

    #[test]
    fn url_normalization_and_segment_encoding() {
        assert_eq!(
            normalize_registry_base_url("  https://registry.example.com/  ")
                .unwrap()
                .as_str(),
            "https://registry.example.com/"
        );
        assert_eq!(
            normalize_registry_base_url("registry.example.com:8081")
                .unwrap()
                .as_str(),
            "http://registry.example.com:8081/"
        );
        let prefixed = normalize_registry_base_url("https://gateway.example.com/sr/").unwrap();
        assert_eq!(prefixed.as_str(), "https://gateway.example.com/sr");
        assert!(normalize_registry_base_url("not a valid url :::").is_err());

        let ep = RegistryEndpoint::from_profile(&profile_with_registry(
            "https://gateway.example.com/sr/",
        ))
        .unwrap();
        let url_slash = ep
            .url(&["subjects", "team/orders-value", "versions", "latest"])
            .unwrap();
        assert_eq!(
            url_slash.path(),
            "/sr/subjects/team%2Forders-value/versions/latest"
        );
        let url_ctx = ep
            .url(&["subjects", ":.prod:orders-value", "versions"])
            .unwrap();
        assert!(
            url_ctx
                .path()
                .contains("/sr/subjects/:.prod:orders-value/versions")
                || url_ctx
                    .path()
                    .contains("/sr/subjects/%3A.prod%3Aorders-value/versions")
        );
    }

    #[test]
    fn http_status_errors_and_secret_redaction_and_compat_409() {
        let (base, _) = spawn_stub_server(vec![
            (
                "401 Unauthorized".to_string(),
                r#"{"error_code":40100,"message":"Unauthorized"}"#.to_string(),
            ),
            (
                "403 Forbidden".to_string(),
                r#"{"error_code":40300,"message":"Forbidden"}"#.to_string(),
            ),
            (
                "404 Not Found".to_string(),
                r#"{"error_code":40401,"message":"Subject not found"}"#.to_string(),
            ),
            ("500 Internal Server Error".to_string(), "boom".to_string()),
            (
                "409 Conflict".to_string(),
                r#"{"error_code":409,"message":"Conflict"}"#.to_string(),
            ),
        ]);

        let err401 = fetch_subjects(profile_with_registry(&base)).unwrap_err();
        assert_eq!(err401.kind, SchemaRegistryErrorKind::Unauthorized);
        assert_eq!(err401.status, Some(401));

        let err403 = fetch_subjects(profile_with_registry(&base)).unwrap_err();
        assert_eq!(err403.kind, SchemaRegistryErrorKind::Forbidden);
        assert_eq!(err403.status, Some(403));

        let err404 =
            fetch_schema(profile_with_registry(&base), "missing".to_string(), None).unwrap_err();
        assert_eq!(err404.kind, SchemaRegistryErrorKind::NotFound);
        assert_eq!(err404.registry_error_code, Some(40401));
        assert!(err404.detail.contains("Subject not found"));

        let err500 = fetch_subjects(profile_with_registry(&base)).unwrap_err();
        assert_eq!(err500.kind, SchemaRegistryErrorKind::HttpStatus);
        assert_eq!(err500.status, Some(500));
        assert_eq!(err500.detail, "boom");

        let err409 = check_schema_compatibility(
            profile_with_registry(&base),
            "orders-value".to_string(),
            None,
            "{}".to_string(),
        )
        .unwrap_err();
        assert_eq!(err409.kind, SchemaRegistryErrorKind::HttpStatus);
        assert_eq!(err409.status, Some(409));

        // Embedded user:secret@ must never appear in error text
        let err_secret =
            fetch_subjects(profile_with_registry("http://user:supersecret@127.0.0.1:1"))
                .unwrap_err();
        assert!(!err_secret.detail.contains("supersecret"));
        assert!(!err_secret.to_string().contains("supersecret"));
    }

    #[test]
    fn reference_bfs_dedupes_and_compatibility_404_returns_none() {
        let orders_body = serde_json::json!({
            "subject": "orders-value",
            "version": 1,
            "id": 10,
            "schemaType": "JSON",
            "schema": r#"{"type":"object","properties":{"a":{"$ref":"a.json"},"b":{"$ref":"b.json"}}}"#,
            "references": [
                {"name": "a.json", "subject": "a-value", "version": 1},
                {"name": "b.json", "subject": "b-value", "version": 1}
            ]
        })
        .to_string();
        let a_body = serde_json::json!({
            "subject": "a-value",
            "version": 1,
            "id": 11,
            "schemaType": "JSON",
            "schema": r#"{"type":"object","properties":{"c":{"$ref":"c.json"}}}"#,
            "references": [
                {"name": "c.json", "subject": "c-value", "version": 1}
            ]
        })
        .to_string();
        let b_body = serde_json::json!({
            "subject": "b-value",
            "version": 1,
            "id": 12,
            "schemaType": "JSON",
            "schema": r#"{"type":"object","properties":{"c":{"$ref":"c.json"}}}"#,
            "references": [
                {"name": "c.json", "subject": "c-value", "version": 1}
            ]
        })
        .to_string();
        let c_body = serde_json::json!({
            "subject": "c-value",
            "version": 1,
            "id": 13,
            "schemaType": "JSON",
            "schema": r#"{"type":"object","properties":{"leaf":{"type":"string"}}}"#
        })
        .to_string();

        let (base, hits) = spawn_stub_server(vec![
            ("200 OK".to_string(), orders_body),
            ("200 OK".to_string(), a_body),
            ("200 OK".to_string(), b_body),
            ("200 OK".to_string(), c_body),
            (
                "404 Not Found".to_string(),
                r#"{"error_code":40408,"message":"Subject does not have subject-level config configured"}"#.to_string(),
            ),
            (
                "403 Forbidden".to_string(),
                r#"{"error_code":40300,"message":"Access denied"}"#.to_string(),
            ),
        ]);

        let view = fetch_subject_schema_view(
            profile_with_registry(&base),
            "orders-value".to_string(),
            None,
        )
        .unwrap();
        // orders + a + b + c = 4 fetches (c fetched once despite being referenced by both a and b)
        assert_eq!(hits.load(std::sync::atomic::Ordering::SeqCst), 4);
        assert!(view.fields.fields.iter().any(|f| f.path == "a.c.leaf"));

        assert_eq!(
            fetch_subject_compatibility(profile_with_registry(&base), "orders-value".to_string())
                .unwrap(),
            None
        );
        let err =
            fetch_subject_compatibility(profile_with_registry(&base), "orders-value".to_string())
                .unwrap_err();
        assert_eq!(err.kind, SchemaRegistryErrorKind::Forbidden);
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

        let schema = provenance.resolve(crate::kafka_consumer::shared_runtime(), 4242);

        assert_eq!(schema.schema_id, 4242);
        assert_eq!(schema.subject, None);
        assert_eq!(schema.version, None);
    }

    #[test]
    fn parse_compatibility_response_handles_success_and_failures() {
        let success_json = serde_json::json!({
            "is_compatible": true
        });
        let res = parse_compatibility_response(success_json);
        assert!(res.is_compatible);
        assert!(res.messages.is_empty());

        let failure_json = serde_json::json!({
            "is_compatible": false,
            "messages": ["Schema field 'id' removed in incompatible mode"]
        });
        let res2 = parse_compatibility_response(failure_json);
        assert!(!res2.is_compatible);
        assert_eq!(
            res2.messages,
            vec!["Schema field 'id' removed in incompatible mode"]
        );
    }

    #[test]
    fn resolve_associated_topics_extracts_correct_topics() {
        let available = vec![
            "orders".to_string(),
            "users".to_string(),
            "notifications".to_string(),
        ];

        let res = resolve_associated_topics_for_subject("orders-value", &available);
        assert_eq!(res, vec!["orders"]);

        let res_key = resolve_associated_topics_for_subject("users-key", &available);
        assert_eq!(res_key, vec!["users"]);

        let res_direct = resolve_associated_topics_for_subject("notifications", &available);
        assert_eq!(res_direct, vec!["notifications"]);
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
        let runtime = crate::kafka_consumer::shared_runtime();

        let first = provenance.resolve(runtime, 9100);
        let second = provenance.resolve(runtime, 9100);
        let third = provenance.resolve(runtime, 9100);

        assert_eq!(first, second);
        assert_eq!(second, third);
        assert_eq!(
            provenance_lookups_for(9100),
            1,
            "three messages of the same schema must not ask the registry three times"
        );
    }

    #[test]
    fn schema_registry_client_verifies_by_default_and_skips_only_when_disabled() {
        use openssl::asn1::Asn1Time;
        use openssl::hash::MessageDigest;
        use openssl::pkey::PKey;
        use openssl::rsa::Rsa;
        use openssl::ssl::{SslAcceptor, SslMethod};
        use openssl::x509::X509Builder;
        use std::io::{Read, Write};
        use std::net::TcpListener;

        let rsa = Rsa::generate(2048).unwrap();
        let pkey = PKey::from_rsa(rsa).unwrap();
        let mut x509 = X509Builder::new().unwrap();
        x509.set_version(2).unwrap();
        x509.set_pubkey(&pkey).unwrap();
        let not_before = Asn1Time::days_from_now(0).unwrap();
        let not_after = Asn1Time::days_from_now(1).unwrap();
        x509.set_not_before(&not_before).unwrap();
        x509.set_not_after(&not_after).unwrap();
        x509.sign(&pkey, MessageDigest::sha256()).unwrap();
        let cert = x509.build();

        let mut acceptor = SslAcceptor::mozilla_intermediate(SslMethod::tls()).unwrap();
        acceptor.set_private_key(&pkey).unwrap();
        acceptor.set_certificate(&cert).unwrap();
        let acceptor = std::sync::Arc::new(acceptor.build());

        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();

        let handle = std::thread::spawn(move || {
            for stream in listener.incoming().take(2).flatten() {
                let acceptor = acceptor.clone();
                std::thread::spawn(move || {
                    if let Ok(mut ssl_stream) = acceptor.accept(stream) {
                        let mut buf = [0u8; 512];
                        let _ = ssl_stream.read(&mut buf);
                        let _ =
                            ssl_stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n[]");
                    }
                });
            }
        });

        let url = format!("https://127.0.0.1:{port}/subjects");
        let rt = crate::kafka_consumer::shared_runtime();

        let verified_profile = ClusterProfile {
            name: "verified".to_string(),
            bootstrap_servers: "localhost:9092".to_string(),
            schema_registry_url: Some(url.clone()),
            ssl_verification_disabled: false,
            ..Default::default()
        };
        let verified_client = schema_registry_client_builder(&verified_profile)
            .build()
            .unwrap();
        let verified_req = verified_client.get(&url).build().unwrap();
        let verified_res = rt.block_on(verified_client.execute(verified_req));
        assert!(
            verified_res.is_err(),
            "self-signed HTTPS registry must be rejected when verification is enabled"
        );

        let insecure_profile = ClusterProfile {
            ssl_verification_disabled: true,
            ..verified_profile
        };
        let insecure_client = schema_registry_client_builder(&insecure_profile)
            .build()
            .unwrap();
        let insecure_req = insecure_client.get(&url).build().unwrap();
        let insecure_res = rt
            .block_on(insecure_client.execute(insecure_req))
            .expect("self-signed HTTPS registry must succeed when verification is disabled");
        assert!(insecure_res.status().is_success());

        drop(handle);
    }
}
