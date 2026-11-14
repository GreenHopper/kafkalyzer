# Kafkalyzer: Hybrid-Architektur (Desktop, Kubernetes & MCP)

Dieses Konzept erweitert die bestehende **kafkalyzer**-Struktur zu einer hybriden Architektur. Durch das Aufbrechen des monolithischen `rust/`-Ordners in einen modularen **Cargo Workspace** und die Einführung einer **Transport-Abstraktion in Flutter** bleibt die lokale Desktop-App (Linux, macOS, Windows) zu $100\,\%$ erhalten, während gleichzeitig ein containerisiertes Backend für Kubernetes inklusive durchgängigem **Model Context Protocol (MCP)** entsteht.

---

## 1. Verbesserte Verzeichnisstruktur

Die Root-Struktur behält die Konventionen für Flutter und `velopack_flutter` bei, strukturiert jedoch das Rust-Backend (`rust/`), die Dart-Datenquellen (`lib/core/backend/`) sowie die Deployment-Artefakte (`deploy/`) sauber um:

```text
kafkalyzer/
├── .github/workflows/
│   ├── ci.yml                      # Prüft check_read_only.sh, cargo test (Workspace) & flutter test
│   ├── release-desktop.yml         # Baut AppImage, macOS Portable & Windows Setup (Velopack)
│   └── release-container.yml       # NEU: Baut & publiziert Docker-Images (Server & MCP) für K8s
├── assets/
├── bin/
├── deploy/                         # NEU: Enterprise & Container Deployment
│   ├── docker/
│   │   ├── Dockerfile.server       # Multi-Stage Build für kafkalyzer-server (inkl. librdkafka/OpenSSL)
│   │   └── docker-compose.dev.yaml # Lokaler Kafka + Schema Registry + Kafkalyzer Server Stack
│   └── helm/
│       └── kafkalyzer/             # Helm Chart für K8s (Deployment, Service, Secret-Mounts, Ingress)
├── design/
├── lib/                            # Flutter Frontend (Material 3)
│   ├── core/
│   │   └── backend/                # NEU: Transport-Abstraktionsschicht
│   │       ├── kafka_backend.dart  # Abstraktes Interface für alle Operationen
│   │       ├── ffrb_backend.dart   # Implementierung via flutter_rust_bridge (Lokal / Desktop)
│   │       └── remote_backend.dart # Implementierung via gRPC / WebSockets (Remote K8s Server)
│   ├── features/
│   │   ├── cluster_profiles/       # Erweitert um Modus-Wahl: "Direct Kafka" vs. "Remote Kafkalyzer"
│   │   ├── mcp_settings/           # NEU: UI-Steuerung für den lokalen MCP-Server (Start/Stop, Port, Config)
│   │   ├── consumer_lag/
│   │   ├── message_viewer/
│   │   ├── multi_search/
│   │   ├── scripting/
│   │   └── topic_explorer/
│   ├── src/rust/                   # Generierter Code von flutter_rust_bridge v2
│   └── main.dart
├── linux/
├── macos/
├── windows/
├── openspec/                       # Zentralisierte KI-Spezifikationen (ersetzt redundante .agent* Ordner)
├── packages/
│   └── velopack_flutter/
├── rust/                           # NEU: Modularer Cargo Workspace statt Einzel-Crate
│   ├── Cargo.toml                  # Workspace-Definition
│   └── crates/
│       ├── kafkalyzer-core/        # Reine Business-Logik (rdkafka, Avro/Protobuf, Suche, Lag, Scripting)
│       ├── kafkalyzer-mcp/         # MCP-Protokoll-Implementierung (Tools, Prompts, Resources)
│       ├── kafkalyzer-bridge/      # FFI-Wrapper für flutter_rust_bridge v2 (Desktop-App)
│       └── kafkalyzer-server/      # Headless gRPC/HTTP- & MCP-Server für Docker/Kubernetes
├── rust_builder/                   # Bestehendes Build-Glue-System für Flutter Desktop
├── scripts/
│   ├── check_read_only.sh          # Erweitert auf alle Crates unter rust/crates/*
│   └── build_linux.sh
├── snap/
├── test/
├── flutter_rust_bridge.yaml        # Zeigt nun gezielt auf rust/crates/kafkalyzer-bridge
└── pubspec.yaml
```

---

## 2. Der Rust Cargo Workspace im Detail

