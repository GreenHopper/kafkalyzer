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
| 🐧 Linux | AppImage | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/Kafkalyzer-x86_64.AppImage) |
| 🍎 macOS | Portable App | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/Kafkalyzer.zip) |
| 🪟 Windows | Installer | [Download](https://github.com/GreenHopper/kafkalyzer/releases/latest/download/KafkalyzerSetup.exe) |

> **Note:** The macOS archive contains a ready-to-use app bundle — unzip it and move the app into your `Applications` folder. All links use GitHub's `/releases/latest/download/` redirect, so they never expire when a new version ships.

## 🏗️ Architecture

The application leverages the power of two ecosystems:

- **Frontend (Flutter)**: Provides a responsive, beautiful, and native-feeling user interface using Material 3. Handles state management and user interactions.
- **Backend (Rust)**: Handles Kafka connectivity via `rdkafka`, message consumption, protocol deserialization (Avro/Protobuf), and high-performance filtering.
- **Bridge**: Communication between Dart and Rust is seamlessly handled by `flutter_rust_bridge` v2.

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
- **Regex Support**: Filter messages based on complex patterns in keys, values, or headers.
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
- **Automated Releases**: Pushing a version tag (`v*`) automatically builds release binaries for all target platforms and creates a GitHub Release.
- **Artifacts**: You can find the latest binaries in the "Actions" tab or the "Releases" section of the repository.

### ⚠️ Windows SSL Requirements

On Windows, the Kafka client (`librdkafka` with OpenSSL) requires an explicit CA bundle for SSL connections.

- **Release Builds**: The automated build scripts bundle `cacert.pem` automatically.
- **Debug/Local Runs**: Ensure a `cacert.pem` file is present in the same directory as the executable. Without this, SSL verification will fail even if disabled in the cluster profile.
