import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

part 'script.freezed.dart';
part 'script.g.dart';

enum ScriptVariableType { string, numeric, timestamp, date }

@freezed
abstract class ScriptVariable with _$ScriptVariable {
  const factory ScriptVariable({required String name, @Default(ScriptVariableType.string) ScriptVariableType type}) =
      _ScriptVariable;

  factory ScriptVariable.fromJson(Map<String, dynamic> json) => _$ScriptVariableFromJson(json);
}

@freezed
abstract class Script with _$Script {
  const factory Script({
    required String id,
    required String name,
    @Default(2) int concurrencyLimit,
    String? outputDirectory,
    @Default([]) List<ScriptVariable> variables,
    @Default([]) List<ScriptStep> steps,
  }) = _Script;

  factory Script.fromJson(Map<String, dynamic> json) => _$ScriptFromJson(json);
}

enum ScriptExtractionSource { value, key }

@freezed
abstract class ScriptExtraction with _$ScriptExtraction {
  const factory ScriptExtraction({
    required String jsonPath,
    required String variableName,
    String? topic,
    @Default(ScriptExtractionSource.value) ScriptExtractionSource source,
  }) = _ScriptExtraction;

  factory ScriptExtraction.fromJson(Map<String, dynamic> json) => _$ScriptExtractionFromJson(json);
}

@freezed
abstract class ScriptStep with _$ScriptStep {
  const factory ScriptStep({
    required String id,
    required String name,
    required String clusterName, // Reference by name for persistence
    @Default([]) List<String> topicNames, // Reference by name for persistence
    String? filterTemplate,
    @Default(FilterType.contains) FilterType filterType,
    @Default(SearchScope.both) SearchScope scope,

    // Configuration strategies
    @Default(MultiSearchStartStrategy.earliest) MultiSearchStartStrategy startStrategy,
    @Default(MultiSearchEndStrategy.latest) MultiSearchEndStrategy endStrategy,

    // Stringified for variable support
    String? startOffset,
    String? startTimestamp,
    String? startPartition,
    @Default(false) bool fastTraceEnabled,
    String? endOffset,
    String? endTimestamp,
    String? maxResults,

    @Default([]) List<ScriptExtraction> extractions,
  }) = _ScriptStep;

  factory ScriptStep.fromJson(Map<String, dynamic> json) => _$ScriptStepFromJson(json);
}

extension ScriptStepX on ScriptStep {
  ScriptStep replaceVariable(String oldName, String newName) {
    String? replace(String? input) {
      if (input == null) return null;
      // Replace exactly {{oldName}} with {{newName}}
      return input.replaceAll('{{$oldName}}', '{{$newName}}');
    }

    return copyWith(
      filterTemplate: replace(filterTemplate),
      startOffset: replace(startOffset),
      startTimestamp: replace(startTimestamp),
      startPartition: replace(startPartition),
      endOffset: replace(endOffset),
      endTimestamp: replace(endTimestamp),
      maxResults: replace(maxResults),
    );
  }
}
