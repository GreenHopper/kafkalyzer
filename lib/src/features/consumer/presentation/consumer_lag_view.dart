import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:watch_it/watch_it.dart';

enum ConsumerGroupSortType { nameAsc, nameDesc, lagAsc, lagDesc }

class ConsumerLagView extends WatchingStatefulWidget {
  const ConsumerLagView({super.key});

  @override
  State<ConsumerLagView> createState() => _ConsumerLagViewState();
}

class _ConsumerLagViewState extends State<ConsumerLagView> {
  final TextEditingController _searchController = TextEditingController();
  ClusterProfile? _lastProfile;
  List<ConsumerGroupLag> _lags = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _filterText = "";
  bool _autoRefresh = false;
  Timer? _refreshTimer;
  ConsumerGroupSortType _sortType = ConsumerGroupSortType.nameAsc;
  Duration? _lastFetchDuration;
  final Set<String> _loadingGroupIds = {};
  final Set<String> _loadedGroupIds = {};
  final Set<String> _failedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filterText = _searchController.text;
    });
  }

  Future<void> _fetchLags(ClusterProfile profile) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastFetchDuration = null;
      _loadingGroupIds.clear();
      _loadedGroupIds.clear();
      _failedGroupIds.clear();
    });

    final stopwatch = Stopwatch()..start();
    try {
      final lags = await getIt<KafkaMetadataService>().fetchConsumerGroups(
        profile: profile,
      );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _lags = lags;
        _lastFetchDuration = stopwatch.elapsed;
        _isLoading = false;
      });
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGroupLag(String groupId) async {
    if (!mounted) return;
    final activeController = getIt<ActiveConnectionController>();
    final activeProfile = activeController.activeProfile;
    if (activeProfile == null) return;

    if (_loadingGroupIds.contains(groupId) ||
        _loadedGroupIds.contains(groupId) ||
        _failedGroupIds.contains(groupId)) {
      return;
    }

    setState(() {
      _loadingGroupIds.add(groupId);
    });

    try {
      final updatedGroup = await getIt<KafkaMetadataService>()
          .fetchConsumerGroupLag(profile: activeProfile, groupId: groupId);
      if (!mounted) return;
      setState(() {
        final idx = _lags.indexWhere((g) => g.groupId == groupId);
        if (idx != -1) {
          _lags[idx] = updatedGroup;
        }
        _loadingGroupIds.remove(groupId);
        _loadedGroupIds.add(groupId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGroupIds.remove(groupId);
        _failedGroupIds.add(groupId);
      });
    }
  }

  Widget _buildTrailingLagWidget(
    BuildContext context,
    AppLocalizations l10n,
    ConsumerGroupLag group,
  ) {
    final isLoaded = _loadedGroupIds.contains(group.groupId);
    final isLoading = _loadingGroupIds.contains(group.groupId);
    final isFailed = _failedGroupIds.contains(group.groupId);

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Error",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    if (!isLoaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "${l10n.lagCol}: -",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    final totalLag = _calculateGroupLag(group);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: totalLag > 0
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "${l10n.lagCol}: $totalLag",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: totalLag > 0
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  void _toggleAutoRefresh(bool enabled, ClusterProfile? profile) {
    setState(() {
      _autoRefresh = enabled;
    });
    _refreshTimer?.cancel();
    if (enabled && profile != null) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _fetchLags(profile);
      });
    }
  }

  int _calculateGroupLag(ConsumerGroupLag group) {
    return group.partitionLags.fold(0, (sum, item) => sum + item.lag.toInt());
  }

  Color _getStateColor(String state) {
    final s = state.toLowerCase();
    if (s.contains('stable') || s.contains('active')) {
      return Colors.green;
    } else if (s.contains('empty')) {
      return Colors.grey;
    } else if (s.contains('dead') || s.contains('error')) {
      return Colors.red;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusterController = watchIt<ClusterListController>();
    final activeController = watchIt<ActiveConnectionController>();
    final activeProfile = activeController.activeProfile;
    final clusters = clusterController.clusters;

    // Check if active profile changed and trigger fetch/refresh reset
    if (activeProfile != _lastProfile) {
      _lastProfile = activeProfile;
      if (activeProfile != null) {
        scheduleMicrotask(() => _fetchLags(activeProfile));
        if (_autoRefresh) {
          _toggleAutoRefresh(true, activeProfile);
        }
      } else {
        _lags = [];
        _errorMessage = null;
        _refreshTimer?.cancel();
      }
    }

    final filteredLags = _lags.where((group) {
      return group.groupId.toLowerCase().contains(_filterText.toLowerCase());
    }).toList();

    filteredLags.sort((a, b) {
      switch (_sortType) {
        case ConsumerGroupSortType.nameAsc:
          return a.groupId.toLowerCase().compareTo(b.groupId.toLowerCase());
        case ConsumerGroupSortType.nameDesc:
          return b.groupId.toLowerCase().compareTo(a.groupId.toLowerCase());
        case ConsumerGroupSortType.lagAsc:
          return _calculateGroupLag(a).compareTo(_calculateGroupLag(b));
        case ConsumerGroupSortType.lagDesc:
          return _calculateGroupLag(b).compareTo(_calculateGroupLag(a));
      }
    });

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, l10n, activeProfile),
            const SizedBox(height: 24),
            _buildControls(
              context,
              l10n,
              activeProfile,
              clusters,
              activeController,
            ),
            const SizedBox(height: 16),
            if (!_isLoading &&
                _errorMessage == null &&
                _lags.isNotEmpty &&
                _lastFetchDuration != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildFetchStatusMessage(context),
              ),
            if (_isLoading && _lags.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: LinearProgressIndicator(),
              ),
            if (_errorMessage != null && activeProfile != null)
              _buildErrorBanner(context, activeProfile),
            Expanded(
              child: activeProfile == null
                  ? _buildNoClusterSelected(context, l10n)
                  : (_isLoading && _lags.isEmpty
                        ? _buildLoadingState(context)
                        : _buildGroupList(context, l10n, filteredLags)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final loadingText = isGerman
        ? "Verbindung zum Cluster wird hergestellt "
              "und Offsets werden berechnet..."
        : "Establishing connection and calculating consumer group offsets...";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            loadingText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClusterSelected(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pleaseSelectCluster,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<ConsumerGroupSortType>(
        value: _sortType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isGerman ? 'Sortieren nach' : 'Sort by',
          prefixIcon: const Icon(Icons.sort),
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
            setState(() {
              _sortType = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildFetchStatusMessage(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final seconds = (_lastFetchDuration!.inMilliseconds / 1000.0)
        .toStringAsFixed(1);
    final count = _lags.length;
    final message = isGerman
        ? 'Erfolgreich $count Consumer-Gruppen in ${seconds}s geladen.'
        : 'Successfully loaded $count consumer groups in ${seconds}s.';

    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ClusterProfile? profile,
  ) {
    return Row(
      children: [
        Text(
          l10n.consumerLag,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (profile != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    AppLocalizations l10n,
    ClusterProfile? activeProfile,
    List<ClusterProfile> clusters,
    ActiveConnectionController activeController,
  ) {
    return Row(
      children: [
        if (clusters.isNotEmpty) ...[
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
            onChanged: (profile) {
              if (profile != null) {
                activeController.connect(profile);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchGroups,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildSortDropdown(context),
        const SizedBox(width: 16),
        Row(
          children: [
            Text(
              l10n.autoRefresh,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            Switch(
              value: _autoRefresh,
              onChanged: activeProfile == null
                  ? null
                  : (val) => _toggleAutoRefresh(val, activeProfile),
            ),
          ],
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: (activeProfile == null || _isLoading)
              ? null
              : () => _fetchLags(activeProfile),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(l10n.apply),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, ClusterProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _errorMessage ?? "",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Theme.of(context).colorScheme.onErrorContainer,
            onPressed: () => _fetchLags(profile),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    AppLocalizations l10n,
    List<ConsumerGroupLag> groups,
  ) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_work_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noConsumerGroupsFound,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        final group = groups[index];
        final isLoaded = _loadedGroupIds.contains(group.groupId);
        final isLoading = _loadingGroupIds.contains(group.groupId);
        final isFailed = _failedGroupIds.contains(group.groupId);

        if (!isLoaded && !isLoading && !isFailed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadGroupLag(group.groupId);
          });
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text(
              group.groupId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStateColor(
                        group.state,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.state,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStateColor(group.state),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Protocol: ${group.protocolType}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            trailing: _buildTrailingLagWidget(context, l10n, group),
            children: [
              const Divider(height: 1),
              _buildPartitionTable(context, l10n, group),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartitionTable(
    BuildContext context,
    AppLocalizations l10n,
    ConsumerGroupLag group,
  ) {
    final isLoaded = _loadedGroupIds.contains(group.groupId);
    final isLoading = _loadingGroupIds.contains(group.groupId);
    final isFailed = _failedGroupIds.contains(group.groupId);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (isFailed) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            "Failed to load partition offsets.",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (!isLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("Pending lag resolution...")),
      );
    }

    final partitionLags = group.partitionLags;
    if (partitionLags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            "No active partition assignments.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: MediaQuery.of(context).size.width - 100,
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3), // Topic
            1: FlexColumnWidth(1), // Partition
            2: FlexColumnWidth(2), // Log End Offset
            3: FlexColumnWidth(2), // Committed Offset
            4: FlexColumnWidth(1.5), // Lag
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
              children: [
                _buildTableCell(l10n.topicCol, isHeader: true),
                _buildTableCell(l10n.partitionCol, isHeader: true),
                _buildTableCell(l10n.logEndOffsetCol, isHeader: true),
                _buildTableCell(l10n.committedOffsetCol, isHeader: true),
                _buildTableCell(l10n.lagCol, isHeader: true),
              ],
            ),
            ...partitionLags.map((part) {
              final lagVal = part.lag.toInt();
              final isHighLag = lagVal > 0;
              final commitedStr = part.currentOffset.toInt() == -1
                  ? "-"
                  : part.currentOffset.toString();

              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                children: [
                  _buildTableCell(part.topic),
                  _buildTableCell(part.partition.toString()),
                  _buildTableCell(part.logEndOffset.toString()),
                  _buildTableCell(commitedStr),
                  _buildTableCell(
                    lagVal.toString(),
                    textColor: isHighLag
                        ? Theme.of(context).colorScheme.error
                        : null,
                    isBold: isHighLag,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    Color? textColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader
              ? FontWeight.bold
              : (isBold ? FontWeight.bold : FontWeight.normal),
          color:
              textColor ??
              (isHeader ? Theme.of(context).colorScheme.onSurface : null),
          fontSize: isHeader ? 12 : 13,
        ),
      ),
    );
  }
}
