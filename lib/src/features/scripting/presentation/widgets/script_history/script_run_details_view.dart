import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_header.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_sidebar.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_schemas_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RunViewType { groupedByStep, byTopic, chronological }

class ScriptRunDetailsView extends StatefulWidget {
  final ScriptRun run;
  final Script script;
  final VoidCallback onBack;

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
  final TextEditingController _searchController = TextEditingController();

  List<ScriptResultMessage>? _allMessages;
  Map<String, Map<String, List<KafkaMessage>>>? _groupedResults;
  bool _loadingDetails = false;

  // View preferences
  String _timelineMode = 'topic';
  RunViewType _currentViewType = RunViewType.byTopic;
  String _activeView = 'timeline';

  // State
  String _searchPhrase = "";
  bool _showNonMatches = false;
  final Map<String, Set<String>> _selectedTopics = {};
  final Map<String, Set<String>> _parameterFilters = {};

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
        _activeView =
            prefs.getString('script_result_active_view') ?? 'timeline';
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

        _showNonMatches = prefs.getBool('script_show_non_matches') ?? false;
      });
    }
  }

  Future<void> _loadRunDetails() async {
    setState(() {
      _groupedResults = null;
      _allMessages = null;
      _selectedTopics.clear();
      _parameterFilters.clear();
      _searchPhrase = "";
      _searchController.clear();
      _loadingDetails = true;
    });

    try {
      final grouped = <String, Map<String, List<KafkaMessage>>>{};
      final allMessages = await getIt<ScriptRunner>().loadRunResults(
        widget.run,
      );

      // Group messages by stepId and topic
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

      _sortMessages(allMessages); // Sort based on current view type

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
    final matchCount = _calculateMatchCount();
    final scriptSteps =
        (widget.run.scriptSnapshot?.steps ?? widget.script.steps)
            .cast<ScriptStep>();

    return Column(
      children: [
        ScriptRunHeader(
          run: widget.run,
          timelineMode: _timelineMode,
          activeView: _activeView,
          searchPhrase: _searchPhrase,
          showNonMatches: _showNonMatches,
          matchCount: matchCount,
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

              if (_allMessages != null) {
                _sortMessages(_allMessages!.cast<ScriptResultMessage>());
              }

              if (_activeView != 'table') {
                _activeView = 'timeline';
              }
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(
              'script_result_view_mode',
              _currentViewType.index,
            );
          },
          onActiveViewChanged: (view) async {
            setState(() {
              _activeView = view;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('script_result_active_view', _activeView);
          },
          onSearchChanged: (val) {
            setState(() {
              _searchPhrase = val;
            });
          },
          onShowNonMatchesChanged: (val) async {
            setState(() {
              _showNonMatches = val;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('script_show_non_matches', val);
          },
          onBack: widget.onBack,
        ),
        const Divider(height: 1),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(child: _filteredResultsView()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filteredResultsView() {
    if (_activeView == 'schema') {
      return ScriptSchemasView(
        script: widget.script,
        searchPhrase: _searchPhrase,
      );
    }

    final results = _getFilteredResults();

    if (results.isEmpty) {
      return Center(child: Text("No results found matching '$_searchPhrase'"));
    }

    if (_activeView == 'table') {
      return _buildTableView(results);
    } else if (_activeView == 'diff') {
      return _buildDiffView(results);
    } else {
      return _buildTimelineView(results);
    }
  }

  Widget _buildTableView(List<KafkaMessage> results) {
    return MessagesTableView(
      key: ValueKey(_currentViewType),
      messages: results,
      showStep: true,
      showTopic: true,
      searchPhrase: _searchPhrase,
      showNonMatches: _showNonMatches,
      onMessageTap: (msg) {
        showDialog(
          context: context,
          builder: (context) => MessageDetailsDialog(
            message: msg,
            initialSearchPhrase: _searchPhrase,
          ),
        );
      },
    );
  }

  Widget _buildDiffView(List<KafkaMessage> results) {
    final sorted = List<KafkaMessage>.from(results);
    sorted.sort(
      (a, b) => a.timestamp.compareTo(b.timestamp),
    ); // Diff view expects chronological order

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MessagesDiffView(
        messages: sorted,
        onMessageTap: (msg) {
          showDialog(
            context: context,
            builder: (context) => MessageDetailsDialog(
              message: msg,
              initialSearchPhrase: _searchPhrase,
            ),
          );
        },
        searchPhrase: _searchPhrase,
      ),
    );
  }

  Widget _buildTimelineView(List<KafkaMessage> results) {
    final sorted = List<KafkaMessage>.from(results);

    // Sort for timeline view based on current mode
    if (_currentViewType == RunViewType.chronological) {
      sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else if (_currentViewType == RunViewType.byTopic) {
      sorted.sort((a, b) {
        final cmp = a.topic.compareTo(b.topic);
        if (cmp != 0) return cmp;
        return a.timestamp.compareTo(b.timestamp);
      });
    } else if (_currentViewType == RunViewType.groupedByStep) {
      sorted.sort((a, b) {
        String stepA = a is ScriptResultMessage ? a.stepName : "";
        String stepB = b is ScriptResultMessage ? b.stepName : "";
        final cmp = stepA.compareTo(stepB);
        if (cmp != 0) return cmp;
        return a.timestamp.compareTo(b.timestamp);
      });
    }

    final stepExtractions = {
      for (final s in widget.script.steps) s.id: s.extractions,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MessagesTimelineView(
        messages: sorted,
        onMessageTap: (msg) {
          showDialog(
            context: context,
            builder: (context) => MessageDetailsDialog(
              message: msg,
              initialSearchPhrase: _searchPhrase,
            ),
          );
        },
        searchPhrase: _searchPhrase,
        showNonMatches: _showNonMatches,
        stepExtractions: stepExtractions,
      ),
    );
  }

  List<KafkaMessage> _getFilteredResults() {
    if (_allMessages == null) return [];

    final query = _searchPhrase.toLowerCase();
    final hasSearch = _searchPhrase.isNotEmpty;
    final hasActiveTopic = _selectedTopics.isNotEmpty;
    final hasParamFilters = _parameterFilters.isNotEmpty;

    if (!hasSearch && !hasActiveTopic && !hasParamFilters) return _allMessages!;

    return _allMessages!.where((msg) {
      if (hasActiveTopic) {
        if (!_isTopicSelected(msg.stepId, msg.topic)) return false;
      }

      if (hasParamFilters) {
        bool matchesAnyFilter = true;
        for (final entry in _parameterFilters.entries) {
          final Set<String> validValues = entry.value;
          bool entryMatch = false;
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

      if (hasSearch) {
        final match =
            ((msg.key ?? "").toLowerCase().contains(query)) ||
            ((msg.payload ?? "").toLowerCase().contains(query)) ||
            (msg.topic.toLowerCase().contains(query)) ||
            (msg.stepName.toLowerCase().contains(query));

        if (match) return true;
        return _showNonMatches;
      }

      return true;
    }).toList();
  }

  int _calculateMatchCount() {
    if (_allMessages == null || _searchPhrase.isEmpty) return 0;
    final query = _searchPhrase.toLowerCase();

    return _allMessages!.where((msg) {
      if (_selectedTopics.isNotEmpty) {
        if (!_isTopicSelected(msg.stepId, msg.topic)) return false;
      }

      if (_parameterFilters.isNotEmpty) {
        bool matchesAnyFilter = true;
        for (final entry in _parameterFilters.entries) {
          final Set<String> validValues = entry.value;
          bool entryMatch = false;
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

      return (msg.key ?? "").toLowerCase().contains(query) ||
          (msg.payload ?? "").toLowerCase().contains(query) ||
          msg.topic.toLowerCase().contains(query) ||
          msg.stepName.toLowerCase().contains(query);
    }).length;
  }

  void _sortMessages(List<KafkaMessage> messages) {
    // Currently sort is handled in _filteredResultsView for transient sorting
    // but we can pre-sort here if needed.
    // Logic extracted from _filteredResultsView or previous _sortMessages
    // The previous implementation sorted _allMessages in place.
    // For now we rely on _filteredResultsView to sort the view copy.
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
