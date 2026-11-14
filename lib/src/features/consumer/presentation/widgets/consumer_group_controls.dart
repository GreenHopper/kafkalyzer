import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

// To import ConsumerGroupSortType

class ConsumerGroupControls extends StatelessWidget {
  final ClusterProfile? activeProfile;
  final TextEditingController searchController;
  final String statusFilter;
  final int refreshIntervalSeconds;
  final AppLocalizations l10n;
  final ValueChanged<ClusterProfile?> onClusterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<int> onRefreshIntervalChanged;

  const ConsumerGroupControls({
    super.key,
    required this.activeProfile,
    required this.searchController,
    required this.statusFilter,
    required this.refreshIntervalSeconds,
    required this.l10n,
    required this.onClusterChanged,
    required this.onStatusFilterChanged,
    required this.onRefreshIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: ClusterDropdown(
                value: activeProfile,
                labelText: l10n.cluster,
                onChanged: onClusterChanged,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: l10n.searchGroups,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildStatusDropdown(context),
            const SizedBox(width: 16),
            _buildRefreshDropdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: statusFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.stateCol,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: 'All', child: Text(l10n.stateAll)),
          DropdownMenuItem(value: 'Stable', child: Text(l10n.stateStable)),
          DropdownMenuItem(value: 'Empty', child: Text(l10n.stateEmpty)),
          DropdownMenuItem(value: 'Dead', child: Text(l10n.stateDead)),
        ],
        onChanged: (val) {
          if (val != null) {
            onStatusFilterChanged(val);
          }
        },
      ),
    );
  }

  Widget _buildRefreshDropdown(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int>(
        initialValue: refreshIntervalSeconds,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.refreshIntervalLabel,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: 0, child: Text(l10n.refreshOff)),
          const DropdownMenuItem(value: 5, child: Text('5s')),
          const DropdownMenuItem(value: 15, child: Text('15s')),
          const DropdownMenuItem(value: 30, child: Text('30s')),
          const DropdownMenuItem(value: 60, child: Text('60s')),
        ],
        onChanged: activeProfile == null
            ? null
            : (val) {
                if (val != null) {
                  onRefreshIntervalChanged(val);
                }
              },
      ),
    );
  }
}
