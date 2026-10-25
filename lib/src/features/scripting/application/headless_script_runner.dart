import 'dart:convert';
import 'dart:io';

import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:logger/logger.dart';

/// Result summary of a headless script pipeline run.
class HeadlessRunResult {
  final bool success;
  final String scriptName;
  final String? runId;
  final int durationMs;
  final Map<String, String> stepStatuses;
  final Map<String, String> extractedVariables;
  final Map<String, int> messageCounts;
  final String? errorMessage;
  final int exitCode;

  const HeadlessRunResult({
    required this.success,
    required this.scriptName,
    this.runId,
    required this.durationMs,
    required this.stepStatuses,
    required this.extractedVariables,
    required this.messageCounts,
    this.errorMessage,
    required this.exitCode,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'scriptName': scriptName,
    if (runId != null) 'runId': runId,
    'durationMs': durationMs,
    'stepStatuses': stepStatuses,
    'extractedVariables': extractedVariables,
    'messageCounts': messageCounts,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'exitCode': exitCode,
  };
}

/// Headless pipeline executor that validates variables and runs a script to completion.
class HeadlessScriptRunner {
  final ScriptRunner? _runner;
  final Logger? _logger;

  HeadlessScriptRunner({ScriptRunner? runner, Logger? logger})
    : _runner = runner,
      _logger = logger;

  ScriptRunner get runner => _runner ?? getIt<ScriptRunner>();
  Logger get logger {
    if (_logger != null) return _logger;
    if (getIt.isRegistered<Logger>()) {
      return getIt<Logger>();
    }
    return Logger();
  }

  /// Formats the CLI invocation command string for a script and its parameter values.
  static String formatCliCommand({
    required String scriptIdOrName,
    required String clusterName,
    Map<String, String> variables = const {},
    String? outputFilePath,
  }) {
    final buffer = StringBuffer('kafkalyzer script run');
    buffer.write(' --script "${scriptIdOrName.replaceAll('"', r'\"')}"');
    buffer.write(' --cluster "${clusterName.replaceAll('"', r'\"')}"');

    for (final entry in variables.entries) {
      if (entry.value.isNotEmpty) {
        final escapedVal = entry.value.replaceAll('"', r'\"');
        buffer.write(' --var ${entry.key}="$escapedVal"');
      }
    }

    if (outputFilePath != null && outputFilePath.isNotEmpty) {
      buffer.write(' --output "$outputFilePath"');
    }

    return buffer.toString();
  }

  /// Validates parameters against script variables.
  /// Throws [ArgumentError] if required variables are missing.
  static Map<String, String> resolveVariables({
    required Script script,
    Map<String, String> providedVariables = const {},
  }) {
    final resolved = Map<String, String>.from(providedVariables);

    // Validate required variables
    final missing = <String>[];
    for (final v in script.variables) {
      final val = resolved[v.name];
      if (val == null || val.isEmpty) {
        missing.add(v.name);
      }
    }

    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing required script variables: ${missing.join(', ')}',
      );
    }

    return resolved;
  }

