import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

enum FilterSuggestionSource { schema, analysis, sample }

class FilterFieldSuggestions {
  final List<String> valuePaths;
  final List<String> headerNames;
  final FilterSuggestionSource? source;

  const FilterFieldSuggestions({
    this.valuePaths = const [],
    this.headerNames = const [],
    this.source,
  });

  bool get isEmpty => valuePaths.isEmpty && headerNames.isEmpty;
}

typedef CollectFieldPathsFn =
    List<String> Function({required String payload, required int limit});

/// Resolves field suggestions in priority order:
/// 1. Schema fields (`schemaFields`)
/// 2. Topic analysis `fieldFrequencies` (`analysisFields`)
/// 3. `collectFieldPaths` over at most the last 200 loaded messages (`messages`)
Future<FilterFieldSuggestions> resolveFilterFieldSuggestions({
  Future<List<String>> Function()? fetchSchemaFields,
  List<String>? analysisFields,
  List<KafkaMessage>? messages,
  CollectFieldPathsFn? collectPathsFn,
}) async {
  final headerSet = <String>{};
  if (messages != null) {
    final start = messages.length > 200 ? messages.length - 200 : 0;
    for (var i = start; i < messages.length; i++) {
      final headers = messages[i].headers;
      if (headers != null) {
        for (final h in headers) {
          if (h.key.isNotEmpty) headerSet.add(h.key);
        }
      }
    }
  }
  final headerNames = headerSet.toList()..sort();

  if (fetchSchemaFields != null) {
    try {
      final schema = await fetchSchemaFields();
      if (schema.isNotEmpty) {
        return FilterFieldSuggestions(
          valuePaths: schema.toSet().toList()..sort(),
          headerNames: headerNames,
          source: FilterSuggestionSource.schema,
        );
      }
    } catch (_) {
      // Fall through to next suggestion source.
    }
  }

  if (analysisFields != null && analysisFields.isNotEmpty) {
    return FilterFieldSuggestions(
      valuePaths: analysisFields.toSet().toList()..sort(),
      headerNames: headerNames,
      source: FilterSuggestionSource.analysis,
    );
  }

  if (messages != null && messages.isNotEmpty) {
    final collect = collectPathsFn ?? collectFieldPaths;
    final pathSet = <String>{};
    final start = messages.length > 200 ? messages.length - 200 : 0;
    for (var i = start; i < messages.length; i++) {
      final payload = messages[i].payload;
      if (payload == null || payload.isEmpty) continue;
      final paths = collect(payload: payload, limit: 64);
      pathSet.addAll(paths);
      if (pathSet.length >= 200) break;
    }
    if (pathSet.isNotEmpty) {
      return FilterFieldSuggestions(
        valuePaths: pathSet.toList()..sort(),
        headerNames: headerNames,
        source: FilterSuggestionSource.sample,
      );
    }
  }

  return FilterFieldSuggestions(
    valuePaths: const [],
    headerNames: headerNames,
    source: headerNames.isNotEmpty ? FilterSuggestionSource.sample : null,
  );
}
