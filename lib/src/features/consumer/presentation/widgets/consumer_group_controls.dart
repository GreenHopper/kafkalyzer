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
    final isGerman = Localizations.localeOf(context).languageCode == 'de';

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
            _buildStatusDropdown(context, isGerman),
            const SizedBox(width: 16),
            _buildRefreshDropdown(context, isGerman),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, bool isGerman) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: statusFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isGerman ? 'Status' : 'State',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(
            value: 'All',
            child: Text(isGerman ? 'Alle' : 'All'),
          ),
          DropdownMenuItem(
            value: 'Stable',
            child: Text(isGerman ? 'Stable' : 'Stable'),
          ),
          DropdownMenuItem(
            value: 'Empty',
            child: Text(isGerman ? 'Empty' : 'Empty'),
          ),
          DropdownMenuItem(
            value: 'Dead',
            child: Text(isGerman ? 'Dead' : 'Dead'),
          ),
        ],
        onChanged: (val) {
          if (val != null) {
            onStatusFilterChanged(val);
          }
        },
      ),
    );
  }

  Widget _buildRefreshDropdown(BuildContext context, bool isGerman) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int>(
        initialValue: refreshIntervalSeconds,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isGerman ? 'Intervall' : 'Refresh',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: 0, child: Text(isGerman ? 'Aus' : 'Off')),
          DropdownMenuItem(value: 5, child: Text(isGerman ? '5s' : '5s')),
          DropdownMenuItem(value: 15, child: Text(isGerman ? '15s' : '15s')),
          DropdownMenuItem(value: 30, child: Text(isGerman ? '30s' : '30s')),
          DropdownMenuItem(value: 60, child: Text(isGerman ? '60s' : '60s')),
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
