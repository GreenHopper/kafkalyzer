// ignore_for_file: deprecated_member_use

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

  /// No description provided for @tombstones.
  ///
  /// In en, this message translates to:
  /// **'Tombstones'**
  String get tombstones;

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

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @stepMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String stepMatches(int count);

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

  /// No description provided for @scanned.
  ///
  /// In en, this message translates to:
  /// **'{count} scanned'**
  String scanned(int count);

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

  /// No description provided for @noPastRunsFound.
  ///
  /// In en, this message translates to:
  /// **'No past runs found.'**
  String get noPastRunsFound;

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

  /// No description provided for @noHeaders.
  ///
  /// In en, this message translates to:
  /// **'No headers present on this message'**
  String get noHeaders;

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

  /// No description provided for @scriptRunMatchedOfExamined.
  ///
  /// In en, this message translates to:
  /// **'{matched} of {examined}'**
  String scriptRunMatchedOfExamined(int matched, int examined);

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

  /// No description provided for @clearRecentTopics.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearRecentTopics;

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

  /// No description provided for @partitionHealthDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Partition Health & Replication'**
  String get partitionHealthDialogTitle;

  /// No description provided for @partitionHealthTooltip.
  ///
  /// In en, this message translates to:
  /// **'View partition replication & health details'**
  String get partitionHealthTooltip;

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

  /// No description provided for @maxConcurrentLagQueries.
  ///
  /// In en, this message translates to:
  /// **'Maximum Concurrent Lag Queries'**
  String get maxConcurrentLagQueries;

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

  /// No description provided for @noSchemaFound.
  ///
  /// In en, this message translates to:
  /// **'No schema found for this topic.'**
  String get noSchemaFound;

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

  /// No description provided for @schemaPinAsColumnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pin this schema field as a projected table column'**
  String get schemaPinAsColumnTooltip;

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

  /// No description provided for @exportAsJson.
  ///
  /// In en, this message translates to:
  /// **'JSON (Full Payload)'**
  String get exportAsJson;

  /// No description provided for @exportAsNdjson.
  ///
  /// In en, this message translates to:
  /// **'NDJSON (One Message per Line)'**
  String get exportAsNdjson;

  /// No description provided for @exportAsCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (Visible Columns)'**
  String get exportAsCsv;

  /// No description provided for @exportMessagesCsv.
  ///
  /// In en, this message translates to:
  /// **'Export Messages as CSV'**
  String get exportMessagesCsv;

  /// No description provided for @exportSelectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only selected messages ({count})'**
  String exportSelectedOnly(int count);

  /// No description provided for @exportIncludeDimmedNonMatches.
  ///
  /// In en, this message translates to:
  /// **'Include dimmed non-matches'**
  String get exportIncludeDimmedNonMatches;

  /// No description provided for @exportAddHeadersColumn.
  ///
  /// In en, this message translates to:
  /// **'Add Headers column (CSV)'**
  String get exportAddHeadersColumn;

  /// No description provided for @pauseView.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseView;

  /// No description provided for @pauseViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Freeze the result view while consumption continues in the background'**
  String get pauseViewTooltip;

  /// No description provided for @resumeViewWithNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Resume} one{Resume · 1 new} other{Resume · {count} new}}'**
  String resumeViewWithNew(int count);

  /// No description provided for @resumeViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume live updates and merge buffered messages'**
  String get resumeViewTooltip;

  /// No description provided for @followNewest.
  ///
  /// In en, this message translates to:
  /// **'Follow newest'**
  String get followNewest;

  /// No description provided for @followNewestOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Following newest messages; click or scroll to pause following'**
  String get followNewestOnTooltip;

  /// No description provided for @followNewestOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Jump to newest messages and keep following'**
  String get followNewestOffTooltip;

  /// No description provided for @followNewestDisabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'Follow newest requires sorting by Timestamp'**
  String get followNewestDisabledTooltip;

  /// No description provided for @droppedMessagesIndicator.
  ///
  /// In en, this message translates to:
  /// **'{dropped} oldest messages dropped (limit {limit})'**
  String droppedMessagesIndicator(String dropped, String limit);

  /// No description provided for @droppedMessagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Oldest messages were dropped when the buffer reached its limit. Adjust in Settings → General.'**
  String get droppedMessagesTooltip;

  /// No description provided for @messageBufferLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Message buffer limit'**
  String get messageBufferLimitLabel;

  /// No description provided for @messageBufferLimitHelper.
  ///
  /// In en, this message translates to:
  /// **'Maximum retained messages per topic tab or search target (1,000–1,000,000)'**
  String get messageBufferLimitHelper;

  /// No description provided for @messageBufferLimitError.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number between 1,000 and 1,000,000'**
  String get messageBufferLimitError;

  /// No description provided for @searchPresets.
  ///
  /// In en, this message translates to:
  /// **'Search Presets'**
  String get searchPresets;

  /// No description provided for @defaultPreset.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultPreset;

  /// No description provided for @saveSearchPreset.
  ///
  /// In en, this message translates to:
  /// **'Save Current Search...'**
  String get saveSearchPreset;

  /// No description provided for @savePresetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Search Preset'**
  String get savePresetDialogTitle;

  /// No description provided for @presetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get presetNameLabel;

  /// No description provided for @presetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset saved'**
  String get presetSaved;

  /// No description provided for @presetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Preset deleted'**
  String get presetDeleted;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get deletePreset;

  /// No description provided for @restoreOpenTabsOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Restore open tabs on startup'**
  String get restoreOpenTabsOnStartup;

  /// No description provided for @restoreOpenTabsOnStartupDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically reopen previously opened topic tabs when reconnecting to a cluster'**
  String get restoreOpenTabsOnStartupDescription;

  /// No description provided for @copyCliCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy Headless CLI Command'**
  String get copyCliCommand;

  /// No description provided for @cliCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'CLI command copied to clipboard'**
  String get cliCommandCopied;

  /// No description provided for @protectedByOsKeyring.
  ///
  /// In en, this message translates to:
  /// **'Protected by OS Keyring'**
  String get protectedByOsKeyring;

  /// No description provided for @includeCredentialsInExport.
  ///
  /// In en, this message translates to:
  /// **'Include passwords and tokens in export'**
  String get includeCredentialsInExport;

  /// No description provided for @includeCredentialsWarning.
  ///
  /// In en, this message translates to:
  /// **'Credentials will be encrypted with your passphrase in an age archive (.zip.age).'**
  String get includeCredentialsWarning;

  /// No description provided for @readOnlyBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Read-Only'**
  String get readOnlyBadgeLabel;

  /// No description provided for @readOnlyBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'kafkalyzer is strictly read-only by design. No write, publish, or offset commit operations are performed.'**
  String get readOnlyBadgeTooltip;

  /// No description provided for @readOnlySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Read-Only Architecture & Security'**
  String get readOnlySecurityTitle;

  /// No description provided for @readOnlySecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'kafkalyzer connects to Kafka exclusively as a consumer with manual partition assignment and auto-commits disabled. It contains no producer logic and cannot alter broker topics, configurations, or consumer group offsets.'**
  String get readOnlySecurityDescription;

  /// No description provided for @readOnlyAclRecommendationTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended Least-Privilege ACLs'**
  String get readOnlyAclRecommendationTitle;

  /// No description provided for @readOnlyAclRecommendationDescription.
  ///
  /// In en, this message translates to:
  /// **'For defense-in-depth, configure broker ACLs so the service account has only read permissions (Describe, Read, DescribeConfigs). Do not grant Write, AlterConfigs, or IdempotentWrite.'**
  String get readOnlyAclRecommendationDescription;

  /// No description provided for @readOnlyAclCommandTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic ACL command template:'**
  String get readOnlyAclCommandTopicLabel;

  /// No description provided for @readOnlyAclCommandGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumer Group ACL command template:'**
  String get readOnlyAclCommandGroupLabel;

  /// No description provided for @readOnlyCopyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy ACL Commands'**
  String get readOnlyCopyCommand;

  /// No description provided for @readOnlyAclCommandsCopied.
  ///
  /// In en, this message translates to:
  /// **'ACL commands copied to clipboard'**
  String get readOnlyAclCommandsCopied;

  /// No description provided for @compareSchemaVersions.
  ///
  /// In en, this message translates to:
  /// **'Compare Versions'**
  String get compareSchemaVersions;

  /// No description provided for @schemaDiffTitle.
  ///
  /// In en, this message translates to:
  /// **'Schema Version Diff'**
  String get schemaDiffTitle;

  /// No description provided for @baseVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Base Version'**
  String get baseVersionLabel;

  /// No description provided for @compareVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Compare Version'**
  String get compareVersionLabel;

  /// No description provided for @checkCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Check Compatibility'**
  String get checkCompatibility;

  /// No description provided for @schemaCompatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible'**
  String get schemaCompatible;

  /// No description provided for @schemaIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible'**
  String get schemaIncompatible;

  /// No description provided for @compatibilityCheckSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schema is compatible with the selected subject version.'**
  String get compatibilityCheckSuccess;

  /// No description provided for @associatedTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Associated Topics'**
  String get associatedTopicsTitle;

  /// No description provided for @noAssociatedTopicsFound.
  ///
  /// In en, this message translates to:
  /// **'No associated topics found for this subject.'**
  String get noAssociatedTopicsFound;

  /// No description provided for @schemaNoDifferencesFound.
  ///
  /// In en, this message translates to:
  /// **'No differences found between the selected versions.'**
  String get schemaNoDifferencesFound;

  /// No description provided for @draftSchemaLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft Schema (JSON)'**
  String get draftSchemaLabel;

  /// No description provided for @dlqBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'DLQ'**
  String get dlqBadgeLabel;

  /// No description provided for @retryBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryBadgeLabel;

  /// No description provided for @associatedDlqCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failure topic} other{{count} failure topics}}'**
  String associatedDlqCount(int count);

  /// No description provided for @failureDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Failure Diagnostics (DLQ)'**
  String get failureDiagnosticsTitle;

  /// No description provided for @exceptionMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Exception'**
  String get exceptionMessageLabel;

  /// No description provided for @originalCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Origin: {topic} [P: {partition}, O: {offset}]'**
  String originalCoordinates(String topic, int partition, int offset);

  /// No description provided for @jumpToOriginalMessage.
  ///
  /// In en, this message translates to:
  /// **'Jump to Original Message'**
  String get jumpToOriginalMessage;

  /// No description provided for @copyFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy failed message'**
  String get copyFailedMessage;

  /// No description provided for @failedMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Failed message copied to clipboard'**
  String get failedMessageCopied;

  /// No description provided for @copyShareableLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Shareable Link'**
  String get copyShareableLink;

  /// No description provided for @shareableLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Shareable link copied to clipboard'**
  String get shareableLinkCopied;

  /// No description provided for @quickJumpTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Jump / Open Reference'**
  String get quickJumpTitle;

  /// No description provided for @quickJumpHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a kafkalyzer:// link (e.g. kafkalyzer://open?topic=...&offset=...)'**
  String get quickJumpHint;

  /// No description provided for @quickJumpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid reference URI format'**
  String get quickJumpInvalid;

  /// No description provided for @quickJumpClusterNotFound.
  ///
  /// In en, this message translates to:
  /// **'Cluster \'{cluster}\' not found in configuration. Select a cluster:'**
  String quickJumpClusterNotFound(String cluster);

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get jump;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in Folder'**
  String get showInFolder;

  /// No description provided for @failedToOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file: {error}'**
  String failedToOpenFile(String error);

  /// No description provided for @lagEstimateCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'Caught up'**
  String get lagEstimateCaughtUp;

  /// No description provided for @lagEstimateGrowing.
  ///
  /// In en, this message translates to:
  /// **'Backlog growing'**
  String get lagEstimateGrowing;

  /// No description provided for @lagEstimateStalled.
  ///
  /// In en, this message translates to:
  /// **'Stalled'**
  String get lagEstimateStalled;

  /// No description provided for @lagEstimatePending.
  ///
  /// In en, this message translates to:
  /// **'Estimating...'**
  String get lagEstimatePending;

  /// No description provided for @lagEstimateRateUnit.
  ///
  /// In en, this message translates to:
  /// **'msg/s'**
  String get lagEstimateRateUnit;

  /// No description provided for @lagEstimateEtaPrefix.
  ///
  /// In en, this message translates to:
  /// **'ETA: {eta}'**
  String lagEstimateEtaPrefix(String eta);

  /// No description provided for @lagEstimateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rate: {rate} | Delta: {delta} over {interval} | Status: {status}'**
  String lagEstimateTooltip(
    String rate,
    String delta,
    String interval,
    String status,
  );

  /// No description provided for @recentProductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Production'**
  String get recentProductionTitle;

  /// No description provided for @window6h.
  ///
  /// In en, this message translates to:
  /// **'6h'**
  String get window6h;

  /// No description provided for @window12h.
  ///
  /// In en, this message translates to:
  /// **'12h'**
  String get window12h;

  /// No description provided for @window24h.
  ///
  /// In en, this message translates to:
  /// **'24h'**
  String get window24h;

  /// No description provided for @window48h.
  ///
  /// In en, this message translates to:
  /// **'48h'**
  String get window48h;

  /// No description provided for @window72h.
  ///
  /// In en, this message translates to:
  /// **'72h'**
  String get window72h;

  /// No description provided for @timelineNotAvailableForReport.
  ///
  /// In en, this message translates to:
  /// **'Timeline is not available for this report.'**
  String get timelineNotAvailableForReport;

  /// No description provided for @timeZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Local time ({timeZone})'**
  String timeZoneLabel(String timeZone);

  /// No description provided for @unusualIncreaseBadge.
  ///
  /// In en, this message translates to:
  /// **'Unusual increase'**
  String get unusualIncreaseBadge;

  /// No description provided for @baselineLabel.
  ///
  /// In en, this message translates to:
  /// **'Baseline: {baseline}'**
  String baselineLabel(String baseline);

  /// No description provided for @noComparisonData.
  ///
  /// In en, this message translates to:
  /// **'No comparison data'**
  String get noComparisonData;

  /// No description provided for @uncoveredHourHint.
  ///
  /// In en, this message translates to:
  /// **'Before coverage start ({count} messages)'**
  String uncoveredHourHint(int count);

  /// No description provided for @currentHourIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete hour'**
  String get currentHourIncomplete;

  /// No description provided for @coverageHint.
  ///
  /// In en, this message translates to:
  /// **'Scan covers the last {hours} hours of this window.'**
  String coverageHint(int hours);

  /// No description provided for @hourlyTooltipMatches.
  ///
  /// In en, this message translates to:
  /// **'{matches} matching ({share}%)'**
  String hourlyTooltipMatches(String matches, String share);

  /// No description provided for @dailyProductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Production Distribution'**
  String get dailyProductionTitle;

  /// No description provided for @dailyProductionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Messages per calendar day'**
  String get dailyProductionSubtitle;

  /// No description provided for @partialCoverageBadge.
  ///
  /// In en, this message translates to:
  /// **'Partial coverage'**
  String get partialCoverageBadge;

  /// No description provided for @dailyMatchesShare.
  ///
  /// In en, this message translates to:
  /// **'{matches} ({share}%)'**
  String dailyMatchesShare(String matches, String share);

  /// No description provided for @valueFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filter by Field Value'**
  String get valueFilterButton;

  /// No description provided for @valueFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Filter: {path} = {value}'**
  String valueFilterActive(String path, String value);

  /// No description provided for @valueFilterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by Field Value'**
  String get valueFilterDialogTitle;

  /// No description provided for @valueFilterDialogFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Field path (e.g. attributes.region)'**
  String get valueFilterDialogFieldPath;

  /// No description provided for @valueFilterDialogValue.
  ///
  /// In en, this message translates to:
  /// **'Exact value'**
  String get valueFilterDialogValue;

  /// No description provided for @valueFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get valueFilterApply;

  /// No description provided for @valueFilterValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Field path cannot be empty'**
  String get valueFilterValidationEmpty;

  /// No description provided for @valueFilterMatchCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Matches'**
  String get valueFilterMatchCardTitle;

  /// No description provided for @valueFilterMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String valueFilterMatchCount(String count);

  /// No description provided for @valueFilterShareOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of all scanned messages'**
  String valueFilterShareOfTotal(String percent);

  /// No description provided for @valueFilterShareOfField.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of messages with this field'**
  String valueFilterShareOfField(String percent);

  /// No description provided for @valueFilterRemainder.
  ///
  /// In en, this message translates to:
  /// **'{remainder} non-matching messages'**
  String valueFilterRemainder(String remainder);

  /// No description provided for @drillDownDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Field Value Details'**
  String get drillDownDialogTitle;

  /// No description provided for @drillDownFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Field: {path}'**
  String drillDownFieldPath(String path);

  /// No description provided for @drillDownCount.
  ///
  /// In en, this message translates to:
  /// **'Count: {count}'**
  String drillDownCount(String count);

  /// No description provided for @drillDownShareOfAll.
  ///
  /// In en, this message translates to:
  /// **'Share of all messages: {percent}%'**
  String drillDownShareOfAll(String percent);

  /// No description provided for @drillDownShareOfField.
  ///
  /// In en, this message translates to:
  /// **'Share of field occurrences: {percent}%'**
  String drillDownShareOfField(String percent);

  /// No description provided for @drillDownRescanButton.
  ///
  /// In en, this message translates to:
  /// **'Re-scan with this filter'**
  String get drillDownRescanButton;

  /// No description provided for @drillDownApproximateBadge.
  ///
  /// In en, this message translates to:
  /// **'Approximate (values capped)'**
  String get drillDownApproximateBadge;

  /// No description provided for @drillDownTruncatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Value was truncated (>80 chars). Re-scan cannot use truncated values.'**
  String get drillDownTruncatedNotice;

  /// No description provided for @drillDownRescanUnavailableImported.
  ///
  /// In en, this message translates to:
  /// **'Re-scan is not available for imported reports.'**
  String get drillDownRescanUnavailableImported;

  /// No description provided for @duplicateScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Scope'**
  String get duplicateScopeLabel;

  /// No description provided for @duplicateScopePayloadOnly.
  ///
  /// In en, this message translates to:
  /// **'Payload (Value)'**
  String get duplicateScopePayloadOnly;

  /// No description provided for @duplicateScopeKeyAndPayload.
  ///
  /// In en, this message translates to:
  /// **'Key + Payload'**
  String get duplicateScopeKeyAndPayload;

  /// No description provided for @duplicateMessagesCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Messages'**
  String get duplicateMessagesCardTitle;

  /// No description provided for @duplicateMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{unique} unique • {scope}'**
  String duplicateMessagesSubtitle(String unique, String scope);

  /// No description provided for @topDuplicatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Duplicated Messages'**
  String get topDuplicatesTitle;

  /// No description provided for @topDuplicatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Showing up to 20 most frequent duplicated messages'**
  String get topDuplicatesSubtitle;

  /// No description provided for @noDuplicatesDetected.
  ///
  /// In en, this message translates to:
  /// **'No duplicate messages detected in this scan.'**
  String get noDuplicatesDetected;

  /// No description provided for @duplicateAnalysisUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Duplicate analysis is not available for this report.'**
  String get duplicateAnalysisUnavailable;

  /// No description provided for @sampleLocation.
  ///
  /// In en, this message translates to:
  /// **'Partition {partition}, Offset {offset}'**
  String sampleLocation(int partition, int offset);

  /// No description provided for @copyPayload.
  ///
  /// In en, this message translates to:
  /// **'Copy payload'**
  String get copyPayload;

  /// No description provided for @copyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get copyKey;

  /// No description provided for @copiedPayload.
  ///
  /// In en, this message translates to:
  /// **'Payload copied to clipboard'**
  String get copiedPayload;

  /// No description provided for @copiedKey.
  ///
  /// In en, this message translates to:
  /// **'Key copied to clipboard'**
  String get copiedKey;

  /// No description provided for @duplicateRankHeader.
  ///
  /// In en, this message translates to:
  /// **'#'**
  String get duplicateRankHeader;

  /// No description provided for @duplicateCountHeader.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get duplicateCountHeader;

  /// No description provided for @duplicateKeyHeader.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get duplicateKeyHeader;

  /// No description provided for @duplicatePayloadPreviewHeader.
  ///
  /// In en, this message translates to:
  /// **'Payload Preview'**
  String get duplicatePayloadPreviewHeader;

  /// No description provided for @duplicateSampleCoordinatesHeader.
  ///
  /// In en, this message translates to:
  /// **'Sample Location'**
  String get duplicateSampleCoordinatesHeader;

  /// No description provided for @duplicateDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Message Details'**
  String get duplicateDetailsTitle;

  /// No description provided for @duplicateDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rank #{rank} • {count} occurrences ({share}%)'**
  String duplicateDetailsSubtitle(int rank, String count, String share);

  /// No description provided for @openInMessages.
  ///
  /// In en, this message translates to:
  /// **'Open in Messages'**
  String get openInMessages;

  /// No description provided for @filterDuplicatesInMessages.
  ///
  /// In en, this message translates to:
  /// **'Filter in Messages'**
  String get filterDuplicatesInMessages;

  /// No description provided for @jumpToSampleOffset.
  ///
  /// In en, this message translates to:
  /// **'Jump to Sample'**
  String get jumpToSampleOffset;

  /// No description provided for @duplicateKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get duplicateKey;

  /// No description provided for @duplicatePayload.
  ///
  /// In en, this message translates to:
  /// **'Decoded Payload'**
  String get duplicatePayload;

  /// No description provided for @inspectDuplicateTooltip.
  ///
  /// In en, this message translates to:
  /// **'View duplicate details'**
  String get inspectDuplicateTooltip;

  /// No description provided for @importRejectedUnsafeEntry.
  ///
  /// In en, this message translates to:
  /// **'Import rejected: archive contains an unsafe entry ({entry}).'**
  String importRejectedUnsafeEntry(String entry);

  /// No description provided for @clusterNameAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'A cluster profile with this name already exists.'**
  String get clusterNameAlreadyUsed;

  /// No description provided for @importConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Cluster Profile Conflict'**
  String get importConflictTitle;

  /// No description provided for @importConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'A cluster profile named \"{name}\" already exists.'**
  String importConflictMessage(String name);

  /// No description provided for @importConflictReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace existing'**
  String get importConflictReplace;

  /// No description provided for @importConflictRename.
  ///
  /// In en, this message translates to:
  /// **'Import as new name'**
  String get importConflictRename;

  /// No description provided for @importConflictSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get importConflictSkip;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported {added} added, {replaced} replaced, {renamed} renamed, {skipped} skipped.'**
  String importSummary(int added, int replaced, int renamed, int skipped);

  /// No description provided for @keyringUnavailableNotice.
  ///
  /// In en, this message translates to:
  /// **'System keyring is unavailable. Credentials are kept in memory for this session only and will not be persisted securely.'**
  String get keyringUnavailableNotice;

  /// No description provided for @profileStoreUnreadableNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved cluster profiles could not be read and were left untouched so nothing is lost.'**
  String get profileStoreUnreadableNotice;

  /// No description provided for @scriptStoreUnreadableNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved scripts could not be read and were left untouched so nothing is lost.'**
  String get scriptStoreUnreadableNotice;

  /// No description provided for @storeBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'Backup saved at: {path}'**
  String storeBackupLocation(String path);

  /// No description provided for @storeBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'No backup file could be written.'**
  String get storeBackupFailed;

  /// No description provided for @storePartiallyUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count} unreadable saved {store} {count, plural, =1{entry was} other{entries were}} skipped and preserved.'**
  String storePartiallyUnreadable(int count, String store);

  /// No description provided for @duplicateProfileNamesNotice.
  ///
  /// In en, this message translates to:
  /// **'Duplicate cluster profile names detected: {names}. Please rename duplicates so each profile has a unique name.'**
  String duplicateProfileNamesNotice(String names);

  /// No description provided for @discardUnreadableData.
  ///
  /// In en, this message translates to:
  /// **'Discard unreadable data'**
  String get discardUnreadableData;

  /// No description provided for @discardUnreadableConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the unreadable stored data so you can save new items. Continue?'**
  String get discardUnreadableConfirm;

  /// No description provided for @copyBackupPath.
  ///
  /// In en, this message translates to:
  /// **'Copy backup path'**
  String get copyBackupPath;

  /// No description provided for @storeUnreadableActionRefused.
  ///
  /// In en, this message translates to:
  /// **'Action refused while stored data is unreadable. Discard unreadable data or restore the backup first.'**
  String get storeUnreadableActionRefused;

  /// No description provided for @passwordsNotPersistedTooltip.
  ///
  /// In en, this message translates to:
  /// **'System keyring is unavailable. This password will not be persisted across restarts.'**
  String get passwordsNotPersistedTooltip;

  /// No description provided for @insecureTlsBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Insecure TLS'**
  String get insecureTlsBadgeLabel;

  /// No description provided for @insecureTlsBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'TLS certificate verification is disabled for this cluster profile.'**
  String get insecureTlsBadgeTooltip;

  /// No description provided for @tlsVerificationSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Verify TLS certificates'**
  String get tlsVerificationSwitchLabel;

  /// No description provided for @tlsVerificationDisabledWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: Certificate and hostname verification is disabled for this profile. Connections are vulnerable to interception.'**
  String get tlsVerificationDisabledWarning;

  /// No description provided for @tlsTransitionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'TLS certificate verification failed'**
  String get tlsTransitionDialogTitle;

  /// No description provided for @tlsTransitionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification failed when checking cluster \"{clusterName}\". Choose whether to keep TLS verification enabled (recommended) or disable it for this profile.\n\nDetails: {error}'**
  String tlsTransitionDialogBody(String clusterName, String error);

  /// No description provided for @tlsTransitionKeepEnabled.
  ///
  /// In en, this message translates to:
  /// **'Keep verification on'**
  String get tlsTransitionKeepEnabled;

  /// No description provided for @tlsTransitionDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable verification (insecure)'**
  String get tlsTransitionDisable;

  /// No description provided for @messageFetchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch messages'**
  String get messageFetchFailedTitle;

  /// No description provided for @topicsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load topics'**
  String get topicsLoadFailedTitle;

  /// No description provided for @subjectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schemas: {error}'**
  String subjectsLoadFailed(String error);

  /// No description provided for @columnFiltersNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No rows match the active column filters.'**
  String get columnFiltersNoMatch;

  /// No description provided for @resetColumnFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetColumnFilters;

  /// No description provided for @lagUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get lagUnknown;

  /// No description provided for @lagNoCommit.
  ///
  /// In en, this message translates to:
  /// **'No commit'**
  String get lagNoCommit;

  /// No description provided for @lagNoCommittedOffsets.
  ///
  /// In en, this message translates to:
  /// **'No committed offsets'**
  String get lagNoCommittedOffsets;

  /// No description provided for @lagGroupsLoadedProgress.
  ///
  /// In en, this message translates to:
  /// **'{loaded} of {total} loaded'**
  String lagGroupsLoadedProgress(int loaded, int total);

  /// No description provided for @lagTotalIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Total incomplete'**
  String get lagTotalIncomplete;

  /// No description provided for @lagErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get lagErrorLabel;

  /// No description provided for @lagErrorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lag error: {error}'**
  String lagErrorTooltip(String error);

  /// No description provided for @lagRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lagRetryAction;

  /// No description provided for @lagRefreshInProgress.
  ///
  /// In en, this message translates to:
  /// **'Refresh in progress'**
  String get lagRefreshInProgress;

  /// No description provided for @partitionOwnershipUnknown.
  ///
  /// In en, this message translates to:
  /// **'Partition ownership unknown'**
  String get partitionOwnershipUnknown;

  /// No description provided for @diagStageNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get diagStageNetwork;

  /// No description provided for @diagStageTls.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get diagStageTls;

  /// No description provided for @diagStageAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get diagStageAuthentication;

  /// No description provided for @diagStageMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get diagStageMetadata;

  /// No description provided for @diagStageSchemaRegistry.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry'**
  String get diagStageSchemaRegistry;

  /// No description provided for @diagStateOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get diagStateOk;

  /// No description provided for @diagStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get diagStateFailed;

  /// No description provided for @diagStateNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get diagStateNotChecked;

  /// No description provided for @diagStateNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get diagStateNotApplicable;

  /// No description provided for @diagStateUndetermined.
  ///
  /// In en, this message translates to:
  /// **'Undetermined'**
  String get diagStateUndetermined;

  /// No description provided for @diagNotCheckedPreviousFailed.
  ///
  /// In en, this message translates to:
  /// **'Skipped because {stage} failed'**
  String diagNotCheckedPreviousFailed(String stage);

  /// No description provided for @diagNotCheckedBudgetExhausted.
  ///
  /// In en, this message translates to:
  /// **'Skipped because the diagnosis time budget ran out'**
  String get diagNotCheckedBudgetExhausted;

  /// No description provided for @diagOverallOk.
  ///
  /// In en, this message translates to:
  /// **'Connection succeeded across all applicable stages'**
  String get diagOverallOk;

  /// No description provided for @diagOverallFailedAtStage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed at stage: {stage}'**
  String diagOverallFailedAtStage(String stage);

  /// No description provided for @diagOverallStageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, stage unknown'**
  String get diagOverallStageUnknown;

  /// No description provided for @diagHintInvalidEntry.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap entry is invalid (expected host:port without scheme)'**
  String get diagHintInvalidEntry;

  /// No description provided for @diagHintHostUnknown.
  ///
  /// In en, this message translates to:
  /// **'Host name could not be resolved'**
  String get diagHintHostUnknown;

  /// No description provided for @diagHintConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection refused by host'**
  String get diagHintConnectionRefused;

  /// No description provided for @diagHintConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get diagHintConnectTimeout;

  /// No description provided for @diagHintCertificateRejected.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification failed — check truststore/CA or hostname'**
  String get diagHintCertificateRejected;

  /// No description provided for @diagHintTlsHandshakeFailed.
  ///
  /// In en, this message translates to:
  /// **'TLS handshake failed — check client/server certificates and TLS settings'**
  String get diagHintTlsHandshakeFailed;

  /// No description provided for @diagHintProtocolMismatch.
  ///
  /// In en, this message translates to:
  /// **'Security protocol does not match the broker listener'**
  String get diagHintProtocolMismatch;

  /// No description provided for @diagHintAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed — check SASL username and password'**
  String get diagHintAuthenticationFailed;

  /// No description provided for @diagHintMechanismRejected.
  ///
  /// In en, this message translates to:
  /// **'SASL mechanism rejected or not supported by broker listener'**
  String get diagHintMechanismRejected;

  /// No description provided for @diagHintNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized to describe cluster metadata (check ACLs)'**
  String get diagHintNotAuthorized;

  /// No description provided for @diagHintRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get diagHintRequestTimeout;

  /// No description provided for @diagHintRegistryUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry is unreachable'**
  String get diagHintRegistryUnreachable;

  /// No description provided for @diagHintRegistryUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry rejected credentials'**
  String get diagHintRegistryUnauthorized;

  /// No description provided for @diagHintRegistryHttpError.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry returned HTTP {status}'**
  String diagHintRegistryHttpError(int status);

  /// No description provided for @diagHintGeneric.
  ///
  /// In en, this message translates to:
  /// **'Connection check failed'**
  String get diagHintGeneric;

  /// No description provided for @diagServerDnsLabel.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get diagServerDnsLabel;

  /// No description provided for @diagServerTcpLabel.
  ///
  /// In en, this message translates to:
  /// **'TCP'**
  String get diagServerTcpLabel;

  /// No description provided for @diagServerResolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get diagServerResolvedLabel;

  /// No description provided for @diagServerConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {address}'**
  String diagServerConnectedTo(String address);

  /// No description provided for @diagRawErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Raw error'**
  String get diagRawErrorLabel;

  /// No description provided for @errorUnexpectedNotice.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorUnexpectedNotice;

  /// No description provided for @errorDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get errorDetailsAction;

  /// No description provided for @errorDetailsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Error Details'**
  String get errorDetailsDialogTitle;

  /// No description provided for @errorCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get errorCopyDetails;

  /// No description provided for @errorDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Error details copied to clipboard'**
  String get errorDetailsCopied;

  /// No description provided for @errorDetailsCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy error details to clipboard. You can select and copy the text manually.'**
  String get errorDetailsCopyFailed;

  /// No description provided for @startupFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Kafkalyzer could not start'**
  String get startupFailureTitle;

  /// No description provided for @startupFailureBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error prevented Kafkalyzer from starting. Copy the details below or open the log folder to inspect the full log.'**
  String get startupFailureBody;

  /// No description provided for @startupFailureLogPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get startupFailureLogPathLabel;

  /// No description provided for @diagnosticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get diagnosticsUnavailable;

  /// No description provided for @diagnosticsUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get diagnosticsUnknown;

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsLogPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get settingsDiagnosticsLogPathLabel;

  /// No description provided for @settingsOpenLogFolder.
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get settingsOpenLogFolder;

  /// No description provided for @settingsCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get settingsCopyDiagnostics;

  /// No description provided for @settingsDiagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics report copied to clipboard'**
  String get settingsDiagnosticsCopied;

  /// No description provided for @settingsOpenLogFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open log folder at {path}'**
  String settingsOpenLogFolderFailed(String path);

  /// No description provided for @settingsFileLoggingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File logging is unavailable'**
  String get settingsFileLoggingUnavailable;

  /// No description provided for @settingsAboutButton.
  ///
  /// In en, this message translates to:
  /// **'About Kafkalyzer'**
  String get settingsAboutButton;

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'Read-only Apache Kafka analyzer. Licensed under Apache-2.0.'**
  String get aboutLegalese;

  /// No description provided for @aboutRepositoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Source repository'**
  String get aboutRepositoryLabel;

  /// No description provided for @aboutLogFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Log folder'**
  String get aboutLogFolderLabel;

  /// No description provided for @aboutDataFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings and data folder'**
  String get aboutDataFolderLabel;

  /// No description provided for @aboutOutputFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Default output folder'**
  String get aboutOutputFolderLabel;

  /// No description provided for @aboutOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the repository link in your browser'**
  String get aboutOpenLinkFailed;

  /// No description provided for @settingsKeyboardShortcutsButton.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get settingsKeyboardShortcutsButton;

  /// No description provided for @shortcutOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutOverviewTitle;

  /// No description provided for @shortcutContextGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get shortcutContextGlobal;

  /// No description provided for @shortcutContextExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get shortcutContextExplorer;

  /// No description provided for @shortcutContextScripts.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get shortcutContextScripts;

  /// No description provided for @shortcutContextMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get shortcutContextMessages;

  /// No description provided for @shortcutContextInspector.
  ///
  /// In en, this message translates to:
  /// **'Message Inspector'**
  String get shortcutContextInspector;

  /// No description provided for @shortcutContextInspectorSearch.
  ///
  /// In en, this message translates to:
  /// **'Inspector Search'**
  String get shortcutContextInspectorSearch;

  /// No description provided for @shortcutToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebar'**
  String get shortcutToggleSidebar;

  /// No description provided for @shortcutQuickJump.
  ///
  /// In en, this message translates to:
  /// **'Quick Jump'**
  String get shortcutQuickJump;

  /// No description provided for @shortcutNextMessage.
  ///
  /// In en, this message translates to:
  /// **'Next message'**
  String get shortcutNextMessage;

  /// No description provided for @shortcutPreviousMessage.
  ///
  /// In en, this message translates to:
  /// **'Previous message'**
  String get shortcutPreviousMessage;

  /// No description provided for @shortcutToggleFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Toggle Focus Mode'**
  String get shortcutToggleFocusMode;

  /// No description provided for @shortcutCloseInspectorOrExitFocus.
  ///
  /// In en, this message translates to:
  /// **'Close inspector or exit Focus Mode'**
  String get shortcutCloseInspectorOrExitFocus;

  /// No description provided for @shortcutNextSearchMatch.
  ///
  /// In en, this message translates to:
  /// **'Next search match'**
  String get shortcutNextSearchMatch;

  /// No description provided for @shortcutPreviousSearchMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous search match'**
  String get shortcutPreviousSearchMatch;

  /// No description provided for @shortcutCloseInspectorSearch.
  ///
  /// In en, this message translates to:
  /// **'Close inspector search'**
  String get shortcutCloseInspectorSearch;

  /// No description provided for @shortcutShowOverview.
  ///
  /// In en, this message translates to:
  /// **'Show keyboard shortcuts'**
  String get shortcutShowOverview;

  /// No description provided for @shortcutKeyEscape.
  ///
  /// In en, this message translates to:
  /// **'Escape'**
  String get shortcutKeyEscape;

  /// No description provided for @shortcutKeyEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get shortcutKeyEnter;

  /// No description provided for @shortcutKeyArrowDown.
  ///
  /// In en, this message translates to:
  /// **'Down Arrow'**
  String get shortcutKeyArrowDown;

  /// No description provided for @shortcutKeyArrowUp.
  ///
  /// In en, this message translates to:
  /// **'Up Arrow'**
  String get shortcutKeyArrowUp;

  /// No description provided for @shortcutKeyShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shortcutKeyShift;

  /// No description provided for @shortcutCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get shortcutCommandPalette;

  /// No description provided for @commandPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Search clusters, topics, groups, scripts…'**
  String get commandPaletteHint;

  /// No description provided for @commandPaletteKindDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get commandPaletteKindDestination;

  /// No description provided for @commandPaletteKindCluster.
  ///
  /// In en, this message translates to:
  /// **'Cluster'**
  String get commandPaletteKindCluster;

  /// No description provided for @commandPaletteKindTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get commandPaletteKindTopic;

  /// No description provided for @commandPaletteKindConsumerGroup.
  ///
  /// In en, this message translates to:
  /// **'Consumer Group'**
  String get commandPaletteKindConsumerGroup;

  /// No description provided for @commandPaletteKindScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get commandPaletteKindScript;

  /// No description provided for @commandPaletteKindReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get commandPaletteKindReference;

  /// No description provided for @commandPaletteOpenReference.
  ///
  /// In en, this message translates to:
  /// **'Open reference in Quick Jump'**
  String get commandPaletteOpenReference;

  /// No description provided for @commandPaletteActiveCluster.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get commandPaletteActiveCluster;

  /// No description provided for @commandPaletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get commandPaletteNoResults;

  /// No description provided for @commandPaletteResultsCap.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} matches, keep typing'**
  String commandPaletteResultsCap(int shown, int total);

  /// No description provided for @commandPaletteGroupsNotLoadedNote.
  ///
  /// In en, this message translates to:
  /// **'Consumer groups appear after Consumer Lag has loaded them.'**
  String get commandPaletteGroupsNotLoadedNote;

  /// No description provided for @commandPaletteListLabel.
  ///
  /// In en, this message translates to:
  /// **'Command palette results'**
  String get commandPaletteListLabel;

  /// No description provided for @commandPalettePartitionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 partition} other{{count} partitions}}'**
  String commandPalettePartitionsCount(int count);

  /// No description provided for @commandPaletteStepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String commandPaletteStepsCount(int count);

  /// No description provided for @consumerGroupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Consumer group {id} not found'**
  String consumerGroupNotFound(String id);

  /// No description provided for @scriptNotFound.
  ///
  /// In en, this message translates to:
  /// **'Script not found'**
  String get scriptNotFound;

  /// No description provided for @fastTracePartitionPreview.
  ///
  /// In en, this message translates to:
  /// **'Partition {partition} of {partitionCount}'**
  String fastTracePartitionPreview(int partition, int partitionCount);

  /// No description provided for @fastTracePartitionCountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Partition count unknown'**
  String get fastTracePartitionCountUnknown;

  /// No description provided for @fastTraceEnterKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a key to preview target partition'**
  String get fastTraceEnterKeyHint;

  /// No description provided for @fastTraceFirstTermOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Only the first term selects the scanned partition'**
  String get fastTraceFirstTermOnlyNote;

  /// No description provided for @fastTraceAssumptionSummary.
  ///
  /// In en, this message translates to:
  /// **'Assumes Java default partitioner (murmur2), UTF-8 text key'**
  String get fastTraceAssumptionSummary;

  /// No description provided for @fastTraceAssumptionCaveat.
  ///
  /// In en, this message translates to:
  /// **'Assumes the Java default partitioner hashing the key as UTF-8 text. The actual partition can differ if the producer uses another partitioner (e.g. librdkafka consistent/CRC32 or custom), binary or serialized keys (e.g. Avro keys with Confluent wire prefix), or if partitions were added after the message was produced.'**
  String get fastTraceAssumptionCaveat;

  /// No description provided for @fastTraceAssumptionInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Fast Trace partitioning assumptions'**
  String get fastTraceAssumptionInfoLabel;

  /// No description provided for @chipFastTracePartition.
  ///
  /// In en, this message translates to:
  /// **'Fast Trace → P{partition}'**
  String chipFastTracePartition(int partition);

  /// No description provided for @exportPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get exportPassphraseLabel;

  /// No description provided for @exportPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get exportPassphraseConfirmLabel;

  /// No description provided for @exportPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Passphrase must be at least {min} characters'**
  String exportPassphraseTooShort(int min);

  /// No description provided for @exportPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passphrases do not match'**
  String get exportPassphraseMismatch;

  /// No description provided for @exportPassphraseNotRecoverable.
  ///
  /// In en, this message translates to:
  /// **'A lost passphrase cannot be recovered. Without it, this bundle cannot be opened.'**
  String get exportPassphraseNotRecoverable;

  /// No description provided for @showPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Show passphrase'**
  String get showPassphrase;

  /// No description provided for @hidePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Hide passphrase'**
  String get hidePassphrase;

  /// No description provided for @encryptingBundle.
  ///
  /// In en, this message translates to:
  /// **'Encrypting bundle...'**
  String get encryptingBundle;

  /// No description provided for @importPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter bundle passphrase'**
  String get importPassphraseTitle;

  /// No description provided for @importPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get importPassphraseLabel;

  /// No description provided for @importPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase. Please try again.'**
  String get importPassphraseWrong;

  /// No description provided for @importEncryptedCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The encrypted bundle is damaged or corrupt.'**
  String get importEncryptedCorrupt;

  /// No description provided for @importEncryptedUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This encrypted file is not passphrase-encrypted and cannot be imported.'**
  String get importEncryptedUnsupported;

  /// No description provided for @importEncryptedTooExpensive.
  ///
  /// In en, this message translates to:
  /// **'This encrypted bundle requires too much work to decrypt on this device.'**
  String get importEncryptedTooExpensive;

  /// No description provided for @searchRunning.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searchRunning;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @matchesCountCapped.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}+'**
  String matchesCountCapped(int current, int total);

  /// No description provided for @environmentTagSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment Tag (optional)'**
  String get environmentTagSectionTitle;

  /// No description provided for @environmentLabelField.
  ///
  /// In en, this message translates to:
  /// **'Environment Label'**
  String get environmentLabelField;

  /// No description provided for @environmentLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. DEV, TEST, STAGE, PROD'**
  String get environmentLabelHint;

  /// No description provided for @environmentLabelTooLong.
  ///
  /// In en, this message translates to:
  /// **'Environment label must be at most {max} characters'**
  String environmentLabelTooLong(int max);

  /// No description provided for @environmentSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment: {label}'**
  String environmentSemanticsLabel(String label);

  /// No description provided for @environmentColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get environmentColorRed;

  /// No description provided for @environmentColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get environmentColorOrange;

  /// No description provided for @environmentColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get environmentColorYellow;

  /// No description provided for @environmentColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get environmentColorGreen;

  /// No description provided for @environmentColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get environmentColorBlue;

  /// No description provided for @environmentColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get environmentColorPurple;

  /// No description provided for @environmentColorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get environmentColorGrey;

  /// No description provided for @bootstrapNoEntries.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one host:port entry'**
  String get bootstrapNoEntries;

  /// No description provided for @bootstrapMissingPort.
  ///
  /// In en, this message translates to:
  /// **'Entry \"{entry}\" requires a port (:port)'**
  String bootstrapMissingPort(String entry);

  /// No description provided for @bootstrapInvalidPort.
  ///
  /// In en, this message translates to:
  /// **'Entry \"{entry}\" has an invalid port (1–65535)'**
  String bootstrapInvalidPort(String entry);

  /// No description provided for @bootstrapInvalidHost.
  ///
  /// In en, this message translates to:
  /// **'Entry \"{entry}\" has an invalid host'**
  String bootstrapInvalidHost(String entry);

  /// No description provided for @bootstrapSchemeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Entry \"{entry}\" must not include a URL scheme'**
  String bootstrapSchemeNotAllowed(String entry);

  /// No description provided for @extraPropertiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional client properties'**
  String get extraPropertiesTitle;

  /// No description provided for @extraPropertiesHint.
  ///
  /// In en, this message translates to:
  /// **'One key=value per line'**
  String get extraPropertiesHint;

  /// No description provided for @extraPropertiesAllowedKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Allowed keys'**
  String get extraPropertiesAllowedKeysTitle;

  /// No description provided for @extraPropertiesSyntaxError.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: invalid syntax (expected key=value)'**
  String extraPropertiesSyntaxError(int line);

  /// No description provided for @extraPropertiesNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: \"{key}\" is not allowed'**
  String extraPropertiesNotAllowed(int line, String key);

  /// No description provided for @extraPropertiesInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: invalid value for \"{key}\" (allowed: {allowed})'**
  String extraPropertiesInvalidValue(int line, String key, String allowed);

  /// No description provided for @extraPropertiesDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: duplicate key \"{key}\"'**
  String extraPropertiesDuplicate(int line, String key);

  /// No description provided for @importClientPropertiesAction.
  ///
  /// In en, this message translates to:
  /// **'Import client.properties'**
  String get importClientPropertiesAction;

  /// No description provided for @importClientPropertiesPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import client.properties Preview'**
  String get importClientPropertiesPreviewTitle;

  /// No description provided for @importClientPropertiesMappedSection.
  ///
  /// In en, this message translates to:
  /// **'Profile fields to apply'**
  String get importClientPropertiesMappedSection;

  /// No description provided for @importClientPropertiesExtrasSection.
  ///
  /// In en, this message translates to:
  /// **'Additional properties'**
  String get importClientPropertiesExtrasSection;

  /// No description provided for @importClientPropertiesSkippedSection.
  ///
  /// In en, this message translates to:
  /// **'Not applied'**
  String get importClientPropertiesSkippedSection;

  /// No description provided for @importClientPropertiesApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get importClientPropertiesApplyAction;

  /// No description provided for @importClientPropertiesTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is larger than 1 MiB and cannot be imported.'**
  String get importClientPropertiesTooLarge;

  /// No description provided for @importClientPropertiesInvalidUtf8.
  ///
  /// In en, this message translates to:
  /// **'File is not valid UTF-8 and cannot be read.'**
  String get importClientPropertiesInvalidUtf8;

  /// No description provided for @importClientPropertiesReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read file: {error}'**
  String importClientPropertiesReadError(String error);

  /// No description provided for @importClientPropertiesNothingToApply.
  ///
  /// In en, this message translates to:
  /// **'No supported properties were found in this file.'**
  String get importClientPropertiesNothingToApply;

  /// No description provided for @skipReasonNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Unknown or not allowed'**
  String get skipReasonNotAllowed;

  /// No description provided for @skipReasonUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported type or format'**
  String get skipReasonUnsupported;

  /// No description provided for @skipReasonPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Placeholder cannot be resolved'**
  String get skipReasonPlaceholder;

  /// No description provided for @skipReasonVerificationOverride.
  ///
  /// In en, this message translates to:
  /// **'TLS verification can only be disabled in the dialog'**
  String get skipReasonVerificationOverride;

  /// No description provided for @skipReasonInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value'**
  String get skipReasonInvalidValue;

  /// No description provided for @duplicateClusterAction.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateClusterAction;

  /// No description provided for @duplicateClusterTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Cluster'**
  String get duplicateClusterTitle;

  /// No description provided for @clusterFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter clusters (name, environment, bootstrap)'**
  String get clusterFilterHint;

  /// No description provided for @clusterFilterNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No cluster matches the filter'**
  String get clusterFilterNoMatch;

  /// No description provided for @clusterFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clusterFilterClear;

  /// No description provided for @disconnectClusterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectClusterTooltip;

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {cluster}?'**
  String disconnectConfirmTitle(String cluster);

  /// No description provided for @disconnectConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'A search or analysis is still running for this cluster. Disconnecting will stop it and close its tabs.'**
  String get disconnectConfirmBody;

  /// No description provided for @disconnectConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectConfirmAction;

  /// No description provided for @unrestoredTabsMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tab could not be restored ({topics})} other{{count} tabs could not be restored ({topics})}}'**
  String unrestoredTabsMessage(int count, String topics);

  /// No description provided for @decodeAs.
  ///
  /// In en, this message translates to:
  /// **'Decode as…'**
  String get decodeAs;

  /// No description provided for @decodeAsJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get decodeAsJson;

  /// No description provided for @decodeAsBase64.
  ///
  /// In en, this message translates to:
  /// **'Base64'**
  String get decodeAsBase64;

  /// No description provided for @decodeAsGzip.
  ///
  /// In en, this message translates to:
  /// **'gzip'**
  String get decodeAsGzip;

  /// No description provided for @showOriginalOnly.
  ///
  /// In en, this message translates to:
  /// **'Show original only'**
  String get showOriginalOnly;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @copyDecoded.
  ///
  /// In en, this message translates to:
  /// **'Copy decoded'**
  String get copyDecoded;

  /// No description provided for @copyAsHex.
  ///
  /// In en, this message translates to:
  /// **'Copy as hex'**
  String get copyAsHex;

  /// No description provided for @binaryBytesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String binaryBytesSummary(int count);

  /// No description provided for @decodeErrorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Not valid JSON'**
  String get decodeErrorInvalidJson;

  /// No description provided for @decodeErrorInvalidBase64.
  ///
  /// In en, this message translates to:
  /// **'Not valid Base64'**
  String get decodeErrorInvalidBase64;

  /// No description provided for @decodeErrorNotGzip.
  ///
  /// In en, this message translates to:
  /// **'Not a gzip stream'**
  String get decodeErrorNotGzip;

  /// No description provided for @decodeErrorCorruptGzip.
  ///
  /// In en, this message translates to:
  /// **'Corrupt gzip data'**
  String get decodeErrorCorruptGzip;

  /// No description provided for @decodeErrorInputTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Input exceeds {limitMib} MiB limit'**
  String decodeErrorInputTooLarge(int limitMib);

  /// No description provided for @decodeErrorOutputTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Decoded output exceeds {limitMib} MiB limit'**
  String decodeErrorOutputTooLarge(int limitMib);

  /// No description provided for @epochUnitSeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get epochUnitSeconds;

  /// No description provided for @epochUnitMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'milliseconds'**
  String get epochUnitMilliseconds;

  /// No description provided for @epochUnitMicroseconds.
  ///
  /// In en, this message translates to:
  /// **'microseconds'**
  String get epochUnitMicroseconds;

  /// No description provided for @epochUnitNanoseconds.
  ///
  /// In en, this message translates to:
  /// **'nanoseconds'**
  String get epochUnitNanoseconds;

  /// No description provided for @epochTooltip.
  ///
  /// In en, this message translates to:
  /// **'{primary}\n{secondary}\nAssumed unit: {unit}'**
  String epochTooltip(String primary, String secondary, String unit);

  /// No description provided for @emptyValueMarker.
  ///
  /// In en, this message translates to:
  /// **'Empty value'**
  String get emptyValueMarker;

  /// No description provided for @inspectorKeySection.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get inspectorKeySection;

  /// No description provided for @inspectorHeadersSection.
  ///
  /// In en, this message translates to:
  /// **'Headers ({count})'**
  String inspectorHeadersSection(int count);

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @textSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSizeLabel;

  /// No description provided for @textSizeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom ({percent}%)'**
  String textSizeCustom(int percent);

  /// No description provided for @timeDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get timeDisplayLabel;

  /// No description provided for @timeDisplayLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get timeDisplayLocal;

  /// No description provided for @timeDisplayUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get timeDisplayUtc;

  /// No description provided for @defaultResultLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Default result limit'**
  String get defaultResultLimitLabel;

  /// No description provided for @intSettingRangeHelper.
  ///
  /// In en, this message translates to:
  /// **'Range: {min}–{max} (Default: {defaultValue})'**
  String intSettingRangeHelper(int min, int max, int defaultValue);

  /// No description provided for @intSettingRangeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}'**
  String intSettingRangeError(int min, int max);

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetToDefaults;

  /// No description provided for @resetSectionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset {section} settings?'**
  String resetSectionConfirmTitle(String section);

  /// No description provided for @resetSectionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This restores {section} preferences to their defaults. Cluster profiles, secrets, scripts, and saved searches will not be touched.'**
  String resetSectionConfirmBody(String section);

  /// No description provided for @resetConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetConfirmAction;

  /// No description provided for @manualUpdateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} available'**
  String manualUpdateAvailableTitle(String version);

  /// No description provided for @manualUpdateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A newer release ({version}) is available on GitHub. This installation cannot update automatically.'**
  String manualUpdateAvailableBody(String version);

  /// No description provided for @manualUpToDateHint.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version. Automatic updates are not available for this installation.'**
  String get manualUpToDateHint;

  /// No description provided for @latestReleaseKnownBody.
  ///
  /// In en, this message translates to:
  /// **'Latest release on GitHub: {version}. Running version could not be compared.'**
  String latestReleaseKnownBody(String version);

  /// No description provided for @openReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get openReleasePage;

  /// No description provided for @downloadCancelledSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled. The update will not be installed.'**
  String get downloadCancelledSnackbar;

  /// No description provided for @connectionErrorInvalidBootstrapServers.
  ///
  /// In en, this message translates to:
  /// **'Invalid bootstrap server'**
  String get connectionErrorInvalidBootstrapServers;

  /// No description provided for @connectionErrorTlsVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'TLS certificate verification failed'**
  String get connectionErrorTlsVerificationFailed;

  /// No description provided for @connectionErrorValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed validation'**
  String get connectionErrorValidationFailed;

  /// No description provided for @connectionErrorBrokerTransport.
  ///
  /// In en, this message translates to:
  /// **'Broker transport failure. Check your address and network.'**
  String get connectionErrorBrokerTransport;

  /// No description provided for @connectionErrorConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection refused'**
  String get connectionErrorConnectionRefused;

  /// No description provided for @connectionErrorOther.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionErrorOther;

  /// No description provided for @topicAnalysisEmptyFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Field path cannot be empty'**
  String get topicAnalysisEmptyFieldPath;

  /// No description provided for @topicAnalysisNoPreviousScope.
  ///
  /// In en, this message translates to:
  /// **'No previous analysis scope to rescan'**
  String get topicAnalysisNoPreviousScope;

  /// No description provided for @exportTopicAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Export Topic Analysis'**
  String get exportTopicAnalysis;

  /// No description provided for @importTopicAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Import Topic Analysis'**
  String get importTopicAnalysis;

  /// No description provided for @saveRunArchive.
  ///
  /// In en, this message translates to:
  /// **'Save Run Archive - {name}'**
  String saveRunArchive(String name);

  /// No description provided for @saveSchemaMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Save Schema Markdown'**
  String get saveSchemaMarkdown;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @filterColumnTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter {column}'**
  String filterColumnTitle(String column);

  /// No description provided for @filterSubstringHint.
  ///
  /// In en, this message translates to:
  /// **'Enter substring to filter...'**
  String get filterSubstringHint;

  /// No description provided for @copyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get copyContent;

  /// No description provided for @emptyBinaryData.
  ///
  /// In en, this message translates to:
  /// **'Empty binary data'**
  String get emptyBinaryData;

  /// No description provided for @preparingHexDump.
  ///
  /// In en, this message translates to:
  /// **'Preparing hex dump for clipboard...'**
  String get preparingHexDump;

  /// No description provided for @hexDumpCopied.
  ///
  /// In en, this message translates to:
  /// **'Hex dump copied to clipboard'**
  String get hexDumpCopied;

  /// No description provided for @copyFullHexDump.
  ///
  /// In en, this message translates to:
  /// **'Copy Full Hex Dump'**
  String get copyFullHexDump;

  /// No description provided for @objectCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Object copied to clipboard'**
  String get objectCopiedToClipboard;

  /// No description provided for @entityDetails.
  ///
  /// In en, this message translates to:
  /// **'Entity Details'**
  String get entityDetails;

  /// No description provided for @copyWholeObject.
  ///
  /// In en, this message translates to:
  /// **'Copy whole object'**
  String get copyWholeObject;

  /// No description provided for @errorComputingDiff.
  ///
  /// In en, this message translates to:
  /// **'Error computing diff'**
  String get errorComputingDiff;

  /// No description provided for @globalNoStep.
  ///
  /// In en, this message translates to:
  /// **'Global (No Step)'**
  String get globalNoStep;

  /// No description provided for @stacktrace.
  ///
  /// In en, this message translates to:
  /// **'Stacktrace'**
  String get stacktrace;

  /// No description provided for @noResultsMatchingPhrase.
  ///
  /// In en, this message translates to:
  /// **'No results found matching \'{phrase}\''**
  String noResultsMatchingPhrase(String phrase);

  /// No description provided for @hideNonMatchingMessages.
  ///
  /// In en, this message translates to:
  /// **'Hide non-matching messages'**
  String get hideNonMatchingMessages;

  /// No description provided for @showNonMatchesAsDimmed.
  ///
  /// In en, this message translates to:
  /// **'Show non-matches as dimmed'**
  String get showNonMatchesAsDimmed;

  /// No description provided for @availableTopics.
  ///
  /// In en, this message translates to:
  /// **'Available Topics'**
  String get availableTopics;

  /// No description provided for @optionalMetadataRegistry.
  ///
  /// In en, this message translates to:
  /// **'Optional metadata registry'**
  String get optionalMetadataRegistry;

  /// No description provided for @noClusterSelected.
  ///
  /// In en, this message translates to:
  /// **'No cluster selected'**
  String get noClusterSelected;

  /// No description provided for @quickJumpTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic: {topic}'**
  String quickJumpTopicLabel(String topic);

  /// No description provided for @quickJumpPartitionLabel.
  ///
  /// In en, this message translates to:
  /// **'Partition: {partition}'**
  String quickJumpPartitionLabel(int partition);

  /// No description provided for @quickJumpOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Offset: {offset}'**
  String quickJumpOffsetLabel(int offset);

  /// No description provided for @quickJumpFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: {filter}'**
  String quickJumpFilterLabel(String filter);

  /// No description provided for @schemaRegistryUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {url}'**
  String schemaRegistryUrlHint(String url);

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @fieldOptional.
  ///
  /// In en, this message translates to:
  /// **'Field (Opt.)'**
  String get fieldOptional;

  /// No description provided for @selectTopicsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select Topic ({filtered}/{total})} other{Select Topics ({filtered}/{total})}}'**
  String selectTopicsDialogTitle(int count, int filtered, int total);

  /// No description provided for @kafkaStreamTopics.
  ///
  /// In en, this message translates to:
  /// **'Kafka Stream Topics'**
  String get kafkaStreamTopics;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @selectCount.
  ///
  /// In en, this message translates to:
  /// **'Select ({count})'**
  String selectCount(int count);

  /// No description provided for @selectDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select Date & Time'**
  String get selectDateTime;

  /// No description provided for @presetsRelativeToNow.
  ///
  /// In en, this message translates to:
  /// **'Presets (Relative to Now)'**
  String get presetsRelativeToNow;

  /// No description provided for @selectVersionsToCompare.
  ///
  /// In en, this message translates to:
  /// **'Select versions to compare'**
  String get selectVersionsToCompare;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @unreadableStoredData.
  ///
  /// In en, this message translates to:
  /// **'Unreadable stored data'**
  String get unreadableStoredData;

  /// No description provided for @tombstoneValueNull.
  ///
  /// In en, this message translates to:
  /// **'TOMBSTONE (Value is NULL)'**
  String get tombstoneValueNull;

  /// No description provided for @lagChangeDelta.
  ///
  /// In en, this message translates to:
  /// **'Change: {delta}'**
  String lagChangeDelta(String delta);

  /// No description provided for @ofTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofTotal(String total);

  /// No description provided for @activeStable.
  ///
  /// In en, this message translates to:
  /// **'Active / Stable'**
  String get activeStable;

  /// No description provided for @idleEmptyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Idle/Empty'**
  String idleEmptyCount(String count);

  /// No description provided for @activeQueries.
  ///
  /// In en, this message translates to:
  /// **'Active Queries'**
  String get activeQueries;

  /// No description provided for @queueCount.
  ///
  /// In en, this message translates to:
  /// **'Queue: {count}'**
  String queueCount(int count);

  /// No description provided for @connectingToCluster.
  ///
  /// In en, this message translates to:
  /// **'Connecting to cluster...'**
  String get connectingToCluster;

  /// No description provided for @establishingConnectionOffsets.
  ///
  /// In en, this message translates to:
  /// **'Establishing connection and calculating consumer group offsets...'**
  String get establishingConnectionOffsets;

  /// No description provided for @selectClusterForConsumerLag.
  ///
  /// In en, this message translates to:
  /// **'Select a cluster above to view consumer lag details.'**
  String get selectClusterForConsumerLag;

  /// No description provided for @loadedConsumerGroupsSummary.
  ///
  /// In en, this message translates to:
  /// **'Successfully loaded {count} consumer groups in {seconds}s.'**
  String loadedConsumerGroupsSummary(String count, String seconds);

  /// No description provided for @groupIdCol.
  ///
  /// In en, this message translates to:
  /// **'Group ID'**
  String get groupIdCol;

  /// No description provided for @stateCol.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stateCol;

  /// No description provided for @protocolCol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocolCol;

  /// No description provided for @consumersCol.
  ///
  /// In en, this message translates to:
  /// **'Consumers'**
  String get consumersCol;

  /// No description provided for @processedCol.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get processedCol;

  /// No description provided for @noActivePartitionAssignments.
  ///
  /// In en, this message translates to:
  /// **'No active partition assignments.'**
  String get noActivePartitionAssignments;

  /// No description provided for @noMessageAtOrAfterOffset.
  ///
  /// In en, this message translates to:
  /// **'No message found at or after offset {offset}'**
  String noMessageAtOrAfterOffset(String offset);

  /// No description provided for @viewMessageAtOffset.
  ///
  /// In en, this message translates to:
  /// **'View message at offset'**
  String get viewMessageAtOffset;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @stateAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get stateAll;

  /// No description provided for @stateStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stateStable;

  /// No description provided for @stateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get stateEmpty;

  /// No description provided for @stateDead.
  ///
  /// In en, this message translates to:
  /// **'Dead'**
  String get stateDead;

  /// No description provided for @refreshIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshIntervalLabel;

  /// No description provided for @refreshOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get refreshOff;

  /// No description provided for @scriptName.
  ///
  /// In en, this message translates to:
  /// **'Script Name'**
  String get scriptName;

  /// No description provided for @sourceCol.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceCol;

  /// No description provided for @newVariableName.
  ///
  /// In en, this message translates to:
  /// **'New Variable Name'**
  String get newVariableName;

  /// No description provided for @extractedVars.
  ///
  /// In en, this message translates to:
  /// **'Extracted: {vars}'**
  String extractedVars(String vars);

  /// No description provided for @usedVars.
  ///
  /// In en, this message translates to:
  /// **'Used: {vars}'**
  String usedVars(String vars);

  /// No description provided for @stepNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Step Name'**
  String get stepNameLabel;

  /// No description provided for @valueExtractions.
  ///
  /// In en, this message translates to:
  /// **'Value Extractions'**
  String get valueExtractions;

  /// No description provided for @noExtractionsDefined.
  ///
  /// In en, this message translates to:
  /// **'No extractions defined'**
  String get noExtractionsDefined;

  /// No description provided for @insertVariable.
  ///
  /// In en, this message translates to:
  /// **'Insert Variable'**
  String get insertVariable;

  /// No description provided for @deleteExtraction.
  ///
  /// In en, this message translates to:
  /// **'Delete extraction'**
  String get deleteExtraction;

  /// No description provided for @filterByParameter.
  ///
  /// In en, this message translates to:
  /// **'Filter by {parameter}'**
  String filterByParameter(String parameter);

  /// No description provided for @searchValues.
  ///
  /// In en, this message translates to:
  /// **'Search values'**
  String get searchValues;

  /// No description provided for @selectAllMatches.
  ///
  /// In en, this message translates to:
  /// **'Select All Matches'**
  String get selectAllMatches;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearSelection;

  /// No description provided for @copyValue.
  ///
  /// In en, this message translates to:
  /// **'Copy value'**
  String get copyValue;

  /// No description provided for @copiedValueToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied \'{value}\' to clipboard'**
  String copiedValueToClipboard(String value);

  /// No description provided for @applyWithCount.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count})'**
  String applyWithCount(int count);

  /// No description provided for @noScriptsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No scripts available'**
  String get noScriptsAvailable;

  /// No description provided for @executionProgress.
  ///
  /// In en, this message translates to:
  /// **'Execution Progress'**
  String get executionProgress;

  /// No description provided for @runningEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get runningEllipsis;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @failedToLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load details'**
  String get failedToLoadDetails;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @clusterLabelValue.
  ///
  /// In en, this message translates to:
  /// **'Cluster: {cluster}'**
  String clusterLabelValue(String cluster);

  /// No description provided for @clusterRuntimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Cluster: {cluster} • {runtime}'**
  String clusterRuntimeLabel(String cluster, String runtime);

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String startedAt(String time);

  /// No description provided for @finishedAt.
  ///
  /// In en, this message translates to:
  /// **'Finished: {time}'**
  String finishedAt(String time);

  /// No description provided for @totalRuntime.
  ///
  /// In en, this message translates to:
  /// **'Total Runtime: {duration}'**
  String totalRuntime(String duration);

  /// No description provided for @runHistory.
  ///
  /// In en, this message translates to:
  /// **'Run History'**
  String get runHistory;

  /// No description provided for @importRunArchive.
  ///
  /// In en, this message translates to:
  /// **'Import Run Archive'**
  String get importRunArchive;

  /// No description provided for @matchedAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'{matched} matched / {analyzed} analyzed'**
  String matchedAnalyzed(int matched, int analyzed);

  /// No description provided for @loadResults.
  ///
  /// In en, this message translates to:
  /// **'Load Results'**
  String get loadResults;

  /// No description provided for @runAgain.
  ///
  /// In en, this message translates to:
  /// **'Run Again'**
  String get runAgain;

  /// No description provided for @exportRunArchive.
  ///
  /// In en, this message translates to:
  /// **'Export Run Archive'**
  String get exportRunArchive;

  /// No description provided for @deleteRun.
  ///
  /// In en, this message translates to:
  /// **'Delete Run'**
  String get deleteRun;

  /// No description provided for @deleteRunResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Run Result'**
  String get deleteRunResultTitle;

  /// No description provided for @deleteRunResultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this run result? This cannot be undone.'**
  String get deleteRunResultConfirm;

  /// No description provided for @failedToDeleteRun.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete run: {error}'**
  String failedToDeleteRun(String error);

  /// No description provided for @noSchemaFieldsMatching.
  ///
  /// In en, this message translates to:
  /// **'No schema fields found matching \'{query}\''**
  String noSchemaFieldsMatching(String query);

  /// No description provided for @noSchemasForScriptTopics.
  ///
  /// In en, this message translates to:
  /// **'No schemas found for the current script\'s topics.'**
  String get noSchemasForScriptTopics;

  /// No description provided for @fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field: {field}'**
  String fieldLabel(String field);

  /// No description provided for @foundTimesAcrossTopics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 time} other{Found {count} times}} across {topics, plural, =1{1 topic} other{{topics} topics}}'**
  String foundTimesAcrossTopics(int count, int topics);

  /// No description provided for @copyMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get copyMarkdown;

  /// No description provided for @copiedSchemaToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied {field} schema to clipboard.'**
  String copiedSchemaToClipboard(String field);

  /// No description provided for @downloadMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Download Markdown'**
  String get downloadMarkdown;

  /// No description provided for @savedSchemaToFile.
  ///
  /// In en, this message translates to:
  /// **'Saved schema to file'**
  String get savedSchemaToFile;

  /// No description provided for @foundInTopic.
  ///
  /// In en, this message translates to:
  /// **'Found in topic: {topic}'**
  String foundInTopic(String topic);

  /// No description provided for @pathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path: {path}'**
  String pathLabel(String path);

  /// No description provided for @foundInMultipleLocations.
  ///
  /// In en, this message translates to:
  /// **'Found in multiple locations (differences highlighted):'**
  String get foundInMultipleLocations;

  /// No description provided for @baselineTopic.
  ///
  /// In en, this message translates to:
  /// **'Baseline Topic: {topic}'**
  String baselineTopic(String topic);

  /// No description provided for @comparedToTopic.
  ///
  /// In en, this message translates to:
  /// **'Compared to Topic: {topic}'**
  String comparedToTopic(String topic);

  /// No description provided for @noDifferencesFromBaseline.
  ///
  /// In en, this message translates to:
  /// **'No differences from baseline.'**
  String get noDifferencesFromBaseline;

  /// No description provided for @stepStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get stepStatusPending;

  /// No description provided for @stepStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'RUNNING'**
  String get stepStatusRunning;

  /// No description provided for @stepStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get stepStatusCompleted;

  /// No description provided for @stepStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get stepStatusFailed;

  /// No description provided for @remainingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} remaining} other{{formatted} remaining}}'**
  String remainingCount(int count, String formatted);

  /// No description provided for @matchesFoundScanned.
  ///
  /// In en, this message translates to:
  /// **'{matches, plural, =1{{formattedMatches} match found ({formattedScanned} scanned)} other{{formattedMatches} matches found ({formattedScanned} scanned)}}'**
  String matchesFoundScanned(
    int matches,
    String formattedMatches,
    String formattedScanned,
  );

  /// No description provided for @matchesFoundInTopics.
  ///
  /// In en, this message translates to:
  /// **'{matches, plural, =1{1 match} other{{matches} matches}} found in {topics, plural, =1{1 topic} other{{topics} topics}}'**
  String matchesFoundInTopics(int matches, int topics);

  /// No description provided for @msgsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} msg} other{{formatted} msgs}}'**
  String msgsCount(int count, String formatted);

  /// No description provided for @msgsPerSecCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} msg/sec} other{{formatted} msgs/sec}}'**
  String msgsPerSecCount(int count, String formatted);

  /// No description provided for @emptyAngleBracket.
  ///
  /// In en, this message translates to:
  /// **'<empty>'**
  String get emptyAngleBracket;

  /// No description provided for @partitionOffsetSummary.
  ///
  /// In en, this message translates to:
  /// **'Partition {partition} • Offset {offset}'**
  String partitionOffsetSummary(int partition, int offset);

  /// No description provided for @noStructuredFieldsDetected.
  ///
  /// In en, this message translates to:
  /// **'No structured fields detected'**
  String get noStructuredFieldsDetected;

  /// No description provided for @noScalarValuesForField.
  ///
  /// In en, this message translates to:
  /// **'No scalar values recorded for this field'**
  String get noScalarValuesForField;

  /// No description provided for @peakHourSummary.
  ///
  /// In en, this message translates to:
  /// **'Peak: {hour}:00 UTC ({count} msgs • {percentage}%)'**
  String peakHourSummary(String hour, String count, String percentage);

  /// No description provided for @hourlyTooltipSummary.
  ///
  /// In en, this message translates to:
  /// **'{hour}:00 - {hour}:59 UTC\n{count} msgs ({percentage}%)'**
  String hourlyTooltipSummary(String hour, String count, String percentage);

  /// No description provided for @noKeyedMessagesFound.
  ///
  /// In en, this message translates to:
  /// **'No keyed messages found'**
  String get noKeyedMessagesFound;

  /// No description provided for @noContentTypesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No content types recorded'**
  String get noContentTypesRecorded;

  /// No description provided for @partitionLabel.
  ///
  /// In en, this message translates to:
  /// **'Partition {partition}'**
  String partitionLabel(int partition);

  /// No description provided for @partitionStatsLine.
  ///
  /// In en, this message translates to:
  /// **'{count} msgs ({percentage}%) • {size}'**
  String partitionStatsLine(String count, String percentage, String size);

  /// No description provided for @offsetsRange.
  ///
  /// In en, this message translates to:
  /// **'Offsets: {from} .. {to}'**
  String offsetsRange(String from, String to);

  /// No description provided for @offsetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Offsets: -'**
  String get offsetsEmpty;

  /// No description provided for @durationPartitionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{partitions, plural, =1{{duration} • 1 partition} other{{duration} • {partitions} partitions}}'**
  String durationPartitionsSummary(String duration, int partitions);

  /// No description provided for @analyzingTopicProgress.
  ///
  /// In en, this message translates to:
  /// **'Analyzing topic... ({scanned} / {total} messages • {percentage}%)'**
  String analyzingTopicProgress(
    String scanned,
    String total,
    String percentage,
  );

  /// No description provided for @keyLabelWithColon.
  ///
  /// In en, this message translates to:
  /// **'Key: '**
  String get keyLabelWithColon;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @editVariableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit variable'**
  String get editVariableTooltip;

  /// No description provided for @deleteVariableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete variable'**
  String get deleteVariableTooltip;

  /// No description provided for @addVariableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get addVariableTooltip;

  /// No description provided for @editStepTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit step'**
  String get editStepTooltip;

  /// No description provided for @deleteStepTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete step'**
  String get deleteStepTooltip;

  /// No description provided for @browseDirectoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get browseDirectoryTooltip;

  /// No description provided for @expandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expandTooltip;

  /// No description provided for @collapseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapseTooltip;

  /// No description provided for @selectStepTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select all topics in step'**
  String get selectStepTooltip;

  /// No description provided for @deselectStepTooltip.
  ///
  /// In en, this message translates to:
  /// **'Deselect all topics in step'**
  String get deselectStepTooltip;

  /// No description provided for @filterColumnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter {column}'**
  String filterColumnTooltip(String column);

  /// No description provided for @removeColumnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get removeColumnTooltip;

  /// No description provided for @compositeBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show nested fields'**
  String get compositeBadgeTooltip;

  /// No description provided for @skewedLabel.
  ///
  /// In en, this message translates to:
  /// **'Skewed'**
  String get skewedLabel;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy to clipboard'**
  String get copyFailed;

  /// No description provided for @topicListUpdatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'updated just now'**
  String get topicListUpdatedJustNow;

  /// No description provided for @topicListUpdatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{updated 1 min ago} other{updated {count} min ago}}'**
  String topicListUpdatedMinutesAgo(int count);

  /// No description provided for @topicListUpdatedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{updated 1 hr ago} other{updated {count} hr ago}}'**
  String topicListUpdatedHoursAgo(int count);

  /// No description provided for @topicListHiddenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hidden} other{{count} hidden}}'**
  String topicListHiddenCount(int count);

  /// No description provided for @topicListHiddenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hidden: {internal} internal, {stream} stream, {filter} filtered'**
  String topicListHiddenTooltip(int internal, int stream, int filter);

  /// No description provided for @topicListShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get topicListShowAll;

  /// No description provided for @topicListInvalidPattern.
  ///
  /// In en, this message translates to:
  /// **'Invalid pattern'**
  String get topicListInvalidPattern;

  /// No description provided for @topicListFilterModeSubstring.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get topicListFilterModeSubstring;

  /// No description provided for @topicListFilterModeGlob.
  ///
  /// In en, this message translates to:
  /// **'Glob'**
  String get topicListFilterModeGlob;

  /// No description provided for @topicListFilterModeRegex.
  ///
  /// In en, this message translates to:
  /// **'Regex'**
  String get topicListFilterModeRegex;

  /// No description provided for @topicListFilterModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter mode'**
  String get topicListFilterModeTooltip;

  /// No description provided for @topicListSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort topics'**
  String get topicListSortTooltip;

  /// No description provided for @topicListSortName.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get topicListSortName;

  /// No description provided for @topicListSortPartitions.
  ///
  /// In en, this message translates to:
  /// **'Partitions'**
  String get topicListSortPartitions;

  /// No description provided for @topicListSortHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get topicListSortHealth;

  /// No description provided for @topicListGroupByPrefixTooltip.
  ///
  /// In en, this message translates to:
  /// **'Group by prefix'**
  String get topicListGroupByPrefixTooltip;

  /// No description provided for @topicListFavouritesSection.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get topicListFavouritesSection;

  /// No description provided for @topicListAddFavouriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get topicListAddFavouriteTooltip;

  /// No description provided for @topicListRemoveFavouriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get topicListRemoveFavouriteTooltip;

  /// No description provided for @topicListNotInList.
  ///
  /// In en, this message translates to:
  /// **'not in topic list'**
  String get topicListNotInList;

  /// No description provided for @topicListRefreshFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String topicListRefreshFailedNotice(String error);

  /// No description provided for @topicListPrefsUnreadableNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved topic list settings could not be read; using defaults.'**
  String get topicListPrefsUnreadableNotice;

  /// No description provided for @topicListPrefsWriteBlockedNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved topic list settings could not be backed up and will not be overwritten.'**
  String get topicListPrefsWriteBlockedNotice;

  /// No description provided for @topicConfigLoading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get topicConfigLoading;

  /// No description provided for @topicConfigNotReadable.
  ///
  /// In en, this message translates to:
  /// **'not readable — permission?'**
  String get topicConfigNotReadable;

  /// No description provided for @topicConfigLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'could not be loaded'**
  String get topicConfigLoadFailed;

  /// No description provided for @topicMetadataNotFound.
  ///
  /// In en, this message translates to:
  /// **'topic not found'**
  String get topicMetadataNotFound;

  /// No description provided for @topicMetadataUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get topicMetadataUnknown;

  /// No description provided for @topicPartitionsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Partition} other{{count} Partitions}}'**
  String topicPartitionsLabel(int count);

  /// No description provided for @topicRfLabel.
  ///
  /// In en, this message translates to:
  /// **'RF: {count}'**
  String topicRfLabel(int count);

  /// No description provided for @topicOpenFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Could not open topic \"{topic}\": {error}'**
  String topicOpenFailedNotice(String topic, String error);

  /// No description provided for @cleanupPolicyNotReadableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not readable'**
  String get cleanupPolicyNotReadableSubtitle;

  /// No description provided for @cleanupPolicyUnknownBadge.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get cleanupPolicyUnknownBadge;

  /// No description provided for @partitionOffsetSkewThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Partition skew threshold (%)'**
  String get partitionOffsetSkewThresholdLabel;

  /// No description provided for @partitionOffsetSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated distribution (offset span)'**
  String get partitionOffsetSectionTitle;

  /// No description provided for @partitionOffsetLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading partition offsets…'**
  String get partitionOffsetLoading;

  /// No description provided for @partitionOffsetLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load partition offsets: {error}'**
  String partitionOffsetLoadError(String error);

  /// No description provided for @partitionOffsetRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get partitionOffsetRetry;

  /// No description provided for @partitionOffsetRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh offsets'**
  String get partitionOffsetRefreshTooltip;

  /// No description provided for @partitionOffsetReadAt.
  ///
  /// In en, this message translates to:
  /// **'Read at {time}'**
  String partitionOffsetReadAt(String time);

  /// No description provided for @partitionOffsetReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String partitionOffsetReadFailed(String error);

  /// No description provided for @partitionOffsetStaleNotice.
  ///
  /// In en, this message translates to:
  /// **'Showing offsets from previous connection — cluster connection changed or disconnected.'**
  String get partitionOffsetStaleNotice;

  /// No description provided for @partitionOffsetTotalSpan.
  ///
  /// In en, this message translates to:
  /// **'Total offset span: {span}'**
  String partitionOffsetTotalSpan(String span);

  /// No description provided for @partitionOffsetKnownSpan.
  ///
  /// In en, this message translates to:
  /// **'Known offset span: {span}'**
  String partitionOffsetKnownSpan(String span);

  /// No description provided for @partitionOffsetUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get partitionOffsetUnknownValue;

  /// No description provided for @partitionOffsetColumnPartition.
  ///
  /// In en, this message translates to:
  /// **'Partition'**
  String get partitionOffsetColumnPartition;

  /// No description provided for @partitionOffsetColumnLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get partitionOffsetColumnLow;

  /// No description provided for @partitionOffsetColumnHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get partitionOffsetColumnHigh;

  /// No description provided for @partitionOffsetColumnSpan.
  ///
  /// In en, this message translates to:
  /// **'Offset span'**
  String get partitionOffsetColumnSpan;

  /// No description provided for @partitionOffsetColumnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get partitionOffsetColumnShare;

  /// No description provided for @partitionOffsetStateNotReadable.
  ///
  /// In en, this message translates to:
  /// **'Offsets not readable — permission?'**
  String get partitionOffsetStateNotReadable;

  /// No description provided for @partitionOffsetStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Read failed'**
  String get partitionOffsetStateFailed;

  /// No description provided for @partitionOffsetStateTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get partitionOffsetStateTimedOut;

  /// No description provided for @partitionOffsetEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'High − low watermark only; not an exact message count.'**
  String get partitionOffsetEstimateNote;

  /// No description provided for @partitionOffsetCompactedNote.
  ///
  /// In en, this message translates to:
  /// **'Compacted topic: retained messages may be fewer than the offset span.'**
  String get partitionOffsetCompactedNote;

  /// No description provided for @partitionOffsetPolicyUnknownNote.
  ///
  /// In en, this message translates to:
  /// **'Cleanup policy unknown; topic may be compacted.'**
  String get partitionOffsetPolicyUnknownNote;

  /// No description provided for @partitionOffsetIncompleteNote.
  ///
  /// In en, this message translates to:
  /// **'Some partitions could not be read; total span and shares are unavailable.'**
  String get partitionOffsetIncompleteNote;

  /// No description provided for @partitionOffsetEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'All partitions are empty (total offset span is 0).'**
  String get partitionOffsetEmptyNote;

  /// No description provided for @partitionOffsetSkewBadge.
  ///
  /// In en, this message translates to:
  /// **'Skewed (≥ {threshold}%)'**
  String partitionOffsetSkewBadge(int threshold);

  /// No description provided for @partitionOffsetSkewRowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exceeds {threshold}% share threshold'**
  String partitionOffsetSkewRowTooltip(int threshold);

  /// No description provided for @partitionOffsetOpenAnalysisAction.
  ///
  /// In en, this message translates to:
  /// **'Count exact messages in Analysis'**
  String get partitionOffsetOpenAnalysisAction;

  /// No description provided for @retentionUnlimited.
  ///
  /// In en, this message translates to:
  /// **'unlimited'**
  String get retentionUnlimited;

  /// No description provided for @retentionBytesPerPartition.
  ///
  /// In en, this message translates to:
  /// **'{size} / partition'**
  String retentionBytesPerPartition(String size);

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String durationHours(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String durationMinutes(int count);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String durationSeconds(int count);

  /// No description provided for @clusterOverviewRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh cluster overview'**
  String get clusterOverviewRefreshTooltip;

  /// No description provided for @clusterOverviewBrokersTitle.
  ///
  /// In en, this message translates to:
  /// **'Brokers ({count})'**
  String clusterOverviewBrokersTitle(int count);

  /// No description provided for @clusterOverviewClusterIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Cluster ID'**
  String get clusterOverviewClusterIdLabel;

  /// No description provided for @clusterOverviewControllerLabel.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get clusterOverviewControllerLabel;

  /// No description provided for @clusterOverviewBrokerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Broker {id}'**
  String clusterOverviewBrokerIdLabel(int id);

  /// No description provided for @clusterOverviewBrokersLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading brokers…'**
  String get clusterOverviewBrokersLoading;

  /// No description provided for @clusterOverviewBrokersError.
  ///
  /// In en, this message translates to:
  /// **'Could not load brokers: {error}'**
  String clusterOverviewBrokersError(String error);

  /// No description provided for @clusterOverviewBrokersNotReadable.
  ///
  /// In en, this message translates to:
  /// **'Brokers not readable — permission?'**
  String get clusterOverviewBrokersNotReadable;

  /// No description provided for @clusterOverviewTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Topic} other{{count} Topics}}'**
  String clusterOverviewTopicsCount(int count);

  /// No description provided for @clusterOverviewPartitionsTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Partition} other{{count} Partitions}}'**
  String clusterOverviewPartitionsTotal(int count);

  /// No description provided for @clusterOverviewTotalsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading topic totals…'**
  String get clusterOverviewTotalsLoading;

  /// No description provided for @clusterOverviewTotalsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Topic & partition totals: unknown'**
  String get clusterOverviewTotalsUnknown;

  /// No description provided for @clusterOverviewHealthHealthy.
  ///
  /// In en, this message translates to:
  /// **'All topics fully replicated (0 unhealthy)'**
  String get clusterOverviewHealthHealthy;

  /// No description provided for @clusterOverviewHealthUnhealthy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 topic with unhealthy partitions} other{{count} topics with unhealthy partitions}}'**
  String clusterOverviewHealthUnhealthy(int count);

  /// No description provided for @clusterOverviewHealthPartitionCounts.
  ///
  /// In en, this message translates to:
  /// **'{underReplicated} under-replicated, {leaderless} leaderless'**
  String clusterOverviewHealthPartitionCounts(
    int underReplicated,
    int leaderless,
  );

  /// No description provided for @clusterOverviewHealthUnknownCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 topic with unknown health} other{{count} topics with unknown health}}'**
  String clusterOverviewHealthUnknownCount(int count);

  /// No description provided for @clusterOverviewHealthStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Replication health: unknown'**
  String get clusterOverviewHealthStatusUnknown;

  /// No description provided for @clusterOverviewHealthStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Replication health: loading…'**
  String get clusterOverviewHealthStatusLoading;

  /// No description provided for @clusterOverviewShowUnhealthyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter topic list to unhealthy topics'**
  String get clusterOverviewShowUnhealthyTooltip;

  /// No description provided for @topicListUnhealthyOnlyChip.
  ///
  /// In en, this message translates to:
  /// **'Only unhealthy topics ({count})'**
  String topicListUnhealthyOnlyChip(int count);

  /// No description provided for @topicHeaderRefreshFactsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh topic facts'**
  String get topicHeaderRefreshFactsTooltip;

  /// No description provided for @topicHeaderEstimateValue.
  ///
  /// In en, this message translates to:
  /// **'≈ {count} messages (estimate)'**
  String topicHeaderEstimateValue(String count);

  /// No description provided for @topicHeaderEstimateCompactedNote.
  ///
  /// In en, this message translates to:
  /// **'Compacted or unknown-policy topic: offset spans are not message counts; use Topic Analysis for exact counts.'**
  String get topicHeaderEstimateCompactedNote;

  /// No description provided for @topicHeaderEstimateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Messages: unknown'**
  String get topicHeaderEstimateUnknown;

  /// No description provided for @topicHeaderEstimateNotReadable.
  ///
  /// In en, this message translates to:
  /// **'Messages: not readable'**
  String get topicHeaderEstimateNotReadable;

  /// No description provided for @topicHeaderRetentionLabel.
  ///
  /// In en, this message translates to:
  /// **'Retention: {duration}'**
  String topicHeaderRetentionLabel(String duration);

  /// No description provided for @topicHeaderRetentionBytesLabel.
  ///
  /// In en, this message translates to:
  /// **'Max size: {size}'**
  String topicHeaderRetentionBytesLabel(String size);

  /// No description provided for @topicHeaderRetentionNotReadable.
  ///
  /// In en, this message translates to:
  /// **'not readable'**
  String get topicHeaderRetentionNotReadable;

  /// No description provided for @topicHeaderLoadTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Load time range'**
  String get topicHeaderLoadTimeRange;

  /// No description provided for @topicHeaderLoadTimeRangeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Read oldest & newest message timestamps across {count} partitions'**
  String topicHeaderLoadTimeRangeTooltip(int count);

  /// No description provided for @topicHeaderTimeRangeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading time range…'**
  String get topicHeaderTimeRangeLoading;

  /// No description provided for @topicHeaderTimeRangeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get topicHeaderTimeRangeEmpty;

  /// No description provided for @topicHeaderTimeRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{oldest} – {newest}'**
  String topicHeaderTimeRangeValue(String oldest, String newest);

  /// No description provided for @topicHeaderTimeRangePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial ({oldestKnown}/{total} oldest, {newestKnown}/{total} newest)'**
  String topicHeaderTimeRangePartial(
    int oldestKnown,
    int newestKnown,
    int total,
  );

  /// No description provided for @topicHeaderTimeRangeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Time range: unknown'**
  String get topicHeaderTimeRangeUnknown;

  /// No description provided for @topicHeaderTimeRangeError.
  ///
  /// In en, this message translates to:
  /// **'Time range failed: {error}'**
  String topicHeaderTimeRangeError(String error);

  /// No description provided for @topicModeConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get topicModeConfig;

  /// No description provided for @topicConfigRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh configuration'**
  String get topicConfigRefreshTooltip;

  /// No description provided for @topicConfigNonDefaultToggle.
  ///
  /// In en, this message translates to:
  /// **'Non-defaults only'**
  String get topicConfigNonDefaultToggle;

  /// No description provided for @topicConfigNonDefaultToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show topic overrides, dynamic broker settings, and static broker settings'**
  String get topicConfigNonDefaultToggleTooltip;

  /// No description provided for @topicConfigDiffToggle.
  ///
  /// In en, this message translates to:
  /// **'Only differences & non-defaults'**
  String get topicConfigDiffToggle;

  /// No description provided for @topicConfigCompareAction.
  ///
  /// In en, this message translates to:
  /// **'Compare…'**
  String get topicConfigCompareAction;

  /// No description provided for @topicConfigCloseComparisonAction.
  ///
  /// In en, this message translates to:
  /// **'Close comparison'**
  String get topicConfigCloseComparisonAction;

  /// No description provided for @topicConfigCopyAsText.
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get topicConfigCopyAsText;

  /// No description provided for @topicConfigCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Configuration copied to clipboard'**
  String get topicConfigCopiedToClipboard;

  /// No description provided for @topicConfigColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get topicConfigColumnName;

  /// No description provided for @topicConfigColumnValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get topicConfigColumnValue;

  /// No description provided for @topicConfigColumnSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get topicConfigColumnSource;

  /// No description provided for @topicConfigColumnDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get topicConfigColumnDefault;

  /// No description provided for @topicConfigColumnLeftValue.
  ///
  /// In en, this message translates to:
  /// **'Left value'**
  String get topicConfigColumnLeftValue;

  /// No description provided for @topicConfigColumnLeftSource.
  ///
  /// In en, this message translates to:
  /// **'Left source'**
  String get topicConfigColumnLeftSource;

  /// No description provided for @topicConfigColumnRightValue.
  ///
  /// In en, this message translates to:
  /// **'Right value'**
  String get topicConfigColumnRightValue;

  /// No description provided for @topicConfigColumnRightSource.
  ///
  /// In en, this message translates to:
  /// **'Right source'**
  String get topicConfigColumnRightSource;

  /// No description provided for @topicConfigColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get topicConfigColumnStatus;

  /// No description provided for @topicConfigDefaultYes.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get topicConfigDefaultYes;

  /// No description provided for @topicConfigDefaultNo.
  ///
  /// In en, this message translates to:
  /// **'Override'**
  String get topicConfigDefaultNo;

  /// No description provided for @topicConfigSourceDynamicTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic override'**
  String get topicConfigSourceDynamicTopic;

  /// No description provided for @topicConfigSourceDynamicBroker.
  ///
  /// In en, this message translates to:
  /// **'Dynamic broker setting'**
  String get topicConfigSourceDynamicBroker;

  /// No description provided for @topicConfigSourceDynamicDefaultBroker.
  ///
  /// In en, this message translates to:
  /// **'Dynamic cluster-wide broker default'**
  String get topicConfigSourceDynamicDefaultBroker;

  /// No description provided for @topicConfigSourceStaticBroker.
  ///
  /// In en, this message translates to:
  /// **'Static broker setting'**
  String get topicConfigSourceStaticBroker;

  /// No description provided for @topicConfigSourceDefault.
  ///
  /// In en, this message translates to:
  /// **'Built-in default'**
  String get topicConfigSourceDefault;

  /// No description provided for @topicConfigSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get topicConfigSourceUnknown;

  /// No description provided for @topicConfigStatusEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get topicConfigStatusEqual;

  /// No description provided for @topicConfigStatusDifferent.
  ///
  /// In en, this message translates to:
  /// **'Different'**
  String get topicConfigStatusDifferent;

  /// No description provided for @topicConfigStatusOnlyLeft.
  ///
  /// In en, this message translates to:
  /// **'Only on left'**
  String get topicConfigStatusOnlyLeft;

  /// No description provided for @topicConfigStatusOnlyRight.
  ///
  /// In en, this message translates to:
  /// **'Only on right'**
  String get topicConfigStatusOnlyRight;

  /// No description provided for @topicConfigStatusNotComparable.
  ///
  /// In en, this message translates to:
  /// **'Not comparable'**
  String get topicConfigStatusNotComparable;

  /// No description provided for @topicConfigStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get topicConfigStatusUnknown;

  /// No description provided for @topicConfigPlaceholderNoValue.
  ///
  /// In en, this message translates to:
  /// **'no value'**
  String get topicConfigPlaceholderNoValue;

  /// No description provided for @topicConfigPlaceholderSensitive.
  ///
  /// In en, this message translates to:
  /// **'hidden (sensitive)'**
  String get topicConfigPlaceholderSensitive;

  /// No description provided for @topicConfigPlaceholderUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get topicConfigPlaceholderUnknown;

  /// No description provided for @topicConfigUnavailableNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Not readable — missing DescribeConfigs permission?'**
  String get topicConfigUnavailableNotAuthorized;

  /// No description provided for @topicConfigUnavailableNotFound.
  ///
  /// In en, this message translates to:
  /// **'Topic not found'**
  String get topicConfigUnavailableNotFound;

  /// No description provided for @topicConfigUnavailableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read configuration: {message}'**
  String topicConfigUnavailableFailed(String message);

  /// No description provided for @topicConfigEmptyReported.
  ///
  /// In en, this message translates to:
  /// **'No configuration entries reported.'**
  String get topicConfigEmptyReported;

  /// No description provided for @topicConfigEmptyNonDefaultFilter.
  ///
  /// In en, this message translates to:
  /// **'All reported entries use default values.'**
  String get topicConfigEmptyNonDefaultFilter;

  /// No description provided for @topicConfigEmptyDiffFilter.
  ///
  /// In en, this message translates to:
  /// **'Configurations do not differ and use only defaults.'**
  String get topicConfigEmptyDiffFilter;

  /// No description provided for @topicConfigDifferencesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 differences} =1{1 difference} other{{count} differences}}'**
  String topicConfigDifferencesCount(int count);

  /// No description provided for @topicConfigDifferencesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Differences: unknown'**
  String get topicConfigDifferencesUnknown;

  /// No description provided for @topicConfigComparisonInProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading comparison…'**
  String get topicConfigComparisonInProgress;

  /// No description provided for @topicConfigCompareDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare Topic Configuration'**
  String get topicConfigCompareDialogTitle;

  /// No description provided for @topicConfigCompareProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Target cluster profile'**
  String get topicConfigCompareProfileLabel;

  /// No description provided for @topicConfigCompareTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Target topic'**
  String get topicConfigCompareTopicLabel;

  /// No description provided for @topicConfigCompareTopicHint.
  ///
  /// In en, this message translates to:
  /// **'Enter or select topic name'**
  String get topicConfigCompareTopicHint;

  /// No description provided for @topicConfigCompareSubmit.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get topicConfigCompareSubmit;

  /// No description provided for @schemaRegistryErrorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry is not configured for this profile.'**
  String get schemaRegistryErrorNotConfigured;

  /// No description provided for @schemaRegistryErrorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry URL is invalid: {detail}'**
  String schemaRegistryErrorInvalidUrl(String detail);

  /// No description provided for @schemaRegistryErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry authentication failed (HTTP 401). Check your username and password in the cluster profile.'**
  String get schemaRegistryErrorUnauthorized;

  /// No description provided for @schemaRegistryErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry access denied (HTTP 403).'**
  String get schemaRegistryErrorForbidden;

  /// No description provided for @schemaRegistryErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Schema or subject not found in Schema Registry (HTTP 404).'**
  String get schemaRegistryErrorNotFound;

  /// No description provided for @schemaRegistryErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry request timed out.'**
  String get schemaRegistryErrorTimeout;

  /// No description provided for @schemaRegistryErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Schema Registry: {detail}'**
  String schemaRegistryErrorUnreachable(String detail);

  /// No description provided for @schemaRegistryErrorCertificateRejected.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry TLS certificate was rejected: {detail}'**
  String schemaRegistryErrorCertificateRejected(String detail);

  /// No description provided for @schemaRegistryErrorHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry returned HTTP {status}: {detail}'**
  String schemaRegistryErrorHttpStatus(int status, String detail);

  /// No description provided for @schemaRegistryErrorHttpStatusNoCode.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry returned an error: {detail}'**
  String schemaRegistryErrorHttpStatusNoCode(String detail);

  /// No description provided for @schemaRegistryErrorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Schema Registry returned an unexpected response: {detail}'**
  String schemaRegistryErrorInvalidResponse(String detail);

  /// No description provided for @schemaTypeAvro.
  ///
  /// In en, this message translates to:
  /// **'Avro'**
  String get schemaTypeAvro;

  /// No description provided for @schemaTypeProtobuf.
  ///
  /// In en, this message translates to:
  /// **'Protobuf'**
  String get schemaTypeProtobuf;

  /// No description provided for @schemaTypeJson.
  ///
  /// In en, this message translates to:
  /// **'JSON Schema'**
  String get schemaTypeJson;

  /// No description provided for @schemaTypeGeneric.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get schemaTypeGeneric;

  /// No description provided for @schemaTypeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Schema (unknown)'**
  String get schemaTypeUnknown;

  /// No description provided for @schemaTypeMixed.
  ///
  /// In en, this message translates to:
  /// **'{keyType} / {valueType}'**
  String schemaTypeMixed(String keyType, String valueType);

  /// No description provided for @schemaTopicHasTypeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Schema: {typeLabel}'**
  String schemaTopicHasTypeTooltip(String typeLabel);

  /// No description provided for @schemaVersionBadge.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String schemaVersionBadge(int version);

  /// No description provided for @schemaIdBadge.
  ///
  /// In en, this message translates to:
  /// **'ID {id}'**
  String schemaIdBadge(int id);

  /// No description provided for @schemaCompatibilityPrefix.
  ///
  /// In en, this message translates to:
  /// **'Compatibility: {level}'**
  String schemaCompatibilityPrefix(String level);

  /// No description provided for @schemaCompatibilitySubject.
  ///
  /// In en, this message translates to:
  /// **'set on subject'**
  String get schemaCompatibilitySubject;

  /// No description provided for @schemaCompatibilityInherited.
  ///
  /// In en, this message translates to:
  /// **'inherited'**
  String get schemaCompatibilityInherited;

  /// No description provided for @schemaCompatibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Compatibility: unknown ({reason})'**
  String schemaCompatibilityUnknown(String reason);

  /// No description provided for @schemaReferencesLabel.
  ///
  /// In en, this message translates to:
  /// **'References:'**
  String get schemaReferencesLabel;

  /// No description provided for @schemaReferenceChip.
  ///
  /// In en, this message translates to:
  /// **'{name} ({subject} v{version})'**
  String schemaReferenceChip(String name, String subject, int version);

  /// No description provided for @schemaMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Messages: {messages}'**
  String schemaMessagesLabel(String messages);

  /// No description provided for @schemaRawUnavailableNotice.
  ///
  /// In en, this message translates to:
  /// **'Structured view unavailable: {reason}'**
  String schemaRawUnavailableNotice(String reason);

  /// No description provided for @schemaUnsupportedTypeNotice.
  ///
  /// In en, this message translates to:
  /// **'Structured view is not supported for schema type {type}.'**
  String schemaUnsupportedTypeNotice(String type);

  /// No description provided for @schemaCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy schema'**
  String get schemaCopyTooltip;

  /// No description provided for @schemaSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save schema'**
  String get schemaSaveTooltip;

  /// No description provided for @schemaCopiedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Schema copied to clipboard'**
  String get schemaCopiedSnackBar;

  /// No description provided for @schemaSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schema saved to {path}'**
  String schemaSavedSuccess(String path);

  /// No description provided for @schemaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save schema: {error}'**
  String schemaSaveFailed(String error);

  /// No description provided for @schemaSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Schema'**
  String get schemaSaveDialogTitle;

  /// No description provided for @schemaViewerSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Schema: {subject}'**
  String schemaViewerSubjectTitle(String subject);

  /// No description provided for @schemaViewerBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to previous schema'**
  String get schemaViewerBackTooltip;

  /// No description provided for @schemaViewerAssociatedTopicsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading associated topics…'**
  String get schemaViewerAssociatedTopicsLoading;

  /// No description provided for @schemaViewerAssociatedTopicsError.
  ///
  /// In en, this message translates to:
  /// **'Failed to resolve associated topics: {error}'**
  String schemaViewerAssociatedTopicsError(String error);

  /// No description provided for @schemaViewerTopicNotOnCluster.
  ///
  /// In en, this message translates to:
  /// **'{topic} (not on cluster)'**
  String schemaViewerTopicNotOnCluster(String topic);

  /// No description provided for @subjectBrowserFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter subjects…'**
  String get subjectBrowserFilterHint;

  /// No description provided for @subjectBrowserCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String subjectBrowserCount(int shown, int total);

  /// No description provided for @subjectBrowserCountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Subjects: unknown'**
  String get subjectBrowserCountUnknown;

  /// No description provided for @subjectBrowserGlobalCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Global compatibility: {level}'**
  String subjectBrowserGlobalCompatibility(String level);

  /// No description provided for @subjectBrowserEmptyRegistry.
  ///
  /// In en, this message translates to:
  /// **'No subjects registered in Schema Registry.'**
  String get subjectBrowserEmptyRegistry;

  /// No description provided for @subjectBrowserNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No subjects match \"{query}\".'**
  String subjectBrowserNoMatch(String query);

  /// No description provided for @subjectBrowserRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh subjects'**
  String get subjectBrowserRefreshTooltip;

  /// No description provided for @subjectBrowserSideKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get subjectBrowserSideKey;

  /// No description provided for @subjectBrowserSideValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get subjectBrowserSideValue;

  /// No description provided for @explorerModeTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get explorerModeTopics;

  /// No description provided for @explorerModeSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get explorerModeSubjects;

  /// No description provided for @explorerModeSwitcherSemantics.
  ///
  /// In en, this message translates to:
  /// **'Browse mode: Topics or Subjects'**
  String get explorerModeSwitcherSemantics;

  /// No description provided for @analysisConfirmThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Large-scan confirmation threshold (messages)'**
  String get analysisConfirmThresholdLabel;

  /// No description provided for @analysisHistoryPerTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved analysis reports per topic'**
  String get analysisHistoryPerTopicLabel;

  /// No description provided for @deleteSavedAnalysisReports.
  ///
  /// In en, this message translates to:
  /// **'Delete saved analysis reports'**
  String get deleteSavedAnalysisReports;

  /// No description provided for @deleteSavedAnalysisReportsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved analysis reports?'**
  String get deleteSavedAnalysisReportsConfirmTitle;

  /// No description provided for @deleteSavedAnalysisReportsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all locally stored topic analysis reports across all clusters. Exported files elsewhere are not affected.'**
  String get deleteSavedAnalysisReportsConfirmBody;

  /// No description provided for @deleteSavedAnalysisReportsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved analysis reports deleted.'**
  String get deleteSavedAnalysisReportsSuccess;

  /// No description provided for @deleteSavedAnalysisReportsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete all saved analysis reports: {error}'**
  String deleteSavedAnalysisReportsFailed(String error);

  /// No description provided for @scopeSummaryButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Scope: {summary}'**
  String scopeSummaryButtonLabel(String summary);

  /// No description provided for @scopeSummaryAll.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get scopeSummaryAll;

  /// No description provided for @scopeSummaryNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest {count}'**
  String scopeSummaryNewest(String count);

  /// No description provided for @scopeSummaryOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest {count}'**
  String scopeSummaryOldest(String count);

  /// No description provided for @scopeSummaryPartitions.
  ///
  /// In en, this message translates to:
  /// **'partitions {list}'**
  String scopeSummaryPartitions(String list);

  /// No description provided for @scopeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Scope'**
  String get scopeDialogTitle;

  /// No description provided for @scopeModeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get scopeModeAll;

  /// No description provided for @scopeModeNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get scopeModeNewest;

  /// No description provided for @scopeModeOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get scopeModeOldest;

  /// No description provided for @scopeMessageLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Message limit (up to N offsets)'**
  String get scopeMessageLimitLabel;

  /// No description provided for @scopeMessageLimitHelper.
  ///
  /// In en, this message translates to:
  /// **'Count is in offsets; compacted or transactional topics may yield fewer messages.'**
  String get scopeMessageLimitHelper;

  /// No description provided for @scopeTimeRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time range (optional, resolved via broker timestamp index)'**
  String get scopeTimeRangeLabel;

  /// No description provided for @scopeStartTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'Start timestamp'**
  String get scopeStartTimestampLabel;

  /// No description provided for @scopeEndTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'End timestamp'**
  String get scopeEndTimestampLabel;

  /// No description provided for @scopePartitionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Partitions'**
  String get scopePartitionsLabel;

  /// No description provided for @scopeAllPartitionsChip.
  ///
  /// In en, this message translates to:
  /// **'All partitions'**
  String get scopeAllPartitionsChip;

  /// No description provided for @scopePartitionChipLabel.
  ///
  /// In en, this message translates to:
  /// **'P{id}'**
  String scopePartitionChipLabel(int id);

  /// No description provided for @scopeErrorInvalidCount.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive integer message limit.'**
  String get scopeErrorInvalidCount;

  /// No description provided for @scopeErrorInvalidStartTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Invalid start timestamp format.'**
  String get scopeErrorInvalidStartTimestamp;

  /// No description provided for @scopeErrorInvalidEndTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Invalid end timestamp format.'**
  String get scopeErrorInvalidEndTimestamp;

  /// No description provided for @scopeErrorStartAfterEnd.
  ///
  /// In en, this message translates to:
  /// **'Start timestamp must be before end timestamp.'**
  String get scopeErrorStartAfterEnd;

  /// No description provided for @scopeErrorNoPartitions.
  ///
  /// In en, this message translates to:
  /// **'Select at least one partition.'**
  String get scopeErrorNoPartitions;

  /// No description provided for @scopeApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get scopeApplyButton;

  /// No description provided for @scopeEstimating.
  ///
  /// In en, this message translates to:
  /// **'Estimating…'**
  String get scopeEstimating;

  /// No description provided for @scopeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start large analysis?'**
  String get scopeConfirmTitle;

  /// No description provided for @scopeConfirmPlannedCount.
  ///
  /// In en, this message translates to:
  /// **'Estimated scan size: {count} offsets.'**
  String scopeConfirmPlannedCount(String count);

  /// No description provided for @scopeConfirmAtLeastCount.
  ///
  /// In en, this message translates to:
  /// **'Estimated scan size: at least {count} offsets.'**
  String scopeConfirmAtLeastCount(String count);

  /// No description provided for @scopeConfirmSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Scan size unknown ({error}). Start anyway?'**
  String scopeConfirmSizeUnknown(String error);

  /// No description provided for @scopeConfirmUnreadableHeader.
  ///
  /// In en, this message translates to:
  /// **'Unreadable partitions:'**
  String get scopeConfirmUnreadableHeader;

  /// No description provided for @scopeConfirmUnreadableItem.
  ///
  /// In en, this message translates to:
  /// **'Partition {partition}: {reason}'**
  String scopeConfirmUnreadableItem(int partition, String reason);

  /// No description provided for @scopeConfirmCompactedHint.
  ///
  /// In en, this message translates to:
  /// **'This is a compacted topic; the actual message count may be lower than the offset range.'**
  String get scopeConfirmCompactedHint;

  /// No description provided for @scopeConfirmStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get scopeConfirmStartButton;

  /// No description provided for @historySaveErrorBanner.
  ///
  /// In en, this message translates to:
  /// **'Could not save report to local history: {error}'**
  String historySaveErrorBanner(String error);

  /// No description provided for @reportScopeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Scope'**
  String get reportScopeCardTitle;

  /// No description provided for @reportScopeNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Scope not recorded for this report.'**
  String get reportScopeNotRecorded;

  /// No description provided for @reportScopeExcludedByTime.
  ///
  /// In en, this message translates to:
  /// **'Excluded by time range: {count}'**
  String reportScopeExcludedByTime(String count);

  /// No description provided for @reportScopeUnreadablePartitions.
  ///
  /// In en, this message translates to:
  /// **'Unreadable partitions: {list}'**
  String reportScopeUnreadablePartitions(String list);

  /// No description provided for @analysisLimitsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Limits'**
  String get analysisLimitsCardTitle;

  /// No description provided for @analysisLimitsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available for this report.'**
  String get analysisLimitsNotAvailable;

  /// No description provided for @analysisLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get analysisLimitReached;

  /// No description provided for @analysisLimitWithin.
  ///
  /// In en, this message translates to:
  /// **'Within limit'**
  String get analysisLimitWithin;

  /// No description provided for @limitKindTrackedFields.
  ///
  /// In en, this message translates to:
  /// **'Tracked fields'**
  String get limitKindTrackedFields;

  /// No description provided for @limitKindListedFields.
  ///
  /// In en, this message translates to:
  /// **'Listed fields'**
  String get limitKindListedFields;

  /// No description provided for @limitKindValuesPerField.
  ///
  /// In en, this message translates to:
  /// **'Values per field'**
  String get limitKindValuesPerField;

  /// No description provided for @limitKindListedValuesPerField.
  ///
  /// In en, this message translates to:
  /// **'Listed values per field'**
  String get limitKindListedValuesPerField;

  /// No description provided for @limitKindFieldDepth.
  ///
  /// In en, this message translates to:
  /// **'Field nesting depth'**
  String get limitKindFieldDepth;

  /// No description provided for @limitKindValueDisplayChars.
  ///
  /// In en, this message translates to:
  /// **'Value display length (chars)'**
  String get limitKindValueDisplayChars;

  /// No description provided for @limitKindTrackedKeys.
  ///
  /// In en, this message translates to:
  /// **'Tracked keys'**
  String get limitKindTrackedKeys;

  /// No description provided for @limitKindListedKeys.
  ///
  /// In en, this message translates to:
  /// **'Listed keys'**
  String get limitKindListedKeys;

  /// No description provided for @limitKindSizePercentileSample.
  ///
  /// In en, this message translates to:
  /// **'Size percentile sample'**
  String get limitKindSizePercentileSample;

  /// No description provided for @limitKindTrackedFingerprints.
  ///
  /// In en, this message translates to:
  /// **'Tracked duplicate fingerprints'**
  String get limitKindTrackedFingerprints;

  /// No description provided for @limitKindDuplicateSamples.
  ///
  /// In en, this message translates to:
  /// **'Duplicate samples'**
  String get limitKindDuplicateSamples;

  /// No description provided for @limitKindListedDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Listed duplicates'**
  String get limitKindListedDuplicates;

  /// No description provided for @limitKindPreviewChars.
  ///
  /// In en, this message translates to:
  /// **'Payload preview length (chars)'**
  String get limitKindPreviewChars;

  /// No description provided for @limitKindTimelineWindowDays.
  ///
  /// In en, this message translates to:
  /// **'Timeline window (days)'**
  String get limitKindTimelineWindowDays;

  /// No description provided for @fieldTrackedCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} fields'**
  String fieldTrackedCountSummary(String shown, String total);

  /// No description provided for @fieldFurtherNotTracked.
  ///
  /// In en, this message translates to:
  /// **'Further fields not tracked'**
  String get fieldFurtherNotTracked;

  /// No description provided for @duplicateEstimatedAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Estimated (at least)'**
  String get duplicateEstimatedAtLeast;

  /// No description provided for @duplicateUntrackedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} untracked messages'**
  String duplicateUntrackedCount(String count);

  /// No description provided for @duplicateListPossiblyIncomplete.
  ///
  /// In en, this message translates to:
  /// **'List possibly incomplete'**
  String get duplicateListPossiblyIncomplete;

  /// No description provided for @historyMenuFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file…'**
  String get historyMenuFromFile;

  /// No description provided for @historyMenuEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved reports for this topic'**
  String get historyMenuEmpty;

  /// No description provided for @historyMenuUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count} unreadable file(s) skipped'**
  String historyMenuUnreadable(int count);

  /// No description provided for @historyMenuLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load history: {error}'**
  String historyMenuLoadError(String error);

  /// No description provided for @historyEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{scope} · {messages} messages'**
  String historyEntrySubtitle(String scope, String messages);

  /// No description provided for @comparisonScopeNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Scope not recorded'**
  String get comparisonScopeNotRecorded;

  /// No description provided for @comparisonScopesDifferWarning.
  ///
  /// In en, this message translates to:
  /// **'Comparison scopes differ — deltas may reflect scope differences rather than data changes.'**
  String get comparisonScopesDifferWarning;

  /// No description provided for @comparisonScopeMissingWarning.
  ///
  /// In en, this message translates to:
  /// **'Scope is not recorded on one or both reports — they cannot be reliably compared.'**
  String get comparisonScopeMissingWarning;

  /// No description provided for @timelinePartitionSubsetNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Timeline covers only a subset of partitions ({partitions}).'**
  String timelinePartitionSubsetNote(String partitions);

  /// No description provided for @diffIgnoredFieldsHeader.
  ///
  /// In en, this message translates to:
  /// **'Ignored fields ({count})'**
  String diffIgnoredFieldsHeader(int count);

  /// No description provided for @diffIgnoredFieldsButton.
  ///
  /// In en, this message translates to:
  /// **'Ignored fields'**
  String get diffIgnoredFieldsButton;

  /// No description provided for @diffIgnoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignored fields — {topic}'**
  String diffIgnoreDialogTitle(String topic);

  /// No description provided for @diffIgnorePathHint.
  ///
  /// In en, this message translates to:
  /// **'Field path (e.g. meta.ts or /items/0/id)'**
  String get diffIgnorePathHint;

  /// No description provided for @diffIgnoreAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get diffIgnoreAddButton;

  /// No description provided for @diffIgnoreRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove ignored field {path}'**
  String diffIgnoreRemoveTooltip(String path);

  /// No description provided for @diffIgnoreEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No ignored fields for this topic.'**
  String get diffIgnoreEmptyList;

  /// No description provided for @diffIgnoreSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested volatile fields'**
  String get diffIgnoreSuggestionsTitle;

  /// No description provided for @ignoreThisField.
  ///
  /// In en, this message translates to:
  /// **'Ignore this field'**
  String get ignoreThisField;

  /// No description provided for @diffHiddenCount.
  ///
  /// In en, this message translates to:
  /// **'Hidden ({count})'**
  String diffHiddenCount(int count);

  /// No description provided for @diffTruncatedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count} more differences not shown'**
  String diffTruncatedNotice(int count);

  /// No description provided for @diffIgnoreLoadWarning.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved ignore list for {topic}.'**
  String diffIgnoreLoadWarning(String topic);

  /// No description provided for @diffIgnoreSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save ignore list. Change was not persisted.'**
  String get diffIgnoreSaveError;

  /// No description provided for @diffIgnoreEmptyPathError.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-empty field path.'**
  String get diffIgnoreEmptyPathError;

  /// No description provided for @diffIgnoreDuplicatePathError.
  ///
  /// In en, this message translates to:
  /// **'This field path is already ignored.'**
  String get diffIgnoreDuplicatePathError;

  /// No description provided for @filterExpressionLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter expression'**
  String get filterExpressionLabel;

  /// No description provided for @filterExpressionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. value.status = \"FAILED\" AND partition = 0'**
  String get filterExpressionHint;

  /// No description provided for @filterExpressionChipSummary.
  ///
  /// In en, this message translates to:
  /// **'Expr: {expr}'**
  String filterExpressionChipSummary(String expr);

  /// No description provided for @filterExpressionInvalidTooltip.
  ///
  /// In en, this message translates to:
  /// **'Invalid filter expression'**
  String get filterExpressionInvalidTooltip;

  /// No description provided for @filterExpressionModeBuilder.
  ///
  /// In en, this message translates to:
  /// **'Builder'**
  String get filterExpressionModeBuilder;

  /// No description provided for @filterExpressionModeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get filterExpressionModeText;

  /// No description provided for @filterExpressionErrorAtColumn.
  ///
  /// In en, this message translates to:
  /// **'Column {column}: {message}'**
  String filterExpressionErrorAtColumn(int column, String message);

  /// No description provided for @filterExpressionAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get filterExpressionAddCondition;

  /// No description provided for @filterExpressionAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get filterExpressionAddGroup;

  /// No description provided for @filterExpressionNotToggle.
  ///
  /// In en, this message translates to:
  /// **'NOT'**
  String get filterExpressionNotToggle;

  /// No description provided for @filterExpressionAndLabel.
  ///
  /// In en, this message translates to:
  /// **'AND'**
  String get filterExpressionAndLabel;

  /// No description provided for @filterExpressionOrLabel.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get filterExpressionOrLabel;

  /// No description provided for @filterExpressionRemoveNode.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get filterExpressionRemoveNode;

  /// No description provided for @filterExpressionEditCondition.
  ///
  /// In en, this message translates to:
  /// **'Edit condition'**
  String get filterExpressionEditCondition;

  /// No description provided for @filterExpressionSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get filterExpressionSourceLabel;

  /// No description provided for @filterExpressionPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path / Header'**
  String get filterExpressionPathLabel;

  /// No description provided for @filterExpressionOperatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get filterExpressionOperatorLabel;

  /// No description provided for @filterExpressionValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get filterExpressionValueLabel;

  /// No description provided for @filterExpressionTypeString.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get filterExpressionTypeString;

  /// No description provided for @filterExpressionTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get filterExpressionTypeNumber;

  /// No description provided for @filterExpressionTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get filterExpressionTypeBoolean;

  /// No description provided for @filterExpressionTypeNull.
  ///
  /// In en, this message translates to:
  /// **'Null'**
  String get filterExpressionTypeNull;

  /// No description provided for @filterExpressionTypeVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get filterExpressionTypeVariable;

  /// No description provided for @filterExpressionPlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'Multi-value script variables match if ANY value satisfies the condition.'**
  String get filterExpressionPlaceholderHint;

  /// No description provided for @filterExpressionSuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Field suggestions'**
  String get filterExpressionSuggestionsLabel;

  /// No description provided for @filterExpressionSuggestionsSourceSchema.
  ///
  /// In en, this message translates to:
  /// **'From schema'**
  String get filterExpressionSuggestionsSourceSchema;

  /// No description provided for @filterExpressionSuggestionsSourceAnalysis.
  ///
  /// In en, this message translates to:
  /// **'From analysis'**
  String get filterExpressionSuggestionsSourceAnalysis;

  /// No description provided for @filterExpressionSuggestionsSourceSample.
  ///
  /// In en, this message translates to:
  /// **'From loaded messages'**
  String get filterExpressionSuggestionsSourceSample;

  /// No description provided for @filterExpressionSuggestionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No field suggestions available'**
  String get filterExpressionSuggestionsEmpty;

  /// No description provided for @filterExpressionOpEq.
  ///
  /// In en, this message translates to:
  /// **'='**
  String get filterExpressionOpEq;

  /// No description provided for @filterExpressionOpNe.
  ///
  /// In en, this message translates to:
  /// **'!='**
  String get filterExpressionOpNe;

  /// No description provided for @filterExpressionOpGt.
  ///
  /// In en, this message translates to:
  /// **'>'**
  String get filterExpressionOpGt;

  /// No description provided for @filterExpressionOpGe.
  ///
  /// In en, this message translates to:
  /// **'>='**
  String get filterExpressionOpGe;

  /// No description provided for @filterExpressionOpLt.
  ///
  /// In en, this message translates to:
  /// **'<'**
  String get filterExpressionOpLt;

  /// No description provided for @filterExpressionOpLe.
  ///
  /// In en, this message translates to:
  /// **'<='**
  String get filterExpressionOpLe;

  /// No description provided for @filterExpressionOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get filterExpressionOpContains;

  /// No description provided for @filterExpressionOpStartsWith.
  ///
  /// In en, this message translates to:
  /// **'startsWith'**
  String get filterExpressionOpStartsWith;

  /// No description provided for @filterExpressionOpEndsWith.
  ///
  /// In en, this message translates to:
  /// **'endsWith'**
  String get filterExpressionOpEndsWith;

  /// No description provided for @filterExpressionOpMatches.
  ///
  /// In en, this message translates to:
  /// **'matches'**
  String get filterExpressionOpMatches;

  /// No description provided for @filterExpressionOpIn.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get filterExpressionOpIn;

  /// No description provided for @filterExpressionOpExists.
  ///
  /// In en, this message translates to:
  /// **'exists'**
  String get filterExpressionOpExists;

  /// No description provided for @filterExpressionOpIsNull.
  ///
  /// In en, this message translates to:
  /// **'is null'**
  String get filterExpressionOpIsNull;

  /// No description provided for @filterExpressionOpIsNotNull.
  ///
  /// In en, this message translates to:
  /// **'is not null'**
  String get filterExpressionOpIsNotNull;

  /// No description provided for @localSchemaDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign Local Schema ({side})'**
  String localSchemaDialogTitle(String side);

  /// No description provided for @localSchemaSideKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get localSchemaSideKey;

  /// No description provided for @localSchemaSideValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get localSchemaSideValue;

  /// No description provided for @localSchemaFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Schema file'**
  String get localSchemaFileLabel;

  /// No description provided for @localSchemaChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file…'**
  String get localSchemaChooseFile;

  /// No description provided for @localSchemaNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get localSchemaNoFileSelected;

  /// No description provided for @localSchemaFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get localSchemaFormatLabel;

  /// No description provided for @localSchemaFormatAvro.
  ///
  /// In en, this message translates to:
  /// **'Avro (.avsc)'**
  String get localSchemaFormatAvro;

  /// No description provided for @localSchemaFormatProtobufSource.
  ///
  /// In en, this message translates to:
  /// **'Protobuf source (.proto)'**
  String get localSchemaFormatProtobufSource;

  /// No description provided for @localSchemaFormatProtobufDescriptor.
  ///
  /// In en, this message translates to:
  /// **'Protobuf descriptor set (.desc)'**
  String get localSchemaFormatProtobufDescriptor;

  /// No description provided for @localSchemaFormatJsonSchema.
  ///
  /// In en, this message translates to:
  /// **'JSON Schema (.json)'**
  String get localSchemaFormatJsonSchema;

  /// No description provided for @localSchemaMessageTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Message type'**
  String get localSchemaMessageTypeLabel;

  /// No description provided for @localSchemaMessageTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select a message type'**
  String get localSchemaMessageTypeHint;

  /// No description provided for @localSchemaFramingLabel.
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get localSchemaFramingLabel;

  /// No description provided for @localSchemaFramingAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get localSchemaFramingAuto;

  /// No description provided for @localSchemaFramingPrefixed.
  ///
  /// In en, this message translates to:
  /// **'Confluent prefixed'**
  String get localSchemaFramingPrefixed;

  /// No description provided for @localSchemaFramingRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw payload'**
  String get localSchemaFramingRaw;

  /// No description provided for @localSchemaModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Precedence'**
  String get localSchemaModeLabel;

  /// No description provided for @localSchemaModeFallback.
  ///
  /// In en, this message translates to:
  /// **'Fallback (registry first)'**
  String get localSchemaModeFallback;

  /// No description provided for @localSchemaModeAlways.
  ///
  /// In en, this message translates to:
  /// **'Always (skip registry)'**
  String get localSchemaModeAlways;

  /// No description provided for @localSchemaPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Field preview'**
  String get localSchemaPreviewTitle;

  /// No description provided for @localSchemaPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No fields extracted'**
  String get localSchemaPreviewEmpty;

  /// No description provided for @localSchemaRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get localSchemaRemoveAction;

  /// No description provided for @localSchemaSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get localSchemaSaveAction;

  /// No description provided for @localSchemaProto2DescriptorHint.
  ///
  /// In en, this message translates to:
  /// **'Compile with protoc --include_imports --descriptor_set_out=<file>.desc and select the descriptor file.'**
  String get localSchemaProto2DescriptorHint;

  /// No description provided for @localSchemaCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Local schema'**
  String get localSchemaCardTitle;

  /// No description provided for @localSchemaAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign local schema'**
  String get localSchemaAssignAction;

  /// No description provided for @localSchemaChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get localSchemaChangeAction;

  /// No description provided for @localSchemaConfirmChangedAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm updated file'**
  String get localSchemaConfirmChangedAction;

  /// No description provided for @localSchemaStateUsable.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get localSchemaStateUsable;

  /// No description provided for @localSchemaStateChanged.
  ///
  /// In en, this message translates to:
  /// **'File modified since assignment'**
  String get localSchemaStateChanged;

  /// No description provided for @localSchemaStateFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get localSchemaStateFileNotFound;

  /// No description provided for @localSchemaStateFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'File unreadable'**
  String get localSchemaStateFileUnreadable;

  /// No description provided for @localSchemaStateSchemaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Schema invalid'**
  String get localSchemaStateSchemaInvalid;

  /// No description provided for @localSchemaStateMessageTypeMissing.
  ///
  /// In en, this message translates to:
  /// **'Message type not found'**
  String get localSchemaStateMessageTypeMissing;

  /// No description provided for @localSchemaStateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get localSchemaStateUnknown;

  /// No description provided for @localSchemaTagPrefix.
  ///
  /// In en, this message translates to:
  /// **'Local: {type}'**
  String localSchemaTagPrefix(String type);

  /// No description provided for @localSchemaUnreadableBanner.
  ///
  /// In en, this message translates to:
  /// **'Stored local schema assignment could not be read: {reason}'**
  String localSchemaUnreadableBanner(String reason);

  /// No description provided for @localSchemaProvenanceDecoded.
  ///
  /// In en, this message translates to:
  /// **'Decoded using local schema: {fileName} ({format})'**
  String localSchemaProvenanceDecoded(String fileName, String format);

  /// No description provided for @localSchemaProvenanceDecodedWithMsg.
  ///
  /// In en, this message translates to:
  /// **'Decoded using local schema: {fileName} ({format}, {messageType})'**
  String localSchemaProvenanceDecodedWithMsg(
    String fileName,
    String format,
    String messageType,
  );

  /// No description provided for @localSchemaProvenanceFailed.
  ///
  /// In en, this message translates to:
  /// **'Local schema decode failed ({fileName})'**
  String localSchemaProvenanceFailed(String fileName);

  /// No description provided for @localSchemaCardBadgeKey.
  ///
  /// In en, this message translates to:
  /// **'K: local'**
  String get localSchemaCardBadgeKey;

  /// No description provided for @localSchemaCardBadgeValue.
  ///
  /// In en, this message translates to:
  /// **'V: local'**
  String get localSchemaCardBadgeValue;

  /// No description provided for @localSchemaCardBadgeKeyError.
  ///
  /// In en, this message translates to:
  /// **'K: local !'**
  String get localSchemaCardBadgeKeyError;

  /// No description provided for @localSchemaCardBadgeValueError.
  ///
  /// In en, this message translates to:
  /// **'V: local !'**
  String get localSchemaCardBadgeValueError;

  /// No description provided for @localSchemaAnalysisNotice.
  ///
  /// In en, this message translates to:
  /// **'Some messages in this analysis were decoded using a local schema.'**
  String get localSchemaAnalysisNotice;

  /// No description provided for @localDecodeErrorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Schema file not found: {detail}'**
  String localDecodeErrorFileNotFound(String detail);

  /// No description provided for @localDecodeErrorFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read schema file: {detail}'**
  String localDecodeErrorFileUnreadable(String detail);

  /// No description provided for @localDecodeErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Schema file exceeds the 10 MiB limit: {detail}'**
  String localDecodeErrorFileTooLarge(String detail);

  /// No description provided for @localDecodeErrorSchemaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid schema: {detail}'**
  String localDecodeErrorSchemaInvalid(String detail);

  /// No description provided for @localDecodeErrorUnsupportedProto2.
  ///
  /// In en, this message translates to:
  /// **'Proto2 source files are not supported directly; compile to a FileDescriptorSet (.desc) instead. ({detail})'**
  String localDecodeErrorUnsupportedProto2(String detail);

  /// No description provided for @localDecodeErrorUnresolvedImport.
  ///
  /// In en, this message translates to:
  /// **'Unresolved import in schema: {detail}. Compile with protoc --include_imports --descriptor_set_out=...'**
  String localDecodeErrorUnresolvedImport(String detail);

  /// No description provided for @localDecodeErrorMessageTypeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Message type not found in schema: {detail}'**
  String localDecodeErrorMessageTypeNotFound(String detail);

  /// No description provided for @localDecodeErrorMissingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Expected Confluent 5-byte wire prefix, but payload did not start with magic byte 0x00: {detail}'**
  String localDecodeErrorMissingPrefix(String detail);

  /// No description provided for @localDecodeErrorUnknownMessageIndex.
  ///
  /// In en, this message translates to:
  /// **'Unknown Protobuf message index in wire prefix: {detail}'**
  String localDecodeErrorUnknownMessageIndex(String detail);

  /// No description provided for @localDecodeErrorPayloadMismatch.
  ///
  /// In en, this message translates to:
  /// **'Payload does not match schema: {detail}'**
  String localDecodeErrorPayloadMismatch(String detail);

  /// No description provided for @localDecodeErrorTrailingBytes.
  ///
  /// In en, this message translates to:
  /// **'Unexpected trailing bytes after decoded payload: {detail}'**
  String localDecodeErrorTrailingBytes(String detail);

  /// No description provided for @localDecodeErrorNotJson.
  ///
  /// In en, this message translates to:
  /// **'Payload is not valid UTF-8 JSON: {detail}'**
  String localDecodeErrorNotJson(String detail);

  /// No description provided for @fetchFilterPlaceholderBoth.
  ///
  /// In en, this message translates to:
  /// **'Filter while fetching (key & value)...'**
  String get fetchFilterPlaceholderBoth;

  /// No description provided for @fetchFilterPlaceholderKey.
  ///
  /// In en, this message translates to:
  /// **'Filter while fetching (key only)...'**
  String get fetchFilterPlaceholderKey;

  /// No description provided for @fetchFilterPlaceholderValue.
  ///
  /// In en, this message translates to:
  /// **'Filter while fetching (value only)...'**
  String get fetchFilterPlaceholderValue;

  /// No description provided for @fetchFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters messages while reading from the topic (limits which messages are fetched).'**
  String get fetchFilterTooltip;

  /// No description provided for @fetchFilterScopeTypeSummary.
  ///
  /// In en, this message translates to:
  /// **'{scope} · {type}'**
  String fetchFilterScopeTypeSummary(String scope, String type);

  /// No description provided for @fetchFilterMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change fetch filter scope and match type'**
  String get fetchFilterMenuTooltip;

  /// No description provided for @moreFiltersButton.
  ///
  /// In en, this message translates to:
  /// **'More filters'**
  String get moreFiltersButton;

  /// No description provided for @moreFiltersButtonWithCount.
  ///
  /// In en, this message translates to:
  /// **'More filters ({count})'**
  String moreFiltersButtonWithCount(int count);

  /// No description provided for @moreFiltersOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show more fetch filters'**
  String get moreFiltersOpenTooltip;

  /// No description provided for @moreFiltersCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide more fetch filters'**
  String get moreFiltersCloseTooltip;

  /// No description provided for @timePresetsMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Relative time presets'**
  String get timePresetsMenuTooltip;

  /// No description provided for @timeRangeEndBeforeStartError.
  ///
  /// In en, this message translates to:
  /// **'End time must not be before start time.'**
  String get timeRangeEndBeforeStartError;

  /// No description provided for @timeRangeInvalidTimestampError.
  ///
  /// In en, this message translates to:
  /// **'Invalid timestamp format.'**
  String get timeRangeInvalidTimestampError;

  /// No description provided for @topicFactsMoreCount.
  ///
  /// In en, this message translates to:
  /// **'{count} more topic facts'**
  String topicFactsMoreCount(int count);

  /// No description provided for @mcpSharingDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with MCP'**
  String get mcpSharingDialogTitle;

  /// No description provided for @mcpSharingSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Share this cluster with headless kafkalyzer (MCP)'**
  String get mcpSharingSwitchLabel;

  /// No description provided for @mcpSharingDataFlowWarning.
  ///
  /// In en, this message translates to:
  /// **'Message keys, payloads, headers and cluster metadata read by an MCP client can be sent to the language-model provider that client uses. You are responsible for sharing a production cluster.'**
  String get mcpSharingDataFlowWarning;

  /// No description provided for @mcpSharingSnippetLabel.
  ///
  /// In en, this message translates to:
  /// **'MCP client configuration'**
  String get mcpSharingSnippetLabel;

  /// No description provided for @mcpSharingCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy snippet'**
  String get mcpSharingCopyAction;

  /// No description provided for @mcpSharingCopiedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Snippet copied'**
  String get mcpSharingCopiedConfirmation;

  /// No description provided for @mcpSharingShareFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Share the profile first to enable copying.'**
  String get mcpSharingShareFirstHint;

  /// No description provided for @mcpSharingProgramNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Program not found at {path}'**
  String mcpSharingProgramNotFoundHint(String path);

  /// No description provided for @mcpSharedBadge.
  ///
  /// In en, this message translates to:
  /// **'Shared with MCP'**
  String get mcpSharedBadge;

  /// No description provided for @mcpSharingFailedBadge.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed'**
  String get mcpSharingFailedBadge;

  /// No description provided for @mcpSharingFailureKeyringUnavailable.
  ///
  /// In en, this message translates to:
  /// **'OS keyring unavailable'**
  String get mcpSharingFailureKeyringUnavailable;

  /// No description provided for @mcpSharingFailureSecretRejected.
  ///
  /// In en, this message translates to:
  /// **'Secret rejected by the keyring'**
  String get mcpSharingFailureSecretRejected;

  /// No description provided for @mcpSharingFailureFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not write the shared profiles file: {detail}'**
  String mcpSharingFailureFileError(String detail);

  /// No description provided for @mcpSharingFailureBridgeError.
  ///
  /// In en, this message translates to:
  /// **'Sharing sync failed: {detail}'**
  String mcpSharingFailureBridgeError(String detail);

  /// No description provided for @mcpSharingFailureNamed.
  ///
  /// In en, this message translates to:
  /// **'{name}: {reason}'**
  String mcpSharingFailureNamed(String name, String reason);

  /// No description provided for @mcpSharingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry sharing'**
  String get mcpSharingRetry;

  /// No description provided for @mcpSharingToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update sharing for this cluster.'**
  String get mcpSharingToggleFailed;

  /// No description provided for @mcpSharingOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Share with MCP'**
  String get mcpSharingOpenAction;
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
