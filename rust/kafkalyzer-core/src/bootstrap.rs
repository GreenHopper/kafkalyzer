use std::fmt;
use std::net::Ipv6Addr;

/// A validated bootstrap `host:port` entry.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostPort {
    pub host: String,
    pub port: u16,
    pub raw: String,
}

impl fmt::Display for HostPort {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.host.contains(':') {
            write!(f, "[{}]:{}", self.host, self.port)
        } else {
            write!(f, "{}:{}", self.host, self.port)
        }
    }
}

/// Reason a bootstrap server entry could not be parsed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BootstrapIssueKind {
    NoEntries,
    MissingPort,
    InvalidPort,
    InvalidHost,
    SchemeNotAllowed,
}

/// A validation issue for a single bootstrap server entry.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BootstrapIssue {
    pub kind: BootstrapIssueKind,
    pub entry: String,
}

/// Parses a comma-separated Kafka `bootstrap.servers` string into `HostPort` entries.
pub fn parse_bootstrap_servers(input: &str) -> Result<Vec<HostPort>, Vec<BootstrapIssue>> {
    let entries: Vec<&str> = input
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();

    if entries.is_empty() {
        return Err(vec![BootstrapIssue {
            kind: BootstrapIssueKind::NoEntries,
            entry: String::new(),
        }]);
    }

    let mut parsed = Vec::with_capacity(entries.len());
    let mut issues = Vec::new();

    for entry in entries {
        match parse_single_entry(entry) {
            Ok(hp) => parsed.push(hp),
            Err(issue) => issues.push(issue),
        }
    }

    if issues.is_empty() {
        Ok(parsed)
    } else {
        Err(issues)
    }
}

/// Parses a single trimmed bootstrap server entry.
pub fn parse_single_entry(entry: &str) -> Result<HostPort, BootstrapIssue> {
    if entry.contains("://") {
        return Err(BootstrapIssue {
            kind: BootstrapIssueKind::SchemeNotAllowed,
            entry: entry.to_string(),
        });
    }

    if entry.starts_with('[') {
        let Some(end_bracket) = entry.find(']') else {
            return Err(BootstrapIssue {
                kind: BootstrapIssueKind::InvalidHost,
                entry: entry.to_string(),
            });
        };
        let host = &entry[1..end_bracket];
        if host.is_empty() || host.parse::<Ipv6Addr>().is_err() {
            return Err(BootstrapIssue {
                kind: BootstrapIssueKind::InvalidHost,
                entry: entry.to_string(),
            });
        }
        let rest = &entry[end_bracket + 1..];
        let Some(port_str) = rest.strip_prefix(':') else {
            return Err(BootstrapIssue {
                kind: BootstrapIssueKind::MissingPort,
                entry: entry.to_string(),
            });
        };
        let port = parse_port(port_str, entry)?;
        return Ok(HostPort {
            host: host.to_string(),
            port,
            raw: entry.to_string(),
        });
    }

    let Some((host, port_str)) = entry.rsplit_once(':') else {
        return Err(BootstrapIssue {
            kind: BootstrapIssueKind::MissingPort,
            entry: entry.to_string(),
        });
    };

    if !is_valid_host(host) {
        return Err(BootstrapIssue {
            kind: BootstrapIssueKind::InvalidHost,
            entry: entry.to_string(),
        });
    }

    let port = parse_port(port_str, entry)?;
    Ok(HostPort {
        host: host.to_string(),
        port,
        raw: entry.to_string(),
    })
}

fn is_valid_host(host: &str) -> bool {
    !host.is_empty()
        && host
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-'))
}

fn parse_port(port_str: &str, entry: &str) -> Result<u16, BootstrapIssue> {
    if port_str.is_empty() || !port_str.bytes().all(|b| b.is_ascii_digit()) {
        return Err(BootstrapIssue {
            kind: BootstrapIssueKind::InvalidPort,
            entry: entry.to_string(),
        });
    }
    match port_str.parse::<u16>() {
        Ok(p) if p > 0 => Ok(p),
        _ => Err(BootstrapIssue {
            kind: BootstrapIssueKind::InvalidPort,
            entry: entry.to_string(),
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_valid_host_ports_and_ipv6() {
        let res = parse_bootstrap_servers(" broker1.internal:9092 , [::1]:9093 , 10.0.0.1:9094 , ")
            .unwrap();
        assert_eq!(
            res,
            vec![
                HostPort {
                    host: "broker1.internal".to_string(),
                    port: 9092,
                    raw: "broker1.internal:9092".to_string(),
                },
                HostPort {
                    host: "::1".to_string(),
                    port: 9093,
                    raw: "[::1]:9093".to_string(),
                },
                HostPort {
                    host: "10.0.0.1".to_string(),
                    port: 9094,
                    raw: "10.0.0.1:9094".to_string(),
                },
            ]
        );
    }

    #[test]
    fn rejects_empty_input_with_no_entries() {
        assert_eq!(
            parse_bootstrap_servers(" ,  , "),
            Err(vec![BootstrapIssue {
                kind: BootstrapIssueKind::NoEntries,
                entry: String::new(),
            }])
        );
    }

    #[test]
    fn rejects_schemes_missing_ports_invalid_ports_and_invalid_hosts() {
        let err = parse_bootstrap_servers(
            "PLAINTEXT://localhost:9092, host.9092, broker:0, broker:65536, bad host:9092, user@host:9092, [::1]",
        )
        .unwrap_err();
        assert_eq!(
            err,
            vec![
                BootstrapIssue {
                    kind: BootstrapIssueKind::SchemeNotAllowed,
                    entry: "PLAINTEXT://localhost:9092".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::MissingPort,
                    entry: "host.9092".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::InvalidPort,
                    entry: "broker:0".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::InvalidPort,
                    entry: "broker:65536".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::InvalidHost,
                    entry: "bad host:9092".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::InvalidHost,
                    entry: "user@host:9092".to_string(),
                },
                BootstrapIssue {
                    kind: BootstrapIssueKind::MissingPort,
                    entry: "[::1]".to_string(),
                },
            ]
        );
    }
}
