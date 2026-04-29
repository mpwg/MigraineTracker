# Symi

Symi ist ein lokal-first Migräne Tagebuch für mehr gute Tage. Die App kombiniert einen schnellen, ruhigen Eintrag mit persönlichem Tagebuch, Wetterkontext, Medikamentendokumentation und Export.

[![Im App Store laden](https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/white/de-de)](https://apps.apple.com/app/id6761906025)

[![App Store Release](https://github.com/mpwg/Symi/actions/workflows/appstore.yml/badge.svg)](https://github.com/mpwg/Symi/actions/workflows/appstore.yml)
[![TestFlight](https://github.com/mpwg/Symi/actions/workflows/testflight.yml/badge.svg)](https://github.com/mpwg/Symi/actions/workflows/testflight.yml)

[![iOS CI](https://github.com/mpwg/Symi/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/mpwg/Symi/actions/workflows/ios-ci.yml)
[![CodeQL](https://github.com/mpwg/Symi/actions/workflows/codeql.yml/badge.svg)](https://github.com/mpwg/Symi/actions/workflows/codeql.yml)


## Produktstand

Der aktuelle Stand der App deckt diese Bereiche ab:

- Tagebuch für Schmerzereignisse mit den Typen `Migräne`, `Kopfschmerz` und `Unklar`
- schneller neuer Eintrag mit Intensität, Zeitpunkt und optionalen Zusatzangaben
- Symptome, Trigger, Notizen, Schmerzlokalisation, Schmerzcharakter und funktionelle Einschränkung
- Medikamentendokumentation inklusive eigener Vorlagen
- Wetter-Snapshots über `Apple Weather` mit `WeatherKit`
- Tagebuchansicht mit Kalender, Tagesauswahl, Detailansicht, Bearbeiten und Papierkorb
- PDF-Bericht und JSON5-Backup für frei wählbare Zeiträume
- optionale iCloud-Synchronisation mit Konfliktanzeige, Cloud-Datenverwaltung und Sync-Protokoll

## Produktidee

Die App bleibt klar migränefokussiert, fühlt sich aber bewusst nicht wie ein medizinisches Formular an. Das Produktversprechen ist ein ruhiger, hochwertiger und alltagstauglicher Gesundheitsbegleiter:

- Beschwerden schnell dokumentieren, ohne von langen Formularen ausgebremst zu werden
- Muster, Trigger und Medikamentenwirkung nachvollziehbarer machen
- eigene Einträge mit belastbaren, exportierbaren Daten auswerten
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
- JSON5-Backup erzeugen oder importieren; enthalten sind Einträge, Medikamente, Wetter-Snapshots und gespeicherter Apple-Health-Kontext

### 4. Optionale Synchronisation

- iCloud-Sync aktivieren oder deaktivieren
- Sync-Vertrag: halbautomatisch beim Aktivieren, danach bewusst manuell über `Jetzt synchronisieren`; beim App-Start wird der gespeicherte Sync-Status geladen und der Provider vorbereitet, CloudKit-Subscriptions werden derzeit nicht angelegt
- letzter Upload/Download, ungesyncte Records, stale Hinweise und offene Konflikte prüfen
- Konflikte einsehen und auflösen
- Cloud-Daten und Sync-Protokoll prüfen

## Technische Leitplanken

- UI mit `SwiftUI`
- lokale Persistenz mit `SwiftData`
- Architektur `lokal-first`
- Zielplattform primär `iPhone`
- Mindestversion `iOS 17.6`
- Wetterdaten über `Apple Weather` mit `WeatherKit`
- optionale Apple-Health-Integration mit versionsabhängigen HealthKit-Datentypen
- PDF-Erzeugung lokal auf dem Gerät
- optionale, manuell ausgelöste iCloud-Synchronisation getrennt von der lokalen Kernnutzung

Interne Apple-Developer-Identifier wie Bundle ID und iCloud-Container bestehen aus Migrations- und Release-Gründen weiterhin unter `MigraineTracker`, obwohl die sichtbare Produktmarke auf `Symi` umgestellt ist. Diese historischen Kennungen sind in [docs/Historische-Identifier.md](/Users/mat/code/Symi/docs/Historische-Identifier.md) dokumentiert.

## Datenschutz und medizinische Einordnung

- Gesundheitsdaten bleiben ohne aktivierten Sync lokal auf dem Gerät
- der PDF-Export entsteht nur auf ausdrücklichen Befehl
- die App ist eine Dokumentationshilfe, keine Diagnose- oder Therapieempfehlung
- Apple Health ist optional; nicht auf allen iOS-Versionen verfügbare HealthKit-Daten werden nicht erzwungen

## Unterstützte iOS-Version

Die App setzt mindestens `iOS 17.6` voraus. Diese Grenze erhält die aktuellen Swift-, SwiftUI- und SwiftData-Architekturentscheidungen ohne Backport- oder UI-Kompromisse. HealthKit-Datentypen, die erst in neueren iOS-Versionen verfügbar sind, werden separat per Availability behandelt und reduzieren auf älteren unterstützten Systemen nur den verfügbaren Health-Kontext.

Aus Release- und Migrationsgründen bleiben App-Identifier, Provisioning Profile und iCloud-Container technisch auf `eu.mpwg.MigraineTracker` beziehungsweise `iCloud.eu.mpwg.MigraineTracker`. Die sichtbare Produktmarke, Projektstruktur und Schemes heißen `Symi`.

## Build und Release

Dieses Projekt verwendet `GitHub Actions` und `fastlane` für CI/CD.

CI:

- Workflow `iOS CI` bei `pull_request` und `push` auf `main`
- Build und Tests für das Shared Scheme `Symi`
- Upload des `xcresult` als Artifact
- keine automatische Screenshot-Erstellung bei Pull Requests

CD:

- Workflow `TestFlight` wird manuell auf `release/*` Branches gestartet
- Workflow `App Store Release` wird manuell auf `release/*` Branches gestartet
- App-Store-Screenshots und Metadaten sind versionierte Release-Artefakte unter `fastlane/`
- `fastlane match`, `build_app`, `pilot` und `deliver` für Signing und Distribution; die App-Store-Einreichung bleibt manuell in App Store Connect
- keine Release-Automatik durch Pushes, Merges oder Tags

Der manuelle Release-Prozess ist in [docs/Release-Prozess.md](/Users/mat/code/Symi/docs/Release-Prozess.md) dokumentiert. Die projektspezifische Release-Einrichtung ist zusätzlich in [docs/Xcode-Cloud.md](/Users/mat/code/Symi/docs/Xcode-Cloud.md) dokumentiert.

## Lokale Entwicklung

Voraussetzungen:

- Xcode mit iPhone-Simulator
- lokales Secrets-File auf Basis von [LocalSecrets.example.xcconfig](/Users/mat/code/Symi/Symi/Configs/LocalSecrets.example.xcconfig)

Einrichtung:

1. `Symi/Configs/LocalSecrets.example.xcconfig` nach `Symi/Configs/LocalSecrets.xcconfig` kopieren.
2. Mindestens `APPLE_DEVELOPER_TEAM_ID` setzen.
3. Optional `SENTRY_DSN` und weitere Release-Secrets ergänzen.

Typische lokale Prüfung:

```bash
xcodebuild test -scheme Symi -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Weiterführende Dokumente

- [docs/MVP-Konzept.md](/Users/mat/code/Symi/docs/MVP-Konzept.md)
- [docs/Insight-Engine.md](/Users/mat/code/Symi/docs/Insight-Engine.md)
- [docs/Apple-Health-Datentypen.md](/Users/mat/code/Symi/docs/Apple-Health-Datentypen.md)
- [docs/App-Store-Metadaten.md](/Users/mat/code/Symi/docs/App-Store-Metadaten.md)
- [docs/Historische-Identifier.md](/Users/mat/code/Symi/docs/Historische-Identifier.md)
- [docs/Release-Prozess.md](/Users/mat/code/Symi/docs/Release-Prozess.md)
- [docs/Teststrategie-und-Release-Checkliste.md](/Users/mat/code/Symi/docs/Teststrategie-und-Release-Checkliste.md)
- [Symi Support](https://symiapp.com)
