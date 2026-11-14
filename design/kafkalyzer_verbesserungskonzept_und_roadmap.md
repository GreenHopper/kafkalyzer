# kafkalyzer — Verbesserungskonzept, Zielarchitektur & Roadmap

Stand: Review gegen Quelltext auf `56895f4` (`lib/src`, `rust/`, `openspec/specs`, `.github/workflows/build.yml`).
Zweite Runde: Code-Review der gesamten Codebasis aus UI/UX- und Funktionssicht; Ergebnisse in §2.4 und als Changes
5.21–5.39.

Dieses Dokument **ersetzt** die beiden Entwürfe `kafkalyzer_ui_ux_feature_konzept.md` und
`kafkalyzer_hybrid_architektur_projektstruktur.md`. Beide wurden zusammengeführt, weil ihre Roadmaps sich gegenseitig
bedingen (Filter, Diff und Profilablage werden von UI, MCP und Server gemeinsam gebraucht) und weil ein Großteil der
dort geforderten Funktionen bereits umgesetzt ist.

Verwandte Dokumente, die gültig bleiben und hier nur referenziert werden:
`feature-gap-analysis.md` (Ist-Inventar, Nicht-Empfehlungen), `mcp-server-feasibility.md` (MCP-Entscheidung, Blocker,
Sicherheits-Pflichtset), `mcp-server-api-design.md` (Tool-Katalog; mit den in `mcp-server-feasibility.md` §1
dokumentierten Fehlern).

---

## 0. Verwendung für OpenSpec

- Jeder Eintrag in §5 ist **ein OpenSpec-Change** mit fester Change-ID (kebab-case). Aufruf später z. B.:
  `/opsx:propose <change-id>` mit Verweis auf den jeweiligen Abschnitt dieses Dokuments.
- Pro Change sind angegeben: Warum, betroffene Capabilities (**NEU** = neuer Spec-Ordner, **MOD** = Delta auf einen
  existierenden Spec unter `openspec/specs/`), Kernanforderungen als prüfbare SHALL-Aussagen, betroffene Schichten in
  der Reihenfolge aus `openspec/config.yaml` (Rust-Crates → Bridge → Dart), Abhängigkeiten und Nicht-Ziele.
- Die Anforderungen sind Vorlagen für die Spec-Deltas, keine fertigen Specs. Szenarien (WHEN/THEN) entstehen im Change.
- Aufwand ist grob klassifiziert: **S** ≤ 1 Tag, **M** 2–4 Tage, **L** ≥ 1 Woche. Nicht gemessen, nur geschätzt.
- Einträge in §2.1 dürfen **nicht** erneut spezifiziert werden; sie existieren bereits als Spec.
- Abschnittsnummern in §5 sind **stabile Kennungen**, keine Reihenfolge. Die Reihenfolge legt §6 fest.

---

## 1. Verbindliche Leitplanken

Diese Regeln gelten für jeden Change in diesem Dokument. Sie stammen aus `openspec/config.yaml` und den bestehenden
Specs und werden hier nicht neu erfunden.

| # | Leitplanke | Quelle |
|---|---|---|
| L1 | **Read-only.** Kein Produce/Replay, kein Offset-Commit/-Reset, kein `subscribe()`, kein Topic-/Config-/ACL-Schreibzugriff, keine schreibenden Schema-Registry-Aufrufe. Gilt für GUI, CLI, MCP und Server gleichermaßen. | `read-only-invariants-enforcement`, `read-only-security-guidance` |
| L2 | **Crate-Schichtung.** `kafkalyzer-core` = reine Berechnung (kein rdkafka, kein Netzwerk, kein frb). `kafkalyzer-kafka` = einziger Ort für rdkafka/OpenSSL/reqwest. `rust_lib_kafkalyzer` (`rust/src`) = einziger Ort für `flutter_rust_bridge`. | `openspec/config.yaml` |
| L3 | **Bridge-DTOs** werden im Bridge-Crate unter `rust/src/api/` definiert und an der Grenze auf Domain-Typen gemappt. Bestehende Rust↔Dart-Signaturen bleiben abwärtskompatibel. | `openspec/config.yaml` |
| L4 | **Hot-Path-Regeln.** Keine Regex-/Ausdrucks-Kompilierung, kein `block_on`, kein Netzwerk-RPC im Poll-Loop; Streams nach Dart gebatcht (50–100 ms); `PartitionEOF` statt Offset-Arithmetik als Ende-Signal. | `openspec/config.yaml`, `topic-consumption` |
| L5 | **UI.** `package:material_ui/material_ui.dart`, alle Texte über `AppLocalizations` (en + de), sichtbares Feedback für jede asynchrone Aktion, Fehler als SnackBar/Dialog. | `openspec/config.yaml` |
| L6 | **Navigation.** Die Rail hat genau Explorer, Consumer Lag, Scripts, Settings. Es gibt keine eigene „Multi-Search“-Destination. | `main-navigation` |
| L7 | **Ein Pfad-Dialekt.** Feldpfade werden ausschließlich über `kafkalyzer_core::json_path` aufgelöst (Dot, `[n]`, `$.`, JSON Pointer; keine Wildcards, keine Filterausdrücke im Pfad). | `json-path-resolution` |

---

## 2. Review-Ergebnis: Korrekturen an den beiden Entwürfen

### 2.1 Bereits umgesetzt — nicht erneut spezifizieren

| Forderung im Entwurf | Bereits vorhanden als | Verbleibender Rest |
|---|---|---|
| Virtualisierter Lazy-Loading-Tree für große Payloads | `smart-virtual-json-tree` (virtualisiert, Context-Windowing für Arrays) | Nur Roh-/Hex-Ansicht kappt noch bei 500 000 Zeichen (`json_or_string_viewer.dart:213`, `hex_viewer.dart`) → Change `chunked-raw-and-hex-viewer` |
| „Als Tabellenspalte anpinnen“ | `message-table-columns`, `smart-virtual-json-tree` (Pin Field to Table Columns) | keiner |
| Gespeicherte Suchprofile | `saved-topic-searches` (bewusst pro Cluster **und** Topic gescoped) | keiner; Topic-Kombinationen sind Scripts |
| Schema-Versions-Diff, Kompatibilitätscheck | `schema-evolution-workflows` | keiner |
| Partition-Skew / Hot Partition | `topic-content-analysis` (Partition Utilization and Balance, scanbasiert und exakt) | Schneller Schätzwert ohne Scan → Change `partition-offset-distribution` |
| Lag-Sparklines, Warnschwelle | `consumer-lag-trend` | Schwelle markiert nur; keine Benachrichtigung → Change `lag-stall-detection-and-alerts` |
| Time-to-Catch-Up-Prognose | `consumer-lag-monitoring` (Processing Rate and Backlog Estimate) | keiner |
| Poison-Pill-Nachricht am Consumer-Offset öffnen | `consumer-lag-messages-view` | Geführter Vergleich fehlt → Change `poison-pill-compare` |
| OS-Keychain für Secrets, Schloss-Icon | `secure-credentials-storage` | Export ist nur „ohne Secrets“ oder „Klartext mit Warnung“ → Change `encrypted-profile-export` |
| Verbindungstest im Profil-Editor | `ergonomic-settings-and-cluster-onboarding` (Live Broker Connection Test), `cluster-connection-progress` | Test liefert nur Erfolg/Fehlertext (`validate_connection`), keine Stufen → Change `connection-diagnostics` |
| Visueller Step-Pipeline-Builder | `modernized-script-and-step-editor`, `ergonomic-script-workspace` (Pipeline Preview) | keiner |
| Cargo Workspace statt Einzel-Crate | existiert: `rust/Cargo.toml` mit `.`, `kafkalyzer-core`, `kafkalyzer-kafka` | nur neue Mitglieder ergänzen |
| `check_read_only.sh` + CI-Gate | `read-only-invariants-enforcement`, Job `read-only-gate` in `build.yml` | Lücken, siehe §2.3 Nr. 1 → Change `harden-read-only-gate` |
| Windows-CA-Bundle | `windows-ci` (Release-Paket enthält `cacert.pem`) | Nur Debug-/Lokalläufe betroffen; Ursache ungeklärt → Spike in `connection-diagnostics` |
| Headless-Script-Ausführung | `headless-script-execution` (`bin/kafkalyzer_script.dart`, Dart) | keiner |

Folge: Die Priorisierungs-Matrix des UI-Entwurfs ist zu etwa der Hälfte gegenstandslos (Custom Columns, Tree-Viewer,
OS-Keychain, Schema-Diff). §6 ersetzt sie.

### 2.2 Sachliche Fehler

| Aussage im Entwurf | Tatsächlich | Konsequenz |
|---|---|---|
| „monolithischer `rust/`-Ordner“, Umzug nach `rust/crates/*` | Workspace existiert. Das Bridge-Crate heißt `rust_lib_kafkalyzer`, liegt in `rust/` und ist über `rust_builder` (Cargokit), `pubspec.yaml` und `flutter_rust_bridge.yaml` (`rust_root: rust/`) verdrahtet. | Kein Umzug, keine Umbenennung (Entscheidung E2). Reines Risiko ohne Nutzen. |
| `kafkalyzer-core` enthält rdkafka, Schema-Registry-Client, Scripting-Engine | Core ist bewusst I/O-frei; rdkafka liegt in `kafkalyzer-kafka`. Die Scripting-Engine ist Dart (`script_runner.dart`), nicht Rust. | Entwurf widerspricht L2. Schichtung bleibt. |
| `lib/core/backend/`, `lib/features/{cluster_profiles,message_viewer,multi_search,topic_explorer,…}` | Code liegt unter `lib/src/features/{cluster,consumer,explorer,navigation,schema,scripting,search,settings,topic}` und `lib/src/services/`. | Zielstruktur in §4.1 nutzt die echten Pfade. |
| Typen `TopicSummary`, `DecodedMessage`, `LagReport`, Parameter `clusterId` | Typen heißen `TopicMetadata`, `KafkaMessage`, `ConsumerGroupLag`; die API ist zustandslos und nimmt je Aufruf ein `ClusterProfile`. | Abstraktion bleibt profilbasiert (§4.4). |
| Workflows `ci.yml`, `release-desktop.yml` | Es gibt genau `build.yml`. | Datei bleibt; Container-Job kommt erst mit dem Server dazu. |
| Verzeichnisse `.agent`, `.cline`, `.clinerules`, `.cursor`, `.pi` konsolidieren nach `openspec/` | Vorhanden sind nur `.agents/skills` und `.continue/skills` — beides von OpenSpec generierte Skill-Kopien. `openspec/` enthält Specs, keine Agent-Konfiguration. | Vorschlag entfällt ersatzlos. |
| Hash-Badge „`murmur2` oder `crc32`“ | Implementiert ist nur Murmur2 (Java-Default-Partitioner). | Badge muss die Annahme nennen (§5, `fast-trace-partition-preview`). |
| Skew „anhand der bereits abgerufenen Watermarks“ | Topic-Liste und `PartitionRow` enthalten keine Watermarks. Zudem ist `high − low` bei kompaktierten/transaktionalen Topics keine Nachrichtenanzahl (siehe L4). | Neuer Abruf nötig, Ergebnis als Schätzung kennzeichnen. |
| Config-Diff: „Backend unterstützt bereits `describe_configs`“ | Intern ja, aber nur `cleanup.policy` und `retention.ms` werden extrahiert. Es gibt keine Bridge-Funktion für die vollständige Config-Liste und keine Broker-Configs. | Neue Kernfunktion + Bridge-API nötig. |
| Schema-ID „im Header/Magic-Byte“ | Sie steht im Confluent-Wire-Präfix der **Payload** (Magic-Byte + 4 Byte ID), nicht in Kafka-Headern; bereits ausgewertet (`message-schema-provenance`). | `poison-pill-compare` nutzt die vorhandene Provenienz. |
| „Regex-Filter auf Keys, Values und Headern“ (auch im README) | `SearchScope` kennt nur `Key`, `Value`, `Both`. Broker-Scan filtert keine Header. | Header-Scope ist Voraussetzung für Trace-Verfolgung → Teil von `structured-message-filter`. README korrigieren. |
| Ist-Zustand „Multi-Search“ als eigene Ansicht | Die Destination wurde entfernt (L6); Mehr-Topic-Suche läuft über Scripts und den geteilten `MultiSearchController`. | Kein neuer Multi-Search-Einstieg. README-Abschnitt anpassen. |
| MCP-Pfade `/mcp/sse` und `/mcp/message` | Das ist der abgelöste HTTP+SSE-Transport. Aktuell ist Streamable HTTP mit einem Endpunkt (`/mcp`). | Nur relevant für den Server (§4.3). |

### 2.3 Konzeptfehler und funktionale Lücken

