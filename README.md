# Migraine Tracker

Migraine Tracker ist eine App-Idee für das schnelle Erfassen von Kopfschmerzen und Migräneepisoden. Der Fokus liegt auf wenigen, klaren Eingaben, damit Betroffene Symptome, Medikamente, Wetterkontext und Verlauf ohne großen Aufwand dokumentieren können.

## Ziel

Die App soll helfen,

- Episoden konsistent zu erfassen,
- mögliche Auslöser und Muster sichtbar zu machen,
- die Wirkung von Medikamenten besser nachzuvollziehen,
- zyklusbezogene oder hormonelle Zusammenhänge zu erkennen,
- Arztgespräche mit belastbaren Verlaufsdaten vorzubereiten.

## Kernfunktionen

- Erfassung von Kopfschmerz- und Migräneepisoden
- Intensitätsskala von `1` bis `10`
- Dokumentation von Medikamenten, Dosis und Wirkung
- Erfassung weiterer Kontextdaten wie Menstruationsstatus, mögliche Trigger und Schmerzlokalisation
- automatisches Anhängen von Wetterdaten zum Zeitpunkt des Eintrags
- Kalender- und Verlaufsansicht
- Export einer Übersicht für Ärztinnen und Ärzte

## Produktidee

Jeder Eintrag soll so schnell wie möglich erstellt werden können. Statt langer Formulare setzt die App auf einen kompakten Ablauf:

1. Intensität wählen
2. Symptome, Kontext und Medikamente ergänzen
3. Wetter automatisch anhängen
4. Verlauf später in Kalender und Statistiken auswerten

## MVP

Der erste Produktumfang ist bewusst klein gehalten. Details stehen im Dokument [docs/MVP-Konzept.md](docs/MVP-Konzept.md).

Enthalten sind:

- Episoden erfassen
- Medikamente dokumentieren
- zusätzliche Kontextfaktoren wie Zyklusstatus, Trigger und andere Schmerzmittel dokumentieren
- Wetterdaten speichern
- Verlauf in Liste und Kalender anzeigen
- Export für Arztbesuche vorbereiten

Nicht Teil der ersten App-Store-MVP sind:

- `Apple Health`
- `iPad`
- `Englisch` oder weitere Lokalisierungen
- `Cloud-Sync` oder eigenes Backend
- `Arzttermine`

## Mögliche Datenquellen für Wetter

- `WeatherKit` von Apple für tiefe iOS-Integration
- `Open-Meteo` mit DWD ICON für freie, einfache Wetter-Snapshots

Für den aktuellen Stand wird `Open-Meteo` auf Basis von `DWD ICON` verwendet. Später kann bei Bedarf auf `WeatherKit` erweitert werden.

## Zielgruppe

- Menschen mit wiederkehrenden Kopfschmerzen
- Menschen mit diagnostizierter Migräne
- Patientinnen und Patienten, die ihren Verlauf für Arzttermine besser dokumentieren möchten

## Verbindlicher MVP-Scope

Die erste einreichbare Version für den App Store ist bewusst eng geschnitten:

- nur `iPhone`
- nur `Deutsch`
- nur lokale Datenspeicherung auf dem Gerät
- kein Account, kein Backend, keine Synchronisation
- Fokus auf `Episode anlegen`, `Medikamente erfassen`, `Verlauf ansehen`, `PDF exportieren`

## Technischer Stack für die erste MVP

Die erste Version basiert auf diesen verbindlichen Entscheidungen:

- UI mit `SwiftUI`
- lokale Persistenz mit `SwiftData`
- Zielplattform nur `iPhone`
- Architektur `lokal-first` ohne Serverabhängigkeit
- Wetterdaten über `Open-Meteo` auf Basis von `DWD ICON`
- PDF-Erzeugung lokal auf dem Gerät

Diese Entscheidungen reduzieren Integrationsrisiko und halten die erste App-Store-Submission technisch überschaubar.

## Definition of Done für die erste Submission

Die erste MVP gilt als fertig, wenn diese Punkte erfüllt sind:

- eine Episode kann auf dem iPhone vollständig angelegt, bearbeitet und gelöscht werden
- Medikamente können pro Episode dokumentiert und im Verlauf wieder eingesehen werden
- Wetterdaten werden, wenn verfügbar, automatisch als Kontext gespeichert
- vergangene Episoden sind in einer verständlichen Verlaufsansicht sichtbar
- für einen frei wählbaren Zeitraum kann ein verständlicher PDF-Bericht erzeugt und geteilt werden
- die App ist auf Deutsch nutzbar und ohne Account vollständig funktionsfähig
- es gibt keine Health-, Sync- oder Arzttermin-Abhängigkeit für die Kernnutzung

## Zusätzliche sinnvolle Datenpunkte

Für eine medizinisch nützlichere, aber weiterhin schlanke Dokumentation sind insbesondere diese Felder sinnvoll:

- Menstruationsstatus oder Zyklusbezug, um hormonelle Muster sichtbar zu machen
- Art der Episode, z. B. Migräne, Spannungskopfschmerz oder unklar
- Schmerzlokalisation und Schmerzcharakter, z. B. einseitig, pulsierend, drückend
- mögliche Trigger wie Schlafmangel, Stress, Alkohol, bestimmte Lebensmittel oder Bildschirmzeit
- funktionelle Einschränkung im Alltag, z. B. arbeitsfähig, eingeschränkt, bettlägerig
- andere Schmerzmittel oder Begleitmedikation zusätzlich zu klassischen Migränemitteln
- Wiederholungseinnahmen und Zeitpunkt der Wirkung, um Übergebrauch und Nutzen besser einordnen zu können

## Apple Health Integration

Eine Apple-Health-Integration kann den dokumentierten Verlauf deutlich verbessern, wenn sie strikt optional bleibt und nur mit klarer Einwilligung arbeitet.

Sinnvolle Daten, die Migraine Tracker in Apple Health schreiben könnte:

- Kopfschmerz- oder Migräneeinträge, soweit über passende Health-Kategorien abbildbar
- Symptom- oder Episodenereignisse mit Start- und Endzeit
- Medikamenteneinnahmen, sofern im gewünschten Integrationsumfang vorgesehen

Sinnvolle Daten, die aus Apple Health gelesen werden könnten:

- Schlafdauer und Schlafregelmäßigkeit
- Zyklus- und Menstruationsdaten
- Schrittzahl und Aktivitätsniveau
- Trainings und körperliche Belastung
- Herzfrequenz, Ruheherzfrequenz und Herzfrequenzvariabilität
- optional weitere Vitaldaten, wenn sie therapeutisch relevant erscheinen

Der Mehrwert liegt vor allem darin, Trigger und Muster besser zu erkennen, ohne die manuelle Eingabe unnötig zu vergrößern.
