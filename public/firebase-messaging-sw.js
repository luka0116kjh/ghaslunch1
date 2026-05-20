// Web FCM/Web Push is temporarily disabled for the Android WebView APK.
// This file is intentionally kept as an unused/no-op service worker placeholder
// so it can be reconnected later when notifications move to Android native FCM
// through FirebaseMessagingService.

self.addEventListener('install', () => {
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});
