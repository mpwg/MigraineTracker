# Historische Identifier

## Grundsatz

Die sichtbare Produktmarke, das Xcode-Projekt, die App-Schemes und die Dokumentation verwenden den Namen `Symi`. Einige Apple-Developer-Identifier stammen jedoch aus der früheren Projektphase als `MigraineTracker` und bleiben absichtlich unverändert.

Diese Kennungen sind Teil der veröffentlichten App-, Signing- und iCloud-Historie. Sie dürfen nicht im Rahmen normaler Branding- oder Release-Arbeiten umbenannt werden.

## Nicht ändern

Folgende Identifier sind historisch und bleiben stabil:

- App Store Connect Bundle ID: `eu.mpwg.MigraineTracker`
- iOS-App-`PRODUCT_BUNDLE_IDENTIFIER`: `eu.mpwg.MigraineTracker`
- fastlane `APP_IDENTIFIER`: `eu.mpwg.MigraineTracker`
- Distribution-Provisioning-Profile: `match AppStore eu.mpwg.MigraineTracker`
- iCloud-/CloudKit-Container: `iCloud.eu.mpwg.MigraineTracker`
- HealthKit-Sync-Metadaten-Präfix: `eu.mpwg.MigraineTracker.episode`

Diese Werte sind bewusst keine Produkttexte. Sie erscheinen in Developer-Portal, App Store Connect, Provisioning Profiles, Entitlements, CloudKit und technischen Metadaten.

## Aktuelle Symi-Identifier

Diese Kennungen dürfen weiterhin `Symi` verwenden, weil sie keine veröffentlichte Apple-App-Identität ersetzen:

- Xcode-Projekt: `Symi.xcodeproj`
- Shared App Scheme: `Symi`
- Test-Scheme: `SymiTests`
- Screenshot-Scheme: `SymiScreenshots`
- Test-Bundle-Identifier: `eu.mpwg.SymiTests` und `eu.mpwg.SymiUITests`
- lokale App-Support-Verzeichnisse und Exportnamen mit sichtbarem Produktbezug

## Release- und Provisioning-Regeln

Für Releases wird weiterhin gegen `eu.mpwg.MigraineTracker` signiert und veröffentlicht. `fastlane match` muss deshalb Zertifikate und Profile für genau diese Bundle ID liefern. Das Provisioning Profile muss außerdem die bestehenden Push-, WeatherKit-, HealthKit- und iCloud-Entitlements abdecken.

Der iCloud-Container `iCloud.eu.mpwg.MigraineTracker` bleibt der produktive CloudKit-Container. Neue Release- oder Provisioning-Arbeiten dürfen keinen parallelen `iCloud.eu.mpwg.Symi`-Container anlegen, solange keine explizite Migrationsentscheidung getroffen wurde.

Vor jedem Signing- oder Capability-Change prüfen:

1. App Store Connect enthält weiterhin das Bundle `eu.mpwg.MigraineTracker`.
2. Apple Developer Portal enthält weiterhin App ID, iCloud-Container und Capabilities für `eu.mpwg.MigraineTracker`.
3. Das `match`-Repository enthält ein gültiges `appstore`-Profil für `eu.mpwg.MigraineTracker`.
4. `Symi/Symi.entitlements` referenziert weiterhin `iCloud.eu.mpwg.MigraineTracker`.
5. `fastlane/Fastfile` verwendet weiterhin `APP_IDENTIFIER = "eu.mpwg.MigraineTracker"`.

## Falls eine Umbenennung geplant wird

Eine spätere technische Umbenennung auf `eu.mpwg.Symi` ist ein eigenes Migrationsprojekt und darf nicht als einfache Textänderung umgesetzt werden. Vor einer Änderung braucht es mindestens:

- Entscheidung, ob eine neue Bundle ID überhaupt zulässig ist oder ob dadurch eine neue App-Store-App entstehen würde.
- Apple-Developer-Plan für neue App ID, Capabilities, Push, WeatherKit, HealthKit und Provisioning Profiles.
- CloudKit-Strategie für `iCloud.eu.mpwg.Symi`, inklusive Datenmigration oder bewusster Trennung vom bestehenden Container.
- Fallback-Plan für Nutzerinnen und Nutzer mit vorhandenen iCloud-Daten im Container `iCloud.eu.mpwg.MigraineTracker`.
- TestFlight-Migrationslauf mit produktionsnahen Daten und dokumentierter Rollback-Entscheidung.
- Aktualisierung von `fastlane`, GitHub-Actions-Secrets, App Store Connect, Entitlements, HealthKit-Metadaten und Support-Dokumentation in einem abgestimmten Release.

Bis diese Strategie beschlossen und getestet ist, bleiben die historischen Identifier unverändert.
