#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/delete-merged-branches.sh [--delete] [--base <branch>] [--prune] [--include-remotes]

Entfernt lokale Git-Branches, die bereits in den Base-Branch gemergt sind,
und lokale Branches, deren Upstream-Branch nicht mehr existiert.
Standardmäßig läuft das Skript als Dry-Run und zeigt nur, was gelöscht würde.

Optionen:
  --delete           Branches tatsächlich löschen
  --base <branch>    Base-Branch für die Merge-Prüfung (Standard: aktueller Branch)
  --prune            Vorher Remote-Tracking-Branches per git fetch --prune aktualisieren
  --include-remotes  Zusätzlich gemergte Remote-Tracking-Branches löschen
  -h, --help         Hilfe anzeigen

Beispiele:
  scripts/delete-merged-branches.sh
  scripts/delete-merged-branches.sh --delete
  scripts/delete-merged-branches.sh --prune --delete
  scripts/delete-merged-branches.sh --base main --include-remotes --delete
USAGE
}

delete=false
include_remotes=false
prune=false
base_branch=""

protected_branches=(
  main
  master
  develop
  development
  staging
  production
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)
      delete=true
      shift
      ;;
    --base)
      if [[ $# -lt 2 ]]; then
        echo "Fehler: --base benötigt einen Branch-Namen." >&2
        exit 2
      fi
      base_branch="$2"
      shift 2
      ;;
    --include-remotes)
      include_remotes=true
      shift
      ;;
    --prune)
      prune=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unbekannte Option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Fehler: Dieses Skript muss in einem Git-Repository ausgeführt werden." >&2
    exit 1
  }
}

is_protected_branch() {
  local branch="$1"

  for protected in "${protected_branches[@]}"; do
    [[ "$branch" == "$protected" ]] && return 0
  done

  return 1
}

delete_or_print() {
  local label="$1"
  local display_name="$2"
  shift
  shift

  if [[ "$delete" == true ]]; then
    "$@"
  else
    printf '[Dry-Run] Würde %s löschen: %s\n' "$label" "$display_name"
  fi
}

require_git_repo

current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
  echo "Fehler: HEAD ist detached. Bitte zuerst auf einen Branch wechseln." >&2
  exit 1
fi

if [[ -z "$base_branch" ]]; then
  base_branch="$current_branch"
fi

git rev-parse --verify --quiet "$base_branch" >/dev/null || {
  echo "Fehler: Base-Branch '$base_branch' existiert nicht." >&2
  exit 1
}

if [[ "$prune" == true ]]; then
  git fetch --prune
fi

if [[ "$delete" == false ]]; then
  echo "Dry-Run: Es wird nichts gelöscht. Nutze --delete zum tatsächlichen Entfernen."
fi

echo "Base-Branch: $base_branch"
echo

mapfile -t merged_local_branches < <(
  git branch --merged "$base_branch" --format='%(refname:short)' |
    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue
      [[ "$branch" == "$current_branch" ]] && continue
      is_protected_branch "$branch" && continue
      printf '%s\n' "$branch"
    done
)

if [[ "${#merged_local_branches[@]}" -eq 0 ]]; then
  echo "Keine gemergten lokalen Branches zum Löschen gefunden."
else
  for branch in "${merged_local_branches[@]}"; do
    delete_or_print "lokalen Branch" "$branch" git branch -d "$branch"
  done
fi

echo

mapfile -t gone_upstream_branches < <(
  git for-each-ref refs/heads \
    --format='%(refname:short)%09%(upstream:track)' |
    while IFS=$'\t' read -r branch upstream_state; do
      [[ -z "$branch" ]] && continue
      [[ "$branch" == "$current_branch" ]] && continue
      is_protected_branch "$branch" && continue
      [[ "$upstream_state" == "[gone]" ]] || continue
      printf '%s\n' "$branch"
    done
)

if [[ "${#gone_upstream_branches[@]}" -eq 0 ]]; then
  echo "Keine lokalen Branches mit gelöschtem Upstream gefunden."
else
  for branch in "${gone_upstream_branches[@]}"; do
    delete_or_print "lokalen Branch mit gelöschtem Upstream" "$branch" git branch -D "$branch"
  done
fi

if [[ "$include_remotes" == true ]]; then
  echo

  mapfile -t merged_remote_branches < <(
    git branch -r --merged "$base_branch" --format='%(refname:short)' |
      while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        [[ "$branch" == */HEAD ]] && continue

        remote="${branch%%/*}"
        remote_branch="${branch#*/}"

        [[ "$remote_branch" == "$current_branch" ]] && continue
        is_protected_branch "$remote_branch" && continue

        printf '%s\t%s\n' "$remote" "$remote_branch"
      done
  )

  if [[ "${#merged_remote_branches[@]}" -eq 0 ]]; then
    echo "Keine gemergten Remote-Tracking-Branches zum Löschen gefunden."
  else
    for entry in "${merged_remote_branches[@]}"; do
      remote="${entry%%$'\t'*}"
      branch="${entry#*$'\t'}"
      delete_or_print "Remote-Branch" "$remote/$branch" git push "$remote" --delete "$branch"
    done
  fi
fi
