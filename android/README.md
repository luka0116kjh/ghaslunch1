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

## Install and run from a terminal

Start an existing emulator or connect a USB device, then run:

```powershell
cd D:\Projects\ghaslunch\android
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:Path="$env:JAVA_HOME\bin;C:\Users\GHAS\AppData\Local\Android\Sdk\platform-tools;$env:Path"
.\gradlew.bat installDebug
adb shell monkey -p kr.hs.ghas.ghason -c android.intent.category.LAUNCHER 1
```

For one-command emulator boot, install, and launch:

```powershell
cd D:\Projects\ghaslunch\android
.\scripts\run-debug.ps1
```

For headless emulator runs in terminal-only environments:

```powershell
.\scripts\run-debug.ps1 -NoWindow
```

To watch app and WebView logs:

```powershell
.\scripts\logcat.ps1 -Clear
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
