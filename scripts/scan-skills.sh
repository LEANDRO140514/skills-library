#!/usr/bin/env bash
# Local SkillSpector runner — mirrors the CI gate threshold.
# Usage: ./scripts/scan-skills.sh <skill-dir> [<skill-dir> ...]
# Reports are written to reports/ (gitignored).
# Exit code != 0 if any skill is DENY (critical finding OR score >= 51).
#
# Install SkillSpector first:
#   uv tool install "git+https://github.com/NVIDIA/SkillSpector.git@v2.9.6"

set -euo pipefail

if ! command -v skillspector &>/dev/null; then
  echo >&2 ""
  echo >&2 "ERROR: skillspector not found in PATH."
  echo >&2 ""
  echo >&2 "Install with:"
  echo >&2 "  uv tool install \"git+https://github.com/NVIDIA/SkillSpector.git@v2.9.6\""
  echo >&2 ""
  echo >&2 "Then re-run this script."
  exit 127
fi

if [ $# -eq 0 ]; then
  echo >&2 "Usage: $0 <skill-dir> [<skill-dir> ...]"
  echo >&2 "Example: $0 agentes-meta/mias/skill-scanner backend/comunidad/add-emails"
  exit 1
fi

mkdir -p reports

OVERALL_EXIT=0

for SKILL in "$@"; do
  if [ ! -f "${SKILL}/SKILL.md" ]; then
    echo >&2 "WARNING: ${SKILL}/SKILL.md not found — skipping"
    continue
  fi

  SAFE="${SKILL//\//-}"
  JSON_OUT="reports/scan-${SAFE}.json"
  SARIF_OUT="reports/scan-${SAFE}.sarif"

  echo ""
  echo "=== Scanning: ${SKILL}"

  skillspector scan --no-llm --format json  "${SKILL}" > "${JSON_OUT}"
  skillspector scan --no-llm --format sarif "${SKILL}" > "${SARIF_OUT}"

  SCORE=$(jq '.risk_assessment.score' "${JSON_OUT}")
  CRITICAL=$(jq '[.issues[] | select(.severity == "CRITICAL")] | length' "${JSON_OUT}")
  REC=$(jq -r '.risk_assessment.recommendation' "${JSON_OUT}")

  echo "    score:       ${SCORE}/100"
  echo "    critical:    ${CRITICAL}"
  echo "    rec:         ${REC}"
  echo "    json:        ${JSON_OUT}"
  echo "    sarif:       ${SARIF_OUT}"

  # Same threshold as CI: score >= 51 OR any critical finding = DENY
  if [ "${CRITICAL}" -gt 0 ] || [ "${SCORE}" -ge 51 ]; then
    echo "    [DENY]   critical or score >= 51 — do not promote"
    OVERALL_EXIT=1
  elif [ "${SCORE}" -ge 21 ]; then
    echo "    [REVIEW] score 21-50 (caution) — needs Sentry review + scan_waiver before promote"
  else
    echo "    [ALLOW]  score 0-20 (safe)"
  fi
done

echo ""
if [ "${OVERALL_EXIT}" -ne 0 ]; then
  echo "RESULT: one or more skills DENY. Fix before promoting."
else
  echo "RESULT: all skills passed the gate."
fi

exit "${OVERALL_EXIT}"
