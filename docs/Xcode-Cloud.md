# GitHub Actions Releases für Migraine Tracker

## Zielbild

Dieses Projekt verwendet `GitHub Actions` als einzigen CI/CD-Kanal:

- `GitHub Actions` ist der CI-Kanal für Builds, Unit-Tests und PR-Feedback
- `GitHub Actions` ist auch der CD-Kanal für signierte Archive, `TestFlight` und tag-gesteuerte `App Store`-Submissions über `fastlane`

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
  - `MATCH_GIT_URL`
  - `MATCH_PASSWORD`
  - `SENTRY_DSN`
- optional:
  - `MATCH_GIT_BRANCH`
  - `MATCH_GIT_BASIC_AUTHORIZATION`
  - `TELEMETRY_APP_ID`
- das Shared Scheme `MigraineTracker` ist versioniert
- das Match-Repository enthält ein gültiges `appstore`-Zertifikat und ein passendes Provisioning Profile für `eu.mpwg.MigraineTracker`
- die vorhandenen Entitlements für Push und iCloud bleiben aktiv
- der verwendete App-Store-Connect-Schlüssel ist ein Team-Key, kein Individual Key

Aus dem Projekt bestätigt:

- `DEVELOPMENT_TEAM = $(APPLE_DEVELOPER_TEAM_ID)`
- `Debug` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Development`
- `Release` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Production`

Die Release-Lanes erzeugen in CI ein lokales Secrets-`xcconfig`, laden über `match` Distribution-Zertifikate und Provisioning Profiles in ein temporäres Keychain und bauen anschließend reproduzierbar mit manuellem Distribution-Signing.

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
- Distribution-Signing über `fastlane match`

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
  - `setup_ci` für temporäres Keychain und `match`-Readonly-Modus
  - `match(type: "appstore")`
  - nächste Buildnummer über `latest_testflight_build_number` und `GITHUB_RUN_ID` bestimmen
  - `build_app(export_method: "app-store")`
  - Upload nach `TestFlight` mit `pilot`

Dieser Workflow ist ausschließlich für produktive Releases zuständig.

- Name: `App Store Release`
- Startbedingung: `push` auf Git-Tags
- Tag-Muster: `v*`
- Scheme: `MigraineTracker`
- Aktionen:
  - Validierung des Tags `vX.Y.Z`
  - Abgleich mit `MARKETING_VERSION`
  - `setup_ci` für temporäres Keychain und `match`-Readonly-Modus
  - `match(type: "appstore")`
  - Buildnummer wie im TestFlight-Lauf bestimmen
  - `build_app(export_method: "app-store")`
  - direkte Submission an den `App Store` über `deliver`

Konfiguration:

- Produktion wird nie durch einen normalen Push auf `main` veröffentlicht
- ein Release wird nur durch ein Versions-Tag wie `v1.2.0` ausgelöst
- der Workflow baut den getaggten Commit neu und promotet nicht einen vorhandenen `TestFlight`-Build
- die Zertifikate und Profile werden nicht mehr über Xcode-Automatik erzeugt, sondern über `match` synchronisiert
- die App-Version im Projekt bleibt führend; der Tag ändert sie nicht

## Versionierte CI-Skripte

Das Repo enthält die Release-Logik jetzt vollständig in `fastlane/Fastfile`.

- Lane `ios testflight` übernimmt Secrets, Signierung, Buildnummer, Build und Upload nach `TestFlight`
- Lane `ios app_store` validiert zusätzlich den Tag und submitted die IPA mit `deliver`
- `match` nutzt standardmäßig ein separates Git-Repository; auf CI läuft es über `setup_ci` im `readonly`-Modus

## Release-Ablauf

### TestFlight

1. Änderungen nach `main` mergen
2. `GitHub Actions` führt `iOS CI` aus
3. `GitHub Actions` startet `TestFlight Release`
4. `fastlane` synchronisiert Distribution-Signing mit `match`
5. `fastlane pilot` lädt die signierte IPA nach `TestFlight`

### App Store

1. Release-Commit auf `main` auswählen
2. Git-Tag im Format `vX.Y.Z` erzeugen, zum Beispiel `v1.2.0`
3. Tag auf `origin` pushen
4. `GitHub Actions` startet `App Store Release`
5. der Workflow validiert `MARKETING_VERSION = X.Y.Z`
6. `fastlane` synchronisiert Distribution-Signing mit `match`
7. `fastlane deliver` lädt den Build hoch und submitted die Version

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
