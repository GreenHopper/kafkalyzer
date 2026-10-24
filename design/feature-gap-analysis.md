# kafkalyzer — Funktionsumfang, Verbesserungsvorschläge & fehlende Funktionen

Stand: Quelltextanalyse auf `73a6155`. Basis: `lib/src` (43.7k Zeilen Dart), `rust/` (5.8k Zeilen Kern), `openspec/specs` (33 umgesetzte Capability-Specs).
Andere Dokumentationen werden nur referenziert, nicht dupliziert: UI/UX-Audit (`ui_ux_audit_und_onboarding_konzept.md`), Performance (`rust-performance-improvements.md`), MCP/CLI (`mcp-server-feasibility.md`).

**Grundprinzip des Projekts:** kafkalyzer ist ein Analyzer. Schreibfunktionen gegen Kafka sind per Design ausgeschlossen (kein Produce/Replay, kein Offset-Reset, kein Topic-CRUD, keine Config-Änderungen), damit die App an Produktiv-Clustern gefahrlos einsetzbar ist. Dieser Grundsatz steht über jedem Vorschlag in diesem Dokument.

---

## 0. Top 5 zuerst

| # | Maßnahme | Typ | Aufwand |
|---|---|---|---|
| 1 | **Profilfelder fehlen beim Speichern** — SASL-Kerberos/OAuth, PEM-mTLS und Schema-Registry-Auth überleben einen Neustart nicht (`lib/src/services/cluster_service.dart:32`). | Defekt | 20 Min |
| 2 | **Read-only ist nicht abgesichert** — der Kern ist heute read-only (kein Producer, keine Commits), aber nichts verhindert, dass später ein Schreibpfad eingebaut wird. CI-Gate + Doku fehlten bisher. | Härtung | 1–2 Stunden |
| 3 | **Keine Partition-Gesundheit** — Leader, Replicas, ISR und under-replicated Partitionen fehlen komplett (`kafka_metadata.rs:10` `TopicMetadata` hat 5 Felder). | Verbesserung | 0,5 Tag |
| 4 | **Schema-ID bleibt unsichtbar** — im Decode-Pfad wird `schema_id` aufgelöst (`kafka_consumer.rs:1264`), aber weder Message-Inspector noch Analyse zeigen Subject/Version der Nachricht. | Verbesserung | 0,5–1 Tag |
| 5 | **Offene Hot-Path-Kosten**: `block_on` mitten im Decode-Loop (`kafka_consumer.rs:980/1272/1292/1298/1339/1361/1371`) und `Runtime::new()` pro Aufruf (`schema_registry.rs:62`, `kafka_metadata.rs:35`), dazu pro Match ein formatierter Log mit vollständigem Payload (`kafka_consumer.rs:1455`). | Defekt/Perf | 1–2 Tage |

---

## 1. Was bereits erledigt ist (nicht doppelt fordern)

Das UI/UX-Audit aus `design/ui_ux_audit_und_onboarding_konzept.md` ist abgearbeitet: `explorer-onboarding`, `compact-topic-sidebar`, `unified-results-toolbar`, `integrated-schema-inspector`, `search-configuration-panel`, `collapsible-sidebars` und `message-inspector-shell` existieren als Specs unter `openspec/specs/`.
Die Perf-Doku ist teils umgesetzt: Release-Profil (`lto = "fat"`, `panic = "abort"`), Regex-Vorkompilierung (`kafka_consumer.rs:638`), Dart-Throttling mit 60 ms Timer (`message_stream_controller.dart:201`) und gecachte unmodifiable Listen.
L10N ist vollständig: `app_en.arb` und `app_de.arb` haben je 479 Keys, keine Lücken.

---

## 2. Ist-Inventar der Funktionen

