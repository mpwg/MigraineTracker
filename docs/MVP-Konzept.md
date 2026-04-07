# MVP-Konzept

## Produktziel

Das MVP von Migraine Tracker soll ein verlässliches, schnelles Migräne-Tagebuch sein. Nutzerinnen und Nutzer sollen eine Episode in wenigen Sekunden erfassen und später nachvollziehen können, wie häufig Beschwerden auftreten, welche Medikamente helfen und ob Wetter oder andere Faktoren eine Rolle spielen.

## Nicht-Ziele im MVP

Diese Punkte sind zunächst bewusst ausgeschlossen:

- komplexe Diagnose- oder Therapieempfehlungen
- Community- oder Social-Features
- umfangreiche KI-Auswertung
- Anbindung an Kliniken oder Praxissysteme
- plattformübergreifende Synchronisation als Pflichtbestandteil der ersten Version

Apple Health ist dagegen eine sinnvolle optionale Integration, weil sie vorhandene iPhone- und Apple-Watch-Daten nutzbar machen kann, ohne das Grundprodukt davon abhängig zu machen.

## Zielgruppe

- Menschen mit wiederkehrenden Kopfschmerzen
- Menschen mit Migräne
- Personen, die Arzttermine mit strukturierten Verlaufsdaten vorbereiten möchten

## Kernproblem

Viele Betroffene dokumentieren Symptome unregelmäßig oder gar nicht, weil vorhandene Lösungen zu komplex wirken. Gleichzeitig fehlen bei Arztterminen oft konkrete Daten zu Intensität, Dauer, Medikamenten und möglichen Auslösern.

## Wertversprechen

Migraine Tracker reduziert Dokumentation auf das Wesentliche und ergänzt automatisch Kontextdaten wie Wetter. Dadurch entsteht ohne großen Aufwand ein verwertbarer Verlauf für den Alltag und für ärztliche Gespräche.

## MVP-Funktionsumfang

### 1. Episoden erfassen

Pro Episode sollen mindestens folgende Daten erfasst werden:

- Startzeitpunkt
- optional Endzeitpunkt oder Dauer
- Episodentyp, z. B. `Migräne`, `Kopfschmerz`, `unklar`
- Intensität von `1` bis `10`
- optionale Schmerzlokalisation, z. B. `links`, `rechts`, `beidseitig`, `Nacken`
- optionaler Schmerzcharakter, z. B. `pulsierend`, `drückend`, `stechend`
- optionale Notiz
- optionale Begleitsymptome wie Übelkeit, Lichtempfindlichkeit, Geräuschempfindlichkeit
- optionale Trigger wie Stress, Schlafmangel, Alkohol, Menstruation, bestimmte Lebensmittel
- optionale funktionelle Einschränkung im Alltag, z. B. `arbeitsfähig`, `eingeschränkt`, `bettlägerig`
- optionaler Menstruations- oder Zyklusstatus, sofern relevant

### 2. Medikamente dokumentieren

Zu einer Episode oder unabhängig davon:

- Medikamentenname
- Medikamententyp, z. B. `Triptan`, `NSAR`, `Paracetamol`, `Antiemetikum`
- Einnahmezeitpunkt
- Dosis
- subjektive Wirkung, z. B. `keine`, `teilweise`, `gut`
- optional Zeitpunkt des Wirkungseintritts
- optional Kennzeichnung als Wiederholungseinnahme

Zusätzlich sinnvoll:

- mehrere Medikamente pro Episode
- Erfassung anderer Schmerzmittel und Begleitmedikation, nicht nur klassischer Migränemittel

### 3. Wetter automatisch speichern

Beim Anlegen einer Episode:

- Temperatur
- Wetterzustand
- Luftfeuchtigkeit, sofern verfügbar
- Luftdruck, sofern verfügbar

Quelle im MVP:

- bevorzugt `Open-Meteo` oder vergleichbare freie Quelle
- `WeatherKit` später als Ausbauoption

### 4. Arzttermine verwalten

- Termin mit Datum, Uhrzeit, Ort und Notiz
- Erinnerung vor dem Termin
- schnelle Ansicht relevanter letzter Episoden vor dem Termin

### 5. Apple Health integrieren

Optional und nur nach expliziter Freigabe:

Schreiben nach Apple Health:

- Kopfschmerz- oder symptombezogene Einträge, soweit über passende Health-Datentypen abbildbar
- Start- und Endzeit dokumentierter Episoden
- optional Medikamenteneinnahmen, falls fachlich und technisch im Zielumfang erwünscht

Lesen aus Apple Health:

- Schlafdauer und Schlafverteilung
- Menstruations- und Zyklusdaten
- Schrittzahl und allgemeines Aktivitätsniveau
- Trainings und körperliche Belastung
- Herzfrequenz, Ruheherzfrequenz und Herzfrequenzvariabilität
- optional weitere vorhandene Vitaldaten als Therapiekontext

Nutzen für die Therapievorbereitung:

