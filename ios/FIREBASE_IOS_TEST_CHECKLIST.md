# Firebase iOS Push Checklist

## Current Status

- iOS push notifications are temporarily disabled.
- The app must not request iOS notification permission in the current build.
- The app must not write FCM/APNs token identifiers to Realtime Database.
- Realtime Database `tokens` and `notificationTokens` writes are blocked by rules.
- Push delivery will be revisited later through a native FCM/APNs implementation.

## Current Verification

- Launch the iOS app and confirm no notification permission prompt appears.
- Confirm the web notification button is hidden on the hosted WebView page.
- Confirm visitor count still reads and increments at `stats/visitCount`.
- Confirm meal, timetable, QR, theme, and privacy screens still work.

## Future Native FCM Reconnect

When push notifications are re-enabled:

- Register the iOS app in Firebase Console with bundle ID `com.ghas.lunch`.
- Add `GoogleService-Info.plist` to the app target.
- Configure APNs Auth Key or APNs certificate in Firebase Console.
- Add Push Notifications and Background Modes only when native push is ready.
- Add Firebase Messaging delegate handling.
- Store token identifiers only if rules are updated intentionally.
- Keep raw FCM/APNs tokens out of Realtime Database.
