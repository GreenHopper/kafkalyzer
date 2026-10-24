# MCP-Server für kafkalyzer — Machbarkeit & Sinnhaftigkeit

Stand: Review auf `73a6155`. Grundlage: Quelltextanalyse `rust/`, `lib/src/`.
Diese Datei bewertet die Entscheidung (ob/wie/sinnvoll). Die Tool-Einzelspezifikation liegt in [`mcp-server-api-design.md`](mcp-server-api-design.md) und wird hier auf ihren Ist-Stand geprüft.

---

## 0. Entscheidung in 6 Zeilen

**Ja, machbar — und sinnvoll, aber nur als schlanker Read-only-Diagnose-Server, nicht als Spiegel der App-Features.**

| Punkt | Ergebnis |
|---|---|
| Technische Machbarkeit | Hoch. Der Kafka-Kern (`kafkalyzer-kafka`, `kafkalyzer-core`) ist bereits Flutter-frei; ein eigenes Binary im Cargo-Workspace braucht **keine** neue Architektur. |
| Aufwand MVP (10 Read-only-Tools, stdio) | **2–3 Arbeitstage.** Volle Ausbaustufe inkl. Prompts/Resources/Diff: **+3–5 Tage.** |
| Empfohlener Modus | Standalone-Rust-Binary `kafkalyzer-mcp` (stdio), Profile aus JSON-Datei. |
| Nicht empfohlen | MCP-Server in Dart/Flutter eingebettet als Hauptvariante (Blocker: GUI-Prozess muss laufen, Freigabe-Erlebnis schlechter). |
| Größtes Risiko | **Datenabfluss**: Kafka-Payloads landen im Kontext eines LLM-Anbieters. Ohne Cluster-Allowlist und Truncation nicht freigebbar. |
| Nutzen | Echt, aber schmal: Incident-Triage und Cross-Topic-Traces, bei denen ein Agent ohnehin Text schrittweise erkundet. Für reine „Message ansehen"-Arbeit bringt MCP keinen Vorteil gegenüber der GUI. |

---

## 1. Was die existierende Design-Dokumentaion falsch oder zu optimistisch darstellt

`design/mcp-server-api-design.md` ist als API-Katalog brauchbar, enthält aber Aussagen, die dem Code widersprechen. Vor jeder Umsetzung korrigieren:

| Behauptung in `mcp-server-api-design.md` | Ist im Code |
|---|---|
| „AS400 / IBM EBCDIC record decoding", „legacy AS400 payloads" | **Existiert nicht.** `grep -ri 'as400\|ebcdic' rust lib` = 0 Treffer. Auch `openspec/config.yaml` beschreibt `kafkalyzer-core` als „AS400 decoding", tatsächlich enthält es nur `avro_utils.rs` (Avro→JSON) und `kafka_types.rs`. |
| `kafka_diff_messages` als Rust-Tool | Diff ist **Dart-only**: `diff_match_patch` + `json_diff` (pubspec), verwendet in `lib/src/features/scripting/presentation/widgets/diff/`. Für MCP neu in Rust zu bauen oder weglassen. |
| `kafka_extract_json_path` mit `customer.address.zipCode` | Rust kennt nur **JSON Pointer** (`serde_json::Value::pointer`) und baut in `kafka_consumer.rs:1417` den Pointer per `format!("/{}", field)` — verschachtelte Dot-Pfade funktionieren dort **nicht**. Echte Dot-/Index-Syntax (`items[0].sku`) liegt in Dart (`lib/src/utils/json_path_extractor.dart`). |
| `kafka_run_investigation_pipeline` (skriptartige Pipelines) | `ScriptRunner` ist Dart, 1172 Zeilen unter `.../scripting/presentation/controllers/script_runner.dart`, inkl. UI-/Export-Nebeneffekten. Als MCP-Tool nur mit neuer, eigenständiger Rust-Implementierung. |
| „Credentials are read from the local encrypted/protected storage" | **Nicht verschlüsselt.** Profile liegen Klartext in `shared_preferences` (`cluster_profiles`), inkl. `saslPassword`, Keytab-Pfade, OAuth-Token-Felder. |
| Fehlende Tools in der Liste | `fetch_consumer_lags` (Gruppenübersicht) und `fetch_consumer_groups` sind vorhanden und gehören 1:1 eins zu eins in die Tool-Liste. |

---

## 2. Ist-Analyse: Was ist wirklich wiederverwendbar?

### 2.1 Schichtentrennung ist bereits MCP-fähig

