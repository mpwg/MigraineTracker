#!/bin/sh
set -eu

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
  echo "ci_post_clone.sh ist nur für Xcode Cloud gedacht."
  exit 0
fi

echo "Starte Xcode-Cloud-Vorbereitung für ${CI_WORKFLOW:-unbekannt}."
echo "Projekt: ${CI_XCODE_PROJECT:-unbekannt}"
echo "Scheme: ${CI_XCODE_SCHEME:-unbekannt}"
echo "Git-Referenz: ${CI_GIT_REF:-unbekannt}"

if [ -z "${APPLE_DEVELOPER_TEAM_ID:-}" ]; then
  echo "Fehlende Umgebungsvariable APPLE_DEVELOPER_TEAM_ID."
  exit 1
fi

if [ "${CI_XCODE_SCHEME:-}" != "Symi" ]; then
  echo "Unerwartetes Scheme '${CI_XCODE_SCHEME:-}'. Erwartet wird 'Symi'."
  exit 1
fi

echo "Projekt setzt auf Apple-verwaltete Signierung und bezieht die Team-ID über APPLE_DEVELOPER_TEAM_ID."
