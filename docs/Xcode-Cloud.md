# GitHub Actions Releases für Migraine Tracker

## Zielbild

Dieses Projekt verwendet `GitHub Actions` als einzigen CI/CD-Kanal:

- `GitHub Actions` ist der CI-Kanal für Builds, Unit-Tests und PR-Feedback
- `GitHub Actions` ist auch der CD-Kanal für signierte Archive, `TestFlight` und tag-gesteuerte `App Store`-Submissions

Es gibt genau drei relevante Workflows:

1. `iOS CI`
2. `TestFlight Release`
3. `App Store Release`

## Vorbedingungen

Vor der Einrichtung in `App Store Connect` und `GitHub` müssen diese Punkte erfüllt sein:

- das Bundle `eu.mpwg.MigraineTracker` existiert bereits in `App Store Connect`
- in `GitHub Actions` sind diese Secrets gesetzt:
  - `APPLE_DEVELOPER_TEAM_ID`
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_KEY_ID`
  - `APP_STORE_CONNECT_PRIVATE_KEY`
  - `SENTRY_DSN`
- optional ist `TELEMETRY_APP_ID`
- das Shared Scheme `MigraineTracker` ist versioniert
- Code Signing bleibt auf `Automatic`
- die vorhandenen Entitlements für Push und iCloud bleiben aktiv
- der verwendete App-Store-Connect-Schlüssel ist ein Team-Key, kein Individual Key

Aus dem Projekt bestätigt:

- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM = PZV43D6HWT`
- `Debug` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Development`
- `Release` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Production`

Damit kann `xcodebuild` in GitHub Actions die erforderlichen Signing-Assets über Apple-verwaltete Signierung bereitstellen, ohne `fastlane match` oder lokale Zertifikatsimporte. Team-ID, Sentry-DSN und optionale Telemetrie werden in CI über `MigraineTracker/Configs/LocalSecrets.xcconfig` bereitgestellt.

## Zuständigkeiten

`GitHub Actions` ist für die übliche Entwicklungsarbeit zuständig:

- `pull_request` auf `main`
- `push` auf `main`
- Build des Shared Scheme `MigraineTracker`
- Ausführung von `MigraineTrackerTests`
- Upload des `xcresult` als Artifact

Die Release-Workflows in `GitHub Actions` übernehmen zusätzlich die Distribution:

- `main` zu `TestFlight`
- Git-Tags `vX.Y.Z` zum `App Store`
- Apple-verwaltetes Signing für Archive und Distribution via App-Store-Connect-Team-Key

## Workflow 1: iOS CI

Dieser Workflow liefert schnelles Entwickler-Feedback.

- Name: `iOS CI`
- Startbedingung: `pull_request` auf `main` und `push` auf `main`
- Scheme: `MigraineTracker`
- Aktionen:
  - Build
  - Tests
  - Upload des `xcresult`

## Workflow 2: TestFlight Release

Dieser Workflow ist für Beta-Verteilung auf Basis eines erfolgreichen `main`-Pushs zuständig.

- Name: `TestFlight Release`
- Startbedingung: `push` auf `main`
- Scheme: `MigraineTracker`
- Aktionen:
  - `Release`-Archiv bauen
  - automatische Signierung mit `-allowProvisioningUpdates`
  - Upload nach `TestFlight`
  - `CURRENT_PROJECT_VERSION` aus `github.run_number` setzen
  - `LocalSecrets.xcconfig` aus GitHub-Secrets erzeugen

Dieser Workflow ist ausschließlich für produktive Releases zuständig.

- Name: `App Store Release`
- Startbedingung: `push` auf Git-Tags
- Tag-Muster: `v*`
- Scheme: `MigraineTracker`
- Aktionen:
  - Validierung des Tags `vX.Y.Z`
  - Abgleich mit `MARKETING_VERSION`
  - `Release`-Archiv bauen
  - Upload des getaggten Commits nach `App Store Connect`
  - Anlegen oder Wiederverwenden der Version `X.Y.Z`
  - Zuordnung des hochgeladenen Builds zur Version
  - direkte Submission an den `App Store`

Konfiguration:

- Produktion wird nie durch einen normalen Push auf `main` veröffentlicht
- ein Release wird nur durch ein Versions-Tag wie `v1.2.0` ausgelöst
- der Workflow baut den getaggten Commit neu und promotet nicht einen vorhandenen `TestFlight`-Build
- der App-Store-Submit erfolgt über die `App Store Connect API`
- die App-Version im Projekt bleibt führend; der Tag ändert sie nicht

## Versionierte CI-Skripte

Das Repo enthält gemeinsame Release-Skripte in `ci_scripts`.

- `github_common.sh` kapselt Secrets, Build-Einstellungen, Export-Optionen und Archivierung
- `github_archive_upload.sh` baut und lädt Release-Artefakte für `TestFlight` oder `App Store Connect` hoch
- `app_store_connect.py` ordnet einen verarbeiteten Build der App-Store-Version zu und stößt die Submission an

Die früheren `Xcode Cloud`-Hilfsskripte bleiben nur als Historie im Repo und sind kein aktiver Release-Pfad mehr.

## Release-Ablauf

### TestFlight

1. Änderungen nach `main` mergen
2. `GitHub Actions` führt `iOS CI` aus
3. `GitHub Actions` startet `TestFlight Release`
4. ein neuer signierter Build erscheint in `TestFlight`

### App Store

1. Release-Commit auf `main` auswählen
2. Git-Tag im Format `vX.Y.Z` erzeugen, zum Beispiel `v1.2.0`
3. Tag auf `origin` pushen
4. `GitHub Actions` startet `App Store Release`
5. der Workflow validiert `MARKETING_VERSION = X.Y.Z`
6. der Workflow lädt einen neuen Build hoch und submitted die Version

Beispiel:

```sh
git tag v1.2.0
git push origin v1.2.0
```

## Abnahme nach der Einrichtung

Die GitHub-Actions-Einrichtung gilt als korrekt, wenn:

- `GitHub Actions` bei `pull_request` und `push` auf `main` erfolgreich läuft
- ein Push auf `main` den Workflow `TestFlight Release` startet
- der erfolgreiche `main`-Lauf einen `TestFlight`-Build erzeugt
- ein Tag wie `v1.2.0` ausschließlich den Workflow `App Store Release` startet
- der Tag-Workflow ein veröffentlichbares Archiv und eine App-Store-Submission erzeugt