  /// Runs the script headlessly and returns a structured [HeadlessRunResult].
  Future<HeadlessRunResult> run({
    required Script script,
    required ClusterProfile clusterProfile,
    Map<String, String> variables = const {},
  }) async {
    final stopwatch = Stopwatch()..start();

    Map<String, String> resolvedVariables;
    try {
      resolvedVariables = resolveVariables(
        script: script,
        providedVariables: variables,
      );
    } catch (e) {
      stopwatch.stop();
      return HeadlessRunResult(
        success: false,
        scriptName: script.name,
        durationMs: stopwatch.elapsedMilliseconds,
        stepStatuses: const {},
        extractedVariables: const {},
        messageCounts: const {},
        errorMessage: e.toString(),
        exitCode: 2, // 2 = parameter validation error
      );
    }

    try {
      final run = await runner.runScript(
        script,
        resolvedVariables,
        overrideCluster: clusterProfile,
      );

      stopwatch.stop();

      final stepStatuses = <String, String>{};
      for (final entry in runner.stepStatuses.entries) {
        stepStatuses[entry.key] = entry.value.name;
      }

      final hasError = runner.stepStatuses.values.any(
        (s) => s == StepStatus.error,
      );

      final messageCounts = <String, int>{};
      if (run != null) {
        for (final step in script.steps) {
          for (final topic in step.topicNames) {
            final count = runner.getMatchCount(step.id, topic);
            messageCounts['${step.id}_$topic'] = count;
          }
        }
      }

      return HeadlessRunResult(
        success: !hasError && run != null,
        scriptName: script.name,
        runId: run?.id,
        durationMs: stopwatch.elapsedMilliseconds,
        stepStatuses: stepStatuses,
        extractedVariables: resolvedVariables,
        messageCounts: messageCounts,
        errorMessage: hasError
            ? runner.stepErrorMessages.values.join('; ')
            : null,
        exitCode: (!hasError && run != null) ? 0 : 1,
      );
    } catch (e, st) {
      stopwatch.stop();
      logger.e('Headless script execution failed', error: e, stackTrace: st);
      return HeadlessRunResult(
        success: false,
        scriptName: script.name,
        durationMs: stopwatch.elapsedMilliseconds,
        stepStatuses: const {},
        extractedVariables: resolvedVariables,
        messageCounts: const {},
        errorMessage: e.toString(),
        exitCode: 3, // 3 = execution runtime failure
      );
    }
  }

  /// Prints usage help to [sink].
  static void printUsage([StringSink? sink]) {
    final target = sink ?? stderr;
    target.writeln('''
kafkalyzer headless script runner

Usage:
  kafkalyzer script run --script <name|id|path> --cluster <name> [options]

Options:
  --script <name|id|path> Script name, script ID, or path to a JSON script file
  --cluster <name>        Target cluster profile name
  --var <key=value>       Set a script variable (can be specified multiple times)
  --params <path>         Path to a JSON file containing variable key-value pairs
  --output <path>         Path to write the final JSON execution summary report
  --json                  Output only raw JSON result to stdout
  --help, -h              Show this usage help
''');
  }

