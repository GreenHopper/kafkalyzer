/// Classification of cluster connection failures so the UI can show a
/// localized title together with the raw cause.
enum ConnectionErrorKind {
  invalidBootstrapServers,
  tlsVerificationFailed,
  validationFailed,
  brokerTransport,
  connectionRefused,
  other,
}

/// Structured connection error exposed by [ActiveConnectionController].
class ConnectionError {
  const ConnectionError({required this.kind, this.detail = ''});

  final ConnectionErrorKind kind;
  final String detail;
}

/// Classifies a raw connection exception into a [ConnectionError] with a
/// non-empty first-line detail when available.
ConnectionError classifyConnectionError(Object error) {
  final errorString = error.toString();
  final firstLine = errorString.split('\n').first.trim();

  if (errorString.contains('BrokerTransportFailure')) {
    return ConnectionError(
      kind: ConnectionErrorKind.brokerTransport,
      detail: firstLine.isEmpty ? errorString : firstLine,
    );
  }
  if (errorString.toLowerCase().contains('connection refused')) {
    return ConnectionError(
      kind: ConnectionErrorKind.connectionRefused,
      detail: firstLine.isEmpty ? errorString : firstLine,
    );
  }
  if (errorString.contains('AnyhowException')) {
    final match = RegExp(r'AnyhowException\((.*?)\)').firstMatch(errorString);
    final extracted = match?.group(1)?.trim();
    final detail = (extracted != null && extracted.isNotEmpty)
        ? extracted
        : (firstLine.isNotEmpty ? firstLine : 'AnyhowException');
    return ConnectionError(kind: ConnectionErrorKind.other, detail: detail);
  }
  return ConnectionError(
    kind: ConnectionErrorKind.other,
    detail: firstLine.isNotEmpty ? firstLine : error.runtimeType.toString(),
  );
}
