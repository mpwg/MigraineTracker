# Teststrategie und Release-Checkliste

## Ziel

Vor einer Submission muss der MVP reproduzierbar prüfbar sein. Die Qualitätssicherung besteht deshalb aus kleinen automatisierten Gates und einer festen manuellen Checkliste für die iPhone-Hauptflows.

## Automatisierte Qualitätsgates

Der offizielle Build- und Release-Pfad ist aufgeteilt:

- `GitHub Actions` für CI
- `GitHub Actions` für CD

Automatisierte Gates im Projekt:

1. Workflow `iOS CI` bei jedem `pull_request` auf `main`
2. Workflow `iOS CI` bei jedem `push` auf `main`
3. Swift-Builds, Tests und Release-Archive laufen in GitHub Actions mit Xcode 26.4
4. schnelles PR-Gate aus SwiftLint/Design-Token-Regeln und `SymiTests` auf `Mac Catalyst`
5. Ausführung von `SymiTests` auf einem `iPhone 17`-Simulator bei Persistence-, Migration-, Backup- oder Import-Änderungen sowie auf `main`
6. fokussierter UI-Smoke auf einem `iPhone 17`-Simulator für `Home → Neuer Eintrag → Speichern` bei Home-, Capture- oder UI-Test-Änderungen sowie auf `main`
7. Upload der `xcresult`-Bundles nur bei Fehlern für nachvollziehbare Fehlerdiagnose in GitHub
8. Workflow `TestFlight Release` per manuellem GitHub-Actions-Start für Distribution-Signing via `match`, Build via `build_app` und Verteilung via `pilot`
9. optionaler `TestFlight Release`-Input `build_number`; leer bedeutet automatische fastlane-Buildnummer
10. Workflow `App Store Release` bei Git-Tags `vX.Y.Z` für Screenshot-Erstellung, Distribution-Signing via `match` und Upload via `deliver`
11. Die finale Einreichung erfolgt manuell in App Store Connect über `Submit`

Lokale Vorab-Prüfung vor einem Tag-Release:

1. Unit-Tests auf Catalyst ausführen:
   `xcodebuild test -project Symi.xcodeproj -scheme SymiTests -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst'`
2. Unit-Tests auf dem iPhone-Simulator ausführen:
   `xcodebuild test -project Symi.xcodeproj -scheme SymiTests -destination 'platform=iOS Simulator,name=iPhone 17'`
3. UI-Smoke lokal ausführen:
   `xcodebuild test -project Symi.xcodeproj -scheme SymiScreenshots -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SymiUITests/HomeRedesignUITests/testHomeQuickEntryCanSaveHeadacheOnlyEntry`
4. Screenshot-Seed ohne vollständige Screenshot-Erzeugung validieren:
   `bundle exec fastlane ios validate_screenshot_seed`
5. App im `Release`-Build in Xcode archivieren oder per `xcodebuild archive` bauen
6. offene Fehler in `GitHub Actions` oder `TestFlight` vor dem Tagging beseitigen

## Automatisierte Testabdeckung

Die automatisierten Tests decken aktuell folgende Kernlogik ab:

- Wetter-Snapshots für echte API-Daten und Zukunftsvalidierung
- Export-Metriken für Durchschnittsintensität und Medikamentenliste
- Insight Engine für Mindestdaten, Ausschlüsse, Durchschnitt, Trigger-/Wochentag-Thresholds, Trend und Hero-Sortierung
- SwiftData-Migration von V4 und V5 auf das aktuelle Schema inklusive Erhalt von Episoden, Medikation und Wetter-Kontext
- JSON5-Backup-Roundtrip inklusive Apple-Health-Kontext, Wetter-Snapshots und kontinuierlicher Medikation
- UI-Smoke für den Skala-zuerst-Erfassungsflow von Home bis Speichern

Damit sind die fehleranfälligen Regeln des MVP reproduzierbar abgesichert, während die schwere App-Store-Screenshot-Erzeugung getrennt vom schnellen PR-Gate bleibt.

## Manuelle Smoke-Tests auf dem iPhone-Simulator

Vor einem Release-Kandidaten einmal vollständig prüfen:

### Neuer Eintrag

- Neue Episode anlegen und speichern
- Standortfreigabe erlauben und Wetter automatisch laden
- Standortfreigabe ablehnen und Episode trotzdem erfolgreich speichern
- Zukunftsdatum wählen und Validierungsfehler prüfen
- Medikament aus „Zuletzt verwendet“ übernehmen und speichern

### Tagebuch

- Gespeicherte Episode in Liste und Kalender finden
- Detailansicht öffnen und Wetter- sowie Medikamentendaten prüfen
- Eintrag bearbeiten, erneut speichern und Änderung im Tagebuch sehen

### Export

- Zeitraum ohne Episoden wählen und Empty State prüfen
- Zeitraum mit Episoden wählen, PDF erzeugen und Teilen-Dialog öffnen
- Exportinhalt auf Zeitraum, Intensität, Medikamente, Trigger und Wetter prüfen

### App-Lebenszyklus

- App schließen und erneut öffnen
- Prüfen, dass bereits gespeicherte Episoden, Medikamente und Wetterdaten weiterhin vorhanden sind
- Export nach Wiederöffnung erneut ausführen

### Produktqualität

- Dynamic Type mit großer Schriftgröße in Home, Neuer Eintrag, Tagebuch und Export prüfen
- VoiceOver-Basis für Schnellzugriffe, Intensitätsauswahl, Kalender und Fehlermeldungen prüfen
- Offensichtliche leere Zustände und Fehlertexte auf Verständlichkeit prüfen

## Release-Freigabe

Ein Release-Kandidat ist freigabefähig, wenn:

- der Workflow `iOS CI` auf `main` erfolgreich läuft
- der Workflow `TestFlight Release` für den gewünschten Build manuell erfolgreich läuft
- die manuelle Checkliste ohne Blocker abgeschlossen ist
- keine irreführenden medizinischen Aussagen oder Berechtigungstexte sichtbar sind

## Release-Auslösung

Die Projektregeln für Releases sind:

- `main` ist der einzige automatische Integrationspfad
- Pull Requests und `main` werden über `GitHub Actions` validiert
- `TestFlight` wird bewusst über den manuell gestarteten Workflow `TestFlight Release` verteilt
- der `App Store` wird nur über Git-Tags im Format `vX.Y.Z` ausgelöst
- `fastlane match`, `build_app`, `pilot` und `deliver` sind die Release-Werkzeuge für Distribution
