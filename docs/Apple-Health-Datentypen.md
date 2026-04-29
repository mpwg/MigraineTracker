# Apple-Health-Datentypen

Dieses Dokument beschreibt die Apple-Health-Datentypen, die Symi als schmerzrelevanten Kontext nutzt. Lesen und Schreiben sind bewusst getrennt, damit Nutzer jeden Typ einzeln aktivieren oder deaktivieren können und spätere HealthKit-Typen über den zentralen Katalog ergänzt werden.

## Lesen aus Apple Health

| Bereich | Symi-Typ | HealthKit-Identifier | Standard | Fachliche Begründung |
| --- | --- | --- | --- | --- |
| Schlaf | Schlaf | `HKCategoryTypeIdentifierSleepAnalysis` | aktiv | Schlafmangel, Schlafdauer und Schlafqualität sind häufige Kontextfaktoren bei Kopfschmerzen und Migräne. |
| Aktivität | Schritte | `HKQuantityTypeIdentifierStepCount` | aktiv | Aktivität am Episodentag hilft, Belastung, Schonung und Tagesroutine im Verlauf einzuordnen. |
| Herzwerte | Herzfrequenz | `HKQuantityTypeIdentifierHeartRate` | aktiv | Herzfrequenz rund um eine Episode kann körperlichen Stress als neutralen Kontext sichtbar machen. |
| Herzwerte | Ruhepuls | `HKQuantityTypeIdentifierRestingHeartRate` | aktiv | Ruhepuls ergänzt den Tageskontext, ohne daraus eine medizinische Bewertung abzuleiten. |
| Herzwerte | Herzfrequenzvariabilität | `HKQuantityTypeIdentifierHeartRateVariabilitySDNN` | aktiv | HRV kann Hinweise auf Stress und Erholung liefern und bleibt in Symi reine Kontextinformation. |
| Zyklus | Menstruation | `HKCategoryTypeIdentifierMenstrualFlow` | aktiv | Echte Health-Flow-Samples können bei migränebezogenen Mustern relevant sein. Der Typ wird erst ab iOS 18 abgefragt und als Kontext mit Quelle, Zeitraum und Genauigkeit gespeichert. |
| Symptome | Kopfschmerz | `HKCategoryTypeIdentifierHeadache` | aktiv | Vorhandene Kopfschmerzsymptome aus Apple Health werden als externe Quelle kenntlich gemacht. |
| Symptome | Übelkeit | `HKCategoryTypeIdentifierNausea` | aktiv | Übelkeit ist ein häufiges Begleitsymptom von Migräne. |
| Symptome | Schwindel | `HKCategoryTypeIdentifierDizziness` | aktiv | Schwindel kann Episoden fachlich ergänzen, ohne Diagnose oder Interpretation. |
| Symptome | Müdigkeit | `HKCategoryTypeIdentifierFatigue` | aktiv | Müdigkeit kann vor oder während Schmerzepisoden relevant sein. |

## Schreiben nach Apple Health

| Bereich | Symi-Typ | HealthKit-Identifier | Standard | Fachliche Begründung |
| --- | --- | --- | --- | --- |
| Symptome | Kopfschmerz | `HKCategoryTypeIdentifierHeadache` | aktiv | Symi kann die dokumentierte Episode als Kopfschmerz-Symptom schreiben. Notizen und Medikamente werden nicht übertragen. |
| Symptome | Übelkeit | `HKCategoryTypeIdentifierNausea` | aktiv | Übelkeit wird nur geschrieben, wenn sie im Eintrag ausdrücklich ausgewählt wurde. |

## Nutzersteuerung

- Die Einstellungen zeigen Lesen und Schreiben getrennt unter `Apple Health`.
- Jeder Datentyp hat einen eigenen Schalter. Die Auswahl wird unabhängig von der iOS-Berechtigung gespeichert.
- Die eigentliche HealthKit-Autorisierung wird erst über `Leserechte anfragen` oder `Schreibrechte anfragen` gestartet.
- Gelesene Episodenkontexte werden in der UI und im PDF-Export als `Apple Health` mit Quelle ausgewiesen.
- Zyklusdaten aus Apple Health überschreiben keine App-Angaben. Der App-Status unterscheidet nur `Nicht angegeben`, `Nein`, `Aktuell` und `Erwartet`; echte Flow-Samples bleiben davon getrennte Health-Kontextdaten.
- App-Angaben wie `Aktuell` oder `Erwartet` sind nicht präzise genug für `HKCategoryTypeIdentifierMenstrualFlow` und werden deshalb nicht nach Apple Health geschrieben.

## Erweiterung

Neue Typen werden über `HealthDataTypeID`, `HealthDataCatalog` und die HealthKit-Zuordnung in `AppleHealthKitService` ergänzt. Die Einstellungen und Präferenzen lesen den Katalog dynamisch, sodass zusätzliche Datentypen ohne neue Einstellungslogik sichtbar werden.

Nicht Bestandteil dieser Strategie sind komplexe Konfliktlogik zwischen Symi und Apple Health, medizinische Interpretation der Werte und nicht-Apple-basierte Gesundheitsplattformen.