1. **„Mathematisch garantiert read-only“ stimmt nicht.** Das Gate ist ein Grep. Es prüft Producer-Typen, Commits,
   `subscribe`, Auto-Commit und `.send(`. Es prüft **nicht**: schreibende `AdminClient`-Aufrufe (`create_topics`,
   `delete_topics`, `create_partitions`, `alter_configs`, `delete_records`, `delete_groups`) — obwohl `AdminClient`
   im Code verwendet wird (`kafka_metadata.rs:71`, `kafka_analyzer.rs:1092`) —, schreibende Schema-Registry-Aufrufe
   (aktuell genau ein `POST`, auf `/compatibility`, per Kommentar ausgenommen) und die Regel „rdkafka nur in einem
   Crate“. → `harden-read-only-gate`.
2. **Drei Abfragesprachen genannt, keine gewählt** (JSONPath, JMESPath, CEL). Filterausdrücke im Pfad widersprechen L7.
   Unklar blieb auch, dass strukturierte Filter die Dekodierung **vor** dem Filter erzwingen (Kosten im Hot Path).
   → Entscheidung E5, Change `structured-message-filter`.
3. **Trace-Verfolgung ohne Kostenmodell.** Kafka hat keinen Index. „1 Klick über alle Topics“ ist ein Vollscan über
   N Topics. Ohne Topic-Auswahl, Zeitfenster und Limit ist das an Produktiv-Clustern nicht vertretbar. Fast Trace
   hilft nur, wenn die Korrelations-ID der Key ist. → `cross-topic-trace` mit Pflichtgrenzen.
4. **Poison-Pill-Vergleich nimmt lückenlose Offsets an.** Der committete Offset `O_c` ist die **nächste zu lesende**
   Nachricht. `O_c − 1` existiert oft nicht (Kompaktierung, Transaktionsmarker, Retention). Bei `O_c` = High Watermark
   gibt es keinen Kandidaten. „Hängt“ muss aus stagnierendem Offset bei wachsendem Log-Ende folgen, nicht aus Lag
   allein. → `poison-pill-compare`.
5. **Lag-Alarme können heute nicht funktionieren.** Das Polling ist ein `Timer.periodic` im Widget-State von
   `consumer_lag_view.dart`. Verlässt der Nutzer die Ansicht, wird nicht mehr abgefragt. Alarme brauchen das Polling
   in einem Controller. Außerdem steht „Alarmierungs-Engine“ in `feature-gap-analysis.md` §5.3 als nicht empfohlen.
   → Entscheidung E7, Change `lag-stall-detection-and-alerts`.
6. **Recipe „Snapshot aller Consumer-Lags“ ist nicht baubar.** Script-Schritte sind Suchschritte auf Topics; es gibt
   keinen Lag-Schritt. → Recipes beschränken sich auf das, was die Engine kann.
7. **MCP-Modus „Desktop Embedded“ (HTTP-Listener im GUI-Prozess)** ist in `mcp-server-feasibility.md` §3 B bereits
   verworfen (Lifecycle, Absturzkopplung). Der Entwurf ergänzt eine Sicherheitslücke: ein unauthentifizierter
   Listener auf `127.0.0.1` gibt jedem lokalen Prozess Zugriff auf Produktivdaten mit den entsperrten Profilen.
   → Entscheidung E3.
8. **MCP-Modus „stdio liest Profile aus Keychain/Config“ ist nicht umsetzbar wie beschrieben.** Profile liegen in
   `shared_preferences` (macOS: plist), Secrets seit `secure-credentials-storage` in `flutter_secure_storage`, dessen
   Ablageformat je Plattform plugin-spezifisch ist. Ein Rust-Binary kann das nicht portabel lesen. → Entscheidung E4.
9. **MCP-Pflichtset fehlt komplett:** Payload-Kappung, Ergebnis-Limits, Scan-Timeout, Verbot von `run_forever`,
   Cluster-Allowlist, Redaction, Hinweis auf Datenabfluss an LLM-Anbieter (`mcp-server-feasibility.md` §4/§5).
   Die Tool-Namen weichen grundlos vom bestehenden Katalog ab; `run_diagnostic_script` setzt eine Rust-Engine voraus,
   die es nicht gibt (Entscheidung E10).
10. **Server-Konzept ohne Betriebs- und Sicherheitsmodell.** Es fehlen: Autorisierung (der Server agiert mit *einem*
    Kafka-Account → jeder Nutzer erbt dessen ACLs), Audit-Log, Limits pro Nutzer (parallele Scans, Speicher),
    Abbruch/Backpressure für Streams, API-Versionierung zwischen automatisch aktualisierter Desktop-App und Server,
    Verbleib von Scripts/Saved Searches/Exports (bleiben lokal). „gRPC oder HTTP/WebSocket“ blieb offen. Zudem
    widerspricht der Server der bisherigen Entscheidung „kein Team-Server“ (`feature-gap-analysis.md` §5.3).
    → Entscheidung E8 (nicht eingeplant).
11. **Flutter-Web als Nebenbemerkung** ist nicht tragfähig: `flutter_rust_bridge` per FFI, `dart:io`,
    `flutter_secure_storage`, Velopack und Dateisystem-Exporte sind desktop-gebunden. → Nicht-Ziel.
12. **Transport-Abstraktion unterschätzt.** 22 Dart-Dateien rufen Bridge-Funktionen direkt auf, 69 importieren
    generierte Bridge-Typen. Diese Typen haben kein `fromJson`. Ein Remote-Backend braucht also JSON-Mapping für alle
    DTOs. Das ist der eigentliche Aufwand, nicht das Interface. → `backend-abstraction` als eigener, verhaltensneutraler
    Change vor jedem Remote-Code.
13. **Eigenes Kryptoformat für `.kafkalyzer-vault`.** Ein selbst entworfener Container (KDF-Parameter, Nonce,
    Versionierung) ist eine vermeidbare Fehlerquelle. → Entscheidung E6.
14. **Command Palette `Strg+K`.** `K` ist in `messages_view.dart` bereits als Navigationstaste belegt (ohne
    Modifier). Kollisionen mit Textfeldern gab es schon einmal (`fix-search-input-shortcut-conflict`). → Im Change
    explizit prüfen.

### 2.4 Befunde aus dem Code-Review

Kennzeichnung: **✔** = von mir an der genannten Stelle im Code nachgeprüft; **◦** = aus der Code-Lektüre eines
Review-Durchlaufs übernommen, Stelle nicht einzeln nachgeprüft. Nichts davon wurde zur Laufzeit ausgeführt.

**A. Sicherheit und Datenverlust — vor allen neuen Funktionen**

| # | Befund | Beleg | Change |
|---|---|---|---|
| A1 ✔ | **TLS-Zertifikatsprüfung ist für jede Verbindung abgeschaltet.** `create_config` setzt bedingungslos `ssl.endpoint.identification.algorithm=none` und `enable.ssl.certificate.verification=false`, kommentiert als „TEMPORARY DEBUG“ / „BYPASS“. Ein konfigurierter Truststore schützt damit nicht; die Oberfläche zeigt das nirgends. | `kafka_utils.rs:165-168` | 5.21 |
| A2 ✔ | **Zip-Slip in drei Importern.** Archiv-Einträge werden mit ihrem Namen ungeprüft unter das Zielverzeichnis geschrieben; `../` verlässt es. | `cluster_list_controller.dart:73-77`, `settings_service.dart:238-244`, `script_runner.dart:760` | 5.22 |
| A3 ✔ | **Defekter Speicher sieht aus wie „leer“ und wird beim nächsten Speichern überschrieben.** Profile und Scripts: jeder Parse-Fehler liefert `[]`. | `cluster_service.dart:73-76`, `script_repository.dart:16-19` | 5.22 |
| A4 ✔ | **Schlüsselbund-Ausfall fällt still auf Arbeitsspeicher zurück.** Passwörter sind nach dem Neustart weg, ohne Hinweis. ◦ Bei der Einmal-Migration werden Klartext-Secrets danach trotzdem aus den Preferences entfernt. | `secure_storage_service.dart:29-61`, `cluster_service.dart:38-70` | 5.22 |
| A5 ✔ | **Fest einkodierter Dateiname eines GCS-Schlüssels** wird in Konfigurations-Exporte gepackt, falls die Datei existiert. | `settings_service.dart:17,152-156` | 5.22 |
| A6 ✔ | **Rust-Debug-Log im Temp-Verzeichnis** wächst unbegrenzt und enthält Bootstrap-Adresse und Dateipfade; jeder `create_config`-Aufruf hängt an. | `kafka_utils.rs:153-160,325` | 5.25 |
| A8 ✔ | **DLQ-Karte kopiert einen fertigen `kcat … -P`-Producer-Befehl** („Copy kcat Replay Command“), der die Nachricht ins Original-Topic zurückschreibt — widerspricht L1. Entscheidung: entfernen, stattdessen „Fehlgeschlagene Nachricht kopieren“. | `dlq_topic_detector.dart:32-52`, `dlq_failure_diagnostics_card.dart` | 5.40 |
| A7 ◦ | Profilname ist Schlüssel für Secrets und Sitzung, wird aber nicht auf Eindeutigkeit geprüft; Import ersetzt gleichnamige Profile ohne Rückfrage. | `cluster_basic_info_form.dart`, `secure_storage_service.dart:25-26` | 5.22 |

**B. Falsche oder irreführende Anzeige**

| # | Befund | Beleg | Change |
|---|---|---|---|
| B1 ✔ | **Gruppen ohne aktive Mitglieder zeigen Lag 0.** Member und damit Topics werden nur im Zustand `Stable` gelesen; eine gestoppte Gruppe (`Empty`) — der wichtigste Lag-Fall — erscheint als „kein Lag“. Partitionen ohne Commit werden verworfen. | `kafka_metadata.rs:309-314,393,525-528,576` | 5.24 |
| B2 ◦ | Sortierung nach Lag und KPI „Gesamt-Lag“ berücksichtigen nur bereits gerenderte Zeilen; nicht geladene Gruppen zählen als 0. | `consumer_lag_view.dart` | 5.24 |
| B3 ✔ | **Abgebrochener Export meldet Erfolg** — entgegen dem bestehenden Spec `downloaded-file-actions` (Save Dialog Cancellation Handling). | `messages_view.dart:871-884` | 5.23 |
| B4 ✔ | **Stream-Fehler werden verschluckt.** Broker-, Auth- oder Dekodierfehler sehen aus wie „fertig, keine Nachrichten“. ◦ Dasselbe beim Laden von Topics und Subjects. | `message_stream_controller.dart:148-162` | 5.23 |
| B5 ✔ | Kopieren eines Objekt-/Array-Knotens im Baum liefert Dart-`toString()`, kein JSON. | `smart_virtual_json_tree.dart:304` | 5.23 |
| B6 ✔ | Sortierung ohne Zweitschlüssel: Nachrichten mit gleichem Millisekunden-Zeitstempel springen zwischen Live-Aktualisierungen. | `messages_view.dart:397-409` | 5.23 |
| B7 ✔ | Unbekanntes Topic aus „Zuletzt verwendet“ bekommt erfundene Metadaten (0 Partitionen, RF 1, `delete`, Retention 0), die als Tatsache angezeigt werden. | `explorer_view.dart:675-683,709-716` | 5.33 |
| B8 ✔ | Topics, die auf `-topic` enden, gelten als „Stream-Topics“ und sind standardmäßig ausgeblendet. | `active_connection_controller.dart:88-95` | 5.33 |
| B9 ◦ | Fehlende ACLs degradieren still: Config-Tags verschwinden, nicht autorisierte Topics fehlen, die Analyse nimmt „nicht kompaktiert“ an. | `kafka_metadata.rs:98`, `kafka_analyzer.rs:1090-1108` | 5.33 |
| B10 ◦ | Schema-Anzeige nimmt überall Avro an; Protobuf- und JSON-Schema-Subjects werden als „Avro“ markiert und liefern keine Feldpfade. | `topic_detail_view.dart`, `schema_registry.rs` | 5.35 |
| B11 ✔ | Duplikat-Erkennung hält alle Fingerprints in einem unbegrenzten `HashSet` — entgegen `topic-duplicate-detection` (Bounded Memory Tracking). Vollscan ist die Voreinstellung. | `kafka_analyzer.rs:83,568` | 5.37 |
| B12 ◦ | Ein nicht auflösbarer Zeitstempel-Parameter in einem Script fällt still auf Offset 0 zurück — aus einer begrenzten Suche wird ein Vollscan. | `script_runner.dart` | 5.39 |
| B13 ◦ | Offene Tabs werden beim Speichern der Sitzung nicht nach Cluster gefiltert; Tabs von Cluster A landen in der Sitzung von Cluster B. | `active_connection_controller.dart` | 5.26 |
| B14 ◦ | `bin/kafkalyzer_script.dart` initialisiert weder Rust-Bibliothek noch Dependency Injection; lauffähig ist nur der Weg über das GUI-Binary (`main.dart:22-29`). | `bin/kafkalyzer_script.dart`, `main.dart` | 5.39 |

**C. Lücken im täglichen Arbeiten** (Details in den jeweiligen Changes)

