# Release-Prozess

Dieser Prozess ist bewusst manuell. Kein Release-Workflow läuft automatisch durch Pushes, Merges oder Tags. TestFlight und App Store werden ausschließlich in GitHub Actions per `workflow_dispatch` gestartet.

## Branching

- `main` ist der Produktionsstand und wird erst nach erfolgreichem App-Store-Release aktualisiert.
- `develop` ist optional für laufende Entwicklung.
- `release/*` ist für Release-Vorbereitung, TestFlight und App-Store-Upload.
- Release-Branch-Namen enthalten keine Versionsnummer. Die Version kommt aus dem Xcode-Projekt und aus dem manuellen Workflow-Input.

## Release vorbereiten

1. Aktuellen Stand holen:

   ```bash
   git checkout main
   git pull
   ```

2. Release-Branch erstellen:

   ```bash
   git checkout -b release/next
   ```

3. Version im Xcode-Projekt setzen, zum Beispiel `2.0.0`.

4. Screenshots und Metadaten vorbereiten:

   - Metadaten liegen unter `fastlane/metadata`
   - Screenshots liegen unter `fastlane/screenshots`
   - beide Verzeichnisse müssen versioniert und committed sein

5. Änderungen committen und Branch pushen:

   ```bash
   git status
   git add Symi.xcodeproj fastlane docs README.md
   git commit -m "Release vorbereiten"
   git push -u origin release/next
   ```

## TestFlight

1. In GitHub Actions den Workflow `TestFlight` öffnen.
2. `Run workflow` wählen.
3. Branch `release/next` auswählen.
4. `changelog` ausfüllen.
5. Workflow starten.
6. Build in TestFlight prüfen:

   - Build ist erfolgreich verarbeitet
   - Installation funktioniert
   - Kernflows laufen
   - Screenshots und Metadaten passen zum Release

Der Workflow bricht ab, wenn er nicht auf einem `release/*` Branch gestartet wird.

## App Store

1. In GitHub Actions den Workflow `App Store Release` öffnen.
2. `Run workflow` wählen.
3. Branch `release/next` auswählen.
4. `version` exakt wie im Xcode-Projekt eingeben, zum Beispiel `2.0.0`.
5. `confirm_release` exakt mit `YES` ausfüllen.
6. Workflow starten.

Der Workflow prüft vor dem Upload:

- Branch muss `release/*` sein
- `confirm_release` muss exakt `YES` sein
- Version darf nicht leer sein und muss `X.Y.Z` entsprechen
- Version muss zur `MARKETING_VERSION` im Xcode-Projekt passen
- Version darf in App Store Connect noch nicht existieren
- `fastlane/metadata` muss Dateien enthalten
- `fastlane/screenshots` muss PNG-Dateien enthalten

Die App wird nach App Store Connect hochgeladen, aber nicht automatisch zur Prüfung eingereicht und nicht automatisch veröffentlicht.

## Nach erfolgreichem App-Store-Upload

1. Release-Branch in `main` mergen:

   ```bash
   git checkout main
   git pull
   git merge --no-ff release/next
   git push origin main
   ```

2. Git-Tag lokal erstellen und pushen:

   ```bash
   git tag v2.0.0
   git push origin v2.0.0
   ```

3. Release-Branch löschen:

   ```bash
   git push origin --delete release/next
   git branch -d release/next
   ```

Tags dokumentieren nur den ausgelieferten Stand. Sie lösen keinen Release-Workflow aus.
