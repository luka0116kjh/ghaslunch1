# Firebase iOS Notification Checklist

## Current Status

- iOS remote push notifications remain disabled.
- The native notification settings sheet may request permission for on-device repeating local notifications.
- The app must not write FCM/APNs token identifiers to Realtime Database.
- Realtime Database `tokens` and `notificationTokens` writes are blocked by rules.
- Remote push delivery will be revisited later through a native FCM/APNs implementation.

## Current Verification

- Launch the iOS app and confirm permission is requested only after enabling notifications in the native settings sheet.
- Confirm meal, timetable, and school notice local notification schedules can be enabled, disabled, and rescheduled.
- Confirm disabling all notifications removes pending local notification requests.
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
