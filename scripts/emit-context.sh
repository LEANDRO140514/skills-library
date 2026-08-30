#!/usr/bin/env bash
# Emit a governed skills index for "context file" runtimes (pattern B):
# AGENTS.md   (OpenCode, Cursor, kimchi, most AGENTS.md-aware CLIs)
# .goosehints (Block Goose)
#
# These runtimes do not auto-discover SKILL.md. They read one always-present
# markdown file. This script produces a block for that file: it lists every
# governed skill, says WHEN to use it and WHERE its SKILL.md lives, and lets
# the agent open the skill body on demand.
#
# It resolves each _INDEX.csv row through the SAME governance rules as
# scripts/find-skills.sh and lists ONLY skills that resolve to `allow` or
# `review`. It reads _INDEX.csv and each SKILL.md. It writes nothing.
#
# The emitted block is a DEPLOYMENT artifact, not canonical: regenerate it,
# never hand-edit it, and never treat it as the source of truth.
#
# Usage:
#   ./scripts/emit-context.sh [--format agents|goosehints]
#                             [--profile dev] [--root <path-prefix>]
#
#   --format agents      (default) markdown section + table, for AGENTS.md
#   --format goosehints  plain bullet list + directive, for .goosehints
#   --profile <name>     restrict to a load-skills profile (known: dev).
#                        default: every resolvable row in _INDEX.csv
#   --root <path>        prefix prepended to each SKILL.md path in the output,
#                        e.g. ~/skills-library or a `load-skills --target` dir.
#                        default: none -> paths are repo-root-relative
#
# Typical use:
#   ./scripts/emit-context.sh --format agents     --root ~/skills-library >> AGENTS.md
#   ./scripts/emit-context.sh --format goosehints --root ~/skills-library >> .goosehints
#
# Exit code:
#   0  at least one skill emitted
#   2  zero resolvable skills for the selection
#   3  usage error or no usable Python interpreter

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PYTHON=""
for c in python3 python "py -3"; do
  if $c -c "import sys" >/dev/null 2>&1; then PYTHON="$c"; break; fi
done
if [ -z "$PYTHON" ]; then
  echo >&2 "emit-context: no usable Python interpreter (tried python3, python, py -3)"
  exit 3
fi

FORMAT="agents"
PROFILE=""
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift 2 ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --root) ROOT="${2:-}"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    -h|--help)
      sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo >&2 "emit-context: unknown argument '$1'"
      exit 3
      ;;
  esac
done

case "$FORMAT" in
  agents|goosehints) ;;
  *) echo >&2 "emit-context: --format must be 'agents' or 'goosehints' (got '$FORMAT')"; exit 3 ;;
esac

set +e
FORMAT="$FORMAT" PROFILE="$PROFILE" ROOT="$ROOT" $PYTHON - <<'PYEOF'
import csv, io, os, pathlib, re, sys

try:                                    # keep accents / em-dashes intact on Windows
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

fmt = os.environ["FORMAT"]
profile = os.environ["PROFILE"].strip()
root_prefix = os.environ["ROOT"].strip()

repo = pathlib.Path(".").resolve()

# Keep in sync with scripts/load-skills.sh :: profile_dev().
PROFILES = {
    "dev": [
        "agentes-meta/comunidad/find-skills",
        "agentes-meta/mias/skill-promote",
        "agentes-meta/mias/skill-scanner",
        "agentes-meta/comunidad/tdd-workflow",
        "agentes-meta/comunidad/security-review",
        "agentes-meta/comunidad/coding-standards",
        "devops/mias/controlled-monorepo-workflow",
    ],
}

if profile and profile not in PROFILES:
    print("emit-context: unknown profile '%s' (known: %s)"
          % (profile, ", ".join(PROFILES)), file=sys.stderr)
    sys.exit(3)

raw = pathlib.Path("_INDEX.csv").read_bytes()
while raw.startswith(b"\xef\xbb\xbf"):
    raw = raw[3:]
text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")

for lineno, line in enumerate(text.split("\n"), 1):
    if "\t" in line:
        print("emit-context: _INDEX.csv has a TAB on line %d; run scripts/lint-index.sh"
              % lineno, file=sys.stderr)
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
    """Same governance rules as scripts/find-skills.sh :: classify()."""
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
        return "allow" if origin == "mias" else "blocked"
    return "blocked"


