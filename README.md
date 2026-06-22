# kafkalyzer

kafkalyzer is a high-performance, cross-platform Desktop Client for Apache Kafka, built with **Flutter** for the UI and **Rust** for the backend logic and heavy lifting.

## Architecture

The application leverages the power of two ecosystems:
- **Frontend (Flutter)**: Provides a responsive, beautiful, and native-feeling user interface. Handles state management and user interactions.
- **Backend (Rust)**: Handles Kafka connectivity, message consumption, protocol deserialization (Avro/Protobuf), and high-performance filtering.
- **Bridge**: Communication between Dart and Rust is seamlessly handled by `flutter_rust_bridge`.

## Key Features

### 🔌 Cluster Management
- Manage connections to multiple Kafka clusters.
- Support for various authentication mechanisms (Plain, SASL/SCRAM, etc.).

### 📂 Topic Explorer
- Browse topics and partitions.
- Inspect schemas (Avro/Protobuf) integrated with Schema Registry.

### 📨 Message Viewer
- Real-time message consumption.
- Automatic deserialization of Avro/JSON keys and values.
- Advanced filtering and search capabilities.

### 🔍 Multi-Search
- Powerful search functionality across topics.
- **Regex Support**: Filter messages based on complex patterns.
- **Fast Trace**: Optimized partition verification for specific keys.

### 📜 Scripting
- Integrated scripting environment (using Dart/Lua) to transform messages or automate workflows directly within the client.

### 💾 Local Data Storage

The application uses the `shared_preferences` plugin to store local data. The files are located in the following standard paths based on your operating system:

- **Linux**: `~/.local/share/at.greenhopper.kafkalyzer/shared_preferences.json`
- **Windows**: `C:\Users\<User>\AppData\Roaming\at.greenhopper\kafkalyzer\shared_preferences.json`
- **macOS**: `~/Library/Preferences/at.greenhopper.kafkalyzer.plist`

## Getting Started

### Prerequisites
- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Rust Toolchain**: [Install Rust](https://www.rust-lang.org/tools/install)
- **Codegen Tools**: `flutter_rust_bridge_codegen` (if modifying the bridge).

### Installation (Linux)

1.  Clone the repository:
    ```bash
    git clone https://github.com/greenhopper/sift_view.git
    cd kafkalyzer
    ```

2.  Install dependencies:
    ```bash
    flutter pub get
    ```

3.  Run the application:
    ```bash
    flutter run -d linux
    ```

### Windows Development Environment (Docker)

To simplify Windows development (building native Windows apps) from a Linux host, we provide a complete Docker-based build environment.

#### Quick Start
Run the setup script:
```bash
./runDockerWin.sh
```

#### Features
This headless Windows 11 environment includes:
- **Automated Toolchain**: Git, Flutter, Rust, and Visual Studio Build Tools 2022 (with C++ & MSVC v142 components).
- **German Locale**: Pre-configured language, region, and keyboard.
- **Shared Filesystem**: Maps the local `windows_shared` folder to `C:\Shared` inside the VM.

#### Access
- **Web Console**: [http://localhost:8006](http://localhost:8006)
- **RDP**: Connect to `localhost` with user `Docker` and password `admin`.

#### Customization
The installation script `windows_oem/install.ps1` is mounted into the container and runs on the first boot to provision the environment.

### ⚠️ Windows SSL Requirements

On Windows, the Kafka client (`librdkafka` with OpenSSL) **does not** automatically use the system's certificate store.

*   **Release Builds**: The `build_windows_release.bat` script automatically downloads a CA bundle (`cacert.pem`) and places it next to the executable.
*   **Debug/Manual Runs**: If you run the executable manually or in debug mode, you **MUST** ensure a `cacert.pem` file is present in the same directory as `kafkalyzer.exe` (or `runner.exe`). Without this, you may encounter `Broker Transport Failure` errors even with SSL verification disabled.