Der Schlüssel zur Doppelverwendung (Desktop + K8s) ohne Code-Duplizierung liegt in `rust/Cargo.toml`. Die Logik wird in vier spezialisierte Crates aufgeteilt:

### A. `kafkalyzer-core` (Library Crate)
Hierhin wandert der gesamte bisherige Kafka- und Analyse-Code. Dieses Crate kennt weder Flutter noch HTTP/gRPC.
* **Inhalt**: `rdkafka`-Consumer-Management, Schema Registry Client (Avro, Protobuf, JSON Schema), Fast-Trace-Hashing, Multi-Topic-Regex/JSONPath-Filter, Consumer-Lag-Berechnung, Poison-Pill-Inspektion und die Scripting-Engine.
* **Garantie**: Alle Read-Only-Invarianten (`enable.auto.commit=false`, manuelles `assign()`, keine Producer) sind hier hart verankert.

### B. `kafkalyzer-mcp` (Library & Binary Crate)
Kapselt die gesamte KI-Integration über das **Model Context Protocol (MCP)** und nutzt intern ausschließlich `kafkalyzer-core`.
* **MCP Tools (Read-Only)**:
  * `list_topics_and_watermarks`: Liefert Topic-Metadaten, Partitionen und Offsets.
  * `inspect_consumer_lag`: Gibt Lag-KPIs, Deltas und potenzielle Poison-Pill-Offsets einer Consumer Group zurück.
  * `fetch_and_decode_messages`: Liest Nachrichten ab einem Offset/Timestamp inkl. automatischer Avro-/Protobuf-Deserialisierung.
  * `fast_trace_key`: Berechnet den Ziel-Hash eines Keys und sucht gezielt in der entsprechenden Partition.
  * `multi_topic_search`: Führt eine gefilterte Suche über mehrere Topics aus.
  * `run_diagnostic_script`: Führt ein vordefiniertes Kafkalyzer-Diagnoseskript aus.
* **Dual-Transport**: Unterstützt sowohl **`stdio`** (Standard Input/Output für lokale Desktop-KI-Clients) als auch **Streamable HTTP / SSE** (Server-Sent Events für Netzwerk-/Kubernetes-Betrieb).

### C. `kafkalyzer-bridge` (Library Crate: `cdylib`, `staticlib`)
Ein sehr dünner Wrapper, der ausschließlich für die Desktop-App kompiliert wird.
* **Aufgabe**: Stellt die Funktionen aus `kafkalyzer-core` für `flutter_rust_bridge` v2 bereit.
* **Lokale MCP-Steuerung**: Bindet zusätzlich `kafkalyzer-mcp` ein. Über die Bridge kann der Nutzer direkt in der Flutter-Desktop-UI per Schalter einen lokalen MCP-Server (auf `127.0.0.1:<port>` via SSE oder als `stdio`-Hilfsbinary) starten, der sofort auf die in der Desktop-App geladenen Cluster-Profile zugreift.

### D. `kafkalyzer-server` (Binary Crate)
Das ausführbare Backend für Docker und Kubernetes.
* **API für das Flutter-Frontend**: Stellt eine gRPC- oder HTTP/WebSocket-Schnittstelle bereit (z. B. mit `tonic` oder `axum`), über die sich die Flutter-Desktop-App (oder eine zukünftige Flutter-Web-App) aus der Ferne verbinden kann.
* **Integrierter MCP-Endpunkt**: Mountet `kafkalyzer-mcp` direkt unter einem Pfad wie `/mcp/sse` bzw. `/mcp/message`.
* **Enterprise Config**: Liest Kafka-Cluster-Profile, Kerberos-Keytabs, AWS-MSK-IAM-Rollen und mTLS-Zertifikate direkt aus Kubernetes Secrets / Umgebungsvariablen, sodass kein Entwickler sensible Produktions-Credentials lokal speichern muss.

---

## 3. Wie der MCP-Server in beiden Welten funktioniert

Durch das eigene Crate `kafkalyzer-mcp` stehen drei flexible Betriebsmodi für KI-Agenten (wie Claude Desktop, Cursor, Cline oder eigene Enterprise-Agenten) bereit:

| Modus | Umgebung | Funktionsweise | Vorteil |
| :--- | :--- | :--- | :--- |
| **1. Desktop Embedded (UI-gesteuert)** | Lokal (Linux, macOS, Windows) | Die Flutter-Desktop-App startet über `kafkalyzer-bridge` im Hintergrund einen lokalen MCP-HTTP/SSE-Listener (z. B. `http://127.0.0.1:9432/mcp`). | KI-Tools im selben System nutzen exakt die aktive Verbindung und entsperrten Profile der geöffneten Desktop-App. |
| **2. Desktop CLI (`stdio`)** | Lokal (Headless Subprozess) | Beim Desktop-Build wird eine kleine Zusatz-Binary `kafkalyzer-mcp-cli` mitgeliefert, die der KI-Client per `stdio` aufruft. | Funktioniert auch, wenn das Kafkalyzer-GUI-Fenster geschlossen ist; liest die lokalen Profile aus dem OS-Keychain/Config. |
| **3. Kubernetes / Docker (Remote)** | Enterprise Cluster | `kafkalyzer-server` läuft als Pod im K8s-Cluster nahe an den Kafka-Brokern und exponiert den MCP-Server über HTTPS (geschützt per Bearer-Token / OIDC). | Zentrale KI-Agenten (CI/CD-Bots, Incident-Response-Agenten) und Entwickler-IDEs greifen ohne lokale Kafka-Zertifikate sicher und read-only auf Cluster-Diagnosen zu. |

---

## 4. Anpassung im Flutter-Frontend (Client-Abstraktion)

Damit die Flutter-App sowohl lokal (wie bisher) als auch als Remote-Client gegen Kubernetes funktioniert, wird in Dart zwischen UI/State-Management und der `flutter_rust_bridge` ein Interface eingezogen:

```dart
// lib/core/backend/kafka_backend.dart
abstract class KafkaBackend {
  Future<List<TopicSummary>> getTopics(String clusterId);
  Stream<DecodedMessage> observeMessages(ConsumptionRequest request);
  Future<LagReport> getConsumerGroupLag(String clusterId, String groupId);
  // ... weitere Methoden
}
```

1. **`FfrbKafkaBackend` (Lokal)**: Ruft wie bisher direkt die generierten Rust-Bridge-Funktionen auf. Latenz ist minimal, ideal für lokale Entwicklung oder direkte VPN-Verbindungen.
2. **`RemoteKafkaBackend` (Kubernetes)**: Kommuniziert per gRPC-Streaming oder WebSockets mit dem `kafkalyzer-server`-Pod in Kubernetes.

**UX-Gewinn im Cluster-Profil-Manager**:
Wenn ein User in Kafkalyzer ein neues Profil anlegt, wählt er künftig den Verbindungstyp:
* **Direkte Kafka-Verbindung (Lokal)**: Eingabe von Bootstrap-Servern, SASL/mTLS und Schema Registry (wird lokal via Rust-Bridge ausgeführt).
* **Kafkalyzer Remote Server (Enterprise)**: Eingabe von lediglich einer URL (z. B. `https://kafkalyzer.internal.company.com`) und einem Auth-Token. Alle vorkonfigurierten Enterprise-Cluster stehen sofort bereit – ohne lokales `cacert.pem`-Setup unter Windows.

---

## 5. CI/CD & Read-Only Enforcement (`check_read_only.sh`)

Das bestehende Sicherheitsversprechen (**Read-Only by Design**) wird auf die Server- und MCP-Komponenten ausgeweitet:

1. **Erweiterung von `scripts/check_read_only.sh`**:
   * Prüft weiterhin `rust/crates/kafkalyzer-core` auf das Fehlen jeglicher Producer-Typen, `subscribe()`-Aufrufe und Offset-Commits.
   * Stellt zusätzlich sicher, dass `rdkafka` **ausschließlich** in `kafkalyzer-core` als Dependency in der `Cargo.toml` auftaucht. Weder `kafkalyzer-mcp` noch `kafkalyzer-server` dürfen eigene Kafka-Clients instanziieren. Damit ist mathematisch und architektonisch garantiert, dass auch kein MCP-Tool jemals in Kafka schreiben oder Offsets verändern kann.
2. **Bereinigung des Repositories**:
   * Entfernen von `.insecure_curlrc` aus dem Root-Verzeichnis.
   * Konsolidierung der verteilten KI-Verzeichnisse (`.agent`, `.agents`, `.cline`, `.clinerules`, `.continue`, `.cursor`, `.pi`) in eine saubere Quelle unter `openspec/`, aus der bei Bedarf lokale Symlinks generiert werden.