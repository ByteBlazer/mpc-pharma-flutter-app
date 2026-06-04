#!/usr/bin/env bash
# Local Flutter web dev: Chrome with web security disabled so staging API
# calls work without CORS headers on localhost. For development only.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME_PROFILE="${TMPDIR:-/tmp}/mpc_pharma_chrome_dev"

exec flutter run -d chrome \
  --dart-define=API_ENV=staging \
  --web-browser-flag "--disable-web-security" \
  --web-browser-flag "--disable-site-isolation-trials" \
  --web-browser-flag "--user-data-dir=$CHROME_PROFILE"
