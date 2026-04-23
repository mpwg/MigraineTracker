# App-Store-Metadaten

## Produktname

Schmerztagebuch - Migräne & Co.

## Untertitel

Beschwerden freundlich dokumentieren

## Kurzbeschreibung

Erfasse Migräne, Kopfschmerzen, Medikamente, Trigger und Wetter lokal auf deinem iPhone. Behalte dein Tagebuch im Blick und exportiere kompakte PDF-Berichte für Arztgespräche.

## Keywords

Migräne,Kopfschmerz,Schmerzen,Tagebuch,Trigger,Medikamente,PDF,Wetter

## Support-URL

https://github.com/mpwg/MigraineTracker/issues

## Privacy-URL

https://s3.privyr.com/privacy/privacy-policy.html?d=eyJlbWFpbCI6ImZldXJpZy5mZXVlcjdhQGljbG91ZC5jb20iLCJjb21wYW55IjoiTWF0dGhpYXMgV2FsbG5lci1H6WhyaSIsImdlbl9hdCI6IjIwMjYtMDQtMDlUMTE6MjI6MjUuOTYzWiJ9

## Marketing-Notizen

- Plattform: nur iPhone
- Sprache: nur Deutsch
- Speicherung: nur lokal auf dem Gerät
- Kein Account, kein Backend, keine Synchronisation
- Kein Apple Health, keine Arzttermine im MVP

## Screenshot-Plan für deutsches iPhone-Listing

Benötigte Screenshots vorbereiten:

1. Home mit freundlichem Tagebuch-Einstieg und Schnellzugriffen
2. Neuer Eintrag mit Typ, Intensität, Symptomen und optionalen Wetterdaten
3. Tagebuch in Listenansicht
4. Tagebuch in Kalenderansicht
5. PDF-Export mit Zeitraum und Vorschau

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
