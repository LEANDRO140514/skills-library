#!/usr/bin/env bash
# workspace-preflight.sh — read-only workspace evidence collector.
# Usage: workspace-preflight.sh [--json] [path]
# Exit codes: 0 = ok, 2 = not a git repository, 1 = error.
# Never mutates the repository. Never fetches. Never prints secret values.
set -u

JSON=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    *) TARGET="$arg" ;;
  esac
done

cd "$TARGET" 2>/dev/null || { echo "ERROR: cannot access path: $TARGET" >&2; exit 1; }
CWD="$(pwd)"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }
sha_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$GIT_ROOT" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{"path":"%s","git":false,"structure":"non-git-folder","role":"undetermined"}\n' "$(json_escape "$CWD")"
  else
    echo "Path: $CWD"
    echo "Git: NOT A GIT REPOSITORY"
    echo "Structure: non-git-folder"
  fi
  exit 2
fi

cd "$GIT_ROOT" || exit 1
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-commits')"
STATUS_ALL="$(git status --short --untracked-files=all 2>/dev/null || true)"
DIRTY_COUNT="$(printf '%s' "$STATUS_ALL" | grep -c . || true)"
[ "$DIRTY_COUNT" -eq 0 ] && TREE="clean" || TREE="dirty ($DIRTY_COUNT entries, -uall)"
UNTRACKED_PATHS="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
UNTRACKED_COUNT="$(printf '%s' "$UNTRACKED_PATHS" | grep -c . || true)"
REMOTES="$(git remote -v 2>/dev/null | awk '{print $1" "$2" "$3}' | sort -u)"
[ -z "$REMOTES" ] && REMOTES="(none)"
COMMITS="$(git log --oneline -5 2>/dev/null || echo '(no commits)')"
TRACKED="$(git ls-files 2>/dev/null | wc -l | tr -d ' ')"

# Cached remote-tracking reference (NO fetch — freshness never verified here)
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -n "$UPSTREAM" ]; then
  AB="$(git rev-list --left-right --count "HEAD...@{u}" 2>/dev/null || echo '? ?')"
  AHEAD="$(echo "$AB" | awk '{print $1}')"; BEHIND="$(echo "$AB" | awk '{print $2}')"
  if [ "$AHEAD" = "0" ] && [ "$BEHIND" = "0" ]; then
    REMOTE_STATE="CACHED_REMOTE_REF_MATCH ($UPSTREAM)"
  else
    REMOTE_STATE="CACHED_REMOTE_REF_DIVERGED ($UPSTREAM: ahead $AHEAD, behind $BEHIND)"
  fi
else
  REMOTE_STATE="(no upstream configured)"
fi
REMOTE_FRESHNESS="REMOTE_FRESHNESS_NOT_VERIFIED"

GIT_KIND="standard"
[ -f "$GIT_ROOT/.git" ] && GIT_KIND="worktree-or-submodule"

PM="(none detected)"; LOCKS=""
[ -f pnpm-lock.yaml ]     && { PM="pnpm";  LOCKS="$LOCKS pnpm-lock.yaml"; }
[ -f yarn.lock ]          && { PM="yarn";  LOCKS="$LOCKS yarn.lock"; }
[ -f package-lock.json ]  && { PM="npm";   LOCKS="$LOCKS package-lock.json"; }
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && { PM="bun"; LOCKS="$LOCKS bun.lock*"; }
for l in poetry.lock uv.lock Cargo.lock go.sum; do
  [ -f "$l" ] && LOCKS="$LOCKS $l"
done
[ -z "$LOCKS" ] && LOCKS=" (none)"

MONO=""
for m in pnpm-workspace.yaml turbo.json lerna.json nx.json; do
  [ -f "$m" ] && MONO="$MONO $m"
done
if [ -f package.json ] && grep -q '"workspaces"' package.json 2>/dev/null; then
  MONO="$MONO package.json:workspaces"
fi

# Authority files: existence + sha256 (content hash, never content)
CONTEXT=""; AUTH_HASHES=""
for f in AGENTS.md CLAUDE.md WORKSPACE_STATUS.md SOURCE_SNAPSHOT.md \
         MIGRATION_MANIFEST.md README.md; do
  if [ -f "$f" ]; then
    CONTEXT="$CONTEXT $f"
    AUTH_HASHES="$AUTH_HASHES $f:$(sha_file "$f")"
  fi
done
for d in docs/architecture docs/adr docs/specs docs/operations memory; do
  [ -d "$d" ] && CONTEXT="$CONTEXT $d/"
