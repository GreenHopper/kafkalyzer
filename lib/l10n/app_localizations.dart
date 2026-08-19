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
  /// **'{current} / {total} matches'**
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

  /// No description provided for @startCondition.
  ///
  /// In en, this message translates to:
  /// **'Start Condition'**
  String get startCondition;

  /// No description provided for @stopCondition.
  ///
  /// In en, this message translates to:
  /// **'Stop Condition'**
  String get stopCondition;

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
