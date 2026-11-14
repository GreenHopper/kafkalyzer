/// Classification of a failed TLS connection probe based on librdkafka
/// error and log lines.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TlsFailureClassification {
    CertificateRejected(String),
    Inconclusive(String),
}

const REJECTION_PATTERNS: &[&str] = &[
    "certificate verify failed",
    "self-signed certificate",
    "self signed certificate",
    "unable to get local issuer certificate",
    "unable to verify the first certificate",
    "hostname mismatch",
    "ip address mismatch",
    "subject name does not match",
    "certificate has expired",
    "certificate is not yet valid",
    "certificate revoked",
    "unknown ca",
    "bad certificate",
    "untrusted root",
    "wrong version number",
    "ssl_error_ssl",
];

/// Classifies captured librdkafka error/log lines from a failed TLS probe.
///
/// Returns `CertificateRejected` when any line matches a known certificate or
/// hostname verification failure pattern; otherwise returns `Inconclusive`.
pub fn classify_tls_failure(lines: &[String]) -> TlsFailureClassification {
    for line in lines {
        let lower = line.to_ascii_lowercase();
        if REJECTION_PATTERNS.iter().any(|p| lower.contains(p)) {
            return TlsFailureClassification::CertificateRejected(line.trim().to_string());
        }
    }

    let summary = lines
        .iter()
        .rev()
        .find(|l| !l.trim().is_empty())
        .map(|l| l.trim().to_string())
        .unwrap_or_default();
    TlsFailureClassification::Inconclusive(summary)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_untrusted_ca_as_rejected() {
        let lines = vec![
            "FAIL [thrd:sasl_ssl://broker:9093/bootstrap]: sasl_ssl://broker:9093/bootstrap: SSL handshake failed: error:0A000086:SSL routines:tls_post_process_server_certificate:certificate verify failed (after 12ms in state CONNECT)".to_string(),
        ];
        assert!(matches!(
            classify_tls_failure(&lines),
            TlsFailureClassification::CertificateRejected(_)
        ));
    }

    #[test]
    fn classifies_self_signed_and_issuer_errors_as_rejected() {
        for msg in [
            "OpenSSL error: self-signed certificate in certificate chain",
            "verify error:num=20:unable to get local issuer certificate",
            "Server certificate Hostname mismatch for broker.internal",
            "SSL handshake failed: certificate has expired",
        ] {
            let result = classify_tls_failure(&[msg.to_string()]);
            assert_eq!(
                result,
                TlsFailureClassification::CertificateRejected(msg.to_string())
            );
        }
    }

    #[test]
    fn classifies_network_and_auth_failures_as_inconclusive() {
        for msg in [
            "Connect to ipv4#127.0.0.1:9093 failed: Connection refused",
            "Local: Broker transport failure (timed out)",
            "SASL authentication error: Authentication failed",
        ] {
            let result = classify_tls_failure(&[msg.to_string()]);
            assert_eq!(
                result,
                TlsFailureClassification::Inconclusive(msg.to_string())
            );
        }
    }

    #[test]
    fn classifies_empty_input_as_inconclusive() {
        assert_eq!(
            classify_tls_failure(&[]),
            TlsFailureClassification::Inconclusive(String::new())
        );
    }
}
