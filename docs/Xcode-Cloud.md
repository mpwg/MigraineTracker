# GitHub Actions Releases für Symi

## Zielbild

Dieses Projekt verwendet `GitHub Actions` als CI/CD-Kanal:

- `iOS CI` prüft Pull Requests, `main` und manuelle CI-Läufe.
- `TestFlight` verteilt signierte Beta-Builds ausschließlich per manuellem Start.
- `App Store Release` lädt produktive Builds ausschließlich per manuellem Start hoch.
- Es gibt keine Release-Automatik durch Pushes, Merges oder Tags.

Der konkrete Ablauf steht in [Release-Prozess](/Users/mat/code/Symi/docs/Release-Prozess.md).

## Vorbedingungen

- Das Bundle `eu.mpwg.MigraineTracker` existiert in App Store Connect.
- Die Bundle ID `eu.mpwg.MigraineTracker` bleibt aus Release- und Migrationsgründen bestehen.
- Das Shared Scheme `Symi` ist versioniert.
- Das Match-Repository enthält ein gültiges `appstore`-Zertifikat und ein passendes Provisioning Profile.
- Die vorhandenen Entitlements für Push, WeatherKit, HealthKit und iCloud bleiben aktiv.
- Der iCloud-Container bleibt `iCloud.eu.mpwg.MigraineTracker`.
- Der App-Store-Connect-Schlüssel ist ein Team-Key.

Erforderliche GitHub-Secrets:

- `APPLE_DEVELOPER_TEAM_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `MATCH_GIT_URL`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `SENTRY_DSN`

Optionale GitHub-Secrets:

- `MATCH_GIT_BRANCH`
- `TELEMETRY_APP_ID`

## Branch-Regeln

- `main` ist Produktionswahrheit und wird erst nach erfolgreichem Release aktualisiert.
- `develop` ist optional.
- `release/*` ist der einzige erlaubte Branch-Typ für TestFlight und App Store.
- Versionen werden nicht aus Branch-Namen abgeleitet.

## Workflows

### iOS CI

- Datei: `.github/workflows/ios-ci.yml`
- Start: `pull_request`, `push` auf `main`, manueller Start
- Zweck: Build, Tests, UI-Smokes und schnelle Rückmeldung

### TestFlight

- Datei: `.github/workflows/testflight.yml`
- Start: ausschließlich `workflow_dispatch`
- Pflicht-Input: `changelog`
- Guardrails:
  - Branch muss `release/*` sein
  - Changelog darf nicht leer sein
  - Release-Secrets müssen vorhanden sein
- Fastlane-Lane: `bundle exec fastlane ios beta`

### App Store Release

- Datei: `.github/workflows/appstore.yml`
- Start: ausschließlich `workflow_dispatch`
- Pflicht-Inputs:
  - `version`
  - `confirm_release`, exakt `YES`
- Guardrails:
  - Branch muss `release/*` sein
  - Version muss im Format `X.Y.Z` sein
  - Version muss zur `MARKETING_VERSION` im Xcode-Projekt passen
  - Version darf in App Store Connect noch nicht existieren
  - `fastlane/metadata` muss versionierte Dateien enthalten
  - `fastlane/screenshots` muss PNG-Screenshots enthalten
  - Release-Secrets müssen vorhanden sein
- Fastlane-Lanes:
  - `bundle exec fastlane ios verify_release`
  - `bundle exec fastlane ios ensure_version_not_released`
  - `bundle exec fastlane ios release`

## Fastlane

Die Release-Lanes erzeugen in CI ein lokales Secrets-`xcconfig`, laden über `match` Distribution-Zertifikate und Provisioning Profiles in ein temporäres Keychain und bauen anschließend mit manuellem Distribution-Signing.

Wichtige Lanes:

- `ios beta`: Buildnummer setzen, Release-IPA bauen, Entitlements prüfen, nach TestFlight hochladen
- `ios verify_release`: Version, Metadaten und Screenshots prüfen
- `ios release`: Version erneut prüfen, Duplikat in App Store Connect verhindern, Release-IPA bauen, Metadaten und Screenshots mit `deliver` hochladen

Die App-Store-Einreichung und Veröffentlichung bleiben manuell in App Store Connect.

## Abnahme

Die Einrichtung gilt als korrekt, wenn:

- `iOS CI` auf Pull Requests und `main` erfolgreich läuft
- `TestFlight` nur auf einem `release/*` Branch startet
- `App Store Release` nur auf einem `release/*` Branch mit `confirm_release=YES` startet
- ein Git-Tag keinen Release-Workflow startet
- App Store Connect nach dem Upload eine prüfbare Version mit Build, Metadaten und Screenshots enthält