```
rust_lib_kafkalyzer  (rust/src)     ← flutter_rust_bridge, StreamSink-Wrapper, DTO-Mapping
   ├─ kafkalyzer-kafka (rust/kafkalyzer-kafka)   ← rdkafka, reqwest, schema_registry_converter. KEIN frb.
   └─ kafkalyzer-core  (rust/kafkalyzer-core)    ← serde, apache-avro. KEIN frb, KEIN rdkafka.
```

Belege:
- `rust/kafkalyzer-kafka/Cargo.toml` und `rust/kafkalyzer-core/Cargo.toml` haben **keine** `flutter_rust_bridge`-Abhängigkeit; `flutter_rust_bridge` steht nur in `rust/Cargo.toml`.
- `kafkalyzer_kafka::kafka_consumer::StreamSink` (`kafka_consumer.rs:62`) ist ein eigener `tokio::sync::mpsc`-Wrapper, kein FRB-Typ. Für MCP: Sender halten und in ein `Vec` sammeln statt in die Bridge.
- Alle Domain-Typen (`ClusterProfile`, `KafkaMessage`, `ConsumerGroupLag`, `TopicAnalysisReport`, `FieldOccurrence`, …) tragen `#[derive(Serialize, Deserialize)]` → die JSON-Antworten eines MCP-Servers sind im Wesentlichen **kostenlos**.
- Plattform-Abhängigkeiten (rdkafka/OpenSSL/SASL, je OS unterschiedlich gemappt) entstehen pro Crate, nicht pro Binary: das neue Binary nutzt exakt dieselbe Toolchain, die der CI-Build heute schon baut.

### 2.2 1:1-Mapping vorhandener Kernfunktionen auf MCP-Tools

| Vorhandene Funktion | Fundstelle | MCP-Tool | Zusatzaufwand |
|---|---|---|---|
| `validate_connection(profile)` | `kafka_metadata.rs:18` | `kafka_test_connection` | geringer Adapter |
| `fetch_topics(profile)` (Partitionen, RF, `cleanup_policy`, `retention_ms`) | `kafka_metadata.rs:26` | `kafka_list_topics` | Filtering/Name-Pattern neu |
| `fetch_consumer_lags` / `fetch_consumer_groups` / `fetch_consumer_group_lag` | `kafka_metadata.rs:204 / 394 / 474` | `kafka_get_consumer_lag`, `kafka_list_consumer_groups` | keiner |
| `consume_with_filter(…, sink)` (Offsets, Timestamps, Tail, `fast_trace_key`, `filter_field`, Regex) | `kafka_consumer.rs:83` | `kafka_consume_messages`, `kafka_search_messages` | Sink→Vec, harte `max_results`, `run_forever` sperren |
| `analyze_topic_content(…, cancel_flag)` (Größen, Tombstones, Skew, Stunden-Histogramm, Feldfrequenzen) | `kafka_analyzer.rs:530` | `kafka_analyze_topic` | Aggregat statt Stream zurückgeben |
| `fetch_subjects` / `fetch_schema` | `schema_registry.rs:56 / 80` | `kafka_list_schemas`, `kafka_get_schema` | keiner |
| `murmur2` / `to_positive` | `kafka_utils.rs:7 / 55` | `kafka_calculate_partition` | keiner |
| „Poison Pill" bei `current_offset` | App: `consumer_lag_messages_view.dart` nutzt `consume_with_filter` auf Offset | `kafka_inspect_lagging_message` | Kombination lag + consume |

→ **Die Read-only-Kernfeatures der App sind ohne neue Kernlogik erreichbar.** Das ist der strongest Punkt der Machbarkeit.

### 2.3 Was NICHT aus dem Rust-Kern kommt (heute Dart)

| Feature | Wo heute | Konsequenz für MCP |
|---|---|---|
| Structured/Text-Diff | Dart (`json_diff`, `diff_match_patch`) | Entweder Diff-Tool weglassen **oder** ~100 Zeilen JSON-Pointer-basierter Diff in Rust. Empfehlung: Phase 2. |
| JSONPath Dot-/Index-Extraktion | `lib/src/utils/json_path_extractor.dart` | ~20–30 Zeilen `a.b[0].c` → `/a/b/0/c` in Rust, dann `serde_json::Value::pointer`. Klein. |
| Multi-Step-Skripte inkl. Variablenpropagation | `script_runner.dart` (Dart) | Eigenständige Rust-Reimplementation oder Feature nicht exponieren. |
| Export `.json`/`.zip`, Profil-Backup | `message_export_service.dart`, `settings_service.dart` | Für MCP nicht nötig — Agent will JSON, keine Archive. |
| Large-Message-Truncation, Format-Aufbereitung | `payload_processing_isolate.dart`, UI-Layer | Muss im MCP-Layer **neu** gebaut werden (Truncation ist Pflicht, siehe §5). |

