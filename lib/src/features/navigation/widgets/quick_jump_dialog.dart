import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/navigation/models/message_reference.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class QuickJumpDialog extends StatefulWidget {
  final List<ClusterProfile>? availableClusters;
  final ClusterProfile? currentCluster;
  final String? initialInput;
  final Future<void> Function(
    ClusterProfile cluster,
    String topic,
    int? partition,
    int? offset,
    String? filter,
  )?
  onJump;

  const QuickJumpDialog({
    super.key,
    this.availableClusters,
    this.currentCluster,
    this.initialInput,
    this.onJump,
    this.clusterController,
    this.activeConnection,
  });

  /// Session-wide state; null falls back to the application container.
  final ClusterListController? clusterController;
  final ActiveConnectionController? activeConnection;

  @override
  State<QuickJumpDialog> createState() => _QuickJumpDialogState();
}

class _QuickJumpDialogState extends State<QuickJumpDialog> {
  late final TextEditingController _inputController;
  MessageReference? _parsedRef;
  ClusterProfile? _selectedCluster;
  String? _errorMessage;
  bool _requiresClusterSelection = false;
  late final List<ClusterProfile> _clusters;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.initialInput);

    if (widget.availableClusters != null) {
      _clusters = widget.availableClusters!;
    } else {
      final clusterController =
          widget.clusterController ??
          (getIt.isRegistered<ClusterListController>()
              ? getIt<ClusterListController>()
              : null);
      _clusters = clusterController?.clusters ?? const [];
    }

    _selectedCluster =
        widget.currentCluster ??
        (_clusters.isNotEmpty ? _clusters.first : null);

    if (widget.initialInput != null && widget.initialInput!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onInputChanged(widget.initialInput!, AppLocalizations.of(context));
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged(String text, AppLocalizations? l10n) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _parsedRef = null;
        _errorMessage = null;
        _requiresClusterSelection = false;
      });
      return;
    }

    final ref = MessageReference.tryParse(trimmed);
    if (ref == null) {
      setState(() {
        _parsedRef = null;
        _errorMessage =
            l10n?.quickJumpInvalid ?? 'Invalid reference URI format';
        _requiresClusterSelection = false;
      });
      return;
    }

    ClusterProfile? matchedCluster;
    bool needsPrompt = false;

    if (ref.cluster != null && ref.cluster!.isNotEmpty) {
      matchedCluster = _clusters
          .where((c) => c.name.toLowerCase() == ref.cluster!.toLowerCase())
          .firstOrNull;
      if (matchedCluster == null) {
        needsPrompt = true;
        matchedCluster =
            _selectedCluster ??
            widget.currentCluster ??
            (_clusters.isNotEmpty ? _clusters.first : null);
      }
    } else {
      matchedCluster =
          _selectedCluster ??
          widget.currentCluster ??
          (_clusters.isNotEmpty ? _clusters.first : null);
      if (matchedCluster == null && _clusters.isNotEmpty) {
        needsPrompt = true;
        matchedCluster = _clusters.first;
      }
    }

    setState(() {
      _parsedRef = ref;
      _errorMessage = null;
      _requiresClusterSelection = needsPrompt;
      _selectedCluster = matchedCluster;
    });
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context);
    final text = _inputController.text.trim();
    final ref = MessageReference.tryParse(text);

    if (ref == null) {
      setState(() {
        _errorMessage =
            l10n?.quickJumpInvalid ?? 'Invalid reference URI format';
      });
      return;
    }

    if (_selectedCluster == null) {
      setState(() {
        _errorMessage = l10n?.noClusterSelected ?? 'No cluster selected';
      });
      return;
    }

    final cluster = _selectedCluster!;
    final topic = ref.topic;
    final partition = ref.partition;
    final offset = ref.offset;
    final filter = ref.filter;

    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();

    if (widget.onJump != null) {
      await widget.onJump!(cluster, topic, partition, offset, filter);
      return;
    }

    // Default navigation logic via ActiveConnectionController
    if (getIt.isRegistered<ActiveConnectionController>()) {
      final activeCtrl =
          widget.activeConnection ?? getIt<ActiveConnectionController>();
      if (activeCtrl.activeProfile?.name != cluster.name) {
        await activeCtrl.connect(cluster);
      }

      await openTopicByNameWithFeedback(
        controller: activeCtrl,
        profile: cluster,
        topicName: topic,
        messenger: messenger,
        l10n: l10n,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, minWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.bolt, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.quickJumpTitle ?? 'Quick Jump / Open Reference',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: l10n?.close ?? 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Input field
              TextField(
                key: const Key('quick_jump_input_field'),
                controller: _inputController,
                autofocus: true,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText:
                      l10n?.quickJumpHint ??
                      'Paste a kafkalyzer:// link (e.g. kafkalyzer://open?topic=...&offset=...)',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    fontFamily: 'sans-serif',
                    color: colorScheme.outline,
                  ),
                  prefixIcon: const Icon(Icons.link, size: 18),
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (val) => _onInputChanged(val, l10n),
                onSubmitted: (_) => _handleSubmit(),
              ),

              // Target Cluster Resolution / Dropdown
              if (_requiresClusterSelection && _parsedRef != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.quickJumpClusterNotFound(
                              _parsedRef?.cluster ?? '',
                            ) ??
                            "Cluster '${_parsedRef?.cluster}' not found in configuration. Select a cluster:",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButton<ClusterProfile>(
                        key: const Key('quick_jump_cluster_dropdown'),
                        isExpanded: true,
                        value: _selectedCluster,
                        items: [
                          for (final cluster in _clusters)
                            DropdownMenuItem(
                              value: cluster,
                              child: Text(cluster.name),
                            ),
                        ],
                        onChanged: (profile) {
                          if (profile != null) {
                            setState(() => _selectedCluster = profile);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Parsed Reference Preview
              if (_parsedRef != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            l10n?.quickJumpTopicLabel(_parsedRef!.topic) ??
                                'Topic: ${_parsedRef!.topic}',
                            if (_parsedRef!.partition != null)
                              l10n?.quickJumpPartitionLabel(
                                    _parsedRef!.partition!,
                                  ) ??
                                  'Partition: ${_parsedRef!.partition}',
                            if (_parsedRef!.offset != null)
                              l10n?.quickJumpOffsetLabel(_parsedRef!.offset!) ??
                                  'Offset: ${_parsedRef!.offset}',
                            if (_parsedRef!.filter != null)
                              l10n?.quickJumpFilterLabel(_parsedRef!.filter!) ??
                                  'Filter: ${_parsedRef!.filter}',
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('quick_jump_submit_button'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(l10n?.jump ?? 'Jump'),
                    onPressed: _parsedRef != null ? _handleSubmit : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
