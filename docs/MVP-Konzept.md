# MVP-Konzept

## Produktziel

Das MVP von Migraine Tracker soll ein verlässliches, schnelles Migräne-Tagebuch sein. Nutzerinnen und Nutzer sollen eine Episode in wenigen Sekunden erfassen und später nachvollziehen können, wie häufig Beschwerden auftreten, welche Medikamente helfen und ob Wetter oder andere Faktoren eine Rolle spielen.

Für die erste App-Store-Submission gilt ein bewusst enger Scope:

- nur `iPhone`
- nur `Deutsch`
- nur lokale Datenspeicherung auf dem Gerät
- kein Account, kein Backend, keine Synchronisation
- Fokus auf `Episode anlegen`, `Medikamente erfassen`, `Verlauf ansehen`, `PDF exportieren`

## Nicht-Ziele im MVP

Diese Punkte sind zunächst bewusst ausgeschlossen:

- `Apple Health`
- `iPad`
- `Englisch` oder weitere Lokalisierungen
- `Cloud-Sync` oder eigenes Backend
- `Arzttermine`
- komplexe Diagnose- oder Therapieempfehlungen
- Community- oder Social-Features
- umfangreiche KI-Auswertung
- Anbindung an Kliniken oder Praxissysteme
- plattformübergreifende Synchronisation als Pflichtbestandteil der ersten Version

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

### 4. Verlauf und Auswertung

- Kalenderansicht mit Tagen und Episoden
- Listenansicht der letzten Einträge
- einfache Statistiken:
  - Anzahl Episoden pro Woche/Monat
  - durchschnittliche Intensität
  - häufig verwendete Medikamente
  - häufige Trigger oder zyklusbezogene Häufungen

### 5. Export

- kompakter Bericht für einen definierten Zeitraum
- zunächst als PDF oder strukturierte Textansicht

## Kernflows der ersten Submission

Diese Flows müssen ohne Produktentscheidungen umsetzbar und testbar sein:

1. Episode anlegen
   - Intensität wählen
   - Zeit prüfen oder anpassen
   - Symptome, Trigger und optionale Notiz ergänzen
   - Episode speichern

2. Medikamente erfassen
   - Medikament zu einer Episode hinzufügen
   - Name, Kategorie, Dosis, Zeitpunkt und Wirkung festhalten
   - bestehende Medikamente schnell erneut auswählen

3. Verlauf ansehen
   - letzte Episoden in einer Liste oder Kalenderansicht sehen
   - eine Episode im Detail mit Medikamenten und Wetterkontext öffnen

4. PDF exportieren
   - Zeitraum auswählen
   - Bericht erzeugen
   - Bericht systemweit teilen

## Empfohlene Screens

1. Startseite
   - heutige Übersicht
   - Button `Episode erfassen`
   - letzter Verlaufseintrag oder Schnellzugriff auf den Verlauf

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

5. Statistiken
   - Wochen- und Monatsübersicht
   - einfache Mustererkennung auf Basis vorhandener Daten

## UX-Prinzipien

- Erfassung in unter `10` Sekunden als Leitlinie
- große, klare Eingabeelemente
- möglichst wenige Pflichtfelder
- automatische Vorbelegung von Datum, Uhrzeit und Wetter
- sensible Zusatzfelder wie Zyklusstatus nur optional und zurückhaltend abfragen
- sensible Gesundheitsdaten standardmäßig lokal und zurückhaltend behandeln

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

## Technische Leitplanken für Version 1

- primär iPhone-App
- lokale Speicherung zuerst, z. B. `SwiftData` oder `Core Data`
- Wetterabruf beim Eintrag, mit Fallback bei fehlender Verbindung
- Export lokal generieren
- Datenschutz und klare Einwilligung für Standortzugriff

## Erfolgskriterien für das MVP

- Nutzer können eine Episode in kurzer Zeit erfassen
- Verlauf ist in Kalender und Liste nachvollziehbar
- Medikamente sind pro Episode sichtbar
- zusätzliche Kontextdaten liefern erkennbaren Mehrwert, ohne den Erfassungsflow unnötig zu verlangsamen
- Wetterdaten werden zuverlässig gespeichert, wenn verfügbar
- ein nutzbarer Bericht für Arzttermine kann erzeugt werden

## Definition of Done für die erste Submission

Die erste MVP ist fertig, wenn alle Punkte erfüllt sind:

- die App läuft als `iPhone`-App stabil in einer Release-Konfiguration
- die App ist vollständig auf `Deutsch` nutzbar
- eine Episode kann angelegt, bearbeitet und gelöscht werden
- Medikamente können pro Episode erfasst und angezeigt werden
- Wetterkontext wird, wenn verfügbar, automatisch gespeichert
- der Verlauf ist in einer verständlichen Listen- oder Kalenderansicht sichtbar
- ein PDF-Bericht für einen wählbaren Zeitraum kann lokal erzeugt und geteilt werden
- die App funktioniert vollständig ohne Account, Backend oder Synchronisation
- weder `Apple Health` noch `Arzttermine` sind Voraussetzung für die Kernnutzung

## Nächste Umsetzungsschritte

1. User Flows und Screen-Reihenfolge finalisieren
2. Design für Erfassung und Kalender ausarbeiten
3. Datenmodell in App-Strukturen übersetzen
4. Wetterquelle auswählen
5. lokalen Prototyp für iOS aufsetzen
