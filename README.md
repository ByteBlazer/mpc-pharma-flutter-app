# MPC Pharma

Flutter logistics app for scanning, dispatch, and delivery.

## Run

```bash
flutter pub get
flutter run --dart-define=API_ENV=staging
```

Production API:

```bash
flutter run --dart-define=API_ENV=production
```

## Flutter web

**Deployment:** static web at **mpcpharma.in** → API at **pharmatracker.in** (cross-origin).

When the app is served from `mpcpharma.in` or `www.mpcpharma.in`, it automatically uses `https://pharmatracker.in/api/` (see `app_config.dart`).

### Production web build

```bash
flutter build web --release
# Deploy build/web to mpcpharma.in hosting
```

### Local Chrome dev

Browsers block `localhost` → staging/production API unless CORS allows it. Options:

1. Deploy updated API (staging allows `localhost` when `NODE_ENV=staging`).
2. Local API: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/`
3. Dev-only script: `./scripts/run_web_dev.sh`
4. Override env: `flutter run -d chrome --dart-define=API_ENV=production`

## Android package

`com.mpc.pharma`

### Google Maps on Android (Trip Dashboard)

If the map shows the **Google logo and zoom buttons** but **no map tiles** (gray/blank), check in order:

1. **`android/local.properties`** must set `GOOGLE_MAPS_API_KEY_ANDROID` to your key (rebuild after changing — hot reload is not enough). If this is missing, the manifest gets an empty key and tiles never load.
2. **Google Cloud → APIs & Services → Library** — enable **Maps SDK for Android** for the project (separate from the key existing).
3. **Key → API restrictions** — use **Don't restrict key**, or **Restrict key** and explicitly select **Maps SDK for Android** (and Maps JavaScript API for web). **Restrict key** with _no APIs checked_ blocks all usage even if application restrictions are None.
4. If the key uses **HTTP referrer** application restrictions, it works in Chrome only; use **None** or **Android apps** for the phone build.

5. Run `./scripts/print_android_maps_setup.sh` for package name and debug **SHA-1**.
6. In [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) → **Credentials** → create an API key (or duplicate an existing one).
7. Enable **Maps SDK for Android** for the project.
8. Restrict the key: **Android apps** → package `com.mpc.pharma` + your SHA-1 fingerprint(s).
9. Add to `android/local.properties` (see `android/local.properties.example`):

   ```properties
   GOOGLE_MAPS_API_KEY_ANDROID=your-android-maps-key
   ```

10. Rebuild: `flutter run` on the device (full restart, not hot reload).

Keep the browser key in `web/index.html` for Flutter web; use a separate key for Android.