done
[ -z "$CONTEXT" ] && CONTEXT=" (none)"
[ -z "$AUTH_HASHES" ] && AUTH_HASHES=" (none)"

ENVFILES="$(find . -maxdepth 2 -name '.env*' -not -path './node_modules/*' \
  -not -name '*.example' -not -name '*.sample' 2>/dev/null | sed 's|^\./||' | tr '\n' ' ')"
[ -z "$ENVFILES" ] && ENVFILES="(none)"

# Structure (physical facts only). Role is NEVER inferred from structure:
# it comes from authorities (WORKSPACE_STATUS.md, AGENTS.md) or the user.
STRUCTURE="standalone-repo"
[ -n "$MONO" ] && STRUCTURE="formal-monorepo"
[ "$GIT_KIND" = "worktree-or-submodule" ] && STRUCTURE="worktree"
ROLE="undetermined (assign from authorities or user, not folder structure)"

# Canonical evidence fingerprint (excludes timestamp; sha256 over field set)
CORE="git_root=$GIT_ROOT|branch=$BRANCH|head=$HEAD_SHA|tree=$TREE|remote_state=$REMOTE_STATE|auth=$AUTH_HASHES|context=$CONTEXT|untracked=$UNTRACKED_COUNT"
FINGERPRINT="$(printf '%s' "$CORE" | sha256sum | awk '{print $1}')"

if [ "$JSON" -eq 1 ]; then
  printf '{'
  printf '"timestamp":"%s",' "$TS"
  printf '"path":"%s","git":true,"git_root":"%s",' "$(json_escape "$CWD")" "$(json_escape "$GIT_ROOT")"
  printf '"git_kind":"%s","branch":"%s","head":"%s",' "$GIT_KIND" "$(json_escape "$BRANCH")" "$HEAD_SHA"
  printf '"working_tree":"%s","dirty_entries":%s,' "$TREE" "$DIRTY_COUNT"
  printf '"untracked_count":%s,"untracked_paths":"%s",' "$UNTRACKED_COUNT" "$(json_escape "$UNTRACKED_PATHS")"
  printf '"cached_remote_state":"%s","remote_freshness":"%s",' "$(json_escape "$REMOTE_STATE")" "$REMOTE_FRESHNESS"
  printf '"tracked_files":%s,' "$TRACKED"
  printf '"package_manager":"%s","lockfiles":"%s",' "$PM" "$(json_escape "$LOCKS")"
  printf '"monorepo_signals":"%s",' "$(json_escape "${MONO:- none}")"
  printf '"context_files":"%s",' "$(json_escape "$CONTEXT")"
  printf '"authority_hashes":"%s",' "$(json_escape "$AUTH_HASHES")"
  printf '"env_files":"%s",' "$(json_escape "$ENVFILES")"
  printf '"remotes":"%s",' "$(json_escape "$REMOTES")"
  printf '"structure":"%s","role":"%s",' "$STRUCTURE" "$(json_escape "$ROLE")"
  printf '"evidence_fingerprint":"%s"' "$FINGERPRINT"
  printf '}\n'
else
  echo "=== WORKSPACE PREFLIGHT (read-only, no fetch) ==="
  echo "Timestamp (UTC): $TS"
  echo "Path: $CWD"
  echo "Git root: $GIT_ROOT  [$GIT_KIND]"
  echo "Branch: $BRANCH"
  echo "HEAD: $HEAD_SHA"
  echo "Working tree: $TREE"
  echo "Untracked files ($UNTRACKED_COUNT):"
  [ -n "$UNTRACKED_PATHS" ] && echo "$UNTRACKED_PATHS" | head -50 | sed 's/^/  /' || echo "  (none)"
  [ "$UNTRACKED_COUNT" -gt 50 ] && echo "  ... ($((UNTRACKED_COUNT-50)) more)"
  echo "Cached remote state: $REMOTE_STATE"
  echo "Remote freshness: $REMOTE_FRESHNESS"
  echo "Tracked files: $TRACKED"
  echo "Remotes:"; echo "$REMOTES" | sed 's/^/  /'
  echo "Last 5 commits:"; echo "$COMMITS" | sed 's/^/  /'
  echo "Package manager: $PM"
  echo "Lockfiles:$LOCKS"
  echo "Monorepo signals:${MONO:- (none)}"
  echo "Context files:$CONTEXT"
  echo "Authority hashes:$AUTH_HASHES"
  echo "Env files (names only): $ENVFILES"
  echo "Structure: $STRUCTURE"
  echo "Role: $ROLE"
  echo "Evidence fingerprint: $FINGERPRINT"
fi
exit 0
