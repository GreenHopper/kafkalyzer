## Context

Die Windows-Build-Pipeline auf GitHub Actions dauert derzeit ca. 42 Minuten.
Dies liegt hauptsächlich daran, dass:
1. `vcpkg` OpenSSL und cyrus-sasl bei jedem Cache-Miss (durch volatile Cache-Keys in `build.yml`) komplett neu aus dem Quellcode baut.
2. `cargokit` den Rust-Code bei jedem Windows-Lauf von Grund auf im Verzeichnis `build/windows/x64/plugins/rust_lib_kafkalyzer/cargokit_build` kompiliert, da dieses Verzeichnis im Gegensatz zu macOS nicht in GitHub Actions gecacht wird.
3. CA-Zertifikate während des Packaging-Schritts live von `curl.se` heruntergeladen werden, was bei Netzwerkausfällen oder Ausfall der Website zu Build-Abbrüchen führt.
4. Jede Änderung (Pushes & PRs) unnötigerweise alle drei Desktop-Releases von Grund auf kompiliert, was wertvolle Runner-Minuten verschwendet.

## Goals / Non-Goals

**Goals:**
- Reduzierung der Windows-Build-Dauer von ~42 Minuten auf unter 15 Minuten.
- Stabilisierung und Vermeidung unnötiger Cache-Misses auf Windows durch robustere Cache-Keys.
- Vermeidung von Live-Downloads externer Ressourcen während des Builds.
- **Einsparung von CI-Ressourcen:** Schnelle Ausführung von Unit-Tests (Flutter & Rust) bei standardmäßigen Pushes/PRs, ohne Kompilierung der App-Binärdateien.
- **Automatische Release-Erstellung:** Koppelung des vollständigen Multi-Plattform-Builds an Git-Tags (z. B. `v1.0.0`) und automatisches Erstellen eines GitHub Releases inklusive angehängter Binärdateien.

**Non-Goals:**
- Entfernung von `rdkafka`-Sicherheitsfeatures (SSL/SASL) oder Verzicht auf OpenSSL.
- Änderung der Pipeline-Konfiguration von Linux und macOS, außer zur Vereinheitlichung und Integration in die neue Release-Logik.

## Decisions

### 1. Statischer Cache-Key für vcpkg
- **Option A (Bisher):** Verwendung des Hashes von `.github/workflows/build.yml` für den Cache-Key. Führt bei jeder Änderung der Action-Datei (z. B. macOS/Linux-Anpassungen) zum Cache-Miss.
- **Option B (Gewählt):** Verwendung eines statischen Keys mit manueller Versionierung (`${{ runner.os }}-vcpkg-openssl-sasl-v1`). Da sich die C-Bibliotheken (OpenSSL, SASL) fast nie ändern, garantiert dies verlässliche Hits. Bei echten Änderungen kann die Version auf `v2` hochgezählt werden.

### 2. Caching des Windows Cargokit Build-Verzeichnisses
- **Option A (Bisher):** Kein Caching des Build-Verzeichnisses. Rust-Kompilierung läuft jedes Mal komplett neu.
- **Option B (Gewählt):** Caching von `build/windows/x64/plugins/rust_lib_kafkalyzer/cargokit_build` gebunden an `rust/Cargo.lock`. Dadurch wird inkrementelles Bauen der Rust-Abhängigkeiten ermöglicht, analog zum macOS-Job.

### 3. Einbindung eines statischen CA-Zertifikat-Bundles
- **Option A (Bisher):** Live-Download von `cacert.pem` via `Invoke-WebRequest`.
- **Option B (Gewählt):** Platzieren einer statischen Kopie von `cacert.pem` in `assets/cacert.pem` (oder `resources/cacert.pem`) im Repository. Im Packaging-Skript wird das Zertifikat nur noch lokal kopiert.

### 4. Trennung von Test- und Build-Pipelines & Release-Automatisierung
- **Option A (Bisher):** Ein einziger monolithischer Build bei jedem Push, der Builds hochlädt, aber keine echten GitHub-Releases anlegt.
- **Option B (Gewählt):** Aufteilung in Jobs und Bedingungen:
  1. **Job `run-tests`:** Läuft auf Ubuntu bei allen Push- und PR-Aktionen (außer bei Tags). Führt nur `flutter test` und `cargo test` aus.
  2. **Build-Jobs (`build-linux`, `build-macos`, `build-windows`):** Werden nur bei Push eines Tags `v*` oder manuellem Dispatch (`workflow_dispatch`) getriggert. Sie bauen die Binärdateien und laden sie als Artefakte hoch.
  3. **Job `create-release`:** Läuft nach erfolgreichem Abschluss der Build-Jobs (nur bei Tags/Dispatch). Sammelt alle Artefakte ein und erstellt ein GitHub Release (Draft oder direkt veröffentlicht) mittels `softprops/action-gh-release@v2`.

## Risks / Trade-offs

- **[Risk] Veraltete Zertifikate:** Das statisch hinterlegte `cacert.pem` könnte veralten.
  - **Mitigation:** Ein Dokumentationshinweis oder ein Skript zum Aktualisieren des Zertifikats wird bereitgestellt. Da sich Root-Zertifikate selten ändern, ist das Risiko gering.
- **[Risk] Cache-Größenbegrenzung auf GitHub:** Das zusätzliche Cachen des Windows-Rust-Builds verbraucht Speicherplatz (ca. 200MB).
  - **Mitigation:** Der Nutzen der Zeitersparnis überwiegt den Speicherverbrauch bei weitem. GitHub Actions löscht ältere Caches automatisch bei Erreichen des 10GB Limits.
- **[Risk] Fehlende Release-Rechte:** Der Release-Job könnte fehlschlagen, wenn das `GITHUB_TOKEN` keine Schreibrechte hat.
  - **Mitigation:** Der Workflow wird explizit mit `permissions: contents: write` deklariert.

