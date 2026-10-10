# Android Signing Configuration for Zohal Connect

This document outlines release keystore generation and CI signing configuration per Section 8.3 & 16.

## 1. Generating a Release Keystore
To generate a release signing keystore, run:

```bash
keytool -genkey -v \
  -keystore zohal-release.jks \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -alias zohal \
  -storetype JKS
```

## 2. CI Secrets Configuration
In GitHub Actions repository secrets, add:

- `ANDROID_KEYSTORE_BASE64`: Base64 encoded contents of `zohal-release.jks`
  ```bash
  base64 -w 0 zohal-release.jks
  ```
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: `zohal`
- `ANDROID_KEY_PASSWORD`: Key password

## 3. Gradle Signing in CI
The GitHub Actions release workflow decodes the keystore into `app/android/app/zohal-release.jks` before invoking `./gradlew assembleRelease` or `flutter build apk --release`.
Keystore files are never committed to version control.
