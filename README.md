# MPC Pharma Flutter App

A fresh Flutter starter for MPC Pharma. The app currently renders a responsive Hello World shell that is web-first, while remaining usable as Android and iOS apps.

The project is generated with these platform targets:

- Web, intended for deployment to `https://mpcpharma.in`
- Android app package
- iOS app package

## Requirements

Install and verify Flutter before packaging:

```bash
flutter --version
flutter doctor
```

Use a Flutter SDK that satisfies the `pubspec.yaml` SDK constraint. Install platform tooling as needed:

- Android: Android Studio, Android SDK, platform tools, and a configured signing key for release builds.
- iOS: macOS with Xcode and CocoaPods. iOS packaging cannot be completed from Linux.
- Web: Any machine with Flutter web support enabled.

Fetch dependencies after cloning or changing `pubspec.yaml`:

```bash
flutter pub get
```

## API Configuration

The REST API base URL is passed at build time using `--dart-define`:

```bash
--dart-define=API_BASE_URL=https://api.example.com
```

The real REST API URL is not set yet. Replace `https://api.example.com` with the API URL when it is available.

For local development:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
flutter run -d android --dart-define=API_BASE_URL=https://api.example.com
flutter run -d ios --dart-define=API_BASE_URL=https://api.example.com
```

## Web-First UI Direction

The UI should be designed as a responsive web application first:

- Prefer layouts that work well in browser widths, such as centered content regions, responsive grids, cards, tables, top navigation, and form sections.
- Avoid mobile-only patterns as the primary experience, such as bottom navigation or full-screen picker flows, unless they are also usable on web.
- Use breakpoints to make the same UI usable on Android and iOS.
- Keep Android and iOS as responsive versions of the same product, not separate mobile-only experiences.

## Run Locally

Web:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
```

Android:

```bash
flutter run -d android --dart-define=API_BASE_URL=https://api.example.com
```

iOS, from macOS:

```bash
flutter run -d ios --dart-define=API_BASE_URL=https://api.example.com
```

## Package for Web

Build the production web bundle:

```bash
flutter build web --release --base-href=/ --dart-define=API_BASE_URL=https://api.example.com
```

The output is generated at:

```text
build/web
```

### Deploy Web to EC2 for `mpcpharma.in`

These steps assume an Ubuntu EC2 instance running Nginx and serving the domain root.

1. Build the web bundle locally or on CI:

```bash
flutter build web --release --base-href=/ --dart-define=API_BASE_URL=https://api.example.com
```

2. Copy the generated files to EC2:

```bash
rsync -avz --delete build/web/ ubuntu@YOUR_EC2_PUBLIC_IP:/tmp/mpc-pharma-web/
```

3. On the EC2 instance, install and configure Nginx:

```bash
sudo apt update
sudo apt install -y nginx
sudo mkdir -p /var/www/mpcpharma.in
sudo rsync -av --delete /tmp/mpc-pharma-web/ /var/www/mpcpharma.in/
```

4. Create an Nginx site config:

```nginx
server {
    listen 80;
    server_name mpcpharma.in www.mpcpharma.in;

    root /var/www/mpcpharma.in;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|wasm|json)$ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        try_files $uri =404;
    }
}
```

Save it as `/etc/nginx/sites-available/mpcpharma.in`, then enable it:

```bash
sudo ln -sf /etc/nginx/sites-available/mpcpharma.in /etc/nginx/sites-enabled/mpcpharma.in
sudo nginx -t
sudo systemctl reload nginx
```

5. Point DNS records for `mpcpharma.in` and `www.mpcpharma.in` to the EC2 public IP.

6. Add HTTPS with Certbot:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d mpcpharma.in -d www.mpcpharma.in
```

After this, the app should be available at:

```text
https://mpcpharma.in
```

## Package for Android

### Debug APK

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Play Store App Bundle

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

### Android Signing Notes

Before distributing release builds, configure Android signing:

1. Create a keystore using `keytool`.
2. Store signing values outside source control, usually in `android/key.properties`.
3. Update `android/app/build.gradle.kts` to use that signing config for release builds.

Do not commit keystores or signing passwords.

## Package for iOS

These steps require macOS and Xcode.

1. Install CocoaPods if needed:

```bash
sudo gem install cocoapods
```

2. Fetch dependencies:

```bash
flutter pub get
```

3. Open the iOS project in Xcode:

```bash
open ios/Runner.xcworkspace
```

4. In Xcode:

- Select the `Runner` target.
- Set the correct Team and Bundle Identifier.
- Configure signing and capabilities.
- Choose a release scheme and target device or archive destination.

5. Build an iOS release from Flutter:

```bash
flutter build ios --release --dart-define=API_BASE_URL=https://api.example.com
```

6. For App Store / TestFlight, create an archive:

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com
```

Output is created under:

```text
build/ios/ipa
```

## Quality Checks

Run these before packaging:

```bash
flutter analyze
flutter test
```

## Current App State

The current app is intentionally minimal:

- Responsive Hello World UI
- Web-first layout direction
- Android, iOS, and web project scaffolding
- Build-time REST API URL placeholder

The REST API integration can be added once the API base URL and endpoints are finalized.