- Nachrichten: nur Einzelauswahl, Zeilen-Kontextmenü mit einem einzigen Eintrag, Export ohne Header und ohne
  Schema-Angaben, Export-Umfang weicht von der sichtbaren Tabelle ab, Tombstone nicht von leerem Wert
  unterscheidbar, Zeit nur lokal ohne Zonenangabe, Live-Stream ohne Pause und mit unbegrenztem Puffer → 5.27–5.30.
- Explorer: Topic-Liste ohne Sortierung, Gruppierung, Favoriten; ein einziger `describe_configs` für alle Topics;
  Cluster-Übersicht ohne Broker-Angaben → 5.33, 5.34.
- Schema: kein Subject-Browser, kein Kompatibilitäts-Level, keine Offline-Schemas, Registry-Aufrufe ohne Timeout
  → 5.35, 5.36.
- Consumer Lag: kein Lag als Zeit, kein Filter nach Topic, kein „wer konsumiert dieses Topic“, kein Export → 5.38.
- Profile: kein Duplizieren, keine Umgebungskennzeichnung (PROD), keine freien librdkafka-Eigenschaften → 5.26.
- Anwendung: keine globale Fehlerbehandlung, kein sichtbares Log, Fenstergröße nicht gespeichert, keine
  Sprach-/Theme-Wahl in den Einstellungen → 5.25, 5.31, 5.32.

---

## 3. Entscheidungen

| # | Entscheidung | Status | Begründung |
|---|---|---|---|
| E1 | Ein gemeinsames Dokument mit einer Roadmap statt zwei Entwürfen. | entschieden | Gemeinsame Bausteine (Filter, Diff, Profilablage) haben mehrere Abnehmer. |
| E2 | Bestehende Crates bleiben an Ort und Namen. Neue Crates werden Geschwister unter `rust/`. | entschieden | Cargokit-/FRB-Verdrahtung, L2. |
| E3 | MCP lokal ausschließlich als eigenständiges stdio-Binary `kafkalyzer-mcp`. Kein Listener im GUI-Prozess. Die App ist nur Pflege-UI (Profile freigeben, Konfigurations-Snippet anzeigen). | entschieden | `mcp-server-feasibility.md` §3; §2.3 Nr. 7. |
| E4 | Profilquelle für headless Rust-Binaries: expliziter Export aus der App pro Cluster (= Allowlist). Nicht-geheime Felder in eine JSON-Datei, Secrets über das Rust-Crate `keyring` — geschrieben von der App via Bridge, gelesen vom Binary mit demselben Code. Für CI/Container alternativ Secret-Referenzen auf Umgebungsvariablen. | entschieden | §2.3 Nr. 8; keine Klartext-Secrets auf der Platte (kein Rückschritt hinter `secure-credentials-storage`). |
| E5 | Strukturierte Filter als eigener, kleiner Prädikat-Baum in `kafkalyzer-core`: Bedingungen `<Quelle>.<Pfad> <Operator> <Literal>`, verknüpft mit AND/OR/NOT. Pfade über L7. Kein CEL, kein JMESPath, keine JSONPath-Filterausdrücke. | entschieden | Der visuelle Builder braucht ohnehin genau dieses Datenmodell; der Textmodus ist dessen Serialisierung. Eine Fremdsprache brächte Typ-Mapping für Avro/Protobuf und eine zweite Pfadsyntax. |
| E6 | Verschlüsselter Profil-Export im `age`-Passphrase-Format (Rust-Crate `age`: scrypt + ChaCha20-Poly1305) statt eigenem AES-GCM/Argon2-Container. | entschieden | Standardformat, mit der `age`-CLI entschlüsselbar, kein Eigenbau. Bau des Crates auf allen drei Plattformen ist im Change zu prüfen. |
| E7 | Lag-Alarme nur innerhalb der laufenden Sitzung: kein Hintergrunddienst, keine Persistenz, keine Zeitreihen. Nur In-App-Hinweise; native OS-Benachrichtigungen sind Nicht-Ziel. | entschieden | Hält die Nicht-Empfehlung aus `feature-gap-analysis.md` §5.3 ein. OS-Benachrichtigung bräuchte ein neues Plugin für drei Plattformen. |
| E8 | Remote-Server (`kafkalyzer-server`, Container/Kubernetes) wird **nicht** eingeplant. Damit entfallen auch Backend-Naht (5.18) und Remote-Profile (5.20). Die Beschreibung bleibt als zurückgestellter Anhang in §5 erhalten. | entschieden | Kein Bedarfsträger; hält die Festlegung „kein Team-Server“ aus `feature-gap-analysis.md` §5.3; §2.3 Nr. 10. |
| E9 | Nur für den Fall, dass E8 später revidiert wird: HTTP/JSON mit `axum`, Streams als NDJSON über die HTTP-Antwort (Abbruch = Verbindung schließen), MCP als Streamable HTTP unter `/mcp`. Kein gRPC. | vorgemerkt | Domain-Typen sind bereits `serde`-fähig; gRPC brächte einen dritten DTO-Satz plus Codegen in Rust und Dart. |
| E10 | MCP-Tools heißen `kafka_*` wie in `mcp-server-api-design.md`. Kein Script-/Pipeline-Tool, solange die Engine Dart ist. Mehr-Topic-Suche ist eine Schleife im Handler über `consume_with_filter`. | entschieden | Ein Katalog; `mcp-server-feasibility.md` §2.3/§9.4. |
| E11 | Struktureller JSON-Diff wandert nach `kafkalyzer-core`; View-Zustand und Text-Diff bleiben Dart. | entschieden | Drei Abnehmer (Diff-Ansicht mit Ignorierliste, Poison-Pill-Vergleich, MCP); entfernt die Git-Abhängigkeit `json_diff`. |
| E12 | Flutter-Web ist kein Ziel. | entschieden | §2.3 Nr. 11. |
| E13 | TLS-Zertifikats- und Hostnamenprüfung ist Standard. Abschalten nur je Profil, ausdrücklich, mit sichtbarem „unsicher“-Kennzeichen. Beim ersten Start nach dem Upgrade testet die App jedes bestehende TLS-Profil **mit** Prüfung: gelingt der Test, ist die Prüfung für dieses Profil ab sofort an; scheitert er, fragt ein Übergangsdialog je Profil, ob die Prüfung ausgeschaltet bleiben soll (dann mit „unsicher“-Kennzeichen). | entschieden | A1. Kein stiller Bruch in Umgebungen ohne verteilte Root-CA und keine stille Fortsetzung des unsicheren Zustands. |
| E14 | Befunde der Gruppen A und B (§2.4) werden vor neuen Funktionen behoben. | entschieden | Ein Analysewerkzeug, das Lag 0 für eine stehende Gruppe zeigt oder Fehler als „keine Daten“ darstellt, führt zu falschen Diagnosen. |
| E15 | Freie librdkafka-Eigenschaften je Profil nur über eine **Positivliste** (Timeouts, `client.id`, Adressfamilie, Fetch-/Socket-Parameter, Debug-Kontexte). Keine Denylist. | entschieden | L1: Eine Denylist müsste jede schreib- oder gruppenrelevante Eigenschaft kennen; eine Positivliste ist prüfbar. |
| E16 | Subject-Browser und Cluster-Übersicht leben im Explorer. Keine fünfte Navigations-Destination. | entschieden | L6. |
| E17 | Lag-Verlauf bleibt sitzungsgebunden und wird nicht auf Platte geschrieben. | entschieden | Konsistent mit E7. Ein Momentaufnahme-Export (5.38) deckt den Weitergabe-Bedarf. |
| E18 | Der lokale MCP-Server (Phase 4) wird gebaut. Jedes Profil muss einzeln freigegeben werden; Produktiv-Cluster sind nicht ausgeschlossen. Pflichtset aus §4.3 gilt ohne Ausnahme. | entschieden | Früheres Gate G1. Die Freigabe je Cluster ist die Allowlist; die Verantwortung für den Datenabfluss liegt sichtbar beim freigebenden Nutzer. |
| E19 | Der einzige Headless-Einstieg für Scripts ist das GUI-Binary (`kafkalyzer --script …`). `bin/kafkalyzer_script.dart` wird entfernt. | entschieden | B14: Die Datei initialisiert nichts und ist nicht lauffähig. |
| E20 | Voreinstellung der Topic-Analyse bleibt der Vollscan. Oberhalb einer Schwelle erscheint vor dem Start eine Rückfrage mit geschätztem Umfang. | entschieden | Kein Verhaltensbruch für bestehende Nutzer; die Rückfrage schützt große Topics. |

---

## 4. Zielarchitektur

### 4.1 Verzeichnisstruktur (Ist + Ergänzungen)

```text
kafkalyzer/
├── .github/workflows/build.yml      # bleibt; + Paketierung kafkalyzer-mcp (Phase 4)
├── bin/kafkalyzer_script.dart       # wird entfernt (E19)
├── design/
├── docker-compose.yaml              # besteht: lokaler Kafka-Stack für Integrationstests
├── lib/src/
│   ├── features/
│   │   ├── cluster/                 # + Diagnose, verschlüsselter Export, MCP-Freigabe, [Remote-Profiltyp]
│   │   ├── consumer/                # + Lag-Monitor-Controller, Stillstandserkennung, Poison-Pill-Vergleich
│   │   ├── explorer/  navigation/   # + Command Palette (navigation)
│   │   ├── schema/  scripting/      # + Recipes, Run-Vergleich (scripting)
│   │   ├── search/                  # + Filter-Builder, Trace-Verfolgung
│   │   ├── settings/  topic/        # + Config-Ansicht/-Diff, Offset-Verteilung (topic)
│   ├── rust/                        # generiert (flutter_rust_bridge)
│   ├── services/                    # besteht: kafka_metadata_service, schema_registry_service, …
│   └── ui/                          # + Chunked Raw/Hex-Viewer, Diff-Ignorierliste, Swimlane-Timeline
├── openspec/                        # Specs und Changes — keine Agent-Konfiguration
├── rust/
│   ├── Cargo.toml                   # Workspace + Bridge-Crate rust_lib_kafkalyzer (unverändert)
│   ├── src/api/                     # Bridge-DTOs und -Funktionen
│   ├── kafkalyzer-core/             # + filter_expr, json_diff, connection_error_class, offset_distribution
│   ├── kafkalyzer-kafka/            # + topic/broker configs, Diagnose-Sonden, Header-Scope
│   ├── kafkalyzer-profiles/         # NEU (Phase 4): Profil-Export lesen/schreiben, keyring
│   └── kafkalyzer-mcp/              # NEU (Phase 4): lib (begrenzte Handler) + bin (stdio)
├── rust_builder/                    # unverändert
└── scripts/check_read_only.sh       # erweitert (Phase 0)
```

### 4.2 Abhängigkeitsregeln der Crates

```text
kafkalyzer-core        ← keine internen Abhängigkeiten; kein rdkafka/reqwest/tokio-net/frb
kafkalyzer-kafka       ← core                         (einziger rdkafka-/reqwest-Nutzer)
kafkalyzer-profiles    ← core                         (serde, keyring; kein rdkafka)
rust_lib_kafkalyzer    ← core, kafka, profiles        (einziger frb-Nutzer; keine MCP-/HTTP-Server-Deps)
kafkalyzer-mcp         ← core, kafka, profiles        (kein frb)
```

Diese Tabelle ist Prüfgegenstand von `harden-read-only-gate` (Abhängigkeits-Allowlist für `rdkafka`,
`flutter_rust_bridge`).

### 4.3 Headless-Betriebsarten

| Modus | Artefakt | Profilquelle | Status |
|---|---|---|---|
| Script-CLI | GUI-Binary mit `--script` (E19) | App-Speicher über `ClusterService` | besteht (`headless-script-execution`); Härtung in 5.39 |
| MCP lokal | `kafkalyzer-mcp` (Rust, stdio), neben der App ausgeliefert | Export nach E4 | Phase 4 |
| MCP/HTTP remote | `kafkalyzer-server` (`/mcp`, Streamable HTTP, OIDC/Bearer) | Kubernetes-Secrets / Umgebung | nicht eingeplant (E8) |

Pflichtset für **jede** MCP-Variante (aus `mcp-server-feasibility.md` §4/§5, hier verbindlich):
Cluster-Allowlist; harte Limits (Standard ≤ 20 Nachrichten, ≤ 4 KB Payload je Nachricht, Scan-Timeout ≤ 15 s;
konfigurierbar, aber gedeckelt); `run_forever` nicht erreichbar; Redaction aller Credential-Felder; interne Topics
nur auf ausdrücklichen Parameter; Tool-Beschreibungen nennen den Datenabfluss an den LLM-Anbieter.

### 4.4 Backend-Naht in Dart (nicht eingeplant, E8)

Nur relevant, falls E8 revidiert wird; hier festgehalten, damit die Analyse nicht verloren geht.