---

## 3. Betriebsmodi — drei Optionen, eine Empfehlung

### A) Standalone-Rust-Binary `kafkalyzer-mcp` (empfohlen)

Neues Workspace-Mitglied `rust/kafkalyzer-mcp` mit `[[bin]]`, ruft `kafkalyzer_kafka::*` direkt.

- ✅ Kein Flutter, kein GUI, startet in Millisekunden; läuft in CI, Docker, Remote-Devcontainer.
- ✅ `cargo test`-fähig, nutzt die bestehenden 49 Rust-Testfunktionen als Sicherheitsnetz.
- ✅ Verteilbar als eine Datei neben AppImage/Setup.exe — CI-Matrix existiert bereits.
- ❌ Profilquelle muss gelöst werden (§4) — die App-Datenhaltung ist an `shared_preferences` und Dart-Modelle gebunden.

### B) Eingebettet in die Desktop-App (App startet Server, localhost)

- ✅ Profilverwaltung, aktive Verbindung und Settings sofort mitbenutzt; Nutzer schaltet MCP in den Settings ein.
- ❌ Der Desktop-App-Prozess muss laufen; Agent-Clients erwarten einen startbaren Prozess (`command` + `args` in der MCP-Config) — ein zweiter Schritt (Port-Token, Discovery) nötig.
- ❌ Ein crashender Agent-Request hängt im GUI-Prozess; Lifecycle (App minimiert, Sleep) bricht Sessions ab.

**Sinnvolle Kombination:** A als Server, **B als Komfort**: App schreibt Profile auf „MCP aktivieren" in eine JSON-Datei, Binary A liest sie. Damit bleibt der Agent-Pfad headless und die App bleibt das Pflege-UI für Profile. (Ein eingebetteter Modus ist kein eigener Server, sondern nur ein Export-Knopf.)

### C) MCP-Server in Dart

- ❌ Neuer Stack (Dart-MCP-Runtime), während die komplette Logik in Rust liegt; Aufrufe gingen zurück über die Bridge in denselben Prozess wie die GUI.
- ❌ Kein headless Betrieb ohne Flutter-Runner.
→ Nicht weiter verfolgen.

---

## 4. Blocker, die vor dem MVP gelöst sein müssen

1. **Profilquelle.** Profile liegen in `shared_preferences` unter Key `cluster_profiles`. Pfade: Linux `~/.local/share/at.greenhopper.kafkalyzer/shared_preferences.json`, Windows `%APPDATA%\at.greenhopper\kafkalyzer\shared_preferences.json`, **macOS: `.plist`, kein JSON** (`~/Library/Preferences/at.greenhopper.kafkalyzer.plist`). Ein Rust-Binary kann Linux/Windows direkt parsen, macOS nicht ohne plist-Parser. Empfehlung: eigenes Format `~/.config/kafkalyzer/mcp_profiles.json`, von der App exportiert; die JSON-Struktur ist bereits vorhanden (`ClusterProfileExtension.toJson`).
2. **Feldverlust im Profil-Store.** `ClusterService` speichert über eine handgeschriebene `toJson`-Extension (`lib/src/services/cluster_service.dart:32`), die neueren Felder (Schema-Registry-Auth, Kerberos/OAuth/MSK, PEM-mTLS) fehlen. Profile mit moderner Authentifizierung überleben heute einen Neustart dieses Pfads nicht. Für MCP wäre dieselbe Datei die Quelle → vorab klären. (Separates Thema, nicht Teil des MCP-MVP.)
3. **Secrets.** Sasl-Passwörter, Keytabs, OAuth-Token stehen im Klartext im Profil. MCP-Ausgaben müssen auf Redaction-Liste (`[REDACTED]`), und `kafka_list_clusters` darf niemals das ganze Profil zurückgeben.
4. **Truncation ist Pflicht, nicht Optimization.** `KafkaMessage.payload` ist `Option<String>` ohne Größenlimit. Ohne harte Kappung (z. B. 4 KB/Message, max. 20 Messages/Antwort) schießt ein einziger `consume`-Aufruf das Kontextfenster zu.
5. **Stream-API.** Beide Streaming-Funktionen (`consume_with_filter`, `analyze_topic_content`) senden progressiv. Für MCP braucht es eine Sammel-Variante mit Timeout/Cancel — der `cancel_flag`-Mechanismus in `kafka_analyzer.rs` ist bereits vorhanden und wiederverwendbar.
6. **`run_forever` muss hart verboten sein** (`consume_with_filter` Parameter, `kafka_consumer.rs:83`), sonst blockiert ein Live-Tail die MCP-Verbindung für immer.

