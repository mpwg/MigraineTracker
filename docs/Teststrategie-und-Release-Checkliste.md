# Teststrategie und Release-Checkliste

## Ziel

Vor einer Submission muss der MVP reproduzierbar prüfbar sein. Die Qualitätssicherung besteht deshalb aus kleinen automatisierten Gates und einer festen manuellen Checkliste für die iPhone-Hauptflows.

## Automatisierte Qualitätsgates

Vor jedem Release-Kandidaten ausführen:

1. `swift test`
2. `xcodebuild -scheme MigraineTrackerApp -project MigraineTracker.xcodeproj -destination 'generic/platform=iOS Simulator' build`
3. Optional gesammelt: `./scripts/qa/run-mvp-quality-gates.sh`

## Automatisierte Testabdeckung

Die automatisierten Tests decken aktuell folgende Kernlogik ab:

- Wetter-Snapshots für echte API-Daten und Zukunftsvalidierung
- Export-Metriken für Durchschnittsintensität und Medikamentenliste

Damit sind die fehleranfälligen, nicht-visuellen Regeln des MVP reproduzierbar abgesichert, ohne das iPhone-UI unnötig kompliziert zu machen.

## Manuelle Smoke-Tests auf dem iPhone-Simulator

Vor einem Release-Kandidaten einmal vollständig prüfen:

### Erfassen

- Neue Episode anlegen und speichern
- Standortfreigabe erlauben und Wetter automatisch laden
- Standortfreigabe ablehnen und Episode trotzdem erfolgreich speichern
- Zukunftsdatum wählen und Validierungsfehler prüfen
- Medikament aus „Zuletzt verwendet“ übernehmen und speichern

### Verlauf

- Gespeicherte Episode in Liste und Kalender finden
- Detailansicht öffnen und Wetter- sowie Medikamentendaten prüfen
- Episode bearbeiten, erneut speichern und Änderung im Verlauf sehen

### Export

- Zeitraum ohne Episoden wählen und Empty State prüfen
- Zeitraum mit Episoden wählen, PDF erzeugen und Teilen-Dialog öffnen
- Exportinhalt auf Zeitraum, Intensität, Medikamente, Trigger und Wetter prüfen

### App-Lebenszyklus

- App schließen und erneut öffnen
- Prüfen, dass bereits gespeicherte Episoden, Medikamente und Wetterdaten weiterhin vorhanden sind
- Export nach Wiederöffnung erneut ausführen

### Produktqualität

- Dynamic Type mit großer Schriftgröße in Home, Erfassen, Verlauf und Export prüfen
- VoiceOver-Basis für Schnellzugriffe, Intensitätsauswahl, Kalender und Fehlermeldungen prüfen
- Offensichtliche leere Zustände und Fehlertexte auf Verständlichkeit prüfen

## Release-Freigabe

Ein Release-Kandidat ist freigabefähig, wenn:

- alle automatisierten Gates erfolgreich laufen
- die manuelle Checkliste ohne Blocker abgeschlossen ist
- keine irreführenden medizinischen Aussagen oder Berechtigungstexte sichtbar sind
