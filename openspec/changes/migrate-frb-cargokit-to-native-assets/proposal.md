# Proposal

## Why

Der macOS-Job wirft zwei Swift-Package-Manager-Warnungen: eine für `flutter_secure_storage` (durch das Update auf 10.3.4 erledigt) und eine für `rust_lib_kafkalyzer`. Die zweite Warnung verschwindet nur, wenn die Rust-Bibliothek nicht mehr als CocoaPods-/CMake-Plugin (`rust_builder/` mit Cargokit) gebaut wird. Cargokit ist ausserdem der Grund, warum der Windows-Job einen cargo-Fehler als kryptische `MSB8066 … exit code -1` meldete und erst durch einen manuellen Vorab-Build diagnostizierbar war. Zusätzlich baut der macOS-Job weiterhin für x86_64 — ein Weg, den seit dem Wegfall der Intel-Runner niemand nutzt und der über `gssapi-vendored`/`krb5-src` beim Cross-Compile mit `configure: error: Cannot test for constructor/destructor support when cross compiling` stirbt.

## What Changes

- Rust-Build des Bridge-Crates `rust_lib_kafkalyzer` von Cargokit auf **Flutter Native Assets** umstellen: `hook/build.dart` mit `RustBuilder` aus `native_toolchain_rust` — exakt das Muster, das das vendored `packages/velopack_flutter` bereits seit Q-10 auf allen drei Plattformen baut.
- **BREAKING** (nur für den Entwicklungs-Workflow): Der Plugin-Ordner `rust_builder/` und die Pfad-Abhängigkeit `rust_lib_kafkalyzer` in `pubspec.yaml` entfallen. Dev-Build, Test-Build und Release-Build nutzen denselben Build-Hook; es gibt keinen separaten Cargokit-Pfad mehr.
- `flutter_rust_bridge` von 2.11.1 auf **2.13.0** anheben (Native Assets ist erst ab 2.13.0-beta.2 verfügbar): `pubspec.yaml`, `rust/Cargo.toml`, `rust/kafkalyzer-mcp/Cargo.toml` und das vendored `packages/velopack_flutter`, inklusive Wiederauftragen der in `KAFKALYZER_PATCHES.md` dokumentierten Patches. Der Bindings-Guard in `scripts/quality_gates.sh` verlangt, dass pubspec-Pin, Cargo-Pin und installierte `flutter_rust_bridge_codegen`-Version identisch sind.
- `rust-toolchain.toml` einführen (Rust-Version + benötigte Targets) — Voraussetzung von `native_toolchain_rust`, das ohne festgelegte Toolchain nicht reproduzierbar baut.
- macOS-Release-Builds sind **arm64-only** (`EXCLUDED_ARCHS = x86_64` in der Projekt-Konfiguration von `macos/Runner.xcodeproj/project.pbxproj`), weil GitHub keine Intel-Runner mehr betreibt und die x86_64-Legs nur Vendor-Builds von OpenSSL/Kerberos kosten. Der CI-Step prüft die effektiv aufgelöste `ARCHS`, damit die Policy nicht stillschweigend verloren geht.
- macOS-Job schaltet Swift Package Manager **ein** statt aus (`flutter config --enable-swift-package-manager`), nachdem das letzte nicht-SPM-fähige Plugin entfernt ist.
- CI-Caching umstellen: Cache-Schlüssel und Pfade treffen das Native-Assets-Zielverzeichnis statt `cargokit_build` (Windows) und `Pods.build/…/rust_lib_kafkalyzer.build` (macOS). Der zeitweise eingebaute Windows-Diagnose-Build vor `flutter build windows` wird wieder entfernt.

## Capabilities

### New Capabilities
- `desktop-bridge-build`: Wie die Rust-Bibliothek der Bridge in die Desktop-App kommt — ein Build-Pfad für Entwicklung, Test und Release, festgelegte Rust-Toolchain, korrektes Bundling des Native Libraries auf allen drei Plattformen, und Caching genau dieses Build-Schritts.

### Modified Capabilities
- `windows-ci`: Die Caching-Anforderung nennt das `cargokit`-Zielverzeichnis; das existiert nicht mehr. Der Cache MUSS stattdessen das Verzeichnis des Native-Assets-Rust-Builds treffen.
- `selective-release-builds`: Der Release-Build bei Tag-Push baut "für alle Zielplattformen" ohne Architektur-Festlegung. Neu ist der macOS-Artefakt-Build auf arm64 beschränkt und verwendet Swift Package Manager.

## Impact

- **Build-Verdrahtung**: `pubspec.yaml` (Entfernen der `rust_builder`-Pfadabhängigkeit, FRB-Pin, `code_assets`/`hooks`/`native_toolchain_rust`), neu `hook/build.dart`, neu `rust-toolchain.toml`, `flutter_rust_bridge.yaml` (Backend-Umstellung via `flutter_rust_bridge_codegen integrate`), `analysis_options.yaml` (Ausschluss `rust_builder/**` entfällt).
- **Gelöscht**: ganzes Verzeichnis `rust_builder/` (Cargokit-Kopie, `macos/*.podspec`, `windows/CMakeLists.txt`, `linux/`).
- **Neu generiert**: `lib/src/rust/frb_generated.dart` und `rust/src/frb_generated.rs` (anderer Loader/Init-Pfad in 2.13), `linux/flutter/generated_plugins.cmake`, `windows/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift` verlieren den Eintrag `rust_lib_kafkalyzer`.
- **CI**: `.github/workflows/build.yml` — macOS-Job (SPM an, Arch-Prüfung), Windows-Job (Diagnose-Build raus, neuer Cache-Pfad), Linux-Job (Cache-Pfad).
- **Xcode**: `macos/Runner.xcodeproj/project.pbxproj` — `EXCLUDED_ARCHS = x86_64` in der Release-Konfiguration (bereits auf Branch `spike/keyring-ci` umgesetzt).
- **Vendored Package**: `packages/velopack_flutter/pubspec.yaml` (FRB-Pin) plus erneutes Anwenden der lokalen Patches.
- **Keine Auswirkung** auf Laufzeitverhalten, UI, Kafka- oder Schema-Registry-Zugriffe: **keine neuen Kafka- oder Schema-Registry-Aufrufe**. Der geladene Libraries-Name bleibt `rust_lib_kafkalyzer`, Crate-Namen und -Orte bleiben unverändert (Roadmap-Entscheidung E2).

**Read-only-Auswirkung**: keine neuen Kafka- oder Schema-Registry-Aufrufe.

**Vorlaufende Änderungen**: keine. Die arm64-Umstellung in `project.pbxproj` ist auf `spike/keyring-ci` bereits implementiert und wird in diesem Change mitgeführt. Das FRB-Support-Update (`flutter_secure_storage` 9.2.4 → 10.3.4) ist auf demselben Branch bereits gemischt.

## Non-Goals

- Intel/x86_64-Unterstützung für macOS — bewusst aufgegeben, kein Fat Binary, keine Universal-Artefakte.
- Upgrade auf `flutter_secure_storage` 11.x (erzwingt `file_picker` 13.x — zwei Major-Stände, 15 Dateien mit FilePicker-API).
- Ablösung von CocoaPods insgesamt, Umzug von `rust/`-Crates oder Umbenennung von `rust_lib_kafkalyzer` (Entscheidung E2: Crate-Namen und -Orte bleiben).
- Änderungen an App-Verhalten, Konfiguration oder Verschlüsselung.
- Auto-Update-/Velopack-Pipeline jenseits des nötigen FRB-Pins.
