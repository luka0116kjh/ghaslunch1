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

const CACHE_NAME = 'ghas-lunch-v15';
const ASSETS = [
    './',
    './index.html',
    './script.js',
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

    if (['/config.js', '/sw.js', '/firebase-messaging-sw.js'].includes(requestUrl.pathname)) {
        event.respondWith(fetch(event.request));
        return;
    }

    // 같은 출처의 기본 에셋 요청에 대해서만 캐시 업데이트 (Stale-While-Revalidate)
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