- Naht ist ein Interface `KafkaBackend` unter `lib/src/backend/` mit denselben Operationen wie die heutigen 24
  Bridge-Funktionen in `rust/src/api/`, **profilbasiert** (Parameter `ClusterProfile`, keine `clusterId`).
- `FrbKafkaBackend` delegiert 1:1 an die generierten Funktionen. Registrierung über `getIt`.
- Die 22 direkt aufrufenden Dateien werden umgestellt; `kafka_metadata_service.dart` und
  `schema_registry_service.dart` sind bereits Teil-Nähte und werden genutzt, nicht dupliziert.
- Streams bleiben gebatcht (L4), unabhängig vom Transport.
- Ein Remote-Profil ist ein `ClusterProfile`-Verweis (Server-URL + Clustername auf dem Server); die Auswahl der
  Implementierung erfolgt pro Profil. Details gehören in das Design von `remote-cluster-profiles`.

### 4.5 Read-only-Absicherung in drei Schichten

1. **Statisch:** erweitertes Gate (Muster + Abhängigkeits-Allowlist), läuft als eigener CI-Job.
2. **Strukturell:** MCP- und Server-Crates haben keine eigene Kafka-Client-Abhängigkeit; sie erreichen Kafka nur über
   die öffentlichen Funktionen von `kafkalyzer-kafka`.
3. **Am Cluster:** Least-Privilege-Service-Account (`read-only-security-guidance`). Für Server und MCP ist das die
   einzige Schicht, die auch bei einem Programmfehler hält — in der Dokumentation als Voraussetzung, nicht als
   Empfehlung führen.

Formulierung in allen Dokumenten: „durch CI-Gate, Crate-Schichtung und Broker-ACLs abgesichert“ — nicht „garantiert“.

---

## 5. Change-Katalog

Die Changes stehen unter ihrer Phase. Nummern sind stabile Kennungen; 5.21–5.39 stammen aus dem Code-Review (§2.4)
und sind deshalb knapper gefasst. Abhängigkeiten sind ausdrücklich genannt.

### Phase 0 — Fundament

#### 5.1 `harden-read-only-gate` (S)

- **Warum:** §2.3 Nr. 1. Voraussetzung dafür, dass MCP und Server dieselbe Zusicherung erben.
- **Capabilities:** MOD `read-only-invariants-enforcement`.
- **Anforderungen:**
  - Das Gate SHALL bei schreibenden Admin-Aufrufen fehlschlagen: `create_topics`, `delete_topics`,
    `create_partitions`, `alter_configs`, `incremental_alter_configs`, `delete_records`, `delete_groups`,
    sowie `store_offset`/`store_offsets`.
  - Das Gate SHALL fehlschlagen, wenn `rdkafka` in einer anderen `Cargo.toml` als `kafkalyzer-kafka` oder
    `flutter_rust_bridge` in einer anderen als `rust/Cargo.toml` deklariert ist.
  - Das Gate SHALL HTTP-Schreibmethoden (`.put(`, `.delete(`, `.patch(`) im Rust-Code verbieten und `.post(` nur
    mit ausdrücklicher, begründeter Ausnahme-Markierung zulassen (heute: `/compatibility`).
  - Das Gate SHALL direkte Aufrufe schreibender librdkafka-C-Funktionen (`rd_kafka_commit`, `rd_kafka_offsets_store`,
    `rd_kafka_AlterConsumerGroupOffsets`, `rd_kafka_CreateTopics` u. a.) verbieten; List/Describe bleiben erlaubt
    (Absicherung für eine mögliche FFI-Bindung in 5.24).
  - `scripts/test_check_read_only.sh` SHALL je neuem Muster einen Positiv- und einen Negativfall enthalten.
- **Schichten:** `scripts/`, `build.yml`. Kein Produktivcode.
- **Dazu (ohne Spec):** `.insecure_curlrc` aus dem Repository entfernen (eingecheckt, in keinem Workflow verwendet).

#### 5.2 Dokumentationskorrekturen (S, kein OpenSpec-Change)

- README: Abschnitt „Multi-Search“ an L6 anpassen; Aussage „headers“ entfernen, bis `structured-message-filter`
  umgesetzt ist; Screenshot-Galerie (Hell/Dunkel) und kurze GIFs für Lag-Dashboard, Message-Diff, Topic-Analyse.
- `openspec/config.yaml`: `kafkalyzer-core` ist nicht „AS400 decoding“ (existiert nicht), sondern Pfadauflösung,
  Avro-Hilfen, Partition-Health, Report-Vergleich.
- `openspec/specs/windows-ci/spec.md`: Purpose ist noch „TBD“.
- „Read-only“-Formulierung gemäß §4.5.
- README Zeile 170 („SSL verification will fail even if disabled in the cluster profile“) nach 5.21 neu fassen.
- `pubspec.yaml`: `description` lautet noch „A new Flutter project.“

#### 5.21 `restore-tls-verification` (M)

- **Warum:** A1, E13. Höchste Priorität im gesamten Dokument.
- **Capabilities:** NEU `tls-verification`; MOD `ergonomic-settings-and-cluster-onboarding` (Kennzeichen in Dialog
  und Cluster-Liste), MOD `read-only-security-guidance` (Dokumentation).
- **Anforderungen:**
  - Neue TLS-Profile SHALL Zertifikatskette und Hostnamen prüfen.
  - Das Abschalten SHALL nur über eine ausdrückliche Profil-Option möglich sein; ein solches Profil SHALL in
    Cluster-Liste, Dialog und an jedem Tab als „unsicher“ gekennzeichnet sein.
  - Beim ersten Start nach dem Upgrade SHALL die App jedes bestehende TLS-Profil mit aktiver Prüfung testen (E13).
    Bei Erfolg SHALL die Prüfung für das Profil aktiv sein. Bei Fehlschlag SHALL ein Übergangsdialog je Profil den
    Fehler nennen und die Wahl bieten: Prüfung aktiv lassen (Profil korrigieren) oder ausdrücklich abschalten.
  - Ist ein Cluster beim Upgrade nicht erreichbar, SHALL die Entscheidung für dieses Profil auf das nächste
    Verbinden verschoben werden; bis dahin SHALL keine Verbindung ohne Prüfung zustande kommen.
  - Der Übergang SHALL je Profil genau einmal stattfinden und sein Ergebnis gespeichert werden.
  - Die Schema-Registry-Verbindung SHALL derselben Einstellung folgen.
  - Kein Codepfad SHALL die Prüfung unabhängig vom Profil abschalten (abgesichert durch Rust-Unit-Tests auf
    `create_config`, nicht durch das Read-only-Gate).
- **Schichten:** core (`ClusterProfile`-Feld) → kafka (`create_config`, Registry-Client) → Bridge → Dart.
- **Spike vorab (Windows-CA):** Die Prüfung ist heute überall abgeschaltet — trotzdem verlangt das README unter
  Windows eine `cacert.pem`. Ursache klären, bevor der Fallback (Systemzertifikatspeicher oder Bundle) festgelegt
  wird. Dieser Spike ersetzt den in 5.3 genannten.

#### 5.22 `harden-local-storage-and-imports` (M)

- **Warum:** A2–A5, A7.
- **Capabilities:** MOD `cluster-profile-persistence`, MOD `secure-credentials-storage`; NEU `archive-import-safety`.
- **Anforderungen:**
  - Jeder Archiv-Import (Profile, Konfiguration, Script-Läufe) SHALL Einträge abweisen, deren aufgelöster Pfad
    außerhalb des Zielverzeichnisses liegt, und den Import dann vollständig abbrechen.
  - Ist der gespeicherte Profil- oder Script-Bestand nicht lesbar, SHALL die App das anzeigen, den Rohinhalt sichern
    und **nicht** überschreiben; ein einzelner defekter Eintrag SHALL die übrigen nicht verbergen.
  - Ist der OS-Schlüsselbund nicht verfügbar, SHALL ein dauerhafter Hinweis erscheinen („Passwörter werden nicht
    gespeichert“); die Migration SHALL Klartext nur entfernen, wenn das Schreiben in den Schlüsselbund gelang.
  - Profilnamen SHALL eindeutig sein; beim Import gleichnamiger Profile SHALL die App ersetzen/umbenennen/überspringen
    anbieten.
  - Der Konfigurations-Export SHALL keine fest einkodierten Fremddateien einpacken (A5 entfernen).
  - Der Cluster-Export SHALL Secrets standardmäßig entfernen und nur nach ausdrücklicher, gewarnter Zustimmung
    einschließen (heute: immer Klartext; stellt den bestehenden Spec her).
  - Der Konfigurations-Import SHALL Profile zusammenführen (Konfliktdialog je Namen) statt die Liste zu ersetzen.
  - Zuletzt verwendete Topics und Tab-Sitzungen sind nicht Teil dieses Changes (wiederherstellbar).
  - Verzeichnisnamen für Script-Läufe SHALL aus dem bereinigten Scriptnamen gebildet werden.
- **Schichten:** nur Dart.

#### 5.23 `fix-result-view-defects` (S)

- **Warum:** B3–B6. Reine Fehlerbehebung; wo ein bestehender Spec das Soll schon beschreibt, ohne Delta.
- **Capabilities:** MOD `message-sort-order` (deterministische Reihenfolge), MOD `explorer-onboarding` (Fehlerzustand);
  `downloaded-file-actions` ohne Delta (Verhalten wiederherstellen).
- **Anforderungen:**
  - Ein abgebrochener Speichern-Dialog SHALL keine Erfolgsmeldung auslösen.
  - Ein Fehler beim Konsumieren, beim Laden der Topic-Liste oder der Subjects SHALL als Fehlerzustand mit Ursache
    und „Erneut versuchen“ erscheinen und sich sichtbar von „keine Nachrichten“ unterscheiden.
  - Kopieren eines Baumknotens SHALL für Objekte und Arrays gültiges JSON liefern.
  - Jede Sortierung SHALL Topic, Partition, Offset als Zweitschlüssel verwenden.
  - Der Spaltenfilter „Inhalt“ SHALL auf dem vollständigen Wert arbeiten, nicht auf der gekürzten Vorschau; eine
    leer gefilterte Tabelle SHALL einen Leerzustand mit „Filter zurücksetzen“ zeigen.
- **Schichten:** nur Dart.

#### 5.40 `remove-dlq-replay-command` (S)

- **Warum:** A8. Ein kopierbarer Producer-Befehl macht einen Schreibzugriff auf Produktiv-Topics einen
  Einfügevorgang entfernt.
- **Capabilities:** `dead-letter-queue-detection` (Requirement ersetzt: Replay-Szenario entfällt),
  `read-only-invariants-enforcement` (ADDED: Gate verbietet `kcat … -P` im Quelltext).
- **Anforderungen:**
  - Die DLQ-Karte SHALL keinen Befehl anbieten, der nach Kafka schreibt.
  - Sie SHALL „Fehlgeschlagene Nachricht kopieren“ anbieten (JSON mit Nachricht, Headern, Original-Koordinaten,
    Exception).
  - Das Gate SHALL `kcat`/`kafkacat` mit `-P` im Quelltext ablehnen; `-C`/`-L` bleiben erlaubt.
- **Abhängigkeit:** nach 5.1; vor 5.27 (dessen `kcat -C`-Befehl die neue Gate-Zeile passieren muss).

#### 5.24 `fix-consumer-lag-accuracy` (M)

- **Warum:** B1, B2. Eine stehende Gruppe ist der häufigste Anlass, die Lag-Ansicht zu öffnen.
- **Capabilities:** MOD `consumer-lag-monitoring`, MOD `consumer-group-member-insights`.
- **Anforderungen:**
  - Für Gruppen ohne aktive Mitglieder SHALL der Lag aus den committeten Offsets ermittelt werden. Ist das nicht
    möglich, SHALL „unbekannt“ erscheinen — nie 0.
  - Partitionen ohne committeten Offset SHALL aufgeführt und als „kein Commit“ markiert sein.
  - Sortierung nach Lag und die Summen-KPI SHALL alle gefilterten Gruppen laden oder „n von m geladen“ ausweisen;
    ungeladene Gruppen SHALL nicht als 0 einsortiert werden.
  - Ein Aktualisierungslauf SHALL nicht starten, solange der vorige läuft; der Fehler je Gruppe SHALL abrufbar
    bleiben.
  - „Partition ohne Besitzer“ SHALL nicht gemeldet werden, wenn die Zuordnung eines Mitglieds nicht lesbar war.
- **Schichten:** kafka (`fetch_consumer_group_lag`, gebündelter Abruf mit geteiltem Watermark-Cache) → Bridge → Dart.
- **Spike vorab:** Wie lassen sich alle committeten Offsets einer mitgliederlosen Gruppe mit der eingesetzten
  rdkafka-Version rein lesend ermitteln (Admin-API vorhanden? sonst `committed_offsets` über die Topics der
  letzten bekannten Subscription bzw. alle Topics, begrenzt).

### Phase 1 — Schnelle Verbesserungen ohne Architekturabhängigkeit

