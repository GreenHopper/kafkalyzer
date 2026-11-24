// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script_extraction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScriptExtraction _$ScriptExtractionFromJson(Map<String, dynamic> json) =>
    _ScriptExtraction(
      jsonPath: json['jsonPath'] as String,
      variableName: json['variableName'] as String,
      topic: json['topic'] as String?,
      source:
          $enumDecodeNullable(
            _$ScriptExtractionSourceEnumMap,
            json['source'],
          ) ??
          ScriptExtractionSource.value,
    );

Map<String, dynamic> _$ScriptExtractionToJson(_ScriptExtraction instance) =>
    <String, dynamic>{
      'jsonPath': instance.jsonPath,
      'variableName': instance.variableName,
      'topic': instance.topic,
      'source': _$ScriptExtractionSourceEnumMap[instance.source]!,
    };

const _$ScriptExtractionSourceEnumMap = {
  ScriptExtractionSource.value: 'value',
  ScriptExtractionSource.key: 'key',
};
