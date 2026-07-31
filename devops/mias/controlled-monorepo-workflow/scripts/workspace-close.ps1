# workspace-close.ps1 — read-only close-out evidence collector (Windows/pwsh).
# Usage: workspace-close.ps1 [-Path <dir>]
# Exit codes: 0 = ok, 2 = not a git repository, 1 = error.
# Collects evidence for CLOSE. Never commits. Never pushes. Never mutates.
param([string]$Path = ".")
$ErrorActionPreference = "SilentlyContinue"

try { Set-Location -LiteralPath $Path -ErrorAction Stop }
catch { Write-Error "ERROR: cannot access path: $Path"; exit 1 }

$gitRoot = git rev-parse --show-toplevel 2>$null
if (-not $gitRoot) {
    Write-Output "Path: $((Get-Location).Path)"
    Write-Output "Git: NOT A GIT REPOSITORY — nothing to close."
    exit 2
}
Set-Location -LiteralPath $gitRoot

Write-Output "=== WORKSPACE CLOSE EVIDENCE (read-only) ==="
Write-Output "Git root: $gitRoot"
$branch = git rev-parse --abbrev-ref HEAD 2>$null; if (-not $branch) { $branch = "unknown" }
$head   = git rev-parse --short HEAD 2>$null;      if (-not $head)   { $head = "no-commits" }
Write-Output "Branch: $branch"
Write-Output "HEAD: $head"
Write-Output ""
Write-Output "--- git status --short ---"
git status --short
Write-Output ""
Write-Output "--- git diff --stat (unstaged) ---"
git diff --stat
Write-Output ""
Write-Output "--- git diff --stat --cached (staged) ---"
git diff --stat --cached
Write-Output ""
Write-Output "--- Untracked files ---"
$untracked = @(git ls-files --others --exclude-standard)
if ($untracked.Count) { $untracked | ForEach-Object { Write-Output "  $_" } }
else { Write-Output "  (none)" }
Write-Output ""
Write-Output "--- Last 5 commits ---"
$commits = @(git log --oneline -5 2>$null)
if ($commits.Count) { $commits | ForEach-Object { Write-Output "  $_" } }
else { Write-Output "  (no commits)" }
Write-Output ""
Write-Output "--- Remotes ---"
$remotes = @(git remote -v)
if ($remotes.Count) { $remotes | ForEach-Object { Write-Output "  $_" } }
else { Write-Output "  (none)" }
Write-Output ""
Write-Output "--- Context files present ---"
$found = $false
foreach ($f in "AGENTS.md","CLAUDE.md","WORKSPACE_STATUS.md",
               "SOURCE_SNAPSHOT.md","MIGRATION_MANIFEST.md") {
    if (Test-Path $f) { Write-Output "  $f"; $found = $true }
}
if (-not $found) { Write-Output "  (none)" }
Write-Output ""
Write-Output "NOTE: no commit or push was performed by this script."
exit 0
