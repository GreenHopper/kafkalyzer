// Guard test for hard-coded user-facing strings and languageCode checks.
//
// Known limits (by design, see design.md D4):
// - Strings built in helper methods and passed positionally to custom widgets
//   (e.g. `_buildHeaderCell(0, 'Group ID')`) are not detected.
// - Strings thrown as exceptions and shown later are not detected.
// - Unreachable `l10n?.key ?? 'English'` fallbacks are intentionally ignored.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:flutter_test/flutter_test.dart';

class GuardFinding {
  const GuardFinding({
    required this.path,
    required this.line,
    required this.literalSource,
    required this.kind,
  });

  final String path;
  final int line;
  final String literalSource;
  final String kind;

  @override
  String toString() => '$path:$line: $literalSource ($kind)';
}

class AllowlistEntry {
  const AllowlistEntry({
    required this.path,
    required this.literalSource,
    required this.reason,
  });

  final String path;
  final String literalSource;
  final String reason;
}

const _uiTextConstructors = {'Text', 'SelectableText', 'TextSpan'};

const _uiNamedArguments = {
  'tooltip',
  'message',
  'label',
  'labelText',
  'hintText',
  'helperText',
  'errorText',
  'title',
  'subtitle',
  'dialogTitle',
  'semanticLabel',
  'semanticsLabel',
  'content',
  'text',
  'confirmText',
  'cancelText',
  'helpText',
  'prefixText',
  'suffixText',
  'counterText',
};

const _errorFieldNames = {'_error', '_errorMessage', 'errorMessage'};

const _l10nIdentifiers = {'l10n', 'loc', 'localizations'};

final _wordLetters = RegExp(r'[A-Za-z]{2,}');

bool _hasWordLetters(String literalPart) => _wordLetters.hasMatch(literalPart);

bool _isTextLiteral(AstNode node) {
  if (node is SimpleStringLiteral) {
    return _hasWordLetters(node.value);
  }
  if (node is AdjacentStrings) {
    return node.strings.any(_isTextLiteral);
  }
  if (node is StringInterpolation) {
    final buffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
      }
    }
    return _hasWordLetters(buffer.toString());
  }
  return false;
}

bool _isL10nNullAwareFallbackTarget(Expression expr) {
  if (expr is PropertyAccess) {
    final target = expr.target;
    if (target is SimpleIdentifier && _l10nIdentifiers.contains(target.name)) {
      return true;
    }
    if (target != null && _isAppLocalizationsOf(target)) {
      return true;
    }
  } else if (expr is PrefixedIdentifier) {
    if (_l10nIdentifiers.contains(expr.prefix.name)) {
      return true;
    }
  } else if (expr is MethodInvocation) {
    final target = expr.target;
    if (target is SimpleIdentifier && _l10nIdentifiers.contains(target.name)) {
      return true;
    }
    if (target != null && _isAppLocalizationsOf(target)) {
      return true;
    }
  }
  return false;
}

bool _isAppLocalizationsOf(Expression expr) {
  if (expr is MethodInvocation && expr.methodName.name == 'of') {
    final target = expr.target;
    if (target is SimpleIdentifier && target.name == 'AppLocalizations') {
      return true;
    }
  }
  return false;
}

class _HardcodedStringsVisitor extends RecursiveAstVisitor<void> {
  _HardcodedStringsVisitor({
    required this.path,
    required this.lineInfo,
    required this.isPresentationPath,
  });

  final String path;
  final LineInfo lineInfo;
  final bool isPresentationPath;
  final List<GuardFinding> findings = [];
  int _clipboardDataDepth = 0;

  void _inspectUiExpression(Expression? expr, String kind) {
    if (expr == null) return;
    if (expr is ParenthesizedExpression) {
      _inspectUiExpression(expr.expression, kind);
      return;
    }
    if (expr is ConditionalExpression) {
      _inspectUiExpression(expr.thenExpression, kind);
      _inspectUiExpression(expr.elseExpression, kind);
      return;
    }
    if (expr is BinaryExpression && expr.operator.lexeme == '??') {
      _inspectUiExpression(expr.leftOperand, kind);
      if (!_isL10nNullAwareFallbackTarget(expr.leftOperand)) {
        _inspectUiExpression(expr.rightOperand, kind);
      }
      return;
    }
    if (expr is StringLiteral && _isTextLiteral(expr)) {
      final line = lineInfo.getLocation(expr.offset).lineNumber;
      findings.add(
        GuardFinding(
          path: path,
          line: line,
          literalSource: expr.toSource(),
          kind: kind,
        ),
      );
    }
  }

