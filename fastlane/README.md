fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios sync_screenshots

```sh
[bundle exec] fastlane ios sync_screenshots
```

Erzeugt App-Store-Screenshots für iPhone und iPad

### ios validate_screenshot_seed

```sh
[bundle exec] fastlane ios validate_screenshot_seed
```

Validiert den Screenshot-Seed und den Skala-zuerst-Flow ohne vollständige Screenshot-Erzeugung

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Erzeugt und lädt iPhone- und iPad-Screenshots nach App Store Connect hoch

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Baut eine Distribution-IPA mit match und lädt sie nach TestFlight hoch

### ios verify_release

```sh
[bundle exec] fastlane ios verify_release
```

Validiert Version, Metadaten und Screenshots für einen App-Store-Release

### ios ensure_version_not_released

```sh
[bundle exec] fastlane ios ensure_version_not_released
```

Prüft, dass eine Version in App Store Connect noch nicht existiert

### ios release

```sh
[bundle exec] fastlane ios release
```

Baut eine Distribution-IPA und lädt sie mit Metadaten und Screenshots für die manuelle App-Store-Einreichung hoch

### ios release_testflight

```sh
[bundle exec] fastlane ios release_testflight
```

Kompatibilitätsalias für ältere lokale Aufrufe: bitte ios beta verwenden

### ios release_app_store

```sh
[bundle exec] fastlane ios release_app_store
```

Kompatibilitätsalias für ältere lokale Aufrufe: bitte ios release verwenden

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
