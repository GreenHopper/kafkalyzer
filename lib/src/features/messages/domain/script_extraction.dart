import 'package:freezed_annotation/freezed_annotation.dart';

part 'script_extraction.freezed.dart';
part 'script_extraction.g.dart';

enum ScriptExtractionSource { value, key }

@freezed
abstract class ScriptExtraction with _$ScriptExtraction {
  const factory ScriptExtraction({
    required String jsonPath,
    required String variableName,
    String? topic,
    @Default(ScriptExtractionSource.value) ScriptExtractionSource source,
  }) = _ScriptExtraction;

  factory ScriptExtraction.fromJson(Map<String, dynamic> json) =>
      _$ScriptExtractionFromJson(json);
}