#### 5.3 `connection-diagnostics` (M)

- **Warum:** Der vorhandene Test meldet nur Erfolg oder einen librdkafka-Fehlertext. Fehlkonfigurationen bei TLS/SASL
  sind die häufigste Einstiegshürde.
- **Capabilities:** NEU `connection-diagnostics`; MOD `ergonomic-settings-and-cluster-onboarding` (Live Broker
  Connection Test zeigt Stufen).
- **Anforderungen:**
  - Der Verbindungstest SHALL ein Ergebnis je Stufe liefern: (1) DNS-Auflösung und TCP-Erreichbarkeit je
    Bootstrap-Server, (2) TLS, (3) Authentifizierung, (4) Metadaten-Abruf, (5) Schema Registry (falls konfiguriert).
  - Jede Stufe SHALL einen der Zustände *ok*, *fehlgeschlagen*, *nicht geprüft* (weil eine Vorstufe scheiterte)
    und bei Fehlern einen lokalisierten Hinweis mit Rohfehler liefern.
  - Stufe 1 SHALL unabhängig von librdkafka geprüft werden. Stufen 2–4 SHALL aus der Klassifikation der
    librdkafka-Fehler abgeleitet werden; ist keine Zuordnung möglich, SHALL das Ergebnis „Verbindung fehlgeschlagen,
    Stufe unbekannt“ lauten statt einer geratenen Stufe.
  - Der Test SHALL keine Secrets in Logs oder Ergebnistexten ausgeben und SHALL ein Gesamt-Timeout haben.
- **Schichten:** core (Fehlerklassifikation, rein und testbar) → kafka (Sonden) → Bridge (neue Funktion;
  `validate_connection` bleibt bestehen, L3) → Dart (`cluster_config_dialog`).
- **Abhängigkeit:** 5.21 (TLS-Prüfung und Windows-CA-Spike). Erst mit aktiver Prüfung ist die TLS-Stufe
  aussagekräftig.
- **Nicht-Ziele:** kein Netzwerk-Scanner, keine Kerberos-Ticket-Verwaltung.

#### 5.4 `command-palette` (M)

- **Capabilities:** NEU `command-palette`.
- **Anforderungen:**
  - `Strg+K` / `Cmd+K` SHALL eine Palette öffnen, außer ein Textfeld hat Fokus und der Kurzbefehl ist dort belegt.
  - Die Palette SHALL fuzzy über diese Quellen suchen: Cluster-Profile (verbinden), Topics des aktiven Clusters
    (Tab öffnen/fokussieren), Consumer Groups (Details öffnen), gespeicherte Scripts (Run-Ansicht öffnen),
    Navigationsziele.
  - Sie SHALL vollständig per Tastatur bedienbar sein und nur bereits geladene Listen durchsuchen (kein Netzwerkaufruf
    je Tastendruck).
  - Ein Script SHALL aus der Palette nur **geöffnet**, nicht ungefragt gestartet werden.
- **Schichten:** nur Dart (`features/navigation`).
- **Zu prüfen:** Kollision mit den Tastenbelegungen in `messages_view.dart` (§2.3 Nr. 14).

#### 5.5 `chunked-raw-and-hex-viewer` (M)

- **Capabilities:** MOD `large-message-handling` (Requirement *Output Truncation* wird ersetzt).
- **Anforderungen:**
  - Roh- und Hex-Ansicht SHALL beliebig große Payloads zeilen-/seitenweise virtualisiert darstellen; die feste
    Kappung bei 500 000 Zeichen entfällt.
  - Die Suche in der Ansicht SHALL Trefferpositionen außerhalb des UI-Threads berechnen und zwischen Treffern
    springen, ohne den gesamten Text in einem Text-Widget zu halten.
  - Kopieren und Export SHALL weiterhin die vollständigen Rohdaten liefern.
- **Schichten:** nur Dart (`lib/src/ui/json_or_string_viewer.dart`, `hex_viewer.dart`, vorhandenes Isolate).
- **Nicht-Ziele:** Baumansicht (bereits virtualisiert).

#### 5.6 `fast-trace-partition-preview` (S)

- **Capabilities:** MOD `search-configuration-panel`.
- **Anforderungen:**
  - Bei aktivem Fast Trace SHALL die Suchkonfiguration vor dem Start die berechnete Zielpartition anzeigen
    (`murmur2`, Partitionsanzahl aus den Metadaten).
  - Die Anzeige SHALL die Annahme nennen: Java-Default-Partitioner, Key als UTF-8-Text. Sie SHALL darauf hinweisen,
    dass andere Partitioner (z. B. librdkafka `consistent`/CRC32, eigene Partitioner) oder binär serialisierte Keys
    abweichen können.
- **Schichten:** nur Dart (Bridge-Funktionen `murmur2`/`to_positive` existieren).

#### 5.7 `encrypted-profile-export` (M)

- **Capabilities:** MOD `secure-credentials-storage` (Requirement *Safe Profile Export and Import Controls*),
  MOD `cluster-profile-persistence`.
- **Anforderungen:**
  - Ein Export **mit** Zugangsdaten SHALL nur passwortverschlüsselt möglich sein; der unverschlüsselte
    Klartext-Export mit Secrets entfällt. Der Export ohne Secrets bleibt Standard.
  - Die Verschlüsselung SHALL ein Standardformat nutzen (E6) und in Rust erfolgen.
  - Beim Import SHALL ein falsches Passwort oder eine beschädigte Datei eine verständliche Fehlermeldung liefern
    und keine Profile verändern.
  - Bestehende unverschlüsselte Bundles SHALL weiterhin importierbar bleiben.
  - Der Dialog SHALL eine Mindestlänge für das Passwort erzwingen und darauf hinweisen, dass es nicht
    wiederherstellbar ist.
- **Schichten:** core oder kafkalyzer-profiles (Ver-/Entschlüsselung als reine Funktion) → Bridge → Dart
  (`settings_service.dart`, Exportdialog).
- **Nicht-Ziele:** Schlüsselverwaltung, Team-Passwortspeicher.

#### 5.25 `app-diagnostics-and-error-reporting` (M)

- **Warum:** A6; Fehler außerhalb von try/catch erreichen in der paketierten App niemanden.
- **Capabilities:** NEU `app-diagnostics`.
- **Anforderungen:**
  - Nicht abgefangene Fehler (Framework, Plattform, Zone) SHALL protokolliert und dem Nutzer mit „Details kopieren“
    gemeldet werden; ein Fehler beim Start SHALL einen Fehlerbildschirm statt eines leeren Fensters zeigen.
  - Dart und Rust SHALL in **eine** rotierende Logdatei im Anwendungsdatenverzeichnis schreiben; die Datei im
    Temp-Verzeichnis entfällt. Logs SHALL keine Secrets und keine Payloads enthalten.
  - Einstellungen → Diagnose SHALL „Log-Ordner öffnen“ und „Diagnose kopieren“ (Version, Plattform, Profil ohne
    Secrets, letzte Fehler) anbieten.
  - Ein Info-Dialog SHALL Version, Lizenzen, Repository-Link und Speicherorte zeigen; eine Übersicht aller
    Tastenkürzel SHALL per `F1`/`?` erreichbar sein.
- **Schichten:** kafka (Logging statt Datei-Append) → Dart (`main.dart`, `features/settings`).

#### 5.26 `cluster-profile-ergonomics` (M)

- **Warum:** Verwechslung von DEV und PROD ist auch lesend teuer (falsche Diagnose); Profile sind heute nur
  anlegbar, änderbar, löschbar.
- **Capabilities:** MOD `ergonomic-settings-and-cluster-onboarding`, MOD `cluster-profile-persistence`,
  MOD `topic-search-tabs` (Sitzung je Cluster, B13).
- **Anforderungen:**
  - Ein Profil SHALL duplizierbar sein; Secrets werden dabei mitkopiert.
  - Ein Profil SHALL eine optionale Umgebungskennzeichnung mit Farbe tragen, die an Cluster-Kachel, Tab und
    Fensterkopf sichtbar ist.
  - Die Cluster-Liste SHALL filterbar sein; der aktive Cluster SHALL eine „Trennen“-Aktion haben.
  - Bootstrap-Server SHALL je Eintrag als `host:port` geprüft werden, bevor verbunden wird.
  - Ein Profil SHALL aus einer Kafka-`client.properties` vorbefüllt werden können (Zuordnung der bekannten
    `bootstrap.servers`/`security.protocol`/`sasl.*`/`ssl.*`-Schlüssel; unbekannte Schlüssel werden aufgelistet,
    nicht übernommen).
  - Ein Profil SHALL zusätzliche librdkafka-Eigenschaften aus einer Positivliste aufnehmen (E15).
  - Gespeicherte Sitzungen SHALL nur Tabs des jeweiligen Clusters enthalten; nicht wiederherstellbare Tabs SHALL
    gemeldet werden.
- **Schichten:** core (`ClusterProfile` additiv, Positivliste) → kafka → Bridge → Dart.

#### 5.27 `message-selection-copy-and-display` (M)

- **Capabilities:** NEU `message-selection-and-copy`; MOD `message-inspector-shell` (Tastatur),
  MOD `message-table-columns`.
- **Anforderungen:**
  - Die Tabelle SHALL Mehrfachauswahl (`Strg`/`Umschalt`+Klick) unterstützen; genau zwei gewählte Nachrichten SHALL
    direkt im Diff geöffnet werden können.
  - Das Zeilen-Kontextmenü SHALL anbieten: Key kopieren, Wert kopieren, Nachricht als JSON kopieren,
    Koordinaten (`topic/partition/offset`) kopieren, lesenden `kcat`-Aufruf für genau diese Nachricht kopieren.
    Im Baum zusätzlich: Feldpfad kopieren.
  - Tombstones SHALL in Tabelle, Timeline und Inspector als solche gekennzeichnet sein; `null` und leere
    Zeichenkette SHALL bei Key und Wert unterscheidbar sein.
  - Zeitangaben SHALL zwischen lokaler Zeit und UTC umschaltbar sein (globale Einstellung) und per Tooltip
    ISO-8601, Epoch-Millisekunden und relative Zeit zeigen; „Metadaten kopieren“ SHALL ISO-8601 verwenden.
  - Tastatur SHALL ohne geöffneten Inspector funktionieren: Filter fokussieren, Anfang/Ende, seitenweise,
    Auswahl kopieren. Kürzel SHALL in Tooltips genannt sein.
  - Der Schnellfilter über geladene Nachrichten SHALL Header, Partition und Offset einbeziehen.
- **Schichten:** nur Dart. Der Zeitstempel-Typ (CreateTime/LogAppendTime) braucht ein additives Feld in
  `KafkaMessage` (kafka → Bridge) und ist optionaler Teil dieses Changes.

#### 5.28 `message-export-fidelity` (S–M)

- **Capabilities:** MOD `message-csv-export`.
- **Anforderungen:**
  - Exportiert SHALL werden, was die Tabelle zeigt: aktive Spaltenfilter und Sortierung gelten; ausgegraute
    Nicht-Treffer sind standardmäßig nicht enthalten. Bei vorhandener Auswahl SHALL „nur Auswahl“ wählbar sein.
  - JSON-Exporte SHALL Header, Schema-Herkunft (Schlüssel und Wert) und einen ISO-8601-Zeitstempel zusätzlich zum
    Epoch-Wert enthalten; CSV SHALL eine Header-Spalte anbieten.
  - NDJSON (eine Nachricht je Zeile) SHALL als Format wählbar sein.
  - Tombstones SHALL im Export als `null` erscheinen, nicht als leere Zeichenkette.
  - Bestehende Exportdateien bleiben lesbar; neue Felder sind additiv.
- **Schichten:** nur Dart (`message_export_service.dart`, `search_json_serializer.dart`).

#### 5.29 `live-tail-controls` (M)

- **Capabilities:** MOD `topic-consumption` (*Result Buffer Honors Configured Limit*); NEU `live-tail-controls`.
- **Anforderungen:**
  - Jeder Nachrichtenpuffer SHALL eine konfigurierbare Obergrenze haben; werden älteste Nachrichten verworfen,
    SHALL die Ansicht deren Anzahl anzeigen. Das gilt für Einzel-Topic-Stream und Mehr-Topic-Suche gleichermaßen
    (heute: unbegrenzt bzw. stille Kappung bei 2000).
  - Ein laufender Stream SHALL pausierbar sein, ohne den Puffer zu leeren; während der Pause eingehende
    Nachrichten werden gezählt („n neue“) und beim Fortsetzen übernommen.
  - „Dem Ende folgen“ SHALL umschaltbar sein und sich beim manuellen Scrollen selbst abschalten.
  - Filtern und Sortieren SHALL bei Live-Aktualisierung nicht die gesamte Liste je Tick neu berechnen (L4).
- **Schichten:** nur Dart.

#### 5.30 `nested-payload-decoding` (M)