---

## 5. Sicherheit / Governance (Pflicht-Set für den MVP)

| Maßnahme | Warum |
|---|---|
| Read-only-Enforcement: keine Produce-/Delete-/Reset-Offsets-Tools | **Projektleitlinie:** kafkalyzer ist per Design ein Analyzer und schreibt nicht. Der Kern hat heute bewusst keinen Producer (`grep` nach produce/create_topic: nichts außer `enable.auto.commit=false`). Diese Eigenschaft ist das wertvollste Sicherheitsmerkmal der Anwendung — der MCP-Server erbt sie und darf sie nicht aufweichen. Abgesichert werden soll sie zusätzlich durch das CI-Gate aus `feature-gap-analysis.md` §5.1. |
| Cluster-Allowlist pro MCP-Session (Env/Config), `cluster_name` nur als Referenz | Verhindert, dass ein Halluzinations-String gegen Produktiv-Cluster läuft. |
| Harte Caps: ≤ 20 Messages, ≤ 4 KB Payload, Scan-Timeout ≤ 15 s | Schutz vor Kontext-EXPLOSION und Vor-Ort-Blockade. |
| Redaction aller Credential-Felder in jeder Antwort | Profile enthalten Klartext-Secrets. |
| Expliziter Hinweis im Tool-Text: „Payloads werden an einen LLM-Anbieter übermittelt" | Compliance: Topic-Daten können personenbezogen sein (DSGVO). Ohne diese Warnung ist das Tool in regulierten Umgebungen nicht freigebbar. |
| Kein `include_internal` für `__consumer_offsets` per Default | interner Broker-State ist selten gewollt und groß. |

---

## 6. Lohnt sich das? Nutzen gegen Kosten

**Wo MCP einen echten Vorteil bringt (Agent kann mehr als der Mensch nicht könnte):**
1. **Incident-Triage**: „Warum wächst Lag in Gruppe X?" — Agent kombiniert `lag` → Offset-Inspection → Payload-Analyse in einer Sitzung. Heute: 15 Minuten Klickarbeit in drei Views.
2. **Cross-Topic-Korrelation**: `order → payment → shipment` über JSONPath-Extraktion und `fast_trace_key`. Genau die Arbeit, die sonst manuelle Skript-Schritte erfordert.
3. **Schema-/Payload-Audit über viele Topics**: `analyze_topic` pro Topic, Aggregat bleibt klein, Ergebnis als Bericht.
4. **Entlastung von Nicht-Desktop-Szenarien**: CI, Bastion, Devcontainer, Chat-Ops ohne GUI.

**Wo MCP keinen Mehrwert bringt:** Message-Tabellen, Diff-/Timeline-Ansichten, Schema-Inspector-UX, Skript-Editor, Export-Archive. Das sind visuelle Features — ein Token-Stream ist dafür das schlechtere Medium. Ein MCP-Server, der dieseFeatures nachbaut, ist teurer und schlechter als die App.

**Die ehrliche Alternative, die man geprüft haben muss:** ein `kafkalyzer-cli` (args → JSON auf stdout). Agenten können CLIs per Bash aufrufen, MCP ist dafür nicht nötig. Unterschied: MCP liefert typisierte Schemas, Discovery und Ressourcen — und funktioniert in Clients ohne Shell-Zugriff (Claude Desktop, Web-Clients). **Wenn Zielgruppe lokale Entwickler-Agenten mit Shell sind, ist der CLI der kleinere Schritt und später die Basis für denselben MCP-Handler** (beide rufen dieselben Crate-Funktionen). Empfehlung: Handler-Funktionen so schreiben, dass CLI und MCP-Wrapper denselben Code teilen.

**Doppeleffekte, die für MCP sprechen:** dieselbe Schicht ermöglicht später einen CLI für CI/CD (Retensions-/Skew-Audits als Pipeline-Job) und Automation ohne UI. Kosten dafür sind mit dem MCP-MVP bereits bezahlt.

