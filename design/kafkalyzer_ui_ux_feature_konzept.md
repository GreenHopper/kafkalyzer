# Kafkalyzer: Detailliertes Konzept zur Verbesserung von UI/UX und Nutzer-Mehrwert

Dieses Dokument beschreibt konkrete Verbesserungen für die Benutzeroberfläche (Flutter / Material 3) und den funktionalen Mehrwert von **kafkalyzer**. Alle Vorschläge wahren strikt das architektonische Kernprinzip **Read-Only by Design** (keine Producer, manuelles `assign()`, keine Offset-Commits).

---

## 1. Message Viewer & Umgang mit großen Payloads

### Ist-Zustand
Die Verarbeitung großer Nachrichten erfolgt bereits nicht-blockierend in Hintergrund-Isolates inklusive Fortschrittsanzeige. Um Abstürze oder Ruckler der Oberfläche zu verhindern, werden Payloads ab $> 500.000$ Zeichen in der UI hart abgeschnitten (Truncation), während der Rohdaten-Export vollständig bleibt. Zudem stehen Table-, Diff- und Timeline-Ansichten sowie Decoder für Avro, Protobuf, JSON, Hex und UTF-8-Header bereit.

### Konkrete Verbesserungen
* **Virtualisierter Lazy-Loading Tree-Viewer**:
  * Statt große JSON-, Avro- oder Protobuf-Payloads als monolithischen Textblock zu rendern, wird ein virtualisierter Baum (`SliverList` / `TreeView`) eingesetzt, der nur die aktuell sichtbaren Knoten im Viewport zeichnet.
  * Tief verschachtelte Objekte und große Arrays (z. B. $> 1.000$ Elemente) werden eingeklappt geladen und erst beim Aufklappen in Segmenten (z. B. in Blöcken zu je $100$ Einträgen) gerendert. Damit entfällt das Limit von $500.000$ Zeichen in der UI komplett.
* **Chunked Raw-/Hex-Viewer mit Inline-Suche**:
  * Für die Rohtext- und Hex-Ansicht großer Nachrichten wird ein seiten- bzw. zeilenbasiertes Virtual-Scrolling eingeführt, inklusive einer lokalen Suchleiste ($\text{Strg}+F$), die über das Rust-Backend bzw. Isolate Treffer-Positionen berechnet, ohne den gesamten String im Flutter-Text-Layout-Speicher zu halten.
* **Anpassbare Spalten (Custom Columns) in der Table-View**:
  * Nutzer können per Rechtsklick auf ein beliebiges Feld eines deserialisierten Payloads (z. B. `payload.customer.id` oder `headers.correlationId`) die Aktion **"Als Tabellenspalte anpinnen"** wählen.
  * Dadurch verwandelt sich die generische Nachrichten-Tabelle in eine domänenspezifische Diagnose-Ansicht, ohne dass jede Nachricht einzeln angeklickt werden muss.
* **Smart-Diffing mit Ignorier-Listen**:
  * In der bestehenden Diff-Ansicht zweier Nachrichten lassen sich flüchtige Felder wie Zeitstempel (`timestamp`, `createdAt`), UUIDs oder Trace-IDs per Checkbox ausblenden, sodass nur fachlich relevante Payload-Unterschiede hervorgehoben werden.

---

## 2. Multi-Search & Strukturierte Abfragen (Query Experience)

### Ist-Zustand
Die Multi-Search erlaubt das gleichzeitige Durchsuchen mehrerer Topics mit konfigurierbaren Start-/End-Bedingungen, Regex-Filtern auf Keys, Values und Headern sowie einer Hash-basierten Partitionsprüfung (Fast Trace).

### Konkrete Verbesserungen
* **Strukturierte Abfragesprache statt reinem Regex**:
  * Regex auf serialisierten oder großen JSON-Strings ist fehleranfällig und bei verschachtelten Bedingungen schwer lesbar.
  * Einführung einer strukturierten Filter-Syntax (z. B. **JSONPath**, **JMESPath** oder einer leichtgewichtigen Ausdruckssprache wie **CEL** im Rust-Backend):
    $$\text{value.order.totalAmount} > 250.0 \land \text{header.env} == \text{"prod"}$$
