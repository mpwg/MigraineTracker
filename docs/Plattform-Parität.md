# Plattform-Parität

## Ziel

`MigraineTracker` bietet auf `iOS` und `macOS` denselben fachlichen Funktionsumfang, sofern keine technische Plattformgrenze dagegen spricht. Unterschiedliche Navigation, Fensterlogik oder Desktop-/Touch-Interaktionen sind erlaubt. Unterschiede im Feature-Set sind es nicht.

## Gemeinsame Bereiche

| Bereich | iOS | macOS | Hinweise |
| --- | --- | --- | --- |
| Heute | Ja | Ja | Start- und Überblicksbereich |
| Erfassen | Ja | Ja | Neue Episode unabhängig von der Shell erreichbar |
| Verlauf | Ja | Ja | Verlauf, Kalender und Detailnavigation |
| Sync & Export | Ja | Ja | iCloud-Sync, Log und Datenexport |
| Einstellungen | Ja | Ja | Vollständige Einstellungsansicht |

## Definition gleicher Features

- Ein Feature gilt als gleich, wenn dieselbe fachliche Aufgabe auf beiden Plattformen möglich ist.
- Unterschiede im Layout, in der Navigation oder im Aufrufkontext zählen nicht als Abweichung.
- Eine Plattform darf nur dann weniger anbieten, wenn die technische Einschränkung explizit im Code und in dieser Datei dokumentiert ist.

## Zulässige Abweichungen

- Desktop-spezifische Fensterstruktur auf `macOS`
- Touch-orientierte Navigation auf `iOS`
- Plattformtypische Toolbar-, Sheet- oder Split-View-Verwendung

## Nicht zulässige Abweichungen

- Ein neuer Bereich ist nur auf einer Plattform erreichbar.
- Ein Feature lebt direkt in einer plattformspezifischen View und nicht in `Core` oder `Infrastructure`.
- Eine Plattform lässt einen bestehenden fachlichen Flow stillschweigend weg.

## Review-Checkliste

- Verwendet die Änderung bestehende `Core`-/`Infrastructure`-Logik statt neuer Fachlogik in der Shell?
- Ist der betroffene Bereich in `AppSection` modelliert?
- Ist die Funktion auf `iOS` und `macOS` verdrahtet?
- Falls nicht: ist die technische Begründung im Code und in dieser Datei dokumentiert?
- Bleiben gemeinsame Views frei von ungekapselten Plattform-Abhängigkeiten?