- **Capabilities:** MOD `smart-virtual-json-tree`, MOD `message-headers-inspection`, MOD `message-inspector-shell`.
- **Anforderungen:**
  - Ein Text-Knoten SHALL auf Wunsch als JSON, Base64 oder gzip dekodiert und an Ort und Stelle als Teilbaum
    gezeigt werden; die Rohdarstellung bleibt erreichbar. Automatisch wird nichts umgedeutet.
  - Zahlen in plausiblen Epoch-Bereichen SHALL per Tooltip als Datum lesbar sein.
  - Header-Werte SHALL denselben Betrachter wie Payload und Key nutzen.
  - Die Suche im Inspector SHALL Key und Header einschließen, Treffer summieren und auch in der Rohansicht zum
    Treffer springen.
- **Schichten:** nur Dart.

#### 5.31 `appearance-window-and-update-settings` (S–M)

- **Capabilities:** MOD `ergonomic-settings-and-cluster-onboarding`, MOD `auto-update`; NEU `appearance-settings`.
- **Anforderungen:**
  - Einstellungen SHALL Theme (System/Hell/Dunkel), Sprache, Textgröße, Zeitanzeige (lokal/UTC) und das
    Standard-Ergebnislimit anbieten; „Auf Standard zurücksetzen“ je Abschnitt.
  - Zahleneingaben SHALL auf gültige Bereiche geprüft werden.
  - Fenstergröße, -position und Maximierung SHALL gespeichert und wiederhergestellt werden.
  - In Installationen ohne Selbst-Update (deb, tar, snap) SHALL die App auf eine neuere Version mit Link hinweisen
    (offen seit `feature-gap-analysis.md` C9); ein laufender Download SHALL abbrechbar sein.
- **Schichten:** nur Dart; Fenstergeometrie erfordert voraussichtlich ein zusätzliches Plugin (im Change prüfen).

#### 5.32 `accessibility-and-l10n-sweep` (M)

- **Capabilities:** MOD `complete-ui-localization-and-discoverability`; NEU `accessibility-baseline`.
- **Anforderungen:**
  - Jede reine Icon-Schaltfläche SHALL Tooltip und Semantik-Label haben; Klickflächen SHALL eine Mindestgröße
    einhalten.
  - Statusfarben SHALL aus dem Farbschema stammen und in beiden Themes ausreichend kontrastieren; Zustand SHALL nie
    nur über Farbe vermittelt werden.
  - Verbliebene fest einkodierte Texte SHALL in die ARB-Dateien wandern (u. a. Tabellen-Filterdialog, Hex-Viewer,
    Roh/Baum-Umschalter, Verbindungsfehler, Cluster-Übersicht). Ein Test SHALL neue Literale in Widgets verhindern,
    soweit mit vertretbarem Aufwand prüfbar.
  - Fehlerboxen SHALL schließbar sein und „Kopieren“ anbieten.
- **Schichten:** nur Dart.

### Phase 2 — Analysekern

#### 5.8 `structural-message-diff` (M)

- **Warum:** E11. Baustein für 5.12 und 5.17.
- **Capabilities:** NEU `message-structural-diff` (die Diff-Ansicht hat bisher keinen Spec).
- **Anforderungen:**
  - Der strukturelle Vergleich zweier JSON-Werte SHALL in `kafkalyzer-core` berechnet werden und eine flache Liste
    `{path, kind (added|removed|changed), old, new}` liefern; Pfade in der Notation nach L7.
  - Die Diff-Ansicht SHALL eine Ignorierliste für Feldpfade anbieten; ignorierte Felder SHALL nicht als Unterschied
    zählen und als „ausgeblendet (n)“ ausgewiesen werden.
  - Die Ignorierliste SHALL pro Topic gespeichert werden und Vorschläge für typische flüchtige Felder machen
    (Zeitstempel, IDs), ohne sie ungefragt zu aktivieren.
  - Die Darstellung bestehender Diffs SHALL sich nicht verändern (vorhandene Widget-Tests als Sicherheitsnetz).
- **Schichten:** core → Bridge → Dart (`widgets/diff/`, `messages_diff_view.dart`); Git-Abhängigkeit `json_diff`
  entfernen.

#### 5.9 `structured-message-filter` (L)

- **Warum:** Präzise Bedingungen statt Regex auf serialisiertem Text; Header als Filterquelle.
- **Capabilities:** NEU `structured-message-filter`; MOD `topic-consumption` (*Pre-compiled Filter Evaluation*),
  MOD `saved-topic-searches` (Ausdruck wird mitgespeichert), MOD `search-configuration-panel`.
- **Anforderungen:**
  - Ein Filter SHALL ein Baum aus Bedingungen sein (E5). Quellen: `key`, `value`, `header.<name>`, sowie Metadaten
    `partition`, `offset`, `timestamp`. Operatoren: `==`, `!=`, `<`, `<=`, `>`, `>=`, `contains`, `matches` (Regex),
    `exists`. Verknüpfung: AND, OR, NOT, Klammern.
  - Vergleiche SHALL typbewusst sein (Zahl gegen Zahl, Text gegen Text); ein nicht auflösbarer Pfad SHALL die
    Bedingung zu *falsch* machen, nicht zu einem Fehler.
  - Der Ausdruck SHALL vor dem Poll-Loop einmal geparst und kompiliert werden; ein ungültiger Ausdruck SHALL die
    Suche vor dem Start mit Positionsangabe abweisen (kein stiller Fallback).
  - Die Oberfläche SHALL zwei gleichwertige Modi bieten — Bedingungs-Chips und Texteingabe — die verlustfrei
    ineinander überführbar sind.
  - Feldvorschläge SHALL aus dem verknüpften Schema stammen, wenn vorhanden, sonst aus den bereits geladenen
    Nachrichten bzw. den Feldfrequenzen einer vorhandenen Topic-Analyse.
  - Bestehende Filter (`FilterType` Contains/Regex/Exact, `filter_field`, `SearchScope`) SHALL unverändert
    funktionieren; gespeicherte Suchen und Scripts im alten Format SHALL ladbar bleiben.
  - Ein reiner Key-/Metadatenfilter SHALL ohne Payload-Dekodierung auswertbar sein.
- **Schichten:** core (`filter_expr`: Parser, AST, Auswertung; vollständig unit-getestet) → kafka (Einbindung in
  `consume_with_filter`, Header-Zugriff) → Bridge (neuer optionaler Parameter bzw. neue Funktion, L3) → Dart.
- **Nicht-Ziele:** Aggregationen, Joins, Projektionen, benutzerdefinierte Funktionen.

#### 5.10 `topic-config-inspection-and-diff` (M)

- **Capabilities:** NEU `topic-config-inspection`.
- **Anforderungen:**
  - Die Topic-Detailansicht SHALL die vollständige Topic-Konfiguration mit Wert, Quelle (Default/überschrieben) und
    Sensitiv-Kennzeichen anzeigen; als sensitiv markierte Werte SHALL nie angezeigt werden.
  - Der Nutzer SHALL zwei Topics vergleichen können — im selben Cluster oder in zwei gespeicherten Profilen — mit
    Schalter „nur Abweichungen und Nicht-Defaults“.
  - Schlägt der Abruf für eine Seite fehl (z. B. fehlendes `DescribeConfigs`-Recht), SHALL die Ansicht das
    ausweisen, statt fehlende Werte als Unterschied darzustellen.
  - Der Abruf SHALL ausschließlich `describe_configs` verwenden.
- **Schichten:** kafka (neue Funktion `fetch_topic_configs`) → Bridge → Dart (`features/topic`).
- **Folgeanforderung (optional, eigener Change):** Broker-Konfiguration nach demselben Muster.
- **Hinweis:** Der Cluster-übergreifende Vergleich braucht keine zweite „aktive Verbindung“ — die API ist
  profilbasiert und zustandslos.

#### 5.11 `partition-offset-distribution` (S)

- **Capabilities:** MOD `partition-health-visibility`.
- **Anforderungen:**
  - Die Partitionstabelle SHALL je Partition Low/High Watermark und die Offset-Spanne anzeigen sowie den Anteil an
    der Gesamtspanne als Balken.
  - Die Anzeige SHALL als **Schätzung** gekennzeichnet sein und bei `cleanup.policy` mit `compact` ausdrücklich
    darauf hinweisen, dass Offset-Spannen keine Nachrichtenanzahl sind; für exakte Werte SHALL sie auf die
    Topic-Analyse verweisen.
  - Ein Hinweis-Badge SHALL erscheinen, wenn eine Partition einen konfigurierbaren Anteil überschreitet
    (Standard 50 %, nur bei ≥ 2 Partitionen).
  - Watermarks SHALL nur auf Abruf der Detailansicht geholt werden, nicht für die gesamte Topic-Liste.
- **Schichten:** core (Verteilungsrechnung) → kafka → Bridge (`PartitionRow` additiv erweitern) → Dart.

#### 5.33 `topic-list-scale-and-organisation` (M)

- **Warum:** B7–B9; die Liste ist der Einstieg in jede Sitzung und skaliert heute nicht (ein `describe_configs` für
  alle Topics mit 10 s Timeout; Filterung je Zeile neu).
- **Capabilities:** MOD `compact-topic-sidebar`, MOD `explorer-onboarding`.
- **Anforderungen:**
  - Die Topic-Liste SHALL ohne Konfigurationsabruf erscheinen; Konfigurationen werden in Blöcken nachgeladen oder
    erst beim Öffnen eines Topics geholt.
  - Die Liste SHALL ihr Alter anzeigen („aktualisiert vor n min“) und unabhängig von der Schema Registry
    aktualisierbar sein.
  - Der Filter SHALL wahlweise Teilstring, Glob oder Regex unterstützen; Filter-Schalter SHALL je Cluster
    gespeichert sein; die Anzahl ausgeblendeter Topics SHALL sichtbar sein. Die Endung `-topic` ist kein
    Stream-Merkmal.
  - Die Liste SHALL sortierbar (Name, Partitionen, Zustand), nach Namenspräfix gruppierbar und um Favoriten
    ergänzbar sein.
  - Nicht lesbare Konfiguration und nicht autorisierte Topics SHALL als solche ausgewiesen werden („nicht lesbar —
    Berechtigung?“), statt zu fehlen.
  - Unbekannte Metadaten SHALL als unbekannt dargestellt und beim Öffnen nachgeladen werden; es werden keine
    Platzhalterwerte angezeigt.
- **Schichten:** kafka (`fetch_topics` ohne Zwang zu Configs, Ergebnis mit Verfügbarkeits-Flag) → Bridge (additiv)
  → Dart (gefilterte Liste zwischenspeichern).

#### 5.34 `cluster-overview-and-topic-facts` (M) — nutzt 5.11

- **Capabilities:** MOD `explorer-onboarding` (*Cluster Overview Dashboard*), MOD `partition-health-visibility`.
- **Anforderungen:**
  - Die Cluster-Übersicht SHALL Broker (ID, Host, Port), Anzahl Topics und Partitionen sowie die Zahl der Topics mit
    unterreplizierten oder führerlosen Partitionen zeigen; ein Klick führt zur gefilterten Topic-Liste.
  - Controller, Cluster-ID und Broker-Version SHALL nur gezeigt werden, wenn sie lesend verfügbar sind (im Change
    prüfen).
  - Der Topic-Kopf SHALL geschätzte Nachrichtenanzahl (als Schätzung gekennzeichnet, wie 5.11), Zeitstempel der
    ältesten und neuesten Nachricht und `retention.bytes` zeigen; Aufbewahrungsdauer SHALL in Tagen/Stunden/Minuten
    formatiert und lokalisiert sein.
- **Schichten:** kafka → Bridge → Dart.

#### 5.35 `schema-type-awareness-and-subject-browser` (L)

- **Warum:** B10; Subjects ohne `<topic>-key`/`-value`-Namen sind heute nicht erreichbar.
- **Capabilities:** MOD `integrated-schema-inspector`, MOD `schema-evolution-workflows`, MOD `schema-registry-auth`.
- **Anforderungen:**
  - Schema-Abrufe SHALL Typ (Avro/Protobuf/JSON Schema), ID, Version und Referenzen liefern; Kennzeichnungen und
    Feldpfade SHALL dem Typ entsprechen. Referenzen SHALL als anklickbare Subjects erscheinen.
  - Der Explorer SHALL eine durchsuchbare Subject-Liste bieten (E16), mit zugeordneten Topics und Sprung in den
    bestehenden Inspector.
  - Das Kompatibilitäts-Level (global und je Subject) SHALL lesend angezeigt werden.
  - Schema-Text SHALL kopier- und als Datei speicherbar sein.
  - Registry-Aufrufe SHALL ein Timeout haben, HTTP-Fehler als solche melden (401/403 verständlich), Subject-Namen
    korrekt kodieren und URLs normalisieren.
- **Schichten:** kafka (`schema_registry.rs`, gemeinsamer Request-Helfer; nur `GET` — siehe 5.1) → Bridge → Dart.

#### 5.36 `offline-schema-decoding` (M–L)

