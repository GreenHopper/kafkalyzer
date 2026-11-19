import 'dart:convert';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';

enum JsonPreviewTokenKind { key, string, number, literal, punctuation, plain }

class JsonPreviewToken {
  final JsonPreviewTokenKind kind;
  final String text;

  const JsonPreviewToken(this.kind, this.text);
}

class TextPreviewUtils {
  /// Safely truncates the payload for preview purposes, replacing newlines with spaces.
  /// If the text is longer than [maxLength], it truncates and appends an ellipsis.
  /// When [filterNulls] is true and [payload] is valid JSON, keys with null values are omitted.
  static String getPayloadPreview(
    String? payload, {
    int maxLength = 300,
    bool filterNulls = true,
  }) {
    if (payload == null || payload.isEmpty) {
      return "";
    }

    String content = payload;
    final trimmed = content.trimLeft();
    bool isValidJson = false;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      if (filterNulls) {
        try {
          final decoded = json.decode(content);
          isValidJson = true;
          if (decoded is Map) {
            final pruned = _pruneNulls(decoded);
            content = json.encode(pruned);
          } else if (decoded is List) {
            final prunedList = decoded.map((item) {
              if (item is Map) return _pruneNulls(item);
              return item;
            }).toList();
            content = json.encode(prunedList);
          }
        } catch (_) {
          // Fallback to raw string if decoding fails
        }
      } else {
        try {
          final decoded = json.decode(content);
          isValidJson = true;
          content = json.encode(decoded);
        } catch (_) {
          // Fallback to raw string if decoding fails
        }
      }
    }

    if (isValidJson) {
      return _formatSpacedJsonPreview(content, maxLength: maxLength);
    }

    String preview = content;
    if (preview.length > maxLength) {
      preview = "${preview.substring(0, maxLength)}...";
    }

    // Replace newlines and multiple spaces for a compact single-line preview
    return preview.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Inserts one space after every `:` and `,` outside string literals,
  /// stopping once [maxLength] output characters are reached.
  static String _formatSpacedJsonPreview(
    String compactJson, {
    required int maxLength,
  }) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;
    bool truncated = false;