* **Dual-Mode Filterleiste (Visual Builder & Code-Modus)**:
  * **Einsteiger-Modus**: Visuelle Filter-Chips (`Feld` + `Operator` + `Wert`), die sich per Klick kombinieren lassen.
  * **Experten-Modus**: Textfeld mit Syntax-Highlighting, Autovervollständigung der Feldnamen (gespeist aus dem verknüpften Schema der Confluent Schema Registry) und Live-Validierung bei ungültigen Ausdrücken.
* **Interaktiver Fast-Trace-Assistent**:
  * Wenn ein Nutzer einen Key in Fast Trace eingibt, zeigt ein kleines Live-Badge sofort den berechneten Hash-Wert (z. B. `murmur2` oder `crc32`) und die resultierende Ziel-Partition $P_{\text{target}} = \text{hash}(\text{key}) \bmod N_{\text{partitions}}$ an, noch bevor der Scan startet.
* **Gespeicherte Suchprofile (Saved Searches)**:
  * Häufig genutzte Topic-Kombinationen und Filter-Ausdrücke lassen sich mit einem Namen im jeweiligen Cluster-Profil speichern und mit einem Klick wieder aufrufen.

---

## 3. Topic Explorer & Schema Registry Integration

### Ist-Zustand
Der Topic Explorer zeigt Topics, Partitionen, Log-End-Offsets und Details an und bindet die Confluent Schema Registry für Avro, Protobuf und JSON Schema ein.

### Konkrete Verbesserungen
* **Visueller Schema-Versions-Vergleich (Schema Diff)**:
  * Auswahl von zwei Schema-Versionen (z. B. Version $v_3$ vs. $v_4$) eines Subjects direkt im Topic Explorer.
  * Eine Side-by-Side-Diff-Ansicht markiert hinzugefügte, gelöschte oder typveränderte Felder und zeigt das konfigurierte Compatibility-Level (`BACKWARD`, `FORWARD`, `FULL`) an. Das beschleunigt die Ursachenforschung bei Deserialisierungsfehlern massiv.
* **Partition Skew & Datenverteilungs-Indikator**:
  * Anhand der bereits abgerufenen Watermarks ($\text{Offset}_{\text{high}} - \text{Offset}_{\text{low}}$) berechnet die UI die Nachrichtenverteilung über alle Partitionen eines Topics.
  * Ein kompaktes Balkendiagramm und ein Warn-Badge markieren sofort, wenn eine sogenannte „Hot Partition“ vorliegt (z. B. wenn eine Partition $> 50\,\%$ aller Nachrichten hält, weil Producer einen ungünstigen Partition-Key verwenden).
* **Broker- und Topic-Konfigurations-Diff**:
  * Da das Backend bereits `describe_configs` unterstützt, können Nutzer zwei Topics (oder dasselbe Topic auf zwei Clustern wie *Staging* und *Production*) nebeneinander legen.
  * Ein Schalter **„Nur Abweichungen & Non-Defaults anzeigen“** hebt Unterschiede bei kritischen Parametern wie `retention.ms`, `cleanup.policy` oder `max.message.bytes` farblich hervor.

---

## 4. Consumer Lag Monitoring & Poison-Pill-Diagnose

### Ist-Zustand
Ein Echtzeit-KPI-Dashboard überwacht aktive Consumer Groups, den Gesamt-Lag und Lag-Rate-Deltas über die Zeit. Zudem können Nachrichten an aktuellen Consumer-Offsets zur Poison-Pill-Identifikation direkt inspiziert werden, ohne Offsets zu verschieben.

### Konkrete Verbesserungen
* **Inline-Sparklines & Time-to-Catch-Up-Prognose**:
  * Neben dem numerischen Lag-Delta ($\Delta\text{Lag}/\Delta t$) zeigt eine kompakte Sparkline-Grafik pro Consumer Group den Verlauf der letzten $5\text{–}15$ Minuten.
  * Sinkt der Lag ($\Delta\text{Lag}/\Delta t < 0$), berechnet die UI eine geschätzte Aufholzeit:
    $$t_{\text{recovery}} = \frac{\text{Lag}_{\text{current}}}{|\Delta\text{Lag}/\Delta t|}$$