  void _inspectArguments(String? invocationName, ArgumentList args) {
    final isClipboardData = invocationName == 'ClipboardData';
    if (isClipboardData) _clipboardDataDepth++;
    try {
      Expression? firstPositional;
      for (final arg in args.arguments) {
        if (arg is NamedArgument) {
          final name = arg.name.lexeme;
          if (_clipboardDataDepth == 0 && _uiNamedArguments.contains(name)) {
            _inspectUiExpression(arg.argumentExpression, 'named:$name');
          }
        } else if (arg is Expression) {
          firstPositional ??= arg;
        }
      }
      if (_clipboardDataDepth == 0 &&
          invocationName != null &&
          _uiTextConstructors.contains(invocationName)) {
        _inspectUiExpression(firstPositional, 'ctor:$invocationName');
      }
    } finally {
      if (isClipboardData) _clipboardDataDepth--;
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    final isClipboard = typeName == 'ClipboardData';
    _inspectArguments(typeName, node.argumentList);
    if (isClipboard) _clipboardDataDepth++;
    try {
      super.visitInstanceCreationExpression(node);
    } finally {
      if (isClipboard) _clipboardDataDepth--;
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final isClipboard = name == 'ClipboardData';
    _inspectArguments(name, node.argumentList);
    if (isClipboard) _clipboardDataDepth++;
    try {
      super.visitMethodInvocation(node);
    } finally {
      if (isClipboard) _clipboardDataDepth--;
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (isPresentationPath) {
      final left = node.leftHandSide;
      String? targetName;
      if (left is SimpleIdentifier) {
        targetName = left.name;
      } else if (left is PropertyAccess) {
        targetName = left.propertyName.name;
      } else if (left is PrefixedIdentifier) {
        targetName = left.identifier.name;
      }
      if (targetName != null && _errorFieldNames.contains(targetName)) {
        _inspectUiExpression(node.rightHandSide, 'assign:$targetName');
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '==' || op == '!=') {
      if (_isLanguageCodeAccess(node.leftOperand) ||
          _isLanguageCodeAccess(node.rightOperand)) {
        final line = lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          GuardFinding(
            path: path,
            line: line,
            literalSource: node.toSource(),
            kind: 'languageCode',
          ),
        );
      }
    }
    super.visitBinaryExpression(node);
  }

  bool _isLanguageCodeAccess(Expression expr) {
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'languageCode';
    }
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'languageCode';
    }
    return false;
  }
}

List<GuardFinding> scanSource(String path, String content) {
  final result = parseString(content: content, throwIfDiagnostics: false);
  final normalized = path.replaceAll('\\', '/');
  final visitor = _HardcodedStringsVisitor(
    path: normalized,
    lineInfo: result.lineInfo,
    isPresentationPath: normalized.contains('/presentation/'),
  );
  result.unit.visitChildren(visitor);
  return visitor.findings;
}

List<AllowlistEntry> parseAllowlist(String content) {
  final entries = <AllowlistEntry>[];
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = rawLine.split('\t');
    if (parts.length < 3) {
      throw FormatException(
        'Invalid allowlist line (expected 3 tab-separated columns): $rawLine',
      );
    }
    entries.add(
      AllowlistEntry(
        path: parts[0].trim(),
        literalSource: parts[1].trim(),
        reason: parts.sublist(2).join('\t').trim(),
      ),
    );
  }
  return entries;
}

