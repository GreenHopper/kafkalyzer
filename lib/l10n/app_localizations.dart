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

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @multiSearch.
  ///
  /// In en, this message translates to:
  /// **'Multi-Search'**
  String get multiSearch;

  /// No description provided for @scripts.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get scripts;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @consumerLag.
  ///
  /// In en, this message translates to:
  /// **'Consumer Lag'**
  String get consumerLag;

  /// No description provided for @consumerGroups.
  ///
  /// In en, this message translates to:
  /// **'Consumer Groups'**
  String get consumerGroups;

  /// No description provided for @noConsumerGroupsFound.
  ///
  /// In en, this message translates to:
  /// **'No consumer groups found.'**
  String get noConsumerGroupsFound;

  /// No description provided for @totalLag.
  ///
  /// In en, this message translates to:
  /// **'Total Lag'**
  String get totalLag;

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

  /// No description provided for @searchGroups.
  ///
  /// In en, this message translates to:
  /// **'Search consumer groups...'**
  String get searchGroups;

  /// No description provided for @unknownView.
  ///
  /// In en, this message translates to:
  /// **'Unknown View'**
  String get unknownView;

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

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @ago.
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get ago;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @quickTimeSelection.
  ///
  /// In en, this message translates to:
  /// **'Quick Time Selection'**
  String get quickTimeSelection;

  /// No description provided for @editVariable.
  ///
  /// In en, this message translates to:
  /// **'Edit Variable'**
  String get editVariable;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @usedIn.
  ///
  /// In en, this message translates to:
  /// **'Used In'**
  String get usedIn;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

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

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @variables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get variables;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @clusterConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Cluster Configuration'**
  String get clusterConfiguration;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @addCluster.
  ///
  /// In en, this message translates to:
  /// **'Add Cluster'**
  String get addCluster;

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

  /// No description provided for @clustersImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Clusters imported successfully'**
  String get clustersImportedSuccessfully;

  /// No description provided for @failedToImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import: {error}'**
  String failedToImport(String error);

  /// No description provided for @clustersExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Clusters exported successfully'**
  String get clustersExportedSuccessfully;

  /// No description provided for @failedToExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export: {error}'**
  String failedToExport(String error);

  /// No description provided for @noActiveStreams.
  ///
  /// In en, this message translates to:
  /// **'No active streams'**
  String get noActiveStreams;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @startSearch.
  ///
  /// In en, this message translates to:
  /// **'Start search'**
  String get startSearch;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get stream;

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

  /// No description provided for @fullMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Full message copied to clipboard'**
  String get fullMessageCopied;

  /// No description provided for @metadataCopied.
  ///
  /// In en, this message translates to:
  /// **'Metadata copied to clipboard'**
  String get metadataCopied;

  /// No description provided for @contentCopied.
  ///
  /// In en, this message translates to:
  /// **'Content copied to clipboard'**
  String get contentCopied;

  /// No description provided for @raw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get raw;

  /// No description provided for @tree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get tree;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @loadOrders.
  ///
  /// In en, this message translates to:
  /// **'Load Orders'**
  String get loadOrders;

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

  /// No description provided for @pleaseSelectCluster.
  ///
  /// In en, this message translates to:
  /// **'Please select a cluster'**
  String get pleaseSelectCluster;

  /// No description provided for @failedToLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders: {error}'**
  String failedToLoadOrders(String error);

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @newRun.
  ///
  /// In en, this message translates to:
  /// **'New Run'**
  String get newRun;

  /// No description provided for @noVariablesRequired.
  ///
  /// In en, this message translates to:
  /// **'No variables required.'**
  String get noVariablesRequired;

  /// No description provided for @noPastRunsFound.
  ///
  /// In en, this message translates to:
  /// **'No past runs found.'**
  String get noPastRunsFound;

  /// No description provided for @runArchiveImported.
  ///
  /// In en, this message translates to:
  /// **'Run archive imported'**
  String get runArchiveImported;

  /// No description provided for @failedToImportRun.
  ///
  /// In en, this message translates to:
  /// **'Failed to import run: {error}'**
  String failedToImportRun(String error);

  /// No description provided for @runArchiveExported.
  ///
  /// In en, this message translates to:
  /// **'Run archive exported'**
  String get runArchiveExported;

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

  /// No description provided for @allMessages.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get allMessages;

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

  /// No description provided for @editStep.
  ///
  /// In en, this message translates to:
  /// **'Edit Step'**
  String get editStep;

  /// No description provided for @addExtraction.
  ///
  /// In en, this message translates to:
  /// **'Add Extraction'**
  String get addExtraction;

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

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @simulateOrder.
  ///
  /// In en, this message translates to:
  /// **'Simulate Order'**
  String get simulateOrder;

  /// No description provided for @noClustersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No clusters available'**
  String get noClustersAvailable;

  /// No description provided for @cluster.
  ///
  /// In en, this message translates to:
  /// **'Cluster'**
  String get cluster;

  /// No description provided for @maxOrders.
  ///
  /// In en, this message translates to:
  /// **'Max Orders'**
  String get maxOrders;

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

  /// No description provided for @searchById.
  ///
  /// In en, this message translates to:
  /// **'Search by ID, CORID or PMXCOR ID'**
  String get searchById;

  /// No description provided for @showingOrders.
  ///
  /// In en, this message translates to:
  /// **'Showing {filtered} of {total} orders'**
  String showingOrders(int filtered, int total);

  /// No description provided for @aiAnalysisDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis Data Available'**
  String get aiAnalysisDataAvailable;

  /// No description provided for @pmxcorStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}'**
  String pmxcorStatus(String status);

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

  /// No description provided for @clusters.
  ///
  /// In en, this message translates to:
  /// **'CLUSTERS'**
  String get clusters;

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

  /// No description provided for @clusterLabel.
  ///
  /// In en, this message translates to:
  /// **'Cluster: {name}'**
  String clusterLabel(String name);

  /// No description provided for @showInternal.
  ///
  /// In en, this message translates to:
  /// **'Show internal'**
  String get showInternal;

  /// No description provided for @reloadTopicsAndSchemas.
  ///
  /// In en, this message translates to:
  /// **'Reload Topics & Schemas'**
  String get reloadTopicsAndSchemas;

  /// No description provided for @filterTopics.
  ///
  /// In en, this message translates to:
  /// **'Filter topics...'**
  String get filterTopics;

  /// No description provided for @multiStreamConfig.
  ///
  /// In en, this message translates to:
  /// **'Multi-Stream Config'**
  String get multiStreamConfig;

  /// No description provided for @selectOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Output Directory'**
  String get selectOutputDirectory;

  /// No description provided for @newSearchStream.
  ///
  /// In en, this message translates to:
  /// **'New Search Stream'**
  String get newSearchStream;

  /// No description provided for @reloadTopics.
  ///
  /// In en, this message translates to:
  /// **'Reload Topics'**
  String get reloadTopics;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @selectTopic.
  ///
  /// In en, this message translates to:
  /// **'Select Topic'**
  String get selectTopic;

  /// No description provided for @loadingTopics.
  ///
  /// In en, this message translates to:
  /// **'Loading topics...'**
  String get loadingTopics;

  /// No description provided for @fieldOptional.
  ///
  /// In en, this message translates to:
  /// **'Field (Opt.)'**
  String get fieldOptional;

  /// No description provided for @valuesCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Values (comma sep.)'**
  String get valuesCommaSeparated;

  /// No description provided for @scope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

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

  /// No description provided for @limitOrders.
  ///
  /// In en, this message translates to:
  /// **'Enable order limit'**
  String get limitOrders;

  /// No description provided for @partitionOptional.
  ///
  /// In en, this message translates to:
  /// **'Partition (Opt.)'**
  String get partitionOptional;

  /// No description provided for @importScripts.
  ///
  /// In en, this message translates to:
  /// **'Import Scripts'**
  String get importScripts;

  /// No description provided for @exportSelectedScript.
  ///
  /// In en, this message translates to:
  /// **'Export Selected Script'**
  String get exportSelectedScript;

  /// No description provided for @exportScript.
  ///
  /// In en, this message translates to:
  /// **'Export Script'**
  String get exportScript;

  /// No description provided for @createNewScript.
  ///
  /// In en, this message translates to:
  /// **'Create New Script'**
  String get createNewScript;

  /// No description provided for @scriptsImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Scripts imported successfully'**
  String get scriptsImportedSuccessfully;

  /// No description provided for @scriptExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Script exported successfully'**
  String get scriptExportedSuccessfully;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @editDefinition.
  ///
  /// In en, this message translates to:
  /// **'Edit Definition'**
  String get editDefinition;

  /// No description provided for @newScript.
  ///
  /// In en, this message translates to:
  /// **'New Script'**
  String get newScript;

  /// No description provided for @useSidebarToSelectScript.
  ///
  /// In en, this message translates to:
  /// **'Use the sidebar to select or create a script.'**
  String get useSidebarToSelectScript;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @exportConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Export Configuration'**
  String get exportConfiguration;

  /// No description provided for @importConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Import Configuration'**
  String get importConfiguration;

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

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @reviewPreviousRuns.
  ///
  /// In en, this message translates to:
  /// **'Review Previous Runs'**
  String get reviewPreviousRuns;

  /// No description provided for @maxScriptRunHistory.
  ///
  /// In en, this message translates to:
  /// **'Max Script Runs to keep'**
  String get maxScriptRunHistory;

  /// No description provided for @scriptExecution.
  ///
  /// In en, this message translates to:
  /// **'Script Execution: {name}'**
  String scriptExecution(String name);

  /// No description provided for @scriptNotFound.
  ///
  /// In en, this message translates to:
  /// **'Script \'{name}\' not found'**
  String scriptNotFound(String name);

  /// No description provided for @selectValidScript.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid script first.'**
  String get selectValidScript;

  /// No description provided for @rerunNotIntegrated.
  ///
  /// In en, this message translates to:
  /// **'Rerun from history is not fully integrated in Orders View yet.'**
  String get rerunNotIntegrated;

  /// No description provided for @kiError.
  ///
  /// In en, this message translates to:
  /// **'AI Error'**
  String get kiError;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'{total} Orders'**
  String totalOrders(int total);

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

  /// No description provided for @startOffset.
  ///
  /// In en, this message translates to:
  /// **'Start Offset'**
  String get startOffset;

  /// No description provided for @startTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Start Timestamp'**
  String get startTimestamp;

  /// No description provided for @endOffset.
  ///
  /// In en, this message translates to:
  /// **'End Offset'**
  String get endOffset;

  /// No description provided for @endTimestamp.
  ///
  /// In en, this message translates to:
  /// **'End Timestamp'**
  String get endTimestamp;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @earliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get earliest;

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

  /// No description provided for @duplicateScript.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Script'**
  String get duplicateScript;

  /// No description provided for @load.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// No description provided for @searchingForOrders.
  ///
  /// In en, this message translates to:
  /// **'Searching for orders...'**
  String get searchingForOrders;

  /// No description provided for @searchingInTopic.
  ///
  /// In en, this message translates to:
  /// **'Searching in: {topic}'**
  String searchingInTopic(String topic);

  /// No description provided for @topicsProgress.
  ///
  /// In en, this message translates to:
  /// **'Completed {completed} of {total} topics'**
  String topicsProgress(int completed, int total);

  /// No description provided for @scannedCount.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {count}'**
  String scannedCount(int count);

  /// No description provided for @noProgressInfo.
  ///
  /// In en, this message translates to:
  /// **'No progress info'**
  String get noProgressInfo;

  /// No description provided for @runSummary.
  ///
  /// In en, this message translates to:
  /// **'Run Summary'**
  String get runSummary;

  /// No description provided for @runDetails.
  ///
  /// In en, this message translates to:
  /// **'Run Details'**
  String get runDetails;

  /// No description provided for @parameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get parameters;

  /// No description provided for @examinedMessages.
  ///
  /// In en, this message translates to:
  /// **'Examined: {count} messages'**
  String examinedMessages(int count);

  /// No description provided for @firstAppearanceForKey.
  ///
  /// In en, this message translates to:
  /// **'First appearance for Key: {key}'**
  String firstAppearanceForKey(String key);

  /// No description provided for @noDifferencesFound.
  ///
  /// In en, this message translates to:
  /// **'No differences found.'**
  String get noDifferencesFound;

  /// No description provided for @chronological.
  ///
  /// In en, this message translates to:
  /// **'Chronological'**
  String get chronological;

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

  /// No description provided for @matchesCount.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} matches'**
  String matchesCount(int current, int total);

  /// No description provided for @stepMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String stepMatches(int count);

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results...'**
  String get searchResults;

  /// No description provided for @scanned.
  ///
  /// In en, this message translates to:
  /// **'{count} scanned'**
  String scanned(int count);

  /// No description provided for @exportMessages.
  ///
  /// In en, this message translates to:
  /// **'Export Messages'**
  String get exportMessages;

  /// No description provided for @messagesExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Messages exported successfully'**
  String get messagesExportedSuccessfully;

  /// No description provided for @messagesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export messages: {error}'**
  String messagesExportFailed(String error);
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
