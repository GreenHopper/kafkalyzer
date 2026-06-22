import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_editor.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_run_view.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history_view.dart';

class ScriptManagerView extends StatefulWidget {
  const ScriptManagerView({super.key});

  @override
  State<ScriptManagerView> createState() => _ScriptManagerViewState();
}

class _ScriptManagerViewState extends State<ScriptManagerView>
    with TickerProviderStateMixin {
  Script? _selectedScript;
  late TabController _tabController;
  Map<String, String>? _rerunParams;
  Key _runViewKey = UniqueKey();
  ScriptRun? _autoOpenRun;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Attempt to restore state immediately after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptRestoreState();
    });

    // Listen to controller updates (e.g. initial load completion)
    getIt<ScriptController>().addListener(_attemptRestoreState);
  }

  @override
  void dispose() {
    getIt<ScriptController>().removeListener(_attemptRestoreState);
    _tabController.dispose();
    super.dispose();
  }

  void _attemptRestoreState() {
    // If user has already selected a script, don't override it automatically
    // unless you want to force show the running one?
    // Generally, if we just opened the view and _selectedScript is null, we restore.
    if (_selectedScript != null) return;

    final runner = getIt<ScriptRunner>();
    if (runner.isRunning && runner.currentRun != null) {
      final controller = getIt<ScriptController>();
      if (controller.isLoading) return;

      try {
        final runningId = runner.currentRun?.scriptSnapshot?.id;
        final script = controller.scripts.firstWhere((s) => s.id == runningId);

        setState(() {
          _selectedScript = script;
          // Ensure we are on Run tab (index 0)
          if (_tabController.index != 0) {
            _tabController.animateTo(0);
          }
        });
      } catch (_) {
        // Running script not found in loaded scripts (maybe deleted or different scope)
      }
    }
  }

  void _handleRerun(ScriptRun run) {
    setState(() {
      _rerunParams = run.parameters;
      _runViewKey = UniqueKey();
    });
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = getIt<ScriptController>();

    return Row(
      children: [
        // Sidebar List
        _buildSidebar(context, l10n, controller),
        // Main Content (Editor/Details)
        Expanded(
          child: _selectedScript != null
              ? _buildSelectedScriptView(l10n)
              : Center(child: Text(l10n.useSidebarToSelectScript)),
        ),
      ],
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AppLocalizations l10n,
    ScriptController controller,
  ) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(context, l10n, controller),
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: controller.scripts.length,
                  itemBuilder: (context, index) {
                    final script = controller.scripts[index];
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        title: Text(script.name),
                        selected: _selectedScript == script,
                        onTap: () => setState(() => _selectedScript = script),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: l10n.duplicateScript,
                              onPressed: () =>
                                  controller.duplicateScript(script),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () =>
                                  controller.deleteScript(script.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(
    BuildContext context,
    AppLocalizations l10n,
    ScriptController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.scripts, style: Theme.of(context).textTheme.titleLarge),
          _buildHeaderActions(context, l10n, controller),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(
    BuildContext context,
    AppLocalizations l10n,
    ScriptController controller,
  ) {
    return Row(
      children: [
        // Import Button
        IconButton(
          tooltip: l10n.importScripts,
          icon: const Icon(Icons.file_upload),
          onPressed: () => _importScripts(context, l10n, controller),
        ),
        // Export Button
        IconButton(
          tooltip: l10n.exportSelectedScript,
          icon: const Icon(Icons.file_download),
          onPressed: _selectedScript == null
              ? null
              : () => _exportScript(context, l10n, controller),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.createNewScript,
          onPressed: () async {
            // Create new script
            final newScript = await controller.createScript(l10n.newScript);
            setState(() => _selectedScript = newScript);
          },
        ),
      ],
    );
  }

  Future<void> _importScripts(
    BuildContext context,
    AppLocalizations l10n,
    ScriptController controller,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        await controller.importScripts(jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scriptsImportedSuccessfully)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToImport(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportScript(
    BuildContext context,
    AppLocalizations l10n,
    ScriptController controller,
  ) async {
    try {
      final jsonString = controller.exportScript(_selectedScript!);
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: l10n.exportScript,
        fileName: '${_selectedScript!.name}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scriptExportedSuccessfully)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToExport(e.toString()))),
        );
      }
    }
  }

  Widget _buildSelectedScriptView(AppLocalizations l10n) {
    if (_selectedScript == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildScriptsTabBar(l10n),
        Expanded(child: _buildScriptsTabBarView()),
      ],
    );
  }

  Widget _buildScriptsTabBar(AppLocalizations l10n) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: l10n.run),
          Tab(text: l10n.history),
          Tab(text: l10n.editDefinition),
        ],
      ),
    );
  }

  Widget _buildScriptsTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Run Tab
        ScriptRunView(
          key: _runViewKey,
          script: _selectedScript!,
          initialValues: _rerunParams,
          onRunFinished: (ScriptRun run) {
            if (run.status == ScriptRunStatus.completed) {
              setState(() {
                _rerunParams = null; // Clear rerun params if we are done
                _autoOpenRun = run;
              });
              // Navigate to History tab
              _tabController.animateTo(1);
            }
          },
        ),

        // History Tab
        ScriptHistoryView(
          script: _selectedScript!,
          onRerun: _handleRerun,
          initialRun: _autoOpenRun, // New param
        ),

        // Editor Tab
        ScriptEditor(
          script: _selectedScript!,
          onSave: (updated) {
            getIt<ScriptController>().saveScript(updated);
            setState(() => _selectedScript = updated);
          },
        ),
      ],
    );
  }
}
