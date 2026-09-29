import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_header.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_sidebar.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_schemas_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RunViewType { groupedByStep, byTopic, chronological }

class ScriptRunDetailsView extends StatefulWidget {
  final ScriptRun run;
  final Script script;
  final VoidCallback onBack;

  static const String sidebarCollapsedPrefKey = 'script_run_sidebar_collapsed';

  const ScriptRunDetailsView({
    super.key,
    required this.run,
    required this.script,
    required this.onBack,
  });

  @override
  State<ScriptRunDetailsView> createState() => _ScriptRunDetailsViewState();
}

class _ScriptRunDetailsViewState extends State<ScriptRunDetailsView> {
  final _logger = getIt<Logger>();

  List<ScriptResultMessage>? _allMessages;
  Map<String, Map<String, List<KafkaMessage>>>? _groupedResults;
  bool _loadingDetails = false;

  String _timelineMode = 'topic';
  RunViewType _currentViewType = RunViewType.byTopic;

  final Map<String, Set<String>> _selectedTopics = {};
  final Map<String, Set<String>> _parameterFilters = {};
  bool _isRunSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadRunDetails();
  }

  @override
  void didUpdateWidget(covariant ScriptRunDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.run.id != oldWidget.run.id) {
      _loadRunDetails();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final viewModeIdx =
            prefs.getInt('script_result_view_mode') ??
            RunViewType.byTopic.index;
        _currentViewType = RunViewType.values[viewModeIdx];

        switch (_currentViewType) {
          case RunViewType.chronological:
            _timelineMode = 'chronological';
            break;
          case RunViewType.groupedByStep:
            _timelineMode = 'step';
            break;
          case RunViewType.byTopic:
            _timelineMode = 'topic';
            break;
        }

        _isRunSidebarCollapsed =
            prefs.getBool(ScriptRunDetailsView.sidebarCollapsedPrefKey) ??
            false;
      });
    }
  }

  Future<void> _toggleRunSidebar() async {
    setState(() => _isRunSidebarCollapsed = !_isRunSidebarCollapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ScriptRunDetailsView.sidebarCollapsedPrefKey,
      _isRunSidebarCollapsed,
    );
  }

  Future<void> _loadRunDetails() async {
    setState(() {
      _groupedResults = null;
      _allMessages = null;
      _selectedTopics.clear();
      _parameterFilters.clear();
      _loadingDetails = true;
    });

    try {
      final grouped = <String, Map<String, List<KafkaMessage>>>{};
      final allMessages = await getIt<ScriptRunner>().loadRunResults(
        widget.run,
      );

      for (final msg in allMessages) {
        grouped.putIfAbsent(msg.stepId, () => {});
        grouped[msg.stepId]!.putIfAbsent(msg.topic, () => []);
        grouped[msg.stepId]![msg.topic]!.add(msg);
      }

      for (var topics in grouped.values) {
        for (var msgs in topics.values) {
          msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }

      if (mounted) {
        setState(() {
          _groupedResults = grouped;
          _allMessages = allMessages;
          _loadingDetails = false;
        });
      }
    } catch (e) {
      _logger.e("Failed to load run details", error: e);
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allMessages == null) {
      return _buildErrorView();
    }

    return _buildMainContent();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Failed to load details"),
          ElevatedButton(
            onPressed: _loadRunDetails,
            child: const Text("Retry"),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onBack, child: const Text("Back")),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final scriptSteps =
        (widget.run.scriptSnapshot?.steps ?? widget.script.steps)
            .cast<ScriptStep>();
    final stepExtractions = {
      for (final s in widget.script.steps) s.id: s.extractions,
    };

    return Column(
      children: [
        ScriptRunHeader(
          run: widget.run,
          timelineMode: _timelineMode,
          onTimelineModeChanged: (mode) async {
            setState(() {
              _timelineMode = mode;
              switch (_timelineMode) {
                case 'chronological':
                  _currentViewType = RunViewType.chronological;
                  break;
                case 'step':
                  _currentViewType = RunViewType.groupedByStep;
                  break;
                case 'topic':
                default:
                  _currentViewType = RunViewType.byTopic;
                  break;
              }
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(
              'script_result_view_mode',
              _currentViewType.index,
            );
          },
          onBack: widget.onBack,
          isSidebarVisible: !_isRunSidebarCollapsed,
          onToggleSidebar: _toggleRunSidebar,
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isRunSidebarCollapsed)
                ScriptRunSidebar(
                  run: widget.run,
                  scriptSteps: scriptSteps,
                  groupedResults: _groupedResults!,
                  totalMessages: _allMessages!.length,
                  selectedTopics: _selectedTopics,
                  parameterFilters: _parameterFilters,
                  onTopicToggle: _toggleTopicSelection,
                  onClearSelection: () => _toggleAllSelection(false),
                  onStepToggle: _toggleStepSelection,
                  onParameterFilterChanged: (param, selected) {
                    setState(() {
                      if (selected.isEmpty) {
                        _parameterFilters.remove(param);
                      } else {
                        _parameterFilters[param] = selected;
                      }
                    });
                  },
                ),
              Expanded(
                child: MessagesView(
                  messages: _getFilteredResults(),
                  showTopic: true,
                  showStep: true,
                  stepExtractions: stepExtractions,
                  preferencesKey: 'script_result_active_view',
                  sortComparator: _scriptSortComparator,
                  schemaViewBuilder: (context, searchPhrase) {
                    return ScriptSchemasView(
                      script: widget.script,
                      searchPhrase: searchPhrase,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _scriptSortComparator(KafkaMessage a, KafkaMessage b) {
    switch (_currentViewType) {
      case RunViewType.chronological:
        return a.timestamp.compareTo(b.timestamp);
      case RunViewType.byTopic:
        final cmp = a.topic.compareTo(b.topic);
        if (cmp != 0) return cmp;
        return a.timestamp.compareTo(b.timestamp);
      case RunViewType.groupedByStep:
        final stepA = a is ScriptResultMessage ? a.stepName : '';
        final stepB = b is ScriptResultMessage ? b.stepName : '';
        final cmp = stepA.compareTo(stepB);
        if (cmp != 0) return cmp;
        return a.timestamp.compareTo(b.timestamp);
    }
  }

  List<KafkaMessage> _getFilteredResults() {
    if (_allMessages == null) return [];

    final hasActiveTopic = _selectedTopics.isNotEmpty;
    final hasParamFilters = _parameterFilters.isNotEmpty;

    if (!hasActiveTopic && !hasParamFilters) return _allMessages!;

    return _allMessages!.where((msg) {
      if (hasActiveTopic) {
        if (!_isTopicSelected(msg.stepId, msg.topic)) return false;
      }

      if (hasParamFilters) {
        var matchesAnyFilter = true;
        for (final entry in _parameterFilters.entries) {
          final Set<String> validValues = entry.value;
          var entryMatch = false;
          final content = (msg.key ?? "") + (msg.payload ?? "");
          for (final val in validValues) {
            if (content.contains(val)) {
              entryMatch = true;
              break;
            }
          }
          if (!entryMatch) {
            matchesAnyFilter = false;
            break;
          }
        }
        if (!matchesAnyFilter) return false;
      }

      return true;
    }).toList();
  }

  bool _isTopicSelected(String stepId, String topic) {
    return _selectedTopics[stepId]?.contains(topic) ?? false;
  }

  void _toggleTopicSelection(String stepId, String topic) {
    setState(() {
      if (_selectedTopics[stepId]?.contains(topic) ?? false) {
        _selectedTopics[stepId]?.remove(topic);
        if (_selectedTopics[stepId]?.isEmpty ?? false) {
          _selectedTopics.remove(stepId);
        }
      } else {
        _selectedTopics.putIfAbsent(stepId, () => {});
        _selectedTopics[stepId]!.add(topic);
      }
    });
  }

  void _toggleAllSelection(bool select) {
    setState(() {
      if (!select) {
        _selectedTopics.clear();
      }
    });
  }

  void _toggleStepSelection(String stepId, bool selectAll) {
    setState(() {
      if (!selectAll) {
        _selectedTopics.remove(stepId);
      } else {
        final steps = (widget.run.scriptSnapshot?.steps ?? widget.script.steps)
            .cast<ScriptStep>();
        try {
          final step = steps.firstWhere((s) => s.id == stepId);
          _selectedTopics[stepId] = step.topicNames.toSet();
        } catch (_) {
          // Step not found, should not happen
        }
      }
    });
  }
}