* **Lokale Schwellenwert-Alarme & Desktop-Notifications**:
  * Nutzer können für kritische Consumer Groups lokale Schwellenwerte definieren (z. B. $\text{Lag} > 10.000$ oder stagnierender Offset bei gleichzeitig wachsendem Log-End-Offset über $> 60\,\text{s}$).
  * Bei Überschreitung sendet kafkalyzer eine native Betriebssystem-Benachrichtigung (Linux, macOS, Windows) und hebt die Gruppe im Dashboard rot hervor.
* **Geführter „Poison Pill Compare“-Workflow**:
  * Klickt der Nutzer bei einer hängenden Partition am aktuellen Consumer-Offset $O_c$ auf **„Poison Pill analysieren“**, lädt kafkalyzer automatisch sowohl die blockierende Nachricht an Offset $O_c$ als auch die letzte erfolgreich verarbeitete Nachricht an Offset $O_c - 1$.
  * Beide Nachrichten werden direkt im **Diff-Modus** geöffnet, inklusive Prüfung, ob sich zwischen $O_c - 1$ und $O_c$ die Schema-ID im Header/Magic-Byte geändert hat.

---

## 5. Topic-übergreifendes Event-Tracing (End-to-End Correlation)

### Ist-Zustand
Die Timeline-Ansicht stellt Nachrichten zeitlich dar, und Fast Trace prüft gezielt einzelne Keys.

### Konkrete Verbesserungen
* **1-Klick „Follow Trace / Correlation ID“**:
  * In modernen Event-Driven-Architekturen durchläuft ein Vorgang oft mehrere Topics (z. B. `orders.created` $\rightarrow$ `payments.processed` $\rightarrow$ `shipments.triggered`), verbunden über eine `correlationId` oder einen W3C-`traceparent`-Header.
  * Per Rechtsklick auf einen solchen Header- oder Payload-Wert wählt der Nutzer **„Trace über Topics verfolgen“**.
* **Visuelle Swimlane-Timeline**:
  * Die Timeline-View gruppiert die gefundenen Events nach Topic als horizontale Swimlanes und zeigt die zeitliche Abfolge inklusive der Latenz $\Delta t$ zwischen den einzelnen Verarbeitungsstufen an.

---

## 6. Scripting-Umgebung & Workflow-Automatisierung

### Ist-Zustand
Die mehrstufige Scripting-Umgebung bietet Ausführungshistorie, Parameter-Prompts, Output-Diffing und einen automatischen Datei-Export unter `Documents/kafkalyzer/<Script_Name>/<Run_ID>`.

### Konkrete Verbesserungen
* **Integrierter Vorlagen-Katalog (Recipe Library)**:
  * Bereitstellung direkt nutzbarer Standard-Skripte beim ersten Start (z. B. *„Snapshot aller Consumer-Lags vor/nach Deployment“*, *„Stichproben-Export aus 5 Kern-Topics“*, *„Dead-Letter-Queue-Triage“*), um die Einstiegshürde für neue Nutzer zu senken.
* **Visueller Step-Pipeline-Builder**:
  * Ergänzung eines kachelbasierten Editors, in dem die einzelnen Skript-Schritte als visuelle Kette dargestellt werden (inklusive Anzeige der Eingabe-Parameter, Laufzeit pro Schritt und Status-Indikator).
* **Direktes Run-zu-Run-Diffing in der UI**:
  * Auswahl zweier vergangener `Run_ID`s aus der Ausführungshistorie mit strukturierter Gegenüberstellung der erzeugten JSON-Artefakte direkt im Hauptfenster, ohne den Umweg über den Dateimanager.

---

## 7. Sicherheit, Plattform-Integration & Onboarding

### Ist-Zustand
Cluster-Profile und Konfigurationen liegen in `shared_preferences.json` bzw. `.plist`. Das Profil-Backup exportiert Cluster-Profile samt SSL-Zertifikaten für das Team-Sharing. Unter Windows wird für lokale/Debug-Läufe manuell eine `cacert.pem` im Programmverzeichnis benötigt.

