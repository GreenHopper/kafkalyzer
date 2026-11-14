/// Splits a comma-separated quick-filter string into trimmed, non-empty terms.
List<String> splitFilterTerms(String text) {
  return text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
