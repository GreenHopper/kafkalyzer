import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';
import 'package:kafkalyzer/src/ui/local_schema_error_formatter.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:kafkalyzer/src/features/messages/domain/message_reference.dart';
import 'package:kafkalyzer/src/features/messages/domain/dlq_failure_metadata.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/dlq_failure_diagnostics_card.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

/// Available dock orientations for the embedded message inspector.
enum InspectorDockPosition { bottom, side }

/// A persistent, non-modal split-screen panel that displays complete details
/// of a selected Kafka message without interrupting stream navigation.
class MessageInspectorPanel extends StatefulWidget {
  final KafkaMessage message;
  final InspectorDockPosition dockPosition;
  final VoidCallback onToggleDockPosition;
  final VoidCallback onClose;
  final String? searchPhrase;
  final int? messageIndex;
  final int? totalMessages;
  final VoidCallback? onPreviousMessage;
  final VoidCallback? onNextMessage;
  final bool isMaximized;
  final VoidCallback? onToggleMaximize;
  final ValueChanged<String>? onPinToColumn;
  final ClusterProfile? profile;
  final void Function(String topic, int partition, int offset)
  onJumpToOriginalMessage;

  /// Builds the schema tab. When null, the tab shows an empty state instead of
  /// reaching into the schema feature.
  final Widget Function(
    BuildContext context,
    KafkaMessage message,
    String? subject,
    int? version,
  )?
  schemaTabBuilder;
  final Future<({Int32List offsets, bool capped})> Function(
    String text,
    String query,
  )?
  findPayloadMatches;

  const MessageInspectorPanel({
    super.key,
    required this.message,
    required this.dockPosition,
    required this.onToggleDockPosition,
    required this.onClose,
    required this.onJumpToOriginalMessage,
    this.searchPhrase,
    this.messageIndex,
    this.totalMessages,
    this.onPreviousMessage,
    this.onNextMessage,
    this.isMaximized = false,
    this.onToggleMaximize,
    this.onPinToColumn,
    this.profile,
    this.schemaTabBuilder,
    this.findPayloadMatches,
  });

  @override
  State<MessageInspectorPanel> createState() => _MessageInspectorPanelState();
}

