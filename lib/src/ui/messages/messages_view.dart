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
import 'package:material_ui/material_ui.dart';

/// SharedPreferences key prefix for sort direction per view type.
const String messageSortOrderPrefPrefix = 'message_sort_order_';

/// SharedPreferences key prefix for sort field per view type.
const String messageSortFieldPrefPrefix = 'message_sort_field_';

/// Supported message result view types that persist their own sort prefs.
const List<String> messageSortOrderViews = [
  'timeline',
  'table',
  'diff',
  'schema',
];

/// Supported sort fields for the results toolbar.
const List<String> messageSortFields = [
  'timestamp',
  'partition',
  'offset',
  'key',
  'value',
];

class MessagesView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final Map<String, List<ScriptExtraction>>? stepExtractions;
  final String? preferencesKey; // Key for persisting the active view mode
  final bool showHeader; // Whether to show the search bar and view switcher
  /// Whether the table view shows the Topic column (scripting contexts).
  final bool showTopic;

  /// Whether the table view shows the Step column (scripting contexts).
  final bool showStep;

  const MessagesView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.stepExtractions,
    this.preferencesKey,
    this.showHeader = true,
    this.showTopic = false,
    this.showStep = false,
  });

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  String _activeView = 'table';
  String _searchPhrase = "";
  bool _showNonMatches = false;

  /// Per-view ascending flags. Missing entries mean descending (default).
  final Map<String, bool> _sortAscendingByView = {};

  /// Per-view sort fields. Missing entries mean timestamp (default).
  final Map<String, String> _sortFieldByView = {};

  // Cached lists to prevent re-filtering and re-sorting when just switching views
  List<KafkaMessage> _cachedFilteredMessages = [];
  List<KafkaMessage> _cachedSortedMessages = [];
  int _cachedMatchCount = 0;

  bool get _sortAscending => _sortAscendingByView[_activeView] ?? false;

  String get _sortField => _sortFieldByView[_activeView] ?? 'timestamp';

  @override
  void initState() {
    super.initState();
    _updateFilters();
    _loadSortPreferences();
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

    // 2. Sort by the active view's preferred field and direction
    _cachedSortedMessages = List<KafkaMessage>.from(_cachedFilteredMessages)
      ..sort(_compareMessages);
  }

  int _compareMessages(KafkaMessage a, KafkaMessage b) {
    final cmp = switch (_sortField) {
      'partition' => a.partition.compareTo(b.partition),
      'offset' => a.offset.compareTo(b.offset),
      'key' => (a.key ?? '').compareTo(b.key ?? ''),
      'value' => (a.payload ?? '').compareTo(b.payload ?? ''),
      _ => a.timestamp.compareTo(b.timestamp),
    };
    return _sortAscending ? cmp : -cmp;
  }

  Future<void> _loadSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (final view in messageSortOrderViews) {
      _sortAscendingByView[view] = _parseSortAscending(
        prefs.getString('$messageSortOrderPrefPrefix$view'),
      );
      _sortFieldByView[view] = _parseSortField(
        prefs.getString('$messageSortFieldPrefPrefix$view'),
      );
    }
    if (mounted) {
      setState(() {
        _updateFilters();
      });
    }
  }

  /// Missing or invalid values default to descending (ascending = false).
  static bool _parseSortAscending(String? value) => value == 'asc';

  /// Missing or invalid values default to timestamp.
  static String _parseSortField(String? value) {
    if (value != null && messageSortFields.contains(value)) {
      return value;
    }
    return 'timestamp';
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedView = prefs.getString(widget.preferencesKey!);
    if (savedView != null && mounted) {
      setState(() {
        _activeView = savedView;
        _updateFilters();
      });
    }
  }

  void _onViewModeChanged(String newView) {
    setState(() {
      _activeView = newView;
      _updateFilters();
    });
    if (widget.preferencesKey != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(widget.preferencesKey!, newView);
      });
    }
  }

  void _toggleSortOrder() {
    final nextAscending = !_sortAscending;
    setState(() {
      _sortAscendingByView[_activeView] = nextAscending;
      _updateFilters();
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        '$messageSortOrderPrefPrefix$_activeView',
        nextAscending ? 'asc' : 'desc',
      );
    });
  }

  void _onSortFieldChanged(String field) {
    setState(() {
      _sortFieldByView[_activeView] = field;
      _updateFilters();
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('$messageSortFieldPrefPrefix$_activeView', field);
    });
  }

  String _labelForSortField(AppLocalizations l10n, String field) {
    switch (field) {
      case 'partition':
        return l10n.sortFieldPartition;
      case 'offset':
        return l10n.sortFieldOffset;
      case 'key':
        return l10n.sortFieldKey;
      case 'value':
        return l10n.sortFieldValue;
      case 'timestamp':
      default:
        return l10n.sortFieldTimestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(child: Text("No messages to display"));
    }

    final l10n = AppLocalizations.of(context)!;

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
                Tooltip(
                  message: l10n.sortFieldTooltip,
                  child: PopupMenuButton<String>(
                    key: const Key('message_sort_field_selector'),
                    initialValue: _sortField,
                    onSelected: _onSortFieldChanged,
                    itemBuilder: (context) => [
                      for (final field in messageSortFields)
                        PopupMenuItem<String>(
                          value: field,
                          child: Text(_labelForSortField(l10n, field)),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_labelForSortField(l10n, _sortField)),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: _sortAscending
                      ? l10n.sortOrderAscending
                      : l10n.sortOrderDescending,
                  child: IconButton(
                    key: const Key('message_sort_order_toggle'),
                    icon: Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: _toggleSortOrder,
                  ),
                ),
                const SizedBox(width: 8),
                ViewModeSwitcher(
                  activeView: _activeView,
                  onViewChanged: _onViewModeChanged,
                  showSchemaView: _showSchemaView,
                ),
                const SizedBox(width: 8),
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
                  message: l10n.exportMessages,
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
                              content: Text(l10n.messagesExportedSuccessfully),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.messagesExportFailed(e.toString()),
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
          messages: _cachedSortedMessages,
          searchPhrase: _searchPhrase,
          showNonMatches: _showNonMatches,
          showTopic: widget.showTopic,
          showStep: widget.showStep,
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
