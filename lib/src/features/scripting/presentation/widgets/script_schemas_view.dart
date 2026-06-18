import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:flutter/material.dart';
import 'package:json_diff/json_diff.dart';
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

  const ScriptSchemasView({
    super.key,
    required this.script,
    required this.searchPhrase,
  });

  @override
  State<ScriptSchemasView> createState() => _ScriptSchemasViewState();
}

class _ScriptSchemasViewState extends State<ScriptSchemasView> {
  final _logger = getIt<Logger>();
  final _schemaController = getIt<SchemaController>();
  final _clusterController = getIt<ClusterListController>();

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
      return Center(
        child: Text(
          query.isNotEmpty
              ? "No schema fields found matching '$query'"
              : "No schemas found for the current script's topics.",
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

  String _generateMarkdown(
    String fieldName,
    List<FieldOccurrence> occurrences,
  ) {
    final sb = StringBuffer();
    sb.writeln('# Schema Field: $fieldName\n');

    if (occurrences.isEmpty) {
      sb.writeln('_No occurrences found._');
      return sb.toString();
    }

    // Sort matching exactly as in UI
    final sortedOccurrences = List<FieldOccurrence>.from(occurrences)
      ..sort((a, b) {
        int topicComp = a.topic.compareTo(b.topic);
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
      sb.writeln('## Comparisons\n');
      for (int i = 1; i < sortedOccurrences.length; i++) {
        final occ = sortedOccurrences[i];

        // Calculate diff
        final differ = JsonDiffer.fromJson(baseline.schemaDef, occ.schemaDef);
        final diffNode = differ.diff();

        sb.writeln('### Compared Occurrence $i (vs Baseline)');
        sb.writeln('- **Topic:** `${occ.topic}`');
        sb.writeln('- **Full Path:** `${occ.fullPath}`\n');

        final diffOutput = _diffNodeToMarkdown(diffNode);
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

  String _diffNodeToMarkdown(DiffNode node, [String path = '']) {
    final sb = StringBuffer();
    final pfx = path.isEmpty ? "" : "$path.";

    node.added.forEach((key, value) {
      sb.writeln('- 🟢 **Added** `$pfx$key`: `$value`');
    });

    node.removed.forEach((key, value) {
      sb.writeln('- 🔴 **Removed** `$pfx$key`: `$value`');
    });

    node.changed.forEach((key, values) {
      final oldVal = values.isNotEmpty ? values[0] : null;
      final newVal = values.length > 1 ? values[1] : null;
      sb.writeln('- 🟡 **Changed** `$pfx$key`: `$oldVal`  ➔  `$newVal`');
    });

    node.node.forEach((key, childNode) {
      sb.write(_diffNodeToMarkdown(childNode, "$pfx$key"));
    });

    return sb.toString();
  }

  Widget _buildFieldCard(
    BuildContext context,
    String fieldName,
    List<FieldOccurrence> occurrences,
  ) {
    final uniqueTopics = occurrences.map((o) => o.topic).toSet();

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          "Field: $fieldName",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "Found ${occurrences.length} time(s) across ${uniqueTopics.length} topic(s)",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: "Copy Markdown",
              onPressed: () async {
                final md = _generateMarkdown(fieldName, occurrences);
                await Clipboard.setData(ClipboardData(text: md));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $fieldName schema to clipboard.'),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              tooltip: "Download Markdown",
              onPressed: () async {
                final md = _generateMarkdown(fieldName, occurrences);
                final outputFile = await FilePicker.saveFile(
                  dialogTitle: 'Save Schema Markdown',
                  fileName: 'schema_$fieldName.md',
                  type: FileType.custom,
                  allowedExtensions: ['md'],
                );

                if (outputFile != null) {
                  final file = File(outputFile);
                  await file.writeAsString(md);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved to $outputFile')),
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
            "Found in topic: ${occ.topic}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            "Path: ${occ.fullPath}",
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
        const Text(
          "Found in multiple locations (differences highlighted):",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...List.generate(sortedOccurrences.length, (i) {
          final occ = sortedOccurrences[i];

          if (i == 0) {
            // First occurrence: baseline
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Baseline Topic: ${occ.topic}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Path: ${occ.fullPath}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.grey.withValues(alpha: 0.1),
                    width: double.infinity,
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(occ.schemaDef),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Compare with baseline
            final baselineDef = sortedOccurrences.first.schemaDef;
            final differ = JsonDiffer.fromJson(baselineDef, occ.schemaDef);
            final diffNode = differ.diff();

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Compared to Topic: ${occ.topic}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Path: ${occ.fullPath}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (diffNode.added.isNotEmpty ||
                      diffNode.removed.isNotEmpty ||
                      diffNode.changed.isNotEmpty ||
                      diffNode.node.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: JsonDiffWidget(diffNode: diffNode),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "No differences from baseline.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
        }),
      ],
    );
  }
}
