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
  String get explorer => 'Explorer';

  @override
  String get scripts => 'Scripts';

  @override
  String get orders => 'Orders';

  @override
  String get settings => 'Settings';

  @override
  String get consumerLag => 'Consumer Lag';

  @override
  String get consumerGroups => 'Consumer Groups';

  @override
  String get noConsumerGroupsFound => 'No consumer groups found.';

  @override
  String get totalLag => 'Total Lag';

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
  String get searchGroups => 'Search consumer groups...';

  @override
  String get unknownView => 'Unknown View';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get now => 'Now';

  @override
  String get ago => 'ago';

  @override
  String get custom => 'Custom';

  @override
  String get quickTimeSelection => 'Quick Time Selection';

  @override
  String get editVariable => 'Edit Variable';

  @override
  String get name => 'Name';

  @override
  String get type => 'Type';

  @override
  String get source => 'Source';

  @override
  String get usedIn => 'Used In';

  @override
  String get actions => 'Actions';

  @override
  String get addStep => 'Add Step';

  @override
  String get unnamedStep => 'Unnamed Step';

  @override
  String get steps => 'Steps';

  @override
  String get variables => 'Variables';

  @override
  String get general => 'General';

  @override
  String get clusterConfiguration => 'Cluster Configuration';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String get addCluster => 'Add Cluster';

  @override
  String get deleteCluster => 'Delete Cluster';

  @override
  String deleteClusterConfirmation(String clusterName) {
    return 'Are you sure you want to delete $clusterName?';
  }

  @override
  String get clustersImportedSuccessfully => 'Clusters imported successfully';

  @override
  String failedToImport(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get clustersExportedSuccessfully => 'Clusters exported successfully';

  @override
  String failedToExport(String error) {
    return 'Failed to export: $error';
  }

  @override
  String get noActiveStreams => 'No active streams';

  @override
  String get clearAll => 'Clear All';

  @override
  String get viewAll => 'View All';

  @override
  String get stop => 'Stop';

  @override
  String get stream => 'Stream';

  @override
  String get messageDetails => 'Message Details';

  @override
  String get copyMessage => 'Copy message';

  @override
  String get fullMessageCopied => 'Full message copied to clipboard';

  @override
  String get metadataCopied => 'Metadata copied to clipboard';

  @override
  String get contentCopied => 'Content copied to clipboard';

  @override
  String get raw => 'Raw';

  @override
  String get tree => 'Tree';

  @override
  String get cards => 'Cards';

  @override
  String get loadOrders => 'Load Orders';

  @override
  String get noOrdersFound => 'No orders found. Click Load to search.';

  @override
  String get noOrdersMatchFilter => 'No orders match the filter.';

  @override
  String get pleaseSelectCluster => 'Please select a cluster';

  @override
  String failedToLoadOrders(String error) {
    return 'Failed to load orders: $error';
  }

  @override
  String get run => 'Run';

  @override
  String get newRun => 'New Run';

  @override
  String get noVariablesRequired => 'No variables required.';

  @override
  String get noPastRunsFound => 'No past runs found.';

  @override
  String get runArchiveImported => 'Run archive imported';

  @override
  String failedToImportRun(String error) {
    return 'Failed to import run: $error';
  }

  @override
  String get runArchiveExported => 'Run archive exported';

  @override
  String get deleteRunResult => 'Delete Run Result';

  @override
  String get deleteRunResultConfirmation =>
      'Are you sure you want to delete this run result?';

  @override
  String get runResultDeleted => 'Run result deleted';

  @override
  String get allMessages => 'All Messages';

  @override
  String get otherResults => 'Other Results';

  @override
  String noResultsFound(String phrase) {
    return 'No results found matching \'$phrase\'';
  }

  @override
  String get editStep => 'Edit Step';

  @override
  String get addExtraction => 'Add Extraction';

  @override
  String get switchLightMode => 'Switch to Light Mode';

  @override
  String get switchDarkMode => 'Switch to Dark Mode';

  @override
  String get defaultScriptOutputDir => 'Default Script Output Directory';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get active => 'Active';

  @override
  String get edit => 'Edit';

  @override
  String get simulateOrder => 'Simulate Order';

  @override
  String get cluster => 'Cluster';

  @override
  String get maxOrders => 'Max Orders';

  @override
  String get filterByMessageId => 'Filter by Message ID, CORID or PMXCOR ID';

  @override
  String get enterMessageIdToFilter =>
      'Enter message ID, CORID or PMXCOR ID...';

  @override
  String showingOrders(int filtered, int total) {
    return 'Showing $filtered of $total orders';
  }

  @override
  String get aiAnalysisDataAvailable => 'AI Analysis Data Available';

  @override
  String pmxcorStatus(String status) {
    return '$status';
  }

  @override
  String get statusOpen => 'OPEN';

  @override
  String get statusAnalyzing => 'AI ANALYSIS STARTED';

  @override
  String get statusCompleted => 'AI ANALYSIS DONE';

  @override
  String get statusFailed => 'FAILED';

  @override
  String get clusters => 'CLUSTERS';

  @override
  String get selectClusterToViewTopics => 'Select a cluster to view topics';

  @override
  String get topics => 'Topics';

  @override
  String clusterLabel(String name) {
    return 'Cluster: $name';
  }

  @override
  String get showInternal => 'Show internal';

  @override
  String get reloadTopicsAndSchemas => 'Reload Topics & Schemas';

  @override
  String get filterTopics => 'Filter topics...';

  @override
  String get selectOutputDirectory => 'Select Output Directory';

  @override
  String get topic => 'Topic';

  @override
  String get scope => 'Scope';

  @override
  String get contains => 'Contains';

  @override
  String get regex => 'Regex';

  @override
  String get exact => 'Exact';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get both => 'Both';

  @override
  String get fastTrace => 'Fast Trace (Hash Key)';

  @override
  String get limit => 'Limit';

  @override
  String get limitOrders => 'Enable order limit';

  @override
  String get partitionOptional => 'Partition (Opt.)';

  @override
  String get importScripts => 'Import Scripts';

  @override
  String get exportSelectedScript => 'Export Selected Script';

  @override
  String get exportScript => 'Export Script';

  @override
  String get createNewScript => 'Create New Script';

  @override
  String get scriptsImportedSuccessfully => 'Scripts imported successfully';

  @override
  String get scriptExportedSuccessfully => 'Script exported successfully';

  @override
  String get history => 'History';

  @override
  String get editDefinition => 'Edit Definition';

  @override
  String get newScript => 'New Script';

  @override
  String get useSidebarToSelectScript =>
      'Use the sidebar to select or create a script.';

  @override
  String get configuration => 'Configuration';

  @override
  String get exportConfiguration => 'Export Configuration';

  @override
  String get importConfiguration => 'Import Configuration';

  @override
  String get configurationExportedSuccessfully =>
      'Configuration exported successfully';

  @override
  String get configurationImportedSuccessfully =>
      'Configuration imported successfully';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get reviewPreviousRuns => 'Review Previous Runs';

  @override
  String get maxScriptRunHistory => 'Max Script Runs to keep';

  @override
  String scriptExecution(String name) {
    return 'Script Execution: $name';
  }

  @override
  String get selectValidScript => 'Please select a valid script first.';

  @override
  String get rerunNotIntegrated =>
      'Rerun from history is not fully integrated in Orders View yet.';

  @override
  String get kiError => 'AI Error';

  @override
  String totalOrders(int total) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString Orders';
  }

  @override
  String get limitResults => 'Limit results';

  @override
  String get maxResults => 'Max Results';

  @override
  String get startCondition => 'Start Condition';

  @override
  String get stopCondition => 'Stop Condition';

  @override
  String get startOffset => 'Start Offset';

  @override
  String get startTimestamp => 'Start Timestamp';

  @override
  String get endOffset => 'End Offset';

  @override
  String get endTimestamp => 'End Timestamp';

  @override
  String get end => 'End';

  @override
  String get latest => 'Latest';

  @override
  String get earliest => 'Earliest';

  @override
  String get offset => 'Offset';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get duplicateScript => 'Duplicate Script';

  @override
  String get searchingForOrders => 'Searching for orders...';

  @override
  String searchingInTopic(String topic) {
    return 'Searching in: $topic';
  }

  @override
  String topicsProgress(int completed, int total) {
    return 'Completed $completed of $total topics';
  }

  @override
  String scannedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Scanned: $countString';
  }

  @override
  String get noProgressInfo => 'No progress info';

  @override
  String get runSummary => 'Run Summary';

  @override
  String get runDetails => 'Run Details';

  @override
  String get parameters => 'Parameters';

  @override
  String examinedMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Examined: $countString messages';
  }

  @override
  String firstAppearanceForKey(String key) {
    return 'First appearance for Key: $key';
  }

  @override
  String get noDifferencesFound => 'No differences found.';

  @override
  String get chronological => 'Chronological';

  @override
  String get byTopic => 'By Topic';

  @override
  String get byStep => 'By Step';

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
  String stepMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString matches';
  }

  @override
  String get searchResults => 'Search results...';

  @override
  String scanned(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString scanned';
  }

  @override
  String get exportMessages => 'Export Messages';

  @override
  String get messagesExportedSuccessfully => 'Messages exported successfully';

  @override
  String messagesExportFailed(String error) {
    return 'Failed to export messages: $error';
  }
}
