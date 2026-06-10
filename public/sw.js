// Web FCM/Web Push is temporarily disabled because Android WebView push handling
// is being moved to native FirebaseMessagingService-based FCM.
// Keep this service worker focused on app shell caching only.

const CACHE_PREFIX = 'ghas-lunch-';
const CACHE_NAME = 'ghas-lunch-v44';
const ASSETS = [
    './',
    './index.html',
    './schedule.js',
    './afterschoolScheduleData.js',
    './script.js',
    './afterschool.js',
    './style.css',
    './src/data/classTimetable2026.js',
    './icon-192.png',
    './icon1.png',
    './favicon.png',
    './apple-touch-icon.png',
    './manifest.json'
];
const NETWORK_FIRST_PATHS = [
    '/',
    '/index.html',
    '/schedule.js',
    '/afterschoolScheduleData.js',
    '/script.js',
    '/afterschool.js',
    '/style.css',
    '/privacy-theme.js',
    '/manifest.json',
    '/src/data/classTimetable2026.js'
];
const BYPASS_CACHE_PATHS = ['/sw.js', '/firebase-messaging-sw.js', '/notification.js'];

function cacheSuccessfulResponse(request, response) {
    if (response && response.status === 200 && response.type === 'basic') {
        const responseToCache = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
        });
    }
}

function networkFirst(request) {
    return fetch(request).then((networkResponse) => {
        cacheSuccessfulResponse(request, networkResponse);
        return networkResponse;
    }).catch(() => caches.match(request).then((cachedResponse) => {
        if (cachedResponse) return cachedResponse;
        if (request.mode === 'navigate') return caches.match('./index.html');
        return Response.error();
    }));
}

function staleWhileRevalidate(request) {
    return caches.match(request).then((cachedResponse) => {
        const fetchPromise = fetch(request).then((networkResponse) => {
            cacheSuccessfulResponse(request, networkResponse);
            return networkResponse;
        }).catch(() => {
            if (request.mode === 'navigate') {
                return caches.match('./index.html');
            }
            return cachedResponse || Response.error();
        });

        return cachedResponse || fetchPromise;
    });
}

self.addEventListener('install', (event) => {
    self.skipWaiting(); // 새 서비스 워커가 대기하지 않고 즉시 활성화되도록 함
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
});

self.addEventListener('activate', (event) => {
    // 이전 GHAS 앱 캐시만 삭제하고 다른 출처/라이브러리 캐시는 건드리지 않는다.
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName.startsWith(CACHE_PREFIX) && cacheName !== CACHE_NAME) {
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

    if (BYPASS_CACHE_PATHS.includes(requestUrl.pathname)) {
        event.respondWith(fetch(event.request));
        return;
    }

    // HTML과 앱 실행에 필요한 핵심 에셋은 네트워크 우선으로 갱신한다.
    if (event.request.mode === 'navigate' || NETWORK_FIRST_PATHS.includes(requestUrl.pathname)) {
        event.respondWith(networkFirst(event.request));
        return;
    }

    event.respondWith(staleWhileRevalidate(event.request));
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
        clients.openWindow('./')
    );
});
