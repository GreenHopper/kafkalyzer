import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:watch_it/watch_it.dart';

enum ConsumerGroupSortType {
  nameAsc,
  nameDesc,
  lagAsc,
  lagDesc,
  stateAsc,
  stateDesc,
  protocolAsc,
  protocolDesc,
  consumersAsc,
  consumersDesc,
  topicsAsc,
  topicsDesc,
}

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
  int _refreshIntervalSeconds = 0;
  Timer? _refreshTimer;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  String _statusFilter = "All";
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

  ConsumerGroupSortType? get _sortType {
    if (_sortColumnIndex == 0) {
      return _sortAscending
          ? ConsumerGroupSortType.nameAsc
          : ConsumerGroupSortType.nameDesc;
    } else if (_sortColumnIndex == 5) {
      return _sortAscending
          ? ConsumerGroupSortType.lagAsc
          : ConsumerGroupSortType.lagDesc;
    }
    return null;
  }

  set _sortType(ConsumerGroupSortType val) {
    switch (val) {
      case ConsumerGroupSortType.nameAsc:
        _sortColumnIndex = 0;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.nameDesc:
        _sortColumnIndex = 0;
        _sortAscending = false;
        break;
      case ConsumerGroupSortType.stateAsc:
        _sortColumnIndex = 1;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.stateDesc:
        _sortColumnIndex = 1;
        _sortAscending = false;
        break;
      case ConsumerGroupSortType.protocolAsc:
        _sortColumnIndex = 2;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.protocolDesc:
        _sortColumnIndex = 2;
        _sortAscending = false;
        break;
      case ConsumerGroupSortType.consumersAsc:
        _sortColumnIndex = 3;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.consumersDesc:
        _sortColumnIndex = 3;
        _sortAscending = false;
        break;
      case ConsumerGroupSortType.topicsAsc:
        _sortColumnIndex = 4;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.topicsDesc:
        _sortColumnIndex = 4;
        _sortAscending = false;
        break;
      case ConsumerGroupSortType.lagAsc:
        _sortColumnIndex = 5;
        _sortAscending = true;
        break;
      case ConsumerGroupSortType.lagDesc:
        _sortColumnIndex = 5;
        _sortAscending = false;
        break;
    }
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

  void _updateRefreshInterval(int seconds, ClusterProfile? profile) {
    setState(() {
      _refreshIntervalSeconds = seconds;
    });
    _refreshTimer?.cancel();
    if (seconds > 0 && profile != null) {
      _refreshTimer = Timer.periodic(Duration(seconds: seconds), (timer) {
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

    if (activeProfile != _lastProfile) {
      _lastProfile = activeProfile;
      if (activeProfile != null) {
        scheduleMicrotask(() => _fetchLags(activeProfile));
        if (_refreshIntervalSeconds > 0) {
          _updateRefreshInterval(_refreshIntervalSeconds, activeProfile);
        }
      } else {
        _lags = [];
        _errorMessage = null;
        _refreshTimer?.cancel();
      }
    }

    final filteredLags = _lags.where((group) {
      final matchesSearch = group.groupId.toLowerCase().contains(
        _filterText.toLowerCase(),
      );
      final matchesStatus =
          _statusFilter == 'All' ||
          group.state.toLowerCase() == _statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    filteredLags.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.groupId.toLowerCase().compareTo(b.groupId.toLowerCase());
          break;
        case 1:
          cmp = a.state.toLowerCase().compareTo(b.state.toLowerCase());
          break;
        case 2:
          cmp = a.protocolType.toLowerCase().compareTo(
            b.protocolType.toLowerCase(),
          );
          break;
        case 3:
          cmp = a.membersCount.compareTo(b.membersCount);
          break;
        case 4:
          cmp = a.topicsCount.compareTo(b.topicsCount);
          break;
        case 5:
        default:
          cmp = _calculateGroupLag(a).compareTo(_calculateGroupLag(b));
          break;
      }
      return _sortAscending ? cmp : -cmp;
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
              filteredLags.length,
              _lags.length,
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

  Widget _buildStatusDropdown(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<String>(
        value: _statusFilter,
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
            setState(() {
              _statusFilter = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildRefreshDropdown(
    BuildContext context,
    ClusterProfile? activeProfile,
  ) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int>(
        value: _refreshIntervalSeconds,
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
                  _updateRefreshInterval(val, activeProfile);
                }
              },
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    AppLocalizations l10n,
    ClusterProfile? activeProfile,
    List<ClusterProfile> clusters,
    ActiveConnectionController activeController,
    int matchedCount,
    int totalCount,
  ) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final matchCountText = isGerman
        ? "$matchedCount von $totalCount Gruppen gefunden"
        : "Found $matchedCount of $totalCount groups";

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
            onChanged: (profile) {
              if (profile != null) {
                activeController.connect(profile);
              }
            },
          ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchGroups,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: matchCountText,
            ),
          ),
        ),
        _buildStatusDropdown(context),
        _buildSortDropdown(context),
        _buildRefreshDropdown(context, activeProfile),
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

  Widget _buildHeaderCell(int index, String title, {required int flex}) {
    final isSelected = _sortColumnIndex == index;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumnIndex == index) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = index;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 24, right: 64, top: 12, bottom: 12),
      child: Row(
        children: [
          _buildHeaderCell(0, isGerman ? 'Gruppen-ID' : 'Group ID', flex: 3),
          _buildHeaderCell(1, isGerman ? 'Status' : 'State', flex: 2),
          _buildHeaderCell(2, isGerman ? 'Protokoll' : 'Protocol', flex: 2),
          _buildHeaderCell(3, isGerman ? 'Consumers' : 'Consumers', flex: 2),
          _buildHeaderCell(4, isGerman ? 'Topics' : 'Topics', flex: 2),
          _buildHeaderCell(5, isGerman ? 'Gesamtes Lag' : 'Total Lag', flex: 2),
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

    return Column(
      children: [
        _buildTableHeader(context),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: groups.length,
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
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.only(left: 24, right: 24),
                  title: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          group.groupId,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          group.protocolType,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(group.membersCount.toString()),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(group.topicsCount.toString()),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTrailingLagWidget(context, l10n, group),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    _GroupDetailsView(group: group, l10n: l10n),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GroupDetailsView extends StatefulWidget {
  final ConsumerGroupLag group;
  final AppLocalizations l10n;

  const _GroupDetailsView({required this.group, required this.l10n});

  @override
  State<_GroupDetailsView> createState() => _GroupDetailsViewState();
}

class _GroupDetailsViewState extends State<_GroupDetailsView> {
  bool _sortTopicsAscending = true;
  bool _sortByLag = false;

  int _calculateTopicLag(List<TopicPartitionLag> partitionLags) {
    return partitionLags.fold(0, (sum, item) => sum + item.lag.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<TopicPartitionLag>> topicGroups = {};
    for (final part in widget.group.partitionLags) {
      topicGroups.putIfAbsent(part.topic, () => []).add(part);
    }

    final topicsList = topicGroups.keys.toList();

    topicsList.sort((a, b) {
      int cmp;
      if (_sortByLag) {
        final lagA = _calculateTopicLag(topicGroups[a]!);
        final lagB = _calculateTopicLag(topicGroups[b]!);
        cmp = lagA.compareTo(lagB);
      } else {
        cmp = a.toLowerCase().compareTo(b.toLowerCase());
      }
      return _sortTopicsAscending ? cmp : -cmp;
    });

    final isGerman = Localizations.localeOf(context).languageCode == 'de';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isGerman ? "Topics sortieren nach:" : "Sort topics by:",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (!_sortByLag) {
                      _sortTopicsAscending = !_sortTopicsAscending;
                    } else {
                      _sortByLag = false;
                      _sortTopicsAscending = true;
                    }
                  });
                },
                icon: Icon(
                  !_sortByLag && _sortTopicsAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: Text(
                  isGerman ? "Name" : "Name",
                  style: TextStyle(
                    fontWeight: !_sortByLag
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_sortByLag) {
                      _sortTopicsAscending = !_sortTopicsAscending;
                    } else {
                      _sortByLag = true;
                      _sortTopicsAscending = true;
                    }
                  });
                },
                icon: Icon(
                  _sortByLag && _sortTopicsAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: Text(
                  isGerman ? "Lag" : "Lag",
                  style: TextStyle(
                    fontWeight: _sortByLag
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (topicsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  isGerman
                      ? "Keine aktiven Partitionen gefunden."
                      : "No active partition assignments.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ...topicsList.map((topic) {
            final parts = topicGroups[topic]!;
            final totalLag = _calculateTopicLag(parts);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ExpansionTile(
                title: Text(
                  topic,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: totalLag > 0
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${widget.l10n.lagCol}: $totalLag",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: totalLag > 0
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                children: [
                  TopicPartitionTable(partitionLags: parts, l10n: widget.l10n),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TopicPartitionTable extends StatefulWidget {
  final List<TopicPartitionLag> partitionLags;
  final AppLocalizations l10n;

  const TopicPartitionTable({
    super.key,
    required this.partitionLags,
    required this.l10n,
  });

  @override
  State<TopicPartitionTable> createState() => _TopicPartitionTableState();
}

class _TopicPartitionTableState extends State<TopicPartitionTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  Widget _buildHeaderCell(int index, String title, {required int flex}) {
    final isSelected = _sortColumnIndex == index;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumnIndex == index) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = index;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    Color? textColor,
    bool isBold = false,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedParts = List<TopicPartitionLag>.from(widget.partitionLags);
    sortedParts.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.partition.compareTo(b.partition);
          break;
        case 1:
          cmp = a.logEndOffset.compareTo(b.logEndOffset);
          break;
        case 2:
          cmp = a.currentOffset.compareTo(b.currentOffset);
          break;
        case 3:
        default:
          cmp = a.lag.compareTo(b.lag);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(0, widget.l10n.partitionCol, flex: 2),
                _buildHeaderCell(1, widget.l10n.logEndOffsetCol, flex: 3),
                _buildHeaderCell(2, widget.l10n.committedOffsetCol, flex: 3),
                _buildHeaderCell(3, widget.l10n.lagCol, flex: 2),
              ],
            ),
          ),
          ...sortedParts.map((part) {
            final lagVal = part.lag.toInt();
            final isHighLag = lagVal > 0;
            final committedStr = part.currentOffset.toInt() == -1
                ? "-"
                : part.currentOffset.toString();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildTableCell(part.partition.toString(), flex: 2),
                  _buildTableCell(part.logEndOffset.toString(), flex: 3),
                  _buildTableCell(committedStr, flex: 3),
                  _buildTableCell(
                    lagVal.toString(),
                    flex: 2,
                    textColor: isHighLag
                        ? Theme.of(context).colorScheme.error
                        : null,
                    isBold: isHighLag,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