({List<GuardFinding> unexpected, List<AllowlistEntry> stale}) evaluateFindings(
  List<GuardFinding> findings,
  List<AllowlistEntry> allowlist,
) {
  final matchedEntries = <int>{};
  final unexpected = <GuardFinding>[];

  for (final finding in findings) {
    var matched = false;
    for (var i = 0; i < allowlist.length; i++) {
      final entry = allowlist[i];
      if (entry.path == finding.path &&
          entry.literalSource == finding.literalSource) {
        matched = true;
        matchedEntries.add(i);
        break;
      }
    }
    if (!matched) {
      unexpected.add(finding);
    }
  }

  final stale = <AllowlistEntry>[];
  for (var i = 0; i < allowlist.length; i++) {
    if (!matchedEntries.contains(i)) {
      stale.add(allowlist[i]);
    }
  }

  return (unexpected: unexpected, stale: stale);
}

List<GuardFinding> scanLibSrc() {
  final root = Directory('lib/src');
  final allFindings = <GuardFinding>[];
  final files = root.listSync(recursive: true).whereType<File>().where((f) {
    final p = f.path.replaceAll('\\', '/');
    return p.endsWith('.dart') &&
        !p.startsWith('lib/src/rust/') &&
        !p.endsWith('.g.dart') &&
        !p.endsWith('.freezed.dart');
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    allFindings.addAll(scanSource(normalizedPath, file.readAsStringSync()));
  }
  return allFindings;
}

void main() {
  group('hardcoded_strings_guard unit cases', () {
    test('detects literal in Text', () {
      final findings = scanSource('lib/src/foo.dart', '''
Widget build() => Text('Hello World');
''');
      expect(findings, hasLength(1));
      expect(findings.first.literalSource, "'Hello World'");
    });

    test('detects literal in tooltip:', () {
      final findings = scanSource('lib/src/foo.dart', '''
Widget build() => IconButton(tooltip: 'Refresh topics', onPressed: null, icon: Icon(Icons.refresh));
''');
      expect(findings, hasLength(1));
      expect(findings.first.literalSource, "'Refresh topics'");
    });

    test('detects literal in ternary inside Text', () {
      final findings = scanSource('lib/src/foo.dart', '''
Widget build(bool ok) => Text(ok ? 'Connected' : 'Disconnected');
''');
      expect(findings.map((f) => f.literalSource).toList(), [
        "'Connected'",
        "'Disconnected'",
      ]);
    });

    test('ignores l10n?.x ?? Fallback', () {
      final findings = scanSource('lib/src/foo.dart', '''
Widget build(dynamic l10n) => Text(l10n?.apply ?? 'Apply');
''');
      expect(findings, isEmpty);
    });

    test('ignores ClipboardData(text: x)', () {
      final findings = scanSource('lib/src/foo.dart', '''
void copy() => ClipboardData(text: 'Copied raw text');
''');
      expect(findings, isEmpty);
    });

    test('detects languageCode == de', () {
      final findings = scanSource('lib/src/foo.dart', '''
bool check(dynamic locale) => locale.languageCode == 'de';
''');
      expect(findings, hasLength(1));
      expect(findings.first.kind, 'languageCode');
    });

    test('reports stale allowlist entry', () {
      final result = evaluateFindings(const [], const [
        AllowlistEntry(
          path: 'lib/src/foo.dart',
          literalSource: "'Old text'",
          reason: 'stale',
        ),
      ]);
      expect(result.stale, hasLength(1));
    });
  });

  test(
    'no unallowlisted hard-coded user-facing strings or languageCode checks in lib/src',
    () {
      final allowlistFile = File('test/l10n/hardcoded_strings_allowlist.txt');
      final allowlist = parseAllowlist(allowlistFile.readAsStringSync());
      final findings = scanLibSrc();
      final result = evaluateFindings(findings, allowlist);

      if (result.unexpected.isNotEmpty) {
        final buf = StringBuffer(
          'Unexpected hard-coded UI strings or languageCode checks (${result.unexpected.length}):\n',
        );
        for (final f in result.unexpected) {
          buf.writeln('  $f');
        }
        fail(buf.toString());
      }
      if (result.stale.isNotEmpty) {
        final buf = StringBuffer(
          'Stale allowlist entries (${result.stale.length}):\n',
        );
        for (final e in result.stale) {
          buf.writeln('  ${e.path}\t${e.literalSource}');
        }
        fail(buf.toString());
      }
    },
  );
}
