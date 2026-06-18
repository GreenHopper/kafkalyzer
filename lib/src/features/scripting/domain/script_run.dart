import 'package:kafkalyzer/src/features/scripting/domain/script.dart';

enum ScriptRunStatus { pending, running, completed, error, cancelled }

class ScriptRun {
  final String id;
  final String scriptName;
  final int timestamp;
  final Map<String, String> parameters;
  final ScriptRunStatus status;
  final String? error;
  final String? clusterName;
  final String path;
  final Script? scriptSnapshot;
  final int? totalMessages;
  final int? totalExamined;
  final Map<String, int> topicExamined;
  final Map<String, String> resultVariables;
  final int? startTime;
  final int? endTime;

  // Runtime calculation
  Duration? get runtime {
    if (startTime == null || endTime == null) return null;
    return Duration(milliseconds: endTime! - startTime!);
  }

  const ScriptRun({
    required this.id,
    required this.scriptName,
    required this.timestamp,
    required this.parameters,
    required this.status,
    required this.path,
    this.clusterName,
    this.error,
    this.scriptSnapshot,
    this.totalMessages,
    this.totalExamined,
    this.topicExamined = const {},
    this.resultVariables = const {},
    this.startTime,
    this.endTime,
  });

  ScriptRun copyWith({
    String? id,
    String? scriptName,
    int? timestamp,
    Map<String, String>? parameters,
    ScriptRunStatus? status,
    String? path,
    String? clusterName,
    String? error,
    Script? scriptSnapshot,
    int? totalMessages,
    int? totalExamined,
    Map<String, int>? topicExamined,
    Map<String, String>? resultVariables,
    int? startTime,
    int? endTime,
  }) {
    return ScriptRun(
      id: id ?? this.id,
      scriptName: scriptName ?? this.scriptName,
      timestamp: timestamp ?? this.timestamp,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      path: path ?? this.path,
      clusterName: clusterName ?? this.clusterName,
      error: error ?? this.error,
      scriptSnapshot: scriptSnapshot ?? this.scriptSnapshot,
      totalMessages: totalMessages ?? this.totalMessages,
      totalExamined: totalExamined ?? this.totalExamined,
      topicExamined: topicExamined ?? this.topicExamined,
      resultVariables: resultVariables ?? this.resultVariables,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scriptName': scriptName,
      'timestamp': timestamp,
      'parameters': parameters,
      'status': status.name,
      'path': path,
      'clusterName': clusterName,
      'error': error,
      'scriptSnapshot': scriptSnapshot?.toJson(),
      'totalMessages': totalMessages,
      'totalExamined': totalExamined,
      'topicExamined': topicExamined,
      'resultVariables': resultVariables,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory ScriptRun.fromJson(Map<String, dynamic> json) {
    return ScriptRun(
      id: json['id'] as String,
      scriptName: json['scriptName'] as String,
      timestamp: json['timestamp'] as int,
      parameters: Map<String, String>.from(json['parameters'] ?? {}),
      status: ScriptRunStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ScriptRunStatus.error,
      ),
      path: json['path'] as String,
      clusterName: json['clusterName'] as String?,
      error: json['error'] as String?,
      scriptSnapshot: json['scriptSnapshot'] != null
          ? Script.fromJson(json['scriptSnapshot'])
          : null,
      totalMessages: json['totalMessages'] as int?,
      totalExamined: json['totalExamined'] as int?,
      topicExamined: Map<String, int>.from(json['topicExamined'] ?? {}),
      resultVariables: Map<String, String>.from(json['resultVariables'] ?? {}),
      startTime: json['startTime'] as int?,
      endTime: json['endTime'] as int?,
    );
  }
}