    for (int i = 0; i < compactJson.length; i++) {
      if (buffer.length >= maxLength) {
        truncated = true;
        break;
      }
      final ch = compactJson[i];
      buffer.write(ch);

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
      } else {
        if (ch == '"') {
          inString = true;
        } else if (ch == ':' || ch == ',') {
          final hasNext = i + 1 < compactJson.length;
          if (hasNext && compactJson[i + 1] != ' ') {
            if (buffer.length < maxLength) {
              buffer.write(' ');
            } else {
              truncated = true;
              break;
            }
          }
        }
      }
    }

    final result = buffer.toString().trim();
    return truncated ? '$result...' : result;
  }

  static Map<String, dynamic> _pruneNulls(Map map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val == null) continue;
      if (val is Map) {
        result[key] = _pruneNulls(val);
      } else if (val is List) {
        result[key] = val.map((e) => e is Map ? _pruneNulls(e) : e).toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }

  /// Tokenizes a single-line preview into JSON syntax tokens (or a single
  /// [JsonPreviewTokenKind.plain] token if the preview does not start like JSON).
  static List<JsonPreviewToken> tokenizePreview(String preview) {
    if (preview.isEmpty) return const [];
    final trimmed = preview.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return [JsonPreviewToken(JsonPreviewTokenKind.plain, preview)];
    }

    final tokens = <JsonPreviewToken>[];
    int i = 0;
    final len = preview.length;

    while (i < len) {
      final ch = preview[i];

      if (ch == '"') {
        final start = i;
        i++;
        bool escaped = false;
        while (i < len) {
          final c = preview[i];
          i++;
          if (escaped) {
            escaped = false;
          } else if (c == r'\') {
            escaped = true;
          } else if (c == '"') {
            break;
          }
        }
        int lookahead = i;
        while (lookahead < len && preview[lookahead] == ' ') {
          lookahead++;
        }
        final isKey = lookahead < len && preview[lookahead] == ':';
        tokens.add(
          JsonPreviewToken(
            isKey ? JsonPreviewTokenKind.key : JsonPreviewTokenKind.string,
            preview.substring(start, i),
          ),
        );
      } else if (ch == '{' ||
          ch == '}' ||
          ch == '[' ||
          ch == ']' ||
          ch == ':' ||
          ch == ',' ||
          ch == ' ') {
        final start = i;
        while (i < len) {
          final c = preview[i];
          if (c == '{' ||
              c == '}' ||
              c == '[' ||
              c == ']' ||
              c == ':' ||
              c == ',' ||
              c == ' ') {
            i++;
          } else {
            break;
          }
        }
        tokens.add(
          JsonPreviewToken(
            JsonPreviewTokenKind.punctuation,
            preview.substring(start, i),
          ),
        );
      } else if (ch == '-' ||
          (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
        final start = i;
        i++;
        while (i < len) {
          final c = preview[i];
          final code = c.codeUnitAt(0);
          if ((code >= 48 && code <= 57) ||
              c == '.' ||
              c == 'e' ||
              c == 'E' ||
              c == '+' ||
              c == '-') {
            i++;
          } else {
            break;
          }
        }
        tokens.add(
          JsonPreviewToken(
            JsonPreviewTokenKind.number,
            preview.substring(start, i),
          ),
        );
      } else if (preview.startsWith('true', i) ||
          preview.startsWith('false', i) ||
          preview.startsWith('null', i)) {
        final word = preview.startsWith('false', i)
            ? 'false'
            : preview.substring(i, i + 4);
        tokens.add(JsonPreviewToken(JsonPreviewTokenKind.literal, word));
        i += word.length;
      } else {
        final start = i;
        i++;
        while (i < len) {
          final c = preview[i];
          if (c == '"' ||
              c == '{' ||
              c == '}' ||
              c == '[' ||
              c == ']' ||
              c == ':' ||
              c == ',' ||
              c == ' ') {
            break;
          }
          i++;
        }
        tokens.add(
          JsonPreviewToken(
            JsonPreviewTokenKind.plain,
            preview.substring(start, i),
          ),
        );
      }
    }

    return tokens;
  }

  /// Computes the WCAG 2.1 contrast ratio between [foreground] and [background].
  static double contrastRatio(Color foreground, Color background) {
    final l1 = foreground.computeLuminance();
    final l2 = background.computeLuminance();
    final brightest = math.max(l1, l2);
    final darkest = math.min(l1, l2);
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Ensures [candidate] (composited over [background] if semi-transparent)
  /// meets at least [minRatio] (default 4.5 for WCAG AA) against [background],
  /// blending toward [fallback] if necessary.
  static Color ensureContrast(
    Color candidate,
    Color background,
    Color fallback, {
    double minRatio = 4.5,
  }) {
    final opaqueBg = background.a < 1.0
        ? Color.alphaBlend(background, const Color(0xFF000000))
        : background;
    final opaqueCandidate = candidate.a < 1.0
        ? Color.alphaBlend(candidate, opaqueBg)
        : candidate;
    final opaqueFallback = fallback.a < 1.0
        ? Color.alphaBlend(fallback, opaqueBg)
        : fallback;

    if (contrastRatio(opaqueCandidate, opaqueBg) >= minRatio) {
      return opaqueCandidate;
    }
    for (int step = 1; step <= 10; step++) {
      final blended = Color.lerp(opaqueCandidate, opaqueFallback, step / 10.0)!;
      if (contrastRatio(blended, opaqueBg) >= minRatio) {
        return blended;
      }
    }
    if (contrastRatio(opaqueFallback, opaqueBg) >= minRatio) {
      return opaqueFallback;
    }
    final white = const Color(0xFFFFFFFF);
    final black = const Color(0xFF000000);
    return contrastRatio(white, opaqueBg) >= contrastRatio(black, opaqueBg)
        ? white
        : black;
  }

  /// Builds syntax-tinted and search-highlighted [TextSpan]s for a payload preview.
  static List<TextSpan> buildSyntaxHighlightedPreviewSpans({
    required String preview,
    required String searchPhrase,
    required TextStyle baseStyle,
    required ColorScheme colorScheme,
    required Color backgroundColor,
    bool isSelected = false,
  }) {
    final tokens = tokenizePreview(preview);
    final fallbackColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final keyColor = ensureContrast(
      isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      backgroundColor,
      fallbackColor,
    );
    final stringColor = ensureContrast(
      isSelected ? colorScheme.primary : colorScheme.primary,
      backgroundColor,
      fallbackColor,
    );
    final numberColor = ensureContrast(
      isSelected ? colorScheme.tertiary : colorScheme.tertiary,
      backgroundColor,
      fallbackColor,
    );
    final literalColor = ensureContrast(
      isSelected ? colorScheme.secondary : colorScheme.secondary,
      backgroundColor,
      fallbackColor,
    );
    final punctuationColor = ensureContrast(
      isSelected
          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.85)
          : colorScheme.onSurfaceVariant,
      backgroundColor,
      fallbackColor,
    );

    final highlightBg = isSelected
        ? colorScheme.tertiaryContainer
        : colorScheme.primaryContainer;
    final highlightFg = isSelected
        ? colorScheme.onTertiaryContainer
        : colorScheme.onPrimaryContainer;
    final highlightStyle = baseStyle.copyWith(
      backgroundColor: highlightBg,
      color: highlightFg,
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    for (final token in tokens) {
      final tokenStyle = switch (token.kind) {
        JsonPreviewTokenKind.key => baseStyle.copyWith(
          color: keyColor,
          fontWeight: FontWeight.w600,
        ),
        JsonPreviewTokenKind.string => baseStyle.copyWith(color: stringColor),
        JsonPreviewTokenKind.number => baseStyle.copyWith(
          color: numberColor,
          fontWeight: FontWeight.w500,
        ),
        JsonPreviewTokenKind.literal => baseStyle.copyWith(
          color: literalColor,
          fontWeight: FontWeight.w600,
        ),
        JsonPreviewTokenKind.punctuation => baseStyle.copyWith(
          color: punctuationColor,
        ),
        JsonPreviewTokenKind.plain => baseStyle.copyWith(color: keyColor),
      };

      spans.addAll(
        HighlightTextUtils.buildHighlightedSpans(
          token.text,
          searchPhrase,
          tokenStyle,
          highlightStyle,
        ),
      );
    }

    return spans;
  }
}
