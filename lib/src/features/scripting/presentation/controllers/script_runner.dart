import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'dart:io';
import 'dart:convert';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/src/features/search/domain/search_json_serializer.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';

enum StepStatus { pending, running, completed, error }

class ScriptRunner extends ChangeNotifier {
  final Logger _logger = getIt<Logger>();
  final MultiSearchController _multiSearchController;

  ScriptRunner({MultiSearchController? multiSearchController})
    : _multiSearchController = multiSearchController ?? getIt<MultiSearchController>();

  /// Executes the given [script] with the provided [variableValues].
  ///
  /// **Contracts:**
  /// 1. **Cluster**: If valid cluster cannot be resolved from step config, usage code must provide [overrideCluster] with a valid profile (including bootstrap servers).
  /// 2. **Variables**:
  ///    - Keys should match the template variables used in the script (e.g. `{{limit}}`).
  ///    - Time variables (e.g. 'from', 'to') can be passed as:
  ///      - Epoch milliseconds (int or string).
  ///      - ISO-8601 string.
  ///      - Localized date string (e.g. "dd.MM.yyyy HH:mm:ss") parseable by the system locale.
  /// 3. **Decoupling**: This runner is UI-agnostic. It relies on [MultiSearchController] for Kafka interactions.
  ///    It does not depend on BuildContext or specific UI widgets.
  MultiSearchController get multiSearchController => _multiSearchController;
  final ClusterListController _clusterController = getIt<ClusterListController>();
  final TopicController _topicController = getIt<TopicController>();

  Map<String, String> _variableValues = {};

  final Map<String, StepStatus> _stepStatuses = {};
  Map<String, StepStatus> get stepStatuses => Map.unmodifiable(_stepStatuses);

  final Map<String, String> _stepErrorMessages = {};
  Map<String, String> get stepErrorMessages => Map.unmodifiable(_stepErrorMessages);

  final Map<String, StepStatus> _topicStatuses = {}; // Key: "stepId_topicName"
  Map<String, StepStatus> get topicStatuses => Map.unmodifiable(_topicStatuses);

  final Map<String, SearchTarget> _activeTargets = {};

  int get totalTopics => _topicStatuses.length;

  int get completedTopics => _topicStatuses.values.where((s) => s == StepStatus.completed).length;

  List<(String topic, SearchProgress? progress)> get activeSearches {
    final active = <(String, SearchProgress?)>[];
    for (final entry in _topicStatuses.entries) {
      if (entry.value == StepStatus.running) {
        // Find target
        final target = _activeTargets[entry.key];
        if (target != null) {
          final progress = _multiSearchController.progress[target];
          active.add((target.topic.name, progress));
        }
      }
    }
    return active;
  }

  // Deprecated: use activeSearches instead
  List<String> get activeTopics => activeSearches.map((e) => e.$1).toSet().toList();

  SearchProgress? getProgress(String stepId, String topic) {
    final key = "${stepId}_$topic";
    final target = _activeTargets[key];
    if (target == null) return null;
    return _multiSearchController.progress[target];
  }

  int getMatchCount(String stepId, String topic) {
    final key = "${stepId}_$topic";
    final target = _activeTargets[key];
    if (target == null) return 0;
    return _multiSearchController.getMessagesFor(target).length;
  }

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  ScriptRun? _currentRun;
  ScriptRun? get currentRun => _currentRun;

  // Resolve dependencies
  ClusterProfile? _resolveCluster(String name) {
    return _clusterController.clusters.cast<ClusterProfile?>().firstWhere((c) => c?.name == name, orElse: () => null);
  }

