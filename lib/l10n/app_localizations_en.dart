// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kafkalyzer';

  @override
  String get topicAnalysis => 'Topic Analysis';

  @override
  String get messagesView => 'Messages';

  @override
  String get startAnalysis => 'Start Analysis';

  @override
  String get stopAnalysis => 'Stop Analysis';

  @override
  String get analyzingTopic => 'Analyzing topic...';

  @override
  String get analysisComplete => 'Analysis Complete';

  @override
  String get scanScope => 'Scan Scope';

  @override
  String get fullTopicScan => 'Full Scan (All Messages)';

  @override
  String get sampleLast10k => 'Sample Last 10,000 Messages';

  @override
  String get sampleLast50k => 'Sample Last 50,000 Messages';

  @override
  String get sampleLast100k => 'Sample Last 100,000 Messages';

  @override
  String get totalMessages => 'Total Messages';

  @override
  String get totalPayloadSize => 'Total Payload Size';

  @override
  String get avgMessageSize => 'Avg Message Size';

  @override
  String get minMaxSize => 'Min / Max Size';

  @override
  String get tombstones => 'Tombstones';

  @override
  String get tombstoneRatio => 'Tombstone Ratio';

  @override
  String get compactedTopic => 'Compacted Topic';

  @override
  String get nonCompactedTopic => 'Delete Retention Topic';

  @override
  String get nullKeys => 'Null Keys';

  @override
  String get keyedMessages => 'Keyed Messages';

  @override
  String get hourlyPeakProduction => 'Hourly Production Peaks (24h UTC)';

  @override
  String get partitionUtilization => 'Partition Utilization & Balance';

  @override
  String get topKeys => 'Top Message Keys';

  @override
  String get contentTypeBreakdown => 'Content Types';

  @override
  String get fieldFrequencies => 'Structured Field Frequencies';

  @override
  String get fieldValuesDistribution => 'Top Values';

  @override
  String get noAnalysisYet =>
      'No analysis data yet. Click Start Analysis to profile this topic.';

  @override
  String get exportAnalysisReport => 'Export Analysis Report';

  @override
  String get importAnalysisReport => 'Import Analysis Report';

  @override
  String importedFromTime(String cluster, String time) {
    return 'Imported from $cluster at $time';
  }

  @override
  String get unknownCluster => 'unknown cluster';

  @override
  String get analysisExportedSuccessfully =>
      'Analysis report exported successfully';

  @override
  String get analysisImportedSuccessfully =>
      'Analysis report imported successfully';

  @override
  String get importNotAValidAnalysisFile =>
      'That file is not a valid Kafkalyzer analysis report.';

  @override
  String importUnsupportedVersion(String version) {
    return 'This analysis file uses an unsupported version ($version).';
  }

  @override
  String get importMalformed => 'This analysis file could not be read.';

  @override
  String get exportFailed => 'Failed to export the analysis report.';

  @override
  String scanSpeed(String speed) {
    return '$speed msgs/sec';
  }

  @override
  String scanDuration(String duration) {
    return 'Scan duration: $duration';
  }

  @override
  String get hotPartition => 'High Load / Skew';

  @override
  String get balancedPartitions => 'Balanced';

  @override
  String get emptyTopicMessage => 'This topic is empty (0 messages).';

  @override
  String get fieldValueExplorer => 'Field Value Explorer (Top 10 Values)';

  @override
  String get searchFields => 'Search fields...';

  @override
  String get selectFieldToInspect =>
      'Select a field to inspect its Top 10 values';

  @override
  String top10ValuesForField(String field) {
    return 'Top 10 Values for $field';
  }

  @override
  String get valueCopied => 'Value copied to clipboard';

  @override
  String distinctValues(int count) {
    return '$count distinct values tracked';
  }

  @override
  String fieldOccurrences(String count, String pct) {
    return 'Appears in $count msgs ($pct%)';
  }

  @override
  String noMatchingFields(String query) {
    return 'No fields matching \'$query\'';
  }

  @override
  String topValuesForField(String field) {
    return 'Top values for $field';
  }

  @override
  String get allMessages => 'All Messages';

  @override
  String get byTopic => 'By Topic';

  @override
  String get byStep => 'By Step';

  @override
  String get filterByMessageId => 'Filter by Message ID, CORID or PMXCOR ID';

  @override
  String get enterMessageIdToFilter =>
      'Enter message ID, CORID or PMXCOR ID...';

  @override
  String get statusOpen => 'OPEN';

  @override
  String get statusAnalyzing => 'AI ANALYSIS STARTED';

  @override
  String get statusCompleted => 'AI ANALYSIS DONE';

  @override
  String get statusFailed => 'FAILED';

  @override
  String showingOrders(int filtered, int total) {
    return 'Showing $filtered of $total orders';
  }

  @override
  String get loadOrders => 'Load Orders';

  @override
  String get searchingForOrders => 'Searching for orders...';

  @override
  String get noOrdersFound => 'No orders found. Click Load to search.';

  @override
  String get noOrdersMatchFilter => 'No orders match the filter.';

  @override
  String failedToLoadOrders(String error) {
    return 'Failed to load orders: $error';
  }

  @override
  String get orders => 'Orders';

  @override
  String get rerunNotIntegrated =>
      'Rerun from history is not fully integrated in Orders View yet.';

  @override
  String get simulateOrder => 'Simulate Order';

  @override
  String get limitOrders => 'Enable order limit';

  @override
  String get maxOrders => 'Max Orders';

  @override
  String totalOrders(int total) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString Orders';
  }

  @override
  String get aiAnalysisDataAvailable => 'AI Analysis Data Available';

  @override
  String get kiError => 'AI Error';

  @override
  String get active => 'Active';

  @override
  String firstAppearanceForKey(String key) {
    return 'First appearance for Key: $key';
  }

  @override
  String stepMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString matches';
  }

  @override
  String searchingInTopic(String topic) {
    return 'Searching in: $topic';
  }

  @override
  String examinedMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Examined: $countString messages';
  }

  @override
  String get searchResults => 'Search results...';

  @override
  String matchesCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String get otherResults => 'Other Results';

  @override
  String noResultsFound(String phrase) {
    return 'No results found matching \'$phrase\'';
  }

  @override
  String get noActiveStreams => 'No active streams';

  @override
  String get noProgressInfo => 'No progress info';

  @override
  String scanned(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString scanned';
  }

  @override
  String scannedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Scanned: $countString';
  }

  @override
  String topicsProgress(int completed, int total) {
    return 'Completed $completed of $total topics';
  }

  @override
  String pmxcorStatus(String status) {
    return '$status';
  }

  @override
  String clusterLabel(String name) {
    return 'Cluster: $name';
  }

  @override
  String get close => 'Close';

  @override
  String get closeTab => 'Close Tab';

  @override
  String get scanning => 'Scanning...';

  @override
  String get operationInProgress => 'Operation in Progress';

  @override
  String get operationInProgressMessage =>
      'A search or analysis is still running on this tab. Close the tab and cancel the operation?';

  @override
  String get duplicateTab => 'Duplicate Tab';

  @override
  String get openInNewTab => 'Open in New Tab';

  @override
  String get explorer => 'Explorer';

  @override
  String get scripts => 'Scripts';

  @override
  String get settings => 'Settings';

  @override
  String get clusters => 'CLUSTERS';

  @override
  String get addCluster => 'Add Cluster';

  @override
  String get reloadTopicsAndSchemas => 'Reload Topics & Schemas';

  @override
  String get selectClusterToViewTopics => 'Select a cluster to view topics';

  @override
  String get topics => 'Topics';

  @override
  String get filterTopics => 'Filter topics...';

  @override
  String get showInternal => 'Show internal';

  @override
  String get consumerGroups => 'Consumer Groups';

  @override
  String get searchGroups => 'Search consumer groups...';

  @override
  String get noConsumerGroupsFound => 'No consumer groups found.';

  @override
  String get consumerLag => 'Consumer Lag';

  @override
  String get autoRefresh => 'Auto-Refresh (15s)';

  @override
  String get topicCol => 'Topic';

  @override
  String get partitionCol => 'Partition';

  @override
  String get logEndOffsetCol => 'Log End Offset';

  @override
  String get committedOffsetCol => 'Committed Offset';

  @override
  String get lagCol => 'Lag';

  @override
  String get totalLag => 'Total Lag';

  @override
  String get stream => 'Stream';

  @override
  String get cards => 'Cards';

  @override
  String get tree => 'Tree';

  @override
  String get raw => 'Raw';

  @override
  String get clear => 'Clear';

  @override
  String get exportMessages => 'Export Messages';

  @override
  String get sortOrderAscending => 'Ascending';

  @override
  String get sortOrderDescending => 'Descending';

  @override
  String get sortFieldTimestamp => 'Timestamp';

  @override
  String get sortFieldPartition => 'Partition';

  @override
  String get sortFieldOffset => 'Offset';

  @override
  String get sortFieldKey => 'Key';

  @override
  String get sortFieldValue => 'Value';

  @override
  String get sortFieldTooltip => 'Sort field';

  @override
  String get startCondition => 'Start Condition';

  @override
  String get startConditionLatestTooltip =>
      'Start at the most recent messages (tail of topic according to limit)';

  @override
  String get startConditionEarliestTooltip =>
      'Start reading from the oldest available message (offset 0)';

  @override
  String get startConditionOffsetTooltip =>
      'Start reading from a specific offset';

  @override
  String get startConditionTimestampTooltip =>
      'Start reading from a specific timestamp';

  @override
  String get stopCondition => 'Stop Condition';

  @override
  String get stopConditionStreamTooltip =>
      'Continue listening indefinitely for newly arriving messages';

  @override
  String get stopConditionEndTooltip =>
      'Stop when reaching the current end of the topic (high watermark)';

  @override
  String get stopConditionOffsetTooltip => 'Stop reading at a specific offset';

  @override
  String get stopConditionTimestampTooltip =>
      'Stop reading at a specific timestamp';

  @override
  String get earliest => 'Earliest';

  @override
  String get latest => 'Latest';

  @override
  String get custom => 'Custom';

  @override
  String get offset => 'Offset';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get startOffset => 'Start Offset';

  @override
  String get endOffset => 'End Offset';

  @override
  String get startTimestamp => 'Start Timestamp';

  @override
  String get endTimestamp => 'End Timestamp';

  @override
  String get quickTimeSelection => 'Quick Time Selection';

  @override
  String get ago => 'ago';

  @override
  String get now => 'Now';

  @override
  String get end => 'End';

  @override
  String get partitionOptional => 'Partition (Opt.)';

  @override
  String get fastTrace => 'Fast Trace (Hash Key)';

  @override
  String get limit => 'Limit';

  @override
  String get limitResults => 'Limit results';

  @override
  String get maxResults => 'Max Results';

  @override
  String get scope => 'Scope';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get both => 'Both';

  @override
  String get type => 'Type';

  @override
  String get contains => 'Contains';

  @override
  String get regex => 'Regex';

  @override
  String get exact => 'Exact';

  @override
  String get run => 'Run';

  @override
  String get stop => 'Stop';

  @override
  String get clearAll => 'Clear All';

  @override
  String get apply => 'Apply';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get actions => 'Actions';

  @override
  String get name => 'Name';

  @override
  String get topic => 'Topic';

  @override
  String get cluster => 'Cluster';

  @override
  String get parameters => 'Parameters';

  @override
  String get steps => 'Steps';

  @override
  String get addStep => 'Add Step';

  @override
  String get unnamedStep => 'Unnamed Step';

  @override
  String get editStep => 'Edit Step';

  @override
  String get variables => 'Variables';

  @override
  String get editVariable => 'Edit Variable';

  @override
  String get usedIn => 'Used In';

  @override
  String get noVariablesRequired => 'No variables required.';

  @override
  String get addExtraction => 'Add Extraction';

  @override
  String get newScript => 'New Script';

  @override
  String get duplicateScript => 'Duplicate Script';

  @override
  String get exportScript => 'Export Script';

  @override
  String get exportSelectedScript => 'Export Selected Script';

  @override
  String get importScripts => 'Import Scripts';

  @override
  String get deleteCluster => 'Delete Cluster';

  @override
  String deleteClusterConfirmation(String clusterName) {
    return 'Are you sure you want to delete $clusterName?';
  }

  @override
  String get useSidebarToSelectScript =>
      'Use the sidebar to select or create a script.';

  @override
  String get createNewScript => 'Create New Script';

  @override
  String get editDefinition => 'Edit Definition';

  @override
  String get selectValidScript => 'Please select a valid script first.';

  @override
  String scriptExecution(String name) {
    return 'Script Execution: $name';
  }

  @override
  String get newRun => 'New Run';

  @override
  String get history => 'History';

  @override
  String get reviewPreviousRuns => 'Review Previous Runs';

  @override
  String get noPastRunsFound => 'No past runs found.';

  @override
  String get deleteRunResult => 'Delete Run Result';

  @override
  String get deleteRunResultConfirmation =>
      'Are you sure you want to delete this run result?';

  @override
  String get runResultDeleted => 'Run result deleted';

  @override
  String get runDetails => 'Run Details';

  @override
  String get runSummary => 'Run Summary';

  @override
  String get chronological => 'Chronological';

  @override
  String get general => 'General';

  @override
  String get switchLightMode => 'Switch to Light Mode';

  @override
  String get switchDarkMode => 'Switch to Dark Mode';

  @override
  String get defaultScriptOutputDir => 'Default Script Output Directory';

  @override
  String get selectOutputDirectory => 'Select Output Directory';

  @override
  String get maxScriptRunHistory => 'Max Script Runs to keep';

  @override
  String get exportConfiguration => 'Export Configuration';

  @override
  String get export => 'Export';

  @override
  String get importConfiguration => 'Import Configuration';

  @override
  String get import => 'Import';

  @override
  String get configuration => 'Configuration';

  @override
  String get clusterConfiguration => 'Cluster Configuration';

  @override
  String get pleaseSelectCluster => 'Please select a cluster';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get viewAll => 'View All';

  @override
  String get messageDetails => 'Message Details';

  @override
  String get copyMessage => 'Copy message';

  @override
  String get contentCopied => 'Content copied to clipboard';

  @override
  String get metadataCopied => 'Metadata copied to clipboard';

  @override
  String get fullMessageCopied => 'Full message copied to clipboard';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get noDifferencesFound =>
      'No differences found between the selected versions.';

  @override
  String get unknownView => 'Unknown View';

  @override
  String get configurationExportedSuccessfully =>
      'Configuration exported successfully';

  @override
  String get configurationImportedSuccessfully =>
      'Configuration imported successfully';

  @override
  String get clustersExportedSuccessfully => 'Clusters exported successfully';

  @override
  String get clustersImportedSuccessfully => 'Clusters imported successfully';

  @override
  String get scriptExportedSuccessfully => 'Script exported successfully';

  @override
  String get scriptsImportedSuccessfully => 'Scripts imported successfully';

  @override
  String get runArchiveExported => 'Run archive exported';

  @override
  String get runArchiveImported => 'Run archive imported';

  @override
  String get messagesExportedSuccessfully => 'Messages exported successfully';

  @override
  String failedToExport(String error) {
    return 'Failed to export: $error';
  }

  @override
  String failedToImport(String error) {
    return 'Failed to import: $error';
  }

  @override
  String failedToImportRun(String error) {
    return 'Failed to import run: $error';
  }

  @override
  String messagesExportFailed(String error) {
    return 'Failed to export messages: $error';
  }

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get appUpToDate => 'Kafkalyzer is up to date';

  @override
  String get appUpToDateDescription =>
      'You are running the latest version of Kafkalyzer.';

  @override
  String get downloadUpdate => 'Download Update';

  @override
  String get downloadingUpdate => 'Downloading update...';

  @override
  String get restartNow => 'Restart Now';

  @override
  String get updateReadyRestart =>
      'Update ready! Restart required to apply update.';

  @override
  String updateError(String error) {
    return 'Error checking or applying update: $error';
  }

  @override
  String get releaseNotes => 'Release Notes';

  @override
  String get noReleaseNotes => 'No release notes available.';

  @override
  String backgroundUpdateAvailable(String version) {
    return 'A new version of Kafkalyzer (v$version) is available.';
  }

  @override
  String get updateAction => 'Update';

  @override
  String get updateUnsupportedEnvironment => 'Automatic updates unavailable';

  @override
  String get updateUnsupportedEnvironmentDescription =>
      'In-place updates require a packaged installation (AppImage on Linux, installer on Windows/macOS). Download the latest release from GitHub.';

  @override
  String get openGitHubReleases => 'Open GitHub Releases';

  @override
  String get retry => 'Retry';

  @override
  String get dockBottom => 'Dock to bottom';

  @override
  String get dockSide => 'Dock to right';

  @override
  String get closeInspector => 'Close inspector';

  @override
  String get tabPayload => 'Payload';

  @override
  String get tabKeyAndHeaders => 'Key & Headers';

  @override
  String get tabRawJson => 'Raw JSON';

  @override
  String get inspectorTitle => 'Message Inspector';

  @override
  String get copyHeaders => 'Copy all headers';

  @override
  String get copyMetadata => 'Copy metadata';

  @override
  String get copiedHeaders => 'All headers copied to clipboard';

  @override
  String copiedHeaderValue(String key) {
    return 'Copied value of \'$key\'';
  }

  @override
  String get noHeaders => 'No headers present on this message';

  @override
  String get copyRawJson => 'Copy JSON';

  @override
  String get previousMessageTooltip => 'Previous message (K)';

  @override
  String get nextMessageTooltip => 'Next message (J)';

  @override
  String messagePosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get focusMode => 'Maximize (Focus Mode)';

  @override
  String get exitFocusMode => 'Minimize (Esc)';

  @override
  String get searchInMessage => 'Search in message...';

  @override
  String get nextMatchTooltip => 'Next match (Enter)';

  @override
  String get previousMatchTooltip => 'Previous match (Shift+Enter)';

  @override
  String get noMatches => 'No matches';

  @override
  String get closeSearch => 'Close search';

  @override
  String collapsedRangeLabel(int count, int start, int end) {
    return '… $count hidden items (Index $start to $end)';
  }

  @override
  String showAllArrayItems(int count) {
    return 'Show all $count';
  }

  @override
  String get reduceToMatchContext => 'Focus matches (±1)';

  @override
  String matchesContextBadge(int matches) {
    return '$matches matches (Focus: ±1)';
  }

  @override
  String get recollapseRange => 'Re-collapse range';

  @override
  String get pinAsColumn => 'Pin as Column';

  @override
  String columnPinned(String path) {
    return 'Column \'$path\' pinned to table';
  }

  @override
  String columnAlreadyPinned(String path) {
    return 'Column \'$path\' is already pinned';
  }

  @override
  String get removeColumn => 'Remove column';

  @override
  String get resetColumns => 'Reset columns';

  @override
  String get columnsReset => 'Table columns reset to default';

  @override
  String get columnsMenu => 'Columns';

  @override
  String get hideColumn => 'Hide column';

  @override
  String get showColumn => 'Show column';

  @override
  String get autoFitColumn => 'Auto-fit width';

  @override
  String get hideEmptyFields => 'Hide empty fields';

  @override
  String get showEmptyFields => 'Show empty fields';

  @override
  String hiddenEmptyFieldsCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hidden empty fields',
      one: '1 hidden empty field',
    );
    return '$_temp0';
  }

  @override
  String get rawTimestampLabel => 'Raw';

  @override
  String get utcTimestampLabel => 'UTC';

  @override
  String get localTimestampLabel => 'Local';

  @override
  String get searchConfigurationTitle => 'Search Configuration';

  @override
  String get collapseSearchConfiguration => 'Collapse search configuration';

  @override
  String get expandSearchConfiguration => 'Expand search configuration';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar (Ctrl+B)';

  @override
  String get collapseScriptCatalog => 'Collapse script catalog';

  @override
  String get expandScriptCatalog => 'Expand script catalog (Ctrl+B)';

  @override
  String get toggleRunOverview => 'Toggle run overview';

  @override
  String get scanModeLabel => 'Mode';

  @override
  String get scanModeLatestN => 'Latest Messages';

  @override
  String get scanModeLiveTail => 'Live Stream';

  @override
  String get scanModeTimeRange => 'Time Range';

  @override
  String get scanModeOffsetEarliest => 'Offset / Earliest';

  @override
  String get quickFilterPlaceholder => 'Filter on fetch (key or value)...';

  @override
  String invalidFilterPattern(Object term) {
    return 'Invalid regular expression: $term';
  }

  @override
  String get limitLabel => 'Limit';

  @override
  String get limitAll => 'All';

  @override
  String get advancedFiltersToggle => 'Advanced';

  @override
  String get collapseAdvancedFilters => 'Collapse advanced filters';

  @override
  String get expandAdvancedFilters => 'Expand advanced filters';

  @override
  String fetchMessagesCount(int count) {
    return 'Fetch $count Messages';
  }

  @override
  String get fetchMessages => 'Fetch Messages';

  @override
  String get startLiveStream => 'Start Live Stream';

  @override
  String get filterChangedTooltip =>
      'Parameters changed – Click to fetch new results';

  @override
  String chipPartition(String partition) {
    return 'Partition: $partition';
  }

  @override
  String chipField(String field) {
    return 'Field: $field';
  }

  @override
  String chipFilterType(String type) {
    return 'Type: $type';
  }

  @override
  String chipScope(String scope) {
    return 'Scope: $scope';
  }

  @override
  String get chipFastTrace => 'Fast Trace';

  @override
  String get welcomeTitle => 'Welcome to Kafkalyzer';

  @override
  String get welcomeSubtitle =>
      'Select a Kafka cluster to explore topics, inspect consumer lag, and run scripts.';

  @override
  String get configuredClusters => 'Configured Clusters';

  @override
  String get noClustersConfigured => 'No clusters configured yet.';

  @override
  String get addClusterAction => 'Add Cluster';

  @override
  String get connectCluster => 'Connect';

  @override
  String get recentTopics => 'Recently Viewed Topics';

  @override
  String get noRecentTopics => 'No recently viewed topics yet.';

  @override
  String get clearRecentTopics => 'Clear History';

  @override
  String get clusterOverviewTitle => 'Cluster Overview';

  @override
  String get clusterOverviewSubtitle =>
      'Explore topics from the sidebar or open a recently examined topic.';

  @override
  String clusterTopicsCount(int count) {
    return '$count Topics';
  }

  @override
  String get schemaRegistryActive => 'Schema Registry Connected';

  @override
  String get schemaRegistryNotConfigured => 'No Schema Registry';

  @override
  String securityProtocolLabel(String protocol) {
    return 'Protocol: $protocol';
  }

  @override
  String get selectTopicPrompt =>
      'Select a topic from the sidebar to inspect messages and analyze partitions.';

  @override
  String recentTopicsForCluster(String cluster) {
    return 'Recent Topics in $cluster';
  }

  @override
  String get noMessagesLoadedTitle => 'No messages loaded yet';

  @override
  String get noMessagesLoadedSubtitle =>
      'Fetch the latest messages from this topic or configure your filters above.';

  @override
  String get fetchLatestMessagesAction => 'Fetch Latest 200 Messages';

  @override
  String get doubleClickTopicTip =>
      'Tip: Double-clicking a topic in the sidebar starts fetching immediately.';

  @override
  String get loadingMessages => 'Loading messages from Kafka...';

  @override
  String get internalTopicsFilter => 'Internal Topics';

  @override
  String get streamTopicsFilter => 'Stream Topics';

  @override
  String partitionBadge(int count) {
    return '${count}P';
  }

  @override
  String topicTooltip(int partitions, int rf, String retention, String policy) {
    return 'Partitions: $partitions • RF: $rf • Retention: $retention • Cleanup: $policy';
  }

  @override
  String topicTooltipSimple(int partitions, int rf) {
    return 'Partitions: $partitions • RF: $rf';
  }

  @override
  String messageSchemaResolved(String subject, int version, int id) {
    return 'Schema: $subject v$version (#$id)';
  }

  @override
  String messageSchemaUnresolved(int id) {
    return 'Schema #$id (unresolved)';
  }

  @override
  String get messageSchemaUnresolvedTooltip =>
      'The Schema Registry could not be reached. The id comes from the message itself.';

  @override
  String get groupMembersTitle => 'Members';

  @override
  String get groupMemberEmpty => 'This group currently has no members.';

  @override
  String groupMemberPartitions(int count) {
    return '$count partitions';
  }

  @override
  String groupUnassignedPartitions(int count) {
    return '$count partitions have no owner';
  }

  @override
  String get groupAssignmentNotDecodable => 'Assignment could not be decoded';

  @override
  String topicHealthWarning(int underReplicated, int leaderless) {
    return '$underReplicated under-replicated, $leaderless leaderless';
  }

  @override
  String get partitionHealthTitle => 'Partition health';

  @override
  String get partitionHealthDialogTitle => 'Partition Health & Replication';

  @override
  String get partitionHealthTooltip =>
      'View partition replication & health details';

  @override
  String get partitionLeaderCol => 'Leader';

  @override
  String get partitionReplicasCol => 'Replicas';

  @override
  String get partitionIsrCol => 'ISR';

  @override
  String get partitionHealthUnavailable => 'Partition metadata unavailable';

  @override
  String get partitionNoLeader => 'none';

  @override
  String schemaTooltipSuffix(String schema) {
    return ' • Schema: $schema';
  }

  @override
  String get viewModeTable => 'Table';

  @override
  String get viewModeTableTooltip => 'Table View';

  @override
  String get viewModeTimeline => 'Timeline';

  @override
  String get viewModeTimelineTooltip => 'Timeline View';

  @override
  String get viewModeDiff => 'Diff';

  @override
  String get viewModeDiffTooltip => 'Diff View';

  @override
  String get viewModeSchema => 'Schema';

  @override
  String get viewModeSchemaTooltip => 'Schema View';

  @override
  String filterInLoadedMessages(int count) {
    return 'Filter in $count loaded messages...';
  }

  @override
  String matchesOfTotal(int matchCount, int totalCount) {
    return '$matchCount of $totalCount matches';
  }

  @override
  String loadedMessagesCount(int count) {
    return '$count loaded messages';
  }

  @override
  String get sslClientAuthMode => 'Client Authentication (mTLS)';

  @override
  String get sslClientAuthNone => 'None';

  @override
  String get sslClientAuthKeystore => 'Keystore (PKCS12 / JKS)';

  @override
  String get sslClientAuthPem => 'PEM Certificate & Key';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get testingConnection => 'Testing Connection...';

  @override
  String get connectionSuccessful => 'Connection successful!';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get schemaRegistryCredentialsOptional =>
      'Schema Registry Credentials (Optional)';

  @override
  String get globalConfigDescription =>
      'Backup or restore the entire application state including all cluster configurations and preferences.';

  @override
  String get clusterExportDescription =>
      'Export or import selected cluster profiles and their certificates as a portable ZIP archive.';

  @override
  String get schemaRegistryConfiguredBadge => 'Schema Registry';

  @override
  String get maxScriptRuns => 'Maximum Script Runs';

  @override
  String get maxConcurrentLagQueries => 'Maximum Concurrent Lag Queries';

  @override
  String get maxConcurrentLagQueriesHelper =>
      'Default: 5 (Higher values can impact performance)';

  @override
  String get deleteStepConfirmationTitle => 'Delete Step?';

  @override
  String deleteStepConfirmationMessage(String name) {
    return 'Are you sure you want to delete step \"$name\"? This action cannot be undone.';
  }

  @override
  String get addTopicManually => 'Add Topic Manually';

  @override
  String get manualTopicNamePrompt => 'Enter topic name';

  @override
  String get addTopicAction => 'Add Topic';

  @override
  String get topicLoadingHint => 'Loading topics...';

  @override
  String selectTopicsCount(int count) {
    return 'Select Topics ($count selected)';
  }

  @override
  String get extractionSource => 'Source';

  @override
  String get extractionTopic => 'Topic';

  @override
  String get extractionVariableName => 'Variable Name';

  @override
  String get extractionJsonPath =>
      'Field path (e.g. order.id, items[0].sku, /order/status)';

  @override
  String get scriptProperties => 'Script Properties';

  @override
  String get concurrencyLimit => 'Concurrency Limit';

  @override
  String get advancedFiltersSection => 'Advanced Filters';

  @override
  String get deleteScriptConfirmationTitle => 'Delete Script?';

  @override
  String deleteScriptConfirmationMessage(String name) {
    return 'Are you sure you want to delete script \"$name\"? This action cannot be undone.';
  }

  @override
  String get searchScripts => 'Search scripts...';

  @override
  String get pipelinePreview => 'Pipeline Preview';

  @override
  String pipelineStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Steps',
      one: '1 Step',
    );
    return '$_temp0';
  }

  @override
  String get noStepsInPipeline =>
      'No execution steps configured. Use the Edit tab to add steps.';

  @override
  String get parametersAndExecution => 'Parameters & Execution';

  @override
  String runScriptWithSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return 'Run Script ($_temp0)';
  }

  @override
  String get variableTypeText => 'Text';

  @override
  String get variableTypeTimestamp => 'Timestamp';

  @override
  String get variableTypeNumeric => 'Numeric';

  @override
  String stepNumber(int number) {
    return 'Step $number';
  }

  @override
  String get targetCluster => 'Target Cluster';

  @override
  String get extractedVariables => 'Extracted';

  @override
  String get filter => 'Filter';

  @override
  String get schemaAction => 'Schema';

  @override
  String get scanProgressTitle => 'Scan Progress';

  @override
  String get clearMessagesTooltip => 'Clear Messages';

  @override
  String get editCluster => 'Edit Cluster';

  @override
  String get add => 'Add';

  @override
  String get securityProtocol => 'Security Protocol';

  @override
  String get sslConfigurationTitle => 'SSL Configuration';

  @override
  String get truststoreLocationLabel => 'Truststore Location (PEM or JKS)';

  @override
  String get truststorePasswordLabel => 'Truststore Password';

  @override
  String get keystoreLocationLabel => 'Keystore Location (.p12/.pfx/.jks)';

  @override
  String get keystorePasswordLabel => 'Keystore Password';

  @override
  String get clientCertPemLocationLabel => 'Client Certificate PEM Location';

  @override
  String get clientKeyPemLocationLabel => 'Client Private Key PEM Location';

  @override
  String get clientKeyPasswordLabel => 'Client Private Key Password';

  @override
  String get saslMechanismLabel => 'SASL Mechanism';

  @override
  String get kerberosServiceNameLabel => 'Kerberos Service Name';

  @override
  String get kerberosKeytabPathLabel => 'Kerberos Keytab Path';

  @override
  String get kerberosPrincipalLabel => 'Kerberos Principal';

  @override
  String get kerberosConfigPathLabel => 'Kerberos Config (krb5.conf) Path';

  @override
  String get oauthbearerTokenLabel => 'OAuthbearer Token';

  @override
  String get saslUsernameLabel => 'SASL Username';

  @override
  String get saslPasswordLabel => 'SASL Password';

  @override
  String get schemaRegistryUsernameOptional =>
      'Schema Registry Username (Optional)';

  @override
  String get schemaRegistryPasswordOptional =>
      'Schema Registry Password (Optional)';

  @override
  String get schemaRegistryUrlTypoPort =>
      'Likely typo: use \':\' for port instead of \'.\'';

  @override
  String get schemaRegistryUrlMissingProtocol =>
      'Missing protocol (http:// or https://)';

  @override
  String get schemaViewerTitle => 'Schema Viewer';

  @override
  String get noAvroSchemaFound => 'No Avro schema found for this topic.';

  @override
  String errorLoadingSchema(String error) {
    return 'Error loading schema: $error';
  }

  @override
  String get noMessagesToDisplay => 'No messages to display';

  @override
  String get copyValueTooltip => 'Copy value';

  @override
  String get valueCopiedToClipboard => 'Value copied to clipboard';

  @override
  String get emptyJson => 'Empty JSON';

  @override
  String get topicNameCopied => 'Topic name copied';

  @override
  String get copyTopicName => 'Copy Topic Name';

  @override
  String get clusterNameLabel => 'Cluster Name';

  @override
  String get requiredValidation => 'Required';

  @override
  String get bootstrapServersLabel => 'Bootstrap Servers (e.g. localhost:9092)';

  @override
  String get schemaRegistryUrlLabel => 'Schema Registry URL (Optional)';

  @override
  String get invalidUrlFormat => 'Invalid URL format';

  @override
  String get keySchemaTitle => 'Key Schema';

  @override
  String get valueSchemaTitle => 'Value Schema';

  @override
  String get schemaTabTitle => 'Schema';

  @override
  String get schemaPinAsColumn => 'Pin as table column';

  @override
  String get schemaPinAsColumnTooltip =>
      'Pin this schema field as a projected table column';

  @override
  String get schemaFilterByField => 'Filter by this field';

  @override
  String get schemaFilterByFieldTooltip =>
      'Filter topic messages by this schema field';

  @override
  String schemaFieldFilterApplied(String field) {
    return 'Filter field set to \'$field\'';
  }

  @override
  String get schemaNoRegistryConfigured =>
      'No Schema Registry configured for this cluster.';

  @override
  String get schemaConfigureRegistryAction => 'Configure Cluster';

  @override
  String get schemaRetry => 'Retry';

  @override
  String get schemaSearchHint => 'Search schema fields and types...';

  @override
  String get schemaVersionLabel => 'Version';

  @override
  String get schemaSideKey => 'Key';

  @override
  String get schemaSideValue => 'Value';

  @override
  String get schemaNone => 'no registry schema';

  @override
  String lagTrendTooltip(Object readings, Object high, Object low) {
    return 'Readings: $readings - highest $high, lowest $low';
  }

  @override
  String lagOverThreshold(Object threshold) {
    return 'Above the warning threshold of $threshold messages';
  }

  @override
  String get lagWarnThresholdLabel =>
      'Consumer lag warning threshold (messages)';

  @override
  String get lagWarnThresholdHelp => '0 disables the warning in the lag view.';

  @override
  String get comparisonAction => 'Compare';

  @override
  String get comparisonTitle => 'Report comparison';

  @override
  String get comparisonSourceLive => 'Live';

  @override
  String get comparisonSourceImported => 'Imported';

  @override
  String get comparisonNotAvailable => 'not available';

  @override
  String get comparisonFieldsAdded => 'Fields added';

  @override
  String get comparisonFieldsRemoved => 'Fields removed';

  @override
  String get comparisonBusiestPartition => 'Busiest partition share';

  @override
  String get comparisonMinSize => 'Min message size';

  @override
  String get comparisonMaxSize => 'Max message size';

  @override
  String get comparisonAwaitingSecond => 'Select the second report to compare.';

  @override
  String comparisonTopicMismatch(Object topicA, Object topicB) {
    return 'Cannot compare reports of different topics: $topicA and $topicB.';
  }

  @override
  String get sizePercentiles => 'p50/p95/p99';

  @override
  String get estimatedIndicator => 'estimated';

  @override
  String get distinctKeys => 'Distinct keys';

  @override
  String get cappedIndicator => 'capped';

  @override
  String get exportAsJson => 'JSON (Full Payload)';

  @override
  String get exportAsCsv => 'CSV (Visible Columns)';

  @override
  String get exportFormat => 'Export Format';

  @override
  String get exportMessagesCsv => 'Export Messages as CSV';

  @override
  String get searchPresets => 'Search Presets';

  @override
  String get defaultPreset => 'Default';

  @override
  String get saveSearchPreset => 'Save Current Search...';

  @override
  String get savePresetDialogTitle => 'Save Search Preset';

  @override
  String get presetNameLabel => 'Preset Name';

  @override
  String get presetSaved => 'Preset saved';

  @override
  String get presetDeleted => 'Preset deleted';

  @override
  String get deletePreset => 'Delete preset';

  @override
  String get updateCurrentPreset => 'Update current preset';

  @override
  String get restoreOpenTabsOnStartup => 'Restore open tabs on startup';

  @override
  String get restoreOpenTabsOnStartupDescription =>
      'Automatically reopen previously opened topic tabs when reconnecting to a cluster';

  @override
  String get copyCliCommand => 'Copy Headless CLI Command';

  @override
  String get cliCommandCopied => 'CLI command copied to clipboard';

  @override
  String get protectedByOsKeyring => 'Protected by OS Keyring';

  @override
  String get includeCredentialsInExport =>
      'Include passwords and tokens in export';

  @override
  String get includeCredentialsWarning =>
      'Warning: Exporting credentials will store unencrypted passwords in the exported archive file.';

  @override
  String get readOnlyBadgeLabel => 'Read-Only';

  @override
  String get readOnlyBadgeTooltip =>
      'kafkalyzer is strictly read-only by design. No write, publish, or offset commit operations are performed.';

  @override
  String get readOnlySecurityTitle => 'Read-Only Architecture & Security';

  @override
  String get readOnlySecurityDescription =>
      'kafkalyzer connects to Kafka exclusively as a consumer with manual partition assignment and auto-commits disabled. It contains no producer logic and cannot alter broker topics, configurations, or consumer group offsets.';

  @override
  String get readOnlyAclRecommendationTitle =>
      'Recommended Least-Privilege ACLs';

  @override
  String get readOnlyAclRecommendationDescription =>
      'For defense-in-depth, configure broker ACLs so the service account has only read permissions (Describe, Read, DescribeConfigs). Do not grant Write, AlterConfigs, or IdempotentWrite.';

  @override
  String get readOnlyAclCommandTopicLabel => 'Topic ACL command template:';

  @override
  String get readOnlyAclCommandGroupLabel =>
      'Consumer Group ACL command template:';

  @override
  String get readOnlyCopyCommand => 'Copy ACL Commands';

  @override
  String get readOnlyAclCommandsCopied => 'ACL commands copied to clipboard';

  @override
  String get compareSchemaVersions => 'Compare Versions';

  @override
  String get schemaDiffTitle => 'Schema Version Diff';

  @override
  String get baseVersionLabel => 'Base Version';

  @override
  String get compareVersionLabel => 'Compare Version';

  @override
  String get checkCompatibility => 'Check Compatibility';

  @override
  String get compatibilityCheckTitle => 'Schema Compatibility Check';

  @override
  String get schemaCompatible => 'Compatible';

  @override
  String get schemaIncompatible => 'Incompatible';

  @override
  String get compatibilityCheckSuccess =>
      'Schema is compatible with the selected subject version.';

  @override
  String get associatedTopicsTitle => 'Associated Topics';

  @override
  String get noAssociatedTopicsFound =>
      'No associated topics found for this subject.';

  @override
  String get draftSchemaLabel => 'Draft Schema (JSON)';

  @override
  String get dlqBadgeLabel => 'DLQ';

  @override
  String get retryBadgeLabel => 'Retry';

  @override
  String get deadLetterQueue => 'Dead-Letter Queue';

  @override
  String associatedDlqCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failure topics',
      one: '1 failure topic',
    );
    return '$_temp0';
  }

  @override
  String get failureDiagnosticsTitle => 'Failure Diagnostics (DLQ)';

  @override
  String get exceptionMessageLabel => 'Exception';

  @override
  String originalCoordinates(String topic, int partition, int offset) {
    return 'Origin: $topic [P: $partition, O: $offset]';
  }

  @override
  String get jumpToOriginalMessage => 'Jump to Original Message';

  @override
  String get copyKcatReplayCommand => 'Copy kcat Replay Command';

  @override
  String get kcatCommandCopied => 'kcat replay command copied to clipboard';

  @override
  String get copyShareableLink => 'Copy Shareable Link';

  @override
  String get shareableLinkCopied => 'Shareable link copied to clipboard';

  @override
  String get quickJumpTitle => 'Quick Jump / Open Reference';

  @override
  String get quickJumpHint =>
      'Paste a kafkalyzer:// link (e.g. kafkalyzer://open?topic=...&offset=...)';

  @override
  String get quickJumpInvalid => 'Invalid reference URI format';

  @override
  String quickJumpClusterNotFound(String cluster) {
    return 'Cluster \'$cluster\' not found in configuration. Select a cluster:';
  }

  @override
  String get jump => 'Jump';

  @override
  String get openFile => 'Open';

  @override
  String get showInFolder => 'Show in Folder';

  @override
  String failedToOpenFile(String error) {
    return 'Failed to open file: $error';
  }

  @override
  String failedToOpenFolder(String error) {
    return 'Failed to open folder: $error';
  }

  @override
  String get lagEstimateCaughtUp => 'Caught up';

  @override
  String get lagEstimateGrowing => 'Backlog growing';

  @override
  String get lagEstimateStalled => 'Stalled';

  @override
  String get lagEstimatePending => 'Estimating...';

  @override
  String get lagEstimateRateUnit => 'msg/s';

  @override
  String lagEstimateEtaPrefix(String eta) {
    return 'ETA: $eta';
  }

  @override
  String lagEstimateTooltip(
    String rate,
    String delta,
    String interval,
    String status,
  ) {
    return 'Rate: $rate | Delta: $delta over $interval | Status: $status';
  }

  @override
  String get recentProductionTitle => 'Recent Production';

  @override
  String get recentProductionSubtitle => 'Message volume over recent hours';

  @override
  String get window6h => '6h';

  @override
  String get window12h => '12h';

  @override
  String get window24h => '24h';

  @override
  String get window48h => '48h';

  @override
  String get window72h => '72h';

  @override
  String get timelineNotAvailableForReport =>
      'Timeline is not available for this report.';

  @override
  String timeZoneLabel(String timeZone) {
    return 'Local time ($timeZone)';
  }

  @override
  String get unusualIncreaseBadge => 'Unusual increase';

  @override
  String baselineLabel(String baseline) {
    return 'Baseline: $baseline';
  }

  @override
  String get noComparisonData => 'No comparison data';

  @override
  String uncoveredHourHint(int count) {
    return 'Before coverage start ($count messages)';
  }

  @override
  String get currentHourIncomplete => 'Incomplete hour';

  @override
  String coverageHint(int hours) {
    return 'Scan covers the last $hours hours of this window.';
  }

  @override
  String hourlyTooltipDetails(String count, String delta) {
    return '$count messages ($delta)';
  }

  @override
  String hourlyTooltipMatches(String matches, String share) {
    return '$matches matching ($share%)';
  }

  @override
  String get dailyProductionTitle => 'Daily Production Distribution';

  @override
  String get dailyProductionSubtitle => 'Messages per calendar day';

  @override
  String get partialCoverageBadge => 'Partial coverage';

  @override
  String dailyMatchesShare(String matches, String share) {
    return '$matches ($share%)';
  }

  @override
  String get valueFilterButton => 'Filter by Field Value';

  @override
  String valueFilterActive(String path, String value) {
    return 'Filter: $path = $value';
  }

  @override
  String get valueFilterClear => 'Clear filter';

  @override
  String get valueFilterDialogTitle => 'Filter by Field Value';

  @override
  String get valueFilterDialogFieldPath =>
      'Field path (e.g. attributes.region)';

  @override
  String get valueFilterDialogValue => 'Exact value';

  @override
  String get valueFilterApply => 'Apply Filter';

  @override
  String get valueFilterValidationEmpty => 'Field path cannot be empty';

  @override
  String get valueFilterMatchCardTitle => 'Filter Matches';

  @override
  String valueFilterMatchCount(String count) {
    return '$count matches';
  }

  @override
  String valueFilterShareOfTotal(String percent) {
    return '$percent% of all scanned messages';
  }

  @override
  String valueFilterShareOfField(String percent) {
    return '$percent% of messages with this field';
  }

  @override
  String valueFilterRemainder(String remainder) {
    return '$remainder non-matching messages';
  }

  @override
  String get drillDownDialogTitle => 'Field Value Details';

  @override
  String drillDownFieldPath(String path) {
    return 'Field: $path';
  }

  @override
  String drillDownValue(String value) {
    return 'Value: $value';
  }

  @override
  String drillDownCount(String count) {
    return 'Count: $count';
  }

  @override
  String drillDownShareOfAll(String percent) {
    return 'Share of all messages: $percent%';
  }

  @override
  String drillDownShareOfField(String percent) {
    return 'Share of field occurrences: $percent%';
  }

  @override
  String get drillDownRescanButton => 'Re-scan with this filter';

  @override
  String get drillDownApproximateBadge => 'Approximate (values capped)';

  @override
  String get drillDownTruncatedNotice =>
      'Value was truncated (>80 chars). Re-scan cannot use truncated values.';

  @override
  String get drillDownRescanUnavailableImported =>
      'Re-scan is not available for imported reports.';

  @override
  String get duplicateScopeLabel => 'Duplicate Scope';

  @override
  String get duplicateScopePayloadOnly => 'Payload (Value)';

  @override
  String get duplicateScopeKeyAndPayload => 'Key + Payload';

  @override
  String get duplicateMessagesCardTitle => 'Duplicate Messages';

  @override
  String duplicateMessagesRate(String rate) {
    return '$rate% of messages';
  }

  @override
  String duplicateMessagesSubtitle(String unique, String scope) {
    return '$unique unique • $scope';
  }

  @override
  String get topDuplicatesTitle => 'Top Duplicated Messages';

  @override
  String get topDuplicatesSubtitle =>
      'Showing up to 20 most frequent duplicated messages';

  @override
  String get noDuplicatesDetected =>
      'No duplicate messages detected in this scan.';

  @override
  String get duplicateAnalysisUnavailable =>
      'Duplicate analysis is not available for this report.';

  @override
  String sampleLocation(int partition, int offset) {
    return 'Partition $partition, Offset $offset';
  }

  @override
  String get copyPayload => 'Copy payload';

  @override
  String get copyKey => 'Copy key';

  @override
  String get copiedPayload => 'Payload copied to clipboard';

  @override
  String get copiedKey => 'Key copied to clipboard';

  @override
  String get duplicateRankHeader => '#';

  @override
  String get duplicateCountHeader => 'Occurrences';

  @override
  String get duplicateShareHeader => 'Share';

  @override
  String get duplicateKeyHeader => 'Key';

  @override
  String get duplicatePayloadPreviewHeader => 'Payload Preview';

  @override
  String get duplicateSampleCoordinatesHeader => 'Sample Location';

  @override
  String get duplicateDetailsTitle => 'Duplicate Message Details';

  @override
  String duplicateDetailsSubtitle(int rank, String count, String share) {
    return 'Rank #$rank • $count occurrences ($share%)';
  }

  @override
  String get openInMessages => 'Open in Messages';

  @override
  String get filterDuplicatesInMessages => 'Filter in Messages';

  @override
  String get jumpToSampleOffset => 'Jump to Sample';

  @override
  String get duplicateCoordinates => 'Coordinates';

  @override
  String get duplicateTimestamp => 'Timestamp';

  @override
  String get duplicateKey => 'Key';

  @override
  String get duplicatePayload => 'Decoded Payload';

  @override
  String get inspectDuplicateTooltip => 'View duplicate details';
}
