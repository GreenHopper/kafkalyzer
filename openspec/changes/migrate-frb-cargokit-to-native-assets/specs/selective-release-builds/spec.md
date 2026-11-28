# Spec Delta

## ADDED Requirements

### Requirement: MacOS-Release-Artefakte Nur Für Arm64
Der Release-Build für macOS MUST ausschließlich für die arm64-Architektur produzieren und Swift Package Manager verwenden. Ein Build für weitere macOS-Architekturen ist nicht Teil der Pipeline.

#### Scenario: Release-Build bei Tag-Push liefert ein arm64-Artefakt
- **WHEN** ein Git-Tag vom Muster `v*` gepusht wird
- **THEN** MUSS der macOS-Job ein Release-Artefakt für arm64 bauen und hochladen
- **AND** MUSS der Swift-Package-Manager-Modus in diesem Job eingeschaltet sein

#### Scenario: Aufgeloeste Architektur ist nicht arm64
- **WHEN** der macOS-Build andere Architekturen als arm64 aufloest
- **THEN** MUSS der Job mit einer Meldung fehlschlagen, die die aufgelösten Architekturen nennt
- **AND** DÜRFEN keine Artefakte für die nicht unterstützte Architektur hochgeladen werden

#### Scenario: Intel-Mac wird nicht geliefert
- **WHEN** ein Nutzer ein Release-Artefakt für einen Intel-Mac sucht
- **THEN** existiert kein solches Artefakt
- **AND** die Release-Beschreibung MUSS die arm64-Beschränkung nennen
