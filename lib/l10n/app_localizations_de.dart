// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Kafkalyzer';

  @override
  String get explorer => 'Explorer';

  @override
  String get scripts => 'Skripte';

  @override
  String get orders => 'Aufträge';

  @override
  String get settings => 'Einstellungen';

  @override
  String get consumerLag => 'Consumer-Lag';

  @override
  String get consumerGroups => 'Consumer-Gruppen';

  @override
  String get noConsumerGroupsFound => 'Keine Consumer-Gruppen gefunden.';

  @override
  String get totalLag => 'Gesamt-Lag';

  @override
  String get autoRefresh => 'Auto-Aktualisierung (15s)';

  @override
  String get topicCol => 'Topic';

  @override
  String get partitionCol => 'Partition';

  @override
  String get logEndOffsetCol => 'Log-End-Offset';

  @override
  String get committedOffsetCol => 'Committed Offset';

  @override
  String get lagCol => 'Lag';

  @override
  String get searchGroups => 'Consumer-Gruppen suchen...';

  @override
  String get unknownView => 'Unbekannte Ansicht';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get apply => 'Anwenden';

  @override
  String get clear => 'Leeren';

  @override
  String get now => 'Jetzt';

  @override
  String get ago => 'her';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get quickTimeSelection => 'Schnellauswahl Zeit';

  @override
  String get editVariable => 'Variable bearbeiten';

  @override
  String get name => 'Name';

  @override
  String get type => 'Typ';

  @override
  String get source => 'Quelle';

  @override
  String get usedIn => 'Verwendet in';

  @override
  String get actions => 'Aktionen';

  @override
  String get addStep => 'Schritt hinzufügen';

  @override
  String get unnamedStep => 'Unbenannter Schritt';

  @override
  String get steps => 'Schritte';

  @override
  String get variables => 'Variablen';

  @override
  String get general => 'Allgemein';

  @override
  String get clusterConfiguration => 'Cluster-Konfiguration';

  @override
  String get import => 'Importieren';

  @override
  String get export => 'Exportieren';

  @override
  String get addCluster => 'Cluster hinzufügen';

  @override
  String get deleteCluster => 'Cluster löschen';

  @override
  String deleteClusterConfirmation(String clusterName) {
    return 'Sind Sie sicher, dass Sie $clusterName löschen möchten?';
  }

  @override
  String get clustersImportedSuccessfully => 'Cluster erfolgreich importiert';

  @override
  String failedToImport(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get clustersExportedSuccessfully => 'Cluster erfolgreich exportiert';

  @override
  String failedToExport(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get noActiveStreams => 'Keine aktiven Streams';

  @override
  String get clearAll => 'Alle leeren';

  @override
  String get viewAll => 'Alle anzeigen';

  @override
  String get stop => 'Stopp';

  @override
  String get stream => 'Stream';

  @override
  String get messageDetails => 'Nachrichtendetails';

  @override
  String get copyMessage => 'Nachricht kopieren';

  @override
  String get fullMessageCopied =>
      'Vollständige Nachricht in die Zwischenablage kopiert';

  @override
  String get metadataCopied => 'Metadaten in die Zwischenablage kopiert';

  @override
  String get contentCopied => 'Inhalt in die Zwischenablage kopiert';

  @override
  String get raw => 'Roh';

  @override
  String get tree => 'Baum';

  @override
  String get cards => 'Karten';

  @override
  String get loadOrders => 'Aufträge laden';

  @override
  String get noOrdersFound =>
      'Keine Aufträge gefunden. Klicken Sie auf Laden, um zu suchen.';

  @override
  String get noOrdersMatchFilter => 'Keine Aufträge entsprechen dem Filter.';

  @override
  String get pleaseSelectCluster => 'Bitte wählen Sie einen Cluster aus';

  @override
  String failedToLoadOrders(String error) {
    return 'Fehler beim Laden der Aufträge: $error';
  }

  @override
  String get run => 'Ausführen';

  @override
  String get newRun => 'Neuer Durchlauf';

  @override
  String get noVariablesRequired => 'Keine Variablen erforderlich.';

  @override
  String get noPastRunsFound => 'Keine vergangenen Durchläufe gefunden.';

  @override
  String get runArchiveImported => 'Durchlauf-Archiv importiert';

  @override
  String failedToImportRun(String error) {
    return 'Fehler beim Importieren des Durchlaufs: $error';
  }

  @override
  String get runArchiveExported => 'Durchlauf-Archiv exportiert';

  @override
  String get deleteRunResult => 'Durchlaufergebnis löschen';

  @override
  String get deleteRunResultConfirmation =>
      'Sind Sie sicher, dass Sie dieses Durchlaufergebnis löschen möchten?';

  @override
  String get runResultDeleted => 'Durchlaufergebnis gelöscht';

  @override
  String get allMessages => 'Alle Nachrichten';

  @override
  String get otherResults => 'Andere Ergebnisse';

  @override
  String noResultsFound(String phrase) {
    return 'Keine Ergebnisse für \'$phrase\' gefunden';
  }

  @override
  String get editStep => 'Schritt bearbeiten';

  @override
  String get addExtraction => 'Extraktion hinzufügen';

  @override
  String get switchLightMode => 'In den hellen Modus wechseln';

  @override
  String get switchDarkMode => 'In den dunklen Modus wechseln';

  @override
  String get defaultScriptOutputDir => 'Standard-Skript-Ausgabeverzeichnis';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get active => 'Aktiv';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get simulateOrder => 'Auftrag simulieren';

  @override
  String get cluster => 'Cluster';

  @override
  String get maxOrders => 'Max. Aufträge';

  @override
  String get filterByMessageId =>
      'Nachrichten-ID, CORID oder PMXCOR-ID filtern';

  @override
  String get enterMessageIdToFilter =>
      'Nachrichten-ID, CORID oder PMXCOR-ID eingeben...';

  @override
  String showingOrders(int filtered, int total) {
    return 'Zeige $filtered von $total Aufträgen';
  }

  @override
  String get aiAnalysisDataAvailable => 'KI-Analysedaten verfügbar';

  @override
  String pmxcorStatus(String status) {
    return '$status';
  }

  @override
  String get statusOpen => 'OFFEN';

  @override
  String get statusAnalyzing => 'KI-ANALYSE GESTARTET';

  @override
  String get statusCompleted => 'KI-ANALYSE ABGESCHLOSSEN';

  @override
  String get statusFailed => 'FEHLGESCHLAGEN';

  @override
  String get clusters => 'CLUSTER';

  @override
  String get selectClusterToViewTopics =>
      'Wählen Sie einen Cluster aus, um Topics anzuzeigen';

  @override
  String get topics => 'Topics';

  @override
  String clusterLabel(String name) {
    return 'Cluster: $name';
  }

  @override
  String get showInternal => 'Interne anzeigen';

  @override
  String get reloadTopicsAndSchemas => 'Topics & Schemas neu laden';

  @override
  String get filterTopics => 'Topics filtern...';

  @override
  String get selectOutputDirectory => 'Ausgabeverzeichnis wählen';

  @override
  String get topic => 'Topic';

  @override
  String get scope => 'Bereich';

  @override
  String get contains => 'Enthält';

  @override
  String get regex => 'Regex';

  @override
  String get exact => 'Exakt';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get both => 'Beides';

  @override
  String get fastTrace => 'Schnellsuche (Hash Key)';

  @override
  String get limit => 'Limit';

  @override
  String get limitOrders => 'Auftragslimit aktivieren';

  @override
  String get partitionOptional => 'Partition (opt.)';

  @override
  String get importScripts => 'Skripte importieren';

  @override
  String get exportSelectedScript => 'Ausgewähltes Skript exportieren';

  @override
  String get exportScript => 'Skript exportieren';

  @override
  String get createNewScript => 'Neues Skript erstellen';

  @override
  String get scriptsImportedSuccessfully => 'Skripte erfolgreich importiert';

  @override
  String get scriptExportedSuccessfully => 'Skript erfolgreich exportiert';

  @override
  String get history => 'Verlauf';

  @override
  String get editDefinition => 'Definition bearbeiten';

  @override
  String get newScript => 'Neues Skript';

  @override
  String get useSidebarToSelectScript =>
      'Verwenden Sie die Seitenleiste, um ein Skript auszuwählen oder zu erstellen.';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get exportConfiguration => 'Konfiguration exportieren';

  @override
  String get importConfiguration => 'Konfiguration importieren';

  @override
  String get configurationExportedSuccessfully =>
      'Konfiguration erfolgreich exportiert';

  @override
  String get configurationImportedSuccessfully =>
      'Konfiguration erfolgreich importiert';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get reviewPreviousRuns => 'Vergangene Durchläufe ansehen';

  @override
  String get maxScriptRunHistory => 'Max. Anzahl an Skript-Durchläufen';

  @override
  String scriptExecution(String name) {
    return 'Skriptausführung: $name';
  }

  @override
  String get selectValidScript =>
      'Bitte wählen Sie zuerst ein gültiges Skript aus.';

  @override
  String get rerunNotIntegrated =>
      'Erneute Ausführung aus dem Verlauf ist in der Auftragsansicht noch nicht integriert.';

  @override
  String get kiError => 'KI Fehler';

  @override
  String totalOrders(int total) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString Aufträge';
  }

  @override
  String get limitResults => 'Ergebnisse begrenzen';

  @override
  String get maxResults => 'Max. Ergebnisse';

  @override
  String get startCondition => 'Startbedingung';

  @override
  String get stopCondition => 'Stoppbedingung';

  @override
  String get startOffset => 'Start-Offset';

  @override
  String get startTimestamp => 'Start-Zeitstempel';

  @override
  String get endOffset => 'End-Offset';

  @override
  String get endTimestamp => 'End-Zeitstempel';

  @override
  String get end => 'Ende';

  @override
  String get latest => 'Neueste';

  @override
  String get earliest => 'Früheste';

  @override
  String get offset => 'Offset';

  @override
  String get timestamp => 'Zeitstempel';

  @override
  String get duplicateScript => 'Skript duplizieren';

  @override
  String get searchingForOrders => 'Suche nach Aufträgen...';

  @override
  String searchingInTopic(String topic) {
    return 'Suche in: $topic';
  }

  @override
  String topicsProgress(int completed, int total) {
    return '$completed von $total Topics abgeschlossen';
  }

  @override
  String scannedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Gescannt: $countString';
  }

  @override
  String get noProgressInfo => 'Keine Fortschrittsinfos';

  @override
  String get runSummary => 'Gesamt';

  @override
  String get runDetails => 'Details';

  @override
  String get parameters => 'Parameter';

  @override
  String examinedMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Untersucht: $countString Nachrichten';
  }

  @override
  String firstAppearanceForKey(String key) {
    return 'Erstes Auftreten für Schlüssel: $key';
  }

  @override
  String get noDifferencesFound => 'Keine Unterschiede gefunden.';

  @override
  String get chronological => 'Chronologisch';

  @override
  String get byTopic => 'Nach Topic';

  @override
  String get byStep => 'Nach Schritt';

  @override
  String matchesCount(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString / $totalString Treffer';
  }

  @override
  String stepMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Treffer';
  }

  @override
  String get searchResults => 'Suchergebnisse...';

  @override
  String scanned(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString gescannt';
  }

  @override
  String get exportMessages => 'Nachrichten exportieren';

  @override
  String get messagesExportedSuccessfully =>
      'Nachrichten erfolgreich exportiert';

  @override
  String messagesExportFailed(String error) {
    return 'Nachrichten konnten nicht exportiert werden: $error';
  }

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get checkingForUpdates => 'Suche nach Updates...';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get appUpToDate => 'Kafkalyzer ist auf dem neuesten Stand';

  @override
  String get appUpToDateDescription =>
      'Sie verwenden die neueste Version von Kafkalyzer.';

  @override
  String get downloadUpdate => 'Update herunterladen';

  @override
  String get downloadingUpdate => 'Update wird heruntergeladen...';

  @override
  String get updateReadyRestart =>
      'Update bereit! Neustart erforderlich, um das Update anzuwenden.';

  @override
  String get restartNow => 'Jetzt neu starten';

  @override
  String updateError(String error) {
    return 'Fehler beim Suchen oder Anwenden des Updates: $error';
  }

  @override
  String get releaseNotes => 'Versionshinweise';

  @override
  String get noReleaseNotes => 'Keine Versionshinweise verfügbar.';

  @override
  String get close => 'Schließen';
}
