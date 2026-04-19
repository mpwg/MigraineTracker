#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=ci_scripts/github_common.sh
source "${SCRIPT_DIR}/github_common.sh"

MODE="${1:-}"
[[ "${MODE}" == "testflight" || "${MODE}" == "app-store" ]] || fail "Verwendung: github_archive_upload.sh <testflight|app-store>"

write_local_secrets
write_app_store_connect_key

if [[ "${MODE}" == "app-store" ]]; then
  validate_release_tag
fi

current_marketing_version="$(marketing_version)"
current_bundle_id="$(bundle_identifier)"
current_build_number="$(build_number)"

base_dir="$(release_root)/${MODE}"
archive_path="${base_dir}/MigraineTracker.xcarchive"
export_path="${base_dir}/export"
export_options_path="${base_dir}/ExportOptions.plist"

rm -rf "${base_dir}"
mkdir -p "${export_path}"

create_export_options_plist "${MODE}" "${current_bundle_id}" "${export_options_path}"
archive_app "${archive_path}" "${current_build_number}"
upload_archive "${archive_path}" "${export_path}" "${export_options_path}"

write_github_output "archive_path" "${archive_path}"
write_github_output "export_path" "${export_path}"
write_github_output "export_options_path" "${export_options_path}"
write_github_output "build_number" "${current_build_number}"
write_github_output "marketing_version" "${current_marketing_version}"
write_github_output "bundle_id" "${current_bundle_id}"

log "Release-Artefakte bereit:"
log "  Modus: ${MODE}"
log "  Bundle ID: ${current_bundle_id}"
log "  Marketing-Version: ${current_marketing_version}"
log "  Buildnummer: ${current_build_number}"
log "  Archiv: ${archive_path}"
log "  Export: ${export_path}"
