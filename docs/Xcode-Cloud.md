# Xcode Cloud für Migraine Tracker

## Zielbild

Dieses Projekt verwendet ein Hybrid-Modell:

- `GitHub Actions` ist der primäre CI-Kanal für Builds, Unit-Tests und PR-Feedback
- `Xcode Cloud` ist der CD-Kanal für signierte Archive, `TestFlight` und spätere `App Store`-Submissions

In `Xcode Cloud` gibt es genau zwei Workflows:

1. `CI + TestFlight`
2. `App Store Release`

## Vorbedingungen

Vor der Einrichtung in `App Store Connect` und `Xcode` müssen diese Punkte erfüllt sein:

- das Bundle `eu.mpwg.MigraineTracker` existiert bereits in `App Store Connect`
- in `Xcode Cloud` ist die Umgebungsvariable `APPLE_DEVELOPER_TEAM_ID` gesetzt
- in `Xcode Cloud` ist die Umgebungsvariable `SENTRY_DSN` als Secret gesetzt
- in `GitHub Actions` ist das Secret `APPLE_DEVELOPER_TEAM_ID` gesetzt
- optionale GitHub-Secrets für konsistente Laufzeitkonfiguration sind `SENTRY_DSN` und `TELEMETRY_APP_ID`
- das Shared Scheme `MigraineTracker` ist versioniert
- Code Signing bleibt auf `Automatic`
- die vorhandenen Entitlements für Push und iCloud bleiben aktiv

Aus dem Projekt bestätigt:

- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM = $(APPLE_DEVELOPER_TEAM_ID)`
- `Debug` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Development`
- `Release` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Production`

Damit kann Xcode Cloud die erforderlichen Signing-Assets über Apple-verwaltete Signierung bereitstellen, ohne `fastlane match` oder lokale `.env`-Secrets. Die Team-ID und die Sentry-DSN werden lokal und in CI über `MigraineTracker/Configs/LocalSecrets.xcconfig` bereitgestellt.

## Zuständigkeiten

`GitHub Actions` ist für die übliche Entwicklungsarbeit zuständig:

- `pull_request` auf `main`
- `push` auf `main`
- Build des Shared Scheme `MigraineTracker`
- Ausführung von `MigraineTrackerTests`
- Upload des `xcresult` als Artifact

`Xcode Cloud` ist ausschließlich für Distribution zuständig:

- `main` zu `TestFlight`
- Git-Tags `vX.Y.Z` zum `App Store`
- Apple-verwaltetes Signing für Archive und Distribution

## Workflow 1: CI + TestFlight

Dieser Workflow ist für Beta-Verteilung auf Basis eines erfolgreichen `main`-Pushs zuständig.

- Name: `CI + TestFlight`
- Startbedingung: `Branch Changes`
- Branch: nur `main`
- Scheme: `MigraineTracker`
- Aktionen:
  - Archive
  - Distribution nach `TestFlight`

Konfiguration:

- Build- und Testfeedback für PRs und normale `main`-Pushes kommt primär aus `GitHub Actions`
- Xcode Cloud darf optional weiterhin Build- und Test-Aktionen enthalten, ist aber nicht mehr das primäre Entwickler-Feedback-System
- Distribution: interne und externe Testergruppen zuweisen
- Signing: von Xcode Cloud verwaltet
- erforderliche Umgebungsvariablen:
  - `APPLE_DEVELOPER_TEAM_ID`
  - `SENTRY_DSN` (als Secret)

Hinweis zu externer Verteilung:

- Xcode Cloud kann Builds für externe Tester vorbereiten und verteilen, soweit die zugehörigen Review- und Compliance-Voraussetzungen in `App Store Connect` erfüllt sind
- fachliche Freigaben in `App Store Connect` bleiben davon unberührt

## Workflow 2: App Store Release

Dieser Workflow ist ausschließlich für produktive Releases zuständig.

- Name: `App Store Release`
- Startbedingung: `Tag Changes`
- Tag-Muster: `v*`
- Scheme: `MigraineTracker`
- Aktionen:
  - Archive
  - Distribution in den `App Store`

Konfiguration:

- Produktion wird nie durch einen normalen Push auf `main` veröffentlicht
- ein Release wird nur durch ein Versions-Tag wie `v1.2.0` ausgelöst
- der Workflow soll die App als `App Store`-Build exportieren und an die bestehende App in `App Store Connect` liefern
- erforderliche Umgebungsvariablen:
  - `APPLE_DEVELOPER_TEAM_ID`
  - `SENTRY_DSN` (als Secret)

## Versionierte Xcode-Cloud-Skripte

Das Repo enthält ein `ci_scripts`-Verzeichnis für Xcode Cloud.

- `ci_post_clone.sh` protokolliert die Build-Kontexte und bestätigt das erwartete Projekt-Setup
- `ci_pre_xcodebuild.sh` erzwingt die Release-Regeln des Projekts:
  - erwartet die Variablen `APPLE_DEVELOPER_TEAM_ID` und `SENTRY_DSN`
  - erzeugt `MigraineTracker/Configs/LocalSecrets.xcconfig` aus `APPLE_DEVELOPER_TEAM_ID` und dem Secret `SENTRY_DSN`
  - `CI + TestFlight` ist für Branch-Builds auf `main`
  - `App Store Release` akzeptiert nur Tags im Format `vX.Y.Z`
- `ci_post_xcodebuild.sh` protokolliert Ergebnis und Exportpfade eines erfolgreichen Archivlaufs

Die Skripte ersetzen keine Workflow-Konfiguration in `App Store Connect`, sichern aber die vereinbarten CD-Regeln im Build selbst ab.

## Release-Ablauf

### TestFlight

1. Änderungen nach `main` mergen
2. `GitHub Actions` führt `iOS CI` aus
3. Xcode Cloud startet `CI + TestFlight`
4. erfolgreiche Builds erscheinen in `TestFlight`
5. interne und externe Tester erhalten den Build gemäß Workflow-Konfiguration

### App Store

1. Release-Commit auf `main` auswählen
2. Git-Tag im Format `vX.Y.Z` erzeugen, zum Beispiel `v1.2.0`
3. Tag auf `origin` pushen
4. Xcode Cloud startet `App Store Release`
5. der Workflow erstellt die produktive App-Store-Submission

Beispiel:

```sh
git tag v1.2.0
git push origin v1.2.0
```

## Abnahme nach der Einrichtung

Die Xcode-Cloud-Einrichtung gilt als korrekt, wenn:

- `GitHub Actions` bei `pull_request` und `push` auf `main` erfolgreich läuft
- ein Push auf `main` den Workflow `CI + TestFlight` startet
- der erfolgreiche `main`-Lauf einen `TestFlight`-Build erzeugt
- ein Tag wie `v1.2.0` ausschließlich den Workflow `App Store Release` startet
- der Tag-Workflow ein veröffentlichbares Archiv und eine App-Store-Submission erzeugt
