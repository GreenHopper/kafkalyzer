import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import '../consumer_lag_view.dart'; // To import ConsumerGroupSortType

class ConsumerGroupControls extends StatelessWidget {
  final List<ClusterProfile> clusters;
  final ClusterProfile? activeProfile;
  final TextEditingController searchController;
  final String matchCountText;
  final String statusFilter;
  final ConsumerGroupSortType? sortType;
  final int refreshIntervalSeconds;
  final AppLocalizations l10n;
  final ValueChanged<ClusterProfile?> onClusterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<ConsumerGroupSortType> onSortTypeChanged;
  final ValueChanged<int> onRefreshIntervalChanged;

  const ConsumerGroupControls({
    super.key,
    required this.clusters,
    required this.activeProfile,
    required this.searchController,
    required this.matchCountText,
    required this.statusFilter,
    required this.sortType,
    required this.refreshIntervalSeconds,
    required this.l10n,
    required this.onClusterChanged,
    required this.onStatusFilterChanged,
    required this.onSortTypeChanged,
    required this.onRefreshIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (clusters.isNotEmpty)
          DropdownButton<ClusterProfile>(
            value: clusters.any((c) => c.name == activeProfile?.name)
                ? clusters.firstWhere((c) => c.name == activeProfile?.name)
                : null,
            hint: Text(l10n.pleaseSelectCluster),
            items: clusters.map((profile) {
              return DropdownMenuItem<ClusterProfile>(
                value: profile,
                child: Text(profile.name),
              );
            }).toList(),
            onChanged: onClusterChanged,
          ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: l10n.searchGroups,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: matchCountText,
            ),
          ),
        ),
        _buildStatusDropdown(context, isGerman),
        _buildSortDropdown(context, isGerman),
        _buildRefreshDropdown(context, isGerman),
      ],
    );
  }

  Widget _buildStatusDropdown(BuildContext context, bool isGerman) {
    return SizedBox(
      width: 130,
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

  Widget _buildSortDropdown(BuildContext context, bool isGerman) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<ConsumerGroupSortType>(
        key: ValueKey(sortType),
        initialValue: sortType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isGerman ? 'Sortieren nach' : 'Sort by',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(
            value: ConsumerGroupSortType.nameAsc,
            child: Text(isGerman ? 'Name (A-Z)' : 'Name (A-Z)'),
          ),
          DropdownMenuItem(
            value: ConsumerGroupSortType.nameDesc,
            child: Text(isGerman ? 'Name (Z-A)' : 'Name (Z-A)'),
          ),
          DropdownMenuItem(
            value: ConsumerGroupSortType.lagDesc,
            child: Text(isGerman ? 'Lag (absteigend)' : 'Lag (Descending)'),
          ),
          DropdownMenuItem(
            value: ConsumerGroupSortType.lagAsc,
            child: Text(isGerman ? 'Lag (aufsteigend)' : 'Lag (Ascending)'),
          ),
        ],
        onChanged: (val) {
          if (val != null) {
            onSortTypeChanged(val);
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
