#!/usr/bin/env bash
# Discover skill directories changed in a PR relative to a base branch.
# Usage: discover-changed-skills.sh <base-ref>
# Output: JSON array of skill directory paths (relative to repo root), or [].
#
# promote-check.yml uses this script.
# skill-gate.yml has an inline copy of equivalent logic (DRY TODO: replace
# with this script once this file is stable on main).

set -euo pipefail

BASE_REF="${1:?Usage: $(basename "$0") <base-ref>}"

git fetch origin "${BASE_REF}" --depth=1 2>/dev/null

CHANGED=$(git diff --name-only "origin/${BASE_REF}...HEAD")

declare -A SEEN
SKILL_LIST=()

find_skill_root() {
  local dir
  dir=$(dirname "$1")
  while [ "$dir" != "." ] && [ -n "$dir" ]; do
    if [ -f "${dir}/SKILL.md" ]; then
      printf '%s' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

while IFS= read -r file; do
  [[ "$file" == _archivo/* ]] && continue
  root=$(find_skill_root "$file") || continue
  if [[ ! "${SEEN[$root]+_}" ]]; then
    SEEN[$root]=1
    SKILL_LIST+=("$root")
  fi
done <<< "$CHANGED"

if [ ${#SKILL_LIST[@]} -eq 0 ]; then
  echo "[]"
else
  printf '%s\n' "${SKILL_LIST[@]}" | jq -R . | jq -sc .
fi
