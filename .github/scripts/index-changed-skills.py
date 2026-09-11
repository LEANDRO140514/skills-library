#!/usr/bin/env python3
"""Print the skill directories whose _INDEX.csv row changed against a base ref.

A PR can promote a skill by editing only its registry row. Skill Gate resolves
those rows back to skill directories so the scan still runs on them; without
this, a registry-only PR would find no changed SKILL.md and skip the gate.

Usage: index-changed-skills.py <base-ref>      # e.g. main
Output: one repo-relative skill directory per line.
"""
import csv
import io
import subprocess
import sys

BS = chr(92)


def norm(ruta):
    """'C:\\skills-library\\a\\b' | 'a/b' -> 'a/b' (mirrors scripts/index-check.sh)."""
    r = (ruta or '').strip().replace(BS, '/')
    for marker in ('skills-library/', 'skills_library/'):
        if marker in r:
            return r[r.index(marker) + len(marker):].rstrip('/')
    return r.rstrip('/')


def load(ref):
    """Map skill dir -> normalized row signature, for _INDEX.csv at `ref`."""
    try:
        raw = subprocess.check_output(['git', 'show', '%s:_INDEX.csv' % ref])
    except subprocess.CalledProcessError:
        return {}
    text = raw.decode('utf-8-sig').replace(chr(13) + chr(10), chr(10))
    rows = {}
    for row in csv.DictReader(io.StringIO(text)):
        d = norm(row.get('ruta_biblioteca', ''))
        if d:
            rows[d] = tuple(sorted((k, (v or '').strip()) for k, v in row.items()))
    return rows


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: index-changed-skills.py <base-ref>')
    # The caller reads this with `while IFS= read -r`; CRLF (Python default on
    # Windows) would leave a stray CR on every path.
    sys.stdout.reconfigure(newline=chr(10))
    base = load('origin/%s' % sys.argv[1])
    head = load('HEAD')
    for d, sig in head.items():
        if base.get(d) != sig:
            print(d)


if __name__ == '__main__':
    main()
