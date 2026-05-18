# GHAS Lunch Android

This Android app wraps `https://ghaslunch1.web.app/` in a WebView and handles notifications with native Firebase Cloud Messaging.

## Firebase setup

1. Open Firebase Console for project `ghaslunch1`.
2. Add an Android app with package name `kr.hs.ghas.ghason`.
3. Download `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. Open the `android` folder in Android Studio and sync Gradle.

## Notification behavior

- The website notification button calls the native bridge `GHASAndroidNotifications`.
- The app requests Android notification permission on Android 13+.
- When allowed, the app subscribes to the FCM topic `meal`.
- Send app notifications to topic `meal` from Firebase Console or a server using FCM.

The existing website browser notification flow still works in regular browsers.
