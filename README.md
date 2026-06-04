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

Ensure `pharma-tracker-api` production `CORS_ALLOWED_ORIGINS` includes `https://mpcpharma.in` and `https://www.mpcpharma.in`, then redeploy the API.

### Local Chrome dev

Browsers block `localhost` → staging/production API unless CORS allows it. Options:

1. Deploy updated API (staging allows `localhost` when `NODE_ENV=staging`).
2. Local API: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/`
3. Dev-only script: `./scripts/run_web_dev.sh`
4. Override env: `flutter run -d chrome --dart-define=API_ENV=production`

## Android package

`com.mpc.pharma`
