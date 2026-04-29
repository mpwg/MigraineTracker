# SwiftData-Schema-Versionen

Diese Übersicht hält fest, welche produktiven App-Versionen welches lokale SwiftData-Schema schreiben. Die versionierten Modelltypen liegen bewusst getrennt in `Symi/Sources/Models/SymiSchemaV1.swift` bis `SymiSchemaV6.swift`; der aktive App-Code nutzt nur die Aliase aus `CurrentModelAliases.swift`.

## Zuordnung

| SwiftData-Schema | App-Version | Zweck |
| --- | --- | --- |
| `SymiSchemaV1` | vor `2.0.0` | Erste lokale Episoden, Medikamente, Medikamentenkatalog und Wetter-Snapshots. |
| `SymiSchemaV2` | vor `2.0.0` | Ergänzt Änderungs- und Löschzeitpunkte für Episoden und Medikamentendefinitionen. |
| `SymiSchemaV3` | vor `2.0.0` | Erweitert Wetter-Snapshots um Niederschlag und Wetter-Code; Migration normalisiert Legacy-Quellen. |
| `SymiSchemaV4` | vor `2.0.0` | Enthält die später entfernten Arzt-, Termin- und Verzeichnismodelle. |
| `SymiSchemaV5` | vor `2.0.0` | Entfernt Arztmodelle aus dem aktiven Store und erweitert Wetter-Snapshots um Tages- und Kontextbereiche. |
| `SymiSchemaV6` | `2.0.0` und neuer | Aktuelles produktives Schema mit Dauermedikation und Episoden-Checks. |

Die historischen Schemata V1 bis V5 bleiben im Code, weil installierte Stores nur über eine vollständige `SymiMigrationPlan`-Kette sicher nach V6 geöffnet werden können. Neue Features dürfen ausschließlich am aktuellen Schema V6 und an einem neuen Folgeschema arbeiten.

## Migration-Fixtures

Die produktiven Fixtures liegen in `SymiTests/SwiftDataMigrationFixtureTests.swift`. Jede Version V1 bis V6 hat eine eigene Seed-Funktion mit deterministischen IDs, Datumwerten und repräsentativen Relationen:

- V1 bis V3 decken Episoden, Medikamente und Legacy-Wetterdaten ab.
- V4 enthält zusätzlich ein Legacy-Arztmodell, damit die Entfernung in V5 weiter abgesichert bleibt.
- V5 deckt Wetter-Kontextbereiche und kodierte Kontextpunkte ab.
- V6 deckt das aktuelle Dauermedikationsmodell und Episoden-Checks ab.

Bei einer neuen produktiven Schema-Version müssen drei Dinge zusammen geändert werden: neue `SymiSchemaV*`-Datei, zusätzlicher Schritt in `SymiMigrationPlan.swift`, neue Fixture samt Dokumentationszeile in dieser Datei.
