# GitHub Actions Releases für Symi

## Zielbild

Dieses Projekt verwendet `GitHub Actions` als einzigen CI/CD-Kanal:

- `GitHub Actions` ist der CI-Kanal für Builds, Unit-Tests und PR-Feedback
- `GitHub Actions` ist auch der CD-Kanal für signierte Archive, `TestFlight` und tag-gesteuerte App-Store-Uploads über `fastlane`

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
- das Shared Scheme `Symi` ist versioniert
- das Match-Repository enthält ein gültiges `appstore`-Zertifikat und ein passendes Provisioning Profile für `eu.mpwg.MigraineTracker`
- die vorhandenen Entitlements für Push und iCloud bleiben aktiv
- der verwendete App-Store-Connect-Schlüssel ist ein Team-Key, kein Individual Key

Aus dem Projekt bestätigt:

- `DEVELOPMENT_TEAM = $(APPLE_DEVELOPER_TEAM_ID)`
- `Debug` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Development`
- `Release` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Production`

Die Release-Lanes erzeugen in CI ein lokales Secrets-`xcconfig`, laden über `match` Distribution-Zertifikate und Provisioning Profiles in ein temporäres Keychain und bauen anschließend reproduzierbar mit manuellem Distribution-Signing.
Die GitHub-Workflows wählen für Swift-Builds explizit Xcode 26.4 aus.

## Zuständigkeiten

`GitHub Actions` ist für die übliche Entwicklungsarbeit zuständig:

- `pull_request` auf `main`
- `push` auf `main`
- Xcode 26.4 für Swift-Builds, Tests und Release-Archive
- schnelles PR-Gate aus SwiftLint und Catalyst-Unit-Tests
- iPhone-Simulator-Tests und UI-Smoke bei relevanten Änderungen, auf `main` oder per manuellem Start
- Upload von `xcresult`-Bundles nur bei Fehlern

Die Release-Workflows in `GitHub Actions` übernehmen zusätzlich die Distribution:

- manueller Start zu `TestFlight`
- Git-Tags `vX.Y.Z` zum `App Store`
- Distribution-Signing über `fastlane match`

## Workflow 1: iOS CI

Dieser Workflow liefert schnelles Entwickler-Feedback.

- Name: `iOS CI`
- Startbedingung: `pull_request` auf `main`, `push` auf `main` und manueller Start
- Scheme: `Symi`
- Aktionen:
  - SwiftLint/Design-Token-Regeln
  - Unit-Tests auf `Mac Catalyst`
  - Unit-Tests auf einem `iPhone 17`-Simulator bei Persistence-, Migration-, Backup- oder Import-Änderungen sowie auf `main`
  - fokussierter UI-Smoke auf einem `iPhone 17`-Simulator bei Home-, Capture- oder UI-Test-Änderungen sowie auf `main`
  - Upload der jeweiligen `xcresult`-Bundles nur bei Fehlern

## Workflow 2: TestFlight Release

Dieser Workflow ist für bewusst ausgelöste Beta-Verteilung zuständig.

- Name: `TestFlight Release`
- Startbedingung: manueller Start über `workflow_dispatch`
- Scheme: `Symi`
- Aktionen:
  - `setup_ci` für temporäres Keychain und `match`-Readonly-Modus
  - `match(type: "appstore")`
  - optionale manuelle Buildnummer übernehmen oder automatisch bestimmen
  - `build_app(export_method: "app-store")`
  - Upload nach `TestFlight` mit `pilot`

Dieser Workflow ist ausschließlich für produktive Releases zuständig.

- Name: `App Store Release`
- Startbedingung: `push` auf Git-Tags
- Tag-Muster: `v*`
- Scheme: `Symi`
- Aktionen:
  - Validierung des Tags `vX.Y.Z`
  - Abgleich mit `MARKETING_VERSION`
  - App-Store-Screenshots erzeugen und nach App Store Connect hochladen
  - `setup_ci` für temporäres Keychain und `match`-Readonly-Modus
  - `match(type: "appstore")`
  - Buildnummer wie im TestFlight-Lauf bestimmen
  - `build_app(export_method: "app-store")`
  - Upload des Builds nach App Store Connect über `deliver`

Konfiguration:

- Produktion wird nie durch einen normalen Push auf `main` veröffentlicht
- ein Release wird nur durch ein Versions-Tag wie `v1.2.0` ausgelöst
- der Workflow baut den getaggten Commit neu und promotet nicht einen vorhandenen `TestFlight`-Build
- die Zertifikate und Profile werden nicht mehr über Xcode-Automatik erzeugt, sondern über `match` synchronisiert
- die App-Version im Projekt bleibt führend; der Tag ändert sie nicht

## Versionierte CI-Skripte

Das Repo enthält die Release-Logik jetzt vollständig in `fastlane/Fastfile`.

- Lane `ios testflight` übernimmt Secrets, Signierung, Buildnummer, Build und Upload nach `TestFlight`
- Lane `ios release_app_store` validiert zusätzlich den Tag, erzeugt Screenshots, lädt Screenshots und IPA mit `deliver` hoch und reicht die Version nicht automatisch ein
- `match` nutzt standardmäßig ein separates Git-Repository; auf CI läuft es über `setup_ci` im `readonly`-Modus

## Release-Ablauf

### TestFlight

1. Änderungen nach `main` mergen
2. `GitHub Actions` führt `iOS CI` aus
3. Workflow `TestFlight Release` in GitHub Actions manuell starten
4. `fastlane` synchronisiert Distribution-Signing mit `match`
5. `fastlane pilot` lädt die signierte IPA nach `TestFlight`

### App Store

1. Release-Commit auf `main` auswählen
2. Git-Tag im Format `vX.Y.Z` erzeugen, zum Beispiel `v1.2.0`
3. Tag auf `origin` pushen
4. `GitHub Actions` startet `App Store Release`
5. der Workflow validiert `MARKETING_VERSION = X.Y.Z`
6. `fastlane` erzeugt die App-Store-Screenshots und lädt sie hoch
7. `fastlane` synchronisiert Distribution-Signing mit `match`
8. `fastlane deliver` lädt den Build hoch
9. App Store Connect öffnen, Build und Metadaten prüfen und manuell auf `Submit` klicken

Beispiel:

```sh
git tag v1.2.0
git push origin v1.2.0
```

## Abnahme nach der Einrichtung

Die GitHub-Actions-Einrichtung gilt als korrekt, wenn:

- `GitHub Actions` bei `pull_request` und `push` auf `main` erfolgreich läuft
- `iOS CI` das schnelle PR-Gate aus SwiftLint und Catalyst-Unit-Tests ausführt
- `iOS CI` iPhone- und UI-Gates bei relevanten Änderungen oder auf `main` ausführt
- ein manueller Start von `TestFlight Release` einen `TestFlight`-Build erzeugt
- ein Tag wie `v1.2.0` ausschließlich den Workflow `App Store Release` startet
- der Tag-Workflow Screenshots und ein veröffentlichbares Archiv in App Store Connect hochlädt, aber die Version nicht automatisch einreicht
