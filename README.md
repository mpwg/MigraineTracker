# Schmerztagebuch - Migräne & Co.

Schmerztagebuch - Migräne & Co. ist eine lokal-first iPhone-App für das strukturierte Dokumentieren von Migräne, Kopfschmerzen und ähnlichen Schmerzereignissen. Die App kombiniert einen schnellen neuen Eintrag mit einem persönlichen Tagebuch, Wetterkontext, Medikamentendokumentation, Export und ergänzenden Organisationsfunktionen für Arztkontakte.

## Produktstand

Der aktuelle Stand der App deckt diese Bereiche ab:

- Tagebuch für Schmerzereignisse mit den Typen `Migräne`, `Kopfschmerz` und `Unklar`
- schneller neuer Eintrag mit Intensität, Zeitpunkt und optionalen Zusatzangaben
- Symptome, Trigger, Notizen, Schmerzlokalisation, Schmerzcharakter und funktionelle Einschränkung
- Medikamentendokumentation inklusive eigener Vorlagen
- Wetter-Snapshots über `Open-Meteo` auf Basis von `DWD ICON`
- Tagebuchansicht mit Kalender, Tagesauswahl, Detailansicht, Bearbeiten und Papierkorb
- PDF-Bericht und JSON5-Backup für frei wählbare Zeiträume
- Ärztinnen- und Ärzte-Verwaltung inklusive lokaler Termine und Erinnerungen
- optionale iCloud-Synchronisation mit Konfliktanzeige, Cloud-Datenverwaltung und Sync-Protokoll

## Produktidee

Die App bleibt klar migränefokussiert, ist aber bewusst nicht nur für Migräne gedacht. Das Produktversprechen ist ein freundliches, nüchternes und alltagstaugliches Schmerztagebuch:

- Beschwerden schnell dokumentieren, ohne von langen Formularen ausgebremst zu werden
- Muster, Trigger und Medikamentenwirkung nachvollziehbarer machen
- Arztgespräche mit belastbaren, exportierbaren Daten vorbereiten
- sensible Gesundheitsdaten standardmäßig lokal halten

## Hauptflows

### 1. Neuer Eintrag

- Typ wählen
- Intensität festhalten
- Zeitpunkt bestätigen oder anpassen
- optional Symptome, Trigger, Notiz, Wetter und Medikamente ergänzen
- lokal speichern

### 2. Tagebuch öffnen

- Einträge im Kalender und pro Tag ansehen
- Details öffnen
- Einträge bearbeiten oder in den Papierkorb verschieben

### 3. Export und Sicherung

- PDF-Bericht für einen Zeitraum erzeugen und teilen
- JSON5-Backup erzeugen oder importieren

### 4. Ärztinnen, Ärzte und Termine

- Arztkontakte aus der ÖGK-Liste übernehmen oder manuell anlegen
- lokale Termine mit Erinnerung verwalten

### 5. Optionale Synchronisation

- iCloud-Sync aktivieren oder deaktivieren
- Konflikte einsehen und auflösen
- Cloud-Daten und Sync-Protokoll prüfen

## Technische Leitplanken

- UI mit `SwiftUI`
- lokale Persistenz mit `SwiftData`
- Architektur `lokal-first`
- Zielplattform primär `iPhone`
- Wetterdaten über `Open-Meteo`
- PDF-Erzeugung lokal auf dem Gerät
- optionale iCloud-Synchronisation getrennt von der lokalen Kernnutzung

Interne technische Kennungen wie `MigraineTracker`, Bundle-ID, Scheme und iCloud-Container bestehen derzeit aus Migrations- und Release-Gründen weiter, obwohl die sichtbare Produktmarke bereits auf `Schmerztagebuch - Migräne & Co.` umgestellt wird.

## Datenschutz und medizinische Einordnung

- Gesundheitsdaten bleiben ohne aktivierten Sync lokal auf dem Gerät
- der PDF-Export entsteht nur auf ausdrücklichen Befehl
- die App ist eine Dokumentationshilfe, keine Diagnose- oder Therapieempfehlung
- Apple Health ist aktuell nicht integriert

## Build und Release

Dieses Projekt verwendet `GitHub Actions` und `fastlane` für CI/CD.

CI:

- Workflow `iOS CI` bei `pull_request` und `push` auf `main`
- Build und Tests für das Shared Scheme `MigraineTracker`
- Upload des `xcresult` als Artifact
- keine automatische Screenshot-Erstellung bei Pull Requests

CD:

- Workflow `TestFlight Release` für Builds von `main`
- Workflow `App Store Release` für Tags im Format `vX.Y.Z`
- App-Store-Screenshots werden erst im App-Store-Release erzeugt und hochgeladen
- `fastlane match`, `build_app`, `pilot` und `deliver` für Signing und Distribution; die App-Store-Einreichung bleibt manuell in App Store Connect

Die projektspezifische Release-Einrichtung ist in [docs/Xcode-Cloud.md](/Users/mat/code/MigraineTracker/docs/Xcode-Cloud.md) dokumentiert.

## Lokale Entwicklung

Voraussetzungen:

- Xcode mit iPhone-Simulator
- lokales Secrets-File auf Basis von [LocalSecrets.example.xcconfig](/Users/mat/code/MigraineTracker/MigraineTracker/Configs/LocalSecrets.example.xcconfig)

Einrichtung:

1. `MigraineTracker/Configs/LocalSecrets.example.xcconfig` nach `MigraineTracker/Configs/LocalSecrets.xcconfig` kopieren.
2. Mindestens `APPLE_DEVELOPER_TEAM_ID` setzen.
3. Optional `SENTRY_DSN` und weitere Release-Secrets ergänzen.

Typische lokale Prüfung:

```bash
xcodebuild test -scheme MigraineTracker -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Weiterführende Dokumente

- [docs/MVP-Konzept.md](/Users/mat/code/MigraineTracker/docs/MVP-Konzept.md)
- [docs/App-Store-Metadaten.md](/Users/mat/code/MigraineTracker/docs/App-Store-Metadaten.md)
- [docs/Teststrategie-und-Release-Checkliste.md](/Users/mat/code/MigraineTracker/docs/Teststrategie-und-Release-Checkliste.md)
- [GitHub-Issues](https://github.com/mpwg/MigraineTracker/issues)
