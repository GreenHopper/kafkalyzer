import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';
import 'package:material_ui/material_ui.dart';
import 'package:logger/logger.dart';

class FieldOccurrence {
  final String topic;
  final String fullPath;
  final Map<String, dynamic> schemaDef;

  FieldOccurrence({
    required this.topic,
    required this.fullPath,
    required this.schemaDef,
  });
}

class ScriptSchemasView extends StatefulWidget {
  final Script script;
  final String searchPhrase;

  /// Session-wide collaborators; null falls back to the application container.
  final Logger? logger;
  final SchemaController? schemaController;
  final ClusterListController? clusterController;

  const ScriptSchemasView({
    super.key,
    required this.script,
    required this.searchPhrase,
    this.logger,
    this.schemaController,
    this.clusterController,
  });

  @override
  State<ScriptSchemasView> createState() => _ScriptSchemasViewState();
}

class _ScriptSchemasViewState extends State<ScriptSchemasView> {
  Logger get _logger => widget.logger ?? getIt<Logger>();

  SchemaController get _schemaController =>
      widget.schemaController ?? getIt<SchemaController>();

  ClusterListController get _clusterController =>
      widget.clusterController ?? getIt<ClusterListController>();

  bool _isLoading = false;

  // fieldName -> List of occurrences
  final Map<String, List<FieldOccurrence>> _fieldDefinitions = {};

  @override
  void initState() {
    super.initState();
    _loadSchemas();
  }

