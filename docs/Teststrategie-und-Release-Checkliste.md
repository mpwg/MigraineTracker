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
3. Build des Shared Scheme `MigraineTracker`
4. Ausführung von `MigraineTrackerTests`
5. Upload des `xcresult` für nachvollziehbare Fehlerdiagnose in GitHub
6. Workflow `TestFlight Release` bei jedem `push` auf `main` für Distribution-Signing via `match`, Build via `build_app` und Verteilung via `pilot`
7. Workflow `App Store Release` bei Git-Tags `vX.Y.Z` für Screenshot-Erstellung, Distribution-Signing via `match` und Upload via `deliver`
8. Die finale Einreichung erfolgt manuell in App Store Connect über `Submit`

Lokale Vorab-Prüfung vor einem Tag-Release:

1. App im `Release`-Build in Xcode archivieren oder per `xcodebuild archive` bauen
2. Tests lokal gegen das Scheme `MigraineTracker` ausführen
3. offene Fehler in `GitHub Actions` oder `TestFlight` vor dem Tagging beseitigen

## Automatisierte Testabdeckung

Die automatisierten Tests decken aktuell folgende Kernlogik ab:

- Wetter-Snapshots für echte API-Daten und Zukunftsvalidierung
- Export-Metriken für Durchschnittsintensität und Medikamentenliste

Damit sind die fehleranfälligen, nicht-visuellen Regeln des MVP reproduzierbar abgesichert, ohne das iPhone-UI unnötig kompliziert zu machen.

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
- der Workflow `TestFlight Release` auf `main` erfolgreich läuft
- die manuelle Checkliste ohne Blocker abgeschlossen ist
- keine irreführenden medizinischen Aussagen oder Berechtigungstexte sichtbar sind

## Release-Auslösung

Die Projektregeln für Releases sind:

- `main` ist der einzige automatische Integrationspfad
- Pull Requests und `main` werden über `GitHub Actions` validiert
- `TestFlight` wird über den Workflow `TestFlight Release` auf `main` verteilt
- der `App Store` wird nur über Git-Tags im Format `vX.Y.Z` ausgelöst
- `fastlane match`, `build_app`, `pilot` und `deliver` sind die Release-Werkzeuge für Distribution
