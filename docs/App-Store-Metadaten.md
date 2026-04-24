# App-Store-Metadaten

## Produktname

Symi

## Untertitel

Migräne Tagebuch

## Kurzbeschreibung

In Sekunden eintragen, Muster verstehen und mehr gute Tage planen. Symi hält dein Migräne Tagebuch ruhig, lokal und übersichtlich.

## Keywords

Migräne,Tagebuch,Kopfschmerz,Symi,Trigger,Medikamente,Wetter,PDF

## Support-URL

https://symiapp.com

## Privacy-URL

https://symiapp.com/privacy

## Marketing-Notizen

- Plattform: nur iPhone
- Sprache: nur Deutsch
- Speicherung: nur lokal auf dem Gerät
- Kein Account, kein Backend, keine Synchronisation
- Kein Apple Health, keine Arzttermine im MVP

## Screenshot-Plan für deutsches iPhone-Listing

Benötigte Screenshots vorbereiten:

1. Emotion: „Mehr gute Tage.“
2. Simplicity: „In Sekunden eintragen“
3. Insight: „Erkenne deine Muster“
4. Control: „Alles im Blick“
5. Trust: „Deine Daten gehören dir“

Wichtige Vorgabe für alle Store-Screenshots:

- ausschließlich anonymisierte Demo-Inhalte verwenden
- nur Musternamen wie `Dr. Anna Muster` oder `Dr. Lea Beispiel` zeigen
- nur Beispieldaten und Beispieltermine zeigen, niemals reale Gesundheitsdaten
- keine Screens mit echter Ärzteliste aus der ÖGK-Suche verwenden

## Screenshot-Demo-Modus

Für reproduzierbare App-Store-Screenshots kann die App mit `APP_STORE_SCREENSHOTS=1` oder `FASTLANE_SNAPSHOT=1` gestartet werden. Dann verwendet sie einen separaten Demo-Store mit:

- anonymisierten Ärztinnen und Ärzten
- anonymisiertem Arztverzeichnis für den Such- und Auswahl-Flow
- Musterterminen
- beispielhaften Migräne- und Kopfschmerz-Einträgen
- Beispielmedikamenten statt realer Präparate
- vorbefüllten Daten im Screen `Neuer Eintrag`
- Beispielwetter statt live geladener Wetterdaten

Der Modus ersetzt dabei den normalen Datenspeicher nicht dauerhaft, sondern verwendet eine getrennte Store-Datei nur für die Screenshot-Erstellung.

## Asset-Stand

- Finales App-Icon liegt als vollständiges `AppIcon.appiconset` vor
- 1024x1024-Marketing-Icon ist enthalten
- Launch Screen wird weiter systemgeneriert verwendet
