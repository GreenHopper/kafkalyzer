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
  String get scanScope => 'Scan Scope';

  @override
  String get fullTopicScan => 'Full Scan (All Messages)';

  @override
  String get totalMessages => 'Total Messages';

  @override
  String get totalPayloadSize => 'Total Payload Size';

  @override
  String get avgMessageSize => 'Avg Message Size';

  @override
  String get tombstones => 'Tombstones';

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
  String fieldOccurrences(String count, String pct) {
    return 'Appears in $count msgs ($pct%)';
  }

  @override
  String noMatchingFields(String query) {
    return 'No fields matching \'$query\'';
  }

  @override
  String get allMessages => 'All Messages';

  @override
  String get byTopic => 'By Topic';

  @override
  String get byStep => 'By Step';

  @override
  String get active => 'Active';

  @override
  String stepMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString matches';
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
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString / $totalString matches';
  }

  @override
  String get otherResults => 'Other Results';

  @override
  String scanned(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString scanned';
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
  String get selectClusterToViewTopics => 'Select a cluster to view topics';

  @override
  String get topics => 'Topics';

  @override
  String get filterTopics => 'Filter topics...';

  @override
  String get consumerGroups => 'Consumer Groups';

  @override
  String get searchGroups => 'Search consumer groups...';

  @override
  String get noConsumerGroupsFound => 'No consumer groups found.';

  @override
  String get consumerLag => 'Consumer Lag';

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
  String get newRun => 'New Run';

  @override
  String get history => 'History';

  @override
  String get noPastRunsFound => 'No past runs found.';

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
  String get noDifferencesFound => 'No differences found.';

  @override
  String get configurationExportedSuccessfully =>
      'Configuration exported successfully';

  @override
  String get configurationImportedSuccessfully =>
      'Configuration imported successfully';

  @override
  String get clustersExportedSuccessfully => 'Clusters exported successfully';

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
  String get copyHeaders => 'Copy all headers';

  @override
  String get copyMetadata => 'Copy metadata';

  @override
  String get copiedHeaders => 'All headers copied to clipboard';

  @override
  String get noHeaders => 'No headers present on this message';

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
  String scriptRunMatchedOfExamined(int matched, int examined) {
    return '$matched of $examined';
  }

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
  String get resetColumns => 'Reset columns';

  @override
  String get columnsReset => 'Table columns reset to default';

  @override
  String get columnsMenu => 'Columns';

  @override
  String get hideColumn => 'Hide column';

  @override
  String get hideEmptyFields => 'Hide empty fields';

  @override
  String get showEmptyFields => 'Show empty fields';

  @override
  String get rawTimestampLabel => 'Raw';

  @override
  String get utcTimestampLabel => 'UTC';

  @override
  String get localTimestampLabel => 'Local';

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
  String get clearRecentTopics => 'Clear History';

  @override
  String clusterTopicsCount(int count) {
    return '$count Topics';
  }

  @override
  String get schemaRegistryActive => 'Schema Registry Connected';

  @override
  String get schemaRegistryNotConfigured => 'No Schema Registry';

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
  String get maxConcurrentLagQueries => 'Maximum Concurrent Lag Queries';

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
  String get noSchemaFound => 'No schema found for this topic.';

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
  String get schemaPinAsColumnTooltip =>
      'Pin this schema field as a projected table column';

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
  String get exportAsNdjson => 'NDJSON (One Message per Line)';

  @override
  String get exportAsCsv => 'CSV (Visible Columns)';

  @override
  String get exportMessagesCsv => 'Export Messages as CSV';

  @override
  String exportSelectedOnly(int count) {
    return 'Only selected messages ($count)';
  }

  @override
  String get exportIncludeDimmedNonMatches => 'Include dimmed non-matches';

  @override
  String get exportAddHeadersColumn => 'Add Headers column (CSV)';

  @override
  String get pauseView => 'Pause';

  @override
  String get pauseViewTooltip =>
      'Freeze the result view while consumption continues in the background';

  @override
  String resumeViewWithNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resume · $count new',
      one: 'Resume · 1 new',
      zero: 'Resume',
    );
    return '$_temp0';
  }

  @override
  String get resumeViewTooltip =>
      'Resume live updates and merge buffered messages';

  @override
  String get followNewest => 'Follow newest';

  @override
  String get followNewestOnTooltip =>
      'Following newest messages; click or scroll to pause following';

  @override
  String get followNewestOffTooltip =>
      'Jump to newest messages and keep following';

  @override
  String get followNewestDisabledTooltip =>
      'Follow newest requires sorting by Timestamp';

  @override
  String droppedMessagesIndicator(String dropped, String limit) {
    return '$dropped oldest messages dropped (limit $limit)';
  }

  @override
  String get droppedMessagesTooltip =>
      'Oldest messages were dropped when the buffer reached its limit. Adjust in Settings → General.';

  @override
  String get messageBufferLimitLabel => 'Message buffer limit';

  @override
  String get messageBufferLimitHelper =>
      'Maximum retained messages per topic tab or search target (1,000–1,000,000)';

  @override
  String get messageBufferLimitError =>
      'Enter a whole number between 1,000 and 1,000,000';

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
      'Credentials will be encrypted with your passphrase in an age archive (.zip.age).';

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
  String get schemaNoDifferencesFound =>
      'No differences found between the selected versions.';

  @override
  String get draftSchemaLabel => 'Draft Schema (JSON)';

  @override
  String get dlqBadgeLabel => 'DLQ';

  @override
  String get retryBadgeLabel => 'Retry';

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
  String get copyFailedMessage => 'Copy failed message';

  @override
  String get failedMessageCopied => 'Failed message copied to clipboard';

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
  String get duplicateKey => 'Key';

  @override
  String get duplicatePayload => 'Decoded Payload';

  @override
  String get inspectDuplicateTooltip => 'View duplicate details';

  @override
  String importRejectedUnsafeEntry(String entry) {
    return 'Import rejected: archive contains an unsafe entry ($entry).';
  }

  @override
  String get clusterNameAlreadyUsed =>
      'A cluster profile with this name already exists.';

  @override
  String get importConflictTitle => 'Cluster Profile Conflict';

  @override
  String importConflictMessage(String name) {
    return 'A cluster profile named \"$name\" already exists.';
  }

  @override
  String get importConflictReplace => 'Replace existing';

  @override
  String get importConflictRename => 'Import as new name';

  @override
  String get importConflictSkip => 'Skip';

  @override
  String importSummary(int added, int replaced, int renamed, int skipped) {
    return 'Imported $added added, $replaced replaced, $renamed renamed, $skipped skipped.';
  }

  @override
  String get keyringUnavailableNotice =>
      'System keyring is unavailable. Credentials are kept in memory for this session only and will not be persisted securely.';

  @override
  String get profileStoreUnreadableNotice =>
      'Saved cluster profiles could not be read and were left untouched so nothing is lost.';

  @override
  String get scriptStoreUnreadableNotice =>
      'Saved scripts could not be read and were left untouched so nothing is lost.';

  @override
  String storeBackupLocation(String path) {
    return 'Backup saved at: $path';
  }

  @override
  String get storeBackupFailed => 'No backup file could be written.';

  @override
  String storePartiallyUnreadable(int count, String store) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entries were',
      one: 'entry was',
    );
    return '$count unreadable saved $store $_temp0 skipped and preserved.';
  }

  @override
  String duplicateProfileNamesNotice(String names) {
    return 'Duplicate cluster profile names detected: $names. Please rename duplicates so each profile has a unique name.';
  }

  @override
  String get discardUnreadableData => 'Discard unreadable data';

  @override
  String get discardUnreadableConfirm =>
      'This will permanently delete the unreadable stored data so you can save new items. Continue?';

  @override
  String get copyBackupPath => 'Copy backup path';

  @override
  String get storeUnreadableActionRefused =>
      'Action refused while stored data is unreadable. Discard unreadable data or restore the backup first.';

  @override
  String get passwordsNotPersistedTooltip =>
      'System keyring is unavailable. This password will not be persisted across restarts.';

  @override
  String get insecureTlsBadgeLabel => 'Insecure TLS';

  @override
  String get insecureTlsBadgeTooltip =>
      'TLS certificate verification is disabled for this cluster profile.';

  @override
  String get tlsVerificationSwitchLabel => 'Verify TLS certificates';

  @override
  String get tlsVerificationDisabledWarning =>
      'Warning: Certificate and hostname verification is disabled for this profile. Connections are vulnerable to interception.';

  @override
  String get tlsTransitionDialogTitle => 'TLS certificate verification failed';

  @override
  String tlsTransitionDialogBody(String clusterName, String error) {
    return 'Certificate verification failed when checking cluster \"$clusterName\". Choose whether to keep TLS verification enabled (recommended) or disable it for this profile.\n\nDetails: $error';
  }

  @override
  String get tlsTransitionKeepEnabled => 'Keep verification on';

  @override
  String get tlsTransitionDisable => 'Disable verification (insecure)';

  @override
  String get messageFetchFailedTitle => 'Failed to fetch messages';

  @override
  String get topicsLoadFailedTitle => 'Failed to load topics';

  @override
  String subjectsLoadFailed(String error) {
    return 'Failed to load schemas: $error';
  }

  @override
  String get columnFiltersNoMatch => 'No rows match the active column filters.';

  @override
  String get resetColumnFilters => 'Reset filters';

  @override
  String get lagUnknown => 'Unknown';

  @override
  String get lagNoCommit => 'No commit';

  @override
  String get lagNoCommittedOffsets => 'No committed offsets';

  @override
  String lagGroupsLoadedProgress(int loaded, int total) {
    return '$loaded of $total loaded';
  }

  @override
  String get lagTotalIncomplete => 'Total incomplete';

  @override
  String get lagErrorLabel => 'Error';

  @override
  String lagErrorTooltip(String error) {
    return 'Lag error: $error';
  }

  @override
  String get lagRetryAction => 'Retry';

  @override
  String get lagRefreshInProgress => 'Refresh in progress';

  @override
  String get partitionOwnershipUnknown => 'Partition ownership unknown';

  @override
  String get diagStageNetwork => 'Network';

  @override
  String get diagStageTls => 'TLS';

  @override
  String get diagStageAuthentication => 'Authentication';

  @override
  String get diagStageMetadata => 'Metadata';

  @override
  String get diagStageSchemaRegistry => 'Schema Registry';

  @override
  String get diagStateOk => 'OK';

  @override
  String get diagStateFailed => 'Failed';

  @override
  String get diagStateNotChecked => 'Not checked';

  @override
  String get diagStateNotApplicable => 'Not applicable';

  @override
  String get diagStateUndetermined => 'Undetermined';

  @override
  String diagNotCheckedPreviousFailed(String stage) {
    return 'Skipped because $stage failed';
  }

  @override
  String get diagNotCheckedBudgetExhausted =>
      'Skipped because the diagnosis time budget ran out';

  @override
  String get diagOverallOk =>
      'Connection succeeded across all applicable stages';

  @override
  String diagOverallFailedAtStage(String stage) {
    return 'Connection failed at stage: $stage';
  }

  @override
  String get diagOverallStageUnknown => 'Connection failed, stage unknown';

  @override
  String get diagHintInvalidEntry =>
      'Bootstrap entry is invalid (expected host:port without scheme)';

  @override
  String get diagHintHostUnknown => 'Host name could not be resolved';

  @override
  String get diagHintConnectionRefused => 'Connection refused by host';

  @override
  String get diagHintConnectTimeout => 'Connection timed out';

  @override
  String get diagHintCertificateRejected =>
      'Certificate verification failed — check truststore/CA or hostname';

  @override
  String get diagHintTlsHandshakeFailed =>
      'TLS handshake failed — check client/server certificates and TLS settings';

  @override
  String get diagHintProtocolMismatch =>
      'Security protocol does not match the broker listener';

  @override
  String get diagHintAuthenticationFailed =>
      'Authentication failed — check SASL username and password';

  @override
  String get diagHintMechanismRejected =>
      'SASL mechanism rejected or not supported by broker listener';

  @override
  String get diagHintNotAuthorized =>
      'Not authorized to describe cluster metadata (check ACLs)';

  @override
  String get diagHintRequestTimeout => 'Request timed out';

  @override
  String get diagHintRegistryUnreachable => 'Schema Registry is unreachable';

  @override
  String get diagHintRegistryUnauthorized =>
      'Schema Registry rejected credentials';

  @override
  String diagHintRegistryHttpError(int status) {
    return 'Schema Registry returned HTTP $status';
  }

  @override
  String get diagHintGeneric => 'Connection check failed';

  @override
  String get diagServerDnsLabel => 'DNS';

  @override
  String get diagServerTcpLabel => 'TCP';

  @override
  String get diagServerResolvedLabel => 'Resolved';

  @override
  String diagServerConnectedTo(String address) {
    return 'Connected to $address';
  }

  @override
  String get diagRawErrorLabel => 'Raw error';

  @override
  String get errorUnexpectedNotice => 'An unexpected error occurred.';

  @override
  String get errorDetailsAction => 'Details';

  @override
  String get errorDetailsDialogTitle => 'Error Details';

  @override
  String get errorCopyDetails => 'Copy details';

  @override
  String get errorDetailsCopied => 'Error details copied to clipboard';

  @override
  String get errorDetailsCopyFailed =>
      'Could not copy error details to clipboard. You can select and copy the text manually.';

  @override
  String get startupFailureTitle => 'Kafkalyzer could not start';

  @override
  String get startupFailureBody =>
      'An unexpected error prevented Kafkalyzer from starting. Copy the details below or open the log folder to inspect the full log.';

  @override
  String get startupFailureLogPathLabel => 'Log file';

  @override
  String get diagnosticsUnavailable => 'unavailable';

  @override
  String get diagnosticsUnknown => 'unknown';

  @override
  String get settingsDiagnosticsTitle => 'Diagnostics';

  @override
  String get settingsDiagnosticsLogPathLabel => 'Log file';

  @override
  String get settingsOpenLogFolder => 'Open log folder';

  @override
  String get settingsCopyDiagnostics => 'Copy diagnostics';

  @override
  String get settingsDiagnosticsCopied =>
      'Diagnostics report copied to clipboard';

  @override
  String settingsOpenLogFolderFailed(String path) {
    return 'Could not open log folder at $path';
  }

  @override
  String get settingsFileLoggingUnavailable => 'File logging is unavailable';

  @override
  String get settingsAboutButton => 'About Kafkalyzer';

  @override
  String get aboutLegalese =>
      'Read-only Apache Kafka analyzer. Licensed under Apache-2.0.';

  @override
  String get aboutRepositoryLabel => 'Source repository';

  @override
  String get aboutLogFolderLabel => 'Log folder';

  @override
  String get aboutDataFolderLabel => 'Settings and data folder';

  @override
  String get aboutOutputFolderLabel => 'Default output folder';

  @override
  String get aboutOpenLinkFailed =>
      'Could not open the repository link in your browser';

  @override
  String get settingsKeyboardShortcutsButton => 'Keyboard shortcuts';

  @override
  String get shortcutOverviewTitle => 'Keyboard Shortcuts';

  @override
  String get shortcutContextGlobal => 'Global';

  @override
  String get shortcutContextExplorer => 'Explorer';

  @override
  String get shortcutContextScripts => 'Scripts';

  @override
  String get shortcutContextMessages => 'Messages';

  @override
  String get shortcutContextInspector => 'Message Inspector';

  @override
  String get shortcutContextInspectorSearch => 'Inspector Search';

  @override
  String get shortcutToggleSidebar => 'Toggle sidebar';

  @override
  String get shortcutQuickJump => 'Quick Jump';

  @override
  String get shortcutNextMessage => 'Next message';

  @override
  String get shortcutPreviousMessage => 'Previous message';

  @override
  String get shortcutToggleFocusMode => 'Toggle Focus Mode';

  @override
  String get shortcutCloseInspectorOrExitFocus =>
      'Close inspector or exit Focus Mode';

  @override
  String get shortcutNextSearchMatch => 'Next search match';

  @override
  String get shortcutPreviousSearchMatch => 'Previous search match';

  @override
  String get shortcutCloseInspectorSearch => 'Close inspector search';

  @override
  String get shortcutShowOverview => 'Show keyboard shortcuts';

  @override
  String get shortcutKeyEscape => 'Escape';

  @override
  String get shortcutKeyEnter => 'Enter';

  @override
  String get shortcutKeyArrowDown => 'Down Arrow';

  @override
  String get shortcutKeyArrowUp => 'Up Arrow';

  @override
  String get shortcutKeyShift => 'Shift';

  @override
  String get shortcutCommandPalette => 'Command palette';

  @override
  String get commandPaletteHint => 'Search clusters, topics, groups, scripts…';

  @override
  String get commandPaletteKindDestination => 'Destination';

  @override
  String get commandPaletteKindCluster => 'Cluster';

  @override
  String get commandPaletteKindTopic => 'Topic';

  @override
  String get commandPaletteKindConsumerGroup => 'Consumer Group';

  @override
  String get commandPaletteKindScript => 'Script';

  @override
  String get commandPaletteKindReference => 'Reference';

  @override
  String get commandPaletteOpenReference => 'Open reference in Quick Jump';

  @override
  String get commandPaletteActiveCluster => 'active';

  @override
  String get commandPaletteNoResults => 'No matching results';

  @override
  String commandPaletteResultsCap(int shown, int total) {
    return '$shown of $total matches, keep typing';
  }

  @override
  String get commandPaletteGroupsNotLoadedNote =>
      'Consumer groups appear after Consumer Lag has loaded them.';

  @override
  String get commandPaletteListLabel => 'Command palette results';

  @override
  String commandPalettePartitionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partitions',
      one: '1 partition',
    );
    return '$_temp0';
  }

  @override
  String commandPaletteStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String consumerGroupNotFound(String id) {
    return 'Consumer group $id not found';
  }

  @override
  String get scriptNotFound => 'Script not found';

  @override
  String fastTracePartitionPreview(int partition, int partitionCount) {
    return 'Partition $partition of $partitionCount';
  }

  @override
  String get fastTracePartitionCountUnknown => 'Partition count unknown';

  @override
  String get fastTraceEnterKeyHint => 'Enter a key to preview target partition';

  @override
  String get fastTraceFirstTermOnlyNote =>
      'Only the first term selects the scanned partition';

  @override
  String get fastTraceAssumptionSummary =>
      'Assumes Java default partitioner (murmur2), UTF-8 text key';

  @override
  String get fastTraceAssumptionCaveat =>
      'Assumes the Java default partitioner hashing the key as UTF-8 text. The actual partition can differ if the producer uses another partitioner (e.g. librdkafka consistent/CRC32 or custom), binary or serialized keys (e.g. Avro keys with Confluent wire prefix), or if partitions were added after the message was produced.';

  @override
  String get fastTraceAssumptionInfoLabel =>
      'Fast Trace partitioning assumptions';

  @override
  String chipFastTracePartition(int partition) {
    return 'Fast Trace → P$partition';
  }

  @override
  String get exportPassphraseLabel => 'Passphrase';

  @override
  String get exportPassphraseConfirmLabel => 'Confirm passphrase';

  @override
  String exportPassphraseTooShort(int min) {
    return 'Passphrase must be at least $min characters';
  }

  @override
  String get exportPassphraseMismatch => 'Passphrases do not match';

  @override
  String get exportPassphraseNotRecoverable =>
      'A lost passphrase cannot be recovered. Without it, this bundle cannot be opened.';

  @override
  String get showPassphrase => 'Show passphrase';

  @override
  String get hidePassphrase => 'Hide passphrase';

  @override
  String get encryptingBundle => 'Encrypting bundle...';

  @override
  String get importPassphraseTitle => 'Enter bundle passphrase';

  @override
  String get importPassphraseLabel => 'Passphrase';

  @override
  String get importPassphraseWrong => 'Wrong passphrase. Please try again.';

  @override
  String get importEncryptedCorrupt =>
      'The encrypted bundle is damaged or corrupt.';

  @override
  String get importEncryptedUnsupported =>
      'This encrypted file is not passphrase-encrypted and cannot be imported.';

  @override
  String get importEncryptedTooExpensive =>
      'This encrypted bundle requires too much work to decrypt on this device.';

  @override
  String get searchRunning => 'Searching...';

  @override
  String get searchFailed => 'Search failed';

  @override
  String matchesCountCapped(int current, int total) {
    return '$current / $total+';
  }

  @override
  String get environmentTagSectionTitle => 'Environment Tag (optional)';

  @override
  String get environmentLabelField => 'Environment Label';

  @override
  String get environmentLabelHint => 'e.g. DEV, TEST, STAGE, PROD';

  @override
  String environmentLabelTooLong(int max) {
    return 'Environment label must be at most $max characters';
  }

  @override
  String environmentSemanticsLabel(String label) {
    return 'Environment: $label';
  }

  @override
  String get environmentColorRed => 'Red';

  @override
  String get environmentColorOrange => 'Orange';

  @override
  String get environmentColorYellow => 'Yellow';

  @override
  String get environmentColorGreen => 'Green';

  @override
  String get environmentColorBlue => 'Blue';

  @override
  String get environmentColorPurple => 'Purple';

  @override
  String get environmentColorGrey => 'Grey';

  @override
  String get bootstrapNoEntries => 'Enter at least one host:port entry';

  @override
  String bootstrapMissingPort(String entry) {
    return 'Entry \"$entry\" requires a port (:port)';
  }

  @override
  String bootstrapInvalidPort(String entry) {
    return 'Entry \"$entry\" has an invalid port (1–65535)';
  }

  @override
  String bootstrapInvalidHost(String entry) {
    return 'Entry \"$entry\" has an invalid host';
  }

  @override
  String bootstrapSchemeNotAllowed(String entry) {
    return 'Entry \"$entry\" must not include a URL scheme';
  }

  @override
  String get extraPropertiesTitle => 'Additional client properties';

  @override
  String get extraPropertiesHint => 'One key=value per line';

  @override
  String get extraPropertiesAllowedKeysTitle => 'Allowed keys';

  @override
  String extraPropertiesSyntaxError(int line) {
    return 'Line $line: invalid syntax (expected key=value)';
  }

  @override
  String extraPropertiesNotAllowed(int line, String key) {
    return 'Line $line: \"$key\" is not allowed';
  }

  @override
  String extraPropertiesInvalidValue(int line, String key, String allowed) {
    return 'Line $line: invalid value for \"$key\" (allowed: $allowed)';
  }

  @override
  String extraPropertiesDuplicate(int line, String key) {
    return 'Line $line: duplicate key \"$key\"';
  }

  @override
  String get importClientPropertiesAction => 'Import client.properties';

  @override
  String get importClientPropertiesPreviewTitle =>
      'Import client.properties Preview';

  @override
  String get importClientPropertiesMappedSection => 'Profile fields to apply';

  @override
  String get importClientPropertiesExtrasSection => 'Additional properties';

  @override
  String get importClientPropertiesSkippedSection => 'Not applied';

  @override
  String get importClientPropertiesApplyAction => 'Apply';

  @override
  String get importClientPropertiesTooLarge =>
      'File is larger than 1 MiB and cannot be imported.';

  @override
  String get importClientPropertiesInvalidUtf8 =>
      'File is not valid UTF-8 and cannot be read.';

  @override
  String importClientPropertiesReadError(String error) {
    return 'Could not read file: $error';
  }

  @override
  String get importClientPropertiesNothingToApply =>
      'No supported properties were found in this file.';

  @override
  String get skipReasonNotAllowed => 'Unknown or not allowed';

  @override
  String get skipReasonUnsupported => 'Unsupported type or format';

  @override
  String get skipReasonPlaceholder => 'Placeholder cannot be resolved';

  @override
  String get skipReasonVerificationOverride =>
      'TLS verification can only be disabled in the dialog';

  @override
  String get skipReasonInvalidValue => 'Invalid value';

  @override
  String get duplicateClusterAction => 'Duplicate';

  @override
  String get duplicateClusterTitle => 'Duplicate Cluster';

  @override
  String get clusterFilterHint =>
      'Filter clusters (name, environment, bootstrap)';

  @override
  String get clusterFilterNoMatch => 'No cluster matches the filter';

  @override
  String get clusterFilterClear => 'Clear filter';

  @override
  String get disconnectClusterTooltip => 'Disconnect';

  @override
  String disconnectConfirmTitle(String cluster) {
    return 'Disconnect from $cluster?';
  }

  @override
  String get disconnectConfirmBody =>
      'A search or analysis is still running for this cluster. Disconnecting will stop it and close its tabs.';

  @override
  String get disconnectConfirmAction => 'Disconnect';

  @override
  String unrestoredTabsMessage(int count, String topics) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tabs could not be restored ($topics)',
      one: '1 tab could not be restored ($topics)',
    );
    return '$_temp0';
  }

  @override
  String get decodeAs => 'Decode as…';

  @override
  String get decodeAsJson => 'JSON';

  @override
  String get decodeAsBase64 => 'Base64';

  @override
  String get decodeAsGzip => 'gzip';

  @override
  String get showOriginalOnly => 'Show original only';

  @override
  String get showOriginal => 'Show original';

  @override
  String get copyDecoded => 'Copy decoded';

  @override
  String get copyAsHex => 'Copy as hex';

  @override
  String binaryBytesSummary(int count) {
    return '$count bytes';
  }

  @override
  String get decodeErrorInvalidJson => 'Not valid JSON';

  @override
  String get decodeErrorInvalidBase64 => 'Not valid Base64';

  @override
  String get decodeErrorNotGzip => 'Not a gzip stream';

  @override
  String get decodeErrorCorruptGzip => 'Corrupt gzip data';

  @override
  String decodeErrorInputTooLarge(int limitMib) {
    return 'Input exceeds $limitMib MiB limit';
  }

  @override
  String decodeErrorOutputTooLarge(int limitMib) {
    return 'Decoded output exceeds $limitMib MiB limit';
  }

  @override
  String get epochUnitSeconds => 'seconds';

  @override
  String get epochUnitMilliseconds => 'milliseconds';

  @override
  String get epochUnitMicroseconds => 'microseconds';

  @override
  String get epochUnitNanoseconds => 'nanoseconds';

  @override
  String epochTooltip(String primary, String secondary, String unit) {
    return '$primary\n$secondary\nAssumed unit: $unit';
  }

  @override
  String get emptyValueMarker => 'Empty value';

  @override
  String get inspectorKeySection => 'Key';

  @override
  String inspectorHeadersSection(int count) {
    return 'Headers ($count)';
  }

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get textSizeLabel => 'Text size';

  @override
  String textSizeCustom(int percent) {
    return 'Custom ($percent%)';
  }

  @override
  String get timeDisplayLabel => 'Timestamps';

  @override
  String get timeDisplayLocal => 'Local';

  @override
  String get timeDisplayUtc => 'UTC';

  @override
  String get defaultResultLimitLabel => 'Default result limit';

  @override
  String intSettingRangeHelper(int min, int max, int defaultValue) {
    return 'Range: $min–$max (Default: $defaultValue)';
  }

  @override
  String intSettingRangeError(int min, int max) {
    return 'Enter a whole number from $min to $max';
  }

  @override
  String get resetToDefaults => 'Reset to defaults';

  @override
  String resetSectionConfirmTitle(String section) {
    return 'Reset $section settings?';
  }

  @override
  String resetSectionConfirmBody(String section) {
    return 'This restores $section preferences to their defaults. Cluster profiles, secrets, scripts, and saved searches will not be touched.';
  }

  @override
  String get resetConfirmAction => 'Reset';

  @override
  String manualUpdateAvailableTitle(String version) {
    return 'Version $version available';
  }

  @override
  String manualUpdateAvailableBody(String version) {
    return 'A newer release ($version) is available on GitHub. This installation cannot update automatically.';
  }

  @override
  String get manualUpToDateHint =>
      'You are on the latest version. Automatic updates are not available for this installation.';

  @override
  String latestReleaseKnownBody(String version) {
    return 'Latest release on GitHub: $version. Running version could not be compared.';
  }

  @override
  String get openReleasePage => 'Open release page';

  @override
  String get downloadCancelledSnackbar =>
      'Download cancelled. The update will not be installed.';

  @override
  String get connectionErrorInvalidBootstrapServers =>
      'Invalid bootstrap server';

  @override
  String get connectionErrorTlsVerificationFailed =>
      'TLS certificate verification failed';

  @override
  String get connectionErrorValidationFailed => 'Connection failed validation';

  @override
  String get connectionErrorBrokerTransport =>
      'Broker transport failure. Check your address and network.';

  @override
  String get connectionErrorConnectionRefused => 'Connection refused';

  @override
  String get connectionErrorOther => 'Connection failed';

  @override
  String get topicAnalysisEmptyFieldPath => 'Field path cannot be empty';

  @override
  String get topicAnalysisNoPreviousScope =>
      'No previous analysis scope to rescan';

  @override
  String get exportTopicAnalysis => 'Export Topic Analysis';

  @override
  String get importTopicAnalysis => 'Import Topic Analysis';

  @override
  String saveRunArchive(String name) {
    return 'Save Run Archive - $name';
  }

  @override
  String get saveSchemaMarkdown => 'Save Schema Markdown';

  @override
  String get step => 'Step';

  @override
  String get content => 'Content';

  @override
  String filterColumnTitle(String column) {
    return 'Filter $column';
  }

  @override
  String get filterSubstringHint => 'Enter substring to filter...';

  @override
  String get copyContent => 'Copy content';

  @override
  String get emptyBinaryData => 'Empty binary data';

  @override
  String get preparingHexDump => 'Preparing hex dump for clipboard...';

  @override
  String get hexDumpCopied => 'Hex dump copied to clipboard';

  @override
  String get copyFullHexDump => 'Copy Full Hex Dump';

  @override
  String get objectCopiedToClipboard => 'Object copied to clipboard';

  @override
  String get entityDetails => 'Entity Details';

  @override
  String get copyWholeObject => 'Copy whole object';

  @override
  String get errorComputingDiff => 'Error computing diff';

  @override
  String get globalNoStep => 'Global (No Step)';

  @override
  String get stacktrace => 'Stacktrace';

  @override
  String noResultsMatchingPhrase(String phrase) {
    return 'No results found matching \'$phrase\'';
  }

  @override
  String get hideNonMatchingMessages => 'Hide non-matching messages';

  @override
  String get showNonMatchesAsDimmed => 'Show non-matches as dimmed';

  @override
  String get availableTopics => 'Available Topics';

  @override
  String get optionalMetadataRegistry => 'Optional metadata registry';

  @override
  String get noClusterSelected => 'No cluster selected';

  @override
  String quickJumpTopicLabel(String topic) {
    return 'Topic: $topic';
  }

  @override
  String quickJumpPartitionLabel(int partition) {
    return 'Partition: $partition';
  }

  @override
  String quickJumpOffsetLabel(int offset) {
    return 'Offset: $offset';
  }

  @override
  String quickJumpFilterLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String schemaRegistryUrlHint(String url) {
    return 'e.g. $url';
  }

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get fieldOptional => 'Field (Opt.)';

  @override
  String selectTopicsDialogTitle(int count, int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Select Topics ($filtered/$total)',
      one: 'Select Topic ($filtered/$total)',
    );
    return '$_temp0';
  }

  @override
  String get kafkaStreamTopics => 'Kafka Stream Topics';

  @override
  String get searchLabel => 'Search';

  @override
  String selectCount(int count) {
    return 'Select ($count)';
  }

  @override
  String get selectDateTime => 'Select Date & Time';

  @override
  String get presetsRelativeToNow => 'Presets (Relative to Now)';

  @override
  String get selectVersionsToCompare => 'Select versions to compare';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get unreadableStoredData => 'Unreadable stored data';

  @override
  String get tombstoneValueNull => 'TOMBSTONE (Value is NULL)';

  @override
  String lagChangeDelta(String delta) {
    return 'Change: $delta';
  }

  @override
  String ofTotal(String total) {
    return 'of $total';
  }

  @override
  String get activeStable => 'Active / Stable';

  @override
  String idleEmptyCount(String count) {
    return '$count Idle/Empty';
  }

  @override
  String get activeQueries => 'Active Queries';

  @override
  String queueCount(int count) {
    return 'Queue: $count';
  }

  @override
  String get connectingToCluster => 'Connecting to cluster...';

  @override
  String get establishingConnectionOffsets =>
      'Establishing connection and calculating consumer group offsets...';

  @override
  String get selectClusterForConsumerLag =>
      'Select a cluster above to view consumer lag details.';

  @override
  String loadedConsumerGroupsSummary(String count, String seconds) {
    return 'Successfully loaded $count consumer groups in ${seconds}s.';
  }

  @override
  String get groupIdCol => 'Group ID';

  @override
  String get stateCol => 'State';

  @override
  String get protocolCol => 'Protocol';

  @override
  String get consumersCol => 'Consumers';

  @override
  String get processedCol => 'Processed';

  @override
  String get noActivePartitionAssignments => 'No active partition assignments.';

  @override
  String noMessageAtOrAfterOffset(String offset) {
    return 'No message found at or after offset $offset';
  }

  @override
  String get viewMessageAtOffset => 'View message at offset';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get stateAll => 'All';

  @override
  String get stateStable => 'Stable';

  @override
  String get stateEmpty => 'Empty';

  @override
  String get stateDead => 'Dead';

  @override
  String get refreshIntervalLabel => 'Refresh';

  @override
  String get refreshOff => 'Off';

  @override
  String get scriptName => 'Script Name';

  @override
  String get sourceCol => 'Source';

  @override
  String get newVariableName => 'New Variable Name';

  @override
  String extractedVars(String vars) {
    return 'Extracted: $vars';
  }

  @override
  String usedVars(String vars) {
    return 'Used: $vars';
  }

  @override
  String get stepNameLabel => 'Step Name';

  @override
  String get valueExtractions => 'Value Extractions';

  @override
  String get noExtractionsDefined => 'No extractions defined';

  @override
  String get insertVariable => 'Insert Variable';

  @override
  String get deleteExtraction => 'Delete extraction';

  @override
  String filterByParameter(String parameter) {
    return 'Filter by $parameter';
  }

  @override
  String get searchValues => 'Search values';

  @override
  String get selectAllMatches => 'Select All Matches';

  @override
  String get clearSelection => 'Clear Selection';

  @override
  String get copyValue => 'Copy value';

  @override
  String copiedValueToClipboard(String value) {
    return 'Copied \'$value\' to clipboard';
  }

  @override
  String applyWithCount(int count) {
    return 'Apply ($count)';
  }

  @override
  String get noScriptsAvailable => 'No scripts available';

  @override
  String get executionProgress => 'Execution Progress';

  @override
  String get runningEllipsis => 'Running...';

  @override
  String get backTooltip => 'Back';

  @override
  String get failedToLoadDetails => 'Failed to load details';

  @override
  String get defaultLabel => 'Default';

  @override
  String clusterLabelValue(String cluster) {
    return 'Cluster: $cluster';
  }

  @override
  String clusterRuntimeLabel(String cluster, String runtime) {
    return 'Cluster: $cluster • $runtime';
  }

  @override
  String startedAt(String time) {
    return 'Started: $time';
  }

  @override
  String finishedAt(String time) {
    return 'Finished: $time';
  }

  @override
  String totalRuntime(String duration) {
    return 'Total Runtime: $duration';
  }

  @override
  String get runHistory => 'Run History';

  @override
  String get importRunArchive => 'Import Run Archive';

  @override
  String matchedAnalyzed(int matched, int analyzed) {
    return '$matched matched / $analyzed analyzed';
  }

  @override
  String get loadResults => 'Load Results';

  @override
  String get runAgain => 'Run Again';

  @override
  String get exportRunArchive => 'Export Run Archive';

  @override
  String get deleteRun => 'Delete Run';

  @override
  String get deleteRunResultTitle => 'Delete Run Result';

  @override
  String get deleteRunResultConfirm =>
      'Are you sure you want to delete this run result? This cannot be undone.';

  @override
  String failedToDeleteRun(String error) {
    return 'Failed to delete run: $error';
  }

  @override
  String noSchemaFieldsMatching(String query) {
    return 'No schema fields found matching \'$query\'';
  }

  @override
  String get noSchemasForScriptTopics =>
      'No schemas found for the current script\'s topics.';

  @override
  String fieldLabel(String field) {
    return 'Field: $field';
  }

  @override
  String foundTimesAcrossTopics(int count, int topics) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count times',
      one: 'Found 1 time',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topics,
      locale: localeName,
      other: '$topics topics',
      one: '1 topic',
    );
    return '$_temp0 across $_temp1';
  }

  @override
  String get copyMarkdown => 'Copy Markdown';

  @override
  String copiedSchemaToClipboard(String field) {
    return 'Copied $field schema to clipboard.';
  }

  @override
  String get downloadMarkdown => 'Download Markdown';

  @override
  String get savedSchemaToFile => 'Saved schema to file';

  @override
  String foundInTopic(String topic) {
    return 'Found in topic: $topic';
  }

  @override
  String pathLabel(String path) {
    return 'Path: $path';
  }

  @override
  String get foundInMultipleLocations =>
      'Found in multiple locations (differences highlighted):';

  @override
  String baselineTopic(String topic) {
    return 'Baseline Topic: $topic';
  }

  @override
  String comparedToTopic(String topic) {
    return 'Compared to Topic: $topic';
  }

  @override
  String get noDifferencesFromBaseline => 'No differences from baseline.';

  @override
  String get stepStatusPending => 'PENDING';

  @override
  String get stepStatusRunning => 'RUNNING';

  @override
  String get stepStatusCompleted => 'COMPLETED';

  @override
  String get stepStatusFailed => 'FAILED';

  @override
  String remainingCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted remaining',
      one: '$formatted remaining',
    );
    return '$_temp0';
  }

  @override
  String matchesFoundScanned(
    int matches,
    String formattedMatches,
    String formattedScanned,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$formattedMatches matches found ($formattedScanned scanned)',
      one: '$formattedMatches match found ($formattedScanned scanned)',
    );
    return '$_temp0';
  }

  @override
  String matchesFoundInTopics(int matches, int topics) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches matches',
      one: '1 match',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topics,
      locale: localeName,
      other: '$topics topics',
      one: '1 topic',
    );
    return '$_temp0 found in $_temp1';
  }

  @override
  String msgsCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted msgs',
      one: '$formatted msg',
    );
    return '$_temp0';
  }

  @override
  String msgsPerSecCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted msgs/sec',
      one: '$formatted msg/sec',
    );
    return '$_temp0';
  }

  @override
  String get emptyAngleBracket => '<empty>';

  @override
  String partitionOffsetSummary(int partition, int offset) {
    return 'Partition $partition • Offset $offset';
  }

  @override
  String get noStructuredFieldsDetected => 'No structured fields detected';

  @override
  String get noScalarValuesForField =>
      'No scalar values recorded for this field';

  @override
  String peakHourSummary(String hour, String count, String percentage) {
    return 'Peak: $hour:00 UTC ($count msgs • $percentage%)';
  }

  @override
  String hourlyTooltipSummary(String hour, String count, String percentage) {
    return '$hour:00 - $hour:59 UTC\n$count msgs ($percentage%)';
  }

  @override
  String get noKeyedMessagesFound => 'No keyed messages found';

  @override
  String get noContentTypesRecorded => 'No content types recorded';

  @override
  String partitionLabel(int partition) {
    return 'Partition $partition';
  }

  @override
  String partitionStatsLine(String count, String percentage, String size) {
    return '$count msgs ($percentage%) • $size';
  }

  @override
  String offsetsRange(String from, String to) {
    return 'Offsets: $from .. $to';
  }

  @override
  String get offsetsEmpty => 'Offsets: -';

  @override
  String durationPartitionsSummary(String duration, int partitions) {
    String _temp0 = intl.Intl.pluralLogic(
      partitions,
      locale: localeName,
      other: '$duration • $partitions partitions',
      one: '$duration • 1 partition',
    );
    return '$_temp0';
  }

  @override
  String analyzingTopicProgress(
    String scanned,
    String total,
    String percentage,
  ) {
    return 'Analyzing topic... ($scanned / $total messages • $percentage%)';
  }

  @override
  String get keyLabelWithColon => 'Key: ';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get editVariableTooltip => 'Edit variable';

  @override
  String get deleteVariableTooltip => 'Delete variable';

  @override
  String get addVariableTooltip => 'Add variable';

  @override
  String get editStepTooltip => 'Edit step';

  @override
  String get deleteStepTooltip => 'Delete step';

  @override
  String get browseDirectoryTooltip => 'Choose folder';

  @override
  String get expandTooltip => 'Expand';

  @override
  String get collapseTooltip => 'Collapse';

  @override
  String get selectStepTooltip => 'Select all topics in step';

  @override
  String get deselectStepTooltip => 'Deselect all topics in step';

  @override
  String filterColumnTooltip(String column) {
    return 'Filter $column';
  }

  @override
  String get removeColumnTooltip => 'Remove column';

  @override
  String get compositeBadgeTooltip => 'Show nested fields';

  @override
  String get skewedLabel => 'Skewed';

  @override
  String get copy => 'Copy';

  @override
  String get copyFailed => 'Failed to copy to clipboard';

  @override
  String get topicListUpdatedJustNow => 'updated just now';

  @override
  String topicListUpdatedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'updated $count min ago',
      one: 'updated 1 min ago',
    );
    return '$_temp0';
  }

  @override
  String topicListUpdatedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'updated $count hr ago',
      one: 'updated 1 hr ago',
    );
    return '$_temp0';
  }

  @override
  String topicListHiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden',
      one: '1 hidden',
    );
    return '$_temp0';
  }

  @override
  String topicListHiddenTooltip(int internal, int stream, int filter) {
    return 'Hidden: $internal internal, $stream stream, $filter filtered';
  }

  @override
  String get topicListShowAll => 'Show all';

  @override
  String get topicListInvalidPattern => 'Invalid pattern';

  @override
  String get topicListFilterModeSubstring => 'Text';

  @override
  String get topicListFilterModeGlob => 'Glob';

  @override
  String get topicListFilterModeRegex => 'Regex';

  @override
  String get topicListFilterModeTooltip => 'Filter mode';

  @override
  String get topicListSortTooltip => 'Sort topics';

  @override
  String get topicListSortName => 'Name (A–Z)';

  @override
  String get topicListSortPartitions => 'Partitions';

  @override
  String get topicListSortHealth => 'Health';

  @override
  String get topicListGroupByPrefixTooltip => 'Group by prefix';

  @override
  String get topicListFavouritesSection => 'Favourites';

  @override
  String get topicListAddFavouriteTooltip => 'Add to favourites';

  @override
  String get topicListRemoveFavouriteTooltip => 'Remove from favourites';

  @override
  String get topicListNotInList => 'not in topic list';

  @override
  String topicListRefreshFailedNotice(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get topicListPrefsUnreadableNotice =>
      'Saved topic list settings could not be read; using defaults.';

  @override
  String get topicListPrefsWriteBlockedNotice =>
      'Saved topic list settings could not be backed up and will not be overwritten.';

  @override
  String get topicConfigLoading => 'loading';

  @override
  String get topicConfigNotReadable => 'not readable — permission?';

  @override
  String get topicConfigLoadFailed => 'could not be loaded';

  @override
  String get topicMetadataNotFound => 'topic not found';

  @override
  String get topicMetadataUnknown => 'unknown';

  @override
  String topicPartitionsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Partitions',
      one: '1 Partition',
    );
    return '$_temp0';
  }

  @override
  String topicRfLabel(int count) {
    return 'RF: $count';
  }

  @override
  String topicOpenFailedNotice(String topic, String error) {
    return 'Could not open topic \"$topic\": $error';
  }

  @override
  String get cleanupPolicyNotReadableSubtitle => 'Not readable';

  @override
  String get cleanupPolicyUnknownBadge => '?';

  @override
  String get partitionOffsetSkewThresholdLabel =>
      'Partition skew threshold (%)';

  @override
  String get partitionOffsetSectionTitle =>
      'Estimated distribution (offset span)';

  @override
  String get partitionOffsetLoading => 'Loading partition offsets…';

  @override
  String partitionOffsetLoadError(String error) {
    return 'Could not load partition offsets: $error';
  }

  @override
  String get partitionOffsetRetry => 'Retry';

  @override
  String get partitionOffsetRefreshTooltip => 'Refresh offsets';

  @override
  String partitionOffsetReadAt(String time) {
    return 'Read at $time';
  }

  @override
  String partitionOffsetReadFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get partitionOffsetStaleNotice =>
      'Showing offsets from previous connection — cluster connection changed or disconnected.';

  @override
  String partitionOffsetTotalSpan(String span) {
    return 'Total offset span: $span';
  }

  @override
  String partitionOffsetKnownSpan(String span) {
    return 'Known offset span: $span';
  }

  @override
  String get partitionOffsetUnknownValue => 'unknown';

  @override
  String get partitionOffsetColumnPartition => 'Partition';

  @override
  String get partitionOffsetColumnLow => 'Low';

  @override
  String get partitionOffsetColumnHigh => 'High';

  @override
  String get partitionOffsetColumnSpan => 'Offset span';

  @override
  String get partitionOffsetColumnShare => 'Share';

  @override
  String get partitionOffsetStateNotReadable =>
      'Offsets not readable — permission?';

  @override
  String get partitionOffsetStateFailed => 'Read failed';

  @override
  String get partitionOffsetStateTimedOut => 'Timed out';

  @override
  String get partitionOffsetEstimateNote =>
      'High − low watermark only; not an exact message count.';

  @override
  String get partitionOffsetCompactedNote =>
      'Compacted topic: retained messages may be fewer than the offset span.';

  @override
  String get partitionOffsetPolicyUnknownNote =>
      'Cleanup policy unknown; topic may be compacted.';

  @override
  String get partitionOffsetIncompleteNote =>
      'Some partitions could not be read; total span and shares are unavailable.';

  @override
  String get partitionOffsetEmptyNote =>
      'All partitions are empty (total offset span is 0).';

  @override
  String partitionOffsetSkewBadge(int threshold) {
    return 'Skewed (≥ $threshold%)';
  }

  @override
  String partitionOffsetSkewRowTooltip(int threshold) {
    return 'Exceeds $threshold% share threshold';
  }

  @override
  String get partitionOffsetOpenAnalysisAction =>
      'Count exact messages in Analysis';

  @override
  String get retentionUnlimited => 'unlimited';

  @override
  String retentionBytesPerPartition(String size) {
    return '$size / partition';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get clusterOverviewRefreshTooltip => 'Refresh cluster overview';

  @override
  String clusterOverviewBrokersTitle(int count) {
    return 'Brokers ($count)';
  }

  @override
  String get clusterOverviewClusterIdLabel => 'Cluster ID';

  @override
  String get clusterOverviewControllerLabel => 'Controller';

  @override
  String clusterOverviewBrokerIdLabel(int id) {
    return 'Broker $id';
  }

  @override
  String get clusterOverviewBrokersLoading => 'Loading brokers…';

  @override
  String clusterOverviewBrokersError(String error) {
    return 'Could not load brokers: $error';
  }

  @override
  String get clusterOverviewBrokersNotReadable =>
      'Brokers not readable — permission?';

  @override
  String clusterOverviewTopicsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Topics',
      one: '1 Topic',
    );
    return '$_temp0';
  }

  @override
  String clusterOverviewPartitionsTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Partitions',
      one: '1 Partition',
    );
    return '$_temp0';
  }

  @override
  String get clusterOverviewTotalsLoading => 'Loading topic totals…';

  @override
  String get clusterOverviewTotalsUnknown =>
      'Topic & partition totals: unknown';

  @override
  String get clusterOverviewHealthHealthy =>
      'All topics fully replicated (0 unhealthy)';

  @override
  String clusterOverviewHealthUnhealthy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics with unhealthy partitions',
      one: '1 topic with unhealthy partitions',
    );
    return '$_temp0';
  }

  @override
  String clusterOverviewHealthPartitionCounts(
    int underReplicated,
    int leaderless,
  ) {
    return '$underReplicated under-replicated, $leaderless leaderless';
  }

  @override
  String clusterOverviewHealthUnknownCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics with unknown health',
      one: '1 topic with unknown health',
    );
    return '$_temp0';
  }

  @override
  String get clusterOverviewHealthStatusUnknown =>
      'Replication health: unknown';

  @override
  String get clusterOverviewHealthStatusLoading =>
      'Replication health: loading…';

  @override
  String get clusterOverviewShowUnhealthyTooltip =>
      'Filter topic list to unhealthy topics';

  @override
  String topicListUnhealthyOnlyChip(int count) {
    return 'Only unhealthy topics ($count)';
  }

  @override
  String get topicHeaderRefreshFactsTooltip => 'Refresh topic facts';

  @override
  String topicHeaderEstimateValue(String count) {
    return '≈ $count messages (estimate)';
  }

  @override
  String get topicHeaderEstimateCompactedNote =>
      'Compacted or unknown-policy topic: offset spans are not message counts; use Topic Analysis for exact counts.';

  @override
  String get topicHeaderEstimateUnknown => 'Messages: unknown';

  @override
  String get topicHeaderEstimateNotReadable => 'Messages: not readable';

  @override
  String topicHeaderRetentionLabel(String duration) {
    return 'Retention: $duration';
  }

  @override
  String topicHeaderRetentionBytesLabel(String size) {
    return 'Max size: $size';
  }

  @override
  String get topicHeaderRetentionNotReadable => 'not readable';

  @override
  String get topicHeaderLoadTimeRange => 'Load time range';

  @override
  String topicHeaderLoadTimeRangeTooltip(int count) {
    return 'Read oldest & newest message timestamps across $count partitions';
  }

  @override
  String get topicHeaderTimeRangeLoading => 'Loading time range…';

  @override
  String get topicHeaderTimeRangeEmpty => 'No messages';

  @override
  String topicHeaderTimeRangeValue(String oldest, String newest) {
    return '$oldest – $newest';
  }

  @override
  String topicHeaderTimeRangePartial(
    int oldestKnown,
    int newestKnown,
    int total,
  ) {
    return 'Partial ($oldestKnown/$total oldest, $newestKnown/$total newest)';
  }

  @override
  String get topicHeaderTimeRangeUnknown => 'Time range: unknown';

  @override
  String topicHeaderTimeRangeError(String error) {
    return 'Time range failed: $error';
  }

  @override
  String get topicModeConfig => 'Configuration';

  @override
  String get topicConfigRefreshTooltip => 'Refresh configuration';

  @override
  String get topicConfigNonDefaultToggle => 'Non-defaults only';

  @override
  String get topicConfigNonDefaultToggleTooltip =>
      'Show topic overrides, dynamic broker settings, and static broker settings';

  @override
  String get topicConfigDiffToggle => 'Only differences & non-defaults';

  @override
  String get topicConfigCompareAction => 'Compare…';

  @override
  String get topicConfigCloseComparisonAction => 'Close comparison';

  @override
  String get topicConfigCopyAsText => 'Copy as text';

  @override
  String get topicConfigCopiedToClipboard =>
      'Configuration copied to clipboard';

  @override
  String get topicConfigColumnName => 'Name';

  @override
  String get topicConfigColumnValue => 'Value';

  @override
  String get topicConfigColumnSource => 'Source';

  @override
  String get topicConfigColumnDefault => 'Default';

  @override
  String get topicConfigColumnLeftValue => 'Left value';

  @override
  String get topicConfigColumnLeftSource => 'Left source';

  @override
  String get topicConfigColumnRightValue => 'Right value';

  @override
  String get topicConfigColumnRightSource => 'Right source';

  @override
  String get topicConfigColumnStatus => 'Status';

  @override
  String get topicConfigDefaultYes => 'Default';

  @override
  String get topicConfigDefaultNo => 'Override';

  @override
  String get topicConfigSourceDynamicTopic => 'Topic override';

  @override
  String get topicConfigSourceDynamicBroker => 'Dynamic broker setting';

  @override
  String get topicConfigSourceDynamicDefaultBroker =>
      'Dynamic cluster-wide broker default';

  @override
  String get topicConfigSourceStaticBroker => 'Static broker setting';

  @override
  String get topicConfigSourceDefault => 'Built-in default';

  @override
  String get topicConfigSourceUnknown => 'Unknown';

  @override
  String get topicConfigStatusEqual => 'Equal';

  @override
  String get topicConfigStatusDifferent => 'Different';

  @override
  String get topicConfigStatusOnlyLeft => 'Only on left';

  @override
  String get topicConfigStatusOnlyRight => 'Only on right';

  @override
  String get topicConfigStatusNotComparable => 'Not comparable';

  @override
  String get topicConfigStatusUnknown => 'Unknown';

  @override
  String get topicConfigPlaceholderNoValue => 'no value';

  @override
  String get topicConfigPlaceholderSensitive => 'hidden (sensitive)';

  @override
  String get topicConfigPlaceholderUnknown => 'unknown';

  @override
  String get topicConfigUnavailableNotAuthorized =>
      'Not readable — missing DescribeConfigs permission?';

  @override
  String get topicConfigUnavailableNotFound => 'Topic not found';

  @override
  String topicConfigUnavailableFailed(String message) {
    return 'Could not read configuration: $message';
  }

  @override
  String get topicConfigEmptyReported => 'No configuration entries reported.';

  @override
  String get topicConfigEmptyNonDefaultFilter =>
      'All reported entries use default values.';

  @override
  String get topicConfigEmptyDiffFilter =>
      'Configurations do not differ and use only defaults.';

  @override
  String topicConfigDifferencesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count differences',
      one: '1 difference',
      zero: '0 differences',
    );
    return '$_temp0';
  }

  @override
  String get topicConfigDifferencesUnknown => 'Differences: unknown';

  @override
  String get topicConfigComparisonInProgress => 'Loading comparison…';

  @override
  String get topicConfigCompareDialogTitle => 'Compare Topic Configuration';

  @override
  String get topicConfigCompareProfileLabel => 'Target cluster profile';

  @override
  String get topicConfigCompareTopicLabel => 'Target topic';

  @override
  String get topicConfigCompareTopicHint => 'Enter or select topic name';

  @override
  String get topicConfigCompareSubmit => 'Compare';

  @override
  String get schemaRegistryErrorNotConfigured =>
      'Schema Registry is not configured for this profile.';

  @override
  String schemaRegistryErrorInvalidUrl(String detail) {
    return 'Schema Registry URL is invalid: $detail';
  }

  @override
  String get schemaRegistryErrorUnauthorized =>
      'Schema Registry authentication failed (HTTP 401). Check your username and password in the cluster profile.';

  @override
  String get schemaRegistryErrorForbidden =>
      'Schema Registry access denied (HTTP 403).';

  @override
  String get schemaRegistryErrorNotFound =>
      'Schema or subject not found in Schema Registry (HTTP 404).';

  @override
  String get schemaRegistryErrorTimeout => 'Schema Registry request timed out.';

  @override
  String schemaRegistryErrorUnreachable(String detail) {
    return 'Could not reach Schema Registry: $detail';
  }

  @override
  String schemaRegistryErrorCertificateRejected(String detail) {
    return 'Schema Registry TLS certificate was rejected: $detail';
  }

  @override
  String schemaRegistryErrorHttpStatus(int status, String detail) {
    return 'Schema Registry returned HTTP $status: $detail';
  }

  @override
  String schemaRegistryErrorHttpStatusNoCode(String detail) {
    return 'Schema Registry returned an error: $detail';
  }

  @override
  String schemaRegistryErrorInvalidResponse(String detail) {
    return 'Schema Registry returned an unexpected response: $detail';
  }

  @override
  String get schemaTypeAvro => 'Avro';

  @override
  String get schemaTypeProtobuf => 'Protobuf';

  @override
  String get schemaTypeJson => 'JSON Schema';

  @override
  String get schemaTypeGeneric => 'Schema';

  @override
  String get schemaTypeUnknown => 'Schema (unknown)';

  @override
  String schemaTypeMixed(String keyType, String valueType) {
    return '$keyType / $valueType';
  }

  @override
  String schemaTopicHasTypeTooltip(String typeLabel) {
    return 'Schema: $typeLabel';
  }

  @override
  String schemaVersionBadge(int version) {
    return 'v$version';
  }

  @override
  String schemaIdBadge(int id) {
    return 'ID $id';
  }

  @override
  String schemaCompatibilityPrefix(String level) {
    return 'Compatibility: $level';
  }

  @override
  String get schemaCompatibilitySubject => 'set on subject';

  @override
  String get schemaCompatibilityInherited => 'inherited';

  @override
  String schemaCompatibilityUnknown(String reason) {
    return 'Compatibility: unknown ($reason)';
  }

  @override
  String get schemaReferencesLabel => 'References:';

  @override
  String schemaReferenceChip(String name, String subject, int version) {
    return '$name ($subject v$version)';
  }

  @override
  String schemaMessagesLabel(String messages) {
    return 'Messages: $messages';
  }

  @override
  String schemaRawUnavailableNotice(String reason) {
    return 'Structured view unavailable: $reason';
  }

  @override
  String schemaUnsupportedTypeNotice(String type) {
    return 'Structured view is not supported for schema type $type.';
  }

  @override
  String get schemaCopyTooltip => 'Copy schema';

  @override
  String get schemaSaveTooltip => 'Save schema';

  @override
  String get schemaCopiedSnackBar => 'Schema copied to clipboard';

  @override
  String schemaSavedSuccess(String path) {
    return 'Schema saved to $path';
  }

  @override
  String schemaSaveFailed(String error) {
    return 'Failed to save schema: $error';
  }

  @override
  String get schemaSaveDialogTitle => 'Save Schema';

  @override
  String schemaViewerSubjectTitle(String subject) {
    return 'Schema: $subject';
  }

  @override
  String get schemaViewerBackTooltip => 'Back to previous schema';

  @override
  String get schemaViewerAssociatedTopicsLoading =>
      'Loading associated topics…';

  @override
  String schemaViewerAssociatedTopicsError(String error) {
    return 'Failed to resolve associated topics: $error';
  }

  @override
  String schemaViewerTopicNotOnCluster(String topic) {
    return '$topic (not on cluster)';
  }

  @override
  String get subjectBrowserFilterHint => 'Filter subjects…';

  @override
  String subjectBrowserCount(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String get subjectBrowserCountUnknown => 'Subjects: unknown';

  @override
  String subjectBrowserGlobalCompatibility(String level) {
    return 'Global compatibility: $level';
  }

  @override
  String get subjectBrowserEmptyRegistry =>
      'No subjects registered in Schema Registry.';

  @override
  String subjectBrowserNoMatch(String query) {
    return 'No subjects match \"$query\".';
  }

  @override
  String get subjectBrowserRefreshTooltip => 'Refresh subjects';

  @override
  String get subjectBrowserSideKey => 'Key';

  @override
  String get subjectBrowserSideValue => 'Value';

  @override
  String get explorerModeTopics => 'Topics';

  @override
  String get explorerModeSubjects => 'Subjects';

  @override
  String get explorerModeSwitcherSemantics => 'Browse mode: Topics or Subjects';

  @override
  String get analysisConfirmThresholdLabel =>
      'Large-scan confirmation threshold (messages)';

  @override
  String get analysisHistoryPerTopicLabel => 'Saved analysis reports per topic';

  @override
  String get deleteSavedAnalysisReports => 'Delete saved analysis reports';

  @override
  String get deleteSavedAnalysisReportsConfirmTitle =>
      'Delete all saved analysis reports?';

  @override
  String get deleteSavedAnalysisReportsConfirmBody =>
      'This removes all locally stored topic analysis reports across all clusters. Exported files elsewhere are not affected.';

  @override
  String get deleteSavedAnalysisReportsSuccess =>
      'Saved analysis reports deleted.';

  @override
  String deleteSavedAnalysisReportsFailed(String error) {
    return 'Could not delete all saved analysis reports: $error';
  }

  @override
  String scopeSummaryButtonLabel(String summary) {
    return 'Scope: $summary';
  }

  @override
  String get scopeSummaryAll => 'All messages';

  @override
  String scopeSummaryNewest(String count) {
    return 'Newest $count';
  }

  @override
  String scopeSummaryOldest(String count) {
    return 'Oldest $count';
  }

  @override
  String scopeSummaryPartitions(String list) {
    return 'partitions $list';
  }

  @override
  String get scopeDialogTitle => 'Analysis Scope';

  @override
  String get scopeModeAll => 'All';

  @override
  String get scopeModeNewest => 'Newest';

  @override
  String get scopeModeOldest => 'Oldest';

  @override
  String get scopeMessageLimitLabel => 'Message limit (up to N offsets)';

  @override
  String get scopeMessageLimitHelper =>
      'Count is in offsets; compacted or transactional topics may yield fewer messages.';

  @override
  String get scopeTimeRangeLabel =>
      'Time range (optional, resolved via broker timestamp index)';

  @override
  String get scopeStartTimestampLabel => 'Start timestamp';

  @override
  String get scopeEndTimestampLabel => 'End timestamp';

  @override
  String get scopePartitionsLabel => 'Partitions';

  @override
  String get scopeAllPartitionsChip => 'All partitions';

  @override
  String scopePartitionChipLabel(int id) {
    return 'P$id';
  }

  @override
  String get scopeErrorInvalidCount =>
      'Enter a positive integer message limit.';

  @override
  String get scopeErrorInvalidStartTimestamp =>
      'Invalid start timestamp format.';

  @override
  String get scopeErrorInvalidEndTimestamp => 'Invalid end timestamp format.';

  @override
  String get scopeErrorStartAfterEnd =>
      'Start timestamp must be before end timestamp.';

  @override
  String get scopeErrorNoPartitions => 'Select at least one partition.';

  @override
  String get scopeApplyButton => 'Apply';

  @override
  String get scopeEstimating => 'Estimating…';

  @override
  String get scopeConfirmTitle => 'Start large analysis?';

  @override
  String scopeConfirmPlannedCount(String count) {
    return 'Estimated scan size: $count offsets.';
  }

  @override
  String scopeConfirmAtLeastCount(String count) {
    return 'Estimated scan size: at least $count offsets.';
  }

  @override
  String scopeConfirmSizeUnknown(String error) {
    return 'Scan size unknown ($error). Start anyway?';
  }

  @override
  String get scopeConfirmUnreadableHeader => 'Unreadable partitions:';

  @override
  String scopeConfirmUnreadableItem(int partition, String reason) {
    return 'Partition $partition: $reason';
  }

  @override
  String get scopeConfirmCompactedHint =>
      'This is a compacted topic; the actual message count may be lower than the offset range.';

  @override
  String get scopeConfirmStartButton => 'Start Scan';

  @override
  String historySaveErrorBanner(String error) {
    return 'Could not save report to local history: $error';
  }

  @override
  String get reportScopeCardTitle => 'Scan Scope';

  @override
  String get reportScopeNotRecorded => 'Scope not recorded for this report.';

  @override
  String reportScopeExcludedByTime(String count) {
    return 'Excluded by time range: $count';
  }

  @override
  String reportScopeUnreadablePartitions(String list) {
    return 'Unreadable partitions: $list';
  }

  @override
  String get analysisLimitsCardTitle => 'Analysis Limits';

  @override
  String get analysisLimitsNotAvailable => 'Not available for this report.';

  @override
  String get analysisLimitReached => 'Reached';

  @override
  String get analysisLimitWithin => 'Within limit';

  @override
  String get limitKindTrackedFields => 'Tracked fields';

  @override
  String get limitKindListedFields => 'Listed fields';

  @override
  String get limitKindValuesPerField => 'Values per field';

  @override
  String get limitKindListedValuesPerField => 'Listed values per field';

  @override
  String get limitKindFieldDepth => 'Field nesting depth';

  @override
  String get limitKindValueDisplayChars => 'Value display length (chars)';

  @override
  String get limitKindTrackedKeys => 'Tracked keys';

  @override
  String get limitKindListedKeys => 'Listed keys';

  @override
  String get limitKindSizePercentileSample => 'Size percentile sample';

  @override
  String get limitKindTrackedFingerprints => 'Tracked duplicate fingerprints';

  @override
  String get limitKindDuplicateSamples => 'Duplicate samples';

  @override
  String get limitKindListedDuplicates => 'Listed duplicates';

  @override
  String get limitKindPreviewChars => 'Payload preview length (chars)';

  @override
  String get limitKindTimelineWindowDays => 'Timeline window (days)';

  @override
  String fieldTrackedCountSummary(String shown, String total) {
    return '$shown of $total fields';
  }

  @override
  String get fieldFurtherNotTracked => 'Further fields not tracked';

  @override
  String get duplicateEstimatedAtLeast => 'Estimated (at least)';

  @override
  String duplicateUntrackedCount(String count) {
    return '$count untracked messages';
  }

  @override
  String get duplicateListPossiblyIncomplete => 'List possibly incomplete';

  @override
  String get historyMenuFromFile => 'From file…';

  @override
  String get historyMenuEmpty => 'No saved reports for this topic';

  @override
  String historyMenuUnreadable(int count) {
    return '$count unreadable file(s) skipped';
  }

  @override
  String historyMenuLoadError(String error) {
    return 'Could not load history: $error';
  }

  @override
  String historyEntrySubtitle(String scope, String messages) {
    return '$scope · $messages messages';
  }

  @override
  String get comparisonScopeNotRecorded => 'Scope not recorded';

  @override
  String get comparisonScopesDifferWarning =>
      'Comparison scopes differ — deltas may reflect scope differences rather than data changes.';

  @override
  String get comparisonScopeMissingWarning =>
      'Scope is not recorded on one or both reports — they cannot be reliably compared.';

  @override
  String timelinePartitionSubsetNote(String partitions) {
    return 'Note: Timeline covers only a subset of partitions ($partitions).';
  }

  @override
  String diffIgnoredFieldsHeader(int count) {
    return 'Ignored fields ($count)';
  }

  @override
  String get diffIgnoredFieldsButton => 'Ignored fields';

  @override
  String diffIgnoreDialogTitle(String topic) {
    return 'Ignored fields — $topic';
  }

  @override
  String get diffIgnorePathHint => 'Field path (e.g. meta.ts or /items/0/id)';

  @override
  String get diffIgnoreAddButton => 'Add';

  @override
  String diffIgnoreRemoveTooltip(String path) {
    return 'Remove ignored field $path';
  }

  @override
  String get diffIgnoreEmptyList => 'No ignored fields for this topic.';

  @override
  String get diffIgnoreSuggestionsTitle => 'Suggested volatile fields';

  @override
  String get ignoreThisField => 'Ignore this field';

  @override
  String diffHiddenCount(int count) {
    return 'Hidden ($count)';
  }

  @override
  String diffTruncatedNotice(int count) {
    return '$count more differences not shown';
  }

  @override
  String diffIgnoreLoadWarning(String topic) {
    return 'Could not read saved ignore list for $topic.';
  }

  @override
  String get diffIgnoreSaveError =>
      'Failed to save ignore list. Change was not persisted.';

  @override
  String get diffIgnoreEmptyPathError => 'Enter a non-empty field path.';

  @override
  String get diffIgnoreDuplicatePathError =>
      'This field path is already ignored.';

  @override
  String get filterExpressionLabel => 'Filter expression';

  @override
  String get filterExpressionHint =>
      'e.g. value.status = \"FAILED\" AND partition = 0';

  @override
  String filterExpressionChipSummary(String expr) {
    return 'Expr: $expr';
  }

  @override
  String get filterExpressionInvalidTooltip => 'Invalid filter expression';

  @override
  String get filterExpressionModeBuilder => 'Builder';

  @override
  String get filterExpressionModeText => 'Text';

  @override
  String filterExpressionErrorAtColumn(int column, String message) {
    return 'Column $column: $message';
  }

  @override
  String get filterExpressionAddCondition => 'Add condition';

  @override
  String get filterExpressionAddGroup => 'Add group';

  @override
  String get filterExpressionNotToggle => 'NOT';

  @override
  String get filterExpressionAndLabel => 'AND';

  @override
  String get filterExpressionOrLabel => 'OR';

  @override
  String get filterExpressionRemoveNode => 'Remove';

  @override
  String get filterExpressionEditCondition => 'Edit condition';

  @override
  String get filterExpressionSourceLabel => 'Source';

  @override
  String get filterExpressionPathLabel => 'Path / Header';

  @override
  String get filterExpressionOperatorLabel => 'Operator';

  @override
  String get filterExpressionValueLabel => 'Value';

  @override
  String get filterExpressionTypeString => 'Text';

  @override
  String get filterExpressionTypeNumber => 'Number';

  @override
  String get filterExpressionTypeBoolean => 'Boolean';

  @override
  String get filterExpressionTypeNull => 'Null';

  @override
  String get filterExpressionTypeVariable => 'Variable';

  @override
  String get filterExpressionPlaceholderHint =>
      'Multi-value script variables match if ANY value satisfies the condition.';

  @override
  String get filterExpressionSuggestionsLabel => 'Field suggestions';

  @override
  String get filterExpressionSuggestionsSourceSchema => 'From schema';

  @override
  String get filterExpressionSuggestionsSourceAnalysis => 'From analysis';

  @override
  String get filterExpressionSuggestionsSourceSample => 'From loaded messages';

  @override
  String get filterExpressionSuggestionsEmpty =>
      'No field suggestions available';

  @override
  String get filterExpressionOpEq => '=';

  @override
  String get filterExpressionOpNe => '!=';

  @override
  String get filterExpressionOpGt => '>';

  @override
  String get filterExpressionOpGe => '>=';

  @override
  String get filterExpressionOpLt => '<';

  @override
  String get filterExpressionOpLe => '<=';

  @override
  String get filterExpressionOpContains => 'contains';

  @override
  String get filterExpressionOpStartsWith => 'startsWith';

  @override
  String get filterExpressionOpEndsWith => 'endsWith';

  @override
  String get filterExpressionOpMatches => 'matches';

  @override
  String get filterExpressionOpIn => 'in';

  @override
  String get filterExpressionOpExists => 'exists';

  @override
  String get filterExpressionOpIsNull => 'is null';

  @override
  String get filterExpressionOpIsNotNull => 'is not null';

  @override
  String localSchemaDialogTitle(String side) {
    return 'Assign Local Schema ($side)';
  }

  @override
  String get localSchemaSideKey => 'Key';

  @override
  String get localSchemaSideValue => 'Value';

  @override
  String get localSchemaFileLabel => 'Schema file';

  @override
  String get localSchemaChooseFile => 'Choose file…';

  @override
  String get localSchemaNoFileSelected => 'No file selected';

  @override
  String get localSchemaFormatLabel => 'Format';

  @override
  String get localSchemaFormatAvro => 'Avro (.avsc)';

  @override
  String get localSchemaFormatProtobufSource => 'Protobuf source (.proto)';

  @override
  String get localSchemaFormatProtobufDescriptor =>
      'Protobuf descriptor set (.desc)';

  @override
  String get localSchemaFormatJsonSchema => 'JSON Schema (.json)';

  @override
  String get localSchemaMessageTypeLabel => 'Message type';

  @override
  String get localSchemaMessageTypeHint => 'Select a message type';

  @override
  String get localSchemaFramingLabel => 'Framing';

  @override
  String get localSchemaFramingAuto => 'Auto';

  @override
  String get localSchemaFramingPrefixed => 'Confluent prefixed';

  @override
  String get localSchemaFramingRaw => 'Raw payload';

  @override
  String get localSchemaModeLabel => 'Precedence';

  @override
  String get localSchemaModeFallback => 'Fallback (registry first)';

  @override
  String get localSchemaModeAlways => 'Always (skip registry)';

  @override
  String get localSchemaPreviewTitle => 'Field preview';

  @override
  String get localSchemaPreviewEmpty => 'No fields extracted';

  @override
  String get localSchemaRemoveAction => 'Remove';

  @override
  String get localSchemaSaveAction => 'Save';

  @override
  String get localSchemaProto2DescriptorHint =>
      'Compile with protoc --include_imports --descriptor_set_out=<file>.desc and select the descriptor file.';

  @override
  String get localSchemaCardTitle => 'Local schema';

  @override
  String get localSchemaAssignAction => 'Assign local schema';

  @override
  String get localSchemaChangeAction => 'Change';

  @override
  String get localSchemaConfirmChangedAction => 'Confirm updated file';

  @override
  String get localSchemaStateUsable => 'Ready';

  @override
  String get localSchemaStateChanged => 'File modified since assignment';

  @override
  String get localSchemaStateFileNotFound => 'File not found';

  @override
  String get localSchemaStateFileUnreadable => 'File unreadable';

  @override
  String get localSchemaStateSchemaInvalid => 'Schema invalid';

  @override
  String get localSchemaStateMessageTypeMissing => 'Message type not found';

  @override
  String get localSchemaStateUnknown => 'Unverified';

  @override
  String localSchemaTagPrefix(String type) {
    return 'Local: $type';
  }

  @override
  String localSchemaUnreadableBanner(String reason) {
    return 'Stored local schema assignment could not be read: $reason';
  }

  @override
  String localSchemaProvenanceDecoded(String fileName, String format) {
    return 'Decoded using local schema: $fileName ($format)';
  }

  @override
  String localSchemaProvenanceDecodedWithMsg(
    String fileName,
    String format,
    String messageType,
  ) {
    return 'Decoded using local schema: $fileName ($format, $messageType)';
  }

  @override
  String localSchemaProvenanceFailed(String fileName) {
    return 'Local schema decode failed ($fileName)';
  }

  @override
  String get localSchemaCardBadgeKey => 'K: local';

  @override
  String get localSchemaCardBadgeValue => 'V: local';

  @override
  String get localSchemaCardBadgeKeyError => 'K: local !';

  @override
  String get localSchemaCardBadgeValueError => 'V: local !';

  @override
  String get localSchemaAnalysisNotice =>
      'Some messages in this analysis were decoded using a local schema.';

  @override
  String localDecodeErrorFileNotFound(String detail) {
    return 'Schema file not found: $detail';
  }

  @override
  String localDecodeErrorFileUnreadable(String detail) {
    return 'Could not read schema file: $detail';
  }

  @override
  String localDecodeErrorFileTooLarge(String detail) {
    return 'Schema file exceeds the 10 MiB limit: $detail';
  }

  @override
  String localDecodeErrorSchemaInvalid(String detail) {
    return 'Invalid schema: $detail';
  }

  @override
  String localDecodeErrorUnsupportedProto2(String detail) {
    return 'Proto2 source files are not supported directly; compile to a FileDescriptorSet (.desc) instead. ($detail)';
  }

  @override
  String localDecodeErrorUnresolvedImport(String detail) {
    return 'Unresolved import in schema: $detail. Compile with protoc --include_imports --descriptor_set_out=...';
  }

  @override
  String localDecodeErrorMessageTypeNotFound(String detail) {
    return 'Message type not found in schema: $detail';
  }

  @override
  String localDecodeErrorMissingPrefix(String detail) {
    return 'Expected Confluent 5-byte wire prefix, but payload did not start with magic byte 0x00: $detail';
  }

  @override
  String localDecodeErrorUnknownMessageIndex(String detail) {
    return 'Unknown Protobuf message index in wire prefix: $detail';
  }

  @override
  String localDecodeErrorPayloadMismatch(String detail) {
    return 'Payload does not match schema: $detail';
  }

  @override
  String localDecodeErrorTrailingBytes(String detail) {
    return 'Unexpected trailing bytes after decoded payload: $detail';
  }

  @override
  String localDecodeErrorNotJson(String detail) {
    return 'Payload is not valid UTF-8 JSON: $detail';
  }

  @override
  String get fetchFilterPlaceholderBoth =>
      'Filter while fetching (key & value)...';

  @override
  String get fetchFilterPlaceholderKey => 'Filter while fetching (key only)...';

  @override
  String get fetchFilterPlaceholderValue =>
      'Filter while fetching (value only)...';

  @override
  String get fetchFilterTooltip =>
      'Filters messages while reading from the topic (limits which messages are fetched).';

  @override
  String fetchFilterScopeTypeSummary(String scope, String type) {
    return '$scope · $type';
  }

  @override
  String get fetchFilterMenuTooltip =>
      'Change fetch filter scope and match type';

  @override
  String get moreFiltersButton => 'More filters';

  @override
  String moreFiltersButtonWithCount(int count) {
    return 'More filters ($count)';
  }

  @override
  String get moreFiltersOpenTooltip => 'Show more fetch filters';

  @override
  String get moreFiltersCloseTooltip => 'Hide more fetch filters';

  @override
  String get timePresetsMenuTooltip => 'Relative time presets';

  @override
  String get timeRangeEndBeforeStartError =>
      'End time must not be before start time.';

  @override
  String get timeRangeInvalidTimestampError => 'Invalid timestamp format.';

  @override
  String topicFactsMoreCount(int count) {
    return '$count more topic facts';
  }
}
