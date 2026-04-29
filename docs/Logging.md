# Logging

Symi schreibt App-Logs über `AppLogStore`. Neue Log-Aufrufe sollen nicht direkt über `print`, `NSLog` oder Sentry laufen, sondern über die zentrale Schnittstelle:

```swift
await appLogStore.log(
    level: .info,
    category: .sync,
    operation: "provider.fetch.finish",
    message: "CloudKit-Änderungen wurden geladen.",
    metadata: ["recordCount": "\(count)"]
)
```

## Level

- `debug`: technische Detailinformationen ohne Nutzdaten
- `info`: erwartete App- und Sync-Ereignisse
- `warning`: unerwartete, aber abgefangene Zustände
- `error`: fehlgeschlagene Operationen
- `critical`: App-kritische Fehler, die sofortige Analyse brauchen

Normale Logs werden als Sentry-Breadcrumbs weitergegeben. `error` und `critical` werden zusätzlich als Sentry-Events erfasst. Die Weitergabe an Sentry ist erst aktiv, nachdem die Nutzerin oder der Nutzer der Nutzungsdaten-Erfassung zugestimmt hat und Sentry mit gültiger DSN gestartet wurde.

## Datenschutz

Metadaten und Nachrichten werden vor der Sentry-Weitergabe sanitizt. Schlüssel mit sensiblen Fragmenten wie `note`, `medication`, `trigger`, `location`, `patient`, `health`, `weather` oder Kontakt-/Standortbezug werden redigiert. Freitext mit E-Mail-Adressen, Telefonnummern oder Begriffen wie Medikament, Notiz, Trigger, Standort, Adresse, Koordinate oder Diagnose wird ebenfalls redigiert.

Trotz Sanitizing sollen Log-Aufrufe keine Gesundheitsdaten, Freitextnotizen, Medikamente, Trigger, Standortdaten oder personenbezogene Inhalte übergeben. Verwende stattdessen technische Zähler, Operationen, Statuswerte und abstrakte Fehlerklassen.
