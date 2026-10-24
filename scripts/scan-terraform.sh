#!/usr/bin/env bash
set -euo pipefail

# Shared by pre-commit and GitHub Actions. The optional argument retains SARIF.
if [ "$#" -gt 1 ]; then
  echo "Usage: bash scripts/scan-terraform.sh [report.sarif]" >&2
  exit 2
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "Install Trivy 0.76.1 before running this check. See CONTRIBUTING.md." >&2
  exit 1
fi

trivy_version="$(trivy --version | sed -n 's/^Version: //p')"
if [ "$trivy_version" != "0.76.1" ]; then
  echo "This check requires Trivy 0.76.1 to match GitHub Actions; found $trivy_version." >&2
  exit 1
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

scan_directory="$(mktemp -d "${TMPDIR:-/tmp}/cloudkube-trivy.XXXXXX")"
trap 'rm -rf "$scan_directory"' EXIT
report_file="${1:-$scan_directory/results.sarif}"

# An empty cache ensures --skip-check-update uses the pinned binary's bundled checks.
# Scan both Terraform roots together, with repository-relative SARIF paths.
# Git metadata and downloaded Terraform caches are not source configurations.
# --tf-vars supplies the committed synthetic example to every scanned root.
# Its only input shared with infra is aws_region, matching infra's current default.
set +e
trivy config --cache-dir "$scan_directory/cache" \
  --skip-check-update --skip-version-check --disable-telemetry \
  --misconfig-scanners terraform \
  --skip-dirs .git --skip-dirs .terraform --skip-dirs '**/.terraform' \
  --tf-vars bootstrap/terraform.tfvars.example \
  --format sarif --severity MEDIUM,HIGH,CRITICAL --exit-code 0 \
  --output "$report_file" . 2>"$scan_directory/trivy.log"
scan_status=$?
set -e
cat "$scan_directory/trivy.log" >&2
if [ "$scan_status" -ne 0 ]; then
  exit "$scan_status"
fi
if grep -Fq '[terraform parser] Error parsing file' "$scan_directory/trivy.log"; then
  echo "Trivy could not parse a Terraform file. The report is incomplete." >&2
  exit 1
fi

python3 - "$report_file" <<'PY'
import json
import os
import sys

with open(sys.argv[1], encoding="utf-8") as report_file:
    report = json.load(report_file)
if report.get("version") != "2.1.0" or not report.get("runs"):
    raise SystemExit("Expected a valid SARIF report with at least one run.")
results = [result for run in report["runs"] for result in run.get("results", [])]
summary = (
    "## Security scan (advisory)\n\n"
    "Terraform configurations in infra and bootstrap are scanned from the repository root.\n\n"
    "This static scan uses synthetic inputs from bootstrap/terraform.tfvars.example. "
    "The --tf-vars option applies to both roots; the current shared aws_region input "
    "matches the infra default. Other real input overrides are not covered by this run.\n\n"
    f"Trivy reported {len(results)} findings at medium severity or above.\n\n"
    "Findings do not block this baseline. Review the SARIF report; a successful "
    "check does not mean the configuration is free of findings.\n"
)
print(summary)
for result in results:
    print(f"{result['ruleId']}: {result['message']['text']}")
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as step_summary:
        step_summary.write(summary)
PY