  // Helper to replace template variables
  String? _applyTemplate(String? template) {
    if (template == null) return null;
    return template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final key = match.group(1)!.trim();
      return _variableValues[key] ?? match.group(0)!;
    });
  }

  int? _resolveInt(String? template) {
    if (template == null || template.isEmpty) return null;
    final text = _applyTemplate(template)!.trim();

    // Try integer
    final i = int.tryParse(text);
    if (i != null) return i;

    // Try standard ISO parse
    try {
      final d = DateTime.parse(text);
      return d.millisecondsSinceEpoch;
    } catch (_) {}

    // Try multiple custom formats
    // Use single 'd' and 'M' to allow both 1 and 2 digit strings (e.g. 1.1.2026 and 01.01.2026)
    final formats = [
      DateFormat("d.M.yyyy HH:mm:ss"),
      DateFormat("d.M.yyyy HH:mm"),
      DateFormat("d.M.yyyy"),
      DateFormat("yyyy-M-d HH:mm:ss"),
      DateFormat("yyyy-M-d HH:mm"),
      DateFormat("yyyy-M-d"),
    ];

    for (final fmt in formats) {
      try {
        final d = fmt.parse(text); // Use parse for better leniency
        return d.millisecondsSinceEpoch;
      } catch (_) {
        // Continue to next format
      }
    }

    return null;
  }

  bool _isCancelled = false;

  Future<void> cancelScript() async {
    if (!_isRunning) return;
    _isCancelled = true;
    _logger.i("Cancelling script execution...");

    // Explicitly stop all active targets to unblock the runner loop
    for (var target in _activeTargets.values) {
      _multiSearchController.stopTarget(target);
    }
    notifyListeners();
  }

  Future<ScriptRun?> runScript(
    Script script,
    Map<String, String> variableValues, {
    ClusterProfile? overrideCluster,
  }) async {
    if (_isRunning) return null;

    _variableValues = variableValues;
    _isRunning = true;
    _isCancelled = false;
    _stepStatuses.clear();
    _stepErrorMessages.clear();
    _topicStatuses.clear();
    _activeTargets.clear();

    // Setup Run Directory
    String? previousDir = _multiSearchController.outputDirectory;
    String? runDir;
    ScriptRun? currentRun;

    try {
      final baseDir = script.outputDirectory ?? previousDir;
      if (baseDir != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final runId = "${script.name}_$timestamp";
        final dir = Directory("$baseDir/$runId");
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }
        runDir = dir.path;
        await _multiSearchController.setDirectory(runDir);

        // Create Manifest
        currentRun = ScriptRun(
          id: runId,
          scriptName: script.name,
          timestamp: timestamp,
          parameters: variableValues,
          status: ScriptRunStatus.running,
          path: runDir,
          clusterName: overrideCluster?.name,
          scriptSnapshot: script,
          startTime: timestamp,
        );
        _currentRun = currentRun;
        await File("$runDir/run_manifest.json").writeAsString(jsonEncode(currentRun.toJson()));
      }
    } catch (e) {
      _logger.e("Failed to setup run directory", error: e);
    }

    // Initialize statuses and work queue
    final workQueue = <MapEntry<ScriptStep, String>>[];
    for (var step in script.steps) {
      _stepStatuses[step.id] = StepStatus.pending;
      for (var topic in step.topicNames) {
        _topicStatuses["${step.id}_$topic"] = StepStatus.pending;
        workQueue.add(MapEntry(step, topic));
      }
    }
    int totalFound = 0;
    int totalExamined = 0;
    final topicExamined = <String, int>{};
    notifyListeners();

    try {
      // if (script.outputDirectory != null) {
      //   await _multiSearchController.setDirectory(script.outputDirectory);
      // }
      // Directory already set above

      final activeFutures = <String, Future<void>>{};

      // Main execution loop
      while ((workQueue.isNotEmpty || activeFutures.isNotEmpty) && !_isCancelled) {
        // Fill active slots
        while (activeFutures.length < script.concurrencyLimit && workQueue.isNotEmpty && !_isCancelled) {
          // Find first runnable item (dependencies met)
          int? runnableIndex;
          for (int i = 0; i < workQueue.length; i++) {
            final step = workQueue[i].key;
            final required = _getRequiredVariables(step);
            // Check if all required variables exist in _variableValues
            if (required.every((v) => _variableValues.containsKey(v))) {
              runnableIndex = i;
              break;
            }
          }

          if (runnableIndex == null) {
            // No runnable items found in queue currently
            break;
          }

          final item = workQueue.removeAt(runnableIndex);
          final step = item.key;
          final topicName = item.value;
          final key = "${step.id}_$topicName";

          _logger.i("Starting execution for Step '${step.name}' on topic '$topicName' (key: $key)");
          _stepStatuses[step.id] = StepStatus.running;
          _topicStatuses[key] = StepStatus.running;
          notifyListeners();

          final future = _runSearchForTopic(step, overrideCluster ?? _resolveCluster(step.clusterName), topicName)
              .then((_) {
                _logger.i("Execution completed for Step '${step.name}' on topic '$topicName' (key: $key)");
                final target = _activeTargets[key];
                if (target != null) {
                  totalFound += _multiSearchController.getMessagesFor(target).length;
                  final prog = _multiSearchController.progress[target];
                  if (prog != null) {
                    topicExamined[key] = prog.scanned;
                    totalExamined += prog.scanned;
                  }
                }
                _topicStatuses[key] = StepStatus.completed;
                notifyListeners();
              })
              .catchError((e) {
                _logger.e("Topic $topicName failed", error: e);
                _topicStatuses[key] = StepStatus.error;
                _stepErrorMessages[step.id] = e.toString();
                notifyListeners();
              })
              .whenComplete(() {
                activeFutures.remove(key);
                _updateStepStatus(step);
                notifyListeners();
              });

          activeFutures[key] = future;
        }

        if (activeFutures.isEmpty && workQueue.isEmpty) break;

        if (activeFutures.isNotEmpty) {
          await Future.any(activeFutures.values);
        } else {
          // activeFutures is empty, but workQueue is not empty.
          // This means we have items in queue but they are blocked by missing dependencies.
          // Since no tasks are running, these dependencies will never be met.
          _logger.w("Script execution stalled: dependencies not met for remaining steps.");

          for (final item in workQueue) {
            final step = item.key;
            final topicName = item.value;
            final key = "${step.id}_$topicName";

            final required = _getRequiredVariables(step);
            final missing = required.where((v) => !_variableValues.containsKey(v)).toList();

            final errorMsg = "Missing variables: ${missing.join(', ')}";
            _stepErrorMessages[step.id] = errorMsg;
            _topicStatuses[key] = StepStatus.error;
            _stepStatuses[step.id] = StepStatus.error;
          }

          notifyListeners();
          workQueue.clear(); // Exit loop
          break;
        }
      }

      if (_isCancelled) {
        for (var target in _activeTargets.values) {
          _multiSearchController.stopTarget(target);
        }
      }

      // Final status check
      for (var step in script.steps) {
        _updateStepStatus(step);
      }
      if (currentRun != null && runDir != null) {
        // Update manifest
        final status = _isCancelled ? ScriptRunStatus.cancelled : ScriptRunStatus.completed; // Simplified
        // A more accurate status would check if any errors occurred
        final hasError = _stepStatuses.values.any((s) => s == StepStatus.error);
        final finalStatus = hasError ? ScriptRunStatus.error : status;

        final updatedRun = ScriptRun(
          id: currentRun.id,
          scriptName: currentRun.scriptName,
          timestamp: currentRun.timestamp,
          parameters: currentRun.parameters,
          status: finalStatus,
          path: currentRun.path,
          clusterName: currentRun.clusterName,
          scriptSnapshot: currentRun.scriptSnapshot,
          totalMessages: totalFound,
          totalExamined: totalExamined,
          topicExamined: topicExamined,
          resultVariables: Map<String, String>.from(_variableValues),
          startTime: currentRun.startTime,
          endTime: DateTime.now().millisecondsSinceEpoch,
        );
        await File("$runDir/run_manifest.json").writeAsString(jsonEncode(updatedRun.toJson()));
        currentRun = updatedRun;
        _currentRun = currentRun;
      }
    } catch (e) {
      _logger.e("Script execution error", error: e);
      if (currentRun != null && runDir != null) {
        try {
          final updatedRun = ScriptRun(
            id: currentRun.id,
            scriptName: currentRun.scriptName,
            timestamp: currentRun.timestamp,
            parameters: currentRun.parameters,
            status: ScriptRunStatus.error,
            error: e.toString(),
            path: currentRun.path,
            clusterName: currentRun.clusterName,
            scriptSnapshot: currentRun.scriptSnapshot,
            totalMessages: totalFound,
            totalExamined: totalExamined,
            topicExamined: topicExamined,
            resultVariables: Map<String, String>.from(_variableValues),
            startTime: currentRun.startTime,
            endTime: DateTime.now().millisecondsSinceEpoch,
          );
          await File("$runDir/run_manifest.json").writeAsString(jsonEncode(updatedRun.toJson()));
          currentRun = updatedRun;
          _currentRun = currentRun;
        } catch (_) {}
      }
    } finally {
      _isRunning = false;
      notifyListeners();
      // Restore directory
      if (previousDir != null) {
        _multiSearchController.setDirectory(previousDir);
      }
    }

    return currentRun;
  }

  Future<List<ScriptRun>> getPastRuns(Script script) async {
    final baseDir = script.outputDirectory ?? _multiSearchController.outputDirectory;
    if (baseDir == null) return [];

    final dir = Directory(baseDir);
    if (!dir.existsSync()) return [];

    final runs = <ScriptRun>[];
    try {
      await for (var entity in dir.list()) {
        if (entity is Directory) {
          final manifestFile = File("${entity.path}/run_manifest.json");
          if (await manifestFile.exists()) {
            try {
              final json = jsonDecode(await manifestFile.readAsString());
              // Override path with actual current location
              final run = ScriptRun.fromJson(json).copyWith(path: entity.path);
              runs.add(run);
            } catch (e) {
              _logger.w("Failed to parse run manifest at ${entity.path}", error: e);
            }
          }
        }
      }
    } catch (e) {
      _logger.e("Error scanning past runs", error: e);
    }

    // Filter by script name to ensure we don't show runs from other scripts
    // that might share the same output directory.
    final filteredRuns = runs.where((r) => r.scriptName == script.name).toList();

    // Sort by timestamp desc
    filteredRuns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filteredRuns;
  }

  void _updateStepStatus(ScriptStep step) {
    final statuses = step.topicNames.map((t) => _topicStatuses["${step.id}_$t"]).toList();
    if (statuses.any((s) => s == StepStatus.running)) {
      _stepStatuses[step.id] = StepStatus.running;
    } else if (statuses.any((s) => s == StepStatus.error)) {
      _stepStatuses[step.id] = StepStatus.error;
    } else if (statuses.every((s) => s == StepStatus.completed)) {
      _stepStatuses[step.id] = StepStatus.completed;
    } else {
      if (statuses.every((s) => s == StepStatus.pending)) {
        _stepStatuses[step.id] = StepStatus.pending;
      } else {
        _stepStatuses[step.id] = StepStatus.running;
      }
    }
  }

  Future<List<ScriptResultMessage>> loadRunResults(ScriptRun run) async {
    final messages = <ScriptResultMessage>[];
    final runDir = Directory(run.path);
    if (!await runDir.exists()) return [];

    try {
      await for (final entity in runDir.list(recursive: true)) {
        if (entity is File &&
            entity.path.endsWith('.json') &&
            !entity.path.split('/').last.startsWith('run_manifest')) {
          final filename = entity.path.split(Platform.pathSeparator).last;
          // Expected format: search_results_{stepId}_{topic}_{timestamp}.json
          // Or search_results_{topic}_{timestamp}.json if stepId is null.

          if (!filename.startsWith('search_results_')) continue;

          String? stepId;
          String stepName = "Unknown";

          final parts = filename.substring('search_results_'.length).split('_');

          final steps = run.scriptSnapshot?.steps ?? [];

          if (steps.isNotEmpty && parts.isNotEmpty) {
            // Check if parts[0] is a step ID.
            final candidateId = parts[0];
            final step = steps.where((s) => s.id == candidateId).firstOrNull;

            if (step != null) {
              stepId = step.id;
              stepName = step.name;
              // This `topicName` variable was unused, so it's removed.
              // if (parts.length > 2) {
              //   topicName = parts.sublist(1, parts.length - 1).join('_');
              // }
            } else {
              // Maybe stepId not present?
              // Topic is everything except last part?
              // This `topicName` variable was unused, so it's removed.
              // topicName = parts.sublist(0, parts.length - 1).join('_');
              // Check if topicName matches a topic in any step?
              // It's ambiguous. But MultiSearchController prefixes stepId if present.
              // And ScriptRunner always provides stepId when running steps.

              // If we can't find stepId, we might assume it's global or unmatched.
            }
          }

          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);

            if (json is Map<String, dynamic> && json.containsKey('messages')) {
              final rawMsgs = json['messages'] as List;
              for (final raw in rawMsgs) {
                final kMsg = SearchJsonSerializer.deserializeMessage(raw);
                messages.add(
                  ScriptResultMessage(
                    topic: kMsg.topic,
                    partition: kMsg.partition,
                    offset: kMsg.offset,
                    key: kMsg.key,
                    payload: kMsg.payload,
                    timestamp: kMsg.timestamp,
                    stepId: stepId ?? "global",
                    stepName: stepName,
                  ),
                );
              }
            }
          } catch (e) {
            _logger.w("Failed to parse results file ${entity.path}", error: e);
          }
        }
      }
    } catch (e) {
      _logger.e("Error loading run results", error: e);
    }

    // Sort
    // Build step index map for sorting
    final stepOrder = <String, int>{};
    if (run.scriptSnapshot != null) {
      for (int i = 0; i < run.scriptSnapshot!.steps.length; i++) {
        stepOrder[run.scriptSnapshot!.steps[i].id] = i;
      }
    }

    // Sort: Timestamp ASC -> Step Order ASC -> Topic ASC -> Partition ASC -> Offset ASC
    messages.sort((a, b) => compareScriptResultMessages(a, b, stepOrder));
    return messages;
  }

  @visibleForTesting
  static int compareScriptResultMessages(ScriptResultMessage a, ScriptResultMessage b, Map<String, int> stepOrder) {
    int cmp = a.timestamp.compareTo(b.timestamp); // Timestamp ASC
    if (cmp != 0) return cmp;

    // Same timestamp: Check step order
    // Default to a high number (unknown step) to push to end? Or -1 to push to start?
    // "Sort by Step ASC": Order 0, 1, 2...
    // Unknown step (-1 or null) -> Usually should be last or first?
    // Let's assume unknown steps come LAST (high index).
    final stepIndexA = stepOrder[a.stepId] ?? 999999;
    final stepIndexB = stepOrder[b.stepId] ?? 999999;
    cmp = stepIndexA.compareTo(stepIndexB); // Ascending step order
    if (cmp != 0) return cmp;

    // Same step: Check topic
    cmp = a.topic.compareTo(b.topic);
    if (cmp != 0) return cmp;

    // Same topic: Check partition
    cmp = a.partition.compareTo(b.partition);
    if (cmp != 0) return cmp;

    // Same partition: Check offset (ascending)
    return a.offset.compareTo(b.offset);
  }

  Future<String?> exportRunArchive(ScriptRun run) async {
    try {
      final sourceDir = Directory(run.path);
      if (!sourceDir.existsSync()) return null;

      // Create an Archive object
      final archive = Archive();

      // recursivly add files
      final files = sourceDir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.substring(sourceDir.path.length + 1); // Relative path
          final data = file.readAsBytesSync();
          archive.addFile(ArchiveFile(fileName, data.length, data));
        }
      }

      final zipEncoder = ZipEncoder();
      final encodedArchive = zipEncoder.encode(archive);

      if (encodedArchive.isEmpty) return null;

      final tempDir = await getTemporaryDirectory();
      final destPath = "${tempDir.path}/${run.id}.zip";

      final zipFile = File(destPath);
      zipFile.writeAsBytesSync(encodedArchive);

      return destPath;
    } catch (e) {
      _logger.e("Error exporting run archive", error: e);
      return null;
    }
  }

  Future<void> deleteRun(ScriptRun run) async {
    try {
      final dir = Directory(run.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      notifyListeners();
    } catch (e) {
      _logger.e("Error deleting run", error: e);
      rethrow;
    }
  }

  Future<void> importRunArchive(String archivePath, Script script) async {
    try {
      final bytes = File(archivePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Determine destination directory
      String? baseDir = script.outputDirectory;

      // Validate baseDir exists
      if (baseDir != null && !Directory(baseDir).existsSync()) {
        baseDir = null;
      }

      if (baseDir == null) {
        // Fallback: Check global default settings
        final prefs = await SharedPreferences.getInstance();
        final defaultGlobal = prefs.getString('general_default_output_dir');

        if (defaultGlobal != null && Directory(defaultGlobal).existsSync()) {
          // Use defaultGlobal/scriptName
          final safeName = script.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          baseDir = "$defaultGlobal/$safeName";
          if (!Directory(baseDir).existsSync()) {
            Directory(baseDir).createSync(recursive: true);
          }
        } else {
          baseDir = _multiSearchController.outputDirectory ?? (await getApplicationDocumentsDirectory()).path;
        }
      }

      // First pass: Find manifest to get ID
      String? runId;
      for (final file in archive) {
        if (file.name == 'run_manifest.json') {
          final content = utf8.decode(file.content as List<int>);
          final json = jsonDecode(content);
          runId = json['id'];
          break;
        }
      }

      // Fallback if no manifest or ID found (shouldn't happen for valid exports)
      // Use zip filename without extension as fallback ID
      if (runId == null) {
        final filename = archivePath.split(Platform.pathSeparator).last;
        runId = filename.endsWith('.zip') ? filename.substring(0, filename.length - 4) : filename;
      }

      final targetDir = Directory('$baseDir/$runId');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${targetDir.path}/${file.name}');
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
        }
      }
      notifyListeners();
    } catch (e) {
      _logger.e("Error importing run archive", error: e);
      rethrow;
    }
  }

  Future<void> _runSearchForTopic(ScriptStep step, ClusterProfile? cluster, String topicName) async {
    if (cluster == null) {
      throw Exception("Cluster '${step.clusterName}' not found or not connected");
    }

    final topic = _topicController
        .getTopics(cluster)
        ?.firstWhere(
          (t) => t.name == topicName,
          orElse: () => TopicMetadata(name: topicName, partitionCount: 0, replicationFactor: 1),
        );

    final startConfig = _resolveStartStrategy(step);
    final endConfig = _resolveEndStrategy(step);
    final filterConfig = _resolveFilterConfiguration(step);

    final target = SearchTarget(
      profile: cluster,
      topic: topic ?? TopicMetadata(name: topicName, partitionCount: 0, replicationFactor: 1),
      filterTerm: filterConfig.filterTerm,
      filterTerms: filterConfig.expandedTerms,
      filterType: filterConfig.filterType,
      scope: step.scope,
      startOffset: startConfig.offset,
      startTimestamp: startConfig.timestamp,
      startPartition: _resolveInt(step.startPartition),
      fastTraceEnabled: step.fastTraceEnabled,
      endStrategy: endConfig.strategy,
      endOffset: endConfig.offset,
      endTimestamp: endConfig.timestamp,
      maxResults: _resolveInt(step.maxResults),
      stepId: step.id,
    );

    _activeTargets["${step.id}_$topicName"] = target;
    _multiSearchController.addTarget(target);

    final completer = Completer<void>();

    void checkStatus() {
      if (completer.isCompleted) return;

      if (!_multiSearchController.targets.contains(target)) {
        completer.complete();
        return;
      }
      final status = _multiSearchController.status[target];
      if (status == SearchStatus.stopped || status == SearchStatus.error) {
        completer.complete();
      }
    }

    if (_multiSearchController.status[target] == SearchStatus.stopped) {
      if (!completer.isCompleted) completer.complete();
    }

    void listenerFn() => checkStatus();
    _multiSearchController.addListener(listenerFn);

    await completer.future;
    _multiSearchController.removeListener(listenerFn);

    // Process extractions after completion
    if (_multiSearchController.status[target] != SearchStatus.error) {
      await _processExtractions(step, target);
    }
  }

  ({int? offset, int? timestamp}) _resolveStartStrategy(ScriptStep step) {
    int? startOffset;
    int? startTimestamp;

    switch (step.startStrategy) {
      case MultiSearchStartStrategy.earliest:
        startOffset = 0;
        break;
      case MultiSearchStartStrategy.latest:
        break;
      case MultiSearchStartStrategy.customOffset:
        startOffset = _resolveInt(step.startOffset);
        startOffset ??= 0;
        break;
      case MultiSearchStartStrategy.customTimestamp:
        startTimestamp = _resolveInt(step.startTimestamp);
        if (startTimestamp == null) {
          _logger.w(
            "startTimestamp variable '${step.startTimestamp}' could not be resolved. Defaulting to Earliest (offset 0).",
          );
          startOffset = 0;
        }
        break;
    }
    return (offset: startOffset, timestamp: startTimestamp);
  }

  ({MultiSearchEndStrategy strategy, int? offset, int? timestamp}) _resolveEndStrategy(ScriptStep step) {
    var endStrategy = step.endStrategy;
    int? endOffset = _resolveInt(step.endOffset);
    int? endTimestamp = _resolveInt(step.endTimestamp);

    if (endStrategy == MultiSearchEndStrategy.customOffset && endOffset == null) {
      endStrategy = MultiSearchEndStrategy.latest;
    }
    if (endStrategy == MultiSearchEndStrategy.customTimestamp && endTimestamp == null) {
      _logger.w("endTimestamp variable '${step.endTimestamp}' could not be resolved. Defaulting to Latest.");
      endStrategy = MultiSearchEndStrategy.latest;
    }
    return (strategy: endStrategy, offset: endOffset, timestamp: endTimestamp);
  }

  ({String? filterTerm, List<String>? expandedTerms, FilterType filterType}) _resolveFilterConfiguration(
    ScriptStep step,
  ) {
    String? filterTerm;
    List<String>? expandedFilterTerms;
    var filterType = step.filterType;

    if (step.filterTemplate != null) {
      final template = step.filterTemplate!;
      final varRegex = RegExp(r'\{\{([^}]+)\}\}');
      bool hasMultiValue = false;

      // Check for multi-values
      for (final match in varRegex.allMatches(template)) {
        final key = match.group(1)!.trim();
        final val = _variableValues[key];
        if (val != null && val.contains(',')) {
          hasMultiValue = true;
          break;
        }
      }

      if (hasMultiValue && filterType != FilterType.regex) {
        expandedFilterTerms = _expandMultiValueFilter(template, varRegex);
      } else {
        filterTerm = _applyTemplate(template);
      }
    }
    return (filterTerm: filterTerm, expandedTerms: expandedFilterTerms, filterType: filterType);
  }

  List<String> _expandMultiValueFilter(String template, RegExp varRegex) {
    // Expand into list of strings instead of Regex to avoid engine limits/bugs
    final matches = varRegex.allMatches(template).toList();
    String baseTemplate = template;
    final multiVars = <String, List<String>>{};

    for (final match in matches) {
      final key = match.group(1)!.trim();
      final val = _variableValues[key] ?? match.group(0)!;
      if (val.contains(',')) {
        multiVars[key] = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else {
        baseTemplate = baseTemplate.replaceAll(match.group(0)!, val.trim());
      }
    }

    List<String> currentTerms = [baseTemplate];
    multiVars.forEach((key, values) {
      final nextTerms = <String>[];
      final placeholder = "{{$key}}";

      for (final term in currentTerms) {
        for (final val in values) {
          nextTerms.add(term.replaceAll(placeholder, val));
        }
      }
      if (nextTerms.isNotEmpty) {
        currentTerms = nextTerms;
      }
    });
    return currentTerms;
  }

  Future<void> _processExtractions(ScriptStep step, SearchTarget target) async {
    final extractions = step.extractions;
    if (extractions.isEmpty) return;

    final messages = _multiSearchController.getMessagesFor(target);
    for (final extraction in extractions) {
      // Filter by topic if specified
      if (extraction.topic != null && extraction.topic != target.topic.name) {
        continue;
      }

      final Set<String> foundValues = {};

      for (final msg in messages) {
        String? data;
        if (extraction.source == ScriptExtractionSource.key) {
          data = msg.key;
        } else {
          data = msg.payload;
        }

        if (data == null) continue;

        if (extraction.jsonPath.isEmpty) {
          // Extract partial or full value if path is empty
          foundValues.add(data);
        } else {
          try {
            final dynamic json = jsonDecode(data);
            final value = _extractValue(json, extraction.jsonPath);
            if (value != null) {
              foundValues.add(value);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }

      if (foundValues.isNotEmpty) {
        // Merge with existing values to handle multi-topic/multi-step concurrency
        final existing = _variableValues[extraction.variableName];
        String newValue;
        if (existing != null && existing.isNotEmpty) {
          final merged = {...existing.split(','), ...foundValues};
          newValue = merged.join(',');
        } else {
          newValue = foundValues.join(',');
        }

        _variableValues[extraction.variableName] = newValue;
        _logger.i("Extracted variable '${extraction.variableName}': $newValue");
      }
    }
  }

  Set<String> _getRequiredVariables(ScriptStep step) {
    final vars = <String>{};
    if (step.filterTemplate != null) {
      vars.addAll(_extractTemplateVars(step.filterTemplate!));
    }
    if (step.startTimestamp != null) {
      vars.addAll(_extractTemplateVars(step.startTimestamp!));
    }
    if (step.endTimestamp != null) {
      vars.addAll(_extractTemplateVars(step.endTimestamp!));
    }
    if (step.startOffset != null) {
      vars.addAll(_extractTemplateVars(step.startOffset!));
    }
    if (step.endOffset != null) {
      vars.addAll(_extractTemplateVars(step.endOffset!));
    }
    if (step.startPartition != null) {
      vars.addAll(_extractTemplateVars(step.startPartition!));
    }
    if (step.maxResults != null) {
      vars.addAll(_extractTemplateVars(step.maxResults!));
    }
    return vars;
  }

  Set<String> _extractTemplateVars(String template) {
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    return regex.allMatches(template).map((m) => m.group(1)!.trim()).toSet();
  }

  String? _extractValue(dynamic data, String path) {
    if (path.isEmpty) return null;
    final parts = path.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current?.toString();
  }

  Future<void> cleanupHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxRuns = prefs.getInt('scripting_max_run_history') ?? 30; // Default 30

      if (maxRuns <= 0) {
        return; // Disable cleanup if <= 0
      }

      // Collect all directories to clean
      final directoriesToClean = <String>{};

      // 1. Global default dir
      final defaultDir =
          _multiSearchController.outputDirectory ??
          prefs.getString('general_default_output_dir') ??
          (await getApplicationDocumentsDirectory()).path;
      directoriesToClean.add(defaultDir);

      // 2. Custom script directories
      try {
        final scriptRepo = getIt<ScriptRepository>();
        final scripts = await scriptRepo.getScripts();
        for (final script in scripts) {
          if (script.outputDirectory != null && script.outputDirectory!.isNotEmpty) {
            directoriesToClean.add(script.outputDirectory!);
          }
        }
      } catch (e) {
        _logger.w("Failed to resolve custom script directories during cleanup", error: e);
      }

      _logger.i("Running cleanup on ${directoriesToClean.length} directories. Max runs: $maxRuns");

      for (final dirPath in directoriesToClean) {
        await _cleanupDirectory(dirPath, maxRuns);
      }
    } catch (e) {
      _logger.e("Error during history cleanup", error: e);
    }
  }

  Future<void> _cleanupDirectory(String path, int maxRuns) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final runs = <ScriptRun>[];
    try {
      await for (var entity in dir.list()) {
        if (entity is Directory) {
          final manifestFile = File("${entity.path}/run_manifest.json");
          if (await manifestFile.exists()) {
            try {
              final json = jsonDecode(await manifestFile.readAsString());
              final run = ScriptRun.fromJson(json).copyWith(path: entity.path);
              runs.add(run);
            } catch (_) {
              // Ignore invalid runs
            }
          }
        }
      }
    } catch (e) {
      // Ignore listing errors
    }

    // Sort: Newest first
    runs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (runs.length > maxRuns) {
      final toDelete = runs.sublist(maxRuns);
      _logger.i("[$path] Cleanup: Deleting ${toDelete.length} old runs (Total: ${runs.length}, Limit: $maxRuns)");
      for (final run in toDelete) {
        try {
          await deleteRun(run);
        } catch (e) {
          _logger.w("Failed to delete old run ${run.id}", error: e);
        }
      }
    }
  }
}
