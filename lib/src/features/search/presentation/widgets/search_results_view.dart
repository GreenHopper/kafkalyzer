import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class SearchResultsView extends StatelessWidget {
  final List<SearchTarget>? selectedTargets;
  final VoidCallback onClearSelection;

  const SearchResultsView({super.key, required this.selectedTargets, required this.onClearSelection});

  @override
  Widget build(BuildContext context) {
    final searchController = getIt<MultiSearchController>();

    return AnimatedBuilder(
      animation: searchController,
      builder: (context, child) {
        List<KafkaMessage> messages = [];
        if (selectedTargets != null && selectedTargets!.isNotEmpty) {
          for (final target in selectedTargets!) {
            messages.addAll(searchController.getMessagesFor(target));
          }
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } else {
          messages = searchController.getMessagesFor(null);
        }

        final bool hasSelection = selectedTargets != null && selectedTargets!.isNotEmpty;
        final String titleText = hasSelection
            ? (selectedTargets!.length == 1
                  ? "Results: ${selectedTargets!.first.topic.name}"
                  : "Results: ${selectedTargets!.length} Topics")
            : "Combined Results";

        return Column(
          children: [_buildHeader(context, titleText, hasSelection, messages.length), _buildMessageList(messages)],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String titleText, bool hasSelection, int messagesCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleText, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (hasSelection)
                Text(
                  "Source: ${selectedTargets!.first.profile.name}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "$messagesCount Messages",
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
          if (hasSelection) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onClearSelection,
              icon: const Icon(Icons.layers_clear),
              label: const Text("View All"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList(List<KafkaMessage> messages) {
    return Expanded(
      child: MessagesView(
        messages: messages,
        onMessageTap: (msg) {
          return showDialog(
            context:
                getIt<GlobalKey<NavigatorState>>().currentContext ??
                getIt<GlobalKey<ScaffoldMessengerState>>().currentContext!,
            builder: (context) => MessageDetailsDialog(message: msg),
          );
        },
      ),
    );
  }
}