- **Warum:** Ohne Registry-Zugriff gibt es heute nur Hex (offen seit `feature-gap-analysis.md` C4).
- **Capabilities:** NEU `offline-schema-decoding`; MOD `extended-serialization-formats`.
- **Anforderungen:**
  - Je Topic SHALL für Key und Wert eine lokale Schemadatei zuweisbar sein (`.avsc`, `.proto`/Descriptor-Set,
    JSON Schema); bei Protobuf mit Auswahl des Nachrichtentyps.
  - Die Zuweisung SHALL je Cluster und Topic gespeichert werden und in Suche, Analyse und Scripts gelten.
  - Schlägt das Dekodieren fehl, SHALL die Rohdarstellung mit Fehlerhinweis erscheinen.
  - Die Schema-Herkunft SHALL „lokale Datei“ ausweisen (`message-schema-provenance`).
- **Schichten:** core (Dekodierung aus Schema-Text) → kafka → Bridge → Dart.

#### 5.37 `analysis-scope-and-history` (M)

- **Warum:** B11; der Umfang einer Analyse ist heute auf vier feste Voreinstellungen begrenzt, Vollscan ist Standard.
- **Capabilities:** MOD `topic-content-analysis`, MOD `topic-duplicate-detection`,
  MOD `topic-analysis-export-import`.
- **Anforderungen:**
  - Der Umfang SHALL über Zeitraum, Partitionsauswahl und freie Nachrichtenanzahl (neueste oder älteste)
    einstellbar sein.
  - Vor einem Scan oberhalb einer Schwelle (geschätzt aus der Offset-Spanne) SHALL die App Umfang und Hinweis zeigen
    und bestätigen lassen. Die Voreinstellung bleibt der Vollscan (E20).
  - Die Fingerprint-Menge der Duplikat-Erkennung SHALL begrenzt sein; bei Erreichen der Grenze SHALL das Ergebnis
    als „geschätzt“ markiert werden (stellt den bestehenden Spec wieder her).
  - Die letzten N Berichte je Cluster und Topic SHALL automatisch lokal gespeichert und in „Vergleichen“ und
    „Importieren“ angeboten werden; Aufräumen nach Anzahl.
  - Alle internen Kappungen (Felder, Werte je Feld, Tiefe) SHALL im Bericht ausgewiesen sein.
- **Schichten:** kafka (`TopicAnalysisOptions` additiv, Zeit → Offsets vor `assign`) → Bridge → Dart.
- **Nicht-Ziele:** Fortsetzen eines abgebrochenen Scans.

### Phase 3 — Geführte Diagnose

#### 5.12 `poison-pill-compare` (M) — benötigt 5.8

- **Capabilities:** MOD `consumer-lag-messages-view`.
- **Anforderungen:**
  - Für eine Partition mit Lag SHALL die Aktion „blockierende Nachricht vergleichen“ die Nachricht am committeten
    Offset (Kandidat) und die **letzte vorhandene Nachricht davor** laden und im Diff öffnen.
  - Existiert `O_c − 1` nicht, SHALL rückwärts in einem begrenzten Fenster gesucht werden; wird nichts gefunden,
    SHALL nur der Kandidat mit erklärendem Hinweis angezeigt werden.
  - Ist der committete Offset gleich dem Log-Ende oder kleiner als die Low Watermark, SHALL die Aktion das
    erklären statt zu laden.
  - Die Ansicht SHALL Schema-ID, Subject und Version beider Nachrichten gegenüberstellen und einen Wechsel
    hervorheben (Daten aus `message-schema-provenance`).
  - Der Vorgang SHALL keine Offsets verändern.
- **Schichten:** Dart; Rust nur, falls das Rückwärtsfenster eine neue Start-Strategie braucht.

#### 5.13 `lag-stall-detection-and-alerts` (M)

- **Capabilities:** MOD `consumer-lag-trend`, MOD `consumer-lag-monitoring`.
- **Anforderungen:**
  - Das periodische Lag-Polling SHALL in einem Controller laufen, der unabhängig von der sichtbaren Ansicht ist,
    solange der Cluster verbunden und das Intervall > 0 ist.
  - Eine Partition SHALL als *stagnierend* gelten, wenn über ein konfigurierbares Fenster der committete Offset
    unverändert bleibt, während das Log-Ende wächst.
  - Überschreitet eine Gruppe die Warnschwelle oder stagniert, SHALL die App das in der Navigation (Badge am
    Eintrag „Consumer Lag“) und in der Gruppenliste anzeigen — einmal je Zustandswechsel, nicht je Abfrage.
  - Alarme SHALL nur für die laufende Sitzung gelten; es wird nichts außer den Einstellungen gespeichert (E7).
- **Nicht-Ziele:** native OS-Benachrichtigungen (E7).
- **Schichten:** nur Dart (`features/consumer`). Achtung: Polling außerhalb der Ansicht erhöht die Last am Cluster —
  bestehende Einstellung für parallele Lag-Abfragen respektieren.

#### 5.14 `cross-topic-trace` (L) — benötigt 5.9 (Header-Scope)

- **Capabilities:** NEU `cross-topic-trace`.
- **Anforderungen:**
  - Aus einem Header- oder Payload-Wert SHALL die Aktion „über Topics verfolgen“ eine Suche vorbereiten, in der der
    Nutzer vor dem Start festlegt: Topic-Auswahl, Zeitfenster relativ zum Zeitstempel der Ausgangsnachricht
    (Standard ± 15 min), Ergebnislimit je Topic. Ohne Topic-Auswahl SHALL die Suche nicht starten.
  - Die Suche SHALL die geschätzte Scan-Menge (Offset-Spanne im Zeitfenster je Topic) vor dem Start anzeigen.
  - Ist der Wert der Message-Key, SHALL Fast Trace verwendet werden.
  - Ergebnisse SHALL als Swimlanes je Topic auf einer gemeinsamen Zeitachse erscheinen, mit Zeitabstand zwischen
    aufeinanderfolgenden Ereignissen; ein Klick öffnet den bestehenden Inspector.
  - Topic-Auswahl und Feldzuordnung SHALL als wiederverwendbare Trace-Definition speicherbar sein.
  - Die Suche SHALL abbrechbar sein und je Topic Fortschritt zeigen.
- **Schichten:** Dart (`MultiSearchController`, `messages_timeline_view.dart`); Rust nur über 5.9.
- **Nicht-Ziele:** automatische Erkennung zusammengehöriger Topics, OpenTelemetry-Anbindung, persistenter Index.

#### 5.15 `script-recipes-and-run-comparison` (M)

- **Capabilities:** NEU `script-recipe-library`, NEU `script-run-comparison`.
- **Anforderungen:**
  - Die App SHALL mitgelieferte Script-Vorlagen anbieten, die nur vorhandene Schrittarten nutzen und alle
    umgebungsspezifischen Werte (Cluster, Topics) als Parameter führen. Eine Vorlage wird beim Verwenden **kopiert**;
    Updates der App überschreiben keine Nutzer-Scripts.
  - Start-Set: DLQ-Triage (baut auf `dead-letter-queue-detection`), Stichprobe aus N Topics, Key-Verfolgung über
    mehrere Topics.
  - Zwei Läufe desselben Scripts SHALL in der Historie auswählbar und strukturiert vergleichbar sein (Nachrichten je
    Schritt: hinzugekommen, entfallen, geändert), auf Basis von 5.8.
- **Nicht-Ziele:** Lag-Snapshot-Recipe (keine Schrittart dafür, §2.3 Nr. 6); neue Schrittarten.

#### 5.38 `consumer-lag-insights` (M) — nach 5.24, sinnvoll zusammen mit 5.13

- **Capabilities:** MOD `consumer-lag-monitoring`, MOD `consumer-lag-dashboard`; NEU `topic-consumer-lookup`.
- **Anforderungen:**
  - Je Partition SHALL der Lag auf Wunsch auch als Zeit erscheinen (Alter der Nachricht am committeten Offset
    gegenüber der neuesten Nachricht); der Abruf erfolgt je Gruppe auf Anforderung, nicht bei jeder Aktualisierung.
  - Der Zustandsfilter SHALL alle tatsächlich vorkommenden Zustände anbieten; zusätzlich „nur mit Lag“, „über
    Warnschwelle“ und Suche nach Topic-Namen.
  - Die Topic-Detailansicht SHALL die konsumierenden Gruppen mit Lag je Gruppe zeigen und in die Lag-Ansicht
    springen.
  - Zustandswechsel und Änderung der Mitgliederzahl zwischen zwei Abfragen SHALL in der Gruppenzeile markiert sein;
    Partitionen ohne Besitzer SHALL bereits in der Zeile sichtbar sein.
  - Die gefilterte Lag-Tabelle SHALL als CSV und JSON exportierbar sein (mit Abfragezeitpunkt).
- **Schichten:** kafka (Zeitstempel am Offset) → Bridge → Dart.
- **Nicht-Ziele:** persistenter Lag-Verlauf (E17).

#### 5.39 `script-robustness-and-ci-expectations` (M)

- **Warum:** B12, B14; Scripts liefern in CI heute Exit-Code 0 auch bei null Treffern.
- **Capabilities:** MOD `headless-script-execution`, MOD `ergonomic-script-workspace`,
  MOD `modernized-script-and-step-editor`.
- **Anforderungen:**
  - Parameter SHALL vor dem Lauf typgerecht geprüft werden — eine gemeinsame Prüfung für Oberfläche und
    Kommandozeile; Parameter SHALL Standardwerte haben und optional sein können.
  - Ein nicht auflösbarer Start- oder Endwert SHALL den Schritt fehlschlagen lassen; es gibt keinen stillen
    Rückfall auf den Topic-Anfang.
  - Ein Schritt SHALL optionale Erwartungen tragen (Mindest-/Höchstzahl Treffer, Variable wurde extrahiert), die
    Schrittstatus und Exit-Code bestimmen.
  - Fehler SHALL je Topic erhalten bleiben; ein abgebrochener Schritt SHALL nicht als abgeschlossen gelten.
  - Gespeicherte Scripts SHALL eine Formatversion tragen; exportierte Script-Dateien SHALL unverändert per
    `--script <pfad>` lauffähig sein; ein Import SHALL ein vorhandenes Script aktualisieren können.
  - Die Kommandozeile SHALL unbekannte Optionen abweisen, ein fehlendes Ausgabeverzeichnis benennen,
    Schrittnamen in der Ausgabe führen und auf Abbruchsignal sauber beenden.
  - Es SHALL genau einen dokumentierten Headless-Einstieg geben: das GUI-Binary mit `--script`.
    `bin/kafkalyzer_script.dart` wird entfernt (E19); der Befehl „CLI-Kommando kopieren“ SHALL diesen Einstieg
    erzeugen.
- **Folgeanforderung (nach 5.16):** Profilquelle aus Datei/Umgebung für CI ohne Schlüsselbund, gemeinsam mit E4.
- **Nicht-Ziele:** neue Schrittarten, Bedingungen/Schleifen, Zeitplanung.

### Phase 4 — Headless & MCP (freigegeben, E18)

#### 5.16 `mcp-profile-export` (M)

- **Capabilities:** NEU `headless-profile-export`.
- **Anforderungen:**
  - In den Cluster-Einstellungen SHALL je Profil ein Schalter „für MCP/CLI freigeben“ existieren, Standard aus.
  - Freigegebene Profile SHALL ohne Secrets in eine Datei im Konfigurationsverzeichnis des Nutzers geschrieben
    werden; Secrets SHALL im OS-Schlüsselbund unter einem eigenen Dienstnamen liegen (E4).
  - Änderungen und das Löschen eines Profils oder der Freigabe SHALL Datei und Schlüsselbund-Einträge nachziehen.
  - Die Ansicht SHALL das Konfigurations-Snippet für gängige MCP-Clients zum Kopieren anbieten und den Hinweis auf
    den Datenabfluss an LLM-Anbieter zeigen.
- **Schichten:** `kafkalyzer-profiles` (neu) → Bridge → Dart (`features/cluster`, `features/settings`).

#### 5.17 `mcp-stdio-server` (L) — benötigt 5.1, 5.16

- **Capabilities:** NEU `mcp-server`.
- **Anforderungen:**
  - Ein eigenständiges Binary `kafkalyzer-mcp` SHALL MCP über stdio bereitstellen, ohne laufende GUI.
  - MVP-Tools (E10): `kafka_list_clusters`, `kafka_test_connection`, `kafka_list_topics`,
    `kafka_list_consumer_groups`, `kafka_get_consumer_lag`, `kafka_consume_messages`, `kafka_search_messages`,
    `kafka_inspect_lagging_message`, `kafka_analyze_topic`, `kafka_list_schemas`, `kafka_get_schema`,
    `kafka_calculate_partition`.
  - Jedes Tool SHALL das Pflichtset aus §4.3 einhalten; `kafka_list_clusters` SHALL nur Namen und nicht-geheime
    Metadaten liefern.
  - Die Handler SHALL als Bibliotheksfunktionen vorliegen, die Transport-unabhängig testbar sind
    (Sammel-Varianten der Streaming-Funktionen mit Timeout und Abbruch).
  - Integrationstests SHALL gegen den Stack aus `docker-compose.yaml` laufen.
  - Das Binary SHALL in `build.yml` für alle drei Plattformen gebaut und den Release-Paketen beigelegt werden.
