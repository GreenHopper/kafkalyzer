import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/ui/focus_utils.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/table_column_config.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/projected_column.dart';
import 'package:kafkalyzer/src/features/messages/presentation/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/features/messages/presentation/views/messages_table_view.dart';
import 'package:kafkalyzer/src/features/messages/presentation/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/message_search_bar.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/view_mode_switcher.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/message_inspector_panel.dart';
import 'package:kafkalyzer/src/features/messages/domain/script_extraction.dart';
import 'package:kafkalyzer/src/features/messages/domain/script_result_message.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/messages/data/message_export_service.dart';
import 'package:kafkalyzer/src/features/messages/presentation/incremental_sorted_merge.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_ring_buffer.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_sort_utils.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/actionable_topic_empty_state.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// SharedPreferences key for inspector dock position.
const String messageInspectorDockPositionPref =
    'message_inspector_dock_position';

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
  final Function(KafkaMessage)? onMessageTap;
  final Map<String, List<ScriptExtraction>>? stepExtractions;
  final String? preferencesKey; // Key for persisting the active view mode
  final bool showHeader; // Whether to show the search bar and view switcher
  /// Whether the table view shows the Topic column (scripting contexts).
  final bool showTopic;

  /// Whether the table view shows the Step column (scripting contexts).
  final bool showStep;

  /// Optional custom schema tab. When non-null, the schema view mode is shown.
  final Widget Function(BuildContext context, String searchPhrase)?
  schemaViewBuilder;

  /// Optional custom schema tab builder with pin-to-column callback. When non-null, the schema view mode is shown.
  final Widget Function(
    BuildContext context,
    String searchPhrase,
    ValueChanged<String> onPinToColumn,
  )?
  schemaViewBuilderWithPin;

  /// Optional ordering override (e.g. script timeline grouping).
  final int Function(KafkaMessage a, KafkaMessage b)? sortComparator;

  /// Optional callback to fetch latest messages when the message list is empty.
  final VoidCallback? onFetchLatest;

  /// Whether messages are actively streaming/loading.
  final bool isStreaming;

  /// Optional active cluster profile.
  final ClusterProfile? profile;

  /// Jump from a DLQ card to the original topic; forwarded to the inspector.
  final void Function(String topic, int partition, int offset)?
  onJumpToOriginalMessage;

  /// Schema tab for the inspector panel. When null, the panel shows an empty
  /// schema tab instead of looking session-wide state up.
  final Widget Function(
    BuildContext context,
    KafkaMessage message,
    String? subject,
    int? version,
  )?
  schemaTabBuilder;

  /// Optional error message from the active stream/fetch.
  final String? errorMessage;

  /// Whether to show the Follow newest toggle overlay in table view.
  final bool showFollowControl;

  /// Token that resets follow-newest to enabled when changed (e.g. stream start).
  final Object? followResetToken;

  /// Test hook invoked whenever the quick-filter predicate is evaluated.
  @visibleForTesting
  final void Function(KafkaMessage)? onFilterEvaluated;

  const MessagesView({
    super.key,
    required this.messages,
    this.onMessageTap,
    this.stepExtractions,
    this.preferencesKey,
    this.showHeader = true,
    this.showTopic = false,
    this.showStep = false,
    this.schemaViewBuilder,
    this.schemaViewBuilderWithPin,
    this.sortComparator,
    this.onFetchLatest,
    this.isStreaming = false,
    this.profile,
    this.onJumpToOriginalMessage,
    this.schemaTabBuilder,
    this.errorMessage,
    this.showFollowControl = false,
    this.followResetToken,
    this.onFilterEvaluated,
  });

  @override
  State<MessagesView> createState() => MessagesViewState();
}

class MessagesViewState extends State<MessagesView> {
  String _activeView = 'table';
  String _searchPhrase = "";
  bool _showNonMatches = false;
  KafkaMessage? _selectedMessage;
  bool _isInspectorOpen = false;
  bool _isMaximized = false;
  InspectorDockPosition _dockPosition = InspectorDockPosition.bottom;

