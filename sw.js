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

    // 백그라운드 메시지 처리
    messaging.onBackgroundMessage((payload) => {
        const notificationTitle = payload.notification.title;
        const notificationOptions = {
            body: payload.notification.body,
            icon: payload.notification.image || 'icon1.png',
            badge: 'icon1.png',
            data: payload.data
        };

        self.registration.showNotification(notificationTitle, notificationOptions);
    });
}

const CACHE_NAME = 'ghas-lunch-v34';
const ASSETS = [
    './',
    './index.html',
    './schedule.js',
    './script.js',
    './icon-192.png',
    './icon1.png',
    './logo.svg',
    './manifest.json'
];

self.addEventListener('install', (event) => {
    self.skipWaiting(); // 새 서비스 워커가 대기하지 않고 즉시 활성화되도록 함
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
});

self.addEventListener('activate', (event) => {
    // 이전 버전의 캐시 삭제
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        return caches.delete(cacheName);
                    }
                })
            );
        }).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET') {
        return;
    }

    const requestUrl = new URL(event.request.url);
    if (requestUrl.origin !== self.location.origin) {
        return;
    }

    if (['/sw.js', '/firebase-messaging-sw.js'].includes(requestUrl.pathname)) {
        event.respondWith(fetch(event.request));
        return;
    }

    // 같은 출처의 기본 에셋 요청에 대해서만 캐시 업데이트 (Stale-While-Revalidate)
    if (
        event.request.mode === 'navigate' ||
        ['/index.html', '/schedule.js', '/script.js', '/privacy-theme.js', '/manifest.json'].includes(requestUrl.pathname)
    ) {
        event.respondWith(
            fetch(event.request).then((networkResponse) => {
                if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
                    const responseToCache = networkResponse.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(event.request, responseToCache);
                    });
                }
                return networkResponse;
            }).catch(() => caches.match(event.request).then((cachedResponse) => {
                if (cachedResponse) return cachedResponse;
                if (event.request.mode === 'navigate') return caches.match('./index.html');
                return Response.error();
            }))
        );
        return;
    }

    event.respondWith(
        caches.match(event.request).then((cachedResponse) => {
            const fetchPromise = fetch(event.request).then((networkResponse) => {
                // 정상적인 응답이면서 같은 출처(basic)의 요청만 캐시에 업데이트
                if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
                    const responseToCache = networkResponse.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(event.request, responseToCache);
                    });
                }
                return networkResponse;
            }).catch(() => {
                if (event.request.mode === 'navigate') {
                    return caches.match('./index.html');
                }
                return cachedResponse || Response.error();
            });

            // 캐시에 있으면 즉시 반환하고 백그라운드에서 캐시 업데이트
            // 캐시에 없으면 네트워크 응답을 기다림
            return cachedResponse || fetchPromise;
        })
    );
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
        clients.openWindow('./')
    );
});