def read_description(rel):
    """Pull `description:` from the SKILL.md YAML frontmatter."""
    try:
        lines = (repo / rel / "SKILL.md").read_text(
            encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    if not lines or lines[0].strip() != "---":
        return ""
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        return ""
    fm = lines[1:end]
    for i, ln in enumerate(fm):
        m = re.match(r"description:\s*(.*)$", ln)
        if not m:
            continue
        val = m.group(1).strip()
        block_scalar = val in (">", "|", ">-", "|-", ">+", "|+", "")
        parts = [] if block_scalar else [val]
        for cont in fm[i + 1:]:
            # A new top-level key ends the value; so does a blank line for a
            # plain multiline scalar.
            if cont and not cont[0].isspace():
                break
            if not cont.strip():
                if block_scalar:
                    continue
                break
            parts.append(cont.strip())
        joined = " ".join(p for p in parts if p)
        if len(joined) >= 2 and joined[0] == joined[-1] and joined[0] in "\"'":
            joined = joined[1:-1]
        return joined
    return ""


def first_sentence(desc):
    d = " ".join(desc.split())
    m = re.search(r"(.+?[.!?])(\s|$)", d)
    return m.group(1) if m else d


def skill_path(rel):
    if not root_prefix:
        return rel + "/SKILL.md"
    return root_prefix.rstrip("/") + "/" + rel + "/SKILL.md"


def cell(s):
    return " ".join(s.split()).replace("|", "\\|").strip()


wanted = PROFILES.get(profile) if profile else None
seen = set()
skills = []
for r in rows:
    rel = norm(r.get("ruta_biblioteca", ""))
    if not rel:
        continue
    if wanted is not None and rel not in wanted:
        continue
    name = (r.get("nombre") or "").strip()
    if not name or name in seen:
        continue
    status = classify(r)
    if status not in ("allow", "review"):
        continue
    seen.add(name)
    skills.append({
        "nombre": name,
        "rel": rel,
        "status": status,
        "waiver": (r.get("scan_waiver") or "").strip(),
        "description": read_description(rel),
    })

skills.sort(key=lambda s: s["nombre"])

if not skills:
    print("emit-context: zero resolvable skills for this selection", file=sys.stderr)
    sys.exit(2)

GEN_NOTE = ("Generated by scripts/emit-context.sh from the governed skills-library "
            "_INDEX.csv. Regenerate; do not hand-edit. These are deployment copies, "
            "not the canonical source.")

lines_out = []
if fmt == "agents":
    lines_out += [
        "<!-- BEGIN governed-skills (scripts/emit-context.sh) -->",
        "## Available Skills (governed)",
        "",
        GEN_NOTE,
        "",
        "When a task matches a skill's \"When to use\", open that skill's "
        "`SKILL.md` and follow it before improvising.",
        "",
        "| Skill | When to use | SKILL.md |",
        "|---|---|---|",
    ]
    for s in skills:
        desc = cell(s["description"] or "(no description in SKILL.md)")
        if s["status"] == "review":
            desc += " _(needs review: %s)_" % cell(s["waiver"] or "waiver on file")
        lines_out.append("| `%s` | %s | `%s` |" % (s["nombre"], desc, skill_path(s["rel"])))
    lines_out += ["", "<!-- END governed-skills -->"]
else:
    lines_out += [
        "# BEGIN governed-skills (scripts/emit-context.sh)",
        GEN_NOTE,
        "",
        "Skills available to this session. Before improvising on a matching "
        "task, read the referenced SKILL.md and follow it:",
        "",
    ]
    for s in skills:
        desc = first_sentence(s["description"]) if s["description"] else \
            "(no description in SKILL.md)"
        tag = " [needs review]" if s["status"] == "review" else ""
        lines_out.append("- %s%s: %s" % (s["nombre"], tag, desc))
        lines_out.append("  read: %s" % skill_path(s["rel"]))
    lines_out += ["", "# END governed-skills"]

print("\n".join(lines_out))
sys.exit(0)
PYEOF
rc=$?
set -e
exit "$rc"
