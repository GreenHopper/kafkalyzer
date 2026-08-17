import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/message_diff.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';

class MessagesDiffView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final String? searchPhrase;

  const MessagesDiffView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.searchPhrase,
  });

  @override
  State<MessagesDiffView> createState() => _MessagesDiffViewState();
}

class _MessagesDiffViewState extends State<MessagesDiffView> {
  // Map<String, KafkaMessage> where Key is the message ID and value is the previous one.
  final Map<String, KafkaMessage> _previousMessages = {};

  // Cache the generated diff futures so they aren't recomputed on scroll
  final Map<String, Future<MessageDiff>> _diffCache = {};

  @override
  void initState() {
    super.initState();
    _groupMessages();
  }

  @override
  void didUpdateWidget(covariant MessagesDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _groupMessages();
    }
  }

  void _groupMessages() {
    _previousMessages.clear();
    _diffCache.clear();

    // Group messages by key internally to find predecessors
    final Map<String, List<KafkaMessage>> keyedMessages = {};

    List<KafkaMessage> sorted = List.from(widget.messages);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (var msg in sorted) {
      final key = _getCompositeKey(msg);
      keyedMessages.putIfAbsent(key, () => []);

      final history = keyedMessages[key]!;
      if (history.isNotEmpty) {
        _previousMessages[_getMessageId(msg)] = history.last;
      }
      history.add(msg);
    }
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
    final future = MessageDiff.computeDiff(previous, current);
    _diffCache[msgId] = future;
    return future;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(child: Text("No messages to display"));
    }

    return Timeline.tileBuilder(
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
    );
  }

  Widget _buildDiffCard(
    BuildContext context,
    KafkaMessage current,
    KafkaMessage? previous,
  ) {
    final isInitial = previous == null;

    return TimelineMessageCard(
      message: current,
      searchPhrase: widget.searchPhrase,
      onTap: () => widget.onMessageTap(current),
      showPayloadPreview: isInitial,
      customContent: isInitial
          ? null
          : _LazyDiffViewer(
              current: current,
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
  final Future<MessageDiff>? Function() getCachedDiff;
  final Future<MessageDiff> Function() computeAndCacheDiff;

  const _LazyDiffViewer({
    required this.current,
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
          return const Text(
            "Error computing diff",
            style: TextStyle(color: Colors.red),
          );
        }
        final diff = snapshot.data;
        if (diff == null) return const SizedBox.shrink();

        if (diff.isJson && diff.jsonDiffToPrevious != null) {
          return JsonDiffWidget(diffNode: diff.jsonDiffToPrevious!);
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
