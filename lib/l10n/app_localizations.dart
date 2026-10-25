import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kafkalyzer'**
  String get appTitle;

  /// No description provided for @topicAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Topic Analysis'**
  String get topicAnalysis;

  /// No description provided for @messagesView.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesView;

  /// No description provided for @startAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start Analysis'**
  String get startAnalysis;

  /// No description provided for @stopAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Stop Analysis'**
  String get stopAnalysis;

  /// No description provided for @analyzingTopic.
  ///
  /// In en, this message translates to:
  /// **'Analyzing topic...'**
  String get analyzingTopic;

  /// No description provided for @analysisComplete.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete'**
  String get analysisComplete;

  /// No description provided for @scanScope.
  ///
  /// In en, this message translates to:
  /// **'Scan Scope'**
  String get scanScope;

  /// No description provided for @fullTopicScan.
  ///
  /// In en, this message translates to:
  /// **'Full Scan (All Messages)'**
  String get fullTopicScan;

  /// No description provided for @sampleLast10k.
  ///
  /// In en, this message translates to:
  /// **'Sample Last 10,000 Messages'**
  String get sampleLast10k;

  /// No description provided for @sampleLast50k.
  ///
  /// In en, this message translates to:
  /// **'Sample Last 50,000 Messages'**
  String get sampleLast50k;

  /// No description provided for @sampleLast100k.
  ///
  /// In en, this message translates to:
  /// **'Sample Last 100,000 Messages'**
  String get sampleLast100k;

  /// No description provided for @totalMessages.
  ///
  /// In en, this message translates to:
  /// **'Total Messages'**
  String get totalMessages;

  /// No description provided for @totalPayloadSize.
  ///
  /// In en, this message translates to:
  /// **'Total Payload Size'**
  String get totalPayloadSize;

  /// No description provided for @avgMessageSize.
  ///
  /// In en, this message translates to:
  /// **'Avg Message Size'**
  String get avgMessageSize;

  /// No description provided for @minMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Min / Max Size'**
  String get minMaxSize;

  /// No description provided for @tombstones.
  ///
  /// In en, this message translates to:
  /// **'Tombstones'**
  String get tombstones;

  /// No description provided for @tombstoneRatio.
  ///
  /// In en, this message translates to:
  /// **'Tombstone Ratio'**
  String get tombstoneRatio;

  /// No description provided for @compactedTopic.
  ///
  /// In en, this message translates to:
  /// **'Compacted Topic'**
  String get compactedTopic;

  /// No description provided for @nonCompactedTopic.
  ///
  /// In en, this message translates to:
  /// **'Delete Retention Topic'**
  String get nonCompactedTopic;

  /// No description provided for @nullKeys.
  ///
  /// In en, this message translates to:
  /// **'Null Keys'**
  String get nullKeys;

  /// No description provided for @keyedMessages.
  ///
  /// In en, this message translates to:
  /// **'Keyed Messages'**
  String get keyedMessages;

  /// No description provided for @hourlyPeakProduction.
  ///
  /// In en, this message translates to:
  /// **'Hourly Production Peaks (24h UTC)'**
  String get hourlyPeakProduction;

  /// No description provided for @partitionUtilization.
  ///
  /// In en, this message translates to:
  /// **'Partition Utilization & Balance'**
  String get partitionUtilization;

  /// No description provided for @topKeys.
  ///
  /// In en, this message translates to:
  /// **'Top Message Keys'**
  String get topKeys;

  /// No description provided for @contentTypeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Content Types'**
  String get contentTypeBreakdown;

  /// No description provided for @fieldFrequencies.
  ///
  /// In en, this message translates to:
  /// **'Structured Field Frequencies'**
  String get fieldFrequencies;

  /// No description provided for @fieldValuesDistribution.
  ///
  /// In en, this message translates to:
  /// **'Top Values'**
  String get fieldValuesDistribution;

  /// No description provided for @noAnalysisYet.
  ///
  /// In en, this message translates to:
  /// **'No analysis data yet. Click Start Analysis to profile this topic.'**
  String get noAnalysisYet;

  /// No description provided for @exportAnalysisReport.
  ///
  /// In en, this message translates to:
  /// **'Export Analysis Report'**
  String get exportAnalysisReport;

  /// No description provided for @importAnalysisReport.
  ///
  /// In en, this message translates to:
  /// **'Import Analysis Report'**
  String get importAnalysisReport;

  /// No description provided for @importedFromTime.
  ///
  /// In en, this message translates to:
  /// **'Imported from {cluster} at {time}'**
  String importedFromTime(String cluster, String time);

  /// No description provided for @unknownCluster.
  ///
  /// In en, this message translates to:
  /// **'unknown cluster'**
  String get unknownCluster;

  /// No description provided for @analysisExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Analysis report exported successfully'**
  String get analysisExportedSuccessfully;

  /// No description provided for @analysisImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Analysis report imported successfully'**
  String get analysisImportedSuccessfully;

  /// No description provided for @importNotAValidAnalysisFile.
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid Kafkalyzer analysis report.'**
  String get importNotAValidAnalysisFile;

  /// No description provided for @importUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This analysis file uses an unsupported version ({version}).'**
  String importUnsupportedVersion(String version);

  /// No description provided for @importMalformed.
  ///
  /// In en, this message translates to:
  /// **'This analysis file could not be read.'**
  String get importMalformed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export the analysis report.'**
  String get exportFailed;

  /// No description provided for @scanSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed} msgs/sec'**
  String scanSpeed(String speed);

  /// No description provided for @scanDuration.
  ///
  /// In en, this message translates to:
  /// **'Scan duration: {duration}'**
  String scanDuration(String duration);

  /// No description provided for @hotPartition.
  ///
  /// In en, this message translates to:
  /// **'High Load / Skew'**
  String get hotPartition;

  /// No description provided for @balancedPartitions.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balancedPartitions;

  /// No description provided for @emptyTopicMessage.
  ///
  /// In en, this message translates to:
  /// **'This topic is empty (0 messages).'**
  String get emptyTopicMessage;

  /// No description provided for @fieldValueExplorer.
  ///
  /// In en, this message translates to:
  /// **'Field Value Explorer (Top 10 Values)'**
  String get fieldValueExplorer;

  /// No description provided for @searchFields.
  ///
  /// In en, this message translates to:
  /// **'Search fields...'**
  String get searchFields;

  /// No description provided for @selectFieldToInspect.
  ///
  /// In en, this message translates to:
  /// **'Select a field to inspect its Top 10 values'**
  String get selectFieldToInspect;

  /// No description provided for @top10ValuesForField.
  ///
  /// In en, this message translates to:
  /// **'Top 10 Values for {field}'**
  String top10ValuesForField(String field);

  /// No description provided for @valueCopied.
  ///
  /// In en, this message translates to:
  /// **'Value copied to clipboard'**
  String get valueCopied;

  /// No description provided for @distinctValues.
  ///
  /// In en, this message translates to:
  /// **'{count} distinct values tracked'**
  String distinctValues(int count);

  /// No description provided for @fieldOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Appears in {count} msgs ({pct}%)'**
  String fieldOccurrences(String count, String pct);

  /// No description provided for @noMatchingFields.
  ///
  /// In en, this message translates to:
  /// **'No fields matching \'{query}\''**
  String noMatchingFields(String query);

  /// No description provided for @topValuesForField.
  ///
  /// In en, this message translates to:
  /// **'Top values for {field}'**
  String topValuesForField(String field);

  /// No description provided for @allMessages.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get allMessages;

  /// No description provided for @byTopic.
  ///
  /// In en, this message translates to:
  /// **'By Topic'**
  String get byTopic;

  /// No description provided for @byStep.
  ///
  /// In en, this message translates to:
  /// **'By Step'**
  String get byStep;

  /// No description provided for @filterByMessageId.
  ///
  /// In en, this message translates to:
  /// **'Filter by Message ID, CORID or PMXCOR ID'**
  String get filterByMessageId;

  /// No description provided for @enterMessageIdToFilter.
  ///
  /// In en, this message translates to:
  /// **'Enter message ID, CORID or PMXCOR ID...'**
  String get enterMessageIdToFilter;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get statusOpen;

  /// No description provided for @statusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'AI ANALYSIS STARTED'**
  String get statusAnalyzing;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'AI ANALYSIS DONE'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get statusFailed;

  /// No description provided for @showingOrders.
  ///
  /// In en, this message translates to:
  /// **'Showing {filtered} of {total} orders'**
  String showingOrders(int filtered, int total);

  /// No description provided for @loadOrders.
  ///
  /// In en, this message translates to:
  /// **'Load Orders'**
  String get loadOrders;

  /// No description provided for @searchingForOrders.
  ///
  /// In en, this message translates to:
  /// **'Searching for orders...'**
  String get searchingForOrders;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found. Click Load to search.'**
  String get noOrdersFound;

  /// No description provided for @noOrdersMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No orders match the filter.'**
  String get noOrdersMatchFilter;

  /// No description provided for @failedToLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders: {error}'**
  String failedToLoadOrders(String error);

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @rerunNotIntegrated.
  ///
  /// In en, this message translates to:
  /// **'Rerun from history is not fully integrated in Orders View yet.'**
  String get rerunNotIntegrated;

  /// No description provided for @simulateOrder.
  ///
  /// In en, this message translates to:
  /// **'Simulate Order'**
  String get simulateOrder;

  /// No description provided for @limitOrders.
  ///
  /// In en, this message translates to:
  /// **'Enable order limit'**
  String get limitOrders;

  /// No description provided for @maxOrders.
  ///
  /// In en, this message translates to:
  /// **'Max Orders'**
  String get maxOrders;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'{total} Orders'**
  String totalOrders(int total);

  /// No description provided for @aiAnalysisDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis Data Available'**
  String get aiAnalysisDataAvailable;

  /// No description provided for @kiError.
  ///
  /// In en, this message translates to:
  /// **'AI Error'**
  String get kiError;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @firstAppearanceForKey.
  ///
  /// In en, this message translates to:
  /// **'First appearance for Key: {key}'**
  String firstAppearanceForKey(String key);

  /// No description provided for @stepMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String stepMatches(int count);

  /// No description provided for @searchingInTopic.
  ///
  /// In en, this message translates to:
  /// **'Searching in: {topic}'**
  String searchingInTopic(String topic);

  /// No description provided for @examinedMessages.
  ///
  /// In en, this message translates to:
  /// **'Examined: {count} messages'**
  String examinedMessages(int count);

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results...'**
  String get searchResults;

  /// No description provided for @matchesCount.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String matchesCount(int current, int total);

  /// No description provided for @otherResults.
  ///
  /// In en, this message translates to:
  /// **'Other Results'**
  String get otherResults;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found matching \'{phrase}\''**
  String noResultsFound(String phrase);

  /// No description provided for @noActiveStreams.
  ///
  /// In en, this message translates to:
  /// **'No active streams'**
  String get noActiveStreams;

  /// No description provided for @noProgressInfo.
  ///
  /// In en, this message translates to:
  /// **'No progress info'**
  String get noProgressInfo;

  /// No description provided for @scanned.
  ///
  /// In en, this message translates to:
  /// **'{count} scanned'**
  String scanned(int count);

  /// No description provided for @scannedCount.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {count}'**
  String scannedCount(int count);

  /// No description provided for @topicsProgress.
  ///
  /// In en, this message translates to:
  /// **'Completed {completed} of {total} topics'**
  String topicsProgress(int completed, int total);

  /// No description provided for @pmxcorStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}'**
  String pmxcorStatus(String status);

  /// No description provided for @clusterLabel.
  ///
  /// In en, this message translates to:
  /// **'Cluster: {name}'**
  String clusterLabel(String name);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get closeTab;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @operationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Operation in Progress'**
  String get operationInProgress;

  /// No description provided for @operationInProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'A search or analysis is still running on this tab. Close the tab and cancel the operation?'**
  String get operationInProgressMessage;

  /// No description provided for @duplicateTab.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Tab'**
  String get duplicateTab;

  /// No description provided for @openInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in New Tab'**
  String get openInNewTab;

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @scripts.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get scripts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @clusters.
  ///
  /// In en, this message translates to:
  /// **'CLUSTERS'**
  String get clusters;

  /// No description provided for @addCluster.
  ///
  /// In en, this message translates to:
  /// **'Add Cluster'**
  String get addCluster;

  /// No description provided for @reloadTopicsAndSchemas.
  ///
  /// In en, this message translates to:
  /// **'Reload Topics & Schemas'**
  String get reloadTopicsAndSchemas;

  /// No description provided for @selectClusterToViewTopics.
  ///
  /// In en, this message translates to:
  /// **'Select a cluster to view topics'**
  String get selectClusterToViewTopics;

  /// No description provided for @topics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topics;

  /// No description provided for @filterTopics.
  ///
  /// In en, this message translates to:
  /// **'Filter topics...'**
  String get filterTopics;

  /// No description provided for @showInternal.
  ///
  /// In en, this message translates to:
  /// **'Show internal'**
  String get showInternal;

  /// No description provided for @consumerGroups.
  ///
  /// In en, this message translates to:
  /// **'Consumer Groups'**
  String get consumerGroups;

  /// No description provided for @searchGroups.
  ///
  /// In en, this message translates to:
  /// **'Search consumer groups...'**
  String get searchGroups;

  /// No description provided for @noConsumerGroupsFound.
  ///
  /// In en, this message translates to:
  /// **'No consumer groups found.'**
  String get noConsumerGroupsFound;

  /// No description provided for @consumerLag.
  ///
  /// In en, this message translates to:
  /// **'Consumer Lag'**
  String get consumerLag;

  /// No description provided for @autoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto-Refresh (15s)'**
  String get autoRefresh;

  /// No description provided for @topicCol.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topicCol;

  /// No description provided for @partitionCol.
  ///
  /// In en, this message translates to:
  /// **'Partition'**
  String get partitionCol;

  /// No description provided for @logEndOffsetCol.
  ///
  /// In en, this message translates to:
  /// **'Log End Offset'**
  String get logEndOffsetCol;

  /// No description provided for @committedOffsetCol.
  ///
  /// In en, this message translates to:
  /// **'Committed Offset'**
  String get committedOffsetCol;

  /// No description provided for @lagCol.
  ///
  /// In en, this message translates to:
  /// **'Lag'**
  String get lagCol;

  /// No description provided for @totalLag.
  ///
  /// In en, this message translates to:
  /// **'Total Lag'**
  String get totalLag;

  /// No description provided for @stream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get stream;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @tree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get tree;

  /// No description provided for @raw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get raw;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @exportMessages.
  ///
  /// In en, this message translates to:
  /// **'Export Messages'**
  String get exportMessages;

  /// No description provided for @sortOrderAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortOrderAscending;

  /// No description provided for @sortOrderDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortOrderDescending;

  /// No description provided for @sortFieldTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get sortFieldTimestamp;

  /// No description provided for @sortFieldPartition.
  ///
  /// In en, this message translates to:
  /// **'Partition'**
  String get sortFieldPartition;

  /// No description provided for @sortFieldOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get sortFieldOffset;

  /// No description provided for @sortFieldKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get sortFieldKey;

  /// No description provided for @sortFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get sortFieldValue;

  /// No description provided for @sortFieldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort field'**
  String get sortFieldTooltip;

  /// No description provided for @startCondition.
  ///
  /// In en, this message translates to:
  /// **'Start Condition'**
  String get startCondition;

  /// No description provided for @startConditionLatestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start at the most recent messages (tail of topic according to limit)'**
  String get startConditionLatestTooltip;

  /// No description provided for @startConditionEarliestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start reading from the oldest available message (offset 0)'**
  String get startConditionEarliestTooltip;

  /// No description provided for @startConditionOffsetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start reading from a specific offset'**
  String get startConditionOffsetTooltip;

  /// No description provided for @startConditionTimestampTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start reading from a specific timestamp'**
  String get startConditionTimestampTooltip;

  /// No description provided for @stopCondition.
  ///
  /// In en, this message translates to:
  /// **'Stop Condition'**
  String get stopCondition;

  /// No description provided for @stopConditionStreamTooltip.
  ///
  /// In en, this message translates to:
  /// **'Continue listening indefinitely for newly arriving messages'**
  String get stopConditionStreamTooltip;

  /// No description provided for @stopConditionEndTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop when reaching the current end of the topic (high watermark)'**
  String get stopConditionEndTooltip;

  /// No description provided for @stopConditionOffsetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop reading at a specific offset'**
  String get stopConditionOffsetTooltip;

  /// No description provided for @stopConditionTimestampTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop reading at a specific timestamp'**
  String get stopConditionTimestampTooltip;

  /// No description provided for @earliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get earliest;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @offset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get offset;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @startOffset.
  ///
  /// In en, this message translates to:
  /// **'Start Offset'**
  String get startOffset;

  /// No description provided for @endOffset.
  ///
  /// In en, this message translates to:
  /// **'End Offset'**
  String get endOffset;

  /// No description provided for @startTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Start Timestamp'**
  String get startTimestamp;

  /// No description provided for @endTimestamp.
  ///
  /// In en, this message translates to:
  /// **'End Timestamp'**
  String get endTimestamp;

  /// No description provided for @quickTimeSelection.
  ///
  /// In en, this message translates to:
  /// **'Quick Time Selection'**
  String get quickTimeSelection;

  /// No description provided for @ago.
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get ago;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @partitionOptional.
  ///
  /// In en, this message translates to:
  /// **'Partition (Opt.)'**
  String get partitionOptional;

  /// No description provided for @fastTrace.
  ///
  /// In en, this message translates to:
  /// **'Fast Trace (Hash Key)'**
  String get fastTrace;

  /// No description provided for @limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// No description provided for @limitResults.
  ///
  /// In en, this message translates to:
  /// **'Limit results'**
  String get limitResults;

  /// No description provided for @maxResults.
  ///
  /// In en, this message translates to:
  /// **'Max Results'**
  String get maxResults;

  /// No description provided for @scope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @contains.
  ///
  /// In en, this message translates to:
  /// **'Contains'**
  String get contains;

  /// No description provided for @regex.
  ///
  /// In en, this message translates to:
  /// **'Regex'**
  String get regex;

  /// No description provided for @exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get exact;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @cluster.
  ///
  /// In en, this message translates to:
  /// **'Cluster'**
  String get cluster;

  /// No description provided for @parameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get parameters;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add Step'**
  String get addStep;

  /// No description provided for @unnamedStep.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Step'**
  String get unnamedStep;

  /// No description provided for @editStep.
  ///
  /// In en, this message translates to:
  /// **'Edit Step'**
  String get editStep;

  /// No description provided for @variables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get variables;

  /// No description provided for @editVariable.
  ///
  /// In en, this message translates to:
  /// **'Edit Variable'**
  String get editVariable;

  /// No description provided for @usedIn.
  ///
  /// In en, this message translates to:
  /// **'Used In'**
  String get usedIn;

  /// No description provided for @noVariablesRequired.
  ///
  /// In en, this message translates to:
  /// **'No variables required.'**
  String get noVariablesRequired;

  /// No description provided for @addExtraction.
  ///
  /// In en, this message translates to:
  /// **'Add Extraction'**
  String get addExtraction;

  /// No description provided for @newScript.
  ///
  /// In en, this message translates to:
  /// **'New Script'**
  String get newScript;

  /// No description provided for @duplicateScript.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Script'**
  String get duplicateScript;

  /// No description provided for @exportScript.
  ///
  /// In en, this message translates to:
  /// **'Export Script'**
  String get exportScript;

  /// No description provided for @exportSelectedScript.
  ///
  /// In en, this message translates to:
  /// **'Export Selected Script'**
  String get exportSelectedScript;

  /// No description provided for @importScripts.
  ///
  /// In en, this message translates to:
  /// **'Import Scripts'**
  String get importScripts;

  /// No description provided for @deleteCluster.
  ///
  /// In en, this message translates to:
  /// **'Delete Cluster'**
  String get deleteCluster;

  /// No description provided for @deleteClusterConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {clusterName}?'**
  String deleteClusterConfirmation(String clusterName);

  /// No description provided for @useSidebarToSelectScript.
  ///
  /// In en, this message translates to:
  /// **'Use the sidebar to select or create a script.'**
  String get useSidebarToSelectScript;

  /// No description provided for @createNewScript.
  ///
  /// In en, this message translates to:
  /// **'Create New Script'**
  String get createNewScript;

  /// No description provided for @editDefinition.
  ///
  /// In en, this message translates to:
  /// **'Edit Definition'**
  String get editDefinition;

  /// No description provided for @selectValidScript.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid script first.'**
  String get selectValidScript;

  /// No description provided for @scriptExecution.
  ///
  /// In en, this message translates to:
  /// **'Script Execution: {name}'**
  String scriptExecution(String name);

  /// No description provided for @newRun.
  ///
  /// In en, this message translates to:
  /// **'New Run'**
  String get newRun;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @reviewPreviousRuns.
  ///
  /// In en, this message translates to:
  /// **'Review Previous Runs'**
  String get reviewPreviousRuns;

  /// No description provided for @noPastRunsFound.
  ///
  /// In en, this message translates to:
  /// **'No past runs found.'**
  String get noPastRunsFound;

  /// No description provided for @deleteRunResult.
  ///
  /// In en, this message translates to:
  /// **'Delete Run Result'**
  String get deleteRunResult;

  /// No description provided for @deleteRunResultConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this run result?'**
  String get deleteRunResultConfirmation;

  /// No description provided for @runResultDeleted.
  ///
  /// In en, this message translates to:
  /// **'Run result deleted'**
  String get runResultDeleted;

  /// No description provided for @runDetails.
  ///
  /// In en, this message translates to:
  /// **'Run Details'**
  String get runDetails;

  /// No description provided for @runSummary.
  ///
  /// In en, this message translates to:
  /// **'Run Summary'**
  String get runSummary;

  /// No description provided for @chronological.
  ///
  /// In en, this message translates to:
  /// **'Chronological'**
  String get chronological;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @switchLightMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to Light Mode'**
  String get switchLightMode;

  /// No description provided for @switchDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to Dark Mode'**
  String get switchDarkMode;

  /// No description provided for @defaultScriptOutputDir.
  ///
  /// In en, this message translates to:
  /// **'Default Script Output Directory'**
  String get defaultScriptOutputDir;

  /// No description provided for @selectOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Output Directory'**
  String get selectOutputDirectory;

  /// No description provided for @maxScriptRunHistory.
  ///
  /// In en, this message translates to:
  /// **'Max Script Runs to keep'**
  String get maxScriptRunHistory;

  /// No description provided for @exportConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Export Configuration'**
  String get exportConfiguration;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @importConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Import Configuration'**
  String get importConfiguration;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @clusterConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Cluster Configuration'**
  String get clusterConfiguration;

  /// No description provided for @pleaseSelectCluster.
  ///
  /// In en, this message translates to:
  /// **'Please select a cluster'**
  String get pleaseSelectCluster;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @messageDetails.
  ///
  /// In en, this message translates to:
  /// **'Message Details'**
  String get messageDetails;

  /// No description provided for @copyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get copyMessage;

  /// No description provided for @contentCopied.
  ///
  /// In en, this message translates to:
  /// **'Content copied to clipboard'**
  String get contentCopied;

  /// No description provided for @metadataCopied.
  ///
  /// In en, this message translates to:
  /// **'Metadata copied to clipboard'**
  String get metadataCopied;

  /// No description provided for @fullMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Full message copied to clipboard'**
  String get fullMessageCopied;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @noDifferencesFound.
  ///
  /// In en, this message translates to:
  /// **'No differences found.'**
  String get noDifferencesFound;

  /// No description provided for @unknownView.
  ///
  /// In en, this message translates to:
  /// **'Unknown View'**
  String get unknownView;

  /// No description provided for @configurationExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Configuration exported successfully'**
  String get configurationExportedSuccessfully;

  /// No description provided for @configurationImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported successfully'**
  String get configurationImportedSuccessfully;

  /// No description provided for @clustersExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Clusters exported successfully'**
  String get clustersExportedSuccessfully;

  /// No description provided for @clustersImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Clusters imported successfully'**
  String get clustersImportedSuccessfully;

  /// No description provided for @scriptExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Script exported successfully'**
  String get scriptExportedSuccessfully;

  /// No description provided for @scriptsImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Scripts imported successfully'**
  String get scriptsImportedSuccessfully;

  /// No description provided for @runArchiveExported.
  ///
  /// In en, this message translates to:
  /// **'Run archive exported'**
  String get runArchiveExported;

  /// No description provided for @runArchiveImported.
  ///
  /// In en, this message translates to:
  /// **'Run archive imported'**
  String get runArchiveImported;

  /// No description provided for @messagesExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Messages exported successfully'**
  String get messagesExportedSuccessfully;

  /// No description provided for @failedToExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export: {error}'**
  String failedToExport(String error);

  /// No description provided for @failedToImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import: {error}'**
  String failedToImport(String error);

  /// No description provided for @failedToImportRun.
  ///
  /// In en, this message translates to:
  /// **'Failed to import run: {error}'**
  String failedToImportRun(String error);

  /// No description provided for @messagesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export messages: {error}'**
  String messagesExportFailed(String error);

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @appUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Kafkalyzer is up to date'**
  String get appUpToDate;

  /// No description provided for @appUpToDateDescription.
  ///
  /// In en, this message translates to:
  /// **'You are running the latest version of Kafkalyzer.'**
  String get appUpToDateDescription;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get downloadUpdate;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get restartNow;

  /// No description provided for @updateReadyRestart.
  ///
  /// In en, this message translates to:
  /// **'Update ready! Restart required to apply update.'**
  String get updateReadyRestart;

  /// No description provided for @updateError.
  ///
  /// In en, this message translates to:
  /// **'Error checking or applying update: {error}'**
  String updateError(String error);

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get releaseNotes;

  /// No description provided for @noReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes available.'**
  String get noReleaseNotes;

  /// No description provided for @backgroundUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version of Kafkalyzer (v{version}) is available.'**
  String backgroundUpdateAvailable(String version);

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// No description provided for @updateUnsupportedEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Automatic updates unavailable'**
  String get updateUnsupportedEnvironment;

  /// No description provided for @updateUnsupportedEnvironmentDescription.
  ///
  /// In en, this message translates to:
  /// **'In-place updates require a packaged installation (AppImage on Linux, installer on Windows/macOS). Download the latest release from GitHub.'**
  String get updateUnsupportedEnvironmentDescription;

  /// No description provided for @openGitHubReleases.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub Releases'**
  String get openGitHubReleases;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @dockBottom.
  ///
  /// In en, this message translates to:
  /// **'Dock to bottom'**
  String get dockBottom;

  /// No description provided for @dockSide.
  ///
  /// In en, this message translates to:
  /// **'Dock to right'**
  String get dockSide;

  /// No description provided for @closeInspector.
  ///
  /// In en, this message translates to:
  /// **'Close inspector'**
  String get closeInspector;

  /// No description provided for @tabPayload.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get tabPayload;

  /// No description provided for @tabKeyAndHeaders.
  ///
  /// In en, this message translates to:
  /// **'Key & Headers'**
  String get tabKeyAndHeaders;

  /// No description provided for @tabRawJson.
  ///
  /// In en, this message translates to:
  /// **'Raw JSON'**
  String get tabRawJson;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Inspector'**
  String get inspectorTitle;

  /// No description provided for @copyHeaders.
  ///
  /// In en, this message translates to:
  /// **'Copy all headers'**
  String get copyHeaders;

  /// No description provided for @copyMetadata.
  ///
  /// In en, this message translates to:
  /// **'Copy metadata'**
  String get copyMetadata;

  /// No description provided for @copiedHeaders.
  ///
  /// In en, this message translates to:
  /// **'All headers copied to clipboard'**
  String get copiedHeaders;

  /// No description provided for @copiedHeaderValue.
  ///
  /// In en, this message translates to:
  /// **'Copied value of \'{key}\''**
  String copiedHeaderValue(String key);

  /// No description provided for @noHeaders.
  ///
  /// In en, this message translates to:
  /// **'No headers present on this message'**
  String get noHeaders;

  /// No description provided for @copyRawJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get copyRawJson;

  /// No description provided for @previousMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous message (K)'**
  String get previousMessageTooltip;

  /// No description provided for @nextMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next message (J)'**
  String get nextMessageTooltip;

  /// No description provided for @messagePosition.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String messagePosition(int current, int total);

  /// No description provided for @focusMode.
  ///
  /// In en, this message translates to:
  /// **'Maximize (Focus Mode)'**
  String get focusMode;

  /// No description provided for @exitFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Minimize (Esc)'**
  String get exitFocusMode;

  /// No description provided for @searchInMessage.
  ///
  /// In en, this message translates to:
  /// **'Search in message...'**
  String get searchInMessage;

  /// No description provided for @nextMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next match (Enter)'**
  String get nextMatchTooltip;

  /// No description provided for @previousMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous match (Shift+Enter)'**
  String get previousMatchTooltip;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @collapsedRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'… {count} hidden items (Index {start} to {end})'**
  String collapsedRangeLabel(int count, int start, int end);

  /// No description provided for @showAllArrayItems.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String showAllArrayItems(int count);

  /// No description provided for @reduceToMatchContext.
  ///
  /// In en, this message translates to:
  /// **'Focus matches (±1)'**
  String get reduceToMatchContext;

  /// No description provided for @matchesContextBadge.
  ///
  /// In en, this message translates to:
  /// **'{matches} matches (Focus: ±1)'**
  String matchesContextBadge(int matches);

  /// No description provided for @recollapseRange.
  ///
  /// In en, this message translates to:
  /// **'Re-collapse range'**
  String get recollapseRange;

  /// No description provided for @pinAsColumn.
  ///
  /// In en, this message translates to:
  /// **'Pin as Column'**
  String get pinAsColumn;

  /// No description provided for @columnPinned.
  ///
  /// In en, this message translates to:
  /// **'Column \'{path}\' pinned to table'**
  String columnPinned(String path);

  /// No description provided for @columnAlreadyPinned.
  ///
  /// In en, this message translates to:
  /// **'Column \'{path}\' is already pinned'**
  String columnAlreadyPinned(String path);

  /// No description provided for @removeColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get removeColumn;

  /// No description provided for @resetColumns.
  ///
  /// In en, this message translates to:
  /// **'Reset columns'**
  String get resetColumns;

  /// No description provided for @columnsReset.
  ///
  /// In en, this message translates to:
  /// **'Table columns reset to default'**
  String get columnsReset;

  /// No description provided for @columnsMenu.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columnsMenu;

  /// No description provided for @hideColumn.
  ///
  /// In en, this message translates to:
  /// **'Hide column'**
  String get hideColumn;

  /// No description provided for @showColumn.
  ///
  /// In en, this message translates to:
  /// **'Show column'**
  String get showColumn;

  /// No description provided for @autoFitColumn.
  ///
  /// In en, this message translates to:
  /// **'Auto-fit width'**
  String get autoFitColumn;

  /// No description provided for @hideEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Hide empty fields'**
  String get hideEmptyFields;

  /// No description provided for @showEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Show empty fields'**
  String get showEmptyFields;

  /// Indicates number of hidden null/empty fields
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hidden empty field} other{{count} hidden empty fields}}'**
  String hiddenEmptyFieldsCount(num count);

  /// No description provided for @rawTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get rawTimestampLabel;

  /// No description provided for @utcTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get utcTimestampLabel;

  /// No description provided for @localTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localTimestampLabel;

  /// No description provided for @searchConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Configuration'**
  String get searchConfigurationTitle;

  /// No description provided for @collapseSearchConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Collapse search configuration'**
  String get collapseSearchConfiguration;

  /// No description provided for @expandSearchConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Expand search configuration'**
  String get expandSearchConfiguration;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar (Ctrl+B)'**
  String get expandSidebar;

  /// No description provided for @collapseScriptCatalog.
  ///
  /// In en, this message translates to:
  /// **'Collapse script catalog'**
  String get collapseScriptCatalog;

  /// No description provided for @expandScriptCatalog.
  ///
  /// In en, this message translates to:
  /// **'Expand script catalog (Ctrl+B)'**
  String get expandScriptCatalog;

  /// No description provided for @toggleRunOverview.
  ///
  /// In en, this message translates to:
  /// **'Toggle run overview'**
  String get toggleRunOverview;

  /// No description provided for @scanModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get scanModeLabel;

  /// No description provided for @scanModeLatestN.
  ///
  /// In en, this message translates to:
  /// **'Latest Messages'**
  String get scanModeLatestN;

  /// No description provided for @scanModeLiveTail.
  ///
  /// In en, this message translates to:
  /// **'Live Stream'**
  String get scanModeLiveTail;

  /// No description provided for @scanModeTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get scanModeTimeRange;

  /// No description provided for @scanModeOffsetEarliest.
  ///
  /// In en, this message translates to:
  /// **'Offset / Earliest'**
  String get scanModeOffsetEarliest;

  /// No description provided for @quickFilterPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Filter on fetch (key or value)...'**
  String get quickFilterPlaceholder;

  /// No description provided for @invalidFilterPattern.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression: {term}'**
  String invalidFilterPattern(Object term);

  /// No description provided for @limitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limitLabel;

  /// No description provided for @limitAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get limitAll;

  /// No description provided for @advancedFiltersToggle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedFiltersToggle;

  /// No description provided for @collapseAdvancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Collapse advanced filters'**
  String get collapseAdvancedFilters;

  /// No description provided for @expandAdvancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Expand advanced filters'**
  String get expandAdvancedFilters;

  /// No description provided for @fetchMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'Fetch {count} Messages'**
  String fetchMessagesCount(int count);

  /// No description provided for @fetchMessages.
  ///
  /// In en, this message translates to:
  /// **'Fetch Messages'**
  String get fetchMessages;

  /// No description provided for @startLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Start Live Stream'**
  String get startLiveStream;

  /// No description provided for @filterChangedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Parameters changed – Click to fetch new results'**
  String get filterChangedTooltip;

  /// No description provided for @chipPartition.
  ///
  /// In en, this message translates to:
  /// **'Partition: {partition}'**
  String chipPartition(String partition);

  /// No description provided for @chipField.
  ///
  /// In en, this message translates to:
  /// **'Field: {field}'**
  String chipField(String field);

  /// No description provided for @chipFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String chipFilterType(String type);

  /// No description provided for @chipScope.
  ///
  /// In en, this message translates to:
  /// **'Scope: {scope}'**
  String chipScope(String scope);

  /// No description provided for @chipFastTrace.
  ///
  /// In en, this message translates to:
  /// **'Fast Trace'**
  String get chipFastTrace;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kafkalyzer'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a Kafka cluster to explore topics, inspect consumer lag, and run scripts.'**
  String get welcomeSubtitle;

  /// No description provided for @configuredClusters.
  ///
  /// In en, this message translates to:
  /// **'Configured Clusters'**
  String get configuredClusters;

  /// No description provided for @noClustersConfigured.
  ///
  /// In en, this message translates to:
  /// **'No clusters configured yet.'**
  String get noClustersConfigured;

  /// No description provided for @addClusterAction.
  ///
  /// In en, this message translates to:
  /// **'Add Cluster'**
  String get addClusterAction;

  /// No description provided for @connectCluster.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectCluster;

  /// No description provided for @recentTopics.
  ///
  /// In en, this message translates to:
  /// **'Recently Viewed Topics'**
  String get recentTopics;

  /// No description provided for @noRecentTopics.
  ///
  /// In en, this message translates to:
  /// **'No recently viewed topics yet.'**
  String get noRecentTopics;

  /// No description provided for @clearRecentTopics.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearRecentTopics;

  /// No description provided for @clusterOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Cluster Overview'**
  String get clusterOverviewTitle;

  /// No description provided for @clusterOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore topics from the sidebar or open a recently examined topic.'**
  String get clusterOverviewSubtitle;

  /// No description provided for @clusterTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Topics'**
  String clusterTopicsCount(int count);

  /// No description provided for @schemaRegistryActive.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry Connected'**
  String get schemaRegistryActive;

  /// No description provided for @schemaRegistryNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No Schema Registry'**
  String get schemaRegistryNotConfigured;

  /// No description provided for @securityProtocolLabel.
  ///
  /// In en, this message translates to:
  /// **'Protocol: {protocol}'**
  String securityProtocolLabel(String protocol);

  /// No description provided for @selectTopicPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a topic from the sidebar to inspect messages and analyze partitions.'**
  String get selectTopicPrompt;

  /// No description provided for @recentTopicsForCluster.
  ///
  /// In en, this message translates to:
  /// **'Recent Topics in {cluster}'**
  String recentTopicsForCluster(String cluster);

  /// No description provided for @noMessagesLoadedTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages loaded yet'**
  String get noMessagesLoadedTitle;

  /// No description provided for @noMessagesLoadedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch the latest messages from this topic or configure your filters above.'**
  String get noMessagesLoadedSubtitle;

  /// No description provided for @fetchLatestMessagesAction.
  ///
  /// In en, this message translates to:
  /// **'Fetch Latest 200 Messages'**
  String get fetchLatestMessagesAction;

  /// No description provided for @doubleClickTopicTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Double-clicking a topic in the sidebar starts fetching immediately.'**
  String get doubleClickTopicTip;

  /// No description provided for @loadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading messages from Kafka...'**
  String get loadingMessages;

  /// No description provided for @internalTopicsFilter.
  ///
  /// In en, this message translates to:
  /// **'Internal Topics'**
  String get internalTopicsFilter;

  /// No description provided for @streamTopicsFilter.
  ///
  /// In en, this message translates to:
  /// **'Stream Topics'**
  String get streamTopicsFilter;

  /// No description provided for @partitionBadge.
  ///
  /// In en, this message translates to:
  /// **'{count}P'**
  String partitionBadge(int count);

  /// No description provided for @topicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Partitions: {partitions} • RF: {rf} • Retention: {retention} • Cleanup: {policy}'**
  String topicTooltip(int partitions, int rf, String retention, String policy);

  /// No description provided for @topicTooltipSimple.
  ///
  /// In en, this message translates to:
  /// **'Partitions: {partitions} • RF: {rf}'**
  String topicTooltipSimple(int partitions, int rf);

  /// No description provided for @messageSchemaResolved.
  ///
  /// In en, this message translates to:
  /// **'Schema: {subject} v{version} (#{id})'**
  String messageSchemaResolved(String subject, int version, int id);

  /// No description provided for @messageSchemaUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Schema #{id} (unresolved)'**
  String messageSchemaUnresolved(int id);

  /// No description provided for @messageSchemaUnresolvedTooltip.
  ///
  /// In en, this message translates to:
  /// **'The Schema Registry could not be reached. The id comes from the message itself.'**
  String get messageSchemaUnresolvedTooltip;

  /// No description provided for @groupMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersTitle;

  /// No description provided for @groupMemberEmpty.
  ///
  /// In en, this message translates to:
  /// **'This group currently has no members.'**
  String get groupMemberEmpty;

  /// No description provided for @groupMemberPartitions.
  ///
  /// In en, this message translates to:
  /// **'{count} partitions'**
  String groupMemberPartitions(int count);

  /// No description provided for @groupUnassignedPartitions.
  ///
  /// In en, this message translates to:
  /// **'{count} partitions have no owner'**
  String groupUnassignedPartitions(int count);

  /// No description provided for @groupAssignmentNotDecodable.
  ///
  /// In en, this message translates to:
  /// **'Assignment could not be decoded'**
  String get groupAssignmentNotDecodable;

  /// No description provided for @topicHealthWarning.
  ///
  /// In en, this message translates to:
  /// **'{underReplicated} under-replicated, {leaderless} leaderless'**
  String topicHealthWarning(int underReplicated, int leaderless);

  /// No description provided for @partitionHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Partition health'**
  String get partitionHealthTitle;

  /// No description provided for @partitionLeaderCol.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get partitionLeaderCol;

  /// No description provided for @partitionReplicasCol.
  ///
  /// In en, this message translates to:
  /// **'Replicas'**
  String get partitionReplicasCol;

  /// No description provided for @partitionIsrCol.
  ///
  /// In en, this message translates to:
  /// **'ISR'**
  String get partitionIsrCol;

  /// No description provided for @partitionHealthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Partition metadata unavailable'**
  String get partitionHealthUnavailable;

  /// No description provided for @partitionNoLeader.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get partitionNoLeader;

  /// No description provided for @schemaTooltipSuffix.
  ///
  /// In en, this message translates to:
  /// **' • Schema: {schema}'**
  String schemaTooltipSuffix(String schema);

  /// No description provided for @viewModeTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get viewModeTable;

  /// No description provided for @viewModeTableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Table View'**
  String get viewModeTableTooltip;

  /// No description provided for @viewModeTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get viewModeTimeline;

  /// No description provided for @viewModeTimelineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Timeline View'**
  String get viewModeTimelineTooltip;

  /// No description provided for @viewModeDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get viewModeDiff;

  /// No description provided for @viewModeDiffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Diff View'**
  String get viewModeDiffTooltip;

  /// No description provided for @viewModeSchema.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get viewModeSchema;

  /// No description provided for @viewModeSchemaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Schema View'**
  String get viewModeSchemaTooltip;

  /// No description provided for @filterInLoadedMessages.
  ///
  /// In en, this message translates to:
  /// **'Filter in {count} loaded messages...'**
  String filterInLoadedMessages(int count);

  /// No description provided for @matchesOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{matchCount} of {totalCount} matches'**
  String matchesOfTotal(int matchCount, int totalCount);

  /// No description provided for @loadedMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} loaded messages'**
  String loadedMessagesCount(int count);

  /// No description provided for @sslClientAuthMode.
  ///
  /// In en, this message translates to:
  /// **'Client Authentication (mTLS)'**
  String get sslClientAuthMode;

  /// No description provided for @sslClientAuthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sslClientAuthNone;

  /// No description provided for @sslClientAuthKeystore.
  ///
  /// In en, this message translates to:
  /// **'Keystore (PKCS12 / JKS)'**
  String get sslClientAuthKeystore;

  /// No description provided for @sslClientAuthPem.
  ///
  /// In en, this message translates to:
  /// **'PEM Certificate & Key'**
  String get sslClientAuthPem;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing Connection...'**
  String get testingConnection;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(String error);

  /// No description provided for @schemaRegistryCredentialsOptional.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry Credentials (Optional)'**
  String get schemaRegistryCredentialsOptional;

  /// No description provided for @globalConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Backup or restore the entire application state including all cluster configurations and preferences.'**
  String get globalConfigDescription;

  /// No description provided for @clusterExportDescription.
  ///
  /// In en, this message translates to:
  /// **'Export or import selected cluster profiles and their certificates as a portable ZIP archive.'**
  String get clusterExportDescription;

  /// No description provided for @schemaRegistryConfiguredBadge.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry'**
  String get schemaRegistryConfiguredBadge;

  /// No description provided for @maxScriptRuns.
  ///
  /// In en, this message translates to:
  /// **'Maximum Script Runs'**
  String get maxScriptRuns;

  /// No description provided for @maxConcurrentLagQueries.
  ///
  /// In en, this message translates to:
  /// **'Maximum Concurrent Lag Queries'**
  String get maxConcurrentLagQueries;

  /// No description provided for @maxConcurrentLagQueriesHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: 5 (Higher values can impact performance)'**
  String get maxConcurrentLagQueriesHelper;

  /// No description provided for @deleteStepConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Step?'**
  String get deleteStepConfirmationTitle;

  /// No description provided for @deleteStepConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete step \"{name}\"? This action cannot be undone.'**
  String deleteStepConfirmationMessage(String name);

  /// No description provided for @addTopicManually.
  ///
  /// In en, this message translates to:
  /// **'Add Topic Manually'**
  String get addTopicManually;

  /// No description provided for @manualTopicNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter topic name'**
  String get manualTopicNamePrompt;

  /// No description provided for @addTopicAction.
  ///
  /// In en, this message translates to:
  /// **'Add Topic'**
  String get addTopicAction;

  /// No description provided for @topicLoadingHint.
  ///
  /// In en, this message translates to:
  /// **'Loading topics...'**
  String get topicLoadingHint;

  /// No description provided for @selectTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'Select Topics ({count} selected)'**
  String selectTopicsCount(int count);

  /// No description provided for @extractionSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get extractionSource;

  /// No description provided for @extractionTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get extractionTopic;

  /// No description provided for @extractionVariableName.
  ///
  /// In en, this message translates to:
  /// **'Variable Name'**
  String get extractionVariableName;

  /// No description provided for @extractionJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Field path (e.g. order.id, items[0].sku, /order/status)'**
  String get extractionJsonPath;

  /// No description provided for @scriptProperties.
  ///
  /// In en, this message translates to:
  /// **'Script Properties'**
  String get scriptProperties;

  /// No description provided for @concurrencyLimit.
  ///
  /// In en, this message translates to:
  /// **'Concurrency Limit'**
  String get concurrencyLimit;

  /// No description provided for @advancedFiltersSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get advancedFiltersSection;

  /// No description provided for @deleteScriptConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Script?'**
  String get deleteScriptConfirmationTitle;

  /// No description provided for @deleteScriptConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete script \"{name}\"? This action cannot be undone.'**
  String deleteScriptConfirmationMessage(String name);

  /// No description provided for @searchScripts.
  ///
  /// In en, this message translates to:
  /// **'Search scripts...'**
  String get searchScripts;

  /// No description provided for @pipelinePreview.
  ///
  /// In en, this message translates to:
  /// **'Pipeline Preview'**
  String get pipelinePreview;

  /// No description provided for @pipelineStepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Step} other{{count} Steps}}'**
  String pipelineStepsCount(int count);

  /// No description provided for @noStepsInPipeline.
  ///
  /// In en, this message translates to:
  /// **'No execution steps configured. Use the Edit tab to add steps.'**
  String get noStepsInPipeline;

  /// No description provided for @parametersAndExecution.
  ///
  /// In en, this message translates to:
  /// **'Parameters & Execution'**
  String get parametersAndExecution;

  /// No description provided for @runScriptWithSteps.
  ///
  /// In en, this message translates to:
  /// **'Run Script ({count, plural, =1{1 step} other{{count} steps}})'**
  String runScriptWithSteps(int count);

  /// No description provided for @variableTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get variableTypeText;

  /// No description provided for @variableTypeTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get variableTypeTimestamp;

  /// No description provided for @variableTypeNumeric.
  ///
  /// In en, this message translates to:
  /// **'Numeric'**
  String get variableTypeNumeric;

  /// No description provided for @stepNumber.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String stepNumber(int number);

  /// No description provided for @targetCluster.
  ///
  /// In en, this message translates to:
  /// **'Target Cluster'**
  String get targetCluster;

  /// No description provided for @extractedVariables.
  ///
  /// In en, this message translates to:
  /// **'Extracted'**
  String get extractedVariables;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @schemaAction.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get schemaAction;

  /// No description provided for @scanProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Progress'**
  String get scanProgressTitle;

  /// No description provided for @clearMessagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Messages'**
  String get clearMessagesTooltip;

  /// No description provided for @editCluster.
  ///
  /// In en, this message translates to:
  /// **'Edit Cluster'**
  String get editCluster;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @securityProtocol.
  ///
  /// In en, this message translates to:
  /// **'Security Protocol'**
  String get securityProtocol;

  /// No description provided for @sslConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'SSL Configuration'**
  String get sslConfigurationTitle;

  /// No description provided for @truststoreLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Truststore Location (PEM or JKS)'**
  String get truststoreLocationLabel;

  /// No description provided for @truststorePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Truststore Password'**
  String get truststorePasswordLabel;

  /// No description provided for @keystoreLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Keystore Location (.p12/.pfx/.jks)'**
  String get keystoreLocationLabel;

  /// No description provided for @keystorePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Keystore Password'**
  String get keystorePasswordLabel;

  /// No description provided for @clientCertPemLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Client Certificate PEM Location'**
  String get clientCertPemLocationLabel;

  /// No description provided for @clientKeyPemLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Client Private Key PEM Location'**
  String get clientKeyPemLocationLabel;

  /// No description provided for @clientKeyPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Client Private Key Password'**
  String get clientKeyPasswordLabel;

  /// No description provided for @saslMechanismLabel.
  ///
  /// In en, this message translates to:
  /// **'SASL Mechanism'**
  String get saslMechanismLabel;

  /// No description provided for @kerberosServiceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Kerberos Service Name'**
  String get kerberosServiceNameLabel;

  /// No description provided for @kerberosKeytabPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Kerberos Keytab Path'**
  String get kerberosKeytabPathLabel;

  /// No description provided for @kerberosPrincipalLabel.
  ///
  /// In en, this message translates to:
  /// **'Kerberos Principal'**
  String get kerberosPrincipalLabel;

  /// No description provided for @kerberosConfigPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Kerberos Config (krb5.conf) Path'**
  String get kerberosConfigPathLabel;

  /// No description provided for @oauthbearerTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'OAuthbearer Token'**
  String get oauthbearerTokenLabel;

  /// No description provided for @saslUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'SASL Username'**
  String get saslUsernameLabel;

  /// No description provided for @saslPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'SASL Password'**
  String get saslPasswordLabel;

  /// No description provided for @schemaRegistryUsernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry Username (Optional)'**
  String get schemaRegistryUsernameOptional;

  /// No description provided for @schemaRegistryPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry Password (Optional)'**
  String get schemaRegistryPasswordOptional;

  /// No description provided for @schemaRegistryUrlTypoPort.
  ///
  /// In en, this message translates to:
  /// **'Likely typo: use \':\' for port instead of \'.\''**
  String get schemaRegistryUrlTypoPort;

  /// No description provided for @schemaRegistryUrlMissingProtocol.
  ///
  /// In en, this message translates to:
  /// **'Missing protocol (http:// or https://)'**
  String get schemaRegistryUrlMissingProtocol;

  /// No description provided for @schemaViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Schema Viewer'**
  String get schemaViewerTitle;

  /// No description provided for @noAvroSchemaFound.
  ///
  /// In en, this message translates to:
  /// **'No Avro schema found for this topic.'**
  String get noAvroSchemaFound;

  /// No description provided for @errorLoadingSchema.
  ///
  /// In en, this message translates to:
  /// **'Error loading schema: {error}'**
  String errorLoadingSchema(String error);

  /// No description provided for @noMessagesToDisplay.
  ///
  /// In en, this message translates to:
  /// **'No messages to display'**
  String get noMessagesToDisplay;

  /// No description provided for @copyValueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy value'**
  String get copyValueTooltip;

  /// No description provided for @valueCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Value copied to clipboard'**
  String get valueCopiedToClipboard;

  /// No description provided for @emptyJson.
  ///
  /// In en, this message translates to:
  /// **'Empty JSON'**
  String get emptyJson;

  /// No description provided for @topicNameCopied.
  ///
  /// In en, this message translates to:
  /// **'Topic name copied'**
  String get topicNameCopied;

  /// No description provided for @copyTopicName.
  ///
  /// In en, this message translates to:
  /// **'Copy Topic Name'**
  String get copyTopicName;

  /// No description provided for @clusterNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Cluster Name'**
  String get clusterNameLabel;

  /// No description provided for @requiredValidation.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredValidation;

  /// No description provided for @bootstrapServersLabel.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap Servers (e.g. localhost:9092)'**
  String get bootstrapServersLabel;

  /// No description provided for @schemaRegistryUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry URL (Optional)'**
  String get schemaRegistryUrlLabel;

  /// No description provided for @invalidUrlFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format'**
  String get invalidUrlFormat;

  /// No description provided for @keySchemaTitle.
  ///
  /// In en, this message translates to:
  /// **'Key Schema'**
  String get keySchemaTitle;

  /// No description provided for @valueSchemaTitle.
  ///
  /// In en, this message translates to:
  /// **'Value Schema'**
  String get valueSchemaTitle;

  /// No description provided for @schemaTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get schemaTabTitle;

  /// No description provided for @schemaPinAsColumn.
  ///
  /// In en, this message translates to:
  /// **'Pin as table column'**
  String get schemaPinAsColumn;

  /// No description provided for @schemaPinAsColumnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pin this schema field as a projected table column'**
  String get schemaPinAsColumnTooltip;

  /// No description provided for @schemaFilterByField.
  ///
  /// In en, this message translates to:
  /// **'Filter by this field'**
  String get schemaFilterByField;

  /// No description provided for @schemaFilterByFieldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter topic messages by this schema field'**
  String get schemaFilterByFieldTooltip;

  /// No description provided for @schemaFieldFilterApplied.
  ///
  /// In en, this message translates to:
  /// **'Filter field set to \'{field}\''**
  String schemaFieldFilterApplied(String field);

  /// No description provided for @schemaNoRegistryConfigured.
  ///
  /// In en, this message translates to:
  /// **'No Schema Registry configured for this cluster.'**
  String get schemaNoRegistryConfigured;

  /// No description provided for @schemaConfigureRegistryAction.
  ///
  /// In en, this message translates to:
  /// **'Configure Cluster'**
  String get schemaConfigureRegistryAction;

  /// No description provided for @schemaRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get schemaRetry;

  /// No description provided for @schemaSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search schema fields and types...'**
  String get schemaSearchHint;

  /// No description provided for @schemaVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get schemaVersionLabel;

  /// No description provided for @schemaSideKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get schemaSideKey;

  /// No description provided for @schemaSideValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get schemaSideValue;

  /// No description provided for @schemaNone.
  ///
  /// In en, this message translates to:
  /// **'no registry schema'**
  String get schemaNone;

  /// No description provided for @lagTrendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Readings: {readings} - highest {high}, lowest {low}'**
  String lagTrendTooltip(Object readings, Object high, Object low);

  /// No description provided for @lagOverThreshold.
  ///
  /// In en, this message translates to:
  /// **'Above the warning threshold of {threshold} messages'**
  String lagOverThreshold(Object threshold);

  /// No description provided for @lagWarnThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumer lag warning threshold (messages)'**
  String get lagWarnThresholdLabel;

  /// No description provided for @lagWarnThresholdHelp.
  ///
  /// In en, this message translates to:
  /// **'0 disables the warning in the lag view.'**
  String get lagWarnThresholdHelp;

  /// No description provided for @comparisonAction.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get comparisonAction;

  /// No description provided for @comparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Report comparison'**
  String get comparisonTitle;

  /// No description provided for @comparisonSourceLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get comparisonSourceLive;

  /// No description provided for @comparisonSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get comparisonSourceImported;

  /// No description provided for @comparisonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get comparisonNotAvailable;

  /// No description provided for @comparisonFieldsAdded.
  ///
  /// In en, this message translates to:
  /// **'Fields added'**
  String get comparisonFieldsAdded;

  /// No description provided for @comparisonFieldsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Fields removed'**
  String get comparisonFieldsRemoved;

  /// No description provided for @comparisonBusiestPartition.
  ///
  /// In en, this message translates to:
  /// **'Busiest partition share'**
  String get comparisonBusiestPartition;

  /// No description provided for @comparisonMinSize.
  ///
  /// In en, this message translates to:
  /// **'Min message size'**
  String get comparisonMinSize;

  /// No description provided for @comparisonMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Max message size'**
  String get comparisonMaxSize;

  /// No description provided for @comparisonAwaitingSecond.
  ///
  /// In en, this message translates to:
  /// **'Select the second report to compare.'**
  String get comparisonAwaitingSecond;

  /// No description provided for @comparisonTopicMismatch.
  ///
  /// In en, this message translates to:
  /// **'Cannot compare reports of different topics: {topicA} and {topicB}.'**
  String comparisonTopicMismatch(Object topicA, Object topicB);

  /// No description provided for @sizePercentiles.
  ///
  /// In en, this message translates to:
  /// **'p50/p95/p99'**
  String get sizePercentiles;

  /// No description provided for @estimatedIndicator.
  ///
  /// In en, this message translates to:
  /// **'estimated'**
  String get estimatedIndicator;

  /// No description provided for @distinctKeys.
  ///
  /// In en, this message translates to:
  /// **'Distinct keys'**
  String get distinctKeys;

  /// No description provided for @cappedIndicator.
  ///
  /// In en, this message translates to:
  /// **'capped'**
  String get cappedIndicator;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
