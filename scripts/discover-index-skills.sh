#!/usr/bin/env bash
# Output relative skill dirs from rows added/modified in _INDEX.csv
# between BASE_REF and HEAD.
# Usage: discover-index-skills.sh <base-ref>
# Outputs one relative skill path per line (e.g. agentes-meta/mias/skill-promote).
# Skips _archivo/ rows.

set -euo pipefail

BASE_REF="${1:?Usage: $(basename "$0") <base-ref>}"

# Python reads git diff output via subprocess to avoid heredoc/stdin conflict.
python3 - "$BASE_REF" << 'PYEOF'
import sys, subprocess, csv, io

base_ref = sys.argv[1]
diff_out = subprocess.check_output(
    ["git", "diff", "--unified=0", f"origin/{base_ref}...HEAD", "--", "_INDEX.csv"],
    text=True,
    errors="replace",
)

def normalize(ruta):
    """Strip absolute prefix, return forward-slash relative path."""
    r = ruta.strip().replace("\\", "/")
    for marker in ("skills-library/", "skills_library/"):
        if marker in r:
            return r[r.index(marker) + len(marker):].rstrip("/")
    if r and ":" not in r and not r.startswith("/"):
        return r.rstrip("/")
    return None

seen = set()
for line in diff_out.splitlines():
    if not line.startswith("+") or line.startswith("+++"):
        continue
    line = line[1:].lstrip("﻿")
    try:
        row = next(csv.reader(io.StringIO(line)))
        # Skip header row (appears in diff when BOM or first line changes)
        if not row or row[0] == 'nombre':
            continue
        # ruta_biblioteca is column index 8 (0-based)
        if len(row) > 8:
            rel = normalize(row[8])
            if rel and not rel.startswith("_archivo/") and rel not in seen:
                seen.add(rel)
                print(rel)
    except Exception:
        pass
PYEOF
