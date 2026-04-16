#!/bin/sh
set -eu

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
  echo "ci_pre_xcodebuild.sh ist nur für Xcode Cloud gedacht."
  exit 0
fi

workflow="${CI_WORKFLOW:-}"
action="${CI_XCODEBUILD_ACTION:-}"
branch="${CI_BRANCH:-}"
tag="${CI_TAG:-}"

if [ -z "${APPLE_DEVELOPER_TEAM_ID:-}" ]; then
  echo "Fehlende Umgebungsvariable APPLE_DEVELOPER_TEAM_ID."
  exit 1
fi

echo "Prüfe Workflow-Regeln für '${workflow}' mit Aktion '${action}'."

case "${workflow}" in
  "CI + TestFlight")
    if [ -n "${tag}" ]; then
      echo "Der Workflow 'CI + TestFlight' darf nicht auf einem Git-Tag laufen."
      exit 1
    fi

    if [ "${branch}" != "main" ]; then
      echo "Der Workflow 'CI + TestFlight' ist nur für Branch-Builds auf 'main' vorgesehen."
      exit 1
    fi
    ;;
  "App Store Release")
    if [ -z "${tag}" ]; then
      echo "Der Workflow 'App Store Release' erfordert einen Git-Tag im Format vX.Y.Z."
      exit 1
    fi

    case "${tag}" in
      v[0-9]*.[0-9]*.[0-9]*)
        ;;
      *)
        echo "Ungültiges Release-Tag '${tag}'. Erwartet wird das Format vX.Y.Z."
        exit 1
        ;;
    esac

    if [ "${action}" != "archive" ]; then
      echo "Der Workflow 'App Store Release' muss als Archivlauf konfiguriert sein."
      exit 1
    fi
    ;;
  *)
    echo "Kein projektspezifischer Guard für Workflow '${workflow}'."
    ;;
esac
