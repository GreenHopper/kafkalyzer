import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/diff_ignore_list_dialog.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/diff_ignore_suggestions.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';

import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/message_diff.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';
import 'package:kafkalyzer/src/ui/scroll_utils.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';

class MessagesDiffView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final String? searchPhrase;
  final KafkaMessage? selectedMessage;
  final DiffIgnoreListService? ignoreListService;

  const MessagesDiffView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.searchPhrase,
    this.selectedMessage,
    this.ignoreListService,
  });

  @override
  State<MessagesDiffView> createState() => _MessagesDiffViewState();
}

class _MessagesDiffViewState extends State<MessagesDiffView> {
  // Map<String, KafkaMessage> where Key is the message ID and value is the previous one.
  final Map<String, KafkaMessage> _previousMessages = {};

  // Cache the generated diff futures so they aren't recomputed on scroll
  final Map<String, Future<MessageDiff>> _diffCache = {};
  final Map<String, MessageDiff> _completedDiffs = {};
  final Map<String, int> _topicVersion = {};
  final Map<String, List<String>> _lastKnownIgnorePaths = {};
  final Map<String, String> _messageTopics = {};

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  late DiffIgnoreListService _ignoreService;
  DiffIgnoreListService? _ownedIgnoreService;
  List<String> _topics = [];
  String? _selectedHeaderTopic;

  @override
  void initState() {
    super.initState();
    _ignoreService = _resolveIgnoreService();
    _ignoreService.addListener(_onIgnoreListChanged);
    _groupMessages();
    _loadIgnoreListsForTopics();
    _scrollToSelectedMessage();
  }

  DiffIgnoreListService _resolveIgnoreService() {
    if (widget.ignoreListService != null) {
      return widget.ignoreListService!;
    }
    if (getIt.isRegistered<DiffIgnoreListService>()) {
      return getIt<DiffIgnoreListService>();
    }
    _ownedIgnoreService ??= DiffIgnoreListService();
    return _ownedIgnoreService!;
  }

