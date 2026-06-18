# windows-ci Specification

## Purpose
TBD - created by archiving change optimize-windows-ci. Update Purpose after archive.
## Requirements
### Requirement: Windows Build Caching
Das CI-System MUST die `vcpkg`-Abhängigkeiten und das `cargokit`-Zielverzeichnis auf Windows zwischenspeichern, um zu verhindern, dass sie bei jedem Build aus dem Quellcode übersetzt werden.

#### Scenario: Schnellerer Windows-Build nach Cache-Restore
- **WHEN** der Windows-Build mit einem bereits vorhandenen Cache gestartet wird
- **THEN** darf die Kompilierung von `vcpkg` und Rust-Code die Gesamt-Buildzeit nicht über 15 Minuten steigen lassen

### Requirement: Sicheres Zertifikats-Bundle
Das Windows-Release-Paket MUST ein statisches CA-Zertifikats-Bundle enthalten, ohne während der Pipeline-Laufzeit auf externe Webressourcen zuzugreifen.

#### Scenario: Lokales Packen des Zertifikats
- **WHEN** der Post-Build-Schritt ausgeführt wird
- **THEN** MUSS die Datei `cacert.pem` aus dem lokalen Repository in das Release-Bundle kopiert werden, anstatt sie von `curl.se` herunterzuladen

