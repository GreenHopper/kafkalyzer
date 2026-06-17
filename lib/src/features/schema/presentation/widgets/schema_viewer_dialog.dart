import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'dart:convert';

class SchemaViewerDialog extends StatefulWidget {
  final ClusterProfile profile;
  final String topicName;
  final SchemaController controller;

  const SchemaViewerDialog({
    super.key,
    required this.profile,
    required this.topicName,
    required this.controller,
  });

  @override
  State<SchemaViewerDialog> createState() => _SchemaViewerDialogState();
}

class _SchemaViewerDialogState extends State<SchemaViewerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Viewer Keys
  final GlobalKey<JsonOrStringViewerState> _keyViewerKey = GlobalKey();
  final GlobalKey<JsonOrStringViewerState> _valueViewerKey = GlobalKey();

  // Search State
  int _keyMatchCount = 0;
  int _valueMatchCount = 0;
  int _currentMatchIndex = 0;

  String? _keySchema;
  String? _valueSchema;
  bool _isLoading = true;
  String? _error;

  int get _totalMatches => _keyMatchCount + _valueMatchCount;

  @override
  void initState() {
    super.initState();
    _loadSchemas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchemas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final schemas = widget.controller.getSchemas(widget.profile);
      if (schemas != null) {
        if (schemas.contains("${widget.topicName}-key")) {
          _keySchema = await widget.controller.fetchSchemaContent(
            widget.profile,
            "${widget.topicName}-key",
          );
        }
        if (schemas.contains("${widget.topicName}-value")) {
          _valueSchema = await widget.controller.fetchSchemaContent(
            widget.profile,
            "${widget.topicName}-value",
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentMatchIndex = 0;
    });
  }

  void _jumpToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToCurrent() {
    if (_currentMatchIndex < _keyMatchCount) {
      _keyViewerKey.currentState?.jumpToMatch(_currentMatchIndex);
    } else {
      _valueViewerKey.currentState?.jumpToMatch(
        _currentMatchIndex - _keyMatchCount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9,
          maxHeight: size.height * 0.9,
          minWidth: 800 > size.width * 0.9 ? size.width * 0.9 : 800,
          minHeight: 500 > size.height * 0.9 ? size.height * 0.9 : 500,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Flexible(child: _buildHeader(context)),
                  const SizedBox(width: 32),
                  _buildSearchBar(context),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Schema Viewer", style: Theme.of(context).textTheme.titleLarge),
        Text(
          "Topic: ${widget.topicName}",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      width: 400,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: "Search...",
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: -11),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (_searchQuery.isNotEmpty && _totalMatches > 0) ...[
            Text(
              "${_currentMatchIndex + 1}/$_totalMatches",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              onPressed: _jumpToPreviousMatch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Previous match",
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              onPressed: _jumpToNextMatch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Next match",
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          "Error loading schema: $_error",
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_keySchema != null) ...[
            SizedBox(
              height: 150,
              child: JsonOrStringViewer(
                key: _keyViewerKey,
                title: "Key Schema",
                rawContent: _keySchema!,
                preParsedJson: _simplifySchema(jsonDecode(_keySchema!)),
                expand: true,
                persistenceKey: 'schema_viewer_key',
                searchQuery: _searchQuery,
                focusedMatchIndex:
                    (_totalMatches > 0 && _currentMatchIndex < _keyMatchCount)
                    ? _currentMatchIndex
                    : null,
                onMatchCountChanged: (count) {
                  if (_keyMatchCount != count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _keyMatchCount = count);
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_valueSchema != null)
            Expanded(
              child: JsonOrStringViewer(
                key: _valueViewerKey,
                title: "Value Schema",
                rawContent: _valueSchema!,
                preParsedJson: _simplifySchema(jsonDecode(_valueSchema!)),
                expand: true,
                persistenceKey: 'schema_viewer_value',
                searchQuery: _searchQuery,
                focusedMatchIndex:
                    (_totalMatches > 0 && _currentMatchIndex >= _keyMatchCount)
                    ? (_currentMatchIndex - _keyMatchCount)
                    : null,
                onMatchCountChanged: (count) {
                  if (_valueMatchCount != count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _valueMatchCount = count);
                      }
                    });
                  }
                },
              ),
            ),
          if (_keySchema == null && _valueSchema == null)
            const Center(child: Text("No Avro schema found for this topic.")),
        ],
      ),
    );
  }

  dynamic _simplifySchema(dynamic schema) {
    if (schema is! Map<String, dynamic>) {
      return schema;
    }

    final type = schema['type'];

    // 1. Records
    if (type == 'record' && schema.containsKey('fields')) {
      final fields = schema['fields'] as List;
      final simplifiedFields = <String, dynamic>{};

      if (schema['doc'] != null) {
        simplifiedFields['_doc'] = schema['doc'];
      }

      for (var f in fields) {
        final fieldName = f['name'];
        final fieldType = f['type'];
        final fieldDoc = f['doc'];

        final typeLabel = _getTypeLabel(fieldType);
        final isComplex = _isComplex(fieldType);
        final possibleValues = _tryParsePossibleValues(fieldDoc);

        String key;
        dynamic value;

        if (isComplex) {
          key = "$fieldName : $typeLabel";
          value = _simplifySchema(_resolveUnderlyingType(fieldType));
        } else {
          // Primitives
          key = fieldName;

          if (possibleValues != null) {
            value = {
              "Type": typeLabel,
              "Possible Values": possibleValues,
              if (fieldDoc != null &&
                  !fieldDoc.toString().startsWith("Possible values"))
                "Doc": fieldDoc,
            };
          } else if (fieldDoc != null) {
            value = "$typeLabel (Doc: $fieldDoc)";
          } else {
            value = typeLabel;
          }
        }

        // Handle Documentation for Complex types
        if (isComplex && value is Map) {
          if (possibleValues != null) {
            value['Possible Values'] = possibleValues;
          }

          if (fieldDoc != null) {
            if (possibleValues == null ||
                !fieldDoc.toString().startsWith("Possible values")) {
              if (!value.containsKey('_doc')) {
                value['_doc'] = fieldDoc;
              } else {
                value['_field_doc'] = fieldDoc;
              }
            }
          }
        }

        simplifiedFields[key] = value;
      }
      return simplifiedFields;
    }

    // 2. Arrays
    if (type == 'array' && schema.containsKey('items')) {
      return _simplifySchema(_resolveUnderlyingType(schema));
    }

    // 3. Enums
    if (type == 'enum' && schema.containsKey('symbols')) {
      return {
        "_type": "Enum",
        "symbols": schema['symbols'],
        if (schema['doc'] != null) "_doc": schema['doc'],
      };
    }

    return type ?? schema;
  }

  List<String>? _tryParsePossibleValues(dynamic doc) {
    if (doc is! String) return null;
    if (doc.contains("Possible values:")) {
      try {
        final parts = doc.split("Possible values:");
        if (parts.length > 1) {
          final valuesStr = parts[1];
          return valuesStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  dynamic _resolveUnderlyingType(dynamic type) {
    if (type is List) {
      final other = type.firstWhere((t) => t != 'null', orElse: () => null);
      if (other != null) return _resolveUnderlyingType(other);
      return type;
    }
    if (type is Map<String, dynamic>) {
      if (type['type'] == 'array') {
        return _resolveUnderlyingType(type['items']);
      }
      return type;
    }
    return type;
  }

  bool _isComplex(dynamic type) {
    if (type is Map<String, dynamic>) {
      if (type['logicalType'] != null) return false;
      String t = type['type'];
      if (t == 'record') return true;
      if (t == 'array') {
        return _isComplex(type['items']);
      }
      if (t == 'enum') return true;
    }
    if (type is List) {
      final other = type.firstWhere((t) => t != 'null', orElse: () => null);
      if (other != null) return _isComplex(other);
    }
    return false;
  }

  String _getTypeLabel(dynamic type) {
    if (type is String) return type;

    if (type is List) {
      if (type.contains('null') && type.length == 2) {
        final other = type.firstWhere((t) => t != 'null');
        return "${_getTypeLabel(other)} (Optional)";
      }
      return "Union${type.map((t) => _getTypeLabel(t)).toList()}";
    }

    if (type is Map<String, dynamic>) {
      if (type['logicalType'] != null) {
        final lt = type['logicalType'];
        if (lt == 'uuid') return 'UUID';
        if (lt == 'localdate') return 'LocalDate';
        if (lt == 'offsetdatetime') return 'OffsetDateTime';
        return lt;
      }
      if (type['type'] == 'record') {
        return type['name'] ?? 'Record';
      }
      if (type['type'] == 'array') {
        return "Array<${_getTypeLabel(type['items'])}>";
      }
      if (type['type'] == 'enum') {
        return type['name'] != null ? "Enum (${type['name']})" : "Enum";
      }
      return type['type'] ?? 'Complex';
    }
    return 'Unknown';
  }
}
