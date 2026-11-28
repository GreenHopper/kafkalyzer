# Spec Delta

## MODIFIED Requirements

### Requirement: Windows Build Caching
Das CI-System MUST die `vcpkg`-Abhängigkeiten und das Rust-Zielverzeichnis des Native-Build-Schritts auf Windows zwischenspeichern, um zu verhindern, dass sie bei jedem Build aus dem Quellcode übersetzt werden. Der Cache-Schlüssel MUSS sich ändert, sobald sich die Abhängigkeitsliste oder die festgelegte Rust-Toolchain ändert.

#### Scenario: Schnellerer Windows-Build nach Cache-Restore
- **WHEN** der Windows-Build mit einem bereits vorhandenen Cache gestartet wird
- **THEN** darf die Kompilierung von `vcpkg` und Rust-Code die Gesamt-Buildzeit nicht über 15 Minuten steigen lassen

#### Scenario: Veralteter Cache führt nicht zu übersprungenem Code
- **WHEN** ein Windows-Build einen Cache eines früheren Commits wiederherstellt und seitdem Rust-Quellen des Bridge-Crates geändert wurden
- **THEN** MUSS das geänderte Crate neu kompiliert werden
- **AND** das gebaute Artefakt MUSS den geänderten Code enthalten

#### Scenario: Fehlender Cache behindert den Build nicht
- **WHEN** für den Windows-Build existiert kein Cache-Eintrag
- **THEN** MUSS der Build als Kaltbau erfolgreich durchlaufen
- **AND** MUSS ein Cache-Eintrag für spätere Builds angelegt werden