- Zusammenhang zwischen Attacken und Schlafmangel besser sichtbar machen
- zyklusbezogene Häufungen erkennen
- mögliche Korrelationen mit Belastung, Stressreaktion oder Erholung prüfen
- ärztliche Gespräche mit mehr objektivem Kontext vorbereiten

### 6. Verlauf und Auswertung

- Kalenderansicht mit Tagen und Episoden
- Listenansicht der letzten Einträge
- einfache Statistiken:
  - Anzahl Episoden pro Woche/Monat
  - durchschnittliche Intensität
  - häufig verwendete Medikamente
  - häufige Trigger oder zyklusbezogene Häufungen

### 7. Export

- kompakter Bericht für einen definierten Zeitraum
- zunächst als PDF oder strukturierte Textansicht

## Empfohlene Screens

1. Startseite
   - heutige Übersicht
   - Button `Episode erfassen`
   - nächster Arzttermin

2. Neue Episode
   - Intensität
   - Zeitangaben
   - Symptome
   - optionale Trigger und Zyklusstatus
   - Notiz
   - Wetter automatisch im Hintergrund

3. Medikamente
   - neue Einnahme erfassen
   - Typ und Wirkung dokumentieren
   - zuletzt verwendete Medikamente schnell auswählen

4. Kalender / Verlauf
   - Tages- und Monatsansicht
   - Detailansicht pro Episode

5. Apple Health
   - Berechtigungen verständlich erklären
   - auswählbare Daten zum Lesen und Schreiben
   - klare Darstellung, welche Daten importiert wurden

6. Arzttermine
   - Liste kommender Termine
   - Termin anlegen und bearbeiten

7. Statistiken
   - Wochen- und Monatsübersicht
   - einfache Mustererkennung auf Basis vorhandener Daten und optionaler Apple-Health-Kontexte

## UX-Prinzipien

- Erfassung in unter `10` Sekunden als Leitlinie
- große, klare Eingabeelemente
- möglichst wenige Pflichtfelder
- automatische Vorbelegung von Datum, Uhrzeit und Wetter
- sensible Zusatzfelder wie Zyklusstatus nur optional und zurückhaltend abfragen
- sensible Gesundheitsdaten standardmäßig lokal und zurückhaltend behandeln
- Health-Berechtigungen granular, verständlich und widerrufbar gestalten
- importierte Gesundheitsdaten klar von manuell eingegebenen Daten unterscheiden

## Vorschlag für Datenmodell

### Episode

- `id`
- `startedAt`
- `endedAt`
- `type`
- `intensity`
- `painLocation`
- `painCharacter`
- `notes`
- `symptoms[]`
- `triggers[]`
- `functionalImpact`
- `menstruationStatus`
- `weatherSnapshotId`
- `healthContextSnapshotId`

### MedicationEntry

- `id`
- `episodeId`
- `name`
- `category`
- `dosage`
- `takenAt`
- `effectiveness`
- `reliefStartedAt`
- `isRepeatDose`

### WeatherSnapshot

- `id`
- `recordedAt`
- `temperature`
- `condition`
- `humidity`
- `pressure`
- `source`

### HealthContextSnapshot

- `id`
- `recordedAt`
- `sleepDuration`
- `sleepConsistency`
- `menstruationStatus`
- `stepCount`
- `workoutLoad`
- `heartRateAverage`
- `restingHeartRate`
- `heartRateVariability`
- `dataSources[]`

### DoctorAppointment

- `id`
- `title`
- `scheduledAt`
- `location`
- `notes`
- `reminderAt`

## Technische Leitplanken für Version 1

- primär iPhone-App
- lokale Speicherung zuerst, z. B. `SwiftData` oder `Core Data`
- Wetterabruf beim Eintrag, mit Fallback bei fehlender Verbindung
- Apple Health nur optional, mit feingranularen Berechtigungen pro Datentyp
- importierte Health-Daten als Snapshot am Episodenzeitpunkt speichern, damit spätere Auswertungen stabil bleiben
- Export lokal generieren
- Datenschutz und klare Einwilligung für Standortzugriff
- Health-Zugriffe transparent erklären und jederzeit deaktivierbar machen

## Erfolgskriterien für das MVP

- Nutzer können eine Episode in kurzer Zeit erfassen
- Verlauf ist in Kalender und Liste nachvollziehbar
- Medikamente sind pro Episode sichtbar
- zusätzliche Kontextdaten liefern erkennbaren Mehrwert, ohne den Erfassungsflow unnötig zu verlangsamen
- Wetterdaten werden zuverlässig gespeichert, wenn verfügbar
- Apple-Health-Daten können optional eingebunden werden und verbessern die Auswertbarkeit für Therapiegespräche
- Arzttermine können angelegt und erinnert werden
- ein nutzbarer Bericht für Arzttermine kann erzeugt werden

## Nächste Umsetzungsschritte

1. User Flows und Screen-Reihenfolge finalisieren
2. Design für Erfassung und Kalender ausarbeiten
3. Datenmodell in App-Strukturen übersetzen
4. Wetterquelle auswählen
5. Apple-Health-Datentypen und Berechtigungsfluss definieren
6. lokalen Prototyp für iOS aufsetzen