**Kosten, die gern unterschätzt werden:**
- Wartung: Jede Änderung an `ClusterProfile`/DTOs braucht Abgleich mit der Tool-Oberfläche.
- Support: Fehler in Agent-Aufrufen kommen als „die KI hat etwas kaputt gemacht" zurück.
- Build-/Release: ein zusätzliches Artefakt pro Plattform (Linux/macOS/Windows, je rdkafka-Flavor).

---

## 7. Aufwand

| Schritt | Inhalt | Aufwand |
|---|---|---|
| 1 | Crate `rust/kafkalyzer-mcp`, JSON-RPC über stdio (Dependency `rmcp` prüfen; Fallback: handgebaut, ~300 Zeilen), Profil-Loader aus JSON | 0,5–1 Tag |
| 2 | 8 Read-only-Tools (§2.2) als Sammel-Varianten, Caps + Timeout + Redaction | 1–1,5 Tage |
| 3 | App-Settings-Knopf „Profile für MCP exportieren" (JSON schreiben) | 0,5 Tag |
| 4 | Integrationstest gegen `docker-compose.yaml`-Kafka (Komposition existiert bereits im Repo) | 0,5 Tag |
| Summe MVP | | **2–3 Tage** |
| 5 | Ressourcen + Prompts (`diagnose-consumer-lag`, `trace-event-flow`), `kafka_calculate_partition`, JSONPath-Mapping | 1–2 Tage |
| 6 | Diff-Tool in Rust, Pipeline-Ausführung, Release-Paketierung in `build.yml` | 2–3 Tage |

---

## 8. Offene Entscheidungen (vor Schritt 1 zu klären)

1. Zielgruppe: nur lokale Entwickler-Agenten (→ CLI zuerst) oder auch Claude Desktop / Web-Clients ohne Shell (→ MCP zuerst)?
2. Profile: Export aus der App (empfohlen) oder direkt `shared_preferences` lesen (macOS: plist-Problem)?
3. Darf der Server gegen Produktiv-Cluster laufen, oder nur gegen allowgelistete Testcluster?
4. Schreibende MCP-Tools (Produce, Offset-Reset): **entschieden — nein.** kafkalyzer ist per Design read-only; die Tool-Oberfläche darf daran nichts ändern. Verbleibend: Sollen schreibgeschützte Service-Accounts pro Cluster erzwungen werden (empfohlen, siehe `feature-gap-analysis.md` C3)?

---

## 9. UI-only-Logik in den Rust-Kern verlagern?

**Antwort: ja, aber nur für reine Berechnungen ohne UI-Zustand — und dort, wo die Logik heute schon doppelt existiert oder von einem wackeligen Dart-Paket abhängt.** Der CLI/MCP-Nutzen ist der Gratis-Nebeneffekt, nicht die Begründung. Wer Logik auf Vorrat verschiebt, zahlt zwei Umzüge.

### 9.1 Grundmuster (existierende Konvention, kein neues Konzept)

`openspec/config.yaml` fordert bereits die Trennung reiner Rechenlogik von plattformabhängiger I/O, plus Orphan-Rule für Bridge-DTOs. Ein Umzug ist deshalb mechanisch:

1. Funktion und Domain-Typen nach `kafkalyzer-core` (Serde auf allen Typen, `cargo test` vorhanden).
2. DTO-Mapping nach `rust/src/api/` (Bridge-Crate), `flutter_rust_bridge_codegen` neu laufen lassen.
3. Dart-Aufrufer tauschen nur den Import — UI-Verhalten bleibt gleich. Bestehende Widget-Tests (`test/src/ui/messages/views/messages_diff_view_test.dart`, `test/src/utils/json_path_extractor_test.dart`) sind das Sicherheitsnetz.

### 9.2 Fall 1 — JSONPath-Extraktion: **sofort, unabhängig von MCP**

Es existieren vier ungleiche Implementierungen:

| Stelle | Akzeptierte Syntax | Array-Index (`items[0]`) | Nutzt es |
|---|---|---|---|
| `lib/src/utils/json_path_extractor.dart` | Dot-Notation, `root.`-Präfix | ja | projizierte Tabellenspalten (`messages_table_view.dart:346`) |
| `lib/src/features/scripting/domain/extraction_utils.dart:29` | nur Dot | nein | Script-Extraktion |
| `lib/src/features/scripting/presentation/controllers/script_runner.dart:1002` (private Kopie `_extractValue`) | nur Dot | nein | Pipeline-Lauf |
| `rust/kafkalyzer-kafka/src/kafka_consumer.rs:1417` (`filter_field`) | JSON Pointer `/a/b/c` | nur als Pointer | Server-Scan-Filter |