class _MessageInspectorPanelState extends State<MessageInspectorPanel>
    with SingleTickerProviderStateMixin {
  bool _isSearchOpen = false;
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  int _totalMatches = 0;
  int _currentMatchIndex = 0;
  RawSearchState _searchState = RawSearchState.idle;
  final GlobalKey<JsonOrStringViewerState> _payloadViewerKey = GlobalKey();
  final GlobalKey<JsonOrStringViewerState> _keyViewerKey = GlobalKey();
  final GlobalKey _keySectionKey = GlobalKey();
  final List<GlobalKey<JsonOrStringViewerState>> _headerViewerKeys = [];
  final List<GlobalKey> _headerSectionKeys = [];

  int _payloadMatchCount = 0;
  int _keyMatchCount = 0;
  List<int> _headerValueMatchCounts = [];

  late final TabController _tabController;
  int _activeTabIndex = 0;

  // Schema of the selected message, set when the user jumps to it.
  String? _schemaSubject;
  int? _schemaVersion;

  static const int _schemaTabIndex = 3;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _syncHeaderLists(widget.message.headers?.length ?? 0);
  }

  void _onTabChanged() {
    if (_activeTabIndex != _tabController.index && mounted) {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    }
  }

  void _syncHeaderLists(int count) {
    _headerViewerKeys
      ..clear()
      ..addAll(
        List.generate(count, (_) => GlobalKey<JsonOrStringViewerState>()),
      );
    _headerSectionKeys
      ..clear()
      ..addAll(List.generate(count, (_) => GlobalKey()));
    _headerValueMatchCounts = List.filled(count, 0);
  }

  @override
  void didUpdateWidget(covariant MessageInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _currentMatchIndex = 0;
      _searchState = RawSearchState.idle;
      _payloadMatchCount = 0;
      _keyMatchCount = 0;
      _syncHeaderLists(widget.message.headers?.length ?? 0);
      _recomputeTotalMatches();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _effectiveSearchQuery {
    if (_isSearchOpen && _searchController.text.isNotEmpty) {
      return _searchController.text;
    }
    return widget.searchPhrase ?? '';
  }

  int _countSubstringMatches(String text, String query) {
    final q = query.trim();
    if (q.isEmpty || text.isEmpty) return 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    var count = 0;
    var start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) break;
      count++;
      start = idx + lowerQuery.length;
    }
    return count;
  }

  int _headerKeyMatchCount(int index) {
    final headers = widget.message.headers ?? const <KafkaHeader>[];
    if (index < 0 || index >= headers.length) return 0;
    return _countSubstringMatches(headers[index].key, _effectiveSearchQuery);
  }

  void _recomputeTotalMatches() {
    final headers = widget.message.headers ?? const <KafkaHeader>[];
    var total = _payloadMatchCount + _keyMatchCount;
    for (var i = 0; i < headers.length; i++) {
      total += _headerKeyMatchCount(i);
      if (i < _headerValueMatchCounts.length) {
        total += _headerValueMatchCounts[i];
      }
    }
    _totalMatches = total;
    if (_totalMatches == 0 || _currentMatchIndex >= _totalMatches) {
      _currentMatchIndex = 0;
    }
  }

  _SearchTarget? _resolveMatchTarget(int globalIndex) {
    if (_totalMatches == 0 || globalIndex < 0 || globalIndex >= _totalMatches) {
      return null;
    }
    var rem = globalIndex;
    if (rem < _payloadMatchCount) {
      return _SearchTarget(
        tab: 0,
        viewerKey: _payloadViewerKey,
        localIndex: rem,
      );
    }
    rem -= _payloadMatchCount;

    if (rem < _keyMatchCount) {
      return _SearchTarget(
        tab: 1,
        sectionKey: _keySectionKey,
        viewerKey: _keyViewerKey,
        localIndex: rem,
      );
    }
    rem -= _keyMatchCount;

    final headers = widget.message.headers ?? const <KafkaHeader>[];
    for (var i = 0; i < headers.length; i++) {
      final hk = _headerKeyMatchCount(i);
      if (rem < hk) {
        return _SearchTarget(
          tab: 1,
          sectionKey: _headerSectionKeys[i],
          headerKeyIndex: i,
          localIndex: rem,
        );
      }
      rem -= hk;

      final hv = i < _headerValueMatchCounts.length
          ? _headerValueMatchCounts[i]
          : 0;
      if (rem < hv) {
        return _SearchTarget(
          tab: 1,
          sectionKey: _headerSectionKeys[i],
          viewerKey: _headerViewerKeys[i],
          localIndex: rem,
        );
      }
      rem -= hv;
    }
    return null;
  }

  void _jumpToActiveMatch() {
    final target = _resolveMatchTarget(_currentMatchIndex);
    if (target == null) return;
    if (_tabController.index != target.tab) {
      _tabController.animateTo(target.tab);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionCtx = target.sectionKey?.currentContext;
      if (sectionCtx != null) {
        Scrollable.ensureVisible(
          sectionCtx,
          duration: const Duration(milliseconds: 200),
          alignment: 0.2,
        );
      }
      if (target.viewerKey != null && target.localIndex != null) {
        target.viewerKey!.currentState?.jumpToMatch(target.localIndex!);
      }
    });
  }

  void _jumpToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _jumpToActiveMatch();
  }

  void _jumpToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _jumpToActiveMatch();
  }

  dynamic _tryParseJson(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      return json.decode(content);
    } catch (_) {
      return content;
    }
  }

  String _formatFullMessageJson(String dateStr) {
    final data = {
      'topic': widget.message.topic,
      'partition': widget.message.partition,
      'offset': widget.message.offset.toInt(),
      'timestamp': widget.message.timestamp.toInt(),
      'formattedTimestamp': dateStr,
      'key': _tryParseJson(widget.message.key),
      'content': _tryParseJson(widget.message.payload),
      'headers': widget.message.headers
          ?.map((h) => {'key': h.key, 'value': _tryParseJson(h.value)})
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final dateStr = DateFormatUtils.formatDateTime(
      context,
      DateTime.fromMillisecondsSinceEpoch(widget.message.timestamp.toInt()),
      withMilliseconds: true,
    );

    final headerCount = widget.message.headers?.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: widget.dockPosition == InspectorDockPosition.bottom
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                )
              : BorderSide.none,
          left: widget.dockPosition == InspectorDockPosition.side
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                )
              : BorderSide.none,
        ),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            _buildHeader(context, colorScheme, l10n, dateStr),
            // Schema provenance of the selected message, per message side.
            _buildProvenanceRow(context, l10n),
            if (_isSearchOpen) ...[
              _buildSearchBar(context, colorScheme, l10n),
              const Divider(height: 1),
            ],
            // Tab Selector
            _buildTabBar(colorScheme, l10n, headerCount),
            const Divider(height: 1),
            // Tab Content
            Expanded(
              child: IndexedStack(
                index: _activeTabIndex,
                children: [
                  // Tab 1: Payload Viewer (kept mounted)
                  _buildPayloadTab(context),
                  // Tab 2: Key & Headers (kept mounted)
                  _buildKeyAndHeadersTab(context, colorScheme, l10n),
                  // Tab 3: Raw JSON (lazy: built only while selected)
                  _activeTabIndex == 2
                      ? _buildRawJsonTab(context, colorScheme, l10n, dateStr)
                      : const SizedBox.shrink(),
                  // Tab 4: Schema Viewer (lazy: built only while selected)
                  _activeTabIndex == _schemaTabIndex
                      ? _buildSchemaTab(context)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    String dateStr,
  ) {
    final isBottom = widget.dockPosition == InspectorDockPosition.bottom;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showDateChip = constraints.maxWidth >= 950;
          final showChips = constraints.maxWidth >= 550;
          final showStepper =
              widget.totalMessages != null && widget.totalMessages! > 0;

          return Row(
            children: [
              // Left: Key & Stepper
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.data_object,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: l10n.keyLabelWithColon,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text: widget.message.key?.isNotEmpty == true
                                    ? widget.message.key!
                                    : '<null>',
                                style: AppFonts.robotoMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (showStepper) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          tooltip: l10n.previousMessageTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed:
                              (widget.messageIndex != null &&
                                  widget.messageIndex! > 0)
                              ? widget.onPreviousMessage
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            l10n.messagePosition(
                              (widget.messageIndex ?? 0) + 1,
                              widget.totalMessages ?? 1,
                            ),
                            style: AppFonts.robotoMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          tooltip: l10n.nextMessageTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed:
                              (widget.messageIndex != null &&
                                  widget.totalMessages != null &&
                                  widget.messageIndex! <
                                      widget.totalMessages! - 1)
                              ? widget.onNextMessage
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Center: Metadata Chips
              if (showChips)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCompactChip(
                        context,
                        'P: ${widget.message.partition}',
                        Icons.grid_view,
                      ),
                      const SizedBox(width: 6),
                      _buildCompactChip(
                        context,
                        'O: ${widget.message.offset}',
                        Icons.numbers,
                      ),
                      if (showDateChip) ...[
                        const SizedBox(width: 6),
                        _buildCompactChip(context, dateStr, Icons.access_time),
                      ],
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: l10n.copyMetadata,
                        icon: const Icon(Icons.copy, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: () {
                          final text =
                              'Partition: ${widget.message.partition}\n'
                              'Offset: ${widget.message.offset}\n'
                              'Timestamp: $dateStr'
                              '${_schemaMetadataLine(l10n)}';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.metadataCopied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Right: Action Buttons (positioned at the end)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search in message toggle
                        IconButton(
                          tooltip: l10n.searchInMessage,
                          icon: Icon(
                            _isSearchOpen ? Icons.search_off : Icons.search,
                            size: 16,
                            color: _isSearchOpen ? colorScheme.primary : null,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchOpen = !_isSearchOpen;
                              if (!_isSearchOpen) {
                                _searchController.clear();
                                _totalMatches = 0;
                                _currentMatchIndex = 0;
                              }
                            });
                            if (_isSearchOpen) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _searchFocusNode.requestFocus();
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        // Copy Entire Message as JSON
                        IconButton(
                          tooltip: l10n.copyMessage,
                          icon: const Icon(Icons.copy_all, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            final fullJson = _formatFullMessageJson(dateStr);
                            Clipboard.setData(ClipboardData(text: fullJson));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.fullMessageCopied),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        // Copy Shareable Link
                        IconButton(
                          key: const Key('copy_shareable_link_button'),
                          tooltip: l10n.copyShareableLink,
                          icon: const Icon(Icons.link, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            final ref = MessageReference(
                              cluster: widget.profile?.name,
                              topic: widget.message.topic,
                              partition: widget.message.partition,
                              offset: widget.message.offset,
                              filter: widget.searchPhrase,
                            );
                            Clipboard.setData(
                              ClipboardData(text: ref.toString()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.shareableLinkCopied),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        // Maximize / Focus Mode Toggle
                        if (widget.onToggleMaximize != null) ...[
                          IconButton(
                            tooltip: widget.isMaximized
                                ? l10n.exitFocusMode
                                : l10n.focusMode,
                            icon: Icon(
                              widget.isMaximized
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: 18,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: widget.onToggleMaximize,
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Docking Toggle (when not maximized)
                        if (!widget.isMaximized) ...[
                          IconButton(
                            tooltip: isBottom ? l10n.dockSide : l10n.dockBottom,
                            icon: Icon(
                              isBottom
                                  ? Icons.view_sidebar_outlined
                                  : Icons.dock_outlined,
                              size: 16,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: widget.onToggleDockPosition,
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Close Button
                        IconButton(
                          tooltip: l10n.closeInspector,
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: CallbackShortcuts(
                bindings: {
                  ...AppShortcuts.nextSearchMatch.bind(_jumpToNextMatch),
                  ...AppShortcuts.previousSearchMatch.bind(
                    _jumpToPreviousMatch,
                  ),
                  ...AppShortcuts.closeInspectorSearch.bind(() {
                    setState(() {
                      _isSearchOpen = false;
                      _searchController.clear();
                      _payloadMatchCount = 0;
                      _keyMatchCount = 0;
                      _headerValueMatchCounts = List.filled(
                        widget.message.headers?.length ?? 0,
                        0,
                      );
                      _recomputeTotalMatches();
                    });
                  }),
                },
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: l10n.searchInMessage,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            tooltip: l10n.clear,
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _payloadMatchCount = 0;
                                _keyMatchCount = 0;
                                _headerValueMatchCounts = List.filled(
                                  widget.message.headers?.length ?? 0,
                                  0,
                                );
                                _recomputeTotalMatches();
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _currentMatchIndex = 0;
                      _recomputeTotalMatches();
                    });
                  },
                  onSubmitted: (_) => _jumpToNextMatch(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_searchState == RawSearchState.running)
            SizedBox(
              width: 14,
              height: 14,
              child: Semantics(
                label: l10n.searchRunning,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_searchState == RawSearchState.failed)
            Text(
              l10n.searchFailed,
              style: AppFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            )
          else
            Text(
              _totalMatches > 0
                  ? (_searchState == RawSearchState.capped
                        ? l10n.matchesCountCapped(
                            _currentMatchIndex + 1,
                            _totalMatches,
                          )
                        : l10n.matchesCount(
                            _currentMatchIndex + 1,
                            _totalMatches,
                          ))
                  : (_searchController.text.isNotEmpty ? l10n.noMatches : ''),
              style: AppFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            tooltip: l10n.previousMatchTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _totalMatches > 0 ? _jumpToPreviousMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            tooltip: l10n.nextMatchTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _totalMatches > 0 ? _jumpToNextMatch : null,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: l10n.closeSearch,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              setState(() {
                _isSearchOpen = false;
                _searchController.clear();
                _totalMatches = 0;
                _currentMatchIndex = 0;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Subject, version and schema id of the selected message, labeled for the key
  /// and the value side. Activating a resolved entry opens the schema inspector.
  Widget _buildProvenanceRow(BuildContext context, AppLocalizations l10n) {
    return Padding(
      key: const Key('message_provenance_row'),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _buildProvenanceEntry(
            context,
            l10n,
            l10n.schemaSideKey,
            widget.message.keySchema,
            widget.message.keyLocalSchema,
            'provenance_key_entry',
          ),
          _buildProvenanceEntry(
            context,
            l10n,
            l10n.schemaSideValue,
            widget.message.valueSchema,
            widget.message.valueLocalSchema,
            'provenance_value_entry',
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceEntry(
    BuildContext context,
    AppLocalizations l10n,
    String side,
    MessageSchema? schema,
    LocalSchemaUseDto? localSchema,
    String key,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = AppFonts.robotoMono(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );

    if (localSchema != null) {
      if (localSchema.error != null) {
        final err = localSchema.error!;
        final msg =
            '$side: ${l10n.localSchemaProvenanceFailed(localSchema.fileName)} — ${describeLocalDecodeError(l10n, err.kind, err.detail)}';
        return Text(
          msg,
          key: Key(key),
          style: style.copyWith(color: colorScheme.error),
        );
      }
      final formatName = localSchemaFormatLabel(l10n, localSchema.format);
      final desc = localSchema.messageType != null
          ? l10n.localSchemaProvenanceDecodedWithMsg(
              localSchema.fileName,
              formatName,
              localSchema.messageType!,
            )
          : l10n.localSchemaProvenanceDecoded(localSchema.fileName, formatName);
      return Text('$side: $desc', key: Key(key), style: style);
    }

    if (schema == null) {
      return Text(
        '$side: ${l10n.schemaNone}',
        key: Key(key),
        style: style.copyWith(fontStyle: FontStyle.italic),
      );
    }

    final resolved = schema.subject != null && schema.version != null;
    final label = resolved
        ? '$side: ${l10n.messageSchemaResolved(schema.subject!, schema.version!, schema.schemaId)}'
        : '$side: ${l10n.messageSchemaUnresolved(schema.schemaId)}';

    if (!resolved) {
      return Tooltip(
        key: Key(key),
        message: l10n.messageSchemaUnresolvedTooltip,
        child: Text(label, style: style),
      );
    }

    return InkWell(
      key: Key(key),
      onTap: () => _openSchemaOfMessage(schema.subject!, schema.version!),
      child: Text(
        label,
        style: style.copyWith(decoration: TextDecoration.underline),
      ),
    );
  }

  void _openSchemaOfMessage(String subject, int version) {
    setState(() {
      _schemaSubject = subject;
      _schemaVersion = version;
    });
    _tabController.animateTo(_schemaTabIndex);
  }

  String _schemaMetadataLine(AppLocalizations l10n) {
    final keySchema = widget.message.keySchema;
    final valueSchema = widget.message.valueSchema;
    final keyLocal = widget.message.keyLocalSchema;
    final valueLocal = widget.message.valueLocalSchema;
    if (keySchema == null &&
        valueSchema == null &&
        keyLocal == null &&
        valueLocal == null) {
      return '';
    }

    String describe(MessageSchema? schema, LocalSchemaUseDto? local) {
      if (local != null) {
        if (local.error != null) {
          return '${l10n.localSchemaProvenanceFailed(local.fileName)}: ${describeLocalDecodeError(l10n, local.error!.kind, local.error!.detail)}';
        }
        final fmt = localSchemaFormatLabel(l10n, local.format);
        return local.messageType != null
            ? l10n.localSchemaProvenanceDecodedWithMsg(
                local.fileName,
                fmt,
                local.messageType!,
              )
            : l10n.localSchemaProvenanceDecoded(local.fileName, fmt);
      }
      if (schema == null) return l10n.schemaNone;
      if (schema.subject != null && schema.version != null) {
        return '${schema.subject} v${schema.version} (#${schema.schemaId})';
      }
      return '#${schema.schemaId} (unresolved)';
    }

    return '\n${l10n.schemaSideKey}: ${describe(keySchema, keyLocal)}'
        '\n${l10n.schemaSideValue}: ${describe(valueSchema, valueLocal)}';
  }

  Widget _buildCompactChip(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.robotoMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
    ColorScheme colorScheme,
    AppLocalizations l10n,
    int headerCount,
  ) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      tabs: [
        Tab(text: l10n.tabPayload),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.tabKeyAndHeaders),
              if (headerCount > 0) ...[
                const SizedBox(width: 6),
                Badge(label: Text('$headerCount')),
              ],
            ],
          ),
        ),
        Tab(text: l10n.tabRawJson),
        Tab(text: l10n.schemaTabTitle),
      ],
    );
  }

  Widget _buildPayloadTab(BuildContext context) {
    final Map<String, String> headerMap = {
      for (final h in widget.message.headers ?? <KafkaHeader>[]) h.key: h.value,
    };
    final failureMeta = DlqFailureMetadata.fromHeaders(headerMap);
    final activeTarget = _resolveMatchTarget(_currentMatchIndex);
    final focusedPayloadMatch =
        activeTarget != null && activeTarget.viewerKey == _payloadViewerKey
        ? activeTarget.localIndex
        : null;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failureMeta != null)
            DlqFailureDiagnosticsCard(
              metadata: failureMeta,
              message: widget.message,
              profile: widget.profile,
              onJumpToOriginalMessage: widget.onJumpToOriginalMessage,
            ),
          Expanded(
            child: JsonOrStringViewer(
              key: _payloadViewerKey,
              rawContent: widget.message.payload ?? '',
              searchQuery: _effectiveSearchQuery,
              focusedMatchIndex: focusedPayloadMatch,
              onMatchCountChanged: (count) {
                if (_payloadMatchCount != count && mounted) {
                  setState(() {
                    _payloadMatchCount = count;
                    _recomputeTotalMatches();
                  });
                }
              },
              onSearchStateChanged: (state) {
                if (_searchState != state && mounted) {
                  setState(() {
                    _searchState = state;
                  });
                }
              },
              findMatches: widget.findPayloadMatches,
              expand: true,
              persistenceKey: 'inspector_payload',
              onPinToColumn: widget.onPinToColumn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedHeaderKey(
    String keyText,
    ColorScheme colorScheme,
    int? focusedOccurrence,
  ) {
    final baseStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    final query = _effectiveSearchQuery.trim();
    if (query.isEmpty || keyText.isEmpty) {
      return SelectableText(keyText, style: baseStyle);
    }

    final lowerText = keyText.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return SelectableText(keyText, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var start = 0;
    var occ = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        if (start < keyText.length) {
          spans.add(TextSpan(text: keyText.substring(start), style: baseStyle));
        }
        break;
      }
      if (idx > start) {
        spans.add(
          TextSpan(text: keyText.substring(start, idx), style: baseStyle),
        );
      }
      final isFocused = focusedOccurrence == occ;
      spans.add(
        TextSpan(
          text: keyText.substring(idx, idx + query.length),
          style: baseStyle.copyWith(
            backgroundColor: isFocused
                ? Colors.orange
                : colorScheme.tertiaryContainer,
            color: isFocused ? Colors.black : colorScheme.onTertiaryContainer,
          ),
        ),
      );
      occ++;
      start = idx + query.length;
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildKeyAndHeadersTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final headers = widget.message.headers ?? [];
    final activeTarget = _resolveMatchTarget(_currentMatchIndex);
    final focusedKeyMatch =
        activeTarget != null && activeTarget.viewerKey == _keyViewerKey
        ? activeTarget.localIndex
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Key Viewer
          Container(
            key: _keySectionKey,
            child: JsonOrStringViewer(
              key: _keyViewerKey,
              title: l10n.inspectorKeySection,
              rawContent: widget.message.key ?? '',
              persistenceKey: 'inspector_key',
              treeViewHeight: 280,
              fitTreeHeight: true,
              emptyValueMarker: l10n.emptyValueMarker,
              searchQuery: _effectiveSearchQuery,
              focusedMatchIndex: focusedKeyMatch,
              onMatchCountChanged: (count) {
                if (_keyMatchCount != count && mounted) {
                  setState(() {
                    _keyMatchCount = count;
                    _recomputeTotalMatches();
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          // Headers Header with Copy Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.inspectorHeadersSection(headers.length),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headers.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    final text = headers
                        .map((h) => '${h.key}: ${h.value}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.copiedHeaders),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 13),
                  label: Text(
                    l10n.copyHeaders,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (headers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  l10n.noHeaders,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            for (var index = 0; index < headers.length; index++)
              Padding(
                key: _headerSectionKeys[index],
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: JsonOrStringViewer(
                    key: _headerViewerKeys[index],
                    titleWidget: _buildHighlightedHeaderKey(
                      headers[index].key,
                      colorScheme,
                      activeTarget?.headerKeyIndex == index
                          ? activeTarget!.localIndex
                          : null,
                    ),
                    rawContent: headers[index].value,
                    persistenceKey: 'inspector_header',
                    treeViewHeight: 220,
                    fitTreeHeight: true,
                    recognizeHexFallback: true,
                    emptyValueMarker: l10n.emptyValueMarker,
                    searchQuery: _effectiveSearchQuery,
                    focusedMatchIndex:
                        activeTarget != null &&
                            activeTarget.viewerKey == _headerViewerKeys[index]
                        ? activeTarget.localIndex
                        : null,
                    onMatchCountChanged: (count) {
                      if (index < _headerValueMatchCounts.length &&
                          _headerValueMatchCounts[index] != count &&
                          mounted) {
                        setState(() {
                          _headerValueMatchCounts[index] = count;
                          _recomputeTotalMatches();
                        });
                      }
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRawJsonTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    String dateStr,
  ) {
    final fullJson = _formatFullMessageJson(dateStr);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            fullJson,
            style: AppFonts.robotoMono(
              fontSize: 11,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchemaTab(BuildContext context) {
    final builder = widget.schemaTabBuilder;
    if (builder == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.selectClusterToViewTopics ??
              'No active cluster',
        ),
      );
    }
    return builder(context, widget.message, _schemaSubject, _schemaVersion);
  }
}

class _SearchTarget {
  final int tab;
  final GlobalKey? sectionKey;
  final GlobalKey<JsonOrStringViewerState>? viewerKey;
  final int? headerKeyIndex;
  final int? localIndex;

  const _SearchTarget({
    required this.tab,
    this.sectionKey,
    this.viewerKey,
    this.headerKeyIndex,
    this.localIndex,
  });
}
