#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="MigraineTracker.xcodeproj"
SCHEME="MigraineTracker"
CONFIGURATION="Release"
APP_CONFIG_PATH="MigraineTracker/Configs/LocalSecrets.xcconfig"
DEFAULT_XCODE_VERSION="26.4"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Fehler: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    fail "Die Umgebungsvariable ${name} fehlt."
  fi
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

release_root() {
  if [[ -n "${RUNNER_TEMP:-}" ]]; then
    printf '%s\n' "${RUNNER_TEMP}/migraine-tracker-release"
  else
    printf '%s\n' "$(repo_root)/artifacts/release"
  fi
}

build_number() {
  if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
    printf '%s\n' "${GITHUB_RUN_NUMBER}"
  else
    date -u '+%Y%m%d%H%M%S'
  fi
}

write_local_secrets() {
  require_env APPLE_DEVELOPER_TEAM_ID
  require_env SENTRY_DSN

  mkdir -p "$(dirname "${APP_CONFIG_PATH}")"
  cat > "${APP_CONFIG_PATH}" <<EOF
// Von GitHub Actions erzeugt. Nicht committen.
APPLE_DEVELOPER_TEAM_ID = ${APPLE_DEVELOPER_TEAM_ID}
SENTRY_DSN = ${SENTRY_DSN}
TELEMETRY_APP_ID = ${TELEMETRY_APP_ID:-}
EOF
}

write_app_store_connect_key() {
  require_env APP_STORE_CONNECT_KEY_ID
  require_env APP_STORE_CONNECT_ISSUER_ID
  require_env APP_STORE_CONNECT_PRIVATE_KEY

  local base_dir
  base_dir="$(release_root)"
  mkdir -p "${base_dir}/keys"

  APP_STORE_CONNECT_KEY_PATH="${base_dir}/keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  python3 - "${APP_STORE_CONNECT_PRIVATE_KEY}" "${APP_STORE_CONNECT_KEY_PATH}" <<'PY'
import sys

value = sys.argv[1]
path = sys.argv[2]
if "\\n" in value and "\n" not in value:
    value = value.replace("\\n", "\n")
if not value.endswith("\n"):
    value += "\n"
with open(path, "w", encoding="utf-8") as handle:
    handle.write(value)
PY
  chmod 600 "${APP_STORE_CONNECT_KEY_PATH}"
  export APP_STORE_CONNECT_KEY_PATH
}

read_build_setting() {
  local key="$1"
  xcodebuild \
    -showBuildSettings \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" 2>/dev/null | awk -F ' = ' -v target="${key}" '$1 ~ target"$" { print $2; exit }'
}

marketing_version() {
  local version
  version="$(read_build_setting MARKETING_VERSION)"
  [[ -n "${version}" ]] || fail "MARKETING_VERSION konnte nicht gelesen werden."
  printf '%s\n' "${version}"
}

bundle_identifier() {
  local bundle_id
  bundle_id="$(read_build_setting PRODUCT_BUNDLE_IDENTIFIER)"
  [[ -n "${bundle_id}" ]] || fail "PRODUCT_BUNDLE_IDENTIFIER konnte nicht gelesen werden."
  printf '%s\n' "${bundle_id}"
}

release_tag() {
  if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    printf '%s\n' "${GITHUB_REF_NAME}"
    return
  fi

  git describe --tags --exact-match 2>/dev/null || true
}

validate_release_tag() {
  local tag version
  tag="$(release_tag)"
  version="$(marketing_version)"

  [[ -n "${tag}" ]] || fail "Für den App-Store-Lauf wurde kein Git-Tag gefunden."
  [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Ungültiges Release-Tag '${tag}'. Erwartet wird das Format vX.Y.Z."
  [[ "${tag#v}" == "${version}" ]] || fail "Release-Tag '${tag}' passt nicht zu MARKETING_VERSION '${version}'."
}

create_export_options_plist() {
  local mode="$1"
  local bundle_id="$2"
  local output_path="$3"

  cat > "${output_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>distributionBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${APPLE_DEVELOPER_TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
EOF

  if [[ "${mode}" == "testflight" ]]; then
    cat >> "${output_path}" <<'EOF'
  <key>testFlightInternalTestingOnly</key>
  <false/>
EOF
  fi

  cat >> "${output_path}" <<'EOF'
</dict>
</plist>
EOF
}

archive_app() {
  local archive_path="$1"
  local current_build_number="$2"

  log "Archiviere ${SCHEME} mit Buildnummer ${current_build_number}."
  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS" \
    -archivePath "${archive_path}" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "${APP_STORE_CONNECT_KEY_PATH}" \
    -authenticationKeyID "${APP_STORE_CONNECT_KEY_ID}" \
    -authenticationKeyIssuerID "${APP_STORE_CONNECT_ISSUER_ID}" \
    CURRENT_PROJECT_VERSION="${current_build_number}" \
    DEVELOPMENT_TEAM="${APPLE_DEVELOPER_TEAM_ID}" \
    clean archive
}

upload_archive() {
  local archive_path="$1"
  local export_path="$2"
  local export_options_path="$3"

  log "Lade Archiv nach App Store Connect hoch."
  xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_options_path}" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "${APP_STORE_CONNECT_KEY_PATH}" \
    -authenticationKeyID "${APP_STORE_CONNECT_KEY_ID}" \
    -authenticationKeyIssuerID "${APP_STORE_CONNECT_ISSUER_ID}"
}

write_github_output() {
  local key="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "${key}" "${value}" >> "${GITHUB_OUTPUT}"
  fi
}
