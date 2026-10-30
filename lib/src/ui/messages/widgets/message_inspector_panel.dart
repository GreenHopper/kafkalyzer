import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:kafkalyzer/src/features/navigation/models/message_reference.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/dlq_failure_diagnostics_card.dart';
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
  final void Function(String topic, int partition, int offset)?
  onJumpToOriginalMessage;

  const MessageInspectorPanel({
    super.key,
    required this.message,
    required this.dockPosition,
    required this.onToggleDockPosition,
    required this.onClose,
    this.searchPhrase,
    this.messageIndex,
    this.totalMessages,
    this.onPreviousMessage,
    this.onNextMessage,
    this.isMaximized = false,
    this.onToggleMaximize,
    this.onPinToColumn,
    this.profile,
    this.onJumpToOriginalMessage,
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
  final GlobalKey<JsonOrStringViewerState> _payloadViewerKey = GlobalKey();
  late final TabController _tabController;

  // Schema of the selected message, set when the user jumps to it.
  String? _schemaSubject;
  int? _schemaVersion;

  static const int _schemaTabIndex = 3;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didUpdateWidget(covariant MessageInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _currentMatchIndex = 0;
    }
  }

  @override
  void dispose() {
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

  void _jumpToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _payloadViewerKey.currentState?.jumpToMatch(_currentMatchIndex);
  }

  void _jumpToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _payloadViewerKey.currentState?.jumpToMatch(_currentMatchIndex);
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
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 1: Payload Viewer
                  _buildPayloadTab(context),
                  // Tab 2: Key & Headers
                  _buildKeyAndHeadersTab(context, colorScheme, l10n),
                  // Tab 3: Raw JSON
                  _buildRawJsonTab(context, colorScheme, l10n, dateStr),
                  // Tab 4: Schema Viewer
                  _buildSchemaTab(context),
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
                            text: 'Key: ',
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
                      Tooltip(
                        message: l10n.copyMetadata,
                        child: IconButton(
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
                        Tooltip(
                          message: l10n.searchInMessage,
                          child: IconButton(
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
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _searchFocusNode.requestFocus();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Copy Entire Message as JSON
                        Tooltip(
                          message: l10n.copyMessage,
                          child: IconButton(
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
                        ),
                        const SizedBox(width: 4),
                        // Copy Shareable Link
                        Tooltip(
                          message: l10n.copyShareableLink,
                          child: IconButton(
                            key: const Key('copy_shareable_link_button'),
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
                        ),
                        const SizedBox(width: 4),
                        // Maximize / Focus Mode Toggle
                        if (widget.onToggleMaximize != null) ...[
                          Tooltip(
                            message: widget.isMaximized
                                ? l10n.exitFocusMode
                                : l10n.focusMode,
                            child: IconButton(
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
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Docking Toggle (when not maximized)
                        if (!widget.isMaximized) ...[
                          Tooltip(
                            message: isBottom ? l10n.dockSide : l10n.dockBottom,
                            child: IconButton(
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
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Close Button
                        Tooltip(
                          message: l10n.closeInspector,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: widget.onClose,
                          ),
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
                  const SingleActivator(LogicalKeyboardKey.enter):
                      _jumpToNextMatch,
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                      _jumpToPreviousMatch,
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    setState(() {
                      _isSearchOpen = false;
                      _searchController.clear();
                      _totalMatches = 0;
                      _currentMatchIndex = 0;
                    });
                  },
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
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _totalMatches = 0;
                                _currentMatchIndex = 0;
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
                    });
                  },
                  onSubmitted: (_) => _jumpToNextMatch(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _totalMatches > 0
                ? l10n.matchesCount(_currentMatchIndex + 1, _totalMatches)
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
            'provenance_key_entry',
          ),
          _buildProvenanceEntry(
            context,
            l10n,
            l10n.schemaSideValue,
            widget.message.valueSchema,
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
    String key,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = AppFonts.robotoMono(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );

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
    if (keySchema == null && valueSchema == null) return '';

    String describe(MessageSchema? schema) {
      if (schema == null) return l10n.schemaNone;
      if (schema.subject != null && schema.version != null) {
        return '${schema.subject} v${schema.version} (#${schema.schemaId})';
      }
      return '#${schema.schemaId} (unresolved)';
    }

    return '\n${l10n.schemaSideKey}: ${describe(keySchema)}'
        '\n${l10n.schemaSideValue}: ${describe(valueSchema)}';
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

  void _defaultJumpToOriginalMessage(
    String topicName,
    int partition,
    int offset,
  ) {
    if (getIt.isRegistered<ActiveConnectionController>()) {
      final activeCtrl = getIt<ActiveConnectionController>();
      final topicMeta = activeCtrl.topics
          .where((t) => t.name == topicName)
          .firstOrNull;
      if (topicMeta != null) {
        activeCtrl.setActiveTopic(topicMeta, widget.profile);
      }
    }
  }

  Widget _buildPayloadTab(BuildContext context) {
    final Map<String, String> headerMap = {
      for (final h in widget.message.headers ?? <KafkaHeader>[]) h.key: h.value,
    };
    final failureMeta = DlqFailureMetadata.fromHeaders(headerMap);

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
              onJumpToOriginalMessage:
                  widget.onJumpToOriginalMessage ??
                  _defaultJumpToOriginalMessage,
            ),
          Expanded(
            child: JsonOrStringViewer(
              key: _payloadViewerKey,
              rawContent: widget.message.payload ?? '',
              searchQuery: _effectiveSearchQuery,
              focusedMatchIndex: _totalMatches > 0 ? _currentMatchIndex : null,
              onMatchCountChanged: (count) {
                if (_totalMatches != count && mounted) {
                  setState(() {
                    _totalMatches = count;
                    if (_currentMatchIndex >= count) {
                      _currentMatchIndex = 0;
                    }
                  });
                }
              },
              expand: true,
              persistenceKey: 'inspector_payload',
              onPinToColumn: widget.onPinToColumn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyAndHeadersTab(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final headers = widget.message.headers ?? [];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Key Viewer
          SizedBox(
            height: 130,
            child: JsonOrStringViewer(
              title: 'Key',
              rawContent: widget.message.key ?? '',
              persistenceKey: 'inspector_key',
            ),
          ),
          const SizedBox(height: 8),
          // Headers Header with Copy Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Headers (${headers.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.primary,
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
          const SizedBox(height: 4),
          // Headers List
          Expanded(
            child: headers.isEmpty
                ? Center(
                    child: Text(
                      l10n.noHeaders,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: headers.length,
                    itemBuilder: (context, index) {
                      final header = headers[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: SelectableText(
                            header.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: SelectableText(
                            header.value,
                            style: AppFonts.robotoMono(
                              fontSize: 11,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.content_copy, size: 14),
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.copiedHeaderValue(header.key),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: header.value),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.copiedHeaderValue(header.key),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
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
    final effectiveProfile =
        widget.profile ??
        (getIt.isRegistered<ActiveConnectionController>()
            ? getIt<ActiveConnectionController>().activeProfile
            : null);

    if (effectiveProfile == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.selectClusterToViewTopics ??
              'No active cluster',
        ),
      );
    }

    return TopicSchemaInspectorView(
      profile: effectiveProfile,
      initialSubject: _schemaSubject,
      initialVersion: _schemaVersion,
      topicName: widget.message.topic,
      isEmbedded: true,
      onPinToColumn: widget.onPinToColumn,
    );
  }
}
