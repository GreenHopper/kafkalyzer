import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_it/watch_it.dart';
import 'group_details_view.dart';
import 'widgets/group_lag_badge.dart';
import 'widgets/group_delta_badge.dart';
import 'widgets/consumer_group_controls.dart';
import 'widgets/kpi_card.dart';

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
  processedAsc,
  processedDesc,
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
  int _refreshIntervalSeconds = 30;
  Timer? _refreshTimer;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  String _statusFilter = "All";
  Duration? _lastFetchDuration;
  final Set<String> _loadingGroupIds = {};
  final Set<String> _loadedGroupIds = {};
  final Set<String> _failedGroupIds = {};
  final Map<String, List<TopicPartitionLag>> _cachedPartitionLags = {};
  int _activeLagQueries = 0;
  final List<String> _lagQueryQueue = [];
  int _maxConcurrentLagQueries = 5;

  // Track previous partition lags for calculating deltas: groupId -> (topic-partition -> lag)
  final Map<String, Map<String, int>> _previousLags = {};
  // Track computed group-level delta: groupId -> delta value
  final Map<String, int> _groupDeltas = {};
  // Track computed partition-level deltas: groupId -> (topic-partition -> delta)
  final Map<String, Map<String, int>> _partitionDeltas = {};

  String _formatNum(num value) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.decimalPattern(locale).format(value);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadConcurrencyLimit();
  }

  Future<void> _loadConcurrencyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final limit = prefs.getInt('consumer_max_concurrent_queries') ?? 5;
    if (mounted) {
      setState(() {
        _maxConcurrentLagQueries = limit;
      });
    }
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
      _lagQueryQueue.clear();
    });
  }

  Future<void> _fetchLags(ClusterProfile profile) async {
    if (!mounted) return;
    _loadConcurrencyLimit();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingGroupIds.clear();
      _loadedGroupIds.clear();
      _failedGroupIds.clear();
      _lagQueryQueue.clear();
      _partitionDeltas.clear();
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

  int? _calculateLagDelta(String groupId, List<TopicPartitionLag> newLags) {
    final oldLagsMap = _previousLags[groupId];
    if (oldLagsMap == null) {
      return null;
    }
    int totalDelta = 0;
    for (final lag in newLags) {
      final key = "${lag.topic}-${lag.partition}";
      final oldLag = oldLagsMap[key];
      if (oldLag != null) {
        totalDelta += (lag.lag.toInt() - oldLag);
      }
    }
    return totalDelta;
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

    if (_activeLagQueries >= _maxConcurrentLagQueries) {
      if (!_lagQueryQueue.contains(groupId)) {
        _lagQueryQueue.add(groupId);
      }
      return;
    }

    _activeLagQueries++;
    setState(() {
      _loadingGroupIds.add(groupId);
    });

    try {
      final updatedGroup = await getIt<KafkaMetadataService>()
          .fetchConsumerGroupLag(profile: activeProfile, groupId: groupId);
      if (!mounted) return;
      if (activeController.activeProfile != activeProfile) return;
      setState(() {
        final idx = _lags.indexWhere((g) => g.groupId == groupId);

        final delta = _calculateLagDelta(groupId, updatedGroup.partitionLags);
        if (delta != null) {
          _groupDeltas[groupId] = delta;
        }

        final oldLags = _previousLags[groupId];
        final groupPartitionDeltas = <String, int>{};
        for (final lag in updatedGroup.partitionLags) {
          final key = "${lag.topic}-${lag.partition}";
          final oldLag = oldLags?[key];
          if (oldLag != null) {
            groupPartitionDeltas[key] = lag.lag.toInt() - oldLag;
          }
        }
        if (oldLags != null) {
          _partitionDeltas[groupId] = groupPartitionDeltas;
        }

        final newLagsMap = <String, int>{};
        for (final lag in updatedGroup.partitionLags) {
          newLagsMap["${lag.topic}-${lag.partition}"] = lag.lag.toInt();
        }
        _previousLags[groupId] = newLagsMap;

        if (idx != -1) {
          _lags[idx] = updatedGroup;
        }
        _cachedPartitionLags[groupId] = updatedGroup.partitionLags;
        _loadingGroupIds.remove(groupId);
        _loadedGroupIds.add(groupId);
      });
    } catch (e) {
      if (!mounted) return;
      if (activeController.activeProfile != activeProfile) return;
      setState(() {
        _loadingGroupIds.remove(groupId);
        _failedGroupIds.add(groupId);
      });
    } finally {
      _activeLagQueries = (_activeLagQueries - 1).clamp(0, 999);
      _processNextLagQuery();
    }
  }

  void _processNextLagQuery() {
    if (!mounted) return;
    if (_lagQueryQueue.isNotEmpty &&
        _activeLagQueries < _maxConcurrentLagQueries) {
      final nextGroupId = _lagQueryQueue.removeAt(0);
      _loadGroupLag(nextGroupId);
    }
  }

  void _updateRefreshInterval(int seconds, ClusterProfile? profile) {
    setState(() {
      _refreshIntervalSeconds = seconds;
    });
    _refreshTimer?.cancel();
    if (profile != null) {
      _fetchLags(profile);
      if (seconds > 0) {
        _refreshTimer = Timer.periodic(Duration(seconds: seconds), (timer) {
          _fetchLags(profile);
        });
      }
    }
  }

  int _calculateGroupLag(ConsumerGroupLag group) {
    final lags = group.partitionLags.isNotEmpty
        ? group.partitionLags
        : (_cachedPartitionLags[group.groupId] ?? const []);
    return lags.fold(0, (sum, item) => sum + item.lag.toInt());
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

  Widget _buildKpiCards(
    BuildContext context,
    AppLocalizations l10n,
    List<ConsumerGroupLag> filteredLags,
  ) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final totalGroups = _lags.length;
    final filteredCount = filteredLags.length;
    final stableGroups = filteredLags.where((g) {
      final s = g.state.toLowerCase();
      return s.contains('stable') || s.contains('active');
    }).length;
    final totalLag = filteredLags.fold(0, (sum, group) => sum + _calculateGroupLag(group));
    final activeQueries = _activeLagQueries;
    final queuedQueries = _lagQueryQueue.length;

    final totalDelta = filteredLags.fold<int>(
      0,
      (sum, group) => sum + (_groupDeltas[group.groupId] ?? 0),
    );
    final String? lagSubtitle;
    if (_groupDeltas.isNotEmpty) {
      final formattedDelta = totalDelta > 0
          ? "+${_formatNum(totalDelta)}"
          : _formatNum(totalDelta);
      lagSubtitle = isGerman
          ? 'Änderung: $formattedDelta'
          : 'Change: $formattedDelta';
    } else {
      lagSubtitle = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth = (constraints.maxWidth - 48) / 4;
          return IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    title: isGerman ? 'Consumer-Gruppen' : 'Consumer Groups',
                    value: _formatNum(filteredCount),
                    subtitle: filteredCount < totalGroups
                        ? (isGerman
                              ? 'von ${_formatNum(totalGroups)}'
                              : 'of ${_formatNum(totalGroups)}')
                        : null,
                    icon: Icons.group_work,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    title: isGerman ? 'Aktiv / Stabil' : 'Active / Stable',
                    value: _formatNum(stableGroups),
                    subtitle: isGerman
                        ? '${_formatNum(filteredCount - stableGroups)} Inaktiv/Leer'
                        : '${_formatNum(filteredCount - stableGroups)} Idle/Empty',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    title: isGerman ? 'Gesamtes Lag' : 'Total Lag',
                    value: _formatNum(totalLag),
                    subtitle: lagSubtitle,
                    icon: Icons.warning_amber_outlined,
                    iconColor: totalLag > 0 ? Colors.orange : Colors.green,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    title: isGerman ? 'Aktive Abfragen' : 'Active Queries',
                    value: _formatNum(activeQueries),
                    subtitle: isGerman
                        ? 'Warteschlange: $queuedQueries'
                        : 'Queue: $queuedQueries',
                    icon: Icons.query_builder,
                    trailing: activeQueries > 0 || queuedQueries > 0
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectingState(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final loadingText = isGerman
        ? "Verbindung zum Cluster wird hergestellt..."
        : "Connecting to cluster...";

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeController = watchIt<ActiveConnectionController>();
    final activeProfile = activeController.activeProfile;

    if (activeProfile != _lastProfile) {
      _lastProfile = activeProfile;
      _cachedPartitionLags.clear();
      _lagQueryQueue.clear();
      _previousLags.clear();
      _groupDeltas.clear();
      _partitionDeltas.clear();
      _activeLagQueries = 0;
      if (activeProfile != null) {
        if (_refreshIntervalSeconds > 0) {
          _updateRefreshInterval(_refreshIntervalSeconds, activeProfile);
        } else {
          scheduleMicrotask(() => _fetchLags(activeProfile));
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
          cmp = _calculateGroupLag(a).compareTo(_calculateGroupLag(b));
          break;
        case 6:
          final deltaA = _groupDeltas[a.groupId] ?? 0;
          final deltaB = _groupDeltas[b.groupId] ?? 0;
          cmp = deltaA.compareTo(deltaB);
          break;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, l10n, activeProfile),
            const SizedBox(height: 24),
            if (activeProfile != null && !activeController.isConnecting)
              _buildKpiCards(context, l10n, filteredLags),
            ConsumerGroupControls(
              activeProfile: activeProfile,
              searchController: _searchController,
              statusFilter: _statusFilter,
              refreshIntervalSeconds: _refreshIntervalSeconds,
              l10n: l10n,
              onClusterChanged: (profile) {
                if (profile != null) {
                  activeController.connect(profile);
                }
              },
              onStatusFilterChanged: (val) {
                setState(() {
                  _statusFilter = val;
                  _lagQueryQueue.clear();
                });
              },
              onRefreshIntervalChanged: (val) {
                _updateRefreshInterval(val, activeProfile);
              },
            ),
            const SizedBox(height: 16),
            if (_errorMessage == null &&
                _lags.isNotEmpty &&
                _lastFetchDuration != null &&
                !activeController.isConnecting)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildFetchStatusMessage(context),
              ),

            if (_errorMessage != null &&
                activeProfile != null &&
                !activeController.isConnecting)
              _buildErrorBanner(context, activeProfile),
            Expanded(
              child: activeController.isConnecting
                  ? _buildConnectingState(context)
                  : (activeProfile == null
                        ? _buildNoClusterSelected(context, l10n)
                        : (_isLoading && _lags.isEmpty
                              ? _buildLoadingState(context)
                              : _buildGroupList(context, l10n, filteredLags))),
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
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.pleaseSelectCluster,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGerman
                ? 'Wähle oben ein Cluster aus, um den Consumer-Lag anzuzeigen.'
                : 'Select a cluster above to view consumer lag details.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchStatusMessage(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final seconds = (_lastFetchDuration!.inMilliseconds / 1000.0)
        .toStringAsFixed(1);
    final count = _lags.length;
    final message = isGerman
        ? 'Erfolgreich ${_formatNum(count)} Consumer-Gruppen in ${seconds}s geladen.'
        : 'Successfully loaded ${_formatNum(count)} consumer groups in ${seconds}s.';

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
          _buildHeaderCell(6, isGerman ? 'Abarbeitung' : 'Processed', flex: 2),
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
              final rawGroup = groups[index];
              final isLoaded = _loadedGroupIds.contains(rawGroup.groupId);
              final isLoading = _loadingGroupIds.contains(rawGroup.groupId);
              final isFailed = _failedGroupIds.contains(rawGroup.groupId);

              if (!isLoaded && !isLoading && !isFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadGroupLag(rawGroup.groupId);
                });
              }

              final cachedLags = _cachedPartitionLags[rawGroup.groupId];
              final partitionLags = rawGroup.partitionLags.isNotEmpty
                  ? rawGroup.partitionLags
                  : (cachedLags ?? const []);
              final group = ConsumerGroupLag(
                groupId: rawGroup.groupId,
                state: rawGroup.state,
                protocolType: rawGroup.protocolType,
                partitionLags: partitionLags,
                membersCount: rawGroup.membersCount,
                topicsCount: rawGroup.topicsCount,
              );

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
                        child: Text(_formatNum(group.membersCount)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_formatNum(group.topicsCount)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GroupLagBadge(
                            totalLag: _calculateGroupLag(group),
                            isLoading: _loadingGroupIds.contains(group.groupId),
                            isLoaded: _loadedGroupIds.contains(group.groupId),
                            isFailed: _failedGroupIds.contains(group.groupId),
                            hasPreviousValue: group.partitionLags.isNotEmpty,
                            labelText:
                                _loadedGroupIds.contains(group.groupId) ||
                                    group.partitionLags.isNotEmpty
                                ? "${l10n.lagCol}: ${_formatNum(_calculateGroupLag(group))}"
                                : "${l10n.lagCol}: -",
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GroupDeltaBadge(
                            delta: _groupDeltas[group.groupId],
                            formattedDelta: _groupDeltas[group.groupId] != null
                                ? (_groupDeltas[group.groupId]! > 0
                                      ? "+${_formatNum(_groupDeltas[group.groupId]!)}"
                                      : _formatNum(
                                          _groupDeltas[group.groupId]!,
                                        ))
                                : "",
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    GroupDetailsView(
                      group: group,
                      partitionDeltas: _partitionDeltas[group.groupId],
                      l10n: l10n,
                    ),
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