  @override
  void didUpdateWidget(covariant ScriptSchemasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script.id != oldWidget.script.id) {
      _loadSchemas();
    }
  }

  Future<void> _loadSchemas() async {
    setState(() {
      _isLoading = true;
      _fieldDefinitions.clear();
    });

    try {
      final steps = widget.script.steps;
      for (final step in steps) {
        final clusterProfile = _clusterController.clusters
            .cast<ClusterProfile?>()
            .firstWhere((c) => c?.name == step.clusterName, orElse: () => null);

        if (clusterProfile == null) continue;

        for (final topic in step.topicNames) {
          try {
            final schemaJson = await _schemaController.fetchSchemaContent(
              clusterProfile,
              "$topic-value",
            );
            final map = jsonDecode(schemaJson);
            if (map is Map<String, dynamic>) {
              _flattenSchemaFields(map, topic, "");
            }
          } catch (e) {
            final errorStr = e.toString();
            // Demote common any-how exceptions for missing schemas to debug
            if (errorStr.contains('Schema not found')) {
              _logger.d("Schema not found in registry for topic: $topic");
            } else {
              _logger.w(
                "Failed to fetch/parse schema for topic $topic: \n$errorStr",
              );
            }
          }
        }
      }
    } catch (e) {
      _logger.e("Failed to load schemas in ScriptSchemasView", error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _flattenSchemaFields(
    Map<String, dynamic> element,
    String topic,
    String currentPath,
  ) {
    if (element['type'] == 'record' && element.containsKey('fields')) {
      final fields = element['fields'] as List;
      for (final f in fields) {
        if (f is Map<String, dynamic> && f.containsKey('name')) {
          final fName = f['name'] as String;
          final path = currentPath.isEmpty ? fName : "$currentPath.$fName";

          // Register this field definition
          _fieldDefinitions.putIfAbsent(fName, () => []);
          _fieldDefinitions[fName]!.add(
            FieldOccurrence(topic: topic, fullPath: path, schemaDef: f),
          );

          // Recurse into the type definition of the field
          if (f.containsKey('type')) {
            _flattenSchemaFields({'type': f['type']}, topic, path);
          }
        }
      }
    } else if (element['type'] is Map) {
      _flattenSchemaFields(
        element['type'] as Map<String, dynamic>,
        topic,
        currentPath,
      );
    } else if (element['type'] == 'array' && element.containsKey('items')) {
      if (element['items'] is Map) {
        _flattenSchemaFields(
          element['items'] as Map<String, dynamic>,
          topic,
          currentPath,
        );
      } else if (element['items'] is List) {
        // Rare but possible union array items
        _flattenSchemaFields({'type': element['items']}, topic, currentPath);
      }
    } else if (element['type'] is List) {
      // Union types (e.g. ["null", {"type": "record", ...}])
      for (final t in (element['type'] as List)) {
        if (t is Map<String, dynamic>) {
          _flattenSchemaFields(t, topic, currentPath);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = widget.searchPhrase.trim().toLowerCase();

    // Filter matching leaf fields
    final filteredFields = _fieldDefinitions.entries.where((entry) {
      if (query.isEmpty) return true;
      final fName = entry.key;
      // Search the serialized JSON or path of any occurrence
      final hasSubstring = entry.value.any((occurrence) {
        return occurrence.fullPath.toLowerCase().contains(query) ||
            jsonEncode(occurrence.schemaDef).toLowerCase().contains(query);
      });
      return fName.toLowerCase().contains(query) || hasSubstring;
    }).toList();

    filteredFields.sort((a, b) {
      if (query.isEmpty) return a.key.compareTo(b.key);

      final leafA = a.key.toLowerCase();
      final leafB = b.key.toLowerCase();

      // Exact match on leaf gets highest priority
      final exactA = leafA == query;
      final exactB = leafB == query;
      if (exactA && !exactB) return -1;
      if (!exactA && exactB) return 1;

      // Partial match on the leaf itself gets second priority
      final containsA = leafA.contains(query);
      final containsB = leafB.contains(query);
      if (containsA && !containsB) return -1;
      if (!containsA && containsB) return 1;

      // Compare by whether any path has a partial match
      final pathContainsA = a.value.any(
        (o) => o.fullPath.toLowerCase().contains(query),
      );
      final pathContainsB = b.value.any(
        (o) => o.fullPath.toLowerCase().contains(query),
      );
      if (pathContainsA && !pathContainsB) return -1;
      if (!pathContainsA && pathContainsB) return 1;

      // Otherwise just sort alphabetically by leaf name
      return a.key.compareTo(b.key);
    });

    if (filteredFields.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          query.isNotEmpty
              ? (l10n?.noSchemaFieldsMatching(query) ??
                    "No schema fields found matching '$query'")
              : (l10n?.noSchemasForScriptTopics ??
                    "No schemas found for the current script's topics."),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredFields.length,
      itemBuilder: (context, index) {
        final fieldEntry = filteredFields[index];
        return _buildFieldCard(context, fieldEntry.key, fieldEntry.value);
      },
    );
  }

  Future<String> _generateMarkdown(
    String fieldName,
    List<FieldOccurrence> occurrences,
  ) => generateMarkdownForSchemaField(fieldName, occurrences);

  Widget _buildFieldCard(
    BuildContext context,
    String fieldName,
    List<FieldOccurrence> occurrences,
  ) {
    final uniqueTopics = occurrences.map((o) => o.topic).toSet();

    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          l10n?.fieldLabel(fieldName) ?? "Field: $fieldName",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          l10n?.foundTimesAcrossTopics(
                occurrences.length,
                uniqueTopics.length,
              ) ??
              "Found ${occurrences.length} time(s) across ${uniqueTopics.length} topic(s)",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: l10n?.copyMarkdown ?? "Copy Markdown",
              onPressed: () async {
                final md = await _generateMarkdown(fieldName, occurrences);
                await Clipboard.setData(ClipboardData(text: md));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n?.copiedSchemaToClipboard(fieldName) ??
                            'Copied $fieldName schema to clipboard.',
                      ),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              tooltip: l10n?.downloadMarkdown ?? "Download Markdown",
              onPressed: () async {
                final saveTitle = AppLocalizations.of(
                  context,
                )!.saveSchemaMarkdown;
                final md = await _generateMarkdown(fieldName, occurrences);
                final outputFile = await FilePicker.saveFile(
                  dialogTitle: saveTitle,
                  fileName: 'schema_$fieldName.md',
                  type: FileType.custom,
                  allowedExtensions: ['md'],
                );

                if (outputFile != null) {
                  final file = File(outputFile);
                  await file.writeAsString(md);
                  if (context.mounted) {
                    showExportSuccessSnackBar(
                      context,
                      message:
                          l10n?.savedSchemaToFile ?? 'Saved schema to file',
                      filePath: outputFile,
                    );
                  }
                }
              },
            ),
            // Default ExpansionTile trailing icon behavior (often rotation) is lost if we override it completely
            // without providing the drop down arrow, but for ease of use we place the buttons here.
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTopicDifferences(occurrences),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDifferences(List<FieldOccurrence> occurrences) {
    if (occurrences.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    // Sort occurrences by topic, then by path
    final sortedOccurrences = List<FieldOccurrence>.from(occurrences)
      ..sort((a, b) {
        int topicComp = a.topic.compareTo(b.topic);
        if (topicComp != 0) return topicComp;
        return a.fullPath.compareTo(b.fullPath);
      });

    // If only one occurrence, just show it
    if (sortedOccurrences.length == 1) {
      final occ = sortedOccurrences.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.foundInTopic(occ.topic) ?? "Found in topic: ${occ.topic}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            l10n?.pathLabel(occ.fullPath) ?? "Path: ${occ.fullPath}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.withValues(alpha: 0.1),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(occ.schemaDef),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      );
    }

    // Multiple occurrences: use first as baseline
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.foundInMultipleLocations ??
              "Found in multiple locations (differences highlighted):",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (sortedOccurrences.isNotEmpty) ...[
          _buildBaselineOccurrence(context, sortedOccurrences.first, l10n),
          if (sortedOccurrences.length > 1)
            FieldSchemaComparisonsWidget(
              baseline: sortedOccurrences.first,
              comparisons: sortedOccurrences.sublist(1),
            ),
        ],
      ],
    );
  }

  Widget _buildBaselineOccurrence(
    BuildContext context,
    FieldOccurrence occ,
    AppLocalizations? l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.baselineTopic(occ.topic) ?? "Baseline Topic: ${occ.topic}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            l10n?.pathLabel(occ.fullPath) ?? "Path: ${occ.fullPath}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.withValues(alpha: 0.1),
            width: double.infinity,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(occ.schemaDef),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class FieldSchemaComparisonsWidget extends StatefulWidget {
  final FieldOccurrence baseline;
  final List<FieldOccurrence> comparisons;

  const FieldSchemaComparisonsWidget({
    super.key,
    required this.baseline,
    required this.comparisons,
  });

  @override
  State<FieldSchemaComparisonsWidget> createState() =>
      _FieldSchemaComparisonsWidgetState();
}

class _FieldSchemaComparisonsWidgetState
    extends State<FieldSchemaComparisonsWidget> {
  late Future<List<JsonDiffResult>> _diffFuture;

  @override
  void initState() {
    super.initState();
    _diffFuture = _loadDiffs();
  }

  @override
  void didUpdateWidget(covariant FieldSchemaComparisonsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseline != widget.baseline ||
        oldWidget.comparisons != widget.comparisons) {
      _diffFuture = _loadDiffs();
    }
  }

  Future<List<JsonDiffResult>> _loadDiffs() async {
    final baselineJson = jsonEncode(widget.baseline.schemaDef);
    final requests = widget.comparisons
        .map(
          (occ) => JsonDiffRequest(
            oldJson: baselineJson,
            newJson: jsonEncode(occ.schemaDef),
            ignorePaths: const [],
          ),
        )
        .toList();
    return await diffJsonBatch(requests: requests);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<JsonDiffResult>>(
      future: _diffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              l10n?.errorComputingDiff ?? 'Error computing diff',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        final results = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(widget.comparisons.length, (i) {
            final occ = widget.comparisons[i];
            final result = i < results.length ? results[i] : null;
            final entries = result?.entries ?? const <JsonDiffEntry>[];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.comparedToTopic(occ.topic) ??
                        "Compared to Topic: ${occ.topic}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    l10n?.pathLabel(occ.fullPath) ?? "Path: ${occ.fullPath}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (entries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: JsonDiffWidget(entries: entries),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        l10n?.noDifferencesFromBaseline ??
                            "No differences from baseline.",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

@visibleForTesting
Future<String> generateMarkdownForSchemaField(
  String fieldName,
  List<FieldOccurrence> occurrences,
) async {
  final sb = StringBuffer();
  sb.writeln('# Schema Field: $fieldName\n');

  if (occurrences.isEmpty) {
    sb.writeln('_No occurrences found._');
    return sb.toString();
  }

  final sortedOccurrences = List<FieldOccurrence>.from(occurrences)
    ..sort((a, b) {
      final topicComp = a.topic.compareTo(b.topic);
      if (topicComp != 0) return topicComp;
      return a.fullPath.compareTo(b.fullPath);
    });

  final baseline = sortedOccurrences.first;

  sb.writeln('## Baseline');
  sb.writeln('- **Topic:** `${baseline.topic}`');
  sb.writeln('- **Full Path:** `${baseline.fullPath}`');
  sb.writeln('\n```json');
  sb.writeln(const JsonEncoder.withIndent('  ').convert(baseline.schemaDef));
  sb.writeln('```\n');

  if (sortedOccurrences.length > 1) {
    final baselineJson = jsonEncode(baseline.schemaDef);
    final requests = [
      for (int i = 1; i < sortedOccurrences.length; i++)
        JsonDiffRequest(
          oldJson: baselineJson,
          newJson: jsonEncode(sortedOccurrences[i].schemaDef),
          ignorePaths: const [],
        ),
    ];
    final results = await diffJsonBatch(requests: requests);

    sb.writeln('## Comparisons\n');
    for (int i = 1; i < sortedOccurrences.length; i++) {
      final occ = sortedOccurrences[i];
      final result = results[i - 1];

      sb.writeln('### Compared Occurrence $i (vs Baseline)');
      sb.writeln('- **Topic:** `${occ.topic}`');
      sb.writeln('- **Full Path:** `${occ.fullPath}`\n');

      final diffOutput = diffEntriesToMarkdown(result.entries);
      if (diffOutput.isNotEmpty) {
        sb.writeln('#### Differences');
        sb.writeln(diffOutput);
      } else {
        sb.writeln('_No structural differences from baseline._\n');
      }

      sb.writeln('#### Full JSON Schema');
      sb.writeln('```json');
      sb.writeln(const JsonEncoder.withIndent('  ').convert(occ.schemaDef));
      sb.writeln('```\n');
    }
  }

  return sb.toString();
}

@visibleForTesting
String diffEntriesToMarkdown(List<JsonDiffEntry> entries) {
  final sb = StringBuffer();
  for (final entry in entries) {
    switch (entry.kind) {
      case JsonDiffKind.added:
        sb.writeln('- 🟢 **Added** `${entry.path}`: `${entry.newValue}`');
      case JsonDiffKind.removed:
        sb.writeln('- 🔴 **Removed** `${entry.path}`: `${entry.oldValue}`');
      case JsonDiffKind.changed:
        sb.writeln(
          '- 🟡 **Changed** `${entry.path}`: `${entry.oldValue}`  ➔  `${entry.newValue}`',
        );
    }
  }
  return sb.toString();
}
