import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';

enum DiffLineType { unchanged, added, removed }

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLine({
    required this.type,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

List<DiffLine> computeLineDiff(String oldText, String newText) {
  final oldFormatted = _prettyFormatJson(oldText);
  final newFormatted = _prettyFormatJson(newText);
  final oldLines = oldFormatted.split('\n');
  final newLines = newFormatted.split('\n');
  final m = oldLines.length;
  final n = newLines.length;

  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i < m; i++) {
    for (var j = 0; j < n; j++) {
      if (oldLines[i] == newLines[j]) {
        dp[i + 1][j + 1] = dp[i][j] + 1;
      } else {
        dp[i + 1][j + 1] = dp[i + 1][j] > dp[i][j + 1]
            ? dp[i + 1][j]
            : dp[i][j + 1];
      }
    }
  }

  var i = m;
  var j = n;
  final result = <DiffLine>[];
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
      result.add(
        DiffLine(
          type: DiffLineType.unchanged,
          text: oldLines[i - 1],
          oldLineNumber: i,
          newLineNumber: j,
        ),
      );
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      result.add(
        DiffLine(
          type: DiffLineType.added,
          text: newLines[j - 1],
          newLineNumber: j,
        ),
      );
      j--;
    } else if (i > 0) {
      result.add(
        DiffLine(
          type: DiffLineType.removed,
          text: oldLines[i - 1],
          oldLineNumber: i,
        ),
      );
      i--;
    }
  }

  return result.reversed.toList();
}

String _prettyFormatJson(String text) {
  try {
    final decoded = jsonDecode(text);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return text;
  }
}

class SchemaDiffDialog extends StatefulWidget {
  final ClusterProfile profile;
  final String subject;
  final int? initialBaseVersion;
  final int? initialCompareVersion;
  final SchemaController? controller;
  final ValueChanged<String>? onNavigateToTopic;

  const SchemaDiffDialog({
    super.key,
    required this.profile,
    required this.subject,
    this.initialBaseVersion,
    this.initialCompareVersion,
    this.controller,
    this.onNavigateToTopic,
  });

  @override
  State<SchemaDiffDialog> createState() => _SchemaDiffDialogState();
}