- **Schichten:** `kafkalyzer-mcp` (neu), `build.yml`. Keine Änderung an der GUI.
- **Folge-Change `mcp-extended-tools` (M):** `kafka_diff_messages` (5.8), strukturierter Filter als Tool-Parameter
  (5.9), `kafka_get_topic_config` (5.10), Prompts `diagnose-consumer-lag` und `trace-event-flow`, Resources.

### Zurückgestellt — Remote-Betrieb (nicht eingeplant, E8)

Die folgenden drei Einträge sind **nicht** Teil der Roadmap und dürfen nicht als OpenSpec-Change angelegt werden,
solange E8 gilt. Sie bleiben als Ausgangspunkt erhalten, falls ein Bedarfsträger auftritt.

#### 5.18 `backend-abstraction` (M–L)

- **Capabilities:** keine fachliche Änderung; ein technischer Spec `kafka-backend-abstraction` hält die Naht fest.
- **Anforderungen:** siehe §4.4. Das Verhalten der App SHALL unverändert bleiben; alle bestehenden Tests SHALL ohne
  inhaltliche Anpassung bestehen. Kein direkter Aufruf generierter Bridge-Funktionen außerhalb von
  `lib/src/backend/` (per Lint oder Grep-Check abgesichert).

#### 5.19 `kafkalyzer-server` (L)

- **Capabilities:** NEU `remote-server`, MOD `mcp-server` (HTTP-Transport), MOD `read-only-security-guidance`.
- **Anforderungen (Mindestumfang, vor Umsetzung im Design zu vertiefen):**
  - HTTP/JSON-API mit versioniertem Pfadpräfix; Streams als NDJSON; Abbruch durch Schließen der Verbindung (E9).
  - Authentifizierung per OIDC; Autorisierung mindestens je Cluster, konfigurierbar je Topic-Präfix. Ohne gültige
    Identität SHALL kein Endpunkt außer Health erreichbar sein.
  - Audit-Log je Anfrage: Identität, Cluster, Topic, Operation, Zeit — ohne Payloads.
  - Limits je Identität: parallele Scans, maximale Scan-Dauer, maximale Antwortgröße.
  - Cluster-Profile und Secrets ausschließlich aus Umgebung/Secret-Mounts; kein Endpunkt gibt Secrets zurück.
  - Der Server SHALL seine API-Version melden; die App SHALL bei inkompatibler Version verständlich abweisen.
  - MCP unter `/mcp` (Streamable HTTP) mit derselben Authentifizierung und dem Pflichtset aus §4.3.
  - Container-Image und Helm-Chart; Container-Job in `build.yml`.
- **Verbleibt lokal im Client:** Scripts und deren Ausführung, Saved Searches, Spalten-Presets, Exporte.

#### 5.20 `remote-cluster-profiles` (M) — benötigt 5.18, 5.19

- **Capabilities:** MOD `cluster-profile-persistence`, MOD `ergonomic-settings-and-cluster-onboarding`.
- **Anforderungen:** Profiltyp „kafkalyzer-Server“ (URL + Anmeldung, Token im OS-Schlüsselbund); die auf dem Server
  verfügbaren Cluster erscheinen als wählbare Ziele; alle Ansichten funktionieren ohne Sonderfälle über die Naht
  aus 5.18; Funktionen, die es remote nicht gibt, sind sichtbar deaktiviert statt fehlerhaft.

---

## 6. Roadmap

### 6.1 Phasen

| Phase | Inhalt | Changes | Aufwand | Ergebnis |
|---|---|---|---|---|
| **0a Sicherheit & Datenverlust** | TLS-Prüfung, Importe, Speicher, Gate, DLQ-Replay entfernen | 5.21, 5.22, 5.1, 5.40 | 2×M + 2×S | Keine stille Unsicherheit, kein stiller Datenverlust |
| **0b Korrektheit** | Falsche Anzeigen beheben, Doku berichtigen | 5.24, 5.23, 5.2 | M + 2×S | Lag-Werte und Fehlerzustände sind verlässlich |
| **1a Tagesarbeit** | Nachrichten, Profile, Diagnose | 5.27, 5.28, 5.26, 5.25, 5.3 | 4×M + S–M | Kopieren, Auswählen, Exportieren, PROD-Kennzeichnung, sichtbares Log |
| **1b Komfort** | Viewer, Palette, Einstellungen | 5.5, 5.29, 5.30, 5.4, 5.6, 5.7, 5.31, 5.32 | 6×M + S + S–M | Kein 500k-Limit, Live-Tail-Steuerung, sicherer Team-Export |
| **2a Explorer & Schema** | Skalierung, Übersicht, Schema-Typen | 5.33, 5.11, 5.34, 5.10, 5.35, 5.37 | 4×M + S + L | Große Cluster bedienbar, Schema-Sicht jenseits von Avro |
| **2b Analysekern** | Wiederverwendbare Rust-Bausteine | 5.8, 5.9, 5.36 | M + L + M–L | Diff und Filter im Kern, Dekodierung ohne Registry |
| **3 Geführte Diagnose** | Workflows auf den Bausteinen | 5.38, 5.13, 5.12, 5.14, 5.39, 5.15 | 5×M + L | Lag als Zeit, Poison-Pill-Vergleich, Trace über Topics, CI-taugliche Scripts |
| **4 Headless & MCP** | Lokaler MCP-Server | 5.16, 5.17, danach `mcp-extended-tools` | M + L + M | `kafkalyzer-mcp` in den Release-Paketen |

### 6.2 Abhängigkeiten

```text
5.1 harden-read-only-gate ─────────────────────────────┐
5.8 structural-message-diff ──► 5.12 poison-pill-compare│
                            ├─► 5.15 script-run-comparison
                            └─► mcp-extended-tools      │
5.9 structured-message-filter ─► 5.14 cross-topic-trace │
                              └─► mcp-extended-tools    │
5.10 topic-config-inspection ──► mcp-extended-tools     │
5.16 mcp-profile-export ──► 5.17 mcp-stdio-server ◄─────┘

5.1 harden-read-only-gate ──► 5.40 remove-dlq-replay-command ──► 5.27 message-selection (kcat -C)
5.21 restore-tls-verification ──► 5.3 connection-diagnostics
5.22 harden-local-storage ──► 5.26 cluster-profile-ergonomics (eindeutige Namen), 5.7 encrypted-profile-export
5.24 fix-consumer-lag-accuracy ──► 5.38 consumer-lag-insights ◄── 5.13 (Controller)
5.27 message-selection ──► 5.28 message-export-fidelity („nur Auswahl“)
5.11 partition-offset-distribution ──► 5.34 cluster-overview-and-topic-facts, 5.37 (Umfangsschätzung)
5.35 schema-type-awareness ──► 5.36 offline-schema-decoding (gemeinsames Typmodell)
5.39 script-robustness ──► 5.15 script-recipes (Vorlagen nutzen Erwartungen und Standardwerte)
```

Nicht genannte Changes sind voneinander unabhängig. Innerhalb einer Teilphase ist die Reihenfolge in der Tabelle
§6.1 die empfohlene.

### 6.3 Reihenfolge-Regeln

1. Phase 0a und 0b zuerst (E14). 5.21 steht an erster Stelle; es ist der einzige Befund, der die
   Sicherheitsaussage des Produkts heute widerlegt.
2. Innerhalb eines Changes: Rust-Crates → Bridge-Generierung → Dart (Regel aus `openspec/config.yaml`), je Schritt
   kompilieren und testen.
3. Ein Baustein wandert erst in den Rust-Kern, wenn ein zweiter Abnehmer feststeht (`mcp-server-feasibility.md` §9.5).
   Für Diff und Filter ist das mit Phase 3 gegeben.

### 6.4 Abnahme je Phase

- **Jede Phase:** `scripts/check_read_only.sh` grün, `cargo test`, `flutter analyze`, `flutter test`, en/de-ARB
  vollständig.
- **Phase 2:** Unit-Tests für Parser/Auswertung (`filter_expr`) und Diff im Core; gespeicherte Suchen und Scripts im
  alten Format laden unverändert.
- **Phase 4:** Integrationstest gegen `docker-compose.yaml`; Test, dass kein Tool Secrets oder ungekappte Payloads
  liefert.
- **Phase 4 zusätzlich:** Lauf gegen einen Broker mit Read-only-Service-Account als Nachweis (steht seit
  `feature-gap-analysis.md` §7 aus).

---

## 7. Nicht-Ziele

- Jede Schreibfunktion gegen Kafka oder die Schema Registry (L1).
- Eigene „Multi-Search“-Destination (L6); Topic-Kombinationen als Saved Search.
- MCP-Listener im GUI-Prozess (E3); MCP-Tool für Script-Ausführung (E10).
- Persistente Alarmierung, Zeitreihenspeicher, Hintergrunddienst, native OS-Benachrichtigungen (E7).
- Remote-Server, Backend-Naht und Remote-Profile (E8).
- CEL/JMESPath oder eine zweite Pfadsyntax (E5, L7).
- Flutter-Web (E12).
- Umzug oder Umbenennung bestehender Crates und Verzeichnisse (E2).
- Kafka-Connect-/ksqlDB-Oberflächen (`feature-gap-analysis.md` §5.3).
- Fünfte Navigations-Destination für Schemas oder Cluster-Übersicht (E16).
- Persistenter Lag-Verlauf (E17); Fortsetzen abgebrochener Analysen; neue Script-Schrittarten, Bedingungen,
  Zeitplanung.
- Mehrere gleichzeitig aktive Cluster oder Mehrfenster-Betrieb — nicht untersucht, kein Bedarf belegt.
- Proxy-/SOCKS-Unterstützung — librdkafka bietet dafür keinen allgemeinen Mechanismus.

---

## 8. Offen und nicht geprüft

**Beim Planen der OpenSpec-Changes gefundene Abweichungen (ohne eigenen Change):**

- Quick Jump (`Strg+G`) erfüllt `shareable-message-references` nicht: wirkt nur mit Fokus im Explorer und springt
  nicht auf Partition/Offset (festgestellt in `command-palette`).
- `app_en.arb`/`app_de.arb` definieren `matchesCount`, `noDifferencesFound`, `noVariablesRequired` doppelt (wird in
  5.32 behoben).
- Rust-`init_app()` wird nie aufgerufen; der `logger` loggt in Release-Builds nichts (wird in 5.25 behoben).

**Offene Entscheidungen:** keine. Alle Entscheidungen in §3 sind getroffen; die verbleibenden Punkte unten sind
technische Klärungen, die im jeweiligen Change als Spike vorgesehen sind.

**Nicht geprüft in diesem Review:**

- Ursache des Windows-`cacert.pem`-Bedarfs in Debug-Läufen (Spike in 5.21). Die Aussage zum Windows-Zertifikatspeicher
  von librdkafka ist aus der Bibliotheksdokumentation übernommen, nicht am Build verifiziert.
- Ob die In-Memory-Suche der Ergebnisliste Header bereits berücksichtigt; geprüft wurde nur der Broker-Scan
  (`SearchScope`).
- Ob das GUI-Binary mit `--script` auf einem Linux-System ohne Display und ohne Schlüsselbund-Dienst startet
  (relevant für CI, 5.39).
- Ob librdkafka-Fehler TLS- und SASL-Fehlschläge auf allen drei Plattformen unterscheidbar melden (bestimmt die
  Trennschärfe von 5.3).
- Verfügbarkeit und Reifegrad der Crates `age`, `keyring` und eines MCP-SDK (`rmcp`) für die Windows-/macOS-Builds
  der bestehenden CI-Matrix.
- Aufwandsklassen sind Schätzungen ohne Prototyp.
- Alle mit ◦ markierten Befunde in §2.4: aus Code-Lektüre übernommen, Zeilen nicht einzeln nachgeprüft. Vor dem
  jeweiligen Change am Symbolnamen verifizieren.
- Skalierungs- und Speicheraussagen (5.33, 5.37, 5.29) stammen aus dem Code, nicht aus Messungen.
- Ob die eingesetzte rdkafka-Version Cluster-ID, Controller, Broker-Version und die Offsets mitgliederloser Gruppen
  lesend liefert (5.24, 5.34).
- Ob die nativen Runner (`linux/`, `windows/`, `macos/`) Fenstergeometrie bereits speichern (5.31).
- Nicht gelesen: `messages_diff_view.dart`, `script_editor.dart`, die Analyse-Diagramme, SSL-/SASL-Formulare,
  sämtliche Tests. Vorschläge in diesen Bereichen können bereits Vorhandenes berühren.
