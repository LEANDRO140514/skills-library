#!/usr/bin/env bash
# Governed skill resolver.
#
# find-skills stops being a "grep of names": it resolves a requested skill
# against _INDEX.csv and applies the scan_verdict governance rules. It NEVER
# writes _INDEX.csv and it does NOT call SkillSpector.
#
# Usage:
#   ./scripts/find-skills.sh <name>
#   ./scripts/find-skills.sh --query "<substring>"
#
# Output: one compact JSON object per matching row, on stdout:
#   {"nombre","ruta_biblioteca","mias_o_comunidad","scan_verdict",
#    "scan_waiver","confianza","status"}
#   status ∈ allow | review | blocked | unindexed | not_found
#
# Exit code:
#   0  at least one result is `allow` or `review`
#   2  every result is `blocked` / `unindexed` / `not_found`
#   3  usage error or no usable Python interpreter
#
# Governance (see README § find-skills):
#   Never resolvable  → status=blocked
#     - ruta_biblioteca under _archivo/
#     - scan_verdict = deny
#     - mias_o_comunidad = comunidad with empty/absent scan_verdict
#       ("comunidad ciega" = BLOCKED_BY_GOVERNANCE, not NOT_FOUND)
#     - scan_verdict = review with an empty scan_waiver
#   Resolvable:
#     - mias, not deny, not _archivo             → allow  (empty scan tolerated
#       until a PR touches its SKILL.md)
#     - comunidad + scan_verdict = allow         → allow
#     - comunidad + scan_verdict = review + non-empty scan_waiver → review
#       (caller must surface needs_review; do not load it silently as allow)
#   name given, folder exists on disk, no _INDEX.csv row → unindexed
#   no name match anywhere                                → not_found

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Sibling scripts assume `python3`; be lenient so this runs on plain Windows too.
PYTHON=""
for c in python3 python "py -3"; do
  if $c -c "import sys" >/dev/null 2>&1; then PYTHON="$c"; break; fi
done
if [ -z "$PYTHON" ]; then
  echo >&2 "find-skills: no usable Python interpreter (tried python3, python, py -3)"
  exit 3
fi

MODE="name"
NEEDLE=""
case "${1:-}" in
  "")
    echo >&2 "Usage: $0 <name> | --query <substring>"
    exit 3
    ;;
  --query)
    MODE="query"
    NEEDLE="${2:-}"
    if [ -z "$NEEDLE" ]; then echo >&2 "find-skills: --query needs an argument"; exit 3; fi
    ;;
  --query=*)
    MODE="query"
    NEEDLE="${1#--query=}"
    if [ -z "$NEEDLE" ]; then echo >&2 "find-skills: --query needs an argument"; exit 3; fi
    ;;
  -*)
    echo >&2 "find-skills: unknown option '$1'"
    exit 3
    ;;
  *)
    MODE="name"
    NEEDLE="$1"
    ;;
esac

set +e
MODE="$MODE" NEEDLE="$NEEDLE" $PYTHON - <<'PYEOF'
import csv, io, json, os, pathlib, sys

mode = os.environ["MODE"]
needle = os.environ["NEEDLE"]
needle_l = needle.lower()

root = pathlib.Path(".").resolve()

raw = pathlib.Path("_INDEX.csv").read_bytes()
while raw.startswith(b"\xef\xbb\xbf"):          # strip UTF-8 BOM(s)
    raw = raw[3:]
text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")

# A tab-delimited row makes csv.DictReader yield None for every unfilled
# column. Refuse it here the same way index-check does, and point at the lint.
for lineno, line in enumerate(text.split("\n"), 1):
    if "\t" in line:
        print(f"find-skills: _INDEX.csv has a TAB on line {lineno}; "
              f"run scripts/lint-index.sh", file=sys.stderr)
        sys.exit(3)

rows = list(csv.DictReader(io.StringIO(text)))


def norm(ruta):
    """Absolute or relative ruta_biblioteca -> forward-slash path from repo root."""
    if not ruta:
        return ""
    r = ruta.strip().replace("\\", "/")
    for marker in ("skills-library/", "skills_library/"):
        if marker in r:
            return r[r.index(marker) + len(marker):].rstrip("/")
    if ":" not in r and not r.startswith("/"):
        return r.rstrip("/")
    return r


def classify(row):
    rel = norm(row.get("ruta_biblioteca", ""))
    verdict = (row.get("scan_verdict") or "").strip().lower()
    waiver = (row.get("scan_waiver") or "").strip()
    origin = (row.get("mias_o_comunidad") or "").strip().lower()

    if rel.startswith("_archivo/"):
        return "blocked"
    if verdict == "deny":
        return "blocked"
    if verdict == "allow":
        return "allow"
    if verdict == "review":
        return "review" if waiver else "blocked"
    if verdict == "":
        if origin == "mias":
            return "allow"
        return "blocked"            # comunidad ciega = BLOCKED_BY_GOVERNANCE
    return "blocked"                # unrecognised verdict value


def matches(row):
    name = (row.get("nombre") or "").strip().lower()
    if not name:
        return False
    if mode == "name":
        return name == needle_l or needle_l in name
    return needle_l in name


hits = [r for r in rows if matches(r)]

# In name mode, an exact hit wins over substring hits.
if mode == "name":
    exact = [r for r in hits if (r.get("nombre") or "").strip().lower() == needle_l]
    if exact:
        hits = exact

results = []
for r in hits:
    results.append({
        "nombre": (r.get("nombre") or "").strip(),
        "ruta_biblioteca": norm(r.get("ruta_biblioteca", "")),
        "mias_o_comunidad": (r.get("mias_o_comunidad") or "").strip(),
        "scan_verdict": (r.get("scan_verdict") or "").strip(),
        "scan_waiver": (r.get("scan_waiver") or "").strip(),
        "confianza": (r.get("confianza") or "").strip(),
        "status": classify(r),
    })

if not results:
    on_disk = None
    if mode == "name" and "/" not in needle and "\\" not in needle:
        for pattern in (f"*/*/{needle}/SKILL.md", f"*/{needle}/SKILL.md"):
            for cand in root.glob(pattern):
                on_disk = cand.parent
                break
            if on_disk is not None:
                break
    if on_disk is not None:
        results.append({
            "nombre": needle,
            "ruta_biblioteca": on_disk.relative_to(root).as_posix(),
            "mias_o_comunidad": "",
            "scan_verdict": "",
            "scan_waiver": "",
            "confianza": "",
            "status": "unindexed",
        })
    else:
        results.append({
            "nombre": needle,
            "ruta_biblioteca": "",
            "mias_o_comunidad": "",
            "scan_verdict": "",
            "scan_waiver": "",
            "confianza": "",
            "status": "not_found",
        })

for obj in results:
    print(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))

sys.exit(0 if any(o["status"] in ("allow", "review") for o in results) else 2)
PYEOF
rc=$?
set -e
exit "$rc"
