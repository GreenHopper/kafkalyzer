## Why

Die Windows-Build-Pipeline auf GitHub Actions dauert derzeit ca. 42 Minuten, was die CI-Feedback-Zeiten massiv verlangsamt (Linux benötigt ~8 Min., macOS ~15 Min.). Die Hauptgründe dafür sind:
1. Das erneute Kompilieren von `openssl` und `cyrus-sasl` (inkl. `krb5` etc.) aus dem Quellcode via `vcpkg` bei jedem Cache-Miss (Dauer: 25,5 Minuten), hervorgerufen durch einen zu volatilen Cache-Key.
2. Das vollständige Neukompilieren des Rust-Codes (Dauer: ~9 Minuten) im separate Cargokit-Build-Verzeichnis auf Windows, da dieses im Gegensatz zu macOS nicht im Workflow zwischengespeichert wird.
3. Ein instabiler Live-Download von CA-Zertifikaten im Packaging-Skript, der bei Serverausfällen den Build abbrechen lässt.
4. **Unnötige Builds bei jedem Commit:** Aktuell wird bei jedem Push auf `main` und bei jedem Pull-Request das gesamte Projekt für alle drei Plattformen (Linux, macOS, Windows) kompiliert, obwohl oft nur Tests ausgeführt werden müssten. Es gibt keine automatische Erstellung von Releases.

## What Changes

- **Stabilisiertes vcpkg-Caching:** Der vcpkg-Cache-Key auf Windows wird von einem volatilen Datei-Hash der `build.yml` auf einen stabilen, manuell versionierten Key umgestellt.
- **Cargokit-Caching für Windows:** Ein neuer Cache-Schritt wird in `.github/workflows/build.yml` hinzugefügt, um Cargokits Windows-Build-Verzeichnis analog zu macOS zu cachen.
- **Statisches CA-Zertifikat-Bundle:** Das Zertifikats-Bundle `cacert.pem` wird nicht mehr live während des CI-Laufs von `curl.se` heruntergeladen, sondern statisch im Repository abgelegt und kopiert.
- **Selektive Builds und Release-Kopplung:** Standard-Pushes und PRs führen nur noch einen schnellen, plattformübergreifenden Test-Job (Flutter & Rust) aus. Die vollständigen Release-Builds für Linux, macOS und Windows werden nur bei Push eines Git-Tags (z. B. `v1.0.0`) oder per manuellem Dispatch ausgelöst und erstellen automatisch ein GitHub Release mit den angehängten Build-Artefakten.

## Capabilities

### New Capabilities
- `selective-release-builds`: Trennung von Test- und Release-Pipelines sowie automatisches Erstellen von GitHub Releases bei Tag-Pushes.

### Modified Capabilities
- None

## Impact

- GitHub Actions Workflow-Konfiguration (`.github/workflows/build.yml`).
- Bereitstellung einer statischen `cacert.pem` im Repository (z. B. unter `assets/` oder einem ähnlichen Pfad) zur Vermeidung von Live-Downloads.
- Windows-Packaging-Schritt im GitHub Actions Workflow.
- Hinzufügen von Berechtigungen (`contents: write`) im GitHub-Workflow zum Erstellen von Releases.

