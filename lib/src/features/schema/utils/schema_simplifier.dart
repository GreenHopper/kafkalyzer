/// Simplifies raw Avro schema maps into human-readable structured maps
/// suitable for rendering in json viewers and smart virtual tree widgets.
dynamic simplifyAvroSchema(dynamic schema) {
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
        value = simplifyAvroSchema(_resolveUnderlyingType(fieldType));
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
    return simplifyAvroSchema(_resolveUnderlyingType(schema));
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
