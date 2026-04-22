const CACHE_NAME = 'ghas-lunch-v8';
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
    // API 요청이나 외부 도메인 요청이 아닌 기본 에셋 요청에 대해서만 캐시 업데이트 (Stale-While-Revalidate)
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
                // 오프라인 상태 등 네트워크 실패 시 아무것도 하지 않음 (기존 캐시를 반환하게 됨)
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
