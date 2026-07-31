# workspace-preflight.ps1 — read-only workspace evidence collector (Windows/pwsh).
# Usage: workspace-preflight.ps1 [-Json] [-Path <dir>]
# Exit codes: 0 = ok, 2 = not a git repository, 1 = error.
# Never mutates the repository. Never fetches. Never prints secret values.
param(
    [switch]$Json,
    [string]$Path = "."
)
$ErrorActionPreference = "SilentlyContinue"

function Get-FileSha256($f) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $f -ErrorAction SilentlyContinue).Hash.ToLower()
}
function Get-StringSha256($s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s)) |
        ForEach-Object { $_.ToString("x2") }) -join ""
}

try { Set-Location -LiteralPath $Path -ErrorAction Stop }
catch { Write-Error "ERROR: cannot access path: $Path"; exit 1 }
$cwd = (Get-Location).Path

$gitRoot = git rev-parse --show-toplevel 2>$null
if (-not $gitRoot) {
    if ($Json) {
        [ordered]@{ path = $cwd; git = $false; structure = "non-git-folder"
                    role = "undetermined" } | ConvertTo-Json -Compress
    } else {
        Write-Output "Path: $cwd"
        Write-Output "Git: NOT A GIT REPOSITORY"
        Write-Output "Structure: non-git-folder"
    }
    exit 2
}

Set-Location -LiteralPath $gitRoot
$ts      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$branch  = git rev-parse --abbrev-ref HEAD 2>$null; if (-not $branch) { $branch = "unknown" }
$head    = git rev-parse --short HEAD 2>$null;      if (-not $head)   { $head = "no-commits" }
$dirty   = @(git status --short --untracked-files=all 2>$null)
$tree    = if ($dirty.Count -eq 0) { "clean" } else { "dirty ($($dirty.Count) entries, -uall)" }
$untracked = @(git ls-files --others --exclude-standard 2>$null)
$remotes = @(git remote -v 2>$null); if ($remotes.Count -eq 0) { $remotes = @("(none)") }
$commits = @(git log --oneline -5 2>$null); if ($commits.Count -eq 0) { $commits = @("(no commits)") }
$tracked = @(git ls-files 2>$null).Count

# Cached remote-tracking reference (NO fetch — freshness never verified here)
$upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
if ($upstream) {
    $ab = (git rev-list --left-right --count "HEAD...@{u}" 2>$null) -split '\s+'
    if ($ab.Count -ge 2 -and $ab[0] -eq "0" -and $ab[1] -eq "0") {
        $remoteState = "CACHED_REMOTE_REF_MATCH ($upstream)"
    } else {
        $remoteState = "CACHED_REMOTE_REF_DIVERGED ($upstream" + ": ahead $($ab[0]), behind $($ab[1]))"
    }
} else { $remoteState = "(no upstream configured)" }
$remoteFreshness = "REMOTE_FRESHNESS_NOT_VERIFIED"

$gitKind = if (Test-Path -LiteralPath (Join-Path $gitRoot ".git") -PathType Leaf) {
    "worktree-or-submodule" } else { "standard" }

$pm = "(none detected)"; $locks = @()
if (Test-Path "pnpm-lock.yaml")    { $pm = "pnpm"; $locks += "pnpm-lock.yaml" }
if (Test-Path "yarn.lock")         { $pm = "yarn"; $locks += "yarn.lock" }
if (Test-Path "package-lock.json") { $pm = "npm";  $locks += "package-lock.json" }
if ((Test-Path "bun.lockb") -or (Test-Path "bun.lock")) { $pm = "bun"; $locks += "bun.lock*" }
foreach ($l in "poetry.lock","uv.lock","Cargo.lock","go.sum") {
    if (Test-Path $l) { $locks += $l }
}
$locksStr = if ($locks.Count) { $locks -join " " } else { "(none)" }

$mono = @()
foreach ($m in "pnpm-workspace.yaml","turbo.json","lerna.json","nx.json") {
    if (Test-Path $m) { $mono += $m }
}
if ((Test-Path "package.json") -and
    (Select-String -Path "package.json" -Pattern '"workspaces"' -Quiet)) {
    $mono += "package.json:workspaces"
}
$monoStr = if ($mono.Count) { $mono -join " " } else { "(none)" }

