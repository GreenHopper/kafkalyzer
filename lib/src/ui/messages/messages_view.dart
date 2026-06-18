import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_search_bar.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/view_mode_switcher.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final Map<String, List<ScriptExtraction>>? stepExtractions;
  final String? preferencesKey; // Key for persisting the active view mode
  final bool showHeader; // Whether to show the search bar and view switcher

  const MessagesView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.stepExtractions,
    this.preferencesKey,
    this.showHeader = true,
  });

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  String _activeView = 'table';
  String _searchPhrase = "";
  bool _showNonMatches = false;

  // Cached lists to prevent re-filtering and re-sorting when just switching views
  List<KafkaMessage> _cachedFilteredMessages = [];
  List<KafkaMessage> _cachedSortedMessages = [];
  int _cachedMatchCount = 0;

  @override
  void initState() {
    super.initState();
    _updateFilters();
    if (widget.preferencesKey != null) {
      _loadPreferences();
    }
    if (!_showSchemaView && _activeView == 'schema') {
      _activeView = 'timeline';
    }
  }

  @override
  void didUpdateWidget(covariant MessagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _updateFilters();
      if (!_showSchemaView && _activeView == 'schema') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _activeView = 'timeline');
        });
      }
    }
  }

  bool get _showSchemaView {
    if (widget.messages.isEmpty) return false;
    final firstTopic = widget.messages.first.topic;
    for (int i = 1; i < widget.messages.length; i++) {
      if (widget.messages[i].topic != firstTopic) return true;
    }
    return false;
  }

  void _updateFilters() {
    // 1. Filter
    if (_searchPhrase.isEmpty) {
      _cachedFilteredMessages = widget.messages;
      _cachedMatchCount = 0;
    } else {
      final query = _searchPhrase.toLowerCase();
      _cachedMatchCount = 0;
      _cachedFilteredMessages = widget.messages.where((msg) {
        final isMatch =
            (msg.key?.toLowerCase().contains(query) ?? false) ||
            (msg.payload?.toLowerCase().contains(query) ?? false) ||
            msg.topic.toLowerCase().contains(query);

        if (isMatch) _cachedMatchCount++;
        return isMatch || _showNonMatches;
      }).toList();
    }

    // 2. Sort (For Diff and Timeline views)
    _cachedSortedMessages = List<KafkaMessage>.from(_cachedFilteredMessages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedView = prefs.getString(widget.preferencesKey!);
    if (savedView != null && mounted) {
      setState(() {
        _activeView = savedView;
      });
    }
  }

  void _onViewModeChanged(String newView) {
    setState(() {
      _activeView = newView;
    });
    if (widget.preferencesKey != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(widget.preferencesKey!, newView);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(child: Text("No messages to display"));
    }

    return Column(
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ViewModeSwitcher(
                  activeView: _activeView,
                  onViewChanged: _onViewModeChanged,
                  showSchemaView: _showSchemaView,
                ),
                const SizedBox(width: 16),
                MessageSearchBar(
                  searchPhrase: _searchPhrase,
                  onSearchChanged: (val) {
                    setState(() {
                      _searchPhrase = val;
                      _updateFilters();
                    });
                  },
                  matchCount: _cachedMatchCount,
                  showNonMatches: _showNonMatches,
                  onShowNonMatchesChanged: (val) {
                    setState(() {
                      _showNonMatches = val;
                      _updateFilters();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: AppLocalizations.of(context)!.exportMessages,
                  child: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () async {
                      try {
                        await getIt<MessageExportService>().exportMessages(
                          _cachedFilteredMessages,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.messagesExportedSuccessfully,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.messagesExportFailed(e.toString()),
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_cachedFilteredMessages.isEmpty) {
      return Center(child: Text("No results found matching '$_searchPhrase'"));
    }

    switch (_activeView) {
      case 'table':
        return MessagesTableView(
          messages: _cachedFilteredMessages,
          searchPhrase: _searchPhrase,
          showNonMatches: _showNonMatches,
          showTopic: true, // Configurable?
          showStep: true, // Configurable?
          onMessageTap: widget.onMessageTap,
        );
      case 'diff':
        return Padding(
          padding: const EdgeInsets.all(16),
          child: MessagesDiffView(
            messages: _cachedSortedMessages,
            onMessageTap: widget.onMessageTap,
            searchPhrase: _searchPhrase,
          ),
        );
      case 'timeline':
      default:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: MessagesTimelineView(
            messages: _cachedSortedMessages,
            onMessageTap: widget.onMessageTap,
            searchPhrase: _searchPhrase,
            showNonMatches: _showNonMatches,
            stepExtractions: widget.stepExtractions,
          ),
        );
    }
  }
}
