import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

typedef TopicConfigCompareSelection = (ClusterProfile profile, String topic);

Future<TopicConfigCompareSelection?> showTopicConfigCompareDialog({
  required BuildContext context,
  required ClusterProfile currentProfile,
  required String openTopicName,
  List<ClusterProfile>? clusters,
  List<String> Function(ClusterProfile profile)? cachedTopicsLookup,
}) {
  return showDialog<TopicConfigCompareSelection>(
    context: context,
    builder: (context) => TopicConfigCompareDialog(
      currentProfile: currentProfile,
      openTopicName: openTopicName,
      clusters: clusters,
      cachedTopicsLookup: cachedTopicsLookup,
    ),
  );
}

class TopicConfigCompareDialog extends StatefulWidget {
  final ClusterProfile currentProfile;
  final String openTopicName;
  final List<ClusterProfile>? clusters;
  final List<String> Function(ClusterProfile profile)? cachedTopicsLookup;

  /// Session-wide collaborators; null falls back to the application container.
  final ClusterListController? clusterController;
  final TopicController? topicController;

  const TopicConfigCompareDialog({
    super.key,
    required this.currentProfile,
    required this.openTopicName,
    this.clusters,
    this.cachedTopicsLookup,
    this.clusterController,
    this.topicController,
  });

  @override
  State<TopicConfigCompareDialog> createState() =>
      _TopicConfigCompareDialogState();
}

class _TopicConfigCompareDialogState extends State<TopicConfigCompareDialog> {
  late final List<ClusterProfile> _profiles;
  late ClusterProfile _selectedProfile;
  late String _topicName;

  @override
  void initState() {
    super.initState();
    _profiles = _orderedProfiles();
    _selectedProfile = _profiles.first;
    _topicName = widget.openTopicName;
  }

  List<ClusterProfile> _orderedProfiles() {
    final clusterController =
        widget.clusterController ??
        (getIt.isRegistered<ClusterListController>()
            ? getIt<ClusterListController>()
            : null);
    final source =
        widget.clusters ?? clusterController?.clusters ?? <ClusterProfile>[];
    final current = widget.currentProfile;
    final others = source.where((p) => p.name != current.name).toList();
    final matchedCurrent = source
        .where((p) => p.name == current.name)
        .firstOrNull;
    return [matchedCurrent ?? current, ...others];
  }

  List<String> _cachedTopicsFor(ClusterProfile profile) {
    if (widget.cachedTopicsLookup != null) {
      return widget.cachedTopicsLookup!(profile);
    }
    final topicController =
        widget.topicController ??
        (getIt.isRegistered<TopicController>()
            ? getIt<TopicController>()
            : null);
    if (topicController == null) {
      return const [];
    }
    final topics = topicController.getTopics(profile);
    if (topics == null) {
      return const [];
    }
    return topics.map((t) => t.name).toList(growable: false);
  }

  void _submit() {
    final trimmed = _topicName.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Navigator.of(context).pop((_selectedProfile, trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.topicConfigCompareDialogTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownMenu<ClusterProfile>(
              expandedInsets: EdgeInsets.zero,
              initialSelection: _selectedProfile,
              label: Text(l10n.topicConfigCompareProfileLabel),
              onSelected: (profile) {
                if (profile != null) {
                  setState(() {
                    _selectedProfile = profile;
                  });
                }
              },
              dropdownMenuEntries: _profiles
                  .map(
                    (profile) => DropdownMenuEntry<ClusterProfile>(
                      value: profile,
                      label: profile.name,
                      labelWidget: _ProfileMenuItemLabel(profile: profile),
                    ),
                  )
                  .toList(growable: false),
            ),
            if ((_selectedProfile.environmentLabel != null &&
                    _selectedProfile.environmentLabel!.trim().isNotEmpty) ||
                _selectedProfile.tlsVerification ==
                    TlsVerification.disabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_selectedProfile.environmentLabel != null &&
                      _selectedProfile.environmentLabel!.trim().isNotEmpty)
                    EnvironmentTagChip(
                      profile: _selectedProfile,
                      compact: true,
                    ),
                  if (_selectedProfile.tlsVerification ==
                      TlsVerification.disabled)
                    const InsecureTlsBadge(compact: true),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.openTopicName),
              optionsBuilder: (textEditingValue) {
                final cached = _cachedTopicsFor(_selectedProfile);
                if (cached.isEmpty) {
                  return const Iterable<String>.empty();
                }
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) {
                  return cached;
                }
                return cached.where(
                  (name) => name.toLowerCase().contains(query),
                );
              },
              onSelected: (selection) {
                setState(() {
                  _topicName = selection;
                });
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: l10n.topicConfigCompareTopicLabel,
                        hintText: l10n.topicConfigCompareTopicHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _topicName = value;
                        });
                      },
                      onSubmitted: (_) {
                        onFieldSubmitted();
                        _submit();
                      },
                    );
                  },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _topicName.trim().isEmpty ? null : _submit,
          child: Text(l10n.topicConfigCompareSubmit),
        ),
      ],
    );
  }
}

class _ProfileMenuItemLabel extends StatelessWidget {
  final ClusterProfile profile;

  const _ProfileMenuItemLabel({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
        if (profile.environmentLabel != null &&
            profile.environmentLabel!.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          EnvironmentTagChip(profile: profile, compact: true),
        ],
        if (profile.tlsVerification == TlsVerification.disabled) ...[
          const SizedBox(width: 6),
          const InsecureTlsBadge(compact: true),
        ],
      ],
    );
  }
}
