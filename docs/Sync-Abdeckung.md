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

## CloudKit-Record-Design

Symi speichert pro fachlichem Sync-Dokument weiterhin einen vollständigen `SyncDocumentEnvelope` als JSON in `payloadJSON`. Die CloudKit-Felder `documentID`, `entityType`, `schemaVersion`, `modifiedAt`, `authorDeviceID` und `deletedAt` bleiben zusätzlich als Record-Metadaten erhalten. Diese Entscheidung ist bewusst: Der Envelope hält die fachliche Dokumentgrenze stabil, vermeidet fragmentierte Teil-Records für Episoden-Sidecars und erlaubt den bestehenden dreiseitigen Merge gegen lokale Shadows ohne CloudKit-spezifische Feldlogik.

Die Kehrseite wird explizit begrenzt. `payloadJSON` hat ein hartes Budget von 900.000 UTF-8-Bytes und wird beim Schreiben und Lesen abgelehnt, wenn dieses Budget überschritten wird. Das lässt Reserve unterhalb der CloudKit-Record-Grenze für Systemfelder und zukünftige Metadaten. Zusätzlich prüfen Tests große Grenz-Payloads und deterministische Fuzz-Payloads mit Umlauten und variierenden Listen.

Schema-Evolution läuft pro `entityType` über `schemaVersion`. Aktuell unterstützen `episode`, `medicationDefinition` und `continuousMedication` ausschließlich Version 1. Remote-Payloads mit unbekannter Version oder mit nicht passendem `entityType`/Payload-Typ werden abgelehnt statt stillschweigend gemergt. Für zukünftige Versionen wird zuerst der unterstützte Versionsbereich pro Typ erweitert und ein expliziter Migrationsschritt von alter zu aktueller Envelope-Version ergänzt, bevor neue Payload-Felder verpflichtend werden.

Normalisierte CloudKit-Felder bleiben eine spätere Option, falls konkrete Anforderungen entstehen, die der Envelope nicht gut tragen kann: serverseitige Feldabfragen, einzelne große Sidecars, häufige Teilkonflikte innerhalb eines Dokuments oder Payloads nahe am Größenbudget. Bis dahin ist JSON-Envelope plus validierte Metadaten die gewählte Strategie.
