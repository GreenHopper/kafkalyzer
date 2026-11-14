/// Result of matching a query against a candidate string.
class FuzzyMatch {
  const FuzzyMatch({required this.score, required this.matchedIndices});

  final double score;
  final List<int> matchedIndices;
}

bool _isSeparator(int codeUnit) {
  return codeUnit == 0x2E /* . */ ||
      codeUnit == 0x2D /* - */ ||
      codeUnit == 0x5F /* _ */ ||
      codeUnit == 0x2F /* / */ ||
      codeUnit == 0x20 /* space */;
}

bool _isWordStart(String candidate, int index) {
  if (index == 0) return true;
  final prev = candidate[index - 1];
  final curr = candidate[index];
  if (_isSeparator(prev.codeUnitAt(0))) return true;
  // CamelCase boundary: lowercase followed by uppercase.
  return prev.toLowerCase() == prev &&
      prev.toUpperCase() != prev &&
      curr.toUpperCase() == curr &&
      curr.toLowerCase() != curr;
}

/// Case-insensitive subsequence fuzzy matcher with word-boundary and
/// contiguous-run scoring.
///
/// Returns `null` when [query] is not a case-insensitive subsequence of
/// [candidate]. An empty [query] returns a zero-score match with empty indices.
FuzzyMatch? fuzzyMatch(String query, String candidate) {
  if (query.isEmpty) {
    return const FuzzyMatch(score: 0, matchedIndices: []);
  }
  if (candidate.isEmpty || query.length > candidate.length) {
    return null;
  }

  final qLower = query.toLowerCase();
  final cLower = candidate.toLowerCase();

  // 1. Greedy leftmost pass.
  final indices = <int>[];
  var cIdx = 0;
  for (var qIdx = 0; qIdx < qLower.length; qIdx++) {
    final ch = qLower[qIdx];
    while (cIdx < cLower.length && cLower[cIdx] != ch) {
      cIdx++;
    }
    if (cIdx >= cLower.length) return null;
    indices.add(cIdx);
    cIdx++;
  }

  // 2. Single backtrack-free improvement pass: if the match did not start at a
  //    word boundary, see if there is a word-boundary match later in the string.
  if (!_isWordStart(candidate, indices.first)) {
    final firstChar = qLower[0];
    for (var start = indices.first + 1; start < cLower.length; start++) {
      if (cLower[start] == firstChar && _isWordStart(candidate, start)) {
        final alt = <int>[start];
        var scan = start + 1;
        var ok = true;
        for (var qIdx = 1; qIdx < qLower.length; qIdx++) {
          final ch = qLower[qIdx];
          while (scan < cLower.length && cLower[scan] != ch) {
            scan++;
          }
          if (scan >= cLower.length) {
            ok = false;
            break;
          }
          alt.add(scan);
          scan++;
        }
        if (ok) {
          indices
            ..clear()
            ..addAll(alt);
          break;
        }
      }
    }
  }

  // 3. Score computation (design D7).
  var score = 0.0;
  if (cLower == qLower) {
    score += 100.0;
  } else if (cLower.startsWith(qLower)) {
    score += 60.0;
  }

  score -= indices.first * 1.0;

  for (var i = 0; i < indices.length; i++) {
    final pos = indices[i];
    if (_isWordStart(candidate, pos)) {
      score += 10.0;
    }
    if (i > 0) {
      final prev = indices[i - 1];
      if (pos == prev + 1) {
        score += 15.0;
      } else {
        score -= (pos - prev - 1) * 0.5;
      }
    }
  }

  return FuzzyMatch(score: score, matchedIndices: indices);
}
