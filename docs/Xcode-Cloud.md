# Xcode Cloud für Migraine Tracker

## Zielbild

Dieses Projekt verwendet `Xcode Cloud` als einzigen unterstützten CI/CD-Weg für Build, Test, `TestFlight` und spätere App-Store-Releases.

Es gibt genau zwei Workflows:

1. `CI + TestFlight`
2. `App Store Release`

## Vorbedingungen

Vor der Einrichtung in `App Store Connect` und `Xcode` müssen diese Punkte erfüllt sein:

- das Bundle `eu.mpwg.MigraineTracker` existiert bereits in `App Store Connect`
- in `Xcode Cloud` ist die Umgebungsvariable `APPLE_DEVELOPER_TEAM_ID` gesetzt
- das Shared Scheme `MigraineTracker` ist versioniert
- Code Signing bleibt auf `Automatic`
- die vorhandenen Entitlements für Push und iCloud bleiben aktiv

Aus dem Projekt bestätigt:

- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM = $(APPLE_DEVELOPER_TEAM_ID)`
- `Debug` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Development`
- `Release` verwendet `ICLOUD_CONTAINER_ENVIRONMENT = Production`

Damit kann Xcode Cloud die erforderlichen Signing-Assets über Apple-verwaltete Signierung bereitstellen, ohne `fastlane match` oder lokale `.env`-Secrets. Die Team-ID liegt nicht im Git-Repo, sondern kommt über die Variable `APPLE_DEVELOPER_TEAM_ID`.

## Workflow 1: CI + TestFlight

Dieser Workflow ist für Integration und Beta-Verteilung zuständig.

- Name: `CI + TestFlight`
- Startbedingung: `Branch Changes`
- Branch: nur `main`
- Scheme: `MigraineTracker`
- Aktionen:
  - Build
  - Test
  - Archive
  - Distribution nach `TestFlight`

Konfiguration:

- Unit-Tests: `MigraineTrackerTests`
- Distribution: interne und externe Testergruppen zuweisen
- Signing: von Xcode Cloud verwaltet
- Keine projektspezifischen Secrets notwendig
- erforderliche Umgebungsvariable: `APPLE_DEVELOPER_TEAM_ID`

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
- erforderliche Umgebungsvariable: `APPLE_DEVELOPER_TEAM_ID`

## Versionierte Xcode-Cloud-Skripte

Das Repo enthält ein `ci_scripts`-Verzeichnis für Xcode Cloud.

- `ci_post_clone.sh` protokolliert die Build-Kontexte und bestätigt das erwartete Projekt-Setup
- `ci_pre_xcodebuild.sh` erzwingt die Release-Regeln des Projekts:
  - `CI + TestFlight` ist für Branch-Builds auf `main`
  - `App Store Release` akzeptiert nur Tags im Format `vX.Y.Z`
- `ci_post_xcodebuild.sh` protokolliert Ergebnis und Exportpfade eines erfolgreichen Archivlaufs

Die Skripte ersetzen keine Workflow-Konfiguration in `App Store Connect`, sichern aber die vereinbarten Regeln im Build selbst ab.

## Release-Ablauf

### TestFlight

1. Änderungen nach `main` mergen
2. Xcode Cloud startet `CI + TestFlight`
3. erfolgreiche Builds erscheinen in `TestFlight`
4. interne und externe Tester erhalten den Build gemäß Workflow-Konfiguration

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

- ein Push auf `main` ausschließlich den Workflow `CI + TestFlight` startet
- `MigraineTrackerTests` dort erfolgreich laufen
- der erfolgreiche `main`-Lauf einen `TestFlight`-Build erzeugt
- ein Tag wie `v1.2.0` ausschließlich den Workflow `App Store Release` startet
- der Tag-Workflow ein veröffentlichbares Archiv und eine App-Store-Submission erzeugt
