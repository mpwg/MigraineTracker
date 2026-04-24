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
repo_root="${CI_PRIMARY_REPOSITORY_PATH:-}"

if [ -z "${repo_root}" ]; then
  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
fi

if [ -z "${APPLE_DEVELOPER_TEAM_ID:-}" ]; then
  echo "Fehlende Umgebungsvariable APPLE_DEVELOPER_TEAM_ID."
  exit 1
fi

if [ -z "${SENTRY_DSN:-}" ]; then
  echo "Fehlende Umgebungsvariable SENTRY_DSN."
  echo "Setze SENTRY_DSN als Secret in Xcode Cloud, damit Sentry-Ereignisse gesendet werden können."
  exit 1
fi

secrets_file="${repo_root}/Symi/Configs/LocalSecrets.xcconfig"
secrets_dir="$(dirname "${secrets_file}")"

if [ ! -d "${secrets_dir}" ]; then
  mkdir -p "${secrets_dir}"
fi

{
  printf 'APPLE_DEVELOPER_TEAM_ID = %s\n' "${APPLE_DEVELOPER_TEAM_ID}"
  printf 'SENTRY_DSN = %s\n' "${SENTRY_DSN}"
  printf 'TELEMETRY_APP_ID = %s\n' "${TELEMETRY_APP_ID:-}"
} > "${secrets_file}"

if [ ! -s "${secrets_file}" ]; then
  echo "Lokale Build-Konfiguration ${secrets_file} konnte nicht geschrieben werden."
  exit 1
fi

echo "Lokale Build-Konfiguration ${secrets_file} für Xcode Cloud erzeugt."

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