| Bereich | Was vorhanden ist | Beleg |
|---|---|---|
| Cluster & Auth | Multi-Profile, PLAINTEXT/SSL/SASL\*, PLAIN/SCRAM/GSSAPI/OAUTHBEARER/MSK, PEM-mTLS und JKS, Schema-Registry mit Basic-Auth, Verbindungsprobe | `kafka_utils.rs:149`, `kafka_types.rs:4` |
| Topic-Metadaten | Topic-Liste mit Partition Count, RF, `cleanup.policy`, `retention.ms` | `kafka_metadata.rs:10/26` |
| Konsum & Suche | Start earliest/latest/tail/offset/timestamp, Ende EOF/Offset/Timestamp/Limit/Live, Partition-Zielwahl, `fast_trace_key` (Murmur2), Contains/Regex/Exact, JSON-Pointer-Feldfilter, Limit fair über Partitionen verteilt | `kafka_consumer.rs:83` |
| Message-Inspection | Andockbarer Split-Screen-Inspector, Stepper, In-Inspector-Suche, Shortcuts, Tabs für Payload/Headers/Metadaten, Hex/UTF-8/Tombstone, virtueller JSON-Baum mit Kontext-Fenster, Pin auf Spalten, Diff- und Timeline-Ansicht, Clipboard-Copy | `openspec/specs/message-inspector-shell`, `smart-virtual-json-tree` |
| Decodierung | Confluent Wire-Format, Avro (inkl. logischer Typen), Protobuf, Confluent JSON Schema, rohes JSON, Header-Decoding | `extended-serialization-formats`, `avro_utils.rs` |
| Topic-Analyse | Volumen/Bytes, min/max/avg Größe, Tombstone-Anteil, Partitionsskew, Stunden-Histogramm, Top-Keys, Feldfrequenzen mit Top-Werten und Typverteilung, Fortschritt + Abbruch, Report-Export/-Import als JSON | `kafka_analyzer.rs:530`, `topic_analysis_report_file.dart` |
| Consumer-Lag | Gruppenübersicht (State, Protokoll, Member-Count), Lag pro Partition, KPI-Dashboard mit Lag-Delta, konfigurierbare Query-Konkurrenz, Nachricht am `current_offset` („Poison Pill") | `kafka_metadata.rs:204/394/474` |
| Scripting | Mehrstufige Pipelines mit JSONPath-Extraktion und `{{var}}`-Substitution, Lauf-Historie, Parametern, Output-Diffing, Einheitsausgabeverzeichnis | `script_runner.dart`, `ergonomic-script-workspace` |
| Export | JSON pro Topic, ZIP bei mehreren Topics, Profil-Backup inkl. Zertifikaten und Scripts | `message_export_service.dart`, `settings_service.dart` |
| Betrieb | Auto-Update via Velopack (AppImage/Installer), Release-Matrix Linux/macOS/Windows, Test-Basis: 101 Dart-Testdateien, 49 Rust-Testfunktionen, CI mit Pflicht-Tests | `update_service.dart`, `.github/workflows/build.yml` |
| **Read-only-Status (geprüft)** | rdkafka-Nutzung beschränkt sich auf `BaseConsumer` und `AdminClient::describe_configs`. Kein Producer-Typ im Code. `enable.auto.commit=false` an Consumer- und Analyse-Pfaden. Fremde Consumer-Gruppen werden nur per `committed_offsets` gelesen, nie joined (`subscribe()` hat 0 Treffer) → kein Rebalance-Risiko in Produktivgruppen. | `kafka_metadata.rs:4/20/36/335`, `kafka_analyzer.rs:555`, `kafka_consumer.rs:305` |

---

## 3. Abschnitt A — Defekte, die vor neuen Features repariert gehören

1. **Profilfelder gehen verloren.** `ClusterService.saveClusters` serialisiert über die Extension `ClusterProfileExtension.toJson` (`cluster_service.dart:32`). Die `ClusterProfile`-Klasse selbst hat kein `toJson`, also greift die Extension — und die kennt nur 11 der 21 Felder. `saslKerberos*`, `saslOauthbearerToken`, `schemaRegistryUsername/Password`, `sslPem*` und `sslKeystore`-Ergänzungen werden beim Speichern stillschweigend `null`. Folge: Cluster mit Kerberos/OAuth/PEM müssen nach jedem Neustart neu eingetragen werden. Fix: Extension durch vollständige Serialisierung ersetzen (Idealfall generiert oder explizite Feldliste) + Roundtrip-Test. `test/src/services/cluster_service_test.dart` deckt die neuen Felder nicht ab. **20 Minuten.**
2. **Regex-Fehler werden verschluckt.** Filtert ein Nutzer einen ungültigen Regex, läuft `matches_filter` im Fallback still auf `contains` zurück (`kafka_consumer.rs:1444-1448`) — das Suchergebnis sieht plausibel aus, ist aber falsch. Zusätzlich kompiliert der Fallback pro Nachricht neu. Fix: Regex beim Eingeben validieren und Fehler in der Suche-Oberfläche zeigen, im Kern nur noch vor-kompilierte Patterns akzeptieren. **2–4 Stunden.**
3. **Payload-Logging pro Match.** Bei jedem Treffer wird ein formatierter Log-String mit vollständigem Target, Term-Bytes und Key über den Stream nach Dart geschickt (`kafka_consumer.rs:1455`). Bei Scans mit vielen Treffern skaliert das linear über Payload-Größe und bläht die Bridge. Fix: Log auf Treffer-Kopfzeile (Partition/Offset/Term) reduzieren, Volltext nur bei eingeschaltetem Debug-Modus. **2 Stunden.**
4. **Runtime-Overhead pro Aufruf.** `Runtime::new()` in `schema_registry.rs:62/86` und `kafka_metadata.rs:35` plus `block_on` im Decode-Loop (`kafka_consumer.rs:980`, `1272`ff). Öffnet pro Aufruf einen Tokio-Runtime-Kern und blockiert den Poll-Loop auf Netzwerk-Schema-Fetches. Fix: geteilte Runtime (static) + Schema-Cache vor Schleifenbeginn. **1–2 Tage.**
5. **Vier JSONPath-Implementierungen, beworbene Syntax bricht.** `json_path_extractor.dart` (Dot + `items[0]`), `extraction_utils.dart:29` (nur Dot), `script_runner.dart:1002` (private Kopie, nur Dot) und der Rust-`filter_field` mit JSON Pointer (`kafka_consumer.rs:1417`). Das UI verspricht `JSONPath (e.g. $.id)` (`lib/l10n/app_en.arb:720`), aber keine Implementierung entfernt das `$` → solche Pfade liefern still `null`, und Array-Indizes funktionieren in der Tabellenspalte, aber nicht im Script. Fix: eine Implementierung in `kafkalyzer-core`, alle vier Aufrufer umstellen (Details in `mcp-server-feasibility.md` §9.2). **0,5–1 Tag.**

---

## 4. Abschnitt B — Verbesserungsvorschläge für bestehende Funktionen

### Gruppe 1: Metadaten & Diagnose (größter Erkenntnisgewinn pro Zeile Code)

| Vorschlag | Warum | Wo ansetzen | Aufwand |
|---|---|---|---|
| **B1. Partitionsgesundheit anzeigen**: Leader, Replicas, ISR, under-replicated, offline Partitionen je Topic. `grep` nach `leader\|isr` im Kern: 0 Treffer. | Höchste Alarmstufe in Prod („warum fehlt ein Broker?") ist heute nicht beantwortbar. rdkafka liefert die Daten bereits im Metadata-Response. | `kafka_metadata.rs:10` + Explorer-Tab | 0,5 Tag |
| **B2. Member-Sicht im Consumer-Lag**: Client-ID, Host, Zuordnung Member → Partitionen. Die Bytes werden schon geparst (`parse_member_subscription` / `parse_member_assignment`, `kafka_metadata.rs:117/154`), aber auf Topic-Listen und `members_count` reduziert. | „Welcher Pod hängt?" ist die häufigste Lag-Frage nach der Lag-Zahl. Daten sind vorhanden, nur verworfen. | `ConsumerGroupLag` (`kafka_types.rs:71`) + `consumer_lag_view.dart` | 0,5 Tag |
| **B3. Schema-Herkunft pro Nachricht**: Subject, Version, Schema-ID einer Nachricht anzeigen; Klick öffnet den bestehenden Schema-Inspector. `schema_id` wird aufgelöst (`kafka_consumer.rs:1264`) aber nicht ausgegeben. | Ohne Version ist nicht erkennbar, ob ein Consumer ein altes Schema liest — typische Ursache für „passt nicht"-Meldungen. | `KafkaMessage` um Option-Felder erweitern, Inspector-Header | 0,5–1 Tag |
| **B4. Analysebericht erweitern**: p50/p95/p99 Message-Größe, geschätzte Unique-Key-Anzahl, und **Vergleich zweier Reports** (Diff zweier Analyse-Snapshots). Reports sind bereits JSON-Dateien mit stabillem Schema. | Der Durchschnitt verschleiert Ausreißer; der Report-Vergleich beantwortet „was hat sich seit gestern geändert?" ohne neue Erhebung. | `kafka_analyzer.rs:323` (`to_report`), `topic_analysis_report_file.dart` | 0,5 Tag (Perzentile) + 0,5 Tag (Report-Diff) |
| **B5. Lag-Trend pro Gruppe** statt nur Gesamt-Lag-Delta: Mini-Sparkline pro Gruppe über die letzten Abfragen, Warnschwelle als Setting. | Der Trend entscheidet, ob Lag ein Problem ist; eine Zahl ohne Verlauf nicht. Bestehende KPI-Karten liefern die Datenbasis. | `consumer_lag_view.dart`, Setting `consumer_lag_warn_threshold` | 0,5–1 Tag |

### Gruppe 2: Datenpfad & Workflows

| Vorschlag | Warum | Wo ansetzen | Aufwand |
|---|---|---|---|
| **B6. CSV-Export** neben JSON/ZIP, mit den sichtbaren (projizierten) Spalten. | JSON-Export ist für Excel/BI-Weiterverarbeitung unbrauchbar; die Spalten-Config existiert bereits als Quelle. | `message_export_service.dart:35` | 2–4 Stunden |
| **B7. Gespeicherte Suchen** pro Topic (Filter + Scan-Modus + Spalten) wiederverwendbar machen. Spalten-Presets werden pro Topic gespeichert, die Filterparameter nicht. | Dieselbe Suche wird im Schichtbetrieb wiederholt; heute hilft nur ein Saved Script (Overkill für eine Einzelsuche). | `recent_topics_service.dart` (Muster), `search_configuration_panel` | 0,5 Tag |
| **B8. Sitzung wiederherstellen**: offene Topics/Tabs nach Neustart öffnen. `active_connection_controller.dart` hält `openTopics` nur im Speicher; `recent_topics` ist das halbe Prinzip. | Nach jedem Restart ist die Ausgangslage weg — Startaufwand, der sich täglich wiederholt. | `active_connection_controller.dart` + prefs-Key | 0,5 Tag |
| **B9. Script-Läufe headless ausführbar machen** (Parameter aus Datei/Env, Exit-Code, JSON-Ausgabe) — teilt sich die Logik mit dem geplanten CLI/MCP (`mcp-server-feasibility.md` §6). | Skripte sind heute an die GUI gebunden; für wiederkehrende Audits und CI bräuchte es dieselbe Pipeline ohne Klicks. | Extraktion der Pipeline-Logik aus `script_runner.dart` | 1–2 Tage |
| **B10. Secrets in den OS-Keyring** statt `shared_preferences` im Klartext (SASL-Passwort, Keytab-Pfade, OAuth-Token, Profil-Export als ZIP). | Das Tool verwaltet Produktiv-Zugänge; Klartext am Datenträger ist der einzige Fund in der Sicherheitsbetrachtung, den man ohne Funktionsänderung beheben kann. | `cluster_service.dart`, `settings_service.dart:109` | 1 Tag |

---

## 5. Abschnitt C — Fehlende Funktionen

Nach Nutzen pro Aufwand sortiert. Bewusst ohne die Punkte, die ein Desktop-Client nicht braucht (§5.3).

### 5.1 Schreiben: per Design ausgeschlossen — aber nicht durchgesetzt

Produzieren, Replay, Offset-Reset und Topic-Verwaltung sind bewusst keine Kandidaten. Der aktuelle Zustand ist read-only, das ist aber eine Gewohnheit, keine Eigenschaft des Builds:

| Maßnahme | Warum | Wo ansetzen | Aufwand |
|---|---|---|---|
| **C1. CI-Gate gegen Schreibpfade.** Skript, das `Producer`, `ThreadedProducer`, `FutureRecord`, `.send(` auf Kafka-Clients, `subscribe(` und `commit` in `rust/*/src` verbietet und den Build fehlschlagen lässt. | Ein einziger Import von `rdkafka::producer` macht die Produktivzusicherung unwirksam. Ohne Gate erkennt das kein Review. | `scripts/check_read_only.sh` + Job in `.github/workflows/build.yml` | 1–2 Stunden |
| **C2. Read-only als dokumentierte Eigenschaft.** README-Abschnitt „Read-only by design“ mit der nachprüfbaren Liste (nur `BaseConsumer`, nur `describe_configs`, keine Commits), plus Hinweis in den Cluster-Einstellungen. | Das Alleinstellungsmerkmal gegenüber anderen Kafka-Clients ist derzeit nirgends nachlesbar — weder für Nutzer noch für Security-Reviews. | `README.md`, `cluster_config_dialog.dart` | 1–2 Stunden |
| **C3. Read-only-Service-Account empfehlen.** Im Cluster-Dialog und in der Doku: SASL-User mit `Describe` + `Read` + `DescribeConfigs` ohne `Write`/`AlterConfigs`. | Der stärkste Hebel sitzt beim Cluster: selbst bei einem zukünftigen Bug kann der Broker das Schreiben nicht annehmen. | Settings-Text, `README.md` | 1 Stunde |

Folgemaßnahme für Nutzer, die Reprocessing brauchen: DLQ-Retest läuft extern (kcat, eigenes Tool). C6 (Retry-/DLQ-Erkennung, unten) macht die fehlerhafte Nachricht sichtbar und kopierbar, verschiebt sie aber nicht.

### 5.2 Weitere Lücken, geordnet

1. **C4. Offline-Decodierung ohne Schema Registry.** Avro-Schema-Datei oder `FileDescriptorSet` (.desc) lokal laden und damit Nachrichten dekodieren. Aktuell läuft jede strukturierte Decodierung über die Registry (`schema_registry_converter`), Umgebungen ohne Registry-Zugriff liefern nur Hex. Aufwand: 1–2 Tage.
2. **C5. Schema-Workflows.** Kompatibilitätscheck gegen eine Subject-Version (`/compatibility`-Endpoint ist in `schema_registry.rs` ansetzbar), Diff zweier Schema-Versionen (Textdiff-Komponenten vorhanden), „welche Themen nutzen dieses Schema". Aufwand: 1–2 Tage.
3. **C6. Retry-/DLQ-Erkennung.** Anhand von Topic-Namensmustern (`*-retry`, `*-DLQ`) und Header-Signaturen zusammengehörige Topics in einer Gruppe anzeigen und die fehlerhafte Nachricht direkt im DLQ-Kontext öffnen. Baut auf vorhandener Topic-Sidebar auf. Aufwand: 0,5–1 Tag.
4. **C7. Teilbarer Verweis** auf Topic + Partition + Offset + Filter als kopierbarer String (Wieder-Import in eine andere Instanz). Gibt es heute nicht; die Profil-Backup-Mechanik zeigt den Importpfad. Aufwand: 0,5 Tag.
5. **C8. Headless-Zugriff (CLI, optional MCP-Server).** Bereits analysiert in `design/mcp-server-feasibility.md` — der Read-only-Kern ist dafür fertig; nur Profilquelle und Truncation fehlen. Aufwand: 2–3 Tage.
6. **C9. Update-Hinweis für Linux ohne AppImage.** Velopack greift nur bei `$APPIMAGE` (`update_service.dart:73`); bei tar/deb/snap-Installation fehlt jede Update-Rückmeldung. Kleiner Hinweis mit Release-Link genügt. Aufwand: 1–2 Stunden.

### 5.3 Bewusst nicht empfohlen

* **Alle Schreibfunktionen** (Produzieren/Replay, Offset-Reset, Topic-CRUD, Config-Änderungen, ACL-Verwaltung): per Design ausgeschlossen, nicht zurückgestellt. kafkalyzer analysiert; Schreiben bleibt dedizierten Tools überlassen.
* Kafka-Connect- und ksqlDB-Oberflächen: eigene Produkte, kein Diagnose-Mehrwert für die bestehenden Workflows.
* Alarmierungs-Engine oder Persistenz-Layer (Timeseries, Benachrichtigungen): macht aus einem Desktop-Client einen Server; Lag-Trend (B5) deckt den Bedarf lokal ab.
* Web-Port oder Team-Server: würde Authentifizierung, Mehrbenutzerdatenhaltung und Deployment einführen, die zum jetzigen Zeitpunkt niemand angefragt hat.

---

## 6. Empfohlene Reihenfolge

| Block | Inhalt | Aufwand |
|---|---|---|
| **Block 1** (Defekte, keine neuen Konzepte) | A1 Profilfelder, A2 Regex-Validierung, A3 Match-Logging, A5 JSONPath vereinheitlichen — ✅ umgesetzt (OpenSpec-Change `fix-profile-search-and-jsonpath-defects`) | 1 Tag |
| **Block 2** (Diagnosewert, kleiner Diff) | B1 Partitionsgesundheit, B2 Member-Sicht, B3 Schema-Herkunft | 1,5–2 Tage |
| **Block 3** (Arbeitserleichterung) | B6 CSV, B7 gespeicherte Suchen, B8 Sitzung, C9 Update-Hinweis | 1,5 Tage |
| **Block 4** (Zusicherung) | C1 CI-Gate, C2 README/Einstellungs-Hinweis, C3 Service-Account-Empfehlung | 0,5 Tag |
| **Block 5** (Nach Bedarf) | A4 Runtime/Caching, B4/B5, C4 Offline-Decodierung, B10 Keyring, C8 CLI/MCP | je 0,5–3 Tage |

---

## 7. Nicht geprüft

* Die Profilfeld-Lücke (A1) war aus dem Code geschlossen (`toJson`-Extension vs. Klassenfelder). Nach dem Fix belegt ein Roundtrip-Test über die Bridge alle 21 Felder und ein Legacy-Test die alte 11-Key-Form; ein Roundtrip gegen eine `shared_preferences`-Datei einer echten Installation fehlt weiterhin.
* A2/A3 sind durch Tests abgedeckt (Setup-Fehler statt Substring-Fallback, Diagnosezeile ohne Payload/Key). Keine Messung der Hot-Path-Kosten aus A4 — die Einordnung kommt aus Code-Stellen und der bestehenden Perf-Analyse, nicht aus einem Profil-Durchlauf.
* Der Read-only-Status ist per grep belegt (kein Producer-Typ, keine `subscribe()`-Aufrufe, `enable.auto.commit=false`), nicht durch Laufzeittest gegen einen Broker mit schreibgeschütztem Account. C3 wäre zugleich der Nachweis.