  final GlobalKey _tableViewKey = GlobalKey();
  final GlobalKey _timelineViewKey = GlobalKey();
  final GlobalKey _diffViewKey = GlobalKey();
  final GlobalKey<MessagesDiffViewState> _diffStateKey =
      GlobalKey<MessagesDiffViewState>();
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'messagesViewShortcuts',
  );

  List<ProjectedColumn> _projectedColumns = [];
  TableColumnConfig _tableColumnConfig = const TableColumnConfig();

  /// Per-view ascending flags. Missing entries mean descending (default).
  final Map<String, bool> _sortAscendingByView = {};

  /// Per-view sort fields. Missing entries mean timestamp (default).
  final Map<String, String> _sortFieldByView = {};

  // Cached lists to prevent re-filtering and re-sorting when just switching views
  List<KafkaMessage> _cachedFilteredMessages = [];
  final Set<KafkaMessage> _cachedMatchedMessages = Set<KafkaMessage>.identity();
  final Set<KafkaMessage> _cachedNonMatches = Set<KafkaMessage>.identity();
  bool _exportSelectedOnly = false;
  bool _exportIncludeNonMatches = false;
  bool _exportIncludeHeadersColumn = false;
  List<KafkaMessage> _cachedSortedMessages = [];
  int _cachedMatchCount = 0;

  bool get _sortAscending => _sortAscendingByView[_activeView] ?? false;

  String get _sortField => _sortFieldByView[_activeView] ?? 'timestamp';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleInspectorShortcut);
    _updateFilters();
    _loadSortPreferences();
    _loadDockPreference();
    _loadProjectedColumnsPreference();
    if (widget.preferencesKey != null) {
      _loadPreferences();
    }
    if (!_showSchemaView && _activeView == 'schema') {
      _activeView = 'timeline';
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleInspectorShortcut);
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages ||
        widget.sortComparator != oldWidget.sortComparator) {
      final oldMsgs = oldWidget.messages;
      final newMsgs = widget.messages;
      if (widget.sortComparator == oldWidget.sortComparator &&
          oldMsgs is MessageSnapshot &&
          newMsgs is MessageSnapshot &&
          newMsgs.epoch == oldMsgs.epoch &&
          newMsgs.firstSeq >= oldMsgs.firstSeq &&
          newMsgs.endSeq >= oldMsgs.endSeq) {
        _applyIncrementalUpdate(oldMsgs, newMsgs);
      } else {
        _updateFilters();
      }
      if (_primaryTopic(widget.messages) != _primaryTopic(oldWidget.messages)) {
        _loadProjectedColumnsPreference();
      }
      if (!_showSchemaView && _activeView == 'schema') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _activeView = 'timeline');
        });
      }
    }
  }

  String? _primaryTopic(List<KafkaMessage> msgs) {
    if (msgs.isEmpty) return null;
    return msgs.first.topic;
  }

  String? get _currentTopic => _primaryTopic(widget.messages);

  String? get _topicPresetKey {
    final topic = _currentTopic;
    if (topic == null || topic.isEmpty) return null;
    return 'topic_columns_preset_$topic';
  }

  Future<void> _loadProjectedColumnsPreference() async {
    final key = _topicPresetKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final config = TableColumnConfig.fromJson(decoded);
        if (mounted) {
          setState(() {
            _tableColumnConfig = config;
            _projectedColumns = config.projectedColumns;
          });
        }
      } catch (_) {}
    } else {
      if (mounted &&
          (_projectedColumns.isNotEmpty ||
              _tableColumnConfig.hiddenColumns.isNotEmpty ||
              _tableColumnConfig.columnWidths.isNotEmpty)) {
        setState(() {
          _tableColumnConfig = const TableColumnConfig();
          _projectedColumns = [];
        });
      }
    }
  }

  Future<void> _saveProjectedColumnsPreference() async {
    final key = _topicPresetKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_tableColumnConfig.projectedColumns.isEmpty &&
        _tableColumnConfig.hiddenColumns.isEmpty &&
        _tableColumnConfig.columnWidths.isEmpty) {
      await prefs.remove(key);
    } else {
      final encoded = jsonEncode(_tableColumnConfig.toJson());
      await prefs.setString(key, encoded);
    }
  }

  void addProjectedColumn(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return;

    if (_tableColumnConfig.projectedColumns.any(
      (col) => col.path == normalized,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.columnAlreadyPinned(normalized) ??
                'Column \'$normalized\' is already pinned',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final newCol = ProjectedColumn.fromPath(normalized);
    final updatedList = [..._tableColumnConfig.projectedColumns, newCol];
    setState(() {
      _tableColumnConfig = _tableColumnConfig.copyWith(
        projectedColumns: updatedList,
      );
      _projectedColumns = updatedList;
    });
    _saveProjectedColumnsPreference();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.columnPinned(normalized) ??
              'Column \'$normalized\' pinned to table',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void removeProjectedColumn(ProjectedColumn column) {
    final updatedList = _tableColumnConfig.projectedColumns
        .where((c) => c.path != column.path)
        .toList();
    final updatedWidths = Map<String, double>.from(
      _tableColumnConfig.columnWidths,
    )..remove(column.path);
    setState(() {
      _tableColumnConfig = _tableColumnConfig.copyWith(
        projectedColumns: updatedList,
        columnWidths: updatedWidths,
      );
      _projectedColumns = updatedList;
    });
    _saveProjectedColumnsPreference();
  }

  void resetProjectedColumns() {
    setState(() {
      _tableColumnConfig = const TableColumnConfig();
      _projectedColumns = [];
    });
    _saveProjectedColumnsPreference();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.columnsReset ??
              'Table columns reset to default',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onColumnWidthChanged(String columnId, double width) {
    final updatedWidths = Map<String, double>.from(
      _tableColumnConfig.columnWidths,
    );
    updatedWidths[columnId] = width;
    setState(() {
      _tableColumnConfig = _tableColumnConfig.copyWith(
        columnWidths: updatedWidths,
      );
    });
    _saveProjectedColumnsPreference();
  }

  void _toggleColumnVisibility(String columnId) {
    final currentHidden = Set<String>.from(_tableColumnConfig.hiddenColumns);
    if (currentHidden.contains(columnId)) {
      currentHidden.remove(columnId);
    } else {
      // Safeguard: Ensure at least 1 column remains visible
      final visibleStandardCount =
          (widget.showTopic || widget.showStep
                  ? StandardTableColumns.scriptingStandard
                  : StandardTableColumns.explorerStandard)
              .where((col) {
                if (col == StandardTableColumns.step && !widget.showStep) {
                  return false;
                }
                if (col == StandardTableColumns.topic && !widget.showTopic) {
                  return false;
                }
                return !currentHidden.contains(col);
              })
              .length;
      final visibleCount =
          visibleStandardCount + _tableColumnConfig.projectedColumns.length;
      if (visibleCount <= 1) {
        return;
      }
      currentHidden.add(columnId);
    }
    setState(() {
      _tableColumnConfig = _tableColumnConfig.copyWith(
        hiddenColumns: currentHidden,
      );
    });
    _saveProjectedColumnsPreference();
  }

  bool get _showSchemaView =>
      widget.schemaViewBuilder != null ||
      widget.schemaViewBuilderWithPin != null;

  void setActiveView(String newView) {
    _onViewModeChanged(newView);
  }

  bool _matchesQuickFilter(KafkaMessage msg, String query) {
    widget.onFilterEvaluated?.call(msg);
    if ((msg.key?.toLowerCase().contains(query) ?? false) ||
        (msg.payload?.toLowerCase().contains(query) ?? false) ||
        msg.topic.toLowerCase().contains(query)) {
      return true;
    }
    if (msg is ScriptResultMessage &&
        msg.stepName.toLowerCase().contains(query)) {
      return true;
    }
    return false;
  }

  void _applyIncrementalUpdate(
    MessageSnapshot oldSnap,
    MessageSnapshot newSnap,
  ) {
    final evictedCount = (newSnap.firstSeq - oldSnap.firstSeq).clamp(
      0,
      oldSnap.length,
    );
    final evicted = Set<KafkaMessage>.identity()
      ..addAll(oldSnap.take(evictedCount));

    for (final msg in evicted) {
      if (_cachedMatchedMessages.remove(msg)) {
        _cachedMatchCount--;
      }
      _cachedNonMatches.remove(msg);
    }

    final addedStart = (oldSnap.endSeq - newSnap.firstSeq).clamp(
      0,
      newSnap.length,
    );
    final added = newSnap.sublist(addedStart);

    final List<KafkaMessage> addedKept;
    if (_searchPhrase.isEmpty) {
      addedKept = added;
    } else {
      final query = _searchPhrase.toLowerCase();
      addedKept = <KafkaMessage>[];
      for (final msg in added) {
        if (_matchesQuickFilter(msg, query)) {
          _cachedMatchedMessages.add(msg);
          _cachedMatchCount++;
          addedKept.add(msg);
        } else if (_showNonMatches) {
          _cachedNonMatches.add(msg);
          addedKept.add(msg);
        }
      }
    }

    _cachedFilteredMessages = [
      for (final msg in _cachedFilteredMessages)
        if (!evicted.contains(msg)) msg,
      ...addedKept,
    ];
    _cachedSortedMessages = mergeIncremental<KafkaMessage>(
      _cachedSortedMessages,
      retain: (msg) => !evicted.contains(msg),
      added: addedKept,
      compare: _compareMessages,
    );
  }

  void _updateFilters() {
    // 1. Filter
    _cachedMatchedMessages.clear();
    _cachedNonMatches.clear();
    if (_searchPhrase.isEmpty) {
      _cachedFilteredMessages = widget.messages;
      _cachedMatchCount = 0;
      _exportIncludeNonMatches = false;
    } else {
      final query = _searchPhrase.toLowerCase();
      _cachedMatchCount = 0;
      _cachedFilteredMessages = widget.messages.where((msg) {
        final isMatch = _matchesQuickFilter(msg, query);
        if (isMatch) {
          _cachedMatchedMessages.add(msg);
          _cachedMatchCount++;
        } else if (_showNonMatches) {
          _cachedNonMatches.add(msg);
        }
        return isMatch || _showNonMatches;
      }).toList();
    }

    // 2. Sort by the active view's preferred field and direction
    _cachedSortedMessages = List<KafkaMessage>.from(_cachedFilteredMessages)
      ..sort(_compareMessages);
  }

  int _compareMessages(KafkaMessage a, KafkaMessage b) {
    final cmp = widget.sortComparator != null
        ? widget.sortComparator!(a, b)
        : switch (_sortField) {
            'partition' => a.partition.compareTo(b.partition),
            'offset' => a.offset.compareTo(b.offset),
            'key' => (a.key ?? '').compareTo(b.key ?? ''),
            'value' => (a.payload ?? '').compareTo(b.payload ?? ''),
            _ => a.timestamp.compareTo(b.timestamp),
          };
    final directed = (widget.sortComparator == null && !_sortAscending)
        ? -cmp
        : cmp;
    return directed != 0 ? directed : compareMessageIdentity(a, b);
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

  Future<void> _loadDockPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(messageInspectorDockPositionPref);
    if (saved != null && mounted) {
      setState(() {
        _dockPosition = saved == 'side'
            ? InspectorDockPosition.side
            : InspectorDockPosition.bottom;
      });
    }
  }

  void _toggleDockPosition() {
    final nextPosition = _dockPosition == InspectorDockPosition.bottom
        ? InspectorDockPosition.side
        : InspectorDockPosition.bottom;
    setState(() {
      _dockPosition = nextPosition;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        messageInspectorDockPositionPref,
        nextPosition == InspectorDockPosition.side ? 'side' : 'bottom',
      );
    });
  }

  List<KafkaMessage>? _tableVisualOrder;

  List<KafkaMessage> get _activeOrderedMessages =>
      (_activeView == 'table' && _tableVisualOrder != null)
      ? _tableVisualOrder!
      : _cachedSortedMessages;

  List<KafkaMessage> get _selectedMessagesForExport =>
      _selectedMessage == null ? const [] : [_selectedMessage!];

  List<KafkaMessage> get _exportScope {
    var list = List<KafkaMessage>.from(_activeOrderedMessages);
    if (!_exportIncludeNonMatches && _cachedNonMatches.isNotEmpty) {
      list = list.where((m) => !_cachedNonMatches.contains(m)).toList();
    }
    if (_exportSelectedOnly && _selectedMessagesForExport.isNotEmpty) {
      final selected = Set<KafkaMessage>.identity()
        ..addAll(_selectedMessagesForExport);
      list = list.where(selected.contains).toList();
    }
    return list;
  }

  Future<void> _exportMessages(ExportFormat format) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final outputFile = await getIt<MessageExportService>().exportMessages(
        _exportScope,
        dialogTitle: format == ExportFormat.csv
            ? l10n.exportMessagesCsv
            : l10n.exportMessages,
        format: format,
        columnConfig: _tableColumnConfig,
        isScriptingView: widget.showTopic || widget.showStep,
        includeHeadersColumn: _exportIncludeHeadersColumn,
      );
      if (mounted && outputFile != null) {
        showExportSuccessSnackBar(
          context,
          message: l10n.messagesExportedSuccessfully,
          filePath: outputFile,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.messagesExportFailed(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  int get _selectedIndex {
    if (_selectedMessage == null) return -1;
    return _activeOrderedMessages.indexOf(_selectedMessage!);
  }

  bool get _hasPrevious => _selectedIndex > 0;
  bool get _hasNext =>
      _selectedIndex >= 0 && _selectedIndex < _activeOrderedMessages.length - 1;

  void _stepPrevious() {
    if (!_hasPrevious) return;
    _handleMessageTap(_activeOrderedMessages[_selectedIndex - 1]);
  }

  void _stepNext() {
    if (!_hasNext) return;
    _handleMessageTap(_activeOrderedMessages[_selectedIndex + 1]);
  }

  void _toggleMaximize() {
    setState(() {
      _isMaximized = !_isMaximized;
    });
  }

  /// Whether this view should own inspector shortcuts right now.
  ///
  /// Shortcuts are intentionally focus-independent while the inspector is open
  /// so topic-list tiles and search-bar icon buttons cannot steal ↑/↓ from
  /// message stepping. They stay disabled when a dialog/route covers us or
  /// when the user is typing letter shortcuts into a text field.
  bool _shouldHandleInspectorShortcuts() {
    if (!mounted || !_isInspectorOpen) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return true;
  }

  void _requestShortcutFocus() {
    if (!mounted) return;
    if (!_shortcutFocusNode.canRequestFocus) return;
    _shortcutFocusNode.requestFocus();
  }

  /// Global handler so ↑/↓/J/K keep working even when focus leaves the
  /// messages subtree (search chrome, explorer topic list, etc.).
  bool _handleInspectorShortcut(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!_shouldHandleInspectorShortcuts()) return false;

    final key = event.logicalKey;
    final textFocused = isTextInputFocused();

    if (AppShortcuts.closeInspectorOrExitFocus.matchesLogicalKey(key)) {
      if (textFocused) {
        FocusManager.instance.primaryFocus?.unfocus();
        _requestShortcutFocus();
        return true;
      }
      if (_isMaximized) {
        setState(() => _isMaximized = false);
      } else {
        _closeInspector();
      }
      return true;
    }

    // Letter shortcuts must not fire while typing into a text field or when a
    // modifier key (Ctrl/Cmd/Alt) is held.
    final isLetterShortcut =
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.keyF;
    final hasModifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (isLetterShortcut && (textFocused || hasModifier)) return false;

    // Arrow up/down always step messages while the inspector is open so
    // focus traversal cannot move between search-bar controls or topic
    // tiles instead. Left/right are left alone for caret movement.
    if (AppShortcuts.nextMessage.matchesLogicalKey(key)) {
      _stepNext();
      return true;
    }
    if (AppShortcuts.previousMessage.matchesLogicalKey(key)) {
      _stepPrevious();
      return true;
    }
    if (AppShortcuts.toggleFocusMode.matchesLogicalKey(key)) {
      _toggleMaximize();
      return true;
    }
    return false;
  }

  void _closeInspector() {
    setState(() {
      _isInspectorOpen = false;
      _isMaximized = false;
    });
  }

  void _handleMessageTap(KafkaMessage msg) {
    setState(() {
      _selectedMessage = msg;
      _isInspectorOpen = true;
    });
    widget.onMessageTap?.call(msg);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestShortcutFocus();
    });
  }

  void _onViewModeChanged(String newView) {
    setState(() {
      _activeView = newView;
      _tableVisualOrder = null;
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
      if (widget.onFetchLatest != null ||
          widget.isStreaming ||
          widget.errorMessage != null) {
        return ActionableTopicEmptyState(
          onFetch: widget.onFetchLatest,
          isStreaming: widget.isStreaming,
          errorMessage: widget.errorMessage,
        );
      }
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(l10n?.noMessagesToDisplay ?? "No messages to display"),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.messageFetchFailedTitle}: ${widget.errorMessage!}',
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.onFetchLatest != null)
                    TextButton(
                      onPressed: widget.onFetchLatest,
                      child: Text(l10n.retry),
                    ),
                ],
              ),
            ),
          if (widget.showHeader && !_isMaximized) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              // Wrap, not Row: the header keeps every control reachable when the
              // window is too narrow for one line.
              child: Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 8,
                children: [
                  if (_activeView != 'table') ...[
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
                  ],
                  ViewModeSwitcher(
                    activeView: _activeView,
                    onViewChanged: _onViewModeChanged,
                    showSchemaView: _showSchemaView,
                  ),
                  if (_activeView == 'diff') ...[
                    const SizedBox(width: 8),
                    _buildDiffIgnoreToolbarControl(context),
                  ],
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
                    totalCount: widget.messages.length,
                    showNonMatches: _showNonMatches,
                    onShowNonMatchesChanged: (val) {
                      setState(() {
                        _showNonMatches = val;
                        if (!val) {
                          _exportIncludeNonMatches = false;
                        }
                        _updateFilters();
                      });
                    },
                  ),
                  if (_activeView == 'table') ...[
                    const SizedBox(width: 8),
                    MenuAnchor(
                      builder: (context, controller, child) {
                        return Tooltip(
                          message: l10n.columnsMenu,
                          child: IconButton(
                            key: const Key('table_columns_menu_button'),
                            icon: const Icon(Icons.view_column_outlined),
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                          ),
                        );
                      },
                      menuChildren: [
                        // Standard columns
                        ...(widget.showTopic || widget.showStep
                                ? StandardTableColumns.scriptingStandard
                                : StandardTableColumns.explorerStandard)
                            .where((col) {
                              if (col == StandardTableColumns.step &&
                                  !widget.showStep) {
                                return false;
                              }
                              if (col == StandardTableColumns.topic &&
                                  !widget.showTopic) {
                                return false;
                              }
                              return true;
                            })
                            .map((colId) {
                              final isVis = _tableColumnConfig.isVisible(colId);
                              String label =
                                  colId[0].toUpperCase() + colId.substring(1);
                              return MenuItemButton(
                                closeOnActivate: false,
                                onPressed: () => _toggleColumnVisibility(colId),
                                leadingIcon: Icon(
                                  isVis
                                      ? Icons.check_box_outlined
                                      : Icons.check_box_outline_blank,
                                  size: 18,
                                  color: isVis
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                ),
                                child: Text(label),
                              );
                            }),
                        if (_tableColumnConfig.projectedColumns.isNotEmpty) ...[
                          const PopupMenuDivider(),
                          ..._tableColumnConfig.projectedColumns.map((col) {
                            final isVis = _tableColumnConfig.isVisible(
                              col.path,
                            );
                            return MenuItemButton(
                              closeOnActivate: false,
                              onPressed: () =>
                                  _toggleColumnVisibility(col.path),
                              leadingIcon: Icon(
                                isVis
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: isVis
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              child: Text('${col.label} (${col.path})'),
                            );
                          }),
                        ],
                      ],
                    ),
                  ],
                  if (_tableColumnConfig.projectedColumns.isNotEmpty ||
                      _tableColumnConfig.hiddenColumns.isNotEmpty ||
                      _tableColumnConfig.columnWidths.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.resetColumns,
                      child: TextButton.icon(
                        onPressed: resetProjectedColumns,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          l10n.resetColumns,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  MenuAnchor(
                    builder: (context, controller, child) {
                      return Semantics(
                        label: l10n.exportMessages,
                        button: true,
                        child: Tooltip(
                          message: l10n.exportMessages,
                          child: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: _cachedFilteredMessages.isEmpty
                                ? null
                                : () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                          ),
                        ),
                      );
                    },
                    menuChildren: [
                      if (_selectedMessagesForExport.isNotEmpty)
                        CheckboxMenuButton(
                          value: _exportSelectedOnly,
                          closeOnActivate: false,
                          onChanged: (val) {
                            setState(() {
                              _exportSelectedOnly = val ?? false;
                            });
                          },
                          child: Text(
                            l10n.exportSelectedOnly(
                              _selectedMessagesForExport.length,
                            ),
                          ),
                        ),
                      if (_searchPhrase.isNotEmpty && _showNonMatches)
                        CheckboxMenuButton(
                          value: _exportIncludeNonMatches,
                          closeOnActivate: false,
                          onChanged: (val) {
                            setState(() {
                              _exportIncludeNonMatches = val ?? false;
                            });
                          },
                          child: Text(l10n.exportIncludeDimmedNonMatches),
                        ),
                      CheckboxMenuButton(
                        value: _exportIncludeHeadersColumn,
                        closeOnActivate: false,
                        onChanged: (val) {
                          setState(() {
                            _exportIncludeHeadersColumn = val ?? false;
                          });
                        },
                        child: Text(l10n.exportAddHeadersColumn),
                      ),
                      const Divider(height: 1),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.data_object, size: 18),
                        onPressed: () => _exportMessages(ExportFormat.json),
                        child: Text(
                          l10n.exportAsJson,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(
                          Icons.view_stream_outlined,
                          size: 18,
                        ),
                        onPressed: () => _exportMessages(ExportFormat.ndjson),
                        child: Text(
                          l10n.exportAsNdjson,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(
                          Icons.table_chart_outlined,
                          size: 18,
                        ),
                        onPressed: () => _exportMessages(ExportFormat.csv),
                        child: Text(
                          l10n.exportAsCsv,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildDiffIgnoreToolbarControl(BuildContext context) {
    final diffState = _diffStateKey.currentState;
    if (diffState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _diffStateKey.currentState != null) {
          setState(() {});
        }
      });
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: diffState.toolbarStateRevision,
      builder: (context, _, _) {
        return diffState.buildIgnoreToolbarControl(context);
      },
    );
  }

  Widget _buildContent() {
    if (_cachedFilteredMessages.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n?.noResultsMatchingPhrase(_searchPhrase) ??
              "No results found matching '$_searchPhrase'",
        ),
      );
    }

    final masterView = _buildMasterView();

    if (!_isInspectorOpen || _selectedMessage == null) {
      return masterView;
    }

    final inspector = MessageInspectorPanel(
      message: _selectedMessage!,
      dockPosition: _dockPosition,
      onToggleDockPosition: _toggleDockPosition,
      onClose: _closeInspector,
      searchPhrase: _searchPhrase,
      messageIndex: _selectedIndex >= 0 ? _selectedIndex : null,
      totalMessages: _activeOrderedMessages.length,
      onPreviousMessage: _hasPrevious ? _stepPrevious : null,
      onNextMessage: _hasNext ? _stepNext : null,
      isMaximized: _isMaximized,
      onToggleMaximize: _toggleMaximize,
      onPinToColumn: addProjectedColumn,
      profile: widget.profile,
      onJumpToOriginalMessage:
          widget.onJumpToOriginalMessage ?? (topic, partition, offset) {},
      schemaTabBuilder: widget.schemaTabBuilder,
    );

    if (_isMaximized) {
      return inspector;
    }

    if (_dockPosition == InspectorDockPosition.side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: masterView),
          const VerticalDivider(width: 1),
          Expanded(flex: 2, child: inspector),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: masterView),
          const Divider(height: 1),
          Expanded(flex: 2, child: inspector),
        ],
      );
    }
  }

  Widget _buildMasterView() {
    switch (_activeView) {
      case 'schema':
        if (widget.schemaViewBuilderWithPin != null) {
          return widget.schemaViewBuilderWithPin!(
            context,
            _searchPhrase,
            addProjectedColumn,
          );
        }
        if (widget.schemaViewBuilder != null) {
          return widget.schemaViewBuilder!(context, _searchPhrase);
        }
        return const SizedBox.shrink();
      case 'table':
        return MessagesTableView(
          key: _tableViewKey,
          messages: _cachedSortedMessages,
          searchPhrase: _searchPhrase,
          showNonMatches: _showNonMatches,
          showTopic: widget.showTopic,
          showStep: widget.showStep,
          onMessageTap: _handleMessageTap,
          selectedMessage: _selectedMessage,
          projectedColumns: _projectedColumns,
          onRemoveProjectedColumn: removeProjectedColumn,
          columnConfig: _tableColumnConfig,
          onColumnWidthChanged: _onColumnWidthChanged,
          onToggleColumnVisibility: _toggleColumnVisibility,
          onVisualOrderChanged: (order) {
            _tableVisualOrder = order;
          },
          clusterProfile: widget.profile,
          showFollowControl: widget.showFollowControl,
          followResetToken: widget.followResetToken,
          inputSortField: _sortField,
          inputSortAscending: _sortAscending,
        );
      case 'diff':
        return Padding(
          key: _diffViewKey,
          padding: const EdgeInsets.all(16),
          child: MessagesDiffView(
            key: _diffStateKey,
            messages: _cachedSortedMessages,
            onMessageTap: _handleMessageTap,
            searchPhrase: _searchPhrase,
            selectedMessage: _selectedMessage,
            showIgnoreHeader: false,
          ),
        );
      case 'timeline':
      default:
        return Padding(
          key: _timelineViewKey,
          padding: const EdgeInsets.all(16),
          child: MessagesTimelineView(
            messages: _cachedSortedMessages,
            onMessageTap: _handleMessageTap,
            selectedMessage: _selectedMessage,
            searchPhrase: _searchPhrase,
            showNonMatches: _showNonMatches,
            stepExtractions: widget.stepExtractions,
          ),
        );
    }
  }
}
