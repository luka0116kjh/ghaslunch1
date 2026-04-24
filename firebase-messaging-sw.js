importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');
importScripts('config.js');

if (typeof firebase !== 'undefined' && typeof CONFIG !== 'undefined') {
    firebase.initializeApp({
        apiKey: CONFIG.FIREBASE.API_KEY,
        authDomain: CONFIG.FIREBASE.AUTH_DOMAIN,
        databaseURL: CONFIG.FIREBASE.DATABASE_URL,
        projectId: CONFIG.FIREBASE.PROJECT_ID,
        storageBucket: CONFIG.FIREBASE.STORAGE_BUCKET,
        messagingSenderId: CONFIG.FIREBASE.MESSAGING_SENDER_ID,
        appId: CONFIG.FIREBASE.APP_ID
    });

    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
        const notificationTitle = payload.notification?.title || 'GHAS 오늘의 급식';
        const notificationOptions = {
            body: payload.notification?.body || '',
            icon: payload.notification?.image || 'icon1.png',
            badge: 'icon1.png',
            data: payload.data || {}
        };

        self.registration.showNotification(notificationTitle, notificationOptions);
    });
}

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(clients.openWindow('./'));
});
