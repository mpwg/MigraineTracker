# Sync-Abdeckung

CloudKit-Sync nutzt `SyncDocumentEnvelope` als fachliche Dokumentgrenze. Die folgende Matrix beschreibt, welche lokalen Daten aktuell synchronisiert werden.

| Modell / Datenbereich | Sync-Dokument | Abdeckung |
| --- | --- | --- |
| `Episode` | `episode:<UUID>` | Vollständig inklusive Basisdaten, Symptome, Trigger, funktionaler Einschränkung und Menstruationsstatus |
| `MedicationEntry` | Bestandteil des Episoden-Dokuments | Akutmedikation wird pro Episode synchronisiert und nach stabiler Entry-ID gemergt |
| `ContinuousMedicationCheck` | Bestandteil des Episoden-Dokuments | Einnahme-Checks werden pro Episode synchronisiert und nach stabiler Check-ID gemergt |
| `WeatherSnapshot` | Bestandteil des Episoden-Dokuments | Wetterkontext wird pro Episode synchronisiert |
| `HealthContextSnapshotData` | Bestandteil des Episoden-Dokuments | Health-Kontext wird pro Episode synchronisiert; alte Records ohne HealthContext-Feld löschen lokale Sidecars nicht |
| Custom `MedicationDefinition` | `medicationDefinition:<catalogKey>` | Eigene Medikamentendefinitionen werden synchronisiert, Seed-Katalogdaten bleiben lokal ableitbar |
| `ContinuousMedication` | `continuousMedication:<UUID>` | Dauermedikationen werden eigenständig synchronisiert und nach stabiler Medikamenten-ID gemergt |

Konfliktbehandlung läuft weiterhin über den dreiseitigen Merge aus Shadow, lokalem Dokument und Remote-Dokument. Konflikte bei Episoden-Sidecars werden mit Feldpfaden wie `continuousMedicationChecks.<id>.wasTaken` oder `healthContext` sichtbar gemacht; Konflikte bei Dauermedikationen werden auf den jeweiligen Feldern wie `dosage`, `frequency` oder `endDate` gemeldet.
