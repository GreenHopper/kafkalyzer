# selective-release-builds Specification

## Purpose
TBD - created by archiving change optimize-windows-ci. Update Purpose after archive.
## Requirements
### Requirement: Schnelle Test-Pipeline
Für reguläre Pushes und Pull-Requests auf `main` MUST das CI-System nur die plattformunabhängigen Unit-Tests ausführen und keine vollständigen Plattform-Binärdateien kompilieren.

#### Scenario: Test-Pipeline bei Push auf main
- **WHEN** ein Push auf `main` erfolgt, der kein Release-Tag ist
- **THEN** MUSS der CI-Workflow einen dedizierten Test-Job starten, der `flutter test` und `cargo test` ausführt, und keine Release-Builds für Linux/macOS/Windows triggern

### Requirement: Automatischer Release-Build bei Tags
Das CI-System MUST bei Push eines Release-Tags (z. B. `v1.0.0`) automatisch die Release-Binärdateien für alle Zielplattformen bauen und ein entsprechendes GitHub-Release erstellen.

#### Scenario: Release-Pipeline bei Tag-Push
- **WHEN** ein Git-Tag vom Muster `v*` gepusht wird
- **THEN** MUSS das CI-System die Release-Builds für Linux, macOS und Windows parallel starten
- **THEN** MUSS das CI-System nach erfolgreichen Builds automatisch ein GitHub Release mit der entsprechenden Tag-Version erstellen und alle gebauten Archive hochladen

