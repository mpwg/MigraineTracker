# MVP-Konzept

## Produktziel

Das MVP von Schmerztagebuch - Migräne & Co. soll ein verlässliches, schnelles Schmerztagebuch mit klarem Fokus auf Migräne sein. Nutzerinnen und Nutzer sollen einen Eintrag in wenigen Sekunden erfassen und später nachvollziehen können, wie häufig Beschwerden auftreten, welche Medikamente helfen und ob Wetter oder andere Faktoren eine Rolle spielen.

Für die erste App-Store-Submission gilt ein bewusst enger Scope:

- nur `iPhone`
- nur `Deutsch`
- nur lokale Datenspeicherung auf dem Gerät
- kein Account, kein Backend, keine Synchronisation
- Fokus auf `Neuer Eintrag`, `Medikamente erfassen`, `Tagebuch öffnen`, `PDF exportieren`

## Verbindliche Architekturentscheidungen

Diese Entscheidungen gelten für die erste App-Store-Submission als fest:

- UI-Framework: `SwiftUI`
- Persistenz: `SwiftData`
- Plattform: `iPhone only`
- Architekturprinzip: `lokal-first`
- Wetterquelle: `Apple Weather` über `WeatherKit`
- Export: PDF lokal auf dem Gerät erzeugen

Nicht Teil dieser Architekturversion sind:

- eigenes Backend
- Benutzerkonten
- Cloud-Sync
- Apple-Health-Integration
- iPad-spezifische UI-Strukturen

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
- Personen, die Arzttermine mit strukturierten Tagebuchdaten vorbereiten möchten

## Kernproblem

Viele Betroffene dokumentieren Symptome unregelmäßig oder gar nicht, weil vorhandene Lösungen zu komplex wirken. Gleichzeitig fehlen bei Arztterminen oft konkrete Daten zu Intensität, Dauer, Medikamenten und möglichen Auslösern.

## Wertversprechen

Schmerztagebuch - Migräne & Co. reduziert Dokumentation auf das Wesentliche und ergänzt automatisch Kontextdaten wie Wetter. Dadurch entsteht ohne großen Aufwand ein verwertbares Tagebuch für den Alltag und für ärztliche Gespräche.

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

Quelle:

- `Apple Weather` über `WeatherKit`
- Wetter wird als Snapshot gespeichert und bleibt optional

### 4. Tagebuch und Auswertung

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

3. Tagebuch öffnen
   - letzte Episoden in einer Liste oder Kalenderansicht sehen
   - eine Episode im Detail mit Medikamenten und Wetterkontext öffnen

4. PDF exportieren
   - Zeitraum auswählen
   - Bericht erzeugen
   - Bericht systemweit teilen

## Empfohlene Screens

1. Startseite
   - freundlicher Tagebuch-Einstieg
   - Button `Neuer Eintrag`
   - letzter Eintrag oder Schnellzugriff auf das Tagebuch

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

4. Kalender / Tagebuch
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

## Architekturskizze für Version 1

Die App wird als kompakte iPhone-App mit klar getrennten Verantwortlichkeiten aufgebaut.

### Schichten

1. Präsentation
   - `SwiftUI`-Screens für Eintragserfassung, Tagebuch, Detailansicht und Export
   - zuständig für Navigation, Formzustand und Darstellung

2. Anwendungslogik
   - koordiniert Speichern, Bearbeiten, Löschen, Wetterabruf und Export
   - kapselt Geschäftsregeln wie Validierung, Standardwerte und Zuordnung von Medikamenten zu Episoden

3. Datenzugriff
   - `SwiftData`-Modelle und einfache Repository- oder Store-Abstraktionen
   - zuständig für Laden, Schreiben, Filtern und Sortieren lokaler Daten

4. Integrationen
   - Wetterdienst über `WeatherKit`
   - PDF-Erzeugung und systemweites Teilen
   - keine weitere externe Abhängigkeit in v1

### Zentrale Module und Verantwortlichkeiten

- `Episode`-Modul
  - Erfassung, Bearbeitung, Löschung und Anzeige von Episoden
- `Medication`-Modul
  - Medikamente pro Episode erfassen und wiederverwenden
- `Weather`-Modul
  - Wetterdaten zum Episodenzeitpunkt abrufen und als Snapshot speichern
- `Export`-Modul
  - Zeitraum auswählen und PDF-Bericht aus vorhandenen lokalen Daten erzeugen
- `History`-Modul
  - Tagebuch-, Kalender- und Detailansichten aus persistierten Episoden ableiten

### Geplanter Datenfluss

1. Nutzer legt eine Episode in der `SwiftUI`-Erfassungsansicht an.
2. Die Anwendungslogik validiert Eingaben und erzeugt lokale Datenobjekte.
3. `SwiftData` speichert Episode, Medikamente und später den Wetter-Snapshot.
4. Der Wetterdienst ergänzt, wenn verfügbar, Kontextdaten ohne den Speichervorgang zu blockieren.
5. Tagebuch und Export lesen ausschließlich aus der lokalen Persistenz.

### Integrationsansatz

- Wetterabruf
  - über `WeatherKit`
  - bei fehlender Verbindung bleibt die Episode trotzdem speicherbar
  - Wetter wird als Snapshot zur Episode abgelegt, nicht live nachgeladen

- Export
  - PDF wird lokal generiert
  - kein externer Dienst für Berichtserstellung
  - Teilen erfolgt über die systemweite iOS-Share-Schnittstelle

### Technische Leitlinien

- Views bleiben schlank und enthalten keine Persistenz- oder Netzwerklogik
- externe Integrationen werden über klar getrennte Services angebunden
- alle Kernfunktionen müssen offline benutzbar bleiben, abgesehen vom optionalen Wetterabruf
- Persistenzmodelle und UI-Darstellung werden logisch getrennt gehalten, damit Export und Tagebuch dieselbe Datenbasis nutzen

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
- Das Tagebuch ist in Kalender und Liste nachvollziehbar
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
- das Tagebuch ist in einer verständlichen Listen- oder Kalenderansicht sichtbar
- ein PDF-Bericht für einen wählbaren Zeitraum kann lokal erzeugt und geteilt werden
- die App funktioniert vollständig ohne Account, Backend oder Synchronisation
- weder `Apple Health` noch `Arzttermine` sind Voraussetzung für die Kernnutzung

## Nächste Umsetzungsschritte

1. User Flows und Screen-Reihenfolge finalisieren
2. Design für Erfassung und Kalender ausarbeiten
3. Datenmodell in App-Strukturen übersetzen
4. Wetterquelle auswählen
5. lokalen Prototyp für iOS aufsetzen
