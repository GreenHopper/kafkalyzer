import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_search_bar.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/view_mode_switcher.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_inspector_panel.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
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

  const MessagesView({
    super.key,
    required this.messages,
    this.onMessageTap,
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
  KafkaMessage? _selectedMessage;
  bool _isInspectorOpen = false;
  bool _isMaximized = false;
  InspectorDockPosition _dockPosition = InspectorDockPosition.bottom;

  final GlobalKey _tableViewKey = GlobalKey();
  final GlobalKey _timelineViewKey = GlobalKey();
  final GlobalKey _diffViewKey = GlobalKey();

  List<ProjectedColumn> _projectedColumns = [];
  TableColumnConfig _tableColumnConfig = const TableColumnConfig();

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
  void didUpdateWidget(covariant MessagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _updateFilters();
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

  bool _isTextInputFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    return context.widget is EditableText;
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
      return const Center(child: Text("No messages to display"));
    }

    final l10n = AppLocalizations.of(context)!;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyJ): () {
          if (!_isTextInputFocused() && _isInspectorOpen) {
            _stepNext();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (!_isTextInputFocused() && _isInspectorOpen) {
            _stepNext();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyK): () {
          if (!_isTextInputFocused() && _isInspectorOpen) {
            _stepPrevious();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (!_isTextInputFocused() && _isInspectorOpen) {
            _stepPrevious();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF): () {
          if (!_isTextInputFocused() && _isInspectorOpen) {
            _toggleMaximize();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isTextInputFocused()) {
            FocusManager.instance.primaryFocus?.unfocus();
          } else if (_isInspectorOpen) {
            if (_isMaximized) {
              setState(() => _isMaximized = false);
            } else {
              _closeInspector();
            }
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader && !_isMaximized) ...[
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
                                final isVis = _tableColumnConfig.isVisible(
                                  colId,
                                );
                                String label =
                                    colId[0].toUpperCase() + colId.substring(1);
                                return MenuItemButton(
                                  closeOnActivate: false,
                                  onPressed: () =>
                                      _toggleColumnVisibility(colId),
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
                          if (_tableColumnConfig
                              .projectedColumns
                              .isNotEmpty) ...[
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
                                  content: Text(
                                    l10n.messagesExportedSuccessfully,
                                  ),
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
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_cachedFilteredMessages.isEmpty) {
      return Center(child: Text("No results found matching '$_searchPhrase'"));
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
        );
      case 'diff':
        return Padding(
          key: _diffViewKey,
          padding: const EdgeInsets.all(16),
          child: MessagesDiffView(
            messages: _cachedSortedMessages,
            onMessageTap: _handleMessageTap,
            searchPhrase: _searchPhrase,
            selectedMessage: _selectedMessage,
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
