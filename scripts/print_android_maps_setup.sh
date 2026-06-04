#!/usr/bin/env bash
# Prints values needed for Google Maps SDK for Android in Cloud Console.
set -euo pipefail

echo "=== Google Maps Android setup (MPC Pharma) ==="
echo ""
echo "Package name: com.mpc.pharma"
echo ""
echo "Debug keystore SHA-1 (add in API key → Android restriction):"
keytool -list -v \
  -keystore "${HOME}/.android/debug.keystore" \
  -alias androiddebugkey \
  -storepass android \
  -keypass android 2>/dev/null | grep "SHA1:" || echo "  (debug.keystore not found)"
echo ""
echo "Release SHA-1: use your release keystore, e.g.:"
echo "  keytool -list -v -keystore /path/to/upload-keystore.jks -alias your-alias"
echo ""
echo "In Google Cloud Console for GOOGLE_MAPS_API_KEY_ANDROID:"
echo "  1. Enable API: Maps SDK for Android"
echo "  2. Credential restriction: Android apps → package + SHA-1 above"
echo "  3. Add key to android/local.properties:"
echo "     GOOGLE_MAPS_API_KEY_ANDROID=<your-android-key>"
echo ""
echo "Web uses a separate browser key in web/index.html (HTTP referrer restriction)."
