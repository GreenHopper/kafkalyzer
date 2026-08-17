import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:timelines_plus/timelines_plus.dart';

import 'package:kafkalyzer/src/ui/color_utils.dart';

import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/extraction_utils.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';

class MessagesTimelineView extends StatelessWidget {
  final List<KafkaMessage> messages;
  final Function(KafkaMessage) onMessageTap;
  final String? searchPhrase;
  final bool showNonMatches;
  final Map<String, List<ScriptExtraction>>? stepExtractions;

  const MessagesTimelineView({
    super.key,
    required this.messages,
    required this.onMessageTap,
    this.searchPhrase,
    this.showNonMatches = false,
    this.stepExtractions,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
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
        itemCount: messages.length,
        contentsBuilder: (context, index) {
          final message = messages[index];
          final stepName = message is ScriptResultMessage
              ? message.stepName
              : 'Global (No Step)';
          final extractedValues = _getExtractedValues(message);
          final isMatch = _isMatch(message, stepName);

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: _LazyTimelineCard(
              message: message,
              stepName: stepName,
              extractedValues: extractedValues,
              isMatch: isMatch,
              showNonMatches: showNonMatches,
              searchPhrase: searchPhrase,
              onMessageTap: onMessageTap,
            ),
          );
        },
        oppositeContentsBuilder: (context, index) {
          final message = messages[index];
          final prevMessage = index > 0 ? messages[index - 1] : null;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildMetadata(context, message, prevMessage),
          );
        },
        indicatorBuilder: (context, index) {
          final message = messages[index];
          return DotIndicator(
            color: ColorUtils.getColorForString(message.topic),
            size: 15.0,
          );
        },
        connectorBuilder: (context, index, type) {
          final message = messages[index];
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
        stepExtractions != null &&
        stepExtractions!.containsKey(message.stepId)) {
      final extractions = stepExtractions![message.stepId]!;
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
    if (searchPhrase == null || searchPhrase!.isEmpty) return true;

    final query = searchPhrase!.toLowerCase();
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
  final Function(KafkaMessage) onMessageTap;

  const _LazyTimelineCard({
    required this.message,
    required this.stepName,
    required this.extractedValues,
    required this.isMatch,
    required this.showNonMatches,
    required this.searchPhrase,
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
      ),
    );
  }
}
