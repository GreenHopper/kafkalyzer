import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';

/// Pure-Dart fake for [ClusterProfileTools] used in widget and controller tests.
class FakeClusterProfileTools implements ClusterProfileTools {
  FakeClusterProfileTools({
    this.bootstrapValidator,
    this.extraPropertiesValidator,
    this.allowedList,
    this.clientPropertiesParser,
  });

  final List<BootstrapServerIssue> Function(String value)? bootstrapValidator;
  final List<ExtraPropertyIssue> Function(String text)?
  extraPropertiesValidator;
  final List<AllowedExtraProperty>? allowedList;
  final Future<ClientPropertiesPreview> Function(String content)?
  clientPropertiesParser;

  @override
  List<BootstrapServerIssue> validateBootstrapServers(String value) {
    if (bootstrapValidator != null) {
      return bootstrapValidator!(value);
    }
    final entries = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (entries.isEmpty) {
      return const [
        BootstrapServerIssue(
          entry: '',
          kind: BootstrapServerIssueKind.noEntries,
        ),
      ];
    }
    final issues = <BootstrapServerIssue>[];
    for (final entry in entries) {
      if (entry.contains('://')) {
        issues.add(
          BootstrapServerIssue(
            entry: entry,
            kind: BootstrapServerIssueKind.schemeNotAllowed,
          ),
        );
        continue;
      }
      final idx = entry.lastIndexOf(':');
      if (idx <= 0 || (entry.startsWith('[') && !entry.contains(']:'))) {
        issues.add(
          BootstrapServerIssue(
            entry: entry,
            kind: BootstrapServerIssueKind.missingPort,
          ),
        );
        continue;
      }
      final host = entry.substring(0, idx);
      final portStr = entry.substring(idx + 1);
      final port = int.tryParse(portStr);
      if (port == null || port < 1 || port > 65535) {
        issues.add(
          BootstrapServerIssue(
            entry: entry,
            kind: BootstrapServerIssueKind.invalidPort,
          ),
        );
        continue;
      }
      if (host.contains(RegExp(r'\s')) || host.contains('/')) {
        issues.add(
          BootstrapServerIssue(
            entry: entry,
            kind: BootstrapServerIssueKind.invalidHost,
          ),
        );
      }
    }
    return issues;
  }

  @override
  List<ExtraPropertyIssue> validateExtraProperties(String text) {
    if (extraPropertiesValidator != null) {
      return extraPropertiesValidator!(text);
    }
    final issues = <ExtraPropertyIssue>[];
    final seen = <String>{};
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('!')) {
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) {
        issues.add(
          ExtraPropertyIssue(
            line: BigInt.from(i + 1),
            key: '',
            kind: ExtraPropertyIssueKind.syntax,
          ),
        );
        continue;
      }
      final key = line.substring(0, eq).trim();
      final val = line.substring(eq + 1).trim();
      if (!seen.add(key)) {
        issues.add(
          ExtraPropertyIssue(
            line: BigInt.from(i + 1),
            key: key,
            kind: ExtraPropertyIssueKind.duplicate,
          ),
        );
        continue;
      }
      if (key == 'client.id' || key == 'client.rack') {
        if (val.isEmpty) {
          issues.add(
            ExtraPropertyIssue(
              line: BigInt.from(i + 1),
              key: key,
              kind: ExtraPropertyIssueKind.invalidValue,
              allowed: 'ASCII text (1..255 chars)',
            ),
          );
        }
      } else if (key == 'socket.timeout.ms') {
        final parsed = int.tryParse(val);
        if (parsed == null || parsed < 10 || parsed > 300000) {
          issues.add(
            ExtraPropertyIssue(
              line: BigInt.from(i + 1),
              key: key,
              kind: ExtraPropertyIssueKind.invalidValue,
              allowed: '10..300000',
            ),
          );
        }
      } else {
        issues.add(
          ExtraPropertyIssue(
            line: BigInt.from(i + 1),
            key: key,
            kind: ExtraPropertyIssueKind.notAllowed,
          ),
        );
      }
    }
    return issues;
  }

  @override
  List<AllowedExtraProperty> allowedExtraProperties() =>
      allowedList ??
      const [
        AllowedExtraProperty(
          key: 'client.id',
          valueHint: 'ASCII text (1..255 chars)',
        ),
        AllowedExtraProperty(
          key: 'client.rack',
          valueHint: 'ASCII text (1..255 chars)',
        ),
        AllowedExtraProperty(key: 'socket.timeout.ms', valueHint: '10..300000'),
      ];

  @override
  Future<ClientPropertiesPreview> parseClientProperties(String content) async {
    if (clientPropertiesParser != null) {
      return clientPropertiesParser!(content);
    }
    return const ClientPropertiesPreview(
      profile: ClusterProfile(
        name: '',
        bootstrapServers: '',
        tlsVerification: TlsVerification.unreviewed,
      ),
      extraProperties: '',
      skipped: [],
    );
  }
}
