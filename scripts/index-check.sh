#!/usr/bin/env bash
# Index integrity check — mirrors the PROMOTE gate.
# Usage: ./scripts/index-check.sh [skill-dir ...]
#   With args:    check only those skill directories.
#   Without args: check all active rows in _INDEX.csv (local use only).
# In CI: always pass dirs explicitly (diff-scoped check).
# Exit code != 0 if any check fails.
#
# Checks per skill (all must pass):
#   a) SKILL.md exists at the given path
#   b) Exactly 1 row in _INDEX.csv with matching ruta_biblioteca
#   c) hash_sha256 == SHA-256 of git cat-file blob HEAD:skill/SKILL.md
#   d) scan_verdict in {allow, review} for active (non-_archivo) skills
#      (deny → skill must be under _archivo/)
#   e) scan_verdict=review → scan_waiver not empty
#   f) mias_o_comunidad=comunidad → scan_verdict not empty
#   g) scan_tool + scan_version present when scan_verdict is set
#   h) nombre == folder basename of ruta_biblioteca

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

python3 - "$@" << 'PYEOF'
import sys, csv, io, subprocess, hashlib, pathlib, os

repo_root = pathlib.Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
index_path = repo_root / "_INDEX.csv"

# Load _INDEX.csv: strip BOM, normalize line endings for parsing.
# This script NEVER writes the CSV.
raw = index_path.read_bytes()
if raw.startswith(b'\xef\xbb\xbf'):
    raw = raw[3:]
text = raw.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
reader = csv.DictReader(io.StringIO(text))
rows = list(reader)


def normalize_ruta(ruta):
    """
    Strip Windows/Unix absolute prefix and return a forward-slash relative path.
    Handles 'C:\\skills-library\\a\\b' -> 'a/b'
    and     '/home/.../skills-library/a/b' -> 'a/b'
    and     'a/b' -> 'a/b'  (already relative)
    DictReader sets missing fields to None (e.g. tab-delimited rows); return ''
    so callers get a predictable non-match instead of AttributeError.
    """
    if not ruta:
        return ''
    r = ruta.strip().replace('\\', '/')
    for marker in ('skills-library/', 'skills_library/'):
        if marker in r:
            return r[r.index(marker) + len(marker):].rstrip('/')
    # Already relative (no drive letter, no leading slash)
    if r and ':' not in r and not r.startswith('/'):
        return r.rstrip('/')
    return r  # Cannot normalize; checks will likely fail with a clear message


def git_blob_sha256(rel_path):
    """
    Return uppercase SHA-256 hex of the canonical Git blob content for HEAD:rel_path.
    Git stores content with LF line endings; this is the authoritative hash.
    """
    content = subprocess.check_output(
        ["git", "cat-file", "blob", f"HEAD:{rel_path}"],
        stderr=subprocess.DEVNULL,
    )
    return hashlib.sha256(content).hexdigest().upper()


skill_dirs = [a for a in sys.argv[1:] if a]

if not skill_dirs:
    # No-args: check all active (non-_archivo) rows.
    skill_dirs = [
        normalize_ruta(r.get('ruta_biblioteca', ''))
        for r in rows
        if r.get('ruta_biblioteca', '').strip()
        and not normalize_ruta(r.get('ruta_biblioteca', '')).startswith('_archivo/')
    ]
    if not skill_dirs:
        print("No active rows in _INDEX.csv to check.")
        sys.exit(0)
    print(f"No args given — checking {len(skill_dirs)} active row(s) from _INDEX.csv.\n")

errors_all = []
total = 0
passed = 0

