use std::collections::HashSet;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParsedLine {
    Entry {
        line_no: usize,
        key: String,
        value: String,
    },
    Syntax {
        line_no: usize,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PropertyKind {
    Int { min: i64, max: i64 },
    Bool,
    Enum(&'static [&'static str]),
    Text { max_len: usize },
    DebugContexts(&'static [&'static str]),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AllowedProperty {
    pub key: &'static str,
    pub kind: PropertyKind,
}

impl AllowedProperty {
    pub fn value_hint(&self) -> String {
        match self.kind {
            PropertyKind::Int { min, max } => format!("{min}..{max}"),
            PropertyKind::Bool => "true / false".to_string(),
            PropertyKind::Enum(opts) => opts.join(", "),
            PropertyKind::Text { max_len } => format!("ASCII text (1..{max_len} chars)"),
            PropertyKind::DebugContexts(opts) => format!("comma list of: {}", opts.join(", ")),
        }
    }

    pub fn is_valid_value(&self, value: &str) -> bool {
        match self.kind {
            PropertyKind::Int { min, max } => value
                .parse::<i64>()
                .map(|v| v >= min && v <= max)
                .unwrap_or(false),
            PropertyKind::Bool => matches!(value, "true" | "false"),
            PropertyKind::Enum(opts) => opts.contains(&value),
            PropertyKind::Text { max_len } => {
                !value.is_empty()
                    && value.len() <= max_len
                    && value.bytes().all(|b| (0x20..=0x7e).contains(&b))
            }
            PropertyKind::DebugContexts(opts) => {
                let parts: Vec<&str> = value.split(',').map(str::trim).collect();
                !parts.is_empty() && parts.iter().all(|p| !p.is_empty() && opts.contains(p))
            }
        }
    }
}

pub const ALLOWED: &[AllowedProperty] = &[
    AllowedProperty {
        key: "client.id",
        kind: PropertyKind::Text { max_len: 255 },
    },
    AllowedProperty {
        key: "client.rack",
        kind: PropertyKind::Text { max_len: 255 },
    },
    AllowedProperty {
        key: "socket.timeout.ms",
        kind: PropertyKind::Int {
            min: 10,
            max: 300_000,
        },
    },
    AllowedProperty {
        key: "socket.connection.setup.timeout.ms",
        kind: PropertyKind::Int {
            min: 1_000,
            max: 3_600_000,
        },
    },
    AllowedProperty {
        key: "socket.keepalive.enable",
        kind: PropertyKind::Bool,
    },
    AllowedProperty {
        key: "socket.nagle.disable",
        kind: PropertyKind::Bool,
    },
    AllowedProperty {
        key: "socket.send.buffer.bytes",
        kind: PropertyKind::Int {
            min: 0,
            max: 100_000_000,
        },
    },
    AllowedProperty {
        key: "socket.receive.buffer.bytes",
        kind: PropertyKind::Int {
            min: 0,
            max: 100_000_000,
        },
    },
    AllowedProperty {
        key: "connections.max.idle.ms",
        kind: PropertyKind::Int {
            min: 0,
            max: 2_147_483_647,
        },
    },
    AllowedProperty {
        key: "broker.address.family",
        kind: PropertyKind::Enum(&["any", "v4", "v6"]),
    },
    AllowedProperty {
        key: "broker.address.ttl",
        kind: PropertyKind::Int {
            min: 0,
            max: 86_400_000,
        },
    },
    AllowedProperty {
        key: "client.dns.lookup",
        kind: PropertyKind::Enum(&[
            "use_all_dns_ips",
            "resolve_canonical_bootstrap_servers_only",
        ]),
    },
    AllowedProperty {
        key: "reconnect.backoff.ms",
        kind: PropertyKind::Int {
            min: 0,
            max: 10_000,
        },
    },
    AllowedProperty {
        key: "reconnect.backoff.max.ms",
        kind: PropertyKind::Int {
            min: 100,
            max: 3_600_000,
        },
    },
    AllowedProperty {
        key: "retry.backoff.ms",
        kind: PropertyKind::Int {
            min: 1,
            max: 300_000,
        },
    },
    AllowedProperty {
        key: "retry.backoff.max.ms",
        kind: PropertyKind::Int {
            min: 1,
            max: 300_000,
        },
    },
    AllowedProperty {
        key: "metadata.max.age.ms",
        kind: PropertyKind::Int {
            min: 1,
            max: 86_400_000,
        },
    },
    AllowedProperty {
        key: "topic.metadata.refresh.interval.ms",
        kind: PropertyKind::Int {
            min: -1,
            max: 3_600_000,
        },
    },
    AllowedProperty {
        key: "api.version.request.timeout.ms",
        kind: PropertyKind::Int {
            min: 1,
            max: 300_000,
        },
    },
    AllowedProperty {
        key: "fetch.min.bytes",
        kind: PropertyKind::Int {
            min: 1,
            max: 100_000_000,
        },
    },
    AllowedProperty {
        key: "fetch.max.bytes",
        kind: PropertyKind::Int {
            min: 1_000_000,
            max: 2_147_483_135,
        },
    },
    AllowedProperty {
        key: "fetch.error.backoff.ms",
        kind: PropertyKind::Int {
            min: 0,
            max: 300_000,
        },
    },
    AllowedProperty {
        key: "debug",
        kind: PropertyKind::DebugContexts(&[
            "generic", "broker", "topic", "metadata", "feature", "queue", "protocol", "security",
            "fetch", "consumer", "cgrp",
        ]),
    },
];

pub fn find_allowed(key: &str) -> Option<&'static AllowedProperty> {
    ALLOWED.iter().find(|p| p.key == key)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PropertyIssueKind {
    Syntax,
    NotAllowed,
    InvalidValue,
    Duplicate,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PropertyIssue {
    pub line_no: usize,
    pub key: String,
    pub kind: PropertyIssueKind,
    pub allowed: Option<String>,
}

fn has_trailing_unescaped_backslash(s: &str) -> bool {
    let count = s.chars().rev().take_while(|&c| c == '\\').count();
    count % 2 == 1
}

fn unescape_properties_str(raw: &str) -> Option<String> {
    let mut out = String::with_capacity(raw.len());
    let mut chars = raw.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }
        let next = chars.next()?;
        match next {
            '\\' => out.push('\\'),
            '=' => out.push('='),
            ':' => out.push(':'),
            'n' => out.push('\n'),
            't' => out.push('\t'),
            'r' => out.push('\r'),
            'u' => {
                let mut hex = String::with_capacity(4);
                for _ in 0..4 {
                    hex.push(chars.next()?);
                }
                let code = u32::from_str_radix(&hex, 16).ok()?;
                let decoded = char::from_u32(code)?;
                out.push(decoded);
            }
            other => out.push(other),
        }
    }
    Some(out)
}

