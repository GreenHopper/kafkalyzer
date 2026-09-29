import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:timelines_plus/timelines_plus.dart';

import 'package:kafkalyzer/src/ui/color_utils.dart';

import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/extraction_utils.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';

class MessagesTimelineView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final String? searchPhrase;
  final bool showNonMatches;
  final Map<String, List<ScriptExtraction>>? stepExtractions;
  final KafkaMessage? selectedMessage;

  const MessagesTimelineView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.searchPhrase,
    this.showNonMatches = false,
    this.stepExtractions,
    this.selectedMessage,
  });

  @override
  State<MessagesTimelineView> createState() => _MessagesTimelineViewState();
}

class _MessagesTimelineViewState extends State<MessagesTimelineView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollToSelectedMessage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.3,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      } else {
        final estimatedOffset = (index * 160.0).clamp(
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
            Scrollable.ensureVisible(
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

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(child: Text("No messages to display"));
    }

    return Timeline.tileBuilder(
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
          final stepName = message is ScriptResultMessage
              ? message.stepName
              : 'Global (No Step)';
          final extractedValues = _getExtractedValues(message);
          final isMatch = _isMatch(message, stepName);

          return Padding(
            key: _itemKeys.putIfAbsent(index, () => GlobalKey()),
            padding: const EdgeInsets.all(8.0),
            child: _LazyTimelineCard(
              message: message,
              stepName: stepName,
              extractedValues: extractedValues,
              isMatch: isMatch,
              showNonMatches: widget.showNonMatches,
              searchPhrase: widget.searchPhrase,
              isSelected: widget.selectedMessage == message,
              onMessageTap: widget.onMessageTap,
            ),
          );
        },
        oppositeContentsBuilder: (context, index) {
          final message = widget.messages[index];
          final prevMessage = index > 0 ? widget.messages[index - 1] : null;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildMetadata(context, message, prevMessage),
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
            color: ColorUtils.getColorForString(
              message.topic,
            ), // Use topic color for line
          );
        },
      ),
    );
  }

  List<MapEntry<String, String>> _getExtractedValues(KafkaMessage message) {
    List<MapEntry<String, String>> extractedValues = [];
    if (message is ScriptResultMessage &&
        widget.stepExtractions != null &&
        widget.stepExtractions!.containsKey(message.stepId)) {
      final extractions = widget.stepExtractions![message.stepId]!;
      for (final ext in extractions) {
        final val = ExtractionUtils.extract(ext, message);
        if (val != null) {
          extractedValues.add(MapEntry(ext.variableName, val));
        }
      }
    }
    return extractedValues;
  }

  bool _isMatch(KafkaMessage message, String stepName) {
    if (widget.searchPhrase == null || widget.searchPhrase!.isEmpty) {
      return true;
    }

    final query = widget.searchPhrase!.toLowerCase();
    final keyMatch = (message.key ?? "").toLowerCase().contains(query);
    final payloadMatch = (message.payload ?? "").toLowerCase().contains(query);
    final topicMatch = message.topic.toLowerCase().contains(query);
    final stepMatch = stepName.toLowerCase().contains(query);

    return keyMatch || payloadMatch || topicMatch || stepMatch;
  }

  Widget _buildMetadata(
    BuildContext context,
    KafkaMessage message,
    KafkaMessage? prevMessage,
  ) {
    return MessageMetadataCard(message: message, prevMessage: prevMessage);
  }
}

class _LazyTimelineCard extends StatefulWidget {
  final KafkaMessage message;
  final String stepName;
  final List<MapEntry<String, String>> extractedValues;
  final bool isMatch;
  final bool showNonMatches;
  final String? searchPhrase;
  final bool isSelected;
  final Function(KafkaMessage) onMessageTap;

  const _LazyTimelineCard({
    required this.message,
    required this.stepName,
    required this.extractedValues,
    required this.isMatch,
    required this.showNonMatches,
    required this.searchPhrase,
    this.isSelected = false,
    required this.onMessageTap,
  });

  @override
  State<_LazyTimelineCard> createState() => _LazyTimelineCardState();
}

class _LazyTimelineCardState extends State<_LazyTimelineCard> {
  bool _isReady = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isDisposed && mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      );
    }

    final double opacity = (widget.showNonMatches && !widget.isMatch)
        ? 0.4
        : 1.0;

    return Opacity(
      opacity: opacity,
      child: TimelineMessageCard(
        message: widget.message,
        onTap: () => widget.onMessageTap(widget.message),
        searchPhrase: widget.searchPhrase,
        extractedValues: widget.extractedValues,
        showPayloadPreview: true,
        isSelected: widget.isSelected,
      ),
    );
  }
}
