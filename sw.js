const CACHE_NAME = 'ghas-lunch-v4';
const ASSETS = [
    './',
    './index.html',
    './script.js',
    './config.js',
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
        })
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request).then((response) => response || fetch(event.request))
    );
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
        clients.openWindow('./')
    );
});