fn find_unescaped_separator(line: &str) -> Option<usize> {
    let mut escaped = false;
    for (idx, ch) in line.char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if ch == '\\' {
            escaped = true;
            continue;
        }
        if ch == '=' || ch == ':' {
            return Some(idx);
        }
    }
    None
}

/// Parses Java-style `.properties` lines (comments `#`/`!`, `=`/`:`, line continuation `\`,
/// and escapes `\\`, `\=`, `\:`, `\n`, `\t`, `\r`, `\uXXXX`).
pub fn parse_lines(text: &str) -> Vec<ParsedLine> {
    let mut result = Vec::new();
    let mut current: Option<(usize, String)> = None;

    for (idx, raw_line) in text.lines().enumerate() {
        let physical_line_no = idx + 1;
        let line = raw_line.strip_suffix('\r').unwrap_or(raw_line);

        if let Some((start_line_no, mut acc)) = current.take() {
            let trimmed_start = line.trim_start();
            if has_trailing_unescaped_backslash(trimmed_start) {
                let without_slash = &trimmed_start[..trimmed_start.len() - 1];
                acc.push_str(without_slash);
                current = Some((start_line_no, acc));
                continue;
            }
            acc.push_str(trimmed_start);
            result.push(parse_logical_line(start_line_no, &acc));
            continue;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with('!') {
            continue;
        }

        let trimmed_start = line.trim_start();
        if has_trailing_unescaped_backslash(trimmed_start) {
            let without_slash = &trimmed_start[..trimmed_start.len() - 1];
            current = Some((physical_line_no, without_slash.to_string()));
        } else {
            result.push(parse_logical_line(physical_line_no, trimmed_start));
        }
    }

    if let Some((start_line_no, _)) = current {
        result.push(ParsedLine::Syntax {
            line_no: start_line_no,
        });
    }

    result
}

fn parse_logical_line(line_no: usize, line: &str) -> ParsedLine {
    let Some(sep_idx) = find_unescaped_separator(line) else {
        return ParsedLine::Syntax { line_no };
    };
    let raw_key = line[..sep_idx].trim();
    let raw_val = line[sep_idx + 1..].trim();
    if raw_key.is_empty() {
        return ParsedLine::Syntax { line_no };
    }
    let Some(key) = unescape_properties_str(raw_key) else {
        return ParsedLine::Syntax { line_no };
    };
    let Some(value) = unescape_properties_str(raw_val) else {
        return ParsedLine::Syntax { line_no };
    };
    let key = key.trim().to_string();
    if key.is_empty() {
        return ParsedLine::Syntax { line_no };
    }
    ParsedLine::Entry {
        line_no,
        key,
        value,
    }
}

/// Validates additional client properties text against `ALLOWED`.
pub fn validate(text: &str) -> Vec<PropertyIssue> {
    let mut issues = Vec::new();
    let mut seen = HashSet::new();

    for item in parse_lines(text) {
        match item {
            ParsedLine::Syntax { line_no } => issues.push(PropertyIssue {
                line_no,
                key: String::new(),
                kind: PropertyIssueKind::Syntax,
                allowed: None,
            }),
            ParsedLine::Entry {
                line_no,
                key,
                value,
            } => {
                if !seen.insert(key.clone()) {
                    issues.push(PropertyIssue {
                        line_no,
                        key,
                        kind: PropertyIssueKind::Duplicate,
                        allowed: None,
                    });
                    continue;
                }
                let Some(spec) = find_allowed(&key) else {
                    issues.push(PropertyIssue {
                        line_no,
                        key,
                        kind: PropertyIssueKind::NotAllowed,
                        allowed: None,
                    });
                    continue;
                };
                if !spec.is_valid_value(&value) {
                    issues.push(PropertyIssue {
                        line_no,
                        key,
                        kind: PropertyIssueKind::InvalidValue,
                        allowed: Some(spec.value_hint()),
                    });
                }
            }
        }
    }

    issues
}

/// Returns only allowlisted entries with valid values; first occurrence wins.
pub fn effective(entries: &[(String, String)]) -> Vec<(&'static str, String)> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();

    for (key, value) in entries {
        let Some(spec) = find_allowed(key) else {
            continue;
        };
        if !spec.is_valid_value(value) {
            continue;
        }
        if seen.insert(spec.key) {
            out.push((spec.key, value.clone()));
        }
    }

    out
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MappedProfileFields {
    pub bootstrap_servers: Option<String>,
    pub security_protocol: Option<String>,
    pub mechanism: Option<String>,
    pub sasl_username: Option<String>,
    pub sasl_password: Option<String>,
    pub sasl_kerberos_service_name: Option<String>,
    pub sasl_kerberos_keytab: Option<String>,
    pub sasl_kerberos_principal: Option<String>,
    pub ssl_truststore_location: Option<String>,
    pub ssl_truststore_password: Option<String>,
    pub ssl_keystore_location: Option<String>,
    pub ssl_keystore_password: Option<String>,
    pub ssl_pem_certificate_location: Option<String>,
    pub ssl_pem_key_location: Option<String>,
    pub ssl_pem_key_password: Option<String>,
    pub schema_registry_url: Option<String>,
    pub schema_registry_username: Option<String>,
    pub schema_registry_password: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SkipReason {
    NotAllowed,
    Unsupported,
    Placeholder,
    VerificationOverride,
    InvalidValue,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkippedProperty {
    pub key: String,
    pub reason: SkipReason,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ClientPropertiesMapping {
    pub fields: MappedProfileFields,
    pub extras: Vec<(String, String)>,
    pub skipped: Vec<SkippedProperty>,
}

enum JaasModule {
    PlainOrScram {
        username: Option<String>,
        password: Option<String>,
    },
    Krb5 {
        key_tab: Option<String>,
        principal: Option<String>,
        service_name: Option<String>,
    },
    UnsupportedModule,
}

fn parse_jaas_config(raw: &str) -> Result<JaasModule, ()> {
    let trimmed = raw.trim();
    let without_semi = trimmed.strip_suffix(';').unwrap_or(trimmed).trim();
    if without_semi.is_empty() {
        return Err(());
    }

    let mut chars = without_semi.char_indices().peekable();

    let read_word = |it: &mut std::iter::Peekable<std::str::CharIndices<'_>>| -> Option<String> {
        while let Some(&(_, c)) = it.peek() {
            if c.is_whitespace() {
                it.next();
            } else {
                break;
            }
        }
        let mut s = String::new();
        while let Some(&(_, c)) = it.peek() {
            if c.is_whitespace() || c == '=' || c == ';' {
                break;
            }
            s.push(c);
            it.next();
        }
        if s.is_empty() {
            None
        } else {
            Some(s)
        }
    };

    let module_class = read_word(&mut chars).ok_or(())?;
    let control_flag = read_word(&mut chars).ok_or(())?;
    if !matches!(
        control_flag.to_ascii_lowercase().as_str(),
        "required" | "requisite" | "sufficient" | "optional"
    ) {
        return Err(());
    }

    let mut pairs: Vec<(String, String)> = Vec::new();
    loop {
        while let Some(&(_, c)) = chars.peek() {
            if c.is_whitespace() {
                chars.next();
            } else {
                break;
            }
        }
        if chars.peek().is_none() {
            break;
        }
        let key = read_word(&mut chars).ok_or(())?;
        while let Some(&(_, c)) = chars.peek() {
            if c.is_whitespace() {
                chars.next();
            } else {
                break;
            }
        }
        match chars.next() {
            Some((_, '=')) => {}
            _ => return Err(()),
        }
        while let Some(&(_, c)) = chars.peek() {
            if c.is_whitespace() {
                chars.next();
            } else {
                break;
            }
        }
        let value = match chars.peek().copied() {
            Some((_, '"')) => {
                chars.next();
                let mut val = String::new();
                let mut closed = false;
                while let Some((_, c)) = chars.next() {
                    if c == '\\' {
                        let (_, escaped) = chars.next().ok_or(())?;
                        val.push(escaped);
                    } else if c == '"' {
                        closed = true;
                        break;
                    } else {
                        val.push(c);
                    }
                }
                if !closed {
                    return Err(());
                }
                val
            }
            Some(_) => read_word(&mut chars).ok_or(())?,
            None => return Err(()),
        };
        pairs.push((key, value));
    }

    let simple_name = module_class.rsplit('.').next().unwrap_or(&module_class);
    match simple_name {
        "PlainLoginModule" | "ScramLoginModule" => {
            let mut username = None;
            let mut password = None;
            for (k, v) in pairs {
                match k.as_str() {
                    "username" => username = Some(v),
                    "password" => password = Some(v),
                    _ => {}
                }
            }
            Ok(JaasModule::PlainOrScram { username, password })
        }
        "Krb5LoginModule" => {
            let mut key_tab = None;
            let mut principal = None;
            let mut service_name = None;
            for (k, v) in pairs {
                match k.as_str() {
                    "keyTab" => key_tab = Some(v),
                    "principal" => principal = Some(v),
                    "serviceName" => service_name = Some(v),
                    _ => {}
                }
            }
            Ok(JaasModule::Krb5 {
                key_tab,
                principal,
                service_name,
            })
        }
        _ => Ok(JaasModule::UnsupportedModule),
    }
}

fn is_jks_path(path: &str) -> bool {
    path.trim().to_ascii_lowercase().ends_with(".jks")
}

/// Maps a Kafka `client.properties` file into profile fields, allowlisted extras,
/// and skipped entries with reasons (never echoing skipped values).
pub fn map_client_properties(text: &str) -> ClientPropertiesMapping {
    let mut out = ClientPropertiesMapping::default();
    let mut pending_key_password: Option<String> = None;
    let mut seen_extras = HashSet::new();

    for item in parse_lines(text) {
        let ParsedLine::Entry { key, value, .. } = item else {
            continue;
        };

        if value.contains("${") {
            out.skipped.push(SkippedProperty {
                key,
                reason: SkipReason::Placeholder,
            });
            continue;
        }

        match key.as_str() {
            "bootstrap.servers" => {
                if value.trim().is_empty() {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                } else {
                    out.fields.bootstrap_servers = Some(value);
                }
            }
            "security.protocol" => {
                let upper = value.trim().to_ascii_uppercase();
                if matches!(
                    upper.as_str(),
                    "PLAINTEXT" | "SSL" | "SASL_PLAINTEXT" | "SASL_SSL"
                ) {
                    out.fields.security_protocol = Some(upper);
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                }
            }
            "sasl.mechanism" | "sasl.mechanisms" => {
                let upper = value.trim().to_ascii_uppercase();
                if matches!(
                    upper.as_str(),
                    "PLAIN"
                        | "SCRAM-SHA-256"
                        | "SCRAM-SHA-512"
                        | "GSSAPI"
                        | "OAUTHBEARER"
                        | "AWS_MSK_IAM"
                ) {
                    out.fields.mechanism = Some(upper);
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                }
            }
            "sasl.jaas.config" => match parse_jaas_config(&value) {
                Ok(JaasModule::PlainOrScram { username, password }) => {
                    if let Some(u) = username {
                        out.fields.sasl_username = Some(u);
                    }
                    if let Some(p) = password {
                        out.fields.sasl_password = Some(p);
                    }
                }
                Ok(JaasModule::Krb5 {
                    key_tab,
                    principal,
                    service_name,
                }) => {
                    if let Some(kt) = key_tab {
                        out.fields.sasl_kerberos_keytab = Some(kt);
                    }
                    if let Some(p) = principal {
                        out.fields.sasl_kerberos_principal = Some(p);
                    }
                    if let Some(sn) = service_name {
                        out.fields.sasl_kerberos_service_name = Some(sn);
                    }
                }
                Ok(JaasModule::UnsupportedModule) => {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::Unsupported,
                    });
                }
                Err(()) => {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                }
            },
            "sasl.username" => out.fields.sasl_username = Some(value),
            "sasl.password" => out.fields.sasl_password = Some(value),
            "sasl.kerberos.service.name" => out.fields.sasl_kerberos_service_name = Some(value),
            "sasl.kerberos.keytab" => out.fields.sasl_kerberos_keytab = Some(value),
            "sasl.kerberos.principal" => out.fields.sasl_kerberos_principal = Some(value),
            "ssl.truststore.location" => {
                if is_jks_path(&value) {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::Unsupported,
                    });
                } else {
                    out.fields.ssl_truststore_location = Some(value);
                }
            }
            "ssl.ca.location" => {
                if out.fields.ssl_truststore_location.is_none() {
                    out.fields.ssl_truststore_location = Some(value);
                }
            }
            "ssl.truststore.password" => out.fields.ssl_truststore_password = Some(value),
            "ssl.keystore.location" => {
                if is_jks_path(&value) {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::Unsupported,
                    });
                } else {
                    out.fields.ssl_keystore_location = Some(value);
                }
            }
            "ssl.keystore.password" => out.fields.ssl_keystore_password = Some(value),
            "ssl.certificate.location" => out.fields.ssl_pem_certificate_location = Some(value),
            "ssl.key.location" => out.fields.ssl_pem_key_location = Some(value),
            "ssl.key.password" => pending_key_password = Some(value),
            "schema.registry.url" => out.fields.schema_registry_url = Some(value),
            "basic.auth.user.info" | "schema.registry.basic.auth.user.info" => {
                if let Some((user, pass)) = value.split_once(':') {
                    out.fields.schema_registry_username = Some(user.to_string());
                    out.fields.schema_registry_password = Some(pass.to_string());
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                }
            }
            "ssl.truststore.type" | "ssl.keystore.type" => {
                let upper = value.trim().to_ascii_uppercase();
                if matches!(upper.as_str(), "PKCS12" | "PEM") {
                    // Consumed without setting a dedicated field.
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::Unsupported,
                    });
                }
            }
            "basic.auth.credentials.source" => {
                if value.trim().eq_ignore_ascii_case("USER_INFO") {
                    // Consumed without setting a dedicated field.
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::Unsupported,
                    });
                }
            }
            "ssl.endpoint.identification.algorithm" => {
                let lower = value.trim().to_ascii_lowercase();
                if lower.is_empty() || lower == "none" {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::VerificationOverride,
                    });
                } else if lower == "https" {
                    // Consumed; verification stays enabled by default.
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::InvalidValue,
                    });
                }
            }
            "enable.ssl.certificate.verification" => {
                if value.trim().eq_ignore_ascii_case("false") {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::VerificationOverride,
                    });
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::NotAllowed,
                    });
                }
            }
            _ => {
                if let Some(spec) = find_allowed(&key) {
                    if spec.is_valid_value(&value) {
                        if seen_extras.insert(spec.key) {
                            out.extras.push((spec.key.to_string(), value));
                        }
                    } else {
                        out.skipped.push(SkippedProperty {
                            key,
                            reason: SkipReason::InvalidValue,
                        });
                    }
                } else {
                    out.skipped.push(SkippedProperty {
                        key,
                        reason: SkipReason::NotAllowed,
                    });
                }
            }
        }
    }

    if let Some(kp) = pending_key_password {
        if out.fields.ssl_pem_key_location.is_some() {
            out.fields.ssl_pem_key_password = Some(kp);
        } else {
            out.skipped.push(SkippedProperty {
                key: "ssl.key.password".to_string(),
                reason: SkipReason::Unsupported,
            });
        }
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_lines_handles_comments_separators_continuations_and_escapes() {
        let input = "\
# hash comment
! bang comment

client.id = my-app
client.rack : rack\\:1\\=a
socket.timeout.ms = 15000
continuation.key = part1 \\
    part2 \\\\\\
  \\n\\t\\u0041
bad_line_without_separator
bad_unicode = \\u12ZZ
";
        let parsed = parse_lines(input);
        assert_eq!(
            parsed,
            vec![
                ParsedLine::Entry {
                    line_no: 4,
                    key: "client.id".to_string(),
                    value: "my-app".to_string(),
                },
                ParsedLine::Entry {
                    line_no: 5,
                    key: "client.rack".to_string(),
                    value: "rack:1=a".to_string(),
                },
                ParsedLine::Entry {
                    line_no: 6,
                    key: "socket.timeout.ms".to_string(),
                    value: "15000".to_string(),
                },
                ParsedLine::Entry {
                    line_no: 7,
                    key: "continuation.key".to_string(),
                    value: "part1 part2 \\\n\tA".to_string(),
                },
                ParsedLine::Syntax { line_no: 10 },
                ParsedLine::Syntax { line_no: 11 },
            ]
        );
    }

    #[test]
    fn validate_checks_all_kinds_duplicates_and_forbidden_keys() {
        let input = "\
client.id=kafkalyzer-alice
client.id=duplicate
socket.timeout.ms=-5
socket.keepalive.enable=yes
broker.address.family=v9
client.rack=ok-rack
debug=generic,all
enable.idempotence=x
group.id=reader
enable.auto.commit=x
enable.ssl.certificate.verification=false
bad line
";
        let issues = validate(input);
        assert_eq!(
            issues,
            vec![
                PropertyIssue {
                    line_no: 2,
                    key: "client.id".to_string(),
                    kind: PropertyIssueKind::Duplicate,
                    allowed: None,
                },
                PropertyIssue {
                    line_no: 3,
                    key: "socket.timeout.ms".to_string(),
                    kind: PropertyIssueKind::InvalidValue,
                    allowed: Some("10..300000".to_string()),
                },
                PropertyIssue {
                    line_no: 4,
                    key: "socket.keepalive.enable".to_string(),
                    kind: PropertyIssueKind::InvalidValue,
                    allowed: Some("true / false".to_string()),
                },
                PropertyIssue {
                    line_no: 5,
                    key: "broker.address.family".to_string(),
                    kind: PropertyIssueKind::InvalidValue,
                    allowed: Some("any, v4, v6".to_string()),
                },
                PropertyIssue {
                    line_no: 7,
                    key: "debug".to_string(),
                    kind: PropertyIssueKind::InvalidValue,
                    allowed: Some(
                        "comma list of: generic, broker, topic, metadata, feature, queue, protocol, security, fetch, consumer, cgrp"
                            .to_string()
                    ),
                },
                PropertyIssue {
                    line_no: 8,
                    key: "enable.idempotence".to_string(),
                    kind: PropertyIssueKind::NotAllowed,
                    allowed: None,
                },
                PropertyIssue {
                    line_no: 9,
                    key: "group.id".to_string(),
                    kind: PropertyIssueKind::NotAllowed,
                    allowed: None,
                },
                PropertyIssue {
                    line_no: 10,
                    key: "enable.auto.commit".to_string(),
                    kind: PropertyIssueKind::NotAllowed,
                    allowed: None,
                },
                PropertyIssue {
                    line_no: 11,
                    key: "enable.ssl.certificate.verification".to_string(),
                    kind: PropertyIssueKind::NotAllowed,
                    allowed: None,
                },
                PropertyIssue {
                    line_no: 12,
                    key: String::new(),
                    kind: PropertyIssueKind::Syntax,
                    allowed: None,
                },
            ]
        );
    }

    #[test]
    fn effective_keeps_first_valid_allowlisted_entry() {
        let entries = vec![
            ("client.id".to_string(), "first".to_string()),
            ("client.id".to_string(), "second".to_string()),
            ("socket.timeout.ms".to_string(), "-1".to_string()),
            ("group.id".to_string(), "forbidden".to_string()),
            ("debug".to_string(), "broker,msg".to_string()),
            ("debug".to_string(), "broker,security".to_string()),
        ];
        assert_eq!(
            effective(&entries),
            vec![
                ("client.id", "first".to_string()),
                ("debug", "broker,security".to_string()),
            ]
        );
    }

    #[test]
    fn map_client_properties_handles_scram_jaas_jks_placeholders_and_overrides() {
        let input = "\
bootstrap.servers=b1:9092,b2:9092
security.protocol=sasl_ssl
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"alice\" password=\"s3cr3t\";
ssl.truststore.type=JKS
ssl.truststore.location=/etc/kafka/trust.jks
sasl.password=${file:/secrets.properties:pw}
ssl.endpoint.identification.algorithm=
basic.auth.credentials.source=USER_INFO
basic.auth.user.info=sr_user:sr_pass
schema.registry.url=https://sr.example.com
acks=all
group.id=x
client.id=kafkalyzer-import
";
        let mapped = map_client_properties(input);
        assert_eq!(
            mapped.fields.bootstrap_servers.as_deref(),
            Some("b1:9092,b2:9092")
        );
        assert_eq!(mapped.fields.security_protocol.as_deref(), Some("SASL_SSL"));
        assert_eq!(mapped.fields.mechanism.as_deref(), Some("SCRAM-SHA-512"));
        assert_eq!(mapped.fields.sasl_username.as_deref(), Some("alice"));
        assert_eq!(mapped.fields.sasl_password.as_deref(), Some("s3cr3t"));
        assert_eq!(
            mapped.fields.schema_registry_url.as_deref(),
            Some("https://sr.example.com")
        );
        assert_eq!(
            mapped.fields.schema_registry_username.as_deref(),
            Some("sr_user")
        );
        assert_eq!(
            mapped.fields.schema_registry_password.as_deref(),
            Some("sr_pass")
        );
        assert_eq!(
            mapped.extras,
            vec![("client.id".to_string(), "kafkalyzer-import".to_string())]
        );
        assert_eq!(
            mapped.skipped,
            vec![
                SkippedProperty {
                    key: "ssl.truststore.type".to_string(),
                    reason: SkipReason::Unsupported,
                },
                SkippedProperty {
                    key: "ssl.truststore.location".to_string(),
                    reason: SkipReason::Unsupported,
                },
                SkippedProperty {
                    key: "sasl.password".to_string(),
                    reason: SkipReason::Placeholder,
                },
                SkippedProperty {
                    key: "ssl.endpoint.identification.algorithm".to_string(),
                    reason: SkipReason::VerificationOverride,
                },
                SkippedProperty {
                    key: "acks".to_string(),
                    reason: SkipReason::NotAllowed,
                },
                SkippedProperty {
                    key: "group.id".to_string(),
                    reason: SkipReason::NotAllowed,
                },
            ]
        );
    }

    #[test]
    fn map_client_properties_handles_plain_krb5_and_librdkafka_keys() {
        let input = "\
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=bob password=\"p@ss\";
sasl.kerberos.service.name=kafka
ssl.key.password=secret
";
        let mapped = map_client_properties(input);
        assert_eq!(mapped.fields.sasl_username.as_deref(), Some("bob"));
        assert_eq!(mapped.fields.sasl_password.as_deref(), Some("p@ss"));
        assert_eq!(
            mapped.fields.sasl_kerberos_service_name.as_deref(),
            Some("kafka")
        );
        assert_eq!(mapped.fields.ssl_pem_key_password, None);
        assert_eq!(
            mapped.skipped,
            vec![SkippedProperty {
                key: "ssl.key.password".to_string(),
                reason: SkipReason::Unsupported,
            }]
        );

        let krb = "\
sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required keyTab=\"/etc/krb5.keytab\" principal=\"svc/host@REALM\" serviceName=kafka;
";
        let mapped_krb = map_client_properties(krb);
        assert_eq!(
            mapped_krb.fields.sasl_kerberos_keytab.as_deref(),
            Some("/etc/krb5.keytab")
        );
        assert_eq!(
            mapped_krb.fields.sasl_kerberos_principal.as_deref(),
            Some("svc/host@REALM")
        );
        assert_eq!(
            mapped_krb.fields.sasl_kerberos_service_name.as_deref(),
            Some("kafka")
        );
    }
}
