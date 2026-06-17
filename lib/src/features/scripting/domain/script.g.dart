// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScriptVariable _$ScriptVariableFromJson(Map<String, dynamic> json) =>
    _ScriptVariable(
      name: json['name'] as String,
      type:
          $enumDecodeNullable(_$ScriptVariableTypeEnumMap, json['type']) ??
          ScriptVariableType.string,
    );

Map<String, dynamic> _$ScriptVariableToJson(_ScriptVariable instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': _$ScriptVariableTypeEnumMap[instance.type]!,
    };

const _$ScriptVariableTypeEnumMap = {
  ScriptVariableType.string: 'string',
  ScriptVariableType.numeric: 'numeric',
  ScriptVariableType.timestamp: 'timestamp',
  ScriptVariableType.date: 'date',
};

_Script _$ScriptFromJson(Map<String, dynamic> json) => _Script(
  id: json['id'] as String,
  name: json['name'] as String,
  concurrencyLimit: (json['concurrencyLimit'] as num?)?.toInt() ?? 2,
  outputDirectory: json['outputDirectory'] as String?,
  variables:
      (json['variables'] as List<dynamic>?)
          ?.map((e) => ScriptVariable.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  steps:
      (json['steps'] as List<dynamic>?)
          ?.map((e) => ScriptStep.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ScriptToJson(_Script instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'concurrencyLimit': instance.concurrencyLimit,
  'outputDirectory': instance.outputDirectory,
  'variables': instance.variables,
  'steps': instance.steps,
};

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

_ScriptStep _$ScriptStepFromJson(Map<String, dynamic> json) => _ScriptStep(
  id: json['id'] as String,
  name: json['name'] as String,
  clusterName: json['clusterName'] as String,
  topicNames:
      (json['topicNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  filterTemplate: json['filterTemplate'] as String?,
  filterType:
      $enumDecodeNullable(_$FilterTypeEnumMap, json['filterType']) ??
      FilterType.contains,
  scope:
      $enumDecodeNullable(_$SearchScopeEnumMap, json['scope']) ??
      SearchScope.both,
  startStrategy:
      $enumDecodeNullable(
        _$MultiSearchStartStrategyEnumMap,
        json['startStrategy'],
      ) ??
      MultiSearchStartStrategy.earliest,
  endStrategy:
      $enumDecodeNullable(
        _$MultiSearchEndStrategyEnumMap,
        json['endStrategy'],
      ) ??
      MultiSearchEndStrategy.latest,
  startOffset: json['startOffset'] as String?,
  startTimestamp: json['startTimestamp'] as String?,
  startPartition: json['startPartition'] as String?,
  fastTraceEnabled: json['fastTraceEnabled'] as bool? ?? false,
  endOffset: json['endOffset'] as String?,
  endTimestamp: json['endTimestamp'] as String?,
  maxResults: json['maxResults'] as String?,
  extractions:
      (json['extractions'] as List<dynamic>?)
          ?.map((e) => ScriptExtraction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ScriptStepToJson(
  _ScriptStep instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'clusterName': instance.clusterName,
  'topicNames': instance.topicNames,
  'filterTemplate': instance.filterTemplate,
  'filterType': _$FilterTypeEnumMap[instance.filterType]!,
  'scope': _$SearchScopeEnumMap[instance.scope]!,
  'startStrategy': _$MultiSearchStartStrategyEnumMap[instance.startStrategy]!,
  'endStrategy': _$MultiSearchEndStrategyEnumMap[instance.endStrategy]!,
  'startOffset': instance.startOffset,
  'startTimestamp': instance.startTimestamp,
  'startPartition': instance.startPartition,
  'fastTraceEnabled': instance.fastTraceEnabled,
  'endOffset': instance.endOffset,
  'endTimestamp': instance.endTimestamp,
  'maxResults': instance.maxResults,
  'extractions': instance.extractions,
};

const _$FilterTypeEnumMap = {
  FilterType.contains: 'contains',
  FilterType.regex: 'regex',
  FilterType.exact: 'exact',
};

const _$SearchScopeEnumMap = {
  SearchScope.key: 'key',
  SearchScope.value: 'value',
  SearchScope.both: 'both',
};

const _$MultiSearchStartStrategyEnumMap = {
  MultiSearchStartStrategy.latest: 'latest',
  MultiSearchStartStrategy.earliest: 'earliest',
  MultiSearchStartStrategy.customOffset: 'customOffset',
  MultiSearchStartStrategy.customTimestamp: 'customTimestamp',
};

const _$MultiSearchEndStrategyEnumMap = {
  MultiSearchEndStrategy.live: 'live',
  MultiSearchEndStrategy.latest: 'latest',
  MultiSearchEndStrategy.customOffset: 'customOffset',
  MultiSearchEndStrategy.customTimestamp: 'customTimestamp',
};
