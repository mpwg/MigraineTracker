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

### ios release_testflight

```sh
[bundle exec] fastlane ios release_testflight
```

Baut eine Distribution-IPA mit match und lädt sie nach TestFlight hoch

### ios release_app_store

```sh
[bundle exec] fastlane ios release_app_store
```

Erzeugt Screenshots, baut eine Distribution-IPA mit match und lädt sie für die manuelle App-Store-Einreichung hoch

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
