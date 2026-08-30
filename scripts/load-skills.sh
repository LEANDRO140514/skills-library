#!/usr/bin/env bash
# Load governed skills into an explicit target directory.
#
# This is the USE side of the library: it resolves each skill in a profile
# through scripts/find-skills.sh and copies ONLY the ones the resolver returns
# as `allow` or `review` (review = resolvable but needs_review). It never
# writes _INDEX.csv, never runs SkillSpector, and never assumes a default
# target — you must pass --target.
#
# Usage:
#   ./scripts/load-skills.sh --profile dev --target <dir> --dry-run   (default)
#   ./scripts/load-skills.sh --profile dev --target <dir> --apply
#
#   --profile <name>   required. Only `dev` is defined today.
#   --target <dir>     required. Destination root; one <dir>/<nombre>/ per skill.
#                      ~/.claude/skills is used ONLY if you pass it explicitly.
#   --dry-run          default. Print src -> dest, copy nothing.
#   --apply            actually copy SKILL.md + UPSTREAM.md + root *.md +
#                      scripts/ + references/ into <target>/<nombre>/.
#
# There is no --prune. Removing stale skills at the target is a manual step.
#
# Exit code:
#   0  at least one skill is loadable (and, with --apply, was copied)
#   2  the profile resolved to zero loadable skills
#   3  usage error, unknown profile, or --prune requested

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ── Profiles ────────────────────────────────────────────────────────────────
# Each entry is a ruta_biblioteca (relative path from repo root). The 5 Jewel
# product skills are deliberately NOT in any profile.
profile_dev() {
  cat <<'EOF'
agentes-meta/comunidad/find-skills
agentes-meta/mias/skill-promote
agentes-meta/mias/skill-scanner
agentes-meta/comunidad/tdd-workflow
agentes-meta/comunidad/security-review
agentes-meta/comunidad/coding-standards
devops/mias/controlled-monorepo-workflow
EOF
}

# ── Args ───────────────────────────────────────────────────────────────────
PROFILE=""
TARGET=""
MODE="dry-run"

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --target=*) TARGET="${1#--target=}"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --apply) MODE="apply"; shift ;;
    --prune)
      echo >&2 "load-skills: --prune is not implemented. Remove stale skills at the target by hand."
      exit 3
      ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo >&2 "load-skills: unknown argument '$1'"
      exit 3
      ;;
  esac
done

if [ -z "$PROFILE" ]; then echo >&2 "load-skills: --profile is required (try: --profile dev)"; exit 3; fi
if [ -z "$TARGET" ]; then echo >&2 "load-skills: --target <dir> is required (no default; ~/.claude/skills only if you pass it)"; exit 3; fi

case "$PROFILE" in
  dev) ENTRIES="$(profile_dev)" ;;
  *) echo >&2 "load-skills: unknown profile '$PROFILE' (known: dev)"; exit 3 ;;
esac

FIND_SKILLS="$REPO_ROOT/scripts/find-skills.sh"
if [ ! -x "$FIND_SKILLS" ] && [ ! -f "$FIND_SKILLS" ]; then
  echo >&2 "load-skills: scripts/find-skills.sh not found"
  exit 3
fi

# ── Pick a Python for the tiny JSON filter (sibling scripts assume python3) ──
PYTHON=""
for c in python3 python "py -3"; do
  if $c -c "import sys" >/dev/null 2>&1; then PYTHON="$c"; break; fi
done
if [ -z "$PYTHON" ]; then
  echo >&2 "load-skills: no usable Python interpreter (tried python3, python, py -3)"
  exit 3
fi

echo "profile:  $PROFILE"
echo "target:   $TARGET"
echo "mode:     $MODE"
echo ""

LOADABLE=0
SKIPPED=0
COPIED=0

# resolve_status <name> <ruta_biblioteca>
# echoes "<status>\t<scan_waiver>" for the resolver row whose ruta_biblioteca
# matches, or "missing" if the resolver never returns that path.
resolve_row() {
  local name="$1" path="$2"
  bash "$FIND_SKILLS" "$name" 2>/dev/null | MATCH="$path" $PYTHON -c '
import sys, os, json
want = os.environ["MATCH"]
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        o = json.loads(line)
    except ValueError:
        continue
    if o.get("ruta_biblioteca") == want:
        print(o.get("status", "") + "\t" + (o.get("scan_waiver") or ""))
        break
else:
    print("missing\t")
'
}

while IFS= read -r ENTRY; do
  [ -z "$ENTRY" ] && continue
  NAME="$(basename "$ENTRY")"
  SRC="$REPO_ROOT/$ENTRY"

  if [ ! -f "$SRC/SKILL.md" ]; then
    echo "SKIP  $ENTRY  — not on disk (no SKILL.md)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  ROW="$(resolve_row "$NAME" "$ENTRY")"
  STATUS="${ROW%%$'\t'*}"
  WAIVER="${ROW#*$'\t'}"

  case "$STATUS" in
    allow)
      echo "LOAD  $ENTRY  — allow"
      ;;
    review)
      echo "LOAD  $ENTRY  — review (needs_review): ${WAIVER:-<no waiver text>}"
      ;;
    blocked)
      echo "SKIP  $ENTRY  — resolver says blocked (BLOCKED_BY_GOVERNANCE); not loaded"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
    unindexed)
      echo "SKIP  $ENTRY  — unindexed (no _INDEX.csv row); not loaded"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
    not_found)
      echo "SKIP  $ENTRY  — not_found by resolver; not loaded"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
    missing)
      echo "SKIP  $ENTRY  — resolver returned no row for this exact path; not loaded"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
    *)
      echo "SKIP  $ENTRY  — unexpected resolver status '$STATUS'; not loaded"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
  esac

  LOADABLE=$((LOADABLE + 1))
  DEST="$TARGET/$NAME"

  # Copy set: SKILL.md + UPSTREAM.md + any root *.md + scripts/ + references/
  ITEMS=()
  [ -f "$SRC/SKILL.md" ] && ITEMS+=("SKILL.md")
  [ -f "$SRC/UPSTREAM.md" ] && ITEMS+=("UPSTREAM.md")
  for md in "$SRC"/*.md; do
    [ -f "$md" ] || continue
    b="$(basename "$md")"
    [ "$b" = "SKILL.md" ] && continue
    [ "$b" = "UPSTREAM.md" ] && continue
    ITEMS+=("$b")
  done
  [ -d "$SRC/scripts" ] && ITEMS+=("scripts/")
  [ -d "$SRC/references" ] && ITEMS+=("references/")

  echo "      src:  $ENTRY/"
  echo "      dest: $DEST/"
  echo "      files: ${ITEMS[*]}"

  if [ "$MODE" = "apply" ]; then
    mkdir -p "$DEST"
    for it in "${ITEMS[@]}"; do
      if [ "${it%/}" != "$it" ]; then
        rm -rf "${DEST:?}/${it%/}"
        cp -R "$SRC/${it%/}" "$DEST/${it%/}"
      else
        cp "$SRC/$it" "$DEST/$it"
      fi
    done
    COPIED=$((COPIED + 1))
    echo "      copied."
  fi
  echo ""
done <<< "$ENTRIES"

echo "----------------------------------------"
echo "loadable: $LOADABLE   skipped: $SKIPPED"
if [ "$MODE" = "apply" ]; then
  echo "copied:   $COPIED  ->  $TARGET/"
else
  echo "(dry-run — nothing copied; re-run with --apply)"
fi

if [ "$LOADABLE" -ge 1 ]; then
  exit 0
else
  echo >&2 "load-skills: profile '$PROFILE' resolved to zero loadable skills"
  exit 2
fi
