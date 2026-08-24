# Firebase App Check Setup

This document describes how to fully configure Firebase App Check for the
Poker Night app. App Check prevents bots, scripts, and stolen API keys from
accessing your Firestore database and Cloud Functions.

## 1. Android — Play Integrity

1. In [Firebase Console](https://console.firebase.google.com) → **App Check** → **Apps**, select your Android app.
2. Register with **Play Integrity** (recommended) or **SafetyNet** (legacy).
3. Add your **SHA-256 signing certificate fingerprint** in
   **Project Settings → Your Android App → SHA certificate fingerprints**.
   ```bash
   # Debug keystore fingerprint
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   # Release keystore fingerprint
   keytool -list -v -keystore <path/to/release.keystore> -alias <alias>
   ```
4. For local development, enable the **Debug provider** in the Firebase Console
   and add the auto-generated debug token.

## 2. iOS — App Attest

1. In Firebase Console → **App Check** → **Apps**, select your iOS app.
2. Register with **App Attest** (iOS 14+) with **DeviceCheck** as fallback.
3. Ensure your **Team ID**, **App ID Prefix**, and **Bundle ID** are correctly
   registered in the Apple Developer portal and match `GoogleService-Info.plist`.
4. For local development, add a **Debug token** via the Firebase Console.

## 3. Web — reCAPTCHA v3

1. Register a **reCAPTCHA v3** site key at <https://www.google.com/recaptcha/admin>.
2. Add your domain to the allowed domains list.
3. Pass the site key at build time:
   ```bash
   flutter build web --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=<your-site-key>
   ```

## 4. Enforce App Check in Firebase Console

1. Firebase Console → **App Check** → **Protect resources**.
2. Click **Enforce** for:
   - **Cloud Firestore**
   - **Cloud Functions** (when added)
3. ⚠️ Do NOT enforce until all platforms are registered and tested, or
   legitimate users will be blocked.

## 5. Developer Onboarding

```bash
# Local dev (uses debug provider — never ship this)
flutter run --dart-define=APP_CHECK_DEBUG=true

# Web production build
flutter build web --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=<key>

# Android/iOS production build (no extra flags — PlayIntegrity/AppAttest auto-selected)
flutter build apk --release
flutter build ios --release
```

## 6. Verifying App Check tokens (Debug)

In debug mode the console prints `[AppCheck] Activated with DEBUG provider`.
You can also check the token is being attached by enabling Firestore debug
logging and inspecting the `x-firebase-appcheck` header.
