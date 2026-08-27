#!/usr/bin/env bash
# Lint _INDEX.csv canonical form. Local use — run before pushing any change
# to _INDEX.csv. This script NEVER writes the file.
#
# Checks:
#   1. Exactly one leading UTF-8 BOM (EF BB BF), no stray BOM bytes elsewhere
#   2. Zero TAB characters (the file is comma-delimited only)
#   3. Every row has the same column count as the header
#
# Usage:
#   ./scripts/lint-index.sh
# Exit code != 0 if any check fails.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - << 'PYEOF'
import csv
import io
import sys
from pathlib import Path

raw = Path("_INDEX.csv").read_bytes()
errors = []

# 1) Exactly one leading BOM
if not raw.startswith(b'\xef\xbb\xbf'):
    errors.append("no UTF-8 BOM at start of file")
elif raw.startswith(b'\xef\xbb\xbf\xef\xbb\xbf'):
    errors.append("more than one UTF-8 BOM at start of file")
body = raw.lstrip(b'\xef\xbb\xbf')
if b'\xef\xbb\xbf' in body:
    errors.append("stray UTF-8 BOM bytes inside the file")

text = body.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')

# 2) Zero tabs
has_tab = False
for lineno, line in enumerate(text.split('\n'), 1):
    if '\t' in line:
        has_tab = True
        name = line.split('\t', 1)[0].strip('"') or f'line {lineno}'
        errors.append(f"TAB in row {name!r} (line {lineno}): use commas only")

# 3) Uniform column count (tab rows are reported above; a comma count on a
#    tab-delimited row would just be noise)
rows = list(csv.reader(io.StringIO(text)))
ncols = len(rows[0]) if rows else 0
for lineno, row in enumerate(rows[1:], 2):
    if len(row) != ncols and not (has_tab and '\t' in ''.join(row)):
        who = row[0] if row else "<empty>"
        errors.append(
            f"row {who!r} (line {lineno}) has {len(row)} columns, header has {ncols}"
        )

if errors:
    print("_INDEX.csv lint: FAIL")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

data_rows = max(len(rows) - 1, 0)
print(f"_INDEX.csv lint: OK — 1 BOM, 0 tabs, {data_rows} rows x {ncols} columns")
PYEOF
