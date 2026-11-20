# kafkalyzer

kafkalyzer is a high-performance, cross-platform Desktop Client for Apache Kafka, built with **Flutter** for the UI and **Rust** for the backend logic and heavy lifting. It is designed to handle large-scale Kafka environments with a focus on developer productivity and performance.

## 🚀 Supported Platforms

- **Linux**: Ubuntu, Debian, and other major distributions.
- **macOS**: Native support for both Intel and Apple Silicon (M1/M2/M3).
- **Windows**: Windows 10 and 11.

## 📥 Downloads

Grab the latest stable release for your platform — the links below always resolve to the newest published build:

| Platform | Asset | |
| --- | --- | --- |
| 🐧 Linux | AppImage | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/Kafkalyzer.AppImage) |
| 🍎 macOS | Portable App | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/Kafkalyzer-osx-Portable.zip) |
| 🪟 Windows | Installer | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/Kafkalyzer-win-Setup.exe) |

> **Note:** The macOS archive contains a ready-to-use app bundle — unzip it and move the app into your `Applications` folder. All links use GitHub's `/releases/latest/download/` redirect, so they never expire when a new version ships.

## 🏗️ Architecture

The application leverages the power of two ecosystems:

- **Frontend (Flutter)**: Provides a responsive, beautiful, and native-feeling user interface using Material 3. Handles state management and user interactions.
- **Backend (Rust)**: Handles Kafka connectivity via `rdkafka`, message consumption, protocol deserialization (Avro/Protobuf), and high-performance filtering.
- **Bridge**: Communication between Dart and Rust is seamlessly handled by `flutter_rust_bridge` v2.

## 🛡️ Read-Only by Design

kafkalyzer is engineered specifically for observability, diagnostics, and stream analysis. **Write operations against connected Kafka clusters are excluded by architectural design.**

### Technical Invariants

1. **No Kafka Producers**: No producer clients (`Producer`, `ThreadedProducer`, `BaseProducer`, `FutureProducer`, `FutureRecord`) exist in the codebase.
2. **Explicit Partition Assignment**: The consumer uses manual partition assignment (`assign()`). It never uses consumer group subscriptions (`subscribe()`), ensuring that running kafkalyzer never triggers partition rebalances or disrupts consumer group topologies.
3. **No Offset Commits**: Consumer clients explicitly configure `enable.auto.commit=false`, and zero offset commit methods (`commit()`, `commit_message()`, `commit_consumer_state()`) are implemented. Consuming or seeking messages never moves consumer group progress on the broker.
4. **Read-Only Metadata**: Broker interactions are strictly limited to `fetch_metadata`, `fetch_watermarks`, and `describe_configs`.

### Verifiable CI Enforcement Gate

To prevent accidental regressions, kafkalyzer includes an automated static analysis verification script that runs on every pull request and build before compilation:

```bash
# Verify read-only invariants locally
./scripts/check_read_only.sh
```

### Recommended Least-Privilege Service Account (Defense-in-Depth)

While kafkalyzer cannot write to Kafka, enterprise best practice recommends configuring broker-side ACLs so that the connecting service account has only read permissions:

```bash
# Allow read and metadata access on topics
kafka-acls.sh --bootstrap-server <bootstrap:9092> \
  --add --allow-principal User:kafkalyzer \
  --operation Describe --operation Read --operation DescribeConfigs \
  --topic "*"

# Allow inspecting consumer groups and lag
kafka-acls.sh --bootstrap-server <bootstrap:9092> \
  --add --allow-principal User:kafkalyzer \
  --operation Describe \
  --group "*"
```

> [!TIP]
> Do **NOT** grant `Write`, `AlterConfigs`, `Alter`, or `IdempotentWrite` permissions. They are never required by kafkalyzer.


## ✨ Key Features

### 🔌 Cluster Management & Enterprise Security

- Manage connections to multiple Kafka clusters.
- **Authentication**: Support for PLAIN, SASL/SCRAM, Kerberos (GSSAPI), SASL OAuthBearer, AWS MSK IAM, and mTLS via PEM certificate/key pairs.
- **Schema Registry**: Support for Basic Auth and HTTPS with TLS certificate inheritance.

### 📈 Consumer Lag Monitoring

- Real-time KPI dashboard tracking active consumer groups, total lag, and lag rate deltas over time.
- **Poison Pill Identification**: Directly inspect messages at current consumer offsets without advancing committed offsets.
- **Query Throttling**: Configurable concurrency limits for background lag queries in Settings.

### 📂 Topic Explorer & Schema Registry

- Browse topics, partitions, log-end offsets, and partition details.
- Schema integration with Confluent Schema Registry (Avro, Protobuf, and Confluent JSON Schema).

### 📨 Message Viewer & Inspection

- Real-time consumption with ad-hoc seeking and multiple inspection modes (Table, Diff, and Timeline views).
- **Format Decoding**: Automatic deserialization of Avro, Protobuf, JSON, Hex, and UTF-8 decoded headers.
- **Large Message Handling**: Non-blocking background processing in Dart Isolates with visual progress and safe output truncation (>500k chars) while preserving raw exports.

### 🔍 Multi-Search

- Powerful search functionality across multiple topics simultaneously with configurable stream start/end conditions.
- **Regex & Structured Filter Expressions**: Filter keys and values with substring, exact, or regex matching, or combine typed conditions on payloads, keys, headers, and metadata (`AND`/`OR`/`NOT`), e.g.:
  `(header.eventType = "OrderCreated" OR value.status = "FAILED") AND NOT partition = 0`
- **Fast Trace**: Hash-based partition verification for targeted key lookup.

### 📜 Scripting & Automated Outputs

