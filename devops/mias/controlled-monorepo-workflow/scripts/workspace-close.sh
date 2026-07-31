#!/usr/bin/env bash
# workspace-close.sh — read-only close-out evidence collector.
# Usage: workspace-close.sh [path]
# Exit codes: 0 = ok, 2 = not a git repository, 1 = error.
# Collects evidence for CLOSE. Never commits. Never pushes. Never mutates.
set -u

TARGET="${1:-.}"
cd "$TARGET" 2>/dev/null || { echo "ERROR: cannot access path: $TARGET" >&2; exit 1; }

GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$GIT_ROOT" ]; then
  echo "Path: $(pwd)"
  echo "Git: NOT A GIT REPOSITORY — nothing to close."
  exit 2
fi
cd "$GIT_ROOT" || exit 1

echo "=== WORKSPACE CLOSE EVIDENCE (read-only) ==="
echo "Git root: $GIT_ROOT"
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
echo "HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo no-commits)"
echo
echo "--- git status --short ---"
git status --short || true
echo
echo "--- git diff --stat (unstaged) ---"
git diff --stat || true
echo
echo "--- git diff --stat --cached (staged) ---"
git diff --stat --cached || true
echo
echo "--- Untracked files ---"
UNTRACKED="$(git ls-files --others --exclude-standard)"
[ -n "$UNTRACKED" ] && echo "$UNTRACKED" | sed 's/^/  /' || echo "  (none)"
echo
echo "--- Last 5 commits ---"
git log --oneline -5 2>/dev/null | sed 's/^/  /' || echo "  (no commits)"
echo
echo "--- Remotes ---"
git remote -v | sed 's/^/  /' || true
[ -z "$(git remote)" ] && echo "  (none)"
echo
echo "--- Context files present ---"
FOUND=0
for f in AGENTS.md CLAUDE.md WORKSPACE_STATUS.md SOURCE_SNAPSHOT.md \
         MIGRATION_MANIFEST.md; do
  [ -f "$f" ] && { echo "  $f"; FOUND=1; }
done
[ "$FOUND" -eq 0 ] && echo "  (none)"
echo
echo "NOTE: no commit or push was performed by this script."
exit 0
