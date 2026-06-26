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

The GitHub Actions workflow pins Flutter to version `3.41.5` for predictable builds. Local development should use the same Flutter version when possible.

Fetch dependencies after cloning or changing `pubspec.yaml`:

```bash
flutter pub get
```

## API Configuration

The REST API base URL is loaded from environment files bundled with the app:

```text
env/local.env
env/staging.env
env/production.env
```

Each file contains the same keys:

```env
APP_ENV=local
API_BASE_URL=http://localhost:8080
```

`env/staging.env` and `env/production.env` keep `API_BASE_URL=__API_BASE_URL__` in source control. GitHub Actions replaces only that placeholder at build time. `env/local.env` keeps the real local API URL and is not patched by CI.

The app defaults to `local` and loads `env/local.env` when no environment is specified.

To select another environment, pass only the environment name:

```bash
--dart-define=APP_ENV=staging
--dart-define=APP_ENV=production
```

Do not pass `API_BASE_URL` on the command line.

For GitHub Actions deployments, the workflow replaces the `__API_BASE_URL__` placeholder in the selected env file at build time using the `DOMAIN_NAME` secret:

- `staging` branch writes `env/staging.env` with `API_BASE_URL=https://staging.<DOMAIN_NAME>/api`
- `main` branch writes `env/production.env` with `API_BASE_URL=https://<DOMAIN_NAME>/api`

`env/local.env` is never patched by GitHub Actions.

## Web-First UI Direction

The UI should be designed as a responsive web application first:

- Prefer layouts that work well in browser widths, such as centered content regions, responsive grids, cards, tables, top navigation, and form sections.
- Avoid mobile-only patterns as the primary experience, such as bottom navigation or full-screen picker flows, unless they are also usable on web.
- Use breakpoints to make the same UI usable on Android and iOS.
- Keep Android and iOS as responsive versions of the same product, not separate mobile-only experiences.

## Run Each Environment

Local is the default environment.

### Local

Web:

```bash
flutter run -d chrome
```

Android:

```bash
flutter run -d android
```

iOS, from macOS:

```bash
flutter run -d ios
```

### Staging

Web:

```bash
flutter run -d chrome --dart-define=APP_ENV=staging
```

Android:

```bash
flutter run -d android --dart-define=APP_ENV=staging
```

iOS, from macOS:

```bash
flutter run -d ios --dart-define=APP_ENV=staging
```

### Production

Web:

```bash
flutter run -d chrome --dart-define=APP_ENV=production
```

Android:

```bash
flutter run -d android --dart-define=APP_ENV=production
```

iOS, from macOS:

```bash
flutter run -d ios --dart-define=APP_ENV=production
```

## Package for Web

Build the production web bundle:

```bash
flutter build web --release --base-href=/ --dart-define=APP_ENV=production
```

The output is generated at:

```text
build/web
```

To build a staging web bundle:

```bash
flutter build web --release --base-href=/ --dart-define=APP_ENV=staging
```

To build a local web bundle, omit `APP_ENV` or pass `APP_ENV=local`.

### Deploy Web to EC2 for `mpcpharma.in`

These steps assume an Ubuntu EC2 instance running Nginx and serving the domain root.

1. Build the web bundle locally or on CI:

```bash
flutter build web --release --base-href=/ --dart-define=APP_ENV=production
```

2. Copy the generated files to EC2:

```bash
rsync -avz --delete build/web/ ec2-user@YOUR_EC2_PUBLIC_IP:/tmp/mpc-pharma-web/
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

## GitHub Actions Deployment

The workflow at `.github/workflows/deploy.yml` runs only when a commit is pushed to one of these branches:

- `staging`
- `main`

Branch behavior:

- `staging` loads `env/staging.env` and deploys the web app to `staging.<DOMAIN_NAME>`.
- `main` loads `env/production.env` and deploys the web app to `<DOMAIN_NAME>`.
- `staging` packages a debug Android APK.
- `main` packages a signed release Android APK and signed release Android App Bundle that can be uploaded to Play Console.
- iOS is built on a macOS runner and uploaded as an unsigned artifact. A signed IPA needs Apple signing certificate/profile secrets to be added later.

Required GitHub Actions secrets:

```text
EC2_HOST
EC2_SSH_PRIVATE_KEY
EC2_USER
DOMAIN_NAME
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
```

`DOMAIN_NAME` is the base domain, for example `byteblazer.com`. The workflow derives the deployment hostnames from it.

`EC2_USER` is optional. If it is not set, the workflow defaults to `ec2-user`. Use `ec2-user` for Amazon Linux AMIs, `ubuntu` for Ubuntu AMIs, and the correct SSH username for any other AMI.

If the deploy fails with `Permission denied (publickey,...)`, check:

- `EC2_SSH_PRIVATE_KEY` contains the private key for the key pair attached to the EC2 instance.
- `EC2_USER` matches the EC2 AMI username.
- The EC2 security group allows SSH from GitHub Actions runners or from a network path that can reach the instance.
- `EC2_HOST` points to the correct EC2 public IP or public DNS name.

The workflow bootstraps a fresh EC2 instance on every web deploy. It installs `nginx` and `rsync` if needed, removes the default Nginx site, writes a managed Nginx config for `<DOMAIN_NAME>` and `staging.<DOMAIN_NAME>`, validates Nginx, and reloads/restarts it. It supports Ubuntu/Debian and Amazon Linux ownership conventions (`www-data` or `nginx`).

The workflow deploys the built web bundle to:

```text
/var/www/staging.<DOMAIN_NAME>
/var/www/<DOMAIN_NAME>
```

The EC2 instance should already have:

- Amazon Linux, Ubuntu, or another image with `dnf`, `yum`, or `apt-get`
- The SSH user allowed to run the needed `sudo dnf`/`sudo yum`/`sudo apt-get`, `sudo mkdir`, `sudo rm`, `sudo tee`, `sudo sed`, `sudo rsync`, `sudo chown`, `sudo nginx`, and `sudo systemctl` commands
- DNS records in Route 53 pointing `staging.<DOMAIN_NAME>` and `<DOMAIN_NAME>` to the EC2 instance or to the load balancer in front of it

If your AWS SSL certificate is in ACM, TLS should terminate at an Application Load Balancer or CloudFront in front of EC2. In that setup, Nginx listens on plain HTTP `80` and the ALB/CloudFront handles HTTPS.

## Package for Android

### Debug APK

```bash
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK

```bash
flutter build apk --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Play Store App Bundle

```bash
flutter build appbundle --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

For staging Android builds, use the same command with `--dart-define=APP_ENV=staging`. For local debug builds, omit `APP_ENV`.

### Android Signing Notes

Production Android builds are signed by GitHub Actions. Add these repository secrets before using the main branch workflow:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
```

Create an upload keystore locally if you do not already have one:

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Convert the keystore to a single-line base64 value for the GitHub secret:

```bash
base64 -w 0 upload-keystore.jks
```

Use that output as `ANDROID_KEYSTORE_BASE64`. Use the shared keystore/key password as `ANDROID_KEYSTORE_PASSWORD`, and the alias you chose as `ANDROID_KEY_ALIAS`.

Do not commit keystores or signing passwords. The workflow decodes the keystore only inside the GitHub runner and signs the production `.aab` during `flutter build appbundle --release`.

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
flutter build ios --release --dart-define=APP_ENV=production
```

6. For App Store / TestFlight, create an archive:

```bash
flutter build ipa --release --dart-define=APP_ENV=production
```

Output is created under:

```text
build/ios/ipa
```

For staging iOS builds, use `--dart-define=APP_ENV=staging`. For local debug runs, omit `APP_ENV`.

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

Need the following as GitHub Actions secrets:

- `EC2_HOST` - IPv4 address or hostname of the EC2 instance. If this changes, update the Route 53 records in the hosted zone for the domain.
- `EC2_SSH_PRIVATE_KEY` - contents of the private key used to SSH into EC2.
- `DOMAIN_NAME` - base domain, for example `byteblazer.com`. If this changes, remove the old hosted zone records and add the required records for the new domain in Route 53.
- `ANDROID_KEYSTORE_BASE64` - base64-encoded upload keystore file. The keystore file is kept in Google Drive under `ByteBlazer > Google & Android > Google Playstore`. You will need to convert to base64. See below for command.
- `ANDROID_KEY_ALIAS` - upload key alias. Refer file kept in Google Drive under `Learning > GooglePlayStoreAppUpload-Notes.txt`.
- `ANDROID_KEYSTORE_PASSWORD` - shared password for both keystore and key. The password is kept in Google Drive under `Learning > GooglePlayStoreAppUpload-Notes.txt`.

To generate `ANDROID_KEYSTORE_BASE64`, run this from the folder containing the keystore file:

```bash
base64 -w 0 local-keystore-byteblazer-play-console-account-used-for-signing-aab-file.keystore > keystore-base64-to-be-used-in-github-action-secret.txt
```

Copy the full contents of `keystore-base64-to-be-used-in-github-action-secret.txt` into the `ANDROID_KEYSTORE_BASE64` GitHub secret.