# Authority files: existence + sha256 (content hash, never content)
$context = @(); $authHashes = @()
foreach ($f in "AGENTS.md","CLAUDE.md","WORKSPACE_STATUS.md","SOURCE_SNAPSHOT.md",
               "MIGRATION_MANIFEST.md","README.md") {
    if (Test-Path $f) {
        $context += $f
        $authHashes += "$f`:$(Get-FileSha256 $f)"
    }
}
foreach ($d in "docs/architecture","docs/adr","docs/specs","docs/operations","memory") {
    if (Test-Path $d -PathType Container) { $context += "$d/" }
}
$contextStr = if ($context.Count) { $context -join " " } else { "(none)" }
$authStr    = if ($authHashes.Count) { $authHashes -join " " } else { "(none)" }

$envFiles = @(Get-ChildItem -Force -Depth 1 -Filter ".env*" -File 2>$null |
    Where-Object { $_.FullName -notmatch "node_modules" -and
                   $_.Name -notmatch '\.(example|sample)$' } |
    ForEach-Object { $_.FullName.Substring($gitRoot.Length).TrimStart('\','/') })
$envStr = if ($envFiles.Count) { $envFiles -join " " } else { "(none)" }

# Structure (physical facts only). Role is NEVER inferred from structure:
# it comes from authorities (WORKSPACE_STATUS.md, AGENTS.md) or the user.
$structure = "standalone-repo"
if ($mono.Count) { $structure = "formal-monorepo" }
if ($gitKind -eq "worktree-or-submodule") { $structure = "worktree" }
$role = "undetermined (assign from authorities or user, not folder structure)"

# Canonical evidence fingerprint (excludes timestamp; sha256 over field set)
$core = "git_root=$gitRoot|branch=$branch|head=$head|tree=$tree|" +
        "remote_state=$remoteState|auth=$authStr|context=$contextStr|" +
        "untracked=$($untracked.Count)"
$fingerprint = Get-StringSha256 $core

if ($Json) {
    [ordered]@{
        timestamp = $ts; path = $cwd; git = $true; git_root = $gitRoot
        git_kind = $gitKind; branch = $branch; head = $head
        working_tree = $tree; dirty_entries = $dirty.Count
        untracked_count = $untracked.Count
        untracked_paths = ($untracked -join "; ")
        cached_remote_state = $remoteState; remote_freshness = $remoteFreshness
        tracked_files = $tracked
        package_manager = $pm; lockfiles = $locksStr
        monorepo_signals = $monoStr; context_files = $contextStr
        authority_hashes = $authStr; env_files = $envStr
        remotes = ($remotes -join "; ")
        structure = $structure; role = $role
        evidence_fingerprint = $fingerprint
    } | ConvertTo-Json -Compress
} else {
    Write-Output "=== WORKSPACE PREFLIGHT (read-only, no fetch) ==="
    Write-Output "Timestamp (UTC): $ts"
    Write-Output "Path: $cwd"
    Write-Output "Git root: $gitRoot  [$gitKind]"
    Write-Output "Branch: $branch"
    Write-Output "HEAD: $head"
    Write-Output "Working tree: $tree"
    Write-Output "Untracked files ($($untracked.Count)):"
    if ($untracked.Count) {
        $untracked | Select-Object -First 50 | ForEach-Object { Write-Output "  $_" }
        if ($untracked.Count -gt 50) { Write-Output "  ... ($($untracked.Count - 50) more)" }
    } else { Write-Output "  (none)" }
    Write-Output "Cached remote state: $remoteState"
    Write-Output "Remote freshness: $remoteFreshness"
    Write-Output "Tracked files: $tracked"
    Write-Output "Remotes:"
    $remotes | ForEach-Object { Write-Output "  $_" }
    Write-Output "Last 5 commits:"
    $commits | ForEach-Object { Write-Output "  $_" }
    Write-Output "Package manager: $pm"
    Write-Output "Lockfiles: $locksStr"
    Write-Output "Monorepo signals: $monoStr"
    Write-Output "Context files: $contextStr"
    Write-Output "Authority hashes: $authStr"
    Write-Output "Env files (names only): $envStr"
    Write-Output "Structure: $structure"
    Write-Output "Role: $role"
    Write-Output "Evidence fingerprint: $fingerprint"
}
exit 0
