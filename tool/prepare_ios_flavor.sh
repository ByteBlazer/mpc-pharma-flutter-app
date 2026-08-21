#!/usr/bin/env bash
# Configure iOS Runner bundle id + display name for production or staging.
# Usage: tool/prepare_ios_flavor.sh production|staging
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAVOR="${1:-}"

case "${FLAVOR}" in
  production)
    BUNDLE_ID="com.mpc.pharma.mpcPharma"
    DISPLAY_NAME="MPC Pharma"
    ;;
  staging)
    BUNDLE_ID="com.mpc.pharma.mpcPharma.staging"
    DISPLAY_NAME="MPC Pharma Staging"
    ;;
  *)
    echo "Usage: $0 production|staging" >&2
    exit 1
    ;;
esac

export ROOT BUNDLE_ID DISPLAY_NAME
python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT"])
bundle = os.environ["BUNDLE_ID"]
display = os.environ["DISPLAY_NAME"]

pbx = root / "ios/Runner.xcodeproj/project.pbxproj"
text = pbx.read_text()
# Runner app ids only — leave *.RunnerTests unchanged.
text2, n = re.subn(
    r"PRODUCT_BUNDLE_IDENTIFIER = com\.mpc\.pharma\.mpcPharma(?:\.staging)?;",
    f"PRODUCT_BUNDLE_IDENTIFIER = {bundle};",
    text,
)
if n < 1:
    raise SystemExit("No Runner PRODUCT_BUNDLE_IDENTIFIER entries updated in project.pbxproj")
pbx.write_text(text2)
print(f"Updated {n} Runner bundle id(s) → {bundle}")

for name in ("Debug.xcconfig", "Release.xcconfig"):
    path = root / "ios/Flutter" / name
    lines = path.read_text().splitlines()
    out = []
    seen_display = False
    for line in lines:
        if line.startswith("BUNDLE_DISPLAY_NAME="):
            out.append(f"BUNDLE_DISPLAY_NAME={display}")
            seen_display = True
        else:
            out.append(line)
    if not seen_display:
        out.append(f"BUNDLE_DISPLAY_NAME={display}")
    path.write_text("\n".join(out) + "\n")
    print(f"Set BUNDLE_DISPLAY_NAME in {name} → {display}")
PY

echo "iOS flavor ready: ${FLAVOR} (${BUNDLE_ID})"