### Konkrete Verbesserungen
* **Natives OS-Keychain-Management für Geheimnisse**:
  * Trennung von unkritischen Metadaten (Cluster-Name, Bootstrap-URLs, UI-Farbe) in `shared_preferences` und sensiblen Zugangsdaten (SASL-Passwörter, OAuth-Tokens, mTLS Private Keys) im nativen Betriebssystem-Tresor (Linux Secret Service / `libsecret`, macOS Keychain, Windows Credential Locker).
  * Ein kleines Schloss-Icon im Profil-Editor signalisiert dem Nutzer transparent, dass Credentials hardware-/OS-geschützt gespeichert sind.
* **Verschlüsseltes Team-Backup (`.kafkalyzer-vault`)**:
  * Beim Exportieren von Cluster-Profilen für Kollegen öffnet sich ein Dialog zur Vergabe eines Master-Passworts (symmetrische Verschlüsselung z. B. via AES-256-GCM mit Argon2-Key-Derivation). So können Export-Dateien gefahrlos über Team-Chats oder Wikis geteilt werden.
* **Automatisiertes Windows-SSL-Handling & Verbindungs-Diagnose**:
  * Einbetten eines Standard-CA-Bundles (oder Nutzung des nativen OS-Zertifikatspeichers in Rust) als automatischer Fallback, falls unter Windows keine externe `cacert.pem` gefunden wird.
  * Ergänzung eines **„Verbindung testen (Diagnose)“**-Buttons im Profil-Editor, der bei Fehlern genau aufschlüsselt, auf welcher Stufe der Verbindungsaufbau scheiterte:
    1. DNS-Auflösung & TCP-Reachability des Bootstrap-Servers
    2. TLS/SSL-Handshake & Zertifikatskette
    3. SASL / IAM / Kerberos Authentifizierung
    4. Erreichbarkeit der Schema Registry
* **Globale Command Palette ($\text{Strg}+K$ / $\text{Cmd}+K$)**:
  * Power-User-Feature zum blitzschnellen Wechseln zwischen Clustern, Springen zu einem Topic, Öffnen einer Consumer Group oder Starten eines gespeicherten Diagnose-Skripts komplett ohne Maus.
* **Visuelle Präsentation im Repository (README)**:
  * Ergänzung einer kompakten Galerie mit Screenshots (Dark & Light Mode) sowie kurzen animierten GIFs der Kern-Features (Lag-Dashboard, Message-Diff, Multi-Search) im GitHub-README, damit potenzielle Nutzer den Mehrwert auf den ersten Blick erfassen.

---

## 8. Priorisierungs-Matrix (Impact vs. Aufwand)

| Maßnahme | Mehrwert für User | Implementierungs-Aufwand | Empfohlene Phase |
| :--- | :--- | :--- | :--- |
| **Verbindungs-Diagnose & Windows-SSL-Fix** | Hoch (beseitigt Start-Hürden) | Gering | **Phase 1 (Quick Wins)** |
| **Command Palette ($\text{Strg}+K$) & Custom Table Columns** | Sehr hoch (Tägliche Produktivität) | Gering bis Mittel | **Phase 1 (Quick Wins)** |
| **OS-Keychain & Verschlüsselter Profil-Export** | Hoch (Enterprise-Readiness) | Mittel | **Phase 1 (Quick Wins)** |
| **Virtualisierter Tree-Viewer ($> 500\text{k}$ Zeichen)** | Sehr hoch (beseitigt UI-Limit) | Mittel | **Phase 2 (Core UX)** |
| **Strukturierte Filter (JSONPath / CEL) & Builder** | Sehr hoch (präzises Debugging) | Mittel bis Hoch | **Phase 2 (Core UX)** |
| **Schema-Versions-Diff & Topic-Config-Diff** | Hoch (schnelle Fehleranalyse) | Mittel | **Phase 2 (Core UX)** |
| **Poison-Pill Auto-Diff ($O_c$ vs. $O_c - 1$) & Lag-Alerts** | Hoch (Observability-Mehrwert) | Mittel | **Phase 3 (Advanced)** |
| **Topic-übergreifendes Event-Tracing (Swimlanes)** | Sehr hoch (Alleinstellungsmerkmal) | Hoch | **Phase 3 (Advanced)** |