for skill_dir in skill_dirs:
    skill_dir = skill_dir.rstrip('/')
    skill_path = repo_root / skill_dir
    skill_md_path = skill_path / "SKILL.md"
    skill_md_rel = f"{skill_dir}/SKILL.md"
    skill_basename = pathlib.Path(skill_dir).name
    total += 1
    row_errors = []

    print(f"=== {skill_dir}")

    # a) SKILL.md exists
    if not skill_md_path.exists():
        row_errors.append(f"  [a] SKILL.md not found at {skill_md_path}")
        errors_all.extend(row_errors)
        print(f"  FAIL ({len(row_errors)} error(s))\n")
        continue  # Can't check further

    # b) Exactly 1 matching INDEX row
    matching = [r for r in rows if normalize_ruta(r.get('ruta_biblioteca', '')) == skill_dir]
    if len(matching) == 0:
        row_errors.append(
            f"  [b] No _INDEX.csv row with ruta_biblioteca matching '{skill_dir}'"
        )
        errors_all.extend(row_errors)
        print(f"  FAIL ({len(row_errors)} error(s))\n")
        continue
    if len(matching) > 1:
        row_errors.append(
            f"  [b] {len(matching)} rows match '{skill_dir}' — expected exactly 1"
        )
        errors_all.extend(row_errors)
        print(f"  FAIL ({len(row_errors)} error(s))\n")
        continue

    row = matching[0]
    scan_verdict   = row.get('scan_verdict', '').strip()
    mias_o_com     = row.get('mias_o_comunidad', '').strip()
    is_archivo     = skill_dir.startswith('_archivo/')

    # c) hash_sha256
    try:
        actual_hash = git_blob_sha256(skill_md_rel)
        stored_hash = row.get('hash_sha256', '').strip().upper()
        if actual_hash != stored_hash:
            row_errors.append(
                f"  [c] hash_sha256 mismatch\n"
                f"      INDEX : {stored_hash or '(empty)'}\n"
                f"      blob  : {actual_hash}\n"
                f"      fix   : git cat-file blob HEAD:{skill_md_rel} | sha256sum"
            )
    except subprocess.CalledProcessError:
        row_errors.append(
            f"  [c] Cannot compute SHA-256 for HEAD:{skill_md_rel} — is the file staged/committed?"
        )

    if not is_archivo:
        # d) scan_verdict valid; deny → must be in _archivo
        if scan_verdict == 'deny':
            row_errors.append(
                f"  [d] scan_verdict=deny but '{skill_dir}' is not under _archivo/\n"
                f"      Move to _archivo/ with razon_archivo, or fix the scan finding first."
            )
        elif scan_verdict not in ('allow', 'review', ''):
            row_errors.append(
                f"  [d] scan_verdict='{scan_verdict}' is not a valid value (allow | review | deny | empty)"
            )

        # e) review → waiver required
        if scan_verdict == 'review':
            waiver = row.get('scan_waiver', '').strip()
            if not waiver:
                row_errors.append(
                    f"  [e] scan_verdict=review but scan_waiver is empty — document why before promoting"
                )

        # f) comunidad → scan_verdict required
        if mias_o_com == 'comunidad' and scan_verdict == '':
            row_errors.append(
                f"  [f] mias_o_comunidad=comunidad with empty scan_verdict\n"
                f"      Comunidad skills must be scanned before promoting. Run Skill Gate first."
            )

        # g) scan_tool + scan_version present if scan_verdict set
        if scan_verdict:
            scan_tool    = row.get('scan_tool', '').strip()
            scan_version = row.get('scan_version', '').strip()
            if not scan_tool:
                row_errors.append(f"  [g] scan_verdict='{scan_verdict}' but scan_tool is empty")
            if not scan_version:
                row_errors.append(f"  [g] scan_verdict='{scan_verdict}' but scan_version is empty")

    # h) nombre == folder basename
    stored_nombre = row.get('nombre', '').strip()
    if stored_nombre != skill_basename:
        row_errors.append(
            f"  [h] nombre='{stored_nombre}' but skill dir basename is '{skill_basename}'"
        )

    if row_errors:
        errors_all.extend(row_errors)
        for e in row_errors:
            print(e)
        print(f"  FAIL ({len(row_errors)} error(s))\n")
    else:
        print(f"  OK\n")
        passed += 1

if errors_all:
    print(f"RESULT: FAIL — {len(errors_all)} error(s) across {total - passed}/{total} skill(s).")
    sys.exit(1)
else:
    print(f"RESULT: OK — {passed}/{total} skill(s) passed all index integrity checks.")
    sys.exit(0)
PYEOF
