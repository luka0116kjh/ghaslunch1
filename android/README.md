# GHAS Lunch Android

This Android app wraps `https://ghaslunch1.web.app/` in a Kotlin WebView Activity and handles notifications with native Firebase Cloud Messaging.

## Build from a terminal

The Android project is designed to build without Android Studio. Use VS Code, PowerShell, the checked-in Gradle Wrapper, and a valid Android SDK path in `local.properties`.

```powershell
cd D:\Projects\ghaslunch\android
.\gradlew.bat clean
.\gradlew.bat assembleDebug
```

The debug APK is written to:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

## Firebase setup

1. Open Firebase Console for project `ghaslunch1`.
2. Add an Android app with package name `kr.hs.ghas.ghason`.
3. Download `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. Keep this file out of public Git history unless the repository policy explicitly allows publishing Firebase client config.

## Notification behavior

- The website notification button calls the native bridge `GHASAndroidNotifications`.
- The app requests Android notification permission on Android 13+.
- When allowed, the app subscribes to the FCM topic `meal`.
- Send app notifications to topic `meal` from Firebase Console or a server using FCM.

The existing website browser notification flow still works in regular browsers.