Konsequenzen, die Nutzer heute sehen: dieselbe Spalte, derselbe Filter, anderes Ergebnis; ein Pfad mit Array-Index funktioniert in der Tabelle, aber nicht im Script; und die im UI beworbene Syntax `JSONPath (e.g. $.id)` (`lib/l10n/app_en.arb:720`) führt in **keiner** Implementierung zu einem Wert — `normalizePath` kennt nur `root.`, das `$` wird als Schlüssel gesucht und liefert still `null`.

**Maßnahme:** eine Implementierung in `kafkalyzer-core` (`json_path::resolve(value, path) -> Option<Value>`), die Dot-Notation, `[n]`, `$.`-Präfix und `/pointer` akzeptiert, plus Einheitlichkeitstests. Dart ruft sie über die Bridge, `filter_field` im Consumer nutzt dieselbe Funktion. Aufwand **0,5–1 Tag**, danach sind UI-Filter, Spaltenprojektion, Script-Extraktion und später MCP identisch.

### 9.3 Fall 2 — struktureller JSON-Diff: **ja, zum Zeitpunkt der MCP/CLI-Entscheidung**

Ist-Zustand: `lib/src/features/scripting/presentation/widgets/diff/message_diff.dart` rechnet mit dem Paket `json_diff`, das als **Git-Abhängigkeit** eingebunden ist (`pubspec.yaml` → `google/dart-json_diff`), textlich mit `diff_match_patch`. `json_converter.dart` sichert API-Unterschiede mit dem Kommentar „json_diff might structure this differently depending on version“ ab — unbeständiges Dependency-Risiko in einer Kernfunktion.

Verschieben: den strukturellen Vergleich (~100 Zeilen Rust über `serde_json`, flaches Ergebnis `[{path, kind, old, new}]`) nach `kafkalyzer-core`. **Bleiben in Dart:** `DiffViewNode` mit `isExpanded`/`depth` und alle Widget-Aufbauschritte — das ist View-Zustand. Text-Diff (`diff_match_patch`) bleibt ebenfalls Dart, solange kein Agent ihn braucht.

Nutzen: `kafka_diff_messages` für MCP/CLI ohne Zweitimplementierung, das Git-Paket verschwindet, und der Diff steht in Skript-Läufen und Analysen zur Verfügung. Aufwand **1–1,5 Tag** inkl. DTO und UI-Umstellung; Prüfpunkt ist die Darstellungsgleichheit der Diff-Ansicht (Widget-Test vorhanden, visuell gegenprüfen).

### 9.4 Was nicht verschoben werden sollte

| Kandidat | Grund |
|---|---|
| Smart Virtual JSON Tree (`json_tree_flattener`, context windowing, `SmartCompositeBadge`, entity formatters) | reine Darstellungslogik mit Flutter-Widgets und Badge-Zustand; headless unbrauchbar. Fünf Testdateien für null Nutzen umziehen. |
| Spalten-Config, Presets, Sortierung, Tab-Zustand | Benutzerzustand und Präsentation, kein Algorithmus. |
| `payload_processing_isolate.dart` (JSON-Parse in Isolate, Truncation) | Die Bridge liefert Payloads bereits als String; ein Umzug verschiebt nur Overhead. Die für MCP nötige Truncation gehört in den MCP-Layer und ist dort ~20 Zeilen neu, kein Umzug. |
| `script_runner.dart` (Pipeline-Orchestrierung) | Zu groß für eine Vorab-Investition. Wenn CLI/MCP beschlossen ist: 1–2 Tage, und die GUI nutzt danach dieselbe Pipeline (siehe `feature-gap-analysis.md` B9). |
| Export als JSON/ZIP, Profil-Backup | CLI/MCP wollen JSON-Strukturen, keine Archive. |

### 9.5 Reihenfolge

1. **JSONPath vereinheitlichen** (0,5–1 Tag) — behebt einen vorhandenen Fehler und eine existierende Duplikation; lohnt ohne MCP.
2. **JSON-Diff nach `kafkalyzer-core`** (1–1,5 Tage) — genau dann, wenn MCP/CLI grünes Licht bekommt oder `json_diff` pflegepolitisch auffällt.
3. Weitere Umzüge nur auf Zuruf einer echten zweiten Aufruferseite (CLI, MCP, CI-Job). Regel: verschieben, wenn ein zweiter Aufrufer da ist oder die Duplikation bereits kostet — nicht auf Verdacht.