  /// Main entrypoint for CLI execution.
  static Future<int> runCli(
    List<String> args, {
    StringSink? stdoutSink,
    StringSink? stderrSink,
    bool shouldExit = true,
    Map<String, String>? environmentOverride,
    ClusterProfile? clusterOverride,
    Script? scriptOverride,
    ScriptRunner? runnerOverride,
  }) async {
    final out = stdoutSink ?? stdout;
    final err = stderrSink ?? stderr;

    // Filter out leading 'script' or 'run' subcommands if invoked like 'kafkalyzer script run ...'
    final filteredArgs = <String>[];
    for (var i = 0; i < args.length; i++) {
      if (filteredArgs.isEmpty && (args[i] == 'script' || args[i] == 'run')) {
        continue;
      }
      filteredArgs.add(args[i]);
    }

    if (filteredArgs.isEmpty ||
        filteredArgs.contains('--help') ||
        filteredArgs.contains('-h')) {
      printUsage(err);
      final code = filteredArgs.isEmpty ? 1 : 0;
      if (shouldExit) exit(code);
      return code;
    }

    String? scriptArg;
    String? clusterName;
    String? paramsPath;
    String? outputPath;
    bool jsonOutputOnly = false;
    final cliVars = <String, String>{};

    for (var i = 0; i < filteredArgs.length; i++) {
      final arg = filteredArgs[i];
      if (arg == '--script' && i + 1 < filteredArgs.length) {
        scriptArg = filteredArgs[++i];
      } else if (arg == '--cluster' && i + 1 < filteredArgs.length) {
        clusterName = filteredArgs[++i];
      } else if (arg == '--params' && i + 1 < filteredArgs.length) {
        paramsPath = filteredArgs[++i];
      } else if (arg == '--output' && i + 1 < filteredArgs.length) {
        outputPath = filteredArgs[++i];
      } else if (arg == '--json') {
        jsonOutputOnly = true;
      } else if (arg == '--var' && i + 1 < filteredArgs.length) {
        final pair = filteredArgs[++i];
        final eqIdx = pair.indexOf('=');
        if (eqIdx > 0) {
          final key = pair.substring(0, eqIdx).trim();
          final val = pair.substring(eqIdx + 1).trim();
          cliVars[key] = val;
        }
      }
    }

    if (scriptArg == null || (clusterName == null && clusterOverride == null)) {
      err.writeln('Error: Both --script and --cluster are required.');
      printUsage(err);
      if (shouldExit) exit(1);
      return 1;
    }

    // Load variables from params file if provided
    final resolvedVars = <String, String>{};
    if (paramsPath != null) {
      final file = File(paramsPath);
      if (!file.existsSync()) {
        err.writeln('Error: Parameters file not found: $paramsPath');
        if (shouldExit) exit(2);
        return 2;
      }
      try {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        for (final entry in map.entries) {
          resolvedVars[entry.key] = entry.value.toString();
        }
      } catch (e) {
        err.writeln('Error parsing parameters JSON: $e');
        if (shouldExit) exit(2);
        return 2;
      }
    }

    // Ingest environment variables prefixed with KAFKALYZER_VAR_
    final env = environmentOverride ?? Platform.environment;
    for (final entry in env.entries) {
      if (entry.key.startsWith('KAFKALYZER_VAR_')) {
        final varName = entry.key.substring('KAFKALYZER_VAR_'.length);
        resolvedVars[varName] = entry.value;
      }
    }

    // CLI variables have highest precedence
    resolvedVars.addAll(cliVars);

    // Resolve ClusterProfile
    ClusterProfile? profile = clusterOverride;
    if (profile == null) {
      try {
        final clusterService = getIt<ClusterService>();
        final clusters = await clusterService.loadClusters();
        profile = clusters.cast<ClusterProfile?>().firstWhere(
          (c) => c?.name == clusterName,
          orElse: () => null,
        );
      } catch (e) {
        err.writeln('Error loading cluster profiles: $e');
        if (shouldExit) exit(3);
        return 3;
      }
    }

    if (profile == null) {
      err.writeln('Error: Cluster profile "$clusterName" not found.');
      if (shouldExit) exit(3);
      return 3;
    }

    // Resolve Script
    Script? script = scriptOverride;
    if (script == null) {
      final scriptFile = File(scriptArg);
      if (scriptFile.existsSync()) {
        try {
          final content = scriptFile.readAsStringSync();
          script = Script.fromJson(jsonDecode(content) as Map<String, dynamic>);
        } catch (e) {
          err.writeln('Error parsing script file "$scriptArg": $e');
          if (shouldExit) exit(2);
          return 2;
        }
      } else {
        try {
          final repo = getIt<ScriptRepository>();
          final scripts = await repo.getScripts();
          script = scripts.cast<Script?>().firstWhere(
            (s) => s?.name == scriptArg || s?.id == scriptArg,
            orElse: () => null,
          );
        } catch (e) {
          err.writeln('Error loading script repository: $e');
          if (shouldExit) exit(3);
          return 3;
        }
      }
    }

    if (script == null) {
      err.writeln('Error: Script "$scriptArg" not found.');
      if (shouldExit) exit(2);
      return 2;
    }

    if (!jsonOutputOnly) {
      err.writeln(
        'Running script: ${script.name} on cluster: ${profile.name}...',
      );
    }

    final headlessRunner = HeadlessScriptRunner(runner: runnerOverride);
    final result = await headlessRunner.run(
      script: script,
      clusterProfile: profile,
      variables: resolvedVars,
    );

    final resultJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(result.toJson());

    if (outputPath != null) {
      try {
        final outFile = File(outputPath);
        outFile.writeAsStringSync(resultJson);
      } catch (e) {
        err.writeln('Warning: Failed to write output file: $e');
      }
    }

    out.writeln(resultJson);
    if (!jsonOutputOnly) {
      if (!result.success) {
        err.writeln('Script execution failed: ${result.errorMessage}');
      } else {
        err.writeln('Script finished successfully in ${result.durationMs}ms.');
      }
    }

    if (shouldExit) exit(result.exitCode);
    return result.exitCode;
  }
}
