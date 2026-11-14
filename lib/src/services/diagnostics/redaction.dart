const int _maxRedactedLength = 4096;
const String _truncationMarker = ' …[truncated]';

final RegExp _pemPrivateKeyPattern = RegExp(
  r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
);

final RegExp _urlUserInfoPattern = RegExp(
  r'([a-zA-Z][a-zA-Z0-9+.-]*://)([^\s/@:]+:[^\s/@]+@)',
);

final RegExp _authHeaderPattern = RegExp(
  r'\b(Authorization\s*:\s*)(?:Bearer|Basic|Negotiate|Digest)\s+\S+',
  caseSensitive: false,
);

final RegExp _bearerTokenPattern = RegExp(
  r'\b(Bearer\s+)\S+',
  caseSensitive: false,
);

const String _secretKeys =
    r'sasl\.password|ssl\.key\.password|ssl\.(?:key|trust)store\.password|basic\.auth\.user\.info|sasl\.jaas\.config|password|passwd|secret|token|api[._-]?key';

final RegExp _jsonSecretPattern = RegExp(
  '("($_secretKeys)"\\s*:\\s*)"[^"]*"',
  caseSensitive: false,
);

final RegExp _jaasConfigPattern = RegExp(
  r'(sasl\.jaas\.config\s*[=:]\s*)[^;\n\r]+;?',
  caseSensitive: false,
);

final RegExp _kvSecretPattern = RegExp(
  '(\\b(?:$_secretKeys)\\s*[=:]\\s*)(?:"[^"]*"|\'[^\']*\'|\\S+)',
  caseSensitive: false,
);

String redact(String input) {
  var result = input;
  result = result.replaceAll(_pemPrivateKeyPattern, '[private key redacted]');
  result = result.replaceAllMapped(_urlUserInfoPattern, (m) => '${m[1]}***@');
  result = result.replaceAllMapped(_authHeaderPattern, (m) => '${m[1]}***');
  result = result.replaceAllMapped(_bearerTokenPattern, (m) => '${m[1]}***');
  result = result.replaceAllMapped(_jsonSecretPattern, (m) => '${m[1]}"***"');
  result = result.replaceAllMapped(_jaasConfigPattern, (m) => '${m[1]}***');
  result = result.replaceAllMapped(_kvSecretPattern, (m) => '${m[1]}***');

  if (result.length > _maxRedactedLength) {
    final keep = _maxRedactedLength - _truncationMarker.length;
    result = '${result.substring(0, keep)}$_truncationMarker';
  }
  return result;
}

String formatSafeError(Object error) {
  if (error is FormatException) {
    final offset = error.offset != null ? ' (at offset ${error.offset})' : '';
    return redact('FormatException: ${error.message}$offset');
  }
  return redact(error.toString());
}
