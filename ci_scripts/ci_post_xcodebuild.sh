#!/bin/sh
set -eu

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
  echo "ci_post_xcodebuild.sh ist nur für Xcode Cloud gedacht."
  exit 0
fi

echo "xcodebuild-Aktion '${CI_XCODEBUILD_ACTION:-unbekannt}' beendet mit Exit-Code ${CI_XCODEBUILD_EXIT_CODE:-unbekannt}."

if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
  echo "Archivpfad: ${CI_ARCHIVE_PATH:-nicht gesetzt}"
  echo "App-Store-Export: ${CI_APP_STORE_SIGNED_APP_PATH:-nicht gesetzt}"
fi