  @override
  void dispose() {
    _ignoreService.removeListener(_onIgnoreListChanged);
    _ownedIgnoreService?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ignoreListService != oldWidget.ignoreListService) {
      _ignoreService.removeListener(_onIgnoreListChanged);
      _ignoreService = _resolveIgnoreService();
      _ignoreService.addListener(_onIgnoreListChanged);
      _loadIgnoreListsForTopics();
    }
    if (widget.messages != oldWidget.messages) {
      _groupMessages();
      _loadIgnoreListsForTopics();
    }
    if (widget.selectedMessage != oldWidget.selectedMessage) {
      _scrollToSelectedMessage();
    }
  }

  void _scrollToSelectedMessage() {
    if (widget.selectedMessage == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final index = widget.messages.indexOf(widget.selectedMessage!);
      if (index < 0) return;

      final key = _itemKeys[index];
      if (key?.currentContext != null) {
        ensureVisibleVertically(
          key!.currentContext!,
          alignment: 0.3,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      } else {
        final estimatedOffset = (index * 220.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final postKey = _itemKeys[index];
          if (postKey?.currentContext != null) {
            ensureVisibleVertically(
              postKey!.currentContext!,
              alignment: 0.3,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });
  }

  void _groupMessages() {
    _previousMessages.clear();
    _diffCache.clear();
    _completedDiffs.clear();
    _messageTopics.clear();

    final seenTopics = <String>{};
    final orderedTopics = <String>[];
    for (final msg in widget.messages) {
      _messageTopics[_getMessageId(msg)] = msg.topic;
      if (seenTopics.add(msg.topic)) {
        orderedTopics.add(msg.topic);
      }
    }
    _topics = orderedTopics;
    if (_topics.isEmpty) {
      _selectedHeaderTopic = null;
    } else if (_selectedHeaderTopic == null ||
        !_topics.contains(_selectedHeaderTopic)) {
      _selectedHeaderTopic = _topics.first;
    }

    // Group messages by key internally to find chronological predecessors.
    // Display order stays as provided by MessagesView; this ascending sort is
    // only used to discover the prior message for each key.
    final Map<String, List<KafkaMessage>> keyedMessages = {};

    final List<KafkaMessage> sortedChronological = List.from(widget.messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (var msg in sortedChronological) {
      final key = _getCompositeKey(msg);
      keyedMessages.putIfAbsent(key, () => []);

      final history = keyedMessages[key]!;
      if (history.isNotEmpty) {
        _previousMessages[_getMessageId(msg)] = history.last;
      }
      history.add(msg);
    }
  }

  Future<void> _loadIgnoreListsForTopics() async {
    for (final topic in _topics) {
      final result = await _ignoreService.load(topic);
      if (!mounted) return;
      final prev = _lastKnownIgnorePaths[topic];
      final changed =
          prev == null ||
          prev.length != result.paths.length ||
          !_listEquals(prev, result.paths);
      _lastKnownIgnorePaths[topic] = List<String>.from(result.paths);
      if (changed && result.paths.isNotEmpty) {
        _invalidateTopicCache(topic);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onIgnoreListChanged() {
    if (!mounted) return;
    var anyChanged = false;
    for (final topic in _topics) {
      final current = _ignoreService.getPathsSync(topic);
      final prev = _lastKnownIgnorePaths[topic] ?? const [];
      if (!_listEquals(prev, current)) {
        _lastKnownIgnorePaths[topic] = List<String>.from(current);
        _invalidateTopicCache(topic);
        anyChanged = true;
      }
    }
    if (anyChanged) {
      setState(() {});
    }
  }

  void _invalidateTopicCache(String topic) {
    final idsToRemove = _messageTopics.entries
        .where((e) => e.value == topic)
        .map((e) => e.key)
        .toList();
    for (final id in idsToRemove) {
      _diffCache.remove(id);
      _completedDiffs.remove(id);
    }
    _topicVersion[topic] = (_topicVersion[topic] ?? 0) + 1;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _getCompositeKey(KafkaMessage msg) {
    return '${msg.topic}/${msg.key ?? "null"}';
  }

  String _getMessageId(KafkaMessage msg) {
    return '${msg.topic}-${msg.partition}-${msg.offset}';
  }

  KafkaMessage? _findPreviousMessage(KafkaMessage current) {
    return _previousMessages[_getMessageId(current)];
  }

  Future<MessageDiff>? _getCachedDiff(KafkaMessage current) {
    final msgId = _getMessageId(current);
    return _diffCache[msgId];
  }

  Future<MessageDiff> _computeAndCacheDiff(
    KafkaMessage current,
    KafkaMessage? previous,
  ) {
    final msgId = _getMessageId(current);
    if (_diffCache.containsKey(msgId)) {
      return _diffCache[msgId]!;
    }
    final ignorePaths = _ignoreService.getPathsSync(current.topic);
    final future =
        MessageDiff.computeDiff(
          previous,
          current,
          ignorePaths: ignorePaths,
          maxEntries: MessageDiff.guiMaxEntries,
        ).then((diff) {
          _completedDiffs[msgId] = diff;
          return diff;
        });
    future.ignore();
    _diffCache[msgId] = future;
    return future;
  }

  List<String> _suggestionsForTopic(String topic) {
    final entries = <JsonDiffEntry>[];
    for (final entry in _completedDiffs.entries) {
      if (_messageTopics[entry.key] == topic) {
        entries.addAll(entry.value.entries);
      }
    }
    return suggestVolatileIgnorePaths(
      entries,
      alreadyIgnored: _ignoreService.getPathsSync(topic),
    );
  }

  Future<void> _openIgnoreDialog(String topic) async {
    await showDialog<void>(
      context: context,
      builder: (_) => DiffIgnoreListDialog(
        topic: topic,
        service: _ignoreService,
        suggestions: _suggestionsForTopic(topic),
      ),
    );
  }

  Future<void> _ignorePathFromRow(String topic, String path) async {
    final l10n = AppLocalizations.of(context);
    final status = await _ignoreService.addPath(topic, path);
    if (!mounted) return;
    if (status == DiffIgnoreSaveStatus.saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.diffIgnoreSaveError ??
                'Failed to save ignore list. Change was not persisted.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.messages.isEmpty) {
      return Center(
        child: Text(l10n?.noMessagesToDisplay ?? 'No messages to display'),
      );
    }

    final headerTopic = _selectedHeaderTopic ?? _topics.first;
    final ignoredCount = _ignoreService.getPathsSync(headerTopic).length;
    final hasLoadError = _ignoreService.hasLoadError(headerTopic);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            children: [
              if (_topics.length > 1) ...[
                DropdownButton<String>(
                  value: headerTopic,
                  isDense: true,
                  items: _topics
                      .map(
                        (t) =>
                            DropdownMenuItem<String>(value: t, child: Text(t)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedHeaderTopic = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
              ],
              TextButton.icon(
                icon: const Icon(Icons.filter_list_off, size: 16),
                label: Text(
                  l10n?.diffIgnoredFieldsHeader(ignoredCount) ??
                      'Ignored fields ($ignoredCount)',
                ),
                onPressed: () => _openIgnoreDialog(headerTopic),
              ),
              if (hasLoadError) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n?.diffIgnoreLoadWarning(headerTopic) ??
                        'Could not read saved ignore list for $headerTopic.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Timeline.tileBuilder(
            controller: _scrollController,
            theme: TimelineThemeData(
              nodePosition: 0.2, // Offset content to allow room for metadata
              color: Theme.of(context).primaryColor,
              connectorTheme: const ConnectorThemeData(thickness: 3.0),
            ),
            builder: TimelineTileBuilder.connected(
              connectionDirection: ConnectionDirection.after,
              itemCount: widget.messages.length,
              contentsBuilder: (context, index) {
                final message = widget.messages[index];
                final previousMessage = _findPreviousMessage(message);

                return Padding(
                  key: _itemKeys.putIfAbsent(index, () => GlobalKey()),
                  padding: const EdgeInsets.all(8.0),
                  child: _buildDiffCard(context, message, previousMessage),
                );
              },
              oppositeContentsBuilder: (context, index) {
                final message = widget.messages[index];
                final previousMessage = _findPreviousMessage(message);
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildMetadata(context, message, previousMessage),
                );
              },
              indicatorBuilder: (context, index) {
                final message = widget.messages[index];
                return DotIndicator(
                  color: ColorUtils.getColorForString(message.topic),
                  size: 15.0,
                );
              },
              connectorBuilder: (context, index, type) {
                final message = widget.messages[index];
                return SolidLineConnector(
                  color: ColorUtils.getColorForString(message.topic),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiffCard(
    BuildContext context,
    KafkaMessage current,
    KafkaMessage? previous,
  ) {
    final isInitial = previous == null;
    final topic = current.topic;
    final version = _topicVersion[topic] ?? 0;

    return TimelineMessageCard(
      message: current,
      searchPhrase: widget.searchPhrase,
      onTap: () => widget.onMessageTap(current),
      showPayloadPreview: isInitial,
      isSelected: widget.selectedMessage == current,
      customContent: isInitial
          ? null
          : _LazyDiffViewer(
              current: current,
              version: version,
              hasLoadError: _ignoreService.hasLoadError(topic),
              onIgnorePath: (path) => _ignorePathFromRow(topic, path),
              onHiddenTap: () => _openIgnoreDialog(topic),
              getCachedDiff: () => _getCachedDiff(current),
              computeAndCacheDiff: () =>
                  _computeAndCacheDiff(current, previous),
            ),
    );
  }

  Widget _buildMetadata(
    BuildContext context,
    KafkaMessage message,
    KafkaMessage? prevMessage,
  ) {
    return MessageMetadataCard(message: message, prevMessage: prevMessage);
  }
}

class _LazyDiffViewer extends StatefulWidget {
  final KafkaMessage current;
  final int version;
  final bool hasLoadError;
  final void Function(String path) onIgnorePath;
  final VoidCallback onHiddenTap;
  final Future<MessageDiff>? Function() getCachedDiff;
  final Future<MessageDiff> Function() computeAndCacheDiff;

  const _LazyDiffViewer({
    required this.current,
    required this.version,
    required this.hasLoadError,
    required this.onIgnorePath,
    required this.onHiddenTap,
    required this.getCachedDiff,
    required this.computeAndCacheDiff,
  });

  @override
  State<_LazyDiffViewer> createState() => _LazyDiffViewerState();
}

class _LazyDiffViewerState extends State<_LazyDiffViewer> {
  Future<MessageDiff>? _diffFuture;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initDiff();
  }

  @override
  void didUpdateWidget(covariant _LazyDiffViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version ||
        oldWidget.current != widget.current) {
      _diffFuture = null;
      _initDiff();
    }
  }

  void _initDiff() {
    final cached = widget.getCachedDiff();
    if (cached != null) {
      // Even if cached, we add a tiny delay to prevent the UI from synchronously
      // laying out thousands of massive JsonDiffWidget trees when scrolling up
      // rapidly through previously-viewed items.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed && mounted) {
          setState(() {
            _diffFuture = cached;
          });
        }
      });
    } else {
      // Delay computation by a generous window. If scrolling fast, this item unmounts
      // before it queues a diff computation, bypassing CPU locks completely.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!_isDisposed && mounted) {
          setState(() {
            _diffFuture = widget.computeAndCacheDiff();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_diffFuture == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      );
    }

    return FutureBuilder<MessageDiff>(
      future: _diffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          );
        }
        if (snapshot.hasError) {
          return Text(
            AppLocalizations.of(context)?.errorComputingDiff ??
                'Error computing diff',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        final diff = snapshot.data;
        if (diff == null) return const SizedBox.shrink();

        if (diff.isJson) {
          final l10n = AppLocalizations.of(context);
          final hiddenCount = widget.hasLoadError ? 0 : diff.hiddenCount;
          final remainingCount = diff.totalCount - diff.entries.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JsonDiffWidget(
                entries: diff.entries,
                hiddenCount: hiddenCount,
                onIgnorePath: widget.onIgnorePath,
                onHiddenTap: widget.onHiddenTap,
              ),
              if (diff.isTruncated && remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                  child: Text(
                    l10n?.diffTruncatedNotice(remainingCount) ??
                        '$remainingCount more differences not shown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          );
        } else if (widget.current.payload == null) {
          return const TombstoneWidget();
        } else {
          return Text(
            TextPreviewUtils.getPayloadPreview(widget.current.payload),
            style: const TextStyle(fontFamily: 'monospace'),
          );
        }
      },
    );
  }
}
