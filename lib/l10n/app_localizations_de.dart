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
  String get topicAnalysis => 'Topic-Analyse';

  @override
  String get messagesView => 'Nachrichten';

  @override
  String get startAnalysis => 'Analyse starten';

  @override
  String get stopAnalysis => 'Analyse stoppen';

  @override
  String get analyzingTopic => 'Topic wird analysiert...';

  @override
  String get scanScope => 'Scan-Umfang';

  @override
  String get fullTopicScan => 'Vollständiger Scan (Alle Nachrichten)';

  @override
  String get sampleLast10k => 'Stichprobe letzte 10.000 Nachrichten';

  @override
  String get sampleLast50k => 'Stichprobe letzte 50.000 Nachrichten';

  @override
  String get sampleLast100k => 'Stichprobe letzte 100.000 Nachrichten';

  @override
  String get totalMessages => 'Gesamtanzahl Nachrichten';

  @override
  String get totalPayloadSize => 'Gesamtgröße Payloads';

  @override
  String get avgMessageSize => 'Durchschnittl. Nachrichtengröße';

  @override
  String get tombstones => 'Tombstones';

  @override
  String get compactedTopic => 'Kompaktiertes Topic';

  @override
  String get nonCompactedTopic => 'Delete Retention Topic';

  @override
  String get nullKeys => 'Null Keys';

  @override
  String get keyedMessages => 'Nachrichten mit Key';

  @override
  String get hourlyPeakProduction => 'Stündliche Produktionsspitzen (24h UTC)';

  @override
  String get partitionUtilization => 'Partition-Auslastung & Verteilung';

  @override
  String get topKeys => 'Häufigste Message Keys';

  @override
  String get contentTypeBreakdown => 'Inhaltstypen';

  @override
  String get fieldFrequencies => 'Strukturierte Feld-Häufigkeiten';

  @override
  String get noAnalysisYet =>
      'Noch keine Analysedaten vorhanden. Klicken Sie auf Analyse starten, um dieses Topic zu profilieren.';

  @override
  String get exportAnalysisReport => 'Analysebericht exportieren';

  @override
  String get importAnalysisReport => 'Analysebericht importieren';

  @override
  String importedFromTime(String cluster, String time) {
    return 'Importiert von $cluster am $time';
  }

  @override
  String get unknownCluster => 'unbekannter Cluster';

  @override
  String get analysisExportedSuccessfully =>
      'Analysebericht erfolgreich exportiert';

  @override
  String get analysisImportedSuccessfully =>
      'Analysebericht erfolgreich importiert';

  @override
  String get importNotAValidAnalysisFile =>
      'Diese Datei ist kein gültiger Kafkalyzer-Analysebericht.';

  @override
  String importUnsupportedVersion(String version) {
    return 'Diese Analyse-Datei verwendet eine nicht unterstützte Version ($version).';
  }

  @override
  String get importMalformed =>
      'Diese Analyse-Datei konnte nicht gelesen werden.';

  @override
  String get exportFailed => 'Fehler beim Exportieren des Analyseberichts.';

  @override
  String get hotPartition => 'Hohe Last / Ungleichgewicht';

  @override
  String get balancedPartitions => 'Ausgeglichen';

  @override
  String get emptyTopicMessage => 'Dieses Topic ist leer (0 Nachrichten).';

  @override
  String get fieldValueExplorer => 'Feldwerte-Explorer (Top 10 Werte)';

  @override
  String get searchFields => 'Felder suchen...';

  @override
  String get selectFieldToInspect =>
      'Wählen Sie ein Feld aus, um dessen Top 10 Werte anzuzeigen';

  @override
  String top10ValuesForField(String field) {
    return 'Top 10 Werte für $field';
  }

  @override
  String get valueCopied => 'Wert in die Zwischenablage kopiert';

  @override
  String fieldOccurrences(String count, String pct) {
    return 'Erscheint in $count Nachr. ($pct%)';
  }

  @override
  String noMatchingFields(String query) {
    return 'Keine Felder für \'$query\' gefunden';
  }

  @override
  String get allMessages => 'Alle Nachrichten';

  @override
  String get byTopic => 'Nach Topic';

  @override
  String get byStep => 'Nach Schritt';

  @override
  String get active => 'Aktiv';

  @override
  String stepMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Treffer';
  }

  @override
  String examinedMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Untersucht: $countString Nachrichten';
  }

  @override
  String get searchResults => 'Suchergebnisse...';

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
  String get otherResults => 'Andere Ergebnisse';

  @override
  String scanned(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString gescannt';
  }

  @override
  String get close => 'Schließen';

  @override
  String get closeTab => 'Tab schließen';

  @override
  String get scanning => 'Wird gescannt...';

  @override
  String get operationInProgress => 'Operation in Fortschritt';

  @override
  String get operationInProgressMessage =>
      'Eine Suche oder Analyse wird auf diesem Tab noch ausgeführt. Tab schließen und die Operation abbrechen?';

  @override
  String get duplicateTab => 'Tab duplizieren';

  @override
  String get openInNewTab => 'In neuem Tab öffnen';

  @override
  String get explorer => 'Explorer';

  @override
  String get scripts => 'Skripte';

  @override
  String get settings => 'Einstellungen';

  @override
  String get clusters => 'CLUSTER';

  @override
  String get addCluster => 'Cluster hinzufügen';

  @override
  String get selectClusterToViewTopics =>
      'Wählen Sie einen Cluster aus, um Topics anzuzeigen';

  @override
  String get topics => 'Topics';

  @override
  String get filterTopics => 'Topics filtern...';

  @override
  String get consumerGroups => 'Consumer-Gruppen';

  @override
  String get searchGroups => 'Consumer-Gruppen suchen...';

  @override
  String get noConsumerGroupsFound => 'Keine Consumer-Gruppen gefunden.';

  @override
  String get consumerLag => 'Consumer-Lag';

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
  String get totalLag => 'Gesamt-Lag';

  @override
  String get stream => 'Stream';

  @override
  String get tree => 'Baum';

  @override
  String get raw => 'Roh';

  @override
  String get clear => 'Leeren';

  @override
  String get exportMessages => 'Nachrichten exportieren';

  @override
  String get sortOrderAscending => 'Aufsteigend';

  @override
  String get sortOrderDescending => 'Absteigend';

  @override
  String get sortFieldTimestamp => 'Zeitstempel';

  @override
  String get sortFieldPartition => 'Partition';

  @override
  String get sortFieldOffset => 'Offset';

  @override
  String get sortFieldKey => 'Key';

  @override
  String get sortFieldValue => 'Value';

  @override
  String get sortFieldTooltip => 'Sortierfeld';

  @override
  String get startCondition => 'Startbedingung';

  @override
  String get startConditionLatestTooltip =>
      'Bei den neuesten Nachrichten beginnen (Ende des Topics basierend auf dem Limit)';

  @override
  String get startConditionEarliestTooltip =>
      'Ab der ältesten verfügbaren Nachricht lesen (Offset 0)';

  @override
  String get startConditionOffsetTooltip => 'Ab einem bestimmten Offset lesen';

  @override
  String get startConditionTimestampTooltip =>
      'Ab einem bestimmten Zeitstempel lesen';

  @override
  String get stopCondition => 'Stoppbedingung';

  @override
  String get stopConditionStreamTooltip =>
      'Endlos auf neu eintreffende Nachrichten warten';

  @override
  String get stopConditionEndTooltip =>
      'Beim aktuellen Ende des Topics anhalten (High Watermark)';

  @override
  String get stopConditionOffsetTooltip =>
      'Bei einem bestimmten Offset anhalten';

  @override
  String get stopConditionTimestampTooltip =>
      'Bei einem bestimmten Zeitstempel anhalten';

  @override
  String get earliest => 'Früheste';

  @override
  String get latest => 'Neueste';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get offset => 'Offset';

  @override
  String get timestamp => 'Zeitstempel';

  @override
  String get startOffset => 'Start-Offset';

  @override
  String get endOffset => 'End-Offset';

  @override
  String get startTimestamp => 'Start-Zeitstempel';

  @override
  String get endTimestamp => 'End-Zeitstempel';

  @override
  String get quickTimeSelection => 'Schnellauswahl Zeit';

  @override
  String get ago => 'her';

  @override
  String get now => 'Jetzt';

  @override
  String get end => 'Ende';

  @override
  String get partitionOptional => 'Partition (opt.)';

  @override
  String get fastTrace => 'Schnellsuche (Hash Key)';

  @override
  String get limit => 'Limit';

  @override
  String get limitResults => 'Ergebnisse begrenzen';

  @override
  String get maxResults => 'Max. Ergebnisse';

  @override
  String get scope => 'Bereich';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get both => 'Beides';

  @override
  String get type => 'Typ';

  @override
  String get contains => 'Enthält';

  @override
  String get regex => 'Regex';

  @override
  String get exact => 'Exakt';

  @override
  String get run => 'Ausführen';

  @override
  String get stop => 'Stopp';

  @override
  String get apply => 'Anwenden';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get actions => 'Aktionen';

  @override
  String get name => 'Name';

  @override
  String get topic => 'Topic';

  @override
  String get cluster => 'Cluster';

  @override
  String get parameters => 'Parameter';

  @override
  String get steps => 'Schritte';

  @override
  String get addStep => 'Schritt hinzufügen';

  @override
  String get unnamedStep => 'Unbenannter Schritt';

  @override
  String get editStep => 'Schritt bearbeiten';

  @override
  String get variables => 'Variablen';

  @override
  String get editVariable => 'Variable bearbeiten';

  @override
  String get usedIn => 'Verwendet in';

  @override
  String get noVariablesRequired => 'Keine Variablen erforderlich.';

  @override
  String get addExtraction => 'Extraktion hinzufügen';

  @override
  String get newScript => 'Neues Skript';

  @override
  String get duplicateScript => 'Skript duplizieren';

  @override
  String get exportScript => 'Skript exportieren';

  @override
  String get exportSelectedScript => 'Ausgewähltes Skript exportieren';

  @override
  String get importScripts => 'Skripte importieren';

  @override
  String get deleteCluster => 'Cluster löschen';

  @override
  String deleteClusterConfirmation(String clusterName) {
    return 'Sind Sie sicher, dass Sie $clusterName löschen möchten?';
  }

  @override
  String get useSidebarToSelectScript =>
      'Verwenden Sie die Seitenleiste, um ein Skript auszuwählen oder zu erstellen.';

  @override
  String get createNewScript => 'Neues Skript erstellen';

  @override
  String get editDefinition => 'Definition bearbeiten';

  @override
  String get newRun => 'Neuer Durchlauf';

  @override
  String get history => 'Verlauf';

  @override
  String get noPastRunsFound => 'Keine vergangenen Durchläufe gefunden.';

  @override
  String get runResultDeleted => 'Durchlaufergebnis gelöscht';

  @override
  String get runDetails => 'Details';

  @override
  String get runSummary => 'Gesamt';

  @override
  String get chronological => 'Chronologisch';

  @override
  String get general => 'Allgemein';

  @override
  String get switchLightMode => 'In den hellen Modus wechseln';

  @override
  String get switchDarkMode => 'In den dunklen Modus wechseln';

  @override
  String get defaultScriptOutputDir => 'Standard-Skript-Ausgabeverzeichnis';

  @override
  String get maxScriptRunHistory => 'Max. Anzahl an Skript-Durchläufen';

  @override
  String get exportConfiguration => 'Konfiguration exportieren';

  @override
  String get export => 'Exportieren';

  @override
  String get importConfiguration => 'Konfiguration importieren';

  @override
  String get import => 'Importieren';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get clusterConfiguration => 'Cluster-Konfiguration';

  @override
  String get pleaseSelectCluster => 'Bitte wählen Sie einen Cluster aus';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get copyMessage => 'Nachricht kopieren';

  @override
  String get contentCopied => 'Inhalt in die Zwischenablage kopiert';

  @override
  String get metadataCopied => 'Metadaten in die Zwischenablage kopiert';

  @override
  String get fullMessageCopied =>
      'Vollständige Nachricht in die Zwischenablage kopiert';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get noDifferencesFound => 'Keine Unterschiede gefunden.';

  @override
  String get configurationExportedSuccessfully =>
      'Konfiguration erfolgreich exportiert';

  @override
  String get configurationImportedSuccessfully =>
      'Konfiguration erfolgreich importiert';

  @override
  String get clustersExportedSuccessfully => 'Cluster erfolgreich exportiert';

  @override
  String get scriptExportedSuccessfully => 'Skript erfolgreich exportiert';

  @override
  String get scriptsImportedSuccessfully => 'Skripte erfolgreich importiert';

  @override
  String get runArchiveExported => 'Durchlauf-Archiv exportiert';

  @override
  String get runArchiveImported => 'Durchlauf-Archiv importiert';

  @override
  String get messagesExportedSuccessfully =>
      'Nachrichten erfolgreich exportiert';

  @override
  String failedToExport(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String failedToImport(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String failedToImportRun(String error) {
    return 'Fehler beim Importieren des Durchlaufs: $error';
  }

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
  String get restartNow => 'Jetzt neu starten';

  @override
  String get updateReadyRestart =>
      'Update bereit! Neustart erforderlich, um das Update anzuwenden.';

  @override
  String updateError(String error) {
    return 'Fehler beim Suchen oder Anwenden des Updates: $error';
  }

  @override
  String get releaseNotes => 'Versionshinweise';

  @override
  String get noReleaseNotes => 'Keine Versionshinweise verfügbar.';

  @override
  String backgroundUpdateAvailable(String version) {
    return 'Eine neue Version von Kafkalyzer (v$version) ist verfügbar.';
  }

  @override
  String get updateAction => 'Aktualisieren';

  @override
  String get updateUnsupportedEnvironment =>
      'Automatische Updates nicht verfügbar';

  @override
  String get updateUnsupportedEnvironmentDescription =>
      'In-Place-Updates erfordern eine paketierte Installation (AppImage unter Linux, Installer unter Windows/macOS). Laden Sie die neueste Version von GitHub herunter.';

  @override
  String get openGitHubReleases => 'GitHub Releases öffnen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get dockBottom => 'Unten andocken';

  @override
  String get dockSide => 'Rechts andocken';

  @override
  String get closeInspector => 'Inspector schließen';

  @override
  String get tabPayload => 'Payload';

  @override
  String get tabKeyAndHeaders => 'Key & Header';

  @override
  String get tabRawJson => 'Rohes JSON';

  @override
  String get copyHeaders => 'Alle Header kopieren';

  @override
  String get copyMetadata => 'Metadaten kopieren';

  @override
  String get copiedHeaders => 'Alle Header in die Zwischenablage kopiert';

  @override
  String get noHeaders => 'Keine Header in dieser Nachricht vorhanden';

  @override
  String get previousMessageTooltip => 'Vorherige Nachricht (K)';

  @override
  String get nextMessageTooltip => 'Nächste Nachricht (J)';

  @override
  String messagePosition(int current, int total) {
    return '$current von $total';
  }

  @override
  String get focusMode => 'Maximieren (Fokus-Modus)';

  @override
  String get exitFocusMode => 'Minimieren (Esc)';

  @override
  String get searchInMessage => 'In Nachricht suchen...';

  @override
  String get nextMatchTooltip => 'Nächster Treffer (Enter)';

  @override
  String get previousMatchTooltip => 'Vorheriger Treffer (Shift+Enter)';

  @override
  String scriptRunMatchedOfExamined(int matched, int examined) {
    return '$matched von $examined';
  }

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String collapsedRangeLabel(int count, int start, int end) {
    return '… $count verborgene Elemente (Index $start bis $end) anzeigen';
  }

  @override
  String showAllArrayItems(int count) {
    return 'Alle $count zeigen';
  }

  @override
  String get reduceToMatchContext => 'Auf Treffer reduzieren (±1)';

  @override
  String matchesContextBadge(int matches) {
    return '$matches Treffer (Fokus: Treffer ±1)';
  }

  @override
  String get pinAsColumn => 'Als Spalte anheften';

  @override
  String columnPinned(String path) {
    return 'Spalte \'$path\' an Tabelle angeheftet';
  }

  @override
  String columnAlreadyPinned(String path) {
    return 'Spalte \'$path\' ist bereits angeheftet';
  }

  @override
  String get resetColumns => 'Spalten zurücksetzen';

  @override
  String get columnsReset => 'Tabellenspalten auf Standard zurückgesetzt';

  @override
  String get columnsMenu => 'Spalten';

  @override
  String get hideColumn => 'Spalte ausblenden';

  @override
  String get hideEmptyFields => 'Leere Felder ausblenden';

  @override
  String get showEmptyFields => 'Leere Felder einblenden';

  @override
  String get rawTimestampLabel => 'Rohwert';

  @override
  String get utcTimestampLabel => 'UTC';

  @override
  String get localTimestampLabel => 'Lokal';

  @override
  String get collapseSidebar => 'Seitenleiste einklappen';

  @override
  String get expandSidebar => 'Seitenleiste ausklappen (Ctrl+B)';

  @override
  String get collapseScriptCatalog => 'Skriptkatalog einklappen';

  @override
  String get expandScriptCatalog => 'Skriptkatalog ausklappen (Ctrl+B)';

  @override
  String get toggleRunOverview => 'Laufübersicht umschalten';

  @override
  String get scanModeLabel => 'Modus';

  @override
  String get scanModeLatestN => 'Neueste Nachrichten';

  @override
  String get scanModeLiveTail => 'Live-Stream';

  @override
  String get scanModeTimeRange => 'Zeitraum';

  @override
  String get scanModeOffsetEarliest => 'Offset / Früheste';

  @override
  String get quickFilterPlaceholder => 'Beim Abruf filtern (Key oder Wert)...';

  @override
  String invalidFilterPattern(Object term) {
    return 'Ungültiger regulärer Ausdruck: $term';
  }

  @override
  String get limitLabel => 'Limit';

  @override
  String get limitAll => 'Alle';

  @override
  String get advancedFiltersToggle => 'Erweitert';

  @override
  String get collapseAdvancedFilters => 'Erweiterte Filter einklappen';

  @override
  String get expandAdvancedFilters => 'Erweiterte Filter ausklappen';

  @override
  String chipPartition(String partition) {
    return 'Partition: $partition';
  }

  @override
  String chipField(String field) {
    return 'Feld: $field';
  }

  @override
  String chipFilterType(String type) {
    return 'Typ: $type';
  }

  @override
  String chipScope(String scope) {
    return 'Bereich: $scope';
  }

  @override
  String get chipFastTrace => 'Fast Trace';

  @override
  String get welcomeTitle => 'Willkommen bei Kafkalyzer';

  @override
  String get welcomeSubtitle =>
      'Wähle einen Kafka-Cluster aus, um Topics zu untersuchen, Consumer-Lag zu überwachen und Skripte auszuführen.';

  @override
  String get configuredClusters => 'Konfigurierte Cluster';

  @override
  String get noClustersConfigured => 'Noch keine Cluster konfiguriert.';

  @override
  String get addClusterAction => 'Cluster hinzufügen';

  @override
  String get connectCluster => 'Verbinden';

  @override
  String get recentTopics => 'Zuletzt untersuchte Topics';

  @override
  String get clearRecentTopics => 'Verlauf leeren';

  @override
  String clusterTopicsCount(int count) {
    return '$count Topics';
  }

  @override
  String get schemaRegistryActive => 'Schema Registry verbunden';

  @override
  String get schemaRegistryNotConfigured => 'Keine Schema Registry';

  @override
  String get selectTopicPrompt =>
      'Wähle ein Topic in der Seitenleiste aus, um Nachrichten abzurufen und Partitionen zu analysieren.';

  @override
  String recentTopicsForCluster(String cluster) {
    return 'Kürzlich geöffnete Topics in $cluster';
  }

  @override
  String get noMessagesLoadedTitle => 'Noch keine Nachrichten geladen';

  @override
  String get noMessagesLoadedSubtitle =>
      'Lade die neuesten Nachrichten aus diesem Topic oder passe oben vorab deine Such- und Zeitfilter an.';

  @override
  String get fetchLatestMessagesAction =>
      'Letzte 200 Nachrichten jetzt abrufen';

  @override
  String get doubleClickTopicTip =>
      'Tipp: Doppelklick auf ein Topic in der Seitenleiste startet den Abruf sofort.';

  @override
  String get loadingMessages => 'Nachrichten werden von Kafka geladen...';

  @override
  String get internalTopicsFilter => 'Interne Topics';

  @override
  String get streamTopicsFilter => 'Stream-Topics';

  @override
  String topicTooltip(int partitions, int rf, String retention, String policy) {
    return 'Partitionen: $partitions • RF: $rf • Retention: $retention • Cleanup: $policy';
  }

  @override
  String topicTooltipSimple(int partitions, int rf) {
    return 'Partitionen: $partitions • RF: $rf';
  }

  @override
  String messageSchemaResolved(String subject, int version, int id) {
    return 'Schema: $subject v$version (#$id)';
  }

  @override
  String messageSchemaUnresolved(int id) {
    return 'Schema #$id (nicht aufgelöst)';
  }

  @override
  String get messageSchemaUnresolvedTooltip =>
      'Das Schema Registry war nicht erreichbar. Die Id stammt aus der Nachricht selbst.';

  @override
  String get groupMembersTitle => 'Mitglieder';

  @override
  String get groupMemberEmpty => 'Diese Gruppe hat aktuell keine Mitglieder.';

  @override
  String groupMemberPartitions(int count) {
    return '$count Partitionen';
  }

  @override
  String groupUnassignedPartitions(int count) {
    return '$count Partitionen haben keinen Eigentümer';
  }

  @override
  String get groupAssignmentNotDecodable =>
      'Zuweisung konnte nicht gelesen werden';

  @override
  String topicHealthWarning(int underReplicated, int leaderless) {
    return '$underReplicated unterrepliziert, $leaderless ohne Leader';
  }

  @override
  String get partitionHealthTitle => 'Replikationsstatus';

  @override
  String get partitionHealthDialogTitle => 'Partitions- und Replikationsstatus';

  @override
  String get partitionHealthTooltip =>
      'Partitions- und Replikationsstatus anzeigen';

  @override
  String get partitionLeaderCol => 'Leader';

  @override
  String get partitionReplicasCol => 'Repliken';

  @override
  String get partitionIsrCol => 'ISR';

  @override
  String get partitionHealthUnavailable =>
      'Partition-Metadaten nicht verfügbar';

  @override
  String get partitionNoLeader => 'keiner';

  @override
  String schemaTooltipSuffix(String schema) {
    return ' • Schema: $schema';
  }

  @override
  String get viewModeTable => 'Tabelle';

  @override
  String get viewModeTableTooltip => 'Tabellenansicht';

  @override
  String get viewModeTimeline => 'Zeitverlauf';

  @override
  String get viewModeTimelineTooltip => 'Zeitverlaufsansicht';

  @override
  String get viewModeDiff => 'Vergleich';

  @override
  String get viewModeDiffTooltip => 'Vergleichsansicht (Diff)';

  @override
  String get viewModeSchema => 'Schema';

  @override
  String get viewModeSchemaTooltip => 'Schemaansicht';

  @override
  String filterInLoadedMessages(int count) {
    return 'In $count geladenen Nachrichten filtern...';
  }

  @override
  String matchesOfTotal(int matchCount, int totalCount) {
    return '$matchCount von $totalCount Treffern';
  }

  @override
  String loadedMessagesCount(int count) {
    return '$count geladene Nachrichten';
  }

  @override
  String get sslClientAuthMode => 'Client-Authentifizierung (mTLS)';

  @override
  String get sslClientAuthNone => 'Keine';

  @override
  String get sslClientAuthKeystore => 'Keystore (PKCS12 / JKS)';

  @override
  String get sslClientAuthPem => 'PEM-Zertifikat & Key';

  @override
  String get browseFiles => 'Dateien durchsuchen';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort ausblenden';

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get testingConnection => 'Verbindung wird getestet...';

  @override
  String get schemaRegistryCredentialsOptional =>
      'Zugangsdaten für Schema Registry (optional)';

  @override
  String get globalConfigDescription =>
      'Gesamte App-Konfiguration inklusive aller Cluster-Profile und Einstellungen sichern oder wiederherstellen.';

  @override
  String get clusterExportDescription =>
      'Ausgewählte Cluster-Profile inklusive Zertifikaten als portable ZIP-Datei exportieren oder importieren.';

  @override
  String get schemaRegistryConfiguredBadge => 'Schema Registry';

  @override
  String get maxConcurrentLagQueries => 'Maximale gleichzeitige Lag-Abfragen';

  @override
  String get deleteStepConfirmationTitle => 'Schritt löschen?';

  @override
  String deleteStepConfirmationMessage(String name) {
    return 'Möchten Sie den Schritt „$name“ wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get addTopicManually => 'Topic manuell hinzufügen';

  @override
  String get manualTopicNamePrompt => 'Topic-Namen eingeben';

  @override
  String get addTopicAction => 'Topic hinzufügen';

  @override
  String get topicLoadingHint => 'Topics werden geladen...';

  @override
  String selectTopicsCount(int count) {
    return 'Topics auswählen ($count ausgewählt)';
  }

  @override
  String get extractionSource => 'Quelle';

  @override
  String get extractionTopic => 'Topic';

  @override
  String get extractionVariableName => 'Variablenname';

  @override
  String get extractionJsonPath =>
      'Feldpfad (z. B. order.id, items[0].sku, /order/status)';

  @override
  String get concurrencyLimit => 'Gleichzeitige Durchläufe';

  @override
  String get advancedFiltersSection => 'Erweiterte Filter';

  @override
  String get deleteScriptConfirmationTitle => 'Skript löschen?';

  @override
  String deleteScriptConfirmationMessage(String name) {
    return 'Möchten Sie das Skript \"$name\" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get searchScripts => 'Skripte durchsuchen...';

  @override
  String get pipelinePreview => 'Pipeline-Vorschau';

  @override
  String pipelineStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return '$_temp0';
  }

  @override
  String get noStepsInPipeline =>
      'Keine Ablauf-Schritte definiert. Wechseln Sie zum Bearbeiten-Tab, um Schritte hinzuzufügen.';

  @override
  String get parametersAndExecution => 'Skript-Parameter & Start';

  @override
  String runScriptWithSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return 'Skript starten ($_temp0)';
  }

  @override
  String get variableTypeText => 'Text';

  @override
  String get variableTypeNumeric => 'Zahl';

  @override
  String stepNumber(int number) {
    return 'Schritt $number';
  }

  @override
  String get targetCluster => 'Ziel-Cluster';

  @override
  String get extractedVariables => 'Extrahiert';

  @override
  String get filter => 'Filter';

  @override
  String get schemaAction => 'Schema';

  @override
  String get scanProgressTitle => 'Scan-Fortschritt';

  @override
  String get clearMessagesTooltip => 'Nachrichten leeren';

  @override
  String get editCluster => 'Cluster bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get securityProtocol => 'Sicherheitsprotokoll';

  @override
  String get sslConfigurationTitle => 'SSL / TLS Konfiguration';

  @override
  String get truststoreLocationLabel => 'Server-Truststore (PEM / JKS)';

  @override
  String get truststorePasswordLabel => 'Truststore-Passwort';

  @override
  String get keystoreLocationLabel => 'Keystore-Datei (.p12 / .pfx / .jks)';

  @override
  String get keystorePasswordLabel => 'Keystore-Passwort';

  @override
  String get clientCertPemLocationLabel => 'Client-Zertifikat (PEM)';

  @override
  String get clientKeyPemLocationLabel => 'Client Private Key (PEM)';

  @override
  String get clientKeyPasswordLabel => 'Private Key Passwort';

  @override
  String get saslMechanismLabel => 'SASL-Mechanismus';

  @override
  String get kerberosServiceNameLabel => 'Kerberos Service-Name';

  @override
  String get kerberosKeytabPathLabel => 'Kerberos Keytab-Pfad';

  @override
  String get kerberosPrincipalLabel => 'Kerberos Principal';

  @override
  String get kerberosConfigPathLabel =>
      'Kerberos Konfiguration (krb5.conf) Pfad';

  @override
  String get oauthbearerTokenLabel => 'OAuthbearer Token';

  @override
  String get saslUsernameLabel => 'SASL-Benutzername';

  @override
  String get saslPasswordLabel => 'SASL-Passwort';

  @override
  String get schemaRegistryUsernameOptional =>
      'Schema Registry Benutzername (optional)';

  @override
  String get schemaRegistryPasswordOptional =>
      'Schema Registry Passwort (optional)';

  @override
  String get schemaRegistryUrlTypoPort =>
      'Möglicher Tippfehler: Verwenden Sie \':\' für den Port statt \'.\'';

  @override
  String get schemaRegistryUrlMissingProtocol =>
      'Fehlendes Protokoll (http:// oder https://)';

  @override
  String get schemaViewerTitle => 'Schema-Viewer';

  @override
  String get noAvroSchemaFound => 'Kein Avro-Schema für dieses Topic gefunden.';

  @override
  String errorLoadingSchema(String error) {
    return 'Fehler beim Laden des Schemas: $error';
  }

  @override
  String get noMessagesToDisplay => 'Keine Nachrichten zum Anzeigen';

  @override
  String get copyValueTooltip => 'Wert kopieren';

  @override
  String get valueCopiedToClipboard => 'Wert in die Zwischenablage kopiert';

  @override
  String get emptyJson => 'Leeres JSON';

  @override
  String get topicNameCopied => 'Topic-Name kopiert';

  @override
  String get copyTopicName => 'Topic-Name kopieren';

  @override
  String get clusterNameLabel => 'Cluster-Name';

  @override
  String get requiredValidation => 'Erforderlich';

  @override
  String get bootstrapServersLabel => 'Bootstrap-Server (z. B. localhost:9092)';

  @override
  String get schemaRegistryUrlLabel => 'Schema Registry URL (optional)';

  @override
  String get invalidUrlFormat => 'Ungültiges URL-Format';

  @override
  String get keySchemaTitle => 'Key-Schema';

  @override
  String get valueSchemaTitle => 'Value-Schema';

  @override
  String get schemaTabTitle => 'Schema';

  @override
  String get schemaPinAsColumnTooltip =>
      'Dieses Schema-Feld als Tabellenspalte anheften';

  @override
  String get schemaFilterByFieldTooltip =>
      'Nachrichten nach diesem Schema-Feld filtern';

  @override
  String schemaFieldFilterApplied(String field) {
    return 'Filterfeld auf \'$field\' gesetzt';
  }

  @override
  String get schemaNoRegistryConfigured =>
      'Keine Schema Registry für diesen Cluster konfiguriert.';

  @override
  String get schemaConfigureRegistryAction => 'Cluster konfigurieren';

  @override
  String get schemaRetry => 'Wiederholen';

  @override
  String get schemaSearchHint => 'Schema-Felder und Typen suchen...';

  @override
  String get schemaVersionLabel => 'Version';

  @override
  String get schemaSideKey => 'Schlüssel';

  @override
  String get schemaSideValue => 'Wert';

  @override
  String get schemaNone => 'kein Registry-Schema';

  @override
  String lagTrendTooltip(Object readings, Object high, Object low) {
    return 'Messwerte: $readings - höchster $high, niedrigster $low';
  }

  @override
  String lagOverThreshold(Object threshold) {
    return 'Oberhalb der Warnschwelle von $threshold Nachrichten';
  }

  @override
  String get lagWarnThresholdLabel => 'Consumer-Lag-Warnschwelle (Nachrichten)';

  @override
  String get comparisonAction => 'Vergleichen';

  @override
  String get comparisonTitle => 'Report-Vergleich';

  @override
  String get comparisonSourceLive => 'Live';

  @override
  String get comparisonSourceImported => 'Importiert';

  @override
  String get comparisonNotAvailable => 'nicht verfügbar';

  @override
  String get comparisonFieldsAdded => 'Felder hinzugekommen';

  @override
  String get comparisonFieldsRemoved => 'Felder entfernt';

  @override
  String get comparisonBusiestPartition => 'Anteil der stärksten Partition';

  @override
  String get comparisonMinSize => 'Min. Nachrichtengröße';

  @override
  String get comparisonMaxSize => 'Max. Nachrichtengröße';

  @override
  String get comparisonAwaitingSecond =>
      'Wähle das zweite Report für den Vergleich.';

  @override
  String comparisonTopicMismatch(Object topicA, Object topicB) {
    return 'Cannot compare reports of different topics: $topicA and $topicB.';
  }

  @override
  String get sizePercentiles => 'p50/p95/p99';

  @override
  String get estimatedIndicator => 'geschätzt';

  @override
  String get distinctKeys => 'Unterschiedliche Keys';

  @override
  String get cappedIndicator => 'begrenzt';

  @override
  String get exportAsJson => 'JSON (Vollständige Nachricht)';

  @override
  String get exportAsNdjson => 'NDJSON (eine Nachricht pro Zeile)';

  @override
  String get exportAsCsv => 'CSV (Sichtbare Spalten)';

  @override
  String get exportMessagesCsv => 'Nachrichten als CSV exportieren';

  @override
  String exportSelectedOnly(int count) {
    return 'Nur ausgewählte Nachrichten ($count)';
  }

  @override
  String get exportIncludeDimmedNonMatches =>
      'Abgeblendete Nicht-Treffer einschließen';

  @override
  String get exportAddHeadersColumn => 'Headers-Spalte hinzufügen (CSV)';

  @override
  String get pauseView => 'Pausieren';

  @override
  String get pauseViewTooltip =>
      'Ergebnisansicht einfrieren, während der Stream im Hintergrund weiterläuft';

  @override
  String resumeViewWithNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fortsetzen · $count neu',
      one: 'Fortsetzen · 1 neu',
      zero: 'Fortsetzen',
    );
    return '$_temp0';
  }

  @override
  String get resumeViewTooltip =>
      'Live-Aktualisierung fortsetzen und gepufferte Nachrichten übernehmen';

  @override
  String get followNewest => 'Neueste verfolgen';

  @override
  String get followNewestOnTooltip =>
      'Folgt den neuesten Nachrichten; klicken oder scrollen zum Anhalten';

  @override
  String get followNewestOffTooltip =>
      'Zu den neuesten Nachrichten springen und weiter verfolgen';

  @override
  String get followNewestDisabledTooltip =>
      '„Neueste verfolgen“ erfordert Sortierung nach Zeitstempel';

  @override
  String droppedMessagesIndicator(String dropped, String limit) {
    return '$dropped älteste Nachrichten verworfen (Limit $limit)';
  }

  @override
  String get droppedMessagesTooltip =>
      'Älteste Nachrichten wurden beim Erreichen des Pufferlimits verworfen. Anpassbar unter Einstellungen → Allgemein.';

  @override
  String get messageBufferLimitLabel => 'Nachrichten-Pufferlimit';

  @override
  String get messageBufferLimitHelper =>
      'Maximale Anzahl gepufferter Nachrichten pro Topic-Tab oder Suchziel (1.000–1.000.000)';

  @override
  String get messageBufferLimitError =>
      'Bitte eine ganze Zahl zwischen 1.000 und 1.000.000 eingeben';

  @override
  String get searchPresets => 'Gespeicherte Suchen';

  @override
  String get defaultPreset => 'Standard';

  @override
  String get saveSearchPreset => 'Aktuelle Suche speichern...';

  @override
  String get savePresetDialogTitle => 'Suche-Preset speichern';

  @override
  String get presetNameLabel => 'Preset-Name';

  @override
  String get presetSaved => 'Preset gespeichert';

  @override
  String get presetDeleted => 'Preset gelöscht';

  @override
  String get deletePreset => 'Preset löschen';

  @override
  String get restoreOpenTabsOnStartup =>
      'Offene Tabs beim Start wiederherstellen';

  @override
  String get restoreOpenTabsOnStartupDescription =>
      'Zuvor geöffnete Topic-Tabs bei Verbindung mit einem Cluster automatisch wiederherstellen';

  @override
  String get copyCliCommand => 'Headless-CLI-Befehl kopieren';

  @override
  String get cliCommandCopied => 'CLI-Befehl in Zwischenablage kopiert';

  @override
  String get protectedByOsKeyring => 'Durch OS-Keyring geschützt';

  @override
  String get includeCredentialsInExport =>
      'Passwörter und Token in den Export einschließen';

  @override
  String get includeCredentialsWarning =>
      'Anmeldedaten werden mit Ihrer Passphrase in einem age-Archiv (.zip.age) verschlüsselt.';

  @override
  String get readOnlyBadgeLabel => 'Schreibgeschützt';

  @override
  String get readOnlyBadgeTooltip =>
      'kafkalyzer ist per Design rein lesend. Es werden keine Schreib-, Veröffentlichungs- oder Offset-Commit-Operationen ausgeführt.';

  @override
  String get readOnlySecurityTitle => 'Read-Only-Architektur & Sicherheit';

  @override
  String get readOnlySecurityDescription =>
      'kafkalyzer verbindet sich ausschließlich als Consumer mit manueller Partitionszuweisung und deaktiviertem Auto-Commit. Die Anwendung enthält keine Producer-Logik und kann Topics, Konfigurationen oder Consumer-Group-Offsets auf dem Broker nicht verändern.';

  @override
  String get readOnlyAclRecommendationTitle =>
      'Empfohlene Least-Privilege-ACLs';

  @override
  String get readOnlyAclRecommendationDescription =>
      'Für Defense-in-Depth empfiehlt sich ein Service-Account mit reinen Leserechten (Describe, Read, DescribeConfigs). Erteilen Sie keine Write-, AlterConfigs- oder IdempotentWrite-Berechtigungen.';

  @override
  String get readOnlyAclCommandTopicLabel => 'Topic-ACL-Befehlsvorlage:';

  @override
  String get readOnlyAclCommandGroupLabel =>
      'Consumer-Group-ACL-Befehlsvorlage:';

  @override
  String get readOnlyCopyCommand => 'ACL-Befehle kopieren';

  @override
  String get readOnlyAclCommandsCopied =>
      'ACL-Befehle in die Zwischenablage kopiert';

  @override
  String get compareSchemaVersions => 'Versionen vergleichen';

  @override
  String get schemaDiffTitle => 'Schema-Versionsvergleich';

  @override
  String get baseVersionLabel => 'Basisversion';

  @override
  String get compareVersionLabel => 'Vergleichsversion';

  @override
  String get checkCompatibility => 'Kompatibilität prüfen';

  @override
  String get schemaCompatible => 'Kompatibel';

  @override
  String get schemaIncompatible => 'Inkompatibel';

  @override
  String get compatibilityCheckSuccess =>
      'Das Schema ist mit der ausgewählten Version kompatibel.';

  @override
  String get associatedTopicsTitle => 'Zugehörige Topics';

  @override
  String get noAssociatedTopicsFound =>
      'Keine zugehörigen Topics für dieses Subject gefunden.';

  @override
  String get schemaNoDifferencesFound =>
      'Keine Unterschiede zwischen den ausgewählten Versionen gefunden.';

  @override
  String get draftSchemaLabel => 'Entwurf-Schema (JSON)';

  @override
  String get dlqBadgeLabel => 'DLQ';

  @override
  String get retryBadgeLabel => 'Retry';

  @override
  String associatedDlqCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler-Topics',
      one: '1 Fehler-Topic',
    );
    return '$_temp0';
  }

  @override
  String get failureDiagnosticsTitle => 'Fehlerdiagnose (DLQ)';

  @override
  String get exceptionMessageLabel => 'Ausnahme';

  @override
  String originalCoordinates(String topic, int partition, int offset) {
    return 'Ursprung: $topic [P: $partition, O: $offset]';
  }

  @override
  String get jumpToOriginalMessage => 'Zu Originalnachricht springen';

  @override
  String get copyFailedMessage => 'Fehlgeschlagene Nachricht kopieren';

  @override
  String get failedMessageCopied =>
      'Fehlgeschlagene Nachricht in die Zwischenablage kopiert';

  @override
  String get copyShareableLink => 'Teilbaren Link kopieren';

  @override
  String get shareableLinkCopied => 'Teilbarer Link in Zwischenablage kopiert';

  @override
  String get quickJumpTitle => 'Direktsprung / Referenz öffnen';

  @override
  String get quickJumpHint =>
      'kafkalyzer:// Link einfügen (z. B. kafkalyzer://open?topic=...&offset=...)';

  @override
  String get quickJumpInvalid => 'Ungültiges Referenz-URI-Format';

  @override
  String quickJumpClusterNotFound(String cluster) {
    return 'Cluster \'$cluster\' nicht konfiguriert. Wählen Sie einen Cluster:';
  }

  @override
  String get jump => 'Springen';

  @override
  String get openFile => 'Öffnen';

  @override
  String get showInFolder => 'Im Ordner anzeigen';

  @override
  String failedToOpenFile(String error) {
    return 'Fehler beim Öffnen der Datei: $error';
  }

  @override
  String get lagEstimateCaughtUp => 'Aufgeholt';

  @override
  String get lagEstimateGrowing => 'Rückstau wächst';

  @override
  String get lagEstimateStalled => 'Stagnierend';

  @override
  String get lagEstimatePending => 'Berechnung...';

  @override
  String get lagEstimateRateUnit => 'Nachr./s';

  @override
  String lagEstimateEtaPrefix(String eta) {
    return 'Dauer: $eta';
  }

  @override
  String lagEstimateTooltip(
    String rate,
    String delta,
    String interval,
    String status,
  ) {
    return 'Rate: $rate | Delta: $delta über $interval | Status: $status';
  }

  @override
  String get recentProductionTitle => 'Kürzliche Produktion';

  @override
  String get window6h => '6 Std.';

  @override
  String get window12h => '12 Std.';

  @override
  String get window24h => '24 Std.';

  @override
  String get window48h => '48 Std.';

  @override
  String get window72h => '72 Std.';

  @override
  String get timelineNotAvailableForReport =>
      'Zeitverlauf ist für diesen Bericht nicht verfügbar.';

  @override
  String timeZoneLabel(String timeZone) {
    return 'Lokale Zeit ($timeZone)';
  }

  @override
  String get unusualIncreaseBadge => 'Ungewöhnlicher Anstieg';

  @override
  String baselineLabel(String baseline) {
    return 'Basislinie: $baseline';
  }

  @override
  String get noComparisonData => 'Keine Vergleichsdaten';

  @override
  String uncoveredHourHint(int count) {
    return 'Vor Erfassungsbeginn ($count Nachrichten)';
  }

  @override
  String get currentHourIncomplete => 'Unvollständige Stunde';

  @override
  String coverageHint(int hours) {
    return 'Scan deckt die letzten $hours Stunden dieses Fensters ab.';
  }

  @override
  String hourlyTooltipMatches(String matches, String share) {
    return '$matches Treffer ($share%)';
  }

  @override
  String get dailyProductionTitle => 'Tägliche Produktionsverteilung';

  @override
  String get dailyProductionSubtitle => 'Nachrichten pro Kalendertag';

  @override
  String get partialCoverageBadge => 'Teilweise erfasst';

  @override
  String dailyMatchesShare(String matches, String share) {
    return '$matches ($share%)';
  }

  @override
  String get valueFilterButton => 'Nach Feldwert filtern';

  @override
  String valueFilterActive(String path, String value) {
    return 'Filter: $path = $value';
  }

  @override
  String get valueFilterDialogTitle => 'Nach Feldwert filtern';

  @override
  String get valueFilterDialogFieldPath => 'Feldpfad (z. B. attributes.region)';

  @override
  String get valueFilterDialogValue => 'Exakter Wert';

  @override
  String get valueFilterApply => 'Filter anwenden';

  @override
  String get valueFilterValidationEmpty => 'Feldpfad darf nicht leer sein';

  @override
  String get valueFilterMatchCardTitle => 'Filter-Treffer';

  @override
  String valueFilterMatchCount(String count) {
    return '$count Treffer';
  }

  @override
  String valueFilterShareOfTotal(String percent) {
    return '$percent% aller gescannten Nachrichten';
  }

  @override
  String valueFilterShareOfField(String percent) {
    return '$percent% der Nachrichten mit diesem Feld';
  }

  @override
  String valueFilterRemainder(String remainder) {
    return '$remainder nicht-übereinstimmende Nachrichten';
  }

  @override
  String get drillDownDialogTitle => 'Feldwert-Details';

  @override
  String drillDownFieldPath(String path) {
    return 'Feld: $path';
  }

  @override
  String drillDownCount(String count) {
    return 'Anzahl: $count';
  }

  @override
  String drillDownShareOfAll(String percent) {
    return 'Anteil an allen Nachrichten: $percent%';
  }

  @override
  String drillDownShareOfField(String percent) {
    return 'Anteil am Vorkommen: $percent%';
  }

  @override
  String get drillDownRescanButton => 'Mit diesem Filter neu scannen';

  @override
  String get drillDownApproximateBadge => 'Ungefähr (Werte begrenzt)';

  @override
  String get drillDownTruncatedNotice =>
      'Wert wurde gekürzt (>80 Zeichen). Neu-Scan kann nicht mit gekürzten Werten gestartet werden.';

  @override
  String get drillDownRescanUnavailableImported =>
      'Neu-Scan ist für importierte Berichte nicht verfügbar.';

  @override
  String get duplicateScopeLabel => 'Duplikatskriterium';

  @override
  String get duplicateScopePayloadOnly => 'Nutzlast (Wert)';

  @override
  String get duplicateScopeKeyAndPayload => 'Key + Nutzlast';

  @override
  String get duplicateMessagesCardTitle => 'Mehrfach publizierte Nachrichten';

  @override
  String duplicateMessagesSubtitle(String unique, String scope) {
    return '$unique eindeutig • $scope';
  }

  @override
  String get topDuplicatesTitle => 'Häufigste Nachrichten-Duplikate';

  @override
  String get topDuplicatesSubtitle =>
      'Zeigt bis zu 20 der am häufigsten duplizierten Nachrichten';

  @override
  String get noDuplicatesDetected => 'Keine Duplikate in diesem Scan gefunden.';

  @override
  String get duplicateAnalysisUnavailable =>
      'Duplikatanalyse für diesen Bericht nicht verfügbar.';

  @override
  String sampleLocation(int partition, int offset) {
    return 'Partition $partition, Offset $offset';
  }

  @override
  String get copyPayload => 'Nutzlast kopieren';

  @override
  String get copyKey => 'Key kopieren';

  @override
  String get copiedPayload => 'Nutzlast in Zwischenablage kopiert';

  @override
  String get copiedKey => 'Key in Zwischenablage kopiert';

  @override
  String get duplicateRankHeader => '#';

  @override
  String get duplicateCountHeader => 'Vorkommen';

  @override
  String get duplicateKeyHeader => 'Key';

  @override
  String get duplicatePayloadPreviewHeader => 'Nutzlast-Vorschau';

  @override
  String get duplicateSampleCoordinatesHeader => 'Beispiel-Ort';

  @override
  String get duplicateDetailsTitle => 'Duplikat-Details';

  @override
  String duplicateDetailsSubtitle(int rank, String count, String share) {
    return 'Rang #$rank • $count Vorkommen ($share%)';
  }

  @override
  String get openInMessages => 'In Nachrichten anzeigen';

  @override
  String get filterDuplicatesInMessages => 'In Nachrichten filtern';

  @override
  String get jumpToSampleOffset => 'Zum Beispiel springen';

  @override
  String get duplicateKey => 'Key';

  @override
  String get duplicatePayload => 'Dekodierte Nutzlast';

  @override
  String get inspectDuplicateTooltip => 'Duplikat-Details anzeigen';

  @override
  String importRejectedUnsafeEntry(String entry) {
    return 'Import abgelehnt: Das Archiv enthält einen unsicheren Eintrag ($entry).';
  }

  @override
  String get clusterNameAlreadyUsed =>
      'Ein Cluster-Profil mit diesem Namen existiert bereits.';

  @override
  String get importConflictTitle => 'Cluster-Profil-Konflikt';

  @override
  String importConflictMessage(String name) {
    return 'Ein Cluster-Profil namens \"$name\" existiert bereits.';
  }

  @override
  String get importConflictReplace => 'Bestehendes ersetzen';

  @override
  String get importConflictRename => 'Unter neuem Namen importieren';

  @override
  String get importConflictSkip => 'Überspringen';

  @override
  String importSummary(int added, int replaced, int renamed, int skipped) {
    return 'Import: $added hinzugefügt, $replaced ersetzt, $renamed umbenannt, $skipped übersprungen.';
  }

  @override
  String get keyringUnavailableNotice =>
      'Der System-Schlüsselbund ist nicht verfügbar. Zugangsdaten werden nur für diese Sitzung im Speicher gehalten und nicht dauerhaft sicher gespeichert.';

  @override
  String get profileStoreUnreadableNotice =>
      'Gespeicherte Cluster-Profile konnten nicht gelesen werden und blieben unverändert, damit nichts verloren geht.';

  @override
  String get scriptStoreUnreadableNotice =>
      'Gespeicherte Skripte konnten nicht gelesen werden und blieben unverändert, damit nichts verloren geht.';

  @override
  String storeBackupLocation(String path) {
    return 'Sicherung gespeichert unter: $path';
  }

  @override
  String get storeBackupFailed =>
      'Es konnte keine Sicherungsdatei geschrieben werden.';

  @override
  String storePartiallyUnreadable(int count, String store) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Einträge wurden',
      one: 'Eintrag wurde',
    );
    return '$count nicht lesbare gespeicherte $store-$_temp0 übersprungen und erhalten.';
  }

  @override
  String duplicateProfileNamesNotice(String names) {
    return 'Doppelte Cluster-Profilnamen erkannt: $names. Bitte benennen Sie Duplikate um, sodass jedes Profil einen eindeutigen Namen hat.';
  }

  @override
  String get discardUnreadableData => 'Unlesbare Daten verwerfen';

  @override
  String get discardUnreadableConfirm =>
      'Dadurch werden die nicht lesbaren gespeicherten Daten dauerhaft gelöscht, sodass neue Einträge gespeichert werden können. Fortfahren?';

  @override
  String get copyBackupPath => 'Sicherungspfad kopieren';

  @override
  String get storeUnreadableActionRefused =>
      'Aktion abgelehnt, solange gespeicherte Daten nicht lesbar sind. Verwerfen Sie zuerst die unlesbaren Daten oder stellen Sie die Sicherung wieder her.';

  @override
  String get passwordsNotPersistedTooltip =>
      'Der System-Schlüsselbund ist nicht verfügbar. Dieses Passwort wird nicht über Neustarts hinweg gespeichert.';

  @override
  String get insecureTlsBadgeLabel => 'Unsicheres TLS';

  @override
  String get insecureTlsBadgeTooltip =>
      'Die TLS-Zertifikatsprüfung ist für dieses Cluster-Profil deaktiviert.';

  @override
  String get tlsVerificationSwitchLabel => 'TLS-Zertifikate prüfen';

  @override
  String get tlsVerificationDisabledWarning =>
      'Warnung: Zertifikats- und Hostname-Prüfung ist für dieses Profil deaktiviert. Verbindungen sind anfällig für Abfangen.';

  @override
  String get tlsTransitionDialogTitle =>
      'TLS-Zertifikatsprüfung fehlgeschlagen';

  @override
  String tlsTransitionDialogBody(String clusterName, String error) {
    return 'Die Zertifikatsprüfung für das Cluster \"$clusterName\" ist fehlgeschlagen. Wählen Sie, ob die TLS-Prüfung aktiviert bleiben soll (empfohlen) oder für dieses Profil deaktiviert werden soll.\n\nDetails: $error';
  }

  @override
  String get tlsTransitionKeepEnabled => 'Prüfung aktiviert lassen';

  @override
  String get tlsTransitionDisable => 'Prüfung deaktivieren (unsicher)';

  @override
  String get messageFetchFailedTitle =>
      'Nachrichten konnten nicht geladen werden';

  @override
  String get topicsLoadFailedTitle => 'Topics konnten nicht geladen werden';

  @override
  String subjectsLoadFailed(String error) {
    return 'Schemas konnten nicht geladen werden: $error';
  }

  @override
  String get columnFiltersNoMatch =>
      'Keine Zeilen entsprechen den aktiven Spaltenfiltern.';

  @override
  String get resetColumnFilters => 'Filter zurücksetzen';

  @override
  String get lagUnknown => 'Unbekannt';

  @override
  String get lagNoCommit => 'Kein Commit';

  @override
  String get lagNoCommittedOffsets => 'Keine gespeicherten Offsets';

  @override
  String lagGroupsLoadedProgress(int loaded, int total) {
    return '$loaded von $total geladen';
  }

  @override
  String get lagTotalIncomplete => 'Summe unvollständig';

  @override
  String get lagErrorLabel => 'Fehler';

  @override
  String lagErrorTooltip(String error) {
    return 'Lag-Fehler: $error';
  }

  @override
  String get lagRetryAction => 'Erneut versuchen';

  @override
  String get lagRefreshInProgress => 'Aktualisierung läuft';

  @override
  String get partitionOwnershipUnknown => 'Partitionszuordnung unbekannt';

  @override
  String get diagStageNetwork => 'Netzwerk';

  @override
  String get diagStageTls => 'TLS';

  @override
  String get diagStageAuthentication => 'Authentifizierung';

  @override
  String get diagStageMetadata => 'Metadaten';

  @override
  String get diagStageSchemaRegistry => 'Schema Registry';

  @override
  String get diagStateOk => 'OK';

  @override
  String get diagStateFailed => 'Fehlgeschlagen';

  @override
  String get diagStateNotChecked => 'Nicht geprüft';

  @override
  String get diagStateNotApplicable => 'Nicht zutreffend';

  @override
  String get diagStateUndetermined => 'Unbestimmt';

  @override
  String diagNotCheckedPreviousFailed(String stage) {
    return 'Übersprungen, da $stage fehlgeschlagen ist';
  }

  @override
  String get diagNotCheckedBudgetExhausted =>
      'Übersprungen, da das Zeitbudget abgelaufen ist';

  @override
  String get diagOverallOk =>
      'Verbindung über alle zutreffenden Phasen erfolgreich';

  @override
  String diagOverallFailedAtStage(String stage) {
    return 'Verbindung fehlgeschlagen in Phase: $stage';
  }

  @override
  String get diagOverallStageUnknown =>
      'Verbindung fehlgeschlagen, Phase unbekannt';

  @override
  String get diagHintInvalidEntry =>
      'Bootstrap-Eintrag ist ungültig (erwartet host:port ohne Schema)';

  @override
  String get diagHintHostUnknown => 'Hostname konnte nicht aufgelöst werden';

  @override
  String get diagHintConnectionRefused => 'Verbindung vom Host abgelehnt';

  @override
  String get diagHintConnectTimeout =>
      'Zeitüberschreitung beim Verbindungsaufbau';

  @override
  String get diagHintCertificateRejected =>
      'Zertifikatsprüfung fehlgeschlagen — Truststore/CA oder Hostname prüfen';

  @override
  String get diagHintTlsHandshakeFailed =>
      'TLS-Handshake fehlgeschlagen — Client-/Server-Zertifikate und TLS-Einstellungen prüfen';

  @override
  String get diagHintProtocolMismatch =>
      'Sicherheitsprotokoll passt nicht zum Broker-Listener';

  @override
  String get diagHintAuthenticationFailed =>
      'Authentifizierung fehlgeschlagen — SASL-Benutzername und Passwort prüfen';

  @override
  String get diagHintMechanismRejected =>
      'SASL-Mechanismus abgelehnt oder vom Broker-Listener nicht unterstützt';

  @override
  String get diagHintNotAuthorized =>
      'Keine Berechtigung zum Abrufen der Cluster-Metadaten (ACLs prüfen)';

  @override
  String get diagHintRequestTimeout => 'Zeitüberschreitung der Anfrage';

  @override
  String get diagHintRegistryUnreachable =>
      'Schema Registry ist nicht erreichbar';

  @override
  String get diagHintRegistryUnauthorized =>
      'Schema Registry hat Zugangsdaten abgelehnt';

  @override
  String diagHintRegistryHttpError(int status) {
    return 'Schema Registry antwortete mit HTTP $status';
  }

  @override
  String get diagHintGeneric => 'Verbindungsprüfung fehlgeschlagen';

  @override
  String get diagServerDnsLabel => 'DNS';

  @override
  String get diagServerTcpLabel => 'TCP';

  @override
  String get diagServerResolvedLabel => 'Aufgelöst';

  @override
  String diagServerConnectedTo(String address) {
    return 'Verbunden mit $address';
  }

  @override
  String get diagRawErrorLabel => 'Roher Fehler';

  @override
  String get errorUnexpectedNotice =>
      'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get errorDetailsAction => 'Details';

  @override
  String get errorDetailsDialogTitle => 'Fehlerdetails';

  @override
  String get errorCopyDetails => 'Details kopieren';

  @override
  String get errorDetailsCopied =>
      'Fehlerdetails in die Zwischenablage kopiert';

  @override
  String get errorDetailsCopyFailed =>
      'Fehlerdetails konnten nicht in die Zwischenablage kopiert werden. Sie können den Text manuell markieren und kopieren.';

  @override
  String get startupFailureTitle => 'Kafkalyzer konnte nicht gestartet werden';

  @override
  String get startupFailureBody =>
      'Ein unerwarteter Fehler hat den Start von Kafkalyzer verhindert. Kopieren Sie die Details unten oder öffnen Sie den Log-Ordner.';

  @override
  String get startupFailureLogPathLabel => 'Logdatei';

  @override
  String get diagnosticsUnavailable => 'nicht verfügbar';

  @override
  String get diagnosticsUnknown => 'unbekannt';

  @override
  String get settingsDiagnosticsTitle => 'Diagnose';

  @override
  String get settingsDiagnosticsLogPathLabel => 'Logdatei';

  @override
  String get settingsOpenLogFolder => 'Log-Ordner öffnen';

  @override
  String get settingsCopyDiagnostics => 'Diagnose kopieren';

  @override
  String get settingsDiagnosticsCopied =>
      'Diagnosebericht in die Zwischenablage kopiert';

  @override
  String settingsOpenLogFolderFailed(String path) {
    return 'Log-Ordner konnte nicht geöffnet werden: $path';
  }

  @override
  String get settingsFileLoggingUnavailable =>
      'Dateiprotokollierung ist nicht verfügbar';

  @override
  String get settingsAboutButton => 'Über Kafkalyzer';

  @override
  String get aboutLegalese =>
      'Schreibgeschützter Apache-Kafka-Analyzer. Lizenziert unter Apache-2.0.';

  @override
  String get aboutRepositoryLabel => 'Quellcode-Repository';

  @override
  String get aboutLogFolderLabel => 'Log-Ordner';

  @override
  String get aboutDataFolderLabel => 'Einstellungs- und Datenordner';

  @override
  String get aboutOutputFolderLabel => 'Standard-Ausgabeordner';

  @override
  String get aboutOpenLinkFailed =>
      'Repository-Link konnte nicht im Browser geöffnet werden';

  @override
  String get settingsKeyboardShortcutsButton => 'Tastaturkürzel';

  @override
  String get shortcutOverviewTitle => 'Tastaturkürzel';

  @override
  String get shortcutContextGlobal => 'Global';

  @override
  String get shortcutContextExplorer => 'Explorer';

  @override
  String get shortcutContextScripts => 'Skripte';

  @override
  String get shortcutContextMessages => 'Nachrichten';

  @override
  String get shortcutContextInspector => 'Nachrichteninspektor';

  @override
  String get shortcutContextInspectorSearch => 'Inspektor-Suche';

  @override
  String get shortcutToggleSidebar => 'Seitenleiste umschalten';

  @override
  String get shortcutQuickJump => 'Schnellsprung';

  @override
  String get shortcutNextMessage => 'Nächste Nachricht';

  @override
  String get shortcutPreviousMessage => 'Vorherige Nachricht';

  @override
  String get shortcutToggleFocusMode => 'Fokusmodus umschalten';

  @override
  String get shortcutCloseInspectorOrExitFocus =>
      'Inspektor schließen oder Fokusmodus verlassen';

  @override
  String get shortcutNextSearchMatch => 'Nächster Suchtreffer';

  @override
  String get shortcutPreviousSearchMatch => 'Vorheriger Suchtreffer';

  @override
  String get shortcutCloseInspectorSearch => 'Inspektor-Suche schließen';

  @override
  String get shortcutShowOverview => 'Tastaturkürzel anzeigen';

  @override
  String get shortcutKeyEscape => 'Escape';

  @override
  String get shortcutKeyEnter => 'Enter';

  @override
  String get shortcutKeyArrowDown => 'Pfeil nach unten';

  @override
  String get shortcutKeyArrowUp => 'Pfeil nach oben';

  @override
  String get shortcutKeyShift => 'Umschalt';

  @override
  String get shortcutCommandPalette => 'Befehlspalette';

  @override
  String get commandPaletteHint => 'Cluster, Topics, Gruppen, Skripte suchen…';

  @override
  String get commandPaletteKindDestination => 'Bereich';

  @override
  String get commandPaletteKindCluster => 'Cluster';

  @override
  String get commandPaletteKindTopic => 'Topic';

  @override
  String get commandPaletteKindConsumerGroup => 'Consumer-Gruppe';

  @override
  String get commandPaletteKindScript => 'Skript';

  @override
  String get commandPaletteKindReference => 'Referenz';

  @override
  String get commandPaletteOpenReference => 'Referenz in Quick Jump öffnen';

  @override
  String get commandPaletteActiveCluster => 'aktiv';

  @override
  String get commandPaletteNoResults => 'Keine passenden Ergebnisse';

  @override
  String commandPaletteResultsCap(int shown, int total) {
    return '$shown von $total Treffern, weitertippen';
  }

  @override
  String get commandPaletteGroupsNotLoadedNote =>
      'Consumer-Gruppen erscheinen, nachdem Consumer Lag sie geladen hat.';

  @override
  String get commandPaletteListLabel => 'Ergebnisse der Befehlspalette';

  @override
  String commandPalettePartitionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Partitionen',
      one: '1 Partition',
    );
    return '$_temp0';
  }

  @override
  String commandPaletteStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return '$_temp0';
  }

  @override
  String consumerGroupNotFound(String id) {
    return 'Consumer-Gruppe $id nicht gefunden';
  }

  @override
  String get scriptNotFound => 'Skript nicht gefunden';

  @override
  String fastTracePartitionPreview(int partition, int partitionCount) {
    return 'Partition $partition von $partitionCount';
  }

  @override
  String get fastTracePartitionCountUnknown => 'Partitionsanzahl unbekannt';

  @override
  String get fastTraceEnterKeyHint =>
      'Schlüssel eingeben, um Zielpartition anzuzeigen';

  @override
  String get fastTraceFirstTermOnlyNote =>
      'Nur der erste Begriff wählt die gescannte Partition';

  @override
  String get fastTraceAssumptionSummary =>
      'Nimmt Java-Standard-Partitionierer (murmur2) und UTF-8-Textschlüssel an';

  @override
  String get fastTraceAssumptionCaveat =>
      'Nimmt den Java-Standard-Partitionierer über die UTF-8-Bytes des Textschlüssels an. Die tatsächliche Partition kann abweichen bei anderen Partitionierern (z. B. librdkafka consistent/CRC32 oder benutzerdefiniert), binären oder serialisierten Schlüsseln (z. B. Avro mit Confluent-Wire-Präfix) oder später hinzugefügten Partitionen.';

  @override
  String get fastTraceAssumptionInfoLabel =>
      'Annahmen zur Fast-Trace-Partitionierung';

  @override
  String chipFastTracePartition(int partition) {
    return 'Fast Trace → P$partition';
  }

  @override
  String get exportPassphraseLabel => 'Passphrase';

  @override
  String get exportPassphraseConfirmLabel => 'Passphrase bestätigen';

  @override
  String exportPassphraseTooShort(int min) {
    return 'Die Passphrase muss mindestens $min Zeichen lang sein';
  }

  @override
  String get exportPassphraseMismatch =>
      'Die Passphrasen stimmen nicht überein';

  @override
  String get exportPassphraseNotRecoverable =>
      'Eine verlorene Passphrase kann nicht wiederhergestellt werden. Ohne sie lässt sich dieses Archiv nicht öffnen.';

  @override
  String get showPassphrase => 'Passphrase anzeigen';

  @override
  String get hidePassphrase => 'Passphrase verbergen';

  @override
  String get encryptingBundle => 'Archiv wird verschlüsselt...';

  @override
  String get importPassphraseTitle => 'Archiv-Passphrase eingeben';

  @override
  String get importPassphraseLabel => 'Passphrase';

  @override
  String get importPassphraseWrong =>
      'Falsche Passphrase. Bitte versuchen Sie es erneut.';

  @override
  String get importEncryptedCorrupt =>
      'Das verschlüsselte Archiv ist beschädigt oder fehlerhaft.';

  @override
  String get importEncryptedUnsupported =>
      'Diese verschlüsselte Datei ist nicht mit einer Passphrase verschlüsselt und kann nicht importiert werden.';

  @override
  String get importEncryptedTooExpensive =>
      'Dieses verschlüsselte Archiv erfordert auf diesem Gerät zu viel Rechenaufwand zum Entschlüsseln.';

  @override
  String get searchRunning => 'Suche läuft...';

  @override
  String get searchFailed => 'Suche fehlgeschlagen';

  @override
  String matchesCountCapped(int current, int total) {
    return '$current / $total+';
  }

  @override
  String get environmentTagSectionTitle => 'Umgebungs-Tag (optional)';

  @override
  String get environmentLabelField => 'Umgebungs-Label';

  @override
  String get environmentLabelHint => 'z. B. DEV, TEST, STAGE, PROD';

  @override
  String environmentLabelTooLong(int max) {
    return 'Das Umgebungs-Label darf höchstens $max Zeichen lang sein';
  }

  @override
  String environmentSemanticsLabel(String label) {
    return 'Umgebung: $label';
  }

  @override
  String get environmentColorRed => 'Rot';

  @override
  String get environmentColorOrange => 'Orange';

  @override
  String get environmentColorYellow => 'Gelb';

  @override
  String get environmentColorGreen => 'Grün';

  @override
  String get environmentColorBlue => 'Blau';

  @override
  String get environmentColorPurple => 'Lila';

  @override
  String get environmentColorGrey => 'Grau';

  @override
  String get bootstrapNoEntries => 'Mindestens einen host:port-Eintrag angeben';

  @override
  String bootstrapMissingPort(String entry) {
    return 'Eintrag „$entry“ benötigt einen Port (:port)';
  }

  @override
  String bootstrapInvalidPort(String entry) {
    return 'Eintrag „$entry“ hat einen ungültigen Port (1–65535)';
  }

  @override
  String bootstrapInvalidHost(String entry) {
    return 'Eintrag „$entry“ hat einen ungültigen Host';
  }

  @override
  String bootstrapSchemeNotAllowed(String entry) {
    return 'Eintrag „$entry“ darf kein URL-Schema enthalten';
  }

  @override
  String get extraPropertiesTitle => 'Zusätzliche Client-Eigenschaften';

  @override
  String get extraPropertiesHint => 'Ein key=value pro Zeile';

  @override
  String get extraPropertiesAllowedKeysTitle => 'Erlaubte Schlüssel';

  @override
  String extraPropertiesSyntaxError(int line) {
    return 'Zeile $line: ungültige Syntax (key=value erwartet)';
  }

  @override
  String extraPropertiesNotAllowed(int line, String key) {
    return 'Zeile $line: „$key“ ist nicht erlaubt';
  }

  @override
  String extraPropertiesInvalidValue(int line, String key, String allowed) {
    return 'Zeile $line: ungültiger Wert für „$key“ (erlaubt: $allowed)';
  }

  @override
  String extraPropertiesDuplicate(int line, String key) {
    return 'Zeile $line: doppelter Schlüssel „$key“';
  }

  @override
  String get importClientPropertiesAction => 'client.properties importieren';

  @override
  String get importClientPropertiesPreviewTitle =>
      'Vorschau: client.properties-Import';

  @override
  String get importClientPropertiesMappedSection =>
      'Zu übernehmende Profilfelder';

  @override
  String get importClientPropertiesExtrasSection => 'Zusätzliche Eigenschaften';

  @override
  String get importClientPropertiesSkippedSection => 'Nicht übernommen';

  @override
  String get importClientPropertiesApplyAction => 'Übernehmen';

  @override
  String get importClientPropertiesTooLarge =>
      'Die Datei ist größer als 1 MiB und kann nicht importiert werden.';

  @override
  String get importClientPropertiesInvalidUtf8 =>
      'Die Datei ist kein gültiges UTF-8 und kann nicht gelesen werden.';

  @override
  String importClientPropertiesReadError(String error) {
    return 'Datei konnte nicht gelesen werden: $error';
  }

  @override
  String get importClientPropertiesNothingToApply =>
      'Keine unterstützten Eigenschaften in dieser Datei gefunden.';

  @override
  String get skipReasonNotAllowed => 'Unbekannt oder nicht erlaubt';

  @override
  String get skipReasonUnsupported => 'Nicht unterstützter Typ oder Format';

  @override
  String get skipReasonPlaceholder => 'Platzhalter kann nicht aufgelöst werden';

  @override
  String get skipReasonVerificationOverride =>
      'TLS-Prüfung kann nur ausdrücklich im Dialog deaktiviert werden';

  @override
  String get skipReasonInvalidValue => 'Ungültiger Wert';

  @override
  String get duplicateClusterAction => 'Duplizieren';

  @override
  String get duplicateClusterTitle => 'Cluster duplizieren';

  @override
  String get clusterFilterHint => 'Cluster filtern (Name, Umgebung, Bootstrap)';

  @override
  String get clusterFilterNoMatch => 'Kein Cluster entspricht dem Filter';

  @override
  String get clusterFilterClear => 'Filter zurücksetzen';

  @override
  String get disconnectClusterTooltip => 'Trennen';

  @override
  String disconnectConfirmTitle(String cluster) {
    return 'Verbindung zu $cluster trennen?';
  }

  @override
  String get disconnectConfirmBody =>
      'Für diesen Cluster läuft noch eine Suche oder Analyse. Beim Trennen wird sie gestoppt und seine Tabs werden geschlossen.';

  @override
  String get disconnectConfirmAction => 'Trennen';

  @override
  String unrestoredTabsMessage(int count, String topics) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tabs konnten nicht wiederhergestellt werden ($topics)',
      one: '1 Tab konnte nicht wiederhergestellt werden ($topics)',
    );
    return '$_temp0';
  }

  @override
  String get decodeAs => 'Dekodieren als…';

  @override
  String get decodeAsJson => 'JSON';

  @override
  String get decodeAsBase64 => 'Base64';

  @override
  String get decodeAsGzip => 'gzip';

  @override
  String get showOriginalOnly => 'Nur Original anzeigen';

  @override
  String get showOriginal => 'Original anzeigen';

  @override
  String get copyDecoded => 'Dekodiert kopieren';

  @override
  String get copyAsHex => 'Als Hex kopieren';

  @override
  String binaryBytesSummary(int count) {
    return '$count Bytes';
  }

  @override
  String get decodeErrorInvalidJson => 'Kein gültiges JSON';

  @override
  String get decodeErrorInvalidBase64 => 'Kein gültiges Base64';

  @override
  String get decodeErrorNotGzip => 'Kein gzip-Datenstrom';

  @override
  String get decodeErrorCorruptGzip => 'Beschädigte gzip-Daten';

  @override
  String decodeErrorInputTooLarge(int limitMib) {
    return 'Eingabe überschreitet Limit von $limitMib MiB';
  }

  @override
  String decodeErrorOutputTooLarge(int limitMib) {
    return 'Dekodierte Ausgabe überschreitet Limit von $limitMib MiB';
  }

  @override
  String get epochUnitSeconds => 'Sekunden';

  @override
  String get epochUnitMilliseconds => 'Millisekunden';

  @override
  String get epochUnitMicroseconds => 'Mikrosekunden';

  @override
  String get epochUnitNanoseconds => 'Nanosekunden';

  @override
  String epochTooltip(String primary, String secondary, String unit) {
    return '$primary\n$secondary\nAngenommene Einheit: $unit';
  }

  @override
  String get emptyValueMarker => 'Leerer Wert';

  @override
  String get inspectorKeySection => 'Schlüssel';

  @override
  String inspectorHeadersSection(int count) {
    return 'Header ($count)';
  }

  @override
  String get appearanceSectionTitle => 'Erscheinungsbild';

  @override
  String get themeLabel => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get textSizeLabel => 'Textgröße';

  @override
  String textSizeCustom(int percent) {
    return 'Benutzerdefiniert ($percent%)';
  }

  @override
  String get timeDisplayLabel => 'Zeitstempel';

  @override
  String get timeDisplayLocal => 'Lokal';

  @override
  String get timeDisplayUtc => 'UTC';

  @override
  String get defaultResultLimitLabel => 'Standard-Ergebnislimit';

  @override
  String intSettingRangeHelper(int min, int max, int defaultValue) {
    return 'Bereich: $min–$max (Standard: $defaultValue)';
  }

  @override
  String intSettingRangeError(int min, int max) {
    return 'Geben Sie eine ganze Zahl von $min bis $max ein';
  }

  @override
  String get resetToDefaults => 'Auf Standard zurücksetzen';

  @override
  String resetSectionConfirmTitle(String section) {
    return 'Einstellungen für „$section“ zurücksetzen?';
  }

  @override
  String resetSectionConfirmBody(String section) {
    return 'Dadurch werden die Einstellungen unter „$section“ auf die Standardwerte zurückgesetzt. Cluster-Profile, Zugangsdaten, Skripte und gespeicherte Suchen bleiben unverändert.';
  }

  @override
  String get resetConfirmAction => 'Zurücksetzen';

  @override
  String manualUpdateAvailableTitle(String version) {
    return 'Version $version verfügbar';
  }

  @override
  String manualUpdateAvailableBody(String version) {
    return 'Eine neuere Version ($version) ist auf GitHub verfügbar. Diese Installation kann sich nicht automatisch aktualisieren.';
  }

  @override
  String get manualUpToDateHint =>
      'Sie verwenden die neueste Version. Automatische Updates sind für diese Installation nicht verfügbar.';

  @override
  String latestReleaseKnownBody(String version) {
    return 'Neueste Version auf GitHub: $version. Die laufende Version konnte nicht verglichen werden.';
  }

  @override
  String get openReleasePage => 'Release-Seite öffnen';

  @override
  String get downloadCancelledSnackbar =>
      'Download abgebrochen. Das Update wird nicht installiert.';

  @override
  String get connectionErrorInvalidBootstrapServers =>
      'Ungültiger Bootstrap-Server';

  @override
  String get connectionErrorTlsVerificationFailed =>
      'TLS-Zertifikatsprüfung fehlgeschlagen';

  @override
  String get connectionErrorValidationFailed =>
      'Verbindungsprüfung fehlgeschlagen';

  @override
  String get connectionErrorBrokerTransport =>
      'Broker-Transportfehler. Adresse und Netzwerk prüfen.';

  @override
  String get connectionErrorConnectionRefused => 'Verbindung abgelehnt';

  @override
  String get connectionErrorOther => 'Verbindung fehlgeschlagen';

  @override
  String get topicAnalysisEmptyFieldPath => 'Feldpfad darf nicht leer sein';

  @override
  String get topicAnalysisNoPreviousScope =>
      'Kein vorheriger Analysebereich zum erneuten Scannen vorhanden';

  @override
  String get exportTopicAnalysis => 'Topic-Analyse exportieren';

  @override
  String get importTopicAnalysis => 'Topic-Analyse importieren';

  @override
  String saveRunArchive(String name) {
    return 'Lauf-Archiv speichern - $name';
  }

  @override
  String get saveSchemaMarkdown => 'Schema-Markdown speichern';

  @override
  String get step => 'Schritt';

  @override
  String get content => 'Inhalt';

  @override
  String filterColumnTitle(String column) {
    return '$column filtern';
  }

  @override
  String get filterSubstringHint => 'Suchtext zum Filtern eingeben...';

  @override
  String get copyContent => 'Inhalt kopieren';

  @override
  String get emptyBinaryData => 'Leere Binärdaten';

  @override
  String get preparingHexDump =>
      'Hex-Dump für Zwischenablage wird vorbereitet...';

  @override
  String get hexDumpCopied => 'Hex-Dump in die Zwischenablage kopiert';

  @override
  String get copyFullHexDump => 'Vollständigen Hex-Dump kopieren';

  @override
  String get objectCopiedToClipboard => 'Objekt in die Zwischenablage kopiert';

  @override
  String get entityDetails => 'Entitätsdetails';

  @override
  String get copyWholeObject => 'Gesamtes Objekt kopieren';

  @override
  String get errorComputingDiff => 'Fehler beim Berechnen des Diffs';

  @override
  String get globalNoStep => 'Global (Kein Schritt)';

  @override
  String get stacktrace => 'Stacktrace';

  @override
  String noResultsMatchingPhrase(String phrase) {
    return 'Keine Ergebnisse für \'$phrase\' gefunden';
  }

  @override
  String get hideNonMatchingMessages => 'Nicht passende Nachrichten ausblenden';

  @override
  String get showNonMatchesAsDimmed =>
      'Nicht passende Nachrichten abgeblendet anzeigen';

  @override
  String get availableTopics => 'Verfügbare Topics';

  @override
  String get optionalMetadataRegistry => 'Optionale Metadaten-Registry';

  @override
  String get noClusterSelected => 'Kein Cluster ausgewählt';

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
    return 'z.B. $url';
  }

  @override
  String get startTime => 'Startzeit';

  @override
  String get endTime => 'Endzeit';

  @override
  String get fieldOptional => 'Feld (Opt.)';

  @override
  String selectTopicsDialogTitle(int count, int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Topics auswählen ($filtered/$total)',
      one: 'Topic auswählen ($filtered/$total)',
    );
    return '$_temp0';
  }

  @override
  String get kafkaStreamTopics => 'Kafka-Stream-Topics';

  @override
  String get searchLabel => 'Suchen';

  @override
  String selectCount(int count) {
    return 'Auswählen ($count)';
  }

  @override
  String get selectDateTime => 'Datum & Uhrzeit auswählen';

  @override
  String get presetsRelativeToNow => 'Vorgaben (relativ zu Jetzt)';

  @override
  String get selectVersionsToCompare => 'Versionen zum Vergleichen auswählen';

  @override
  String get unknownError => 'Unbekannter Fehler';

  @override
  String get unreadableStoredData => 'Nicht lesbare gespeicherte Daten';

  @override
  String get tombstoneValueNull => 'TOMBSTONE (Wert ist NULL)';

  @override
  String lagChangeDelta(String delta) {
    return 'Änderung: $delta';
  }

  @override
  String ofTotal(String total) {
    return 'von $total';
  }

  @override
  String get activeStable => 'Aktiv / Stabil';

  @override
  String idleEmptyCount(String count) {
    return '$count Inaktiv/Leer';
  }

  @override
  String get activeQueries => 'Aktive Abfragen';

  @override
  String queueCount(int count) {
    return 'Warteschlange: $count';
  }

  @override
  String get connectingToCluster =>
      'Verbindung zum Cluster wird hergestellt...';

  @override
  String get establishingConnectionOffsets =>
      'Verbindung zum Cluster wird hergestellt und Offsets werden berechnet...';

  @override
  String get selectClusterForConsumerLag =>
      'Wähle oben ein Cluster aus, um den Consumer-Lag anzuzeigen.';

  @override
  String loadedConsumerGroupsSummary(String count, String seconds) {
    return 'Erfolgreich $count Consumer-Gruppen in ${seconds}s geladen.';
  }

  @override
  String get groupIdCol => 'Gruppen-ID';

  @override
  String get stateCol => 'Status';

  @override
  String get protocolCol => 'Protokoll';

  @override
  String get consumersCol => 'Consumers';

  @override
  String get processedCol => 'Abarbeitung';

  @override
  String get noActivePartitionAssignments =>
      'Keine aktiven Partitionen gefunden.';

  @override
  String noMessageAtOrAfterOffset(String offset) {
    return 'Keine Nachricht am oder nach Offset $offset gefunden';
  }

  @override
  String get viewMessageAtOffset => 'Message am Offset anzeigen';

  @override
  String errorWithMessage(String error) {
    return 'Fehler: $error';
  }

  @override
  String get stateAll => 'Alle';

  @override
  String get stateStable => 'Stabil';

  @override
  String get stateEmpty => 'Leer';

  @override
  String get stateDead => 'Tot';

  @override
  String get refreshIntervalLabel => 'Intervall';

  @override
  String get refreshOff => 'Aus';

  @override
  String get scriptName => 'Skriptname';

  @override
  String get sourceCol => 'Quelle';

  @override
  String get newVariableName => 'Neuer Variablenname';

  @override
  String extractedVars(String vars) {
    return 'Extrahiert: $vars';
  }

  @override
  String usedVars(String vars) {
    return 'Verwendet: $vars';
  }

  @override
  String get stepNameLabel => 'Schrittname';

  @override
  String get valueExtractions => 'Wertextraktionen';

  @override
  String get noExtractionsDefined => 'Keine Extraktionen definiert';

  @override
  String get insertVariable => 'Variable einfügen';

  @override
  String get deleteExtraction => 'Extraktion löschen';

  @override
  String filterByParameter(String parameter) {
    return 'Filtern nach $parameter';
  }

  @override
  String get searchValues => 'Werte suchen';

  @override
  String get selectAllMatches => 'Alle Treffer auswählen';

  @override
  String get clearSelection => 'Auswahl aufheben';

  @override
  String get copyValue => 'Wert kopieren';

  @override
  String copiedValueToClipboard(String value) {
    return '\'$value\' in die Zwischenablage kopiert';
  }

  @override
  String applyWithCount(int count) {
    return 'Anwenden ($count)';
  }

  @override
  String get noScriptsAvailable => 'Keine Skripte verfügbar';

  @override
  String get executionProgress => 'Ausführungsfortschritt';

  @override
  String get runningEllipsis => 'Läuft...';

  @override
  String get backTooltip => 'Zurück';

  @override
  String get failedToLoadDetails => 'Details konnten nicht geladen werden';

  @override
  String get defaultLabel => 'Standard';

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
    return 'Gestartet: $time';
  }

  @override
  String finishedAt(String time) {
    return 'Beendet: $time';
  }

  @override
  String totalRuntime(String duration) {
    return 'Gesamtlaufzeit: $duration';
  }

  @override
  String get runHistory => 'Laufverlauf';

  @override
  String get importRunArchive => 'Laufarchiv importieren';

  @override
  String matchedAnalyzed(int matched, int analyzed) {
    return '$matched Treffer / $analyzed analysiert';
  }

  @override
  String get loadResults => 'Ergebnisse laden';

  @override
  String get runAgain => 'Erneut ausführen';

  @override
  String get exportRunArchive => 'Laufarchiv exportieren';

  @override
  String get deleteRun => 'Lauf löschen';

  @override
  String get deleteRunResultTitle => 'Laufergebnis löschen';

  @override
  String get deleteRunResultConfirm =>
      'Möchten Sie dieses Laufergebnis wirklich löschen? Dies kann nicht rückgängig gemacht werden.';

  @override
  String failedToDeleteRun(String error) {
    return 'Fehler beim Löschen des Laufs: $error';
  }

  @override
  String noSchemaFieldsMatching(String query) {
    return 'Keine Schemafelder passend zu \'$query\' gefunden';
  }

  @override
  String get noSchemasForScriptTopics =>
      'Keine Schemas für die Topics des aktuellen Skripts gefunden.';

  @override
  String fieldLabel(String field) {
    return 'Feld: $field';
  }

  @override
  String foundTimesAcrossTopics(int count, int topics) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal',
      one: '1-mal',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topics,
      locale: localeName,
      other: '$topics Topics',
      one: '1 Topic',
    );
    return '$_temp0 in $_temp1 gefunden';
  }

  @override
  String get copyMarkdown => 'Markdown kopieren';

  @override
  String copiedSchemaToClipboard(String field) {
    return 'Schema für $field in die Zwischenablage kopiert.';
  }

  @override
  String get downloadMarkdown => 'Markdown herunterladen';

  @override
  String get savedSchemaToFile => 'Schema in Datei gespeichert';

  @override
  String foundInTopic(String topic) {
    return 'Gefunden in Topic: $topic';
  }

  @override
  String pathLabel(String path) {
    return 'Pfad: $path';
  }

  @override
  String get foundInMultipleLocations =>
      'An mehreren Stellen gefunden (Unterschiede hervorgehoben):';

  @override
  String baselineTopic(String topic) {
    return 'Basis-Topic: $topic';
  }

  @override
  String comparedToTopic(String topic) {
    return 'Verglichen mit Topic: $topic';
  }

  @override
  String get noDifferencesFromBaseline => 'Keine Unterschiede zur Basis.';

  @override
  String get stepStatusPending => 'AUSSTEHEND';

  @override
  String get stepStatusRunning => 'LÄUFT';

  @override
  String get stepStatusCompleted => 'ABGESCHLOSSEN';

  @override
  String get stepStatusFailed => 'FEHLGESCHLAGEN';

  @override
  String remainingCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted verbleibend',
      one: '$formatted verbleibend',
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
      other:
          '$formattedMatches Treffer gefunden ($formattedScanned durchsucht)',
      one: '$formattedMatches Treffer gefunden ($formattedScanned durchsucht)',
    );
    return '$_temp0';
  }

  @override
  String matchesFoundInTopics(int matches, int topics) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches Treffer',
      one: '1 Treffer',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topics,
      locale: localeName,
      other: '$topics Topics',
      one: '1 Topic',
    );
    return '$_temp0 in $_temp1 gefunden';
  }

  @override
  String msgsCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted Nachr.',
      one: '$formatted Nachr.',
    );
    return '$_temp0';
  }

  @override
  String msgsPerSecCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted Nachr./Sek.',
      one: '$formatted Nachr./Sek.',
    );
    return '$_temp0';
  }

  @override
  String get emptyAngleBracket => '<leer>';

  @override
  String partitionOffsetSummary(int partition, int offset) {
    return 'Partition $partition • Offset $offset';
  }

  @override
  String get noStructuredFieldsDetected =>
      'Keine strukturierten Felder erkannt';

  @override
  String get noScalarValuesForField =>
      'Keine skalaren Werte für dieses Feld erfasst';

  @override
  String peakHourSummary(String hour, String count, String percentage) {
    return 'Spitze: $hour:00 UTC ($count Nachr. • $percentage %)';
  }

  @override
  String hourlyTooltipSummary(String hour, String count, String percentage) {
    return '$hour:00 - $hour:59 UTC\n$count Nachr. ($percentage %)';
  }

  @override
  String get noKeyedMessagesFound => 'Keine Nachrichten mit Key gefunden';

  @override
  String get noContentTypesRecorded => 'Keine Inhaltstypen erfasst';

  @override
  String partitionLabel(int partition) {
    return 'Partition $partition';
  }

  @override
  String partitionStatsLine(String count, String percentage, String size) {
    return '$count Nachr. ($percentage %) • $size';
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
      other: '$duration • $partitions Partitionen',
      one: '$duration • 1 Partition',
    );
    return '$_temp0';
  }

  @override
  String analyzingTopicProgress(
    String scanned,
    String total,
    String percentage,
  ) {
    return 'Topic wird analysiert... ($scanned / $total Nachrichten • $percentage %)';
  }

  @override
  String get keyLabelWithColon => 'Key: ';

  @override
  String get refreshTooltip => 'Aktualisieren';

  @override
  String get editVariableTooltip => 'Variable bearbeiten';

  @override
  String get deleteVariableTooltip => 'Variable löschen';

  @override
  String get addVariableTooltip => 'Variable hinzufügen';

  @override
  String get editStepTooltip => 'Schritt bearbeiten';

  @override
  String get deleteStepTooltip => 'Schritt löschen';

  @override
  String get browseDirectoryTooltip => 'Ordner auswählen';

  @override
  String get expandTooltip => 'Aufklappen';

  @override
  String get collapseTooltip => 'Zuklappen';

  @override
  String get selectStepTooltip => 'Alle Topics im Schritt auswählen';

  @override
  String get deselectStepTooltip => 'Alle Topics im Schritt abwählen';

  @override
  String filterColumnTooltip(String column) {
    return '$column filtern';
  }

  @override
  String get removeColumnTooltip => 'Spalte entfernen';

  @override
  String get compositeBadgeTooltip => 'Verschachtelte Felder anzeigen';

  @override
  String get skewedLabel => 'Ungleich';

  @override
  String get copy => 'Kopieren';

  @override
  String get copyFailed => 'Kopieren fehlgeschlagen';
}
