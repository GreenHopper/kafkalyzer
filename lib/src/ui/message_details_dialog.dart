import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class MessageDetailsDialog extends StatefulWidget {
  final KafkaMessage message;
  final String? initialSearchPhrase;

  const MessageDetailsDialog({
    super.key,
    required this.message,
    this.initialSearchPhrase,
  });

  @override
  State<MessageDetailsDialog> createState() => _MessageDetailsDialogState();
}

class _MessageDetailsDialogState extends State<MessageDetailsDialog> {
  late final TextEditingController _searchController;
  late String _searchQuery;

  final GlobalKey<JsonOrStringViewerState> _keyViewerKey = GlobalKey();
  final GlobalKey<JsonOrStringViewerState> _contentViewerKey = GlobalKey();
  int _keyMatchCount = 0;
  int _contentMatchCount = 0;
  int _currentMatchIndex = 0;

  int get _totalMatches => _keyMatchCount + _contentMatchCount;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchPhrase ?? "";
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      // Reset match index on new search
      _currentMatchIndex = 0;
    });
  }

  void _jumpToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToCurrent() {
    if (_currentMatchIndex < _keyMatchCount) {
      _keyViewerKey.currentState?.jumpToMatch(_currentMatchIndex);
    } else {
      _contentViewerKey.currentState?.jumpToMatch(
        _currentMatchIndex - _keyMatchCount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dateStr = DateFormatUtils.formatDateTime(
      context,
      DateTime.fromMillisecondsSinceEpoch(widget.message.timestamp.toInt()),
      withMilliseconds: true,
    );

    return DefaultTabController(
      length: 2,
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width * 0.85,
            maxHeight: size.height * 0.85,
            minWidth: 600,
            minHeight: 400,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Message Details",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            widget.message.topic,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Search Bar
                    Container(
                      width: 400, // Slightly wider for controls
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                hintText: "Search...",
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.search, size: 20),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: -11,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty && _totalMatches > 0) ...[
                            Text(
                              "${_currentMatchIndex + 1}/$_totalMatches",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_up,
                                size: 20,
                              ),
                              onPressed: _jumpToPreviousMatch,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Previous match",
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                              onPressed: _jumpToNextMatch,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Next match",
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  const Tab(text: "Payload & Key"),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Headers"),
                        if (widget.message.headers != null &&
                            widget.message.headers!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Badge(
                            label: Text("${widget.message.headers!.length}"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Payload and Key
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetadataSection(
                            context,
                            widget.message.partition,
                            widget.message.offset,
                            dateStr,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: JsonOrStringViewer(
                              key: _keyViewerKey,
                              title: "Key",
                              rawContent: widget.message.key ?? "",
                              searchQuery: _searchQuery,
                              focusedMatchIndex:
                                  (_totalMatches > 0 &&
                                      _currentMatchIndex < _keyMatchCount)
                                  ? _currentMatchIndex
                                  : null,
                              persistenceKey: 'message_details_key',
                              onMatchCountChanged: (count) {
                                if (_keyMatchCount != count) {
                                  setState(() {
                                    _keyMatchCount = count;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: JsonOrStringViewer(
                              key: _contentViewerKey,
                              title: "Content",
                              rawContent: widget.message.payload ?? "",
                              searchQuery: _searchQuery,
                              expand: true,
                              focusedMatchIndex:
                                  (_totalMatches > 0 &&
                                      _currentMatchIndex >= _keyMatchCount)
                                  ? (_currentMatchIndex - _keyMatchCount)
                                  : null,
                              persistenceKey: 'message_details_content',
                              onMatchCountChanged: (count) {
                                if (_contentMatchCount != count) {
                                  setState(() {
                                    _contentMatchCount = count;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab 2: Headers
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildHeadersTab(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final data = {
                          'topic': widget.message.topic,
                          'partition': widget.message.partition,
                          'offset': widget.message.offset,
                          'timestamp': widget.message.timestamp,
                          'formattedTimestamp': dateStr,
                          'key': _tryParseJson(widget.message.key),
                          'content': _tryParseJson(widget.message.payload),
                          'headers': widget.message.headers
                              ?.map(
                                (h) => {
                                  'key': h.key,
                                  'value': _tryParseJson(h.value),
                                },
                              )
                              .toList(),
                        };
                        final jsonStr = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(data);
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Full message copied to clipboard"),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text("Copy message"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadersTab(BuildContext context) {
    final headers = widget.message.headers;
    if (headers == null || headers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              "No headers present on this message",
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Message Headers (${headers.length})",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final text = headers
                    .map((h) => "${h.key}: ${h.value}")
                    .join("\n");
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All headers copied to clipboard"),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text("Copy all headers"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: headers.length,
            itemBuilder: (context, index) {
              final header = headers[index];
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  title: SelectableText(
                    header.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: SelectableText(
                      header.value,
                      style: AppFonts.robotoMono(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    tooltip: "Copy header value",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: header.value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Copied value of '${header.key}'"),
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
    );
  }

  Widget _buildMetadataSection(
    BuildContext context,
    int partition,
    int offset,
    String timestamp,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Metadata",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: "Copy metadata",
              onPressed: () {
                final text =
                    "Partition: $partition\nOffset: $offset\nTimestamp: $timestamp";
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Metadata copied to clipboard")),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetadataCard(
              context,
              Icons.grid_view,
              "Partition",
              partition.toString(),
            ),
            const SizedBox(width: 12),
            _buildMetadataCard(
              context,
              Icons.numbers,
              "Offset",
              offset.toString(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetadataCard(
                context,
                Icons.access_time,
                "Timestamp",
                timestamp,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppFonts.roboto(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SelectableText(
                value,
                style: AppFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  dynamic _tryParseJson(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      return json.decode(content);
    } catch (_) {
      return content;
    }
  }
}
