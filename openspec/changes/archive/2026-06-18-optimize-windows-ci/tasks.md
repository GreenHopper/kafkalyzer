## 1. Vorbereitungen und Zertifikat-Einbindung

- [x] 1.1 Herunterladen der aktuellen `cacert.pem` von curl.se und Speichern im Repository unter `assets/cacert.pem`
- [x] 1.2 Sicherstellen, dass das Verzeichnis `assets/` und die Datei `cacert.pem` im Repository eingecheckt werden (kein Ausschluss via `.gitignore`)

## 2. GitHub Actions Caching & Stabilität

- [x] 2.1 Ändern des vcpkg-Cache-Keys in `.github/workflows/build.yml` auf den stabilen Key `key: ${{ runner.os }}-vcpkg-openssl-sasl-v1`
- [x] 2.2 Hinzufügen des neuen Cache-Schritts für das Windows Cargokit-Build-Verzeichnis (`build/windows/x64/plugins/rust_lib_kafkalyzer/cargokit_build`) in `.github/workflows/build.yml`
- [x] 2.3 Anpassen des Windows Packaging-Schritts in `.github/workflows/build.yml`, sodass `assets/cacert.pem` kopiert wird anstelle des Live-Downloads von `curl.se`

## 3. Trennung der Pipelines und Release-Automatisierung

- [x] 3.1 Anpassen der `on`-Trigger in `.github/workflows/build.yml`, um Push von Tags (z. B. `v*`) und PRs abzufangen
- [x] 3.2 Erstellen des neuen Jobs `run-tests` (auf `ubuntu-latest`), der plattformübergreifend Tests (`flutter test` und `cargo test`) bei Pushes/PRs ausführt
- [x] 3.3 Hinzufügen von `if`-Bedingungen zu den Build-Jobs (`build-linux`, `build-macos`, `build-windows`), sodass diese nur bei Tag-Pushes oder `workflow_dispatch` laufen
- [x] 3.4 Hinzufügen des Jobs `create-release` (abhängig von den Build-Jobs), der die Artefakte herunterlädt und mit `softprops/action-gh-release@v2` hochlädt
- [x] 3.5 Deklarieren der `contents: write` Schreibberechtigung für das GitHub-Token im Workflow

