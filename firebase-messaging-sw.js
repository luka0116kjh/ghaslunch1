importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

const FIREBASE_CONFIG = {
    apiKey: "AIzaSyDuqKOq-5dRC8dClv7fRBULA0lows-RHUg",
    authDomain: "ghaslunch1.firebaseapp.com",
    databaseURL: "https://ghaslunch1-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "ghaslunch1",
    storageBucket: "ghaslunch1.firebasestorage.app",
    messagingSenderId: "348512527529",
    appId: "1:348512527529:web:fee72bc56b6a44bfda75b8"
};

if (typeof firebase !== 'undefined') {
    firebase.initializeApp({
        apiKey: FIREBASE_CONFIG.apiKey,
        authDomain: FIREBASE_CONFIG.authDomain,
        databaseURL: FIREBASE_CONFIG.databaseURL,
        projectId: FIREBASE_CONFIG.projectId,
        storageBucket: FIREBASE_CONFIG.storageBucket,
        messagingSenderId: FIREBASE_CONFIG.messagingSenderId,
        appId: FIREBASE_CONFIG.appId
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
