#!/usr/bin/env python3
"""Report the governance state registered in _INDEX.csv for one skill directory.

Skill Gate uses this to honour verdicts and waivers that were already reviewed and
recorded, instead of re-denying every skill whose score sits above the threshold.

A waiver is only honoured when it was issued for the exact content being scanned:
`hash_sha256` in the row must equal the SHA-256 of the git blob of that skill's
SKILL.md. If the SKILL.md changed, the waiver is stale and does not apply.

Usage: index-waiver.py <skill-dir> [<index-path>]
Output (GITHUB_OUTPUT format, one per line):
    verdict=allow|review|deny|none
    waiver=yes|no
    hash_match=yes|no
    waived=yes|no        # verdict+waiver+hash all check out
"""
import csv
import hashlib
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


def blob_sha256(rel_path):
    """Uppercase SHA-256 of the canonical git blob (LF) at HEAD, or None."""
    try:
        content = subprocess.check_output(['git', 'cat-file', 'blob', 'HEAD:' + rel_path])
    except subprocess.CalledProcessError:
        return None
    return hashlib.sha256(content).hexdigest().upper()


def main():
    if not 2 <= len(sys.argv) <= 3:
        sys.exit('usage: index-waiver.py <skill-dir> [<index-path>]')
    skill_dir = sys.argv[1].rstrip('/')
    index_path = sys.argv[2] if len(sys.argv) == 3 else '_INDEX.csv'

    raw = io.open(index_path, newline='', encoding='utf-8-sig').read()
    rows = [r for r in csv.DictReader(io.StringIO(raw))
            if norm(r.get('ruta_biblioteca', '')) == skill_dir]

    verdict, waiver, hash_match = 'none', False, False
    if len(rows) == 1:
        row = rows[0]
        verdict = (row.get('scan_verdict') or '').strip() or 'none'
        waiver = bool((row.get('scan_waiver') or '').strip())
        stored = (row.get('hash_sha256') or '').strip().upper()
        actual = blob_sha256(skill_dir + '/SKILL.md')
        hash_match = bool(stored) and stored == actual

    # allow needs no waiver text; review must carry one.
    waived = (
        hash_match
        and (verdict == 'allow' or (verdict == 'review' and waiver))
    )

    out = [
        'verdict=%s' % verdict,
        'waiver=%s' % ('yes' if waiver else 'no'),
        'hash_match=%s' % ('yes' if hash_match else 'no'),
        'waived=%s' % ('yes' if waived else 'no'),
    ]
    print(chr(10).join(out))


if __name__ == '__main__':
    main()