- Multi-step scripting environment with execution history, parameter prompts, and output diffing.
- **Unified Output Directory**: Automatic structured file export under `Documents/kafkalyzer/<Script_Name>/<Run_ID>`.

### 📦 Export, Import & Customization

- **Data Export**: Export single-topic messages as `.json` or multi-topic selections as `.zip` archives.
- **Profile Backup**: Export and import cluster profiles (including SSL certificates) and saved scripts for team sharing.
- **Localization & Themes**: Built-in English and German (i18n) support with Dark and Light mode themes.

## 💾 Local Data Storage

The application uses `shared_preferences` to store local configurations and cluster profiles. The files are located in:

- **Linux**: `~/.local/share/at.greenhopper.kafkalyzer/shared_preferences.json`
- **macOS**: `~/Library/Preferences/at.greenhopper.kafkalyzer.plist`
- **Windows**: `C:\Users\<User>\AppData\Roaming\at.greenhopper\kafkalyzer\shared_preferences.json`

## 🛠️ Getting Started

### Prerequisites

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Rust Toolchain**: [Install Rust](https://www.rust-lang.org/tools/install)
- **Codegen Tools**: `flutter_rust_bridge_codegen` v2 (only if modifying the bridge).

### Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/greenhopper/kafkalyzer.git
    cd kafkalyzer
    ```

2. Install dependencies:

    ```bash
    flutter pub get
    ```

3. Run the application:

    ```bash
    # For Linux
    flutter run -d linux
    # For macOS
    flutter run -d macos
    # For Windows
    flutter run -d windows
    ```

## 🏗️ Build & CI/CD

We use **GitHub Actions** for continuous integration and automated release packaging across Linux, macOS, and Windows.

- **Selective CI**: Pull requests and main pushes execute unit tests (`flutter test` and `cargo test`).
- **Source Quality Gates**: The `Source quality gates` job runs `bash scripts/quality_gates.sh`, the same script you can run locally before pushing:

  ```bash
  bash scripts/quality_gates.sh
  ```

  It checks Dart formatting (`dart format --output=none --set-exit-if-changed lib test`), the Dart analyzer (`flutter analyze`), Rust formatting (`cargo fmt --all --manifest-path rust/Cargo.toml --check`) and a source-file size guard, and stops at the first finding. Release builds wait for it. The size guard allows 800 lines per hand-written Dart file under `lib/`: it fails a change that takes a file from at or below 800 lines to above it, or adds a new file above 800 lines, and it leaves files that were already oversized at the merge base editable. Generated sources (`*.g.dart`, `*.freezed.dart`, `lib/src/rust/**`, `lib/l10n/**`) are exempt, and there is no exception list to add a file to. Locally the base revision is `origin/main`; set `KAFKALYZER_BASE_REF` to compare against another revision. The Rust lint check (`cargo clippy --workspace --all-targets -- -D warnings`) is not enabled yet: 30 pre-existing findings must be removed first.
- **Automated Releases**: Pushing a version tag (`v*`) automatically builds release binaries for all target platforms and creates a GitHub Release.
- **Artifacts**: You can find the latest binaries in the "Actions" tab or the "Releases" section of the repository.

### 🔒 TLS Verification

- **Enabled by Default**: TLS certificate and hostname verification are enabled by default for all `SSL` / `SASL_SSL` Kafka connections and `https://` Schema Registry connections.
- **Private CAs**: Configure a custom CA bundle or truststore via **Truststore Location (PEM or JKS)** in the cluster configuration dialog.
- **Per-Profile Opt-Out (Insecure)**: If you need to connect to a broker or registry with an untrusted or self-signed certificate without configuring a truststore, you can disable **Verify TLS certificates** in the cluster's SSL settings. Profiles with verification disabled are marked with an **Insecure TLS** badge in cluster settings, the configuration dialog, and open topic tabs.
- **Upgrade Transition**: Existing profiles created before TLS verification was restored are checked once on upgrade; if certificate verification fails, Kafkalyzer prompts you to either keep verification enabled or explicitly disable it for that profile.

### ⚠️ Windows SSL Requirements

On Windows, when no custom truststore is configured in the cluster profile, `librdkafka` falls back to `cacert.pem` next to the executable (pending final Windows/macOS spike confirmation).

- **Release Builds**: The automated build scripts bundle `cacert.pem` automatically.
- **Debug/Local Runs**: Place `cacert.pem` next to the executable if connecting to public-CA TLS brokers without an explicit truststore.

## 🧩 Local Schema Decoding (Offline)

kafkalyzer can decode Kafka message keys and values using local schema files without requiring a Schema Registry connection (or alongside one).

- **Supported Formats**:
  - **Avro (`.avsc`)**: Supports Confluent 5-byte wire-prefixed payloads, raw Avro binary payloads, or automatic detection (`Auto`).
  - **Protobuf Source (`.proto`)**: Single-file `proto3` definitions. When multiple top-level messages exist, select the target message type in the assignment dialog.
  - **Protobuf Descriptor Set (`.desc`, `.pb`, `.binpb`)**: Compiled `FileDescriptorSet` binaries — required for `proto2` schemas or `.proto` files with external imports. Compile with:

    ```bash
    protoc --include_imports --descriptor_set_out=schema.desc path/to/schema.proto
    ```

  - **JSON Schema (`.json`)**: Validates UTF-8 JSON payloads against a local JSON Schema file.
- **Precedence**:
  - **Fallback** (default): Uses Schema Registry when available and falls back to the local schema when no registry is configured or no schema is registered for the subject.
  - **Always**: Always decodes with the assigned local schema and skips Schema Registry lookups.
- **Machine-Local Paths**: Local schema assignments reference file paths on the current machine; headless/script runs share those persisted assignments on the same host.

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
