import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicSelectionDialog extends StatefulWidget {
  final List<TopicMetadata> topics;
  final bool multiSelect;
  final List<String> initialSelection;
  final ClusterProfile? clusterProfile;

  const TopicSelectionDialog({
    super.key,
    required this.topics,
    this.multiSelect = false,
    this.initialSelection = const [],
    this.clusterProfile,
  });

  @override
  State<TopicSelectionDialog> createState() => _TopicSelectionDialogState();
}

class _TopicSelectionDialogState extends State<TopicSelectionDialog> {
  late List<TopicMetadata> _filteredTopics;
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedTopics;

  bool _showInternalTopics = false;
  bool _showStreamTopics = false;

  @override
  void initState() {
    super.initState();
    _selectedTopics = Set.from(widget.initialSelection);
    _filter("");
  }

  void _filter(String query) {
    setState(() {
      _filteredTopics = widget.topics.where((t) {
        final name = t.name.toLowerCase();

        // Filter internal topics if not shown
        if (!_showInternalTopics && t.name.startsWith("_")) {
          return false;
        }

        // Filter stream topics if not shown
        if (!_showStreamTopics &&
            (name.endsWith("-topic") ||
                name.endsWith("-changelog") ||
                name.endsWith("-repartition"))) {
          return false;
        }

        // Filter by user query
        if (query.isNotEmpty && !name.contains(query.toLowerCase())) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            _buildDialogTitle(context),
            _buildSearchAndFilters(context),
            const SizedBox(height: 8),
            const Divider(),
            _buildTopicList(),
            _buildDialogActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        widget.multiSelect
            ? "Select Topics (${_filteredTopics.length}/${widget.topics.length})"
            : "Select Topic (${_filteredTopics.length}/${widget.topics.length})",
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterToggle(
            context,
            label: "Internal Topics",
            value: _showInternalTopics,
            onChanged: (val) {
              setState(() {
                _showInternalTopics = val;
                _filter(_searchController.text);
              });
            },
          ),
          _buildFilterToggle(
            context,
            label: "Kafka Stream Topics",
            value: _showStreamTopics,
            onChanged: (val) {
              setState(() {
                _showStreamTopics = val;
                _filter(_searchController.text);
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Search",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _filter,
            autofocus: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Transform.scale(
          scale: 0.8,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildTopicList() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTopics.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final topic = _filteredTopics[index];
          final isSelected = _selectedTopics.contains(topic.name);

          return TopicListItem(
            topic: topic,
            isSelected: isSelected,
            clusterProfile: widget.clusterProfile,
            trailing: widget.multiSelect
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTopics.add(topic.name);
                        } else {
                          _selectedTopics.remove(topic.name);
                        }
                      });
                    },
                  )
                : null,
            onTap: () {
              if (widget.multiSelect) {
                setState(() {
                  if (isSelected) {
                    _selectedTopics.remove(topic.name);
                  } else {
                    _selectedTopics.add(topic.name);
                  }
                });
              } else {
                Navigator.pop(context, [topic]);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDialogActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (widget.multiSelect) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                // Find full metadata objects for selected names
                final selected = widget.topics
                    .where((t) => _selectedTopics.contains(t.name))
                    .toList();
                Navigator.pop(context, selected);
              },
              child: Text("Select (${_selectedTopics.length})"),
            ),
          ],
        ],
      ),
    );
  }
}