class _SchemaDiffDialogState extends State<SchemaDiffDialog>
    with SingleTickerProviderStateMixin {
  late final SchemaController _controller;
  late final TabController _tabController;

  List<int> _versions = const [];
  int? _baseVersion;
  int? _compareVersion;
  String? _baseContent;
  String? _compareContent;
  bool _isLoadingVersions = true;
  bool _isLoadingContent = false;
  String? _versionError;

  // Compatibility tab
  late final TextEditingController _draftSchemaController;
  int? _compatTargetVersion;
  bool _isCheckingCompatibility = false;
  api.SchemaCompatibilityResult? _compatResult;
  String? _compatError;

  // Associated topics tab
  List<String> _associatedTopics = const [];
  bool _isLoadingAssociatedTopics = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? getIt<SchemaController>();
    _tabController = TabController(length: 3, vsync: this);
    _draftSchemaController = TextEditingController();
    _loadVersions();
    _loadAssociatedTopics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _draftSchemaController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoadingVersions = true;
      _versionError = null;
    });

    try {
      final versions = await _controller.fetchSchemaVersions(
        widget.profile,
        widget.subject,
      );
      if (!mounted) return;

      int? base = widget.initialBaseVersion;
      int? compare = widget.initialCompareVersion;

      if (versions.isNotEmpty) {
        if (compare == null || !versions.contains(compare)) {
          compare = versions.last;
        }
        if (base == null || !versions.contains(base)) {
          base = versions.length > 1
              ? versions[versions.length - 2]
              : versions.first;
        }
      }

      setState(() {
        _versions = versions;
        _baseVersion = base;
        _compareVersion = compare;
        _compatTargetVersion =
            compare ?? (versions.isNotEmpty ? versions.last : null);
        _isLoadingVersions = false;
      });

      if (base != null && compare != null) {
        await _fetchDiffContents(base, compare);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVersions = false;
          _versionError = e.toString();
        });
      }
    }
  }

  Future<void> _fetchDiffContents(int base, int compare) async {
    setState(() {
      _isLoadingContent = true;
    });

    try {
      final baseText = await _controller.fetchSchemaContent(
        widget.profile,
        widget.subject,
        version: base,
      );
      final compareText = await _controller.fetchSchemaContent(
        widget.profile,
        widget.subject,
        version: compare,
      );

      if (mounted) {
        setState(() {
          _baseContent = baseText;
          _compareContent = compareText;
          if (_draftSchemaController.text.isEmpty) {
            _draftSchemaController.text = _prettyFormatJson(compareText);
          }
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
      }
    }
  }

  Future<void> _loadAssociatedTopics() async {
    setState(() {
      _isLoadingAssociatedTopics = true;
    });

    try {
      List<String> available = [];
      if (getIt.isRegistered<TopicController>()) {
        final topicController = getIt<TopicController>();
        final topics = topicController.getTopics(widget.profile);
        if (topics != null) {
          available = topics.map((t) => t.name).toList();
        }
      }

      final associated = await _controller.getAssociatedTopics(
        widget.subject,
        available,
      );

      if (mounted) {
        setState(() {
          _associatedTopics = associated;
          _isLoadingAssociatedTopics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAssociatedTopics = false;
        });
      }
    }
  }

  Future<void> _runCompatibilityCheck() async {
    final schema = _draftSchemaController.text.trim();
    if (schema.isEmpty) return;

    setState(() {
      _isCheckingCompatibility = true;
      _compatResult = null;
      _compatError = null;
    });

    try {
      final result = await _controller.checkCompatibility(
        widget.profile,
        widget.subject,
        version: _compatTargetVersion,
        schema: schema,
      );

      if (mounted) {
        setState(() {
          _compatResult = result;
          _isCheckingCompatibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _compatError = e.toString();
          _isCheckingCompatibility = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 720,
          minWidth: 640,
          minHeight: 480,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.schema_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.schemaDiffTitle ?? 'Schema Version Diff',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.subject,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Bar
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    text: l10n?.compareSchemaVersions ?? 'Compare Versions',
                  ),
                  Tab(
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    text: l10n?.checkCompatibility ?? 'Check Compatibility',
                  ),
                  Tab(
                    icon: const Icon(Icons.hub_outlined, size: 18),
                    text: l10n?.associatedTopicsTitle ?? 'Associated Topics',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDiffTab(context, colorScheme, l10n),
                    _buildCompatibilityTab(context, colorScheme, l10n),
                    _buildAssociatedTopicsTab(context, colorScheme, l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    if (_isLoadingVersions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_versionError != null) {
      return Center(
        child: Text(_versionError!, style: TextStyle(color: colorScheme.error)),
      );
    }

    if (_versions.isEmpty) {
      return Center(
        child: Text(
          l10n?.noMatches ?? 'No versions found for subject',
          style: TextStyle(color: colorScheme.outline),
        ),
      );
    }

    return Column(
      children: [
        // Selectors row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${l10n?.baseVersionLabel ?? "Base Version"}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              DropdownButton<int>(
                key: const Key('diff_base_version_dropdown'),
                value: _baseVersion,
                isDense: true,
                items: [
                  for (final v in _versions)
                    DropdownMenuItem(value: v, child: Text('v$v')),
                ],
                onChanged: (val) {
                  if (val != null && val != _baseVersion) {
                    setState(() => _baseVersion = val);
                    if (_compareVersion != null) {
                      _fetchDiffContents(val, _compareVersion!);
                    }
                  }
                },
              ),
              const SizedBox(width: 24),
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 24),
              Text(
                '${l10n?.compareVersionLabel ?? "Compare Version"}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              DropdownButton<int>(
                key: const Key('diff_compare_version_dropdown'),
                value: _compareVersion,
                isDense: true,
                items: [
                  for (final v in _versions)
                    DropdownMenuItem(value: v, child: Text('v$v')),
                ],
                onChanged: (val) {
                  if (val != null && val != _compareVersion) {
                    setState(() => _compareVersion = val);
                    if (_baseVersion != null) {
                      _fetchDiffContents(_baseVersion!, val);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Diff content viewer
        Expanded(
          child: _isLoadingContent
              ? const Center(child: CircularProgressIndicator())
              : _buildDiffViewer(colorScheme, l10n),
        ),
      ],
    );
  }

  Widget _buildDiffViewer(ColorScheme colorScheme, AppLocalizations? l10n) {
    if (_baseContent == null || _compareContent == null) {
      return Center(
        child: Text(
          'Select versions to compare',
          style: TextStyle(color: colorScheme.outline),
        ),
      );
    }

    final diffLines = computeLineDiff(_baseContent!, _compareContent!);
    final hasChanges = diffLines.any(
      (line) => line.type != DiffLineType.unchanged,
    );

    if (!hasChanges) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              l10n?.noDifferencesFound ??
                  'No differences found between the selected versions.',
              style: TextStyle(
                color: colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListView.builder(
        itemCount: diffLines.length,
        itemBuilder: (context, index) {
          final line = diffLines[index];
          Color? bgColor;
          Color textColor = colorScheme.onSurface;
          String prefix = ' ';

          if (line.type == DiffLineType.added) {
            bgColor = Colors.green.withValues(alpha: 0.12);
            textColor = Colors.green.shade700;
            prefix = '+';
          } else if (line.type == DiffLineType.removed) {
            bgColor = Colors.red.withValues(alpha: 0.12);
            textColor = Colors.red.shade700;
            prefix = '-';
          }

          return Container(
            color: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    line.oldLineNumber != null ? '${line.oldLineNumber}' : '',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    line.newLineNumber != null ? '${line.newLineNumber}' : '',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  prefix,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompatibilityTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${l10n?.baseVersionLabel ?? "Target Version"}: ',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (_versions.isNotEmpty)
              DropdownButton<int>(
                key: const Key('compat_target_version_dropdown'),
                value: _compatTargetVersion,
                isDense: true,
                items: [
                  for (final v in _versions)
                    DropdownMenuItem(value: v, child: Text('v$v')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _compatTargetVersion = val);
                  }
                },
              ),
            const Spacer(),
            FilledButton.icon(
              key: const Key('run_compatibility_check_button'),
              icon: _isCheckingCompatibility
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.fact_check, size: 16),
              label: Text(l10n?.checkCompatibility ?? 'Check Compatibility'),
              onPressed: _isCheckingCompatibility
                  ? null
                  : _runCompatibilityCheck,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.draftSchemaLabel ?? 'Draft Schema (JSON)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextField(
              key: const Key('draft_schema_text_field'),
              controller: _draftSchemaController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_compatResult != null || _compatError != null)
          Expanded(
            flex: 2,
            child: _buildCompatibilityResult(colorScheme, l10n),
          ),
      ],
    );
  }

  Widget _buildCompatibilityResult(
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    if (_compatError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _compatError!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final result = _compatResult!;
    final isCompatible = result.isCompatible;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompatible
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompatible
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompatible ? Icons.check_circle : Icons.cancel,
                color: isCompatible ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCompatible
                    ? (l10n?.schemaCompatible ?? 'Compatible')
                    : (l10n?.schemaIncompatible ?? 'Incompatible'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCompatible
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCompatible
                ? (l10n?.compatibilityCheckSuccess ??
                      'Schema is compatible with the selected subject version.')
                : (result.messages.isNotEmpty
                      ? result.messages.join('\n')
                      : (l10n?.schemaIncompatible ??
                            'Incompatible with registry policy')),
            style: TextStyle(
              fontSize: 12,
              color: isCompatible ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssociatedTopicsTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    if (_isLoadingAssociatedTopics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_associatedTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 40, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              l10n?.noAssociatedTopicsFound ??
                  'No associated topics found for this subject.',
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _associatedTopics.length,
      itemBuilder: (context, index) {
        final topic = _associatedTopics[index];
        return ListTile(
          leading: const Icon(Icons.topic_outlined),
          title: Text(
            topic,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: widget.onNavigateToTopic != null
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: widget.onNavigateToTopic != null
              ? () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTopic!(topic);
                }
              : null,
        );
      },
    );
  }
}
