(function () {
    // UNUSED: Web FCM/Web Push is temporarily disabled for Android WebView.
    // Keep this module as a backup/reference for the planned Android native FCM
    // migration using FirebaseMessagingService.
    let notiTimer = null;
    let notiInterval = null;

    function getFirebaseConfig() {
        return window.FIREBASE_CONFIG;
    }

    function getFirebaseVapidKey() {
        return window.FIREBASE_VAPID_KEY;
    }

    function updateNotiButton() {
        const btn = document.getElementById('btn-noti');
        if (!btn) return;

        const enabled = localStorage.getItem('noti-enabled') === 'true';
        btn.classList.toggle('active', enabled);
        btn.textContent = enabled ? '🔕' : '🔔';
        btn.title = enabled ? '알림 취소' : '알림 설정';
        btn.setAttribute('aria-label', enabled ? '알림 취소' : '알림 설정');
    }

    async function toggleNoti() {
        if (localStorage.getItem('noti-enabled') === 'true') {
            await cancelNoti();
        } else {
            await requestNoti();
        }
    }

    async function requestNoti() {
        // Android WebView APK: native bridge subscribes the app to the FCM topic.
        if (window.GHASAndroidNotifications?.requestNotifications) {
            window.GHASAndroidNotifications.requestNotifications();
            alert('앱 알림 설정을 요청했습니다. 권한을 허용하면 앱 알림을 받을 수 있습니다.');
            return;
        }

        // Browser/PWA: web push token is created with Firebase Messaging.
        if (!('Notification' in window)) {
            alert('이 브라우저는 알림 기능을 지원하지 않습니다.');
            updateNotiButton();
            return;
        }

        if (!('serviceWorker' in navigator)) {
            alert('이 브라우저는 서비스 워커를 지원하지 않아 알림을 사용할 수 없습니다.');
            updateNotiButton();
            return;
        }

        const permission = await Notification.requestPermission();
        if (permission !== 'granted') {
            alert('알림 권한을 허용해야 알림을 받을 수 있습니다.');
            updateNotiButton();
            return;
        }

        try {
            if (typeof firebase === 'undefined') {
                throw new Error('Firebase 설정을 찾지 못했습니다.');
            }

            const firebaseConfig = getFirebaseConfig();
            if (!firebaseConfig) {
                throw new Error('Firebase 설정을 찾지 못했습니다.');
            }

            if (!firebase.apps.length) {
                firebase.initializeApp(firebaseConfig);
            }

            const messaging = firebase.messaging();
            const vapidKey = getFirebaseVapidKey();

            if (!vapidKey || vapidKey.includes('YOUR_')) {
                console.warn('VAPID 키가 설정되지 않았습니다.');
                localStorage.setItem('noti-enabled', 'true');
                updateNotiButton();
                alert('알림 권한은 허용되었지만 VAPID 키가 없어 로컬 알림 모드로 동작합니다.');
                scheduleDailyNotification();
                return;
            }

            const serviceWorkerRegistration = await navigator.serviceWorker.ready;
            const currentToken = await messaging.getToken({
                vapidKey,
                serviceWorkerRegistration
            });

            if (!currentToken) {
                alert('알림 토큰을 생성하지 못했습니다. 다시 시도해 주세요.');
                return;
            }

            localStorage.setItem('noti-enabled', 'true');
            updateNotiButton();

            alert('푸시 알림 설정이 완료되었습니다. 이제 실시간 알림을 받을 수 있습니다.');
        } catch (err) {
            console.error('FCM 설정 중 오류:', err);
            updateNotiButton();

            const message = err?.code === 'messaging/permission-blocked'
                ? '브라우저 알림 권한이 차단되어 있습니다. 사이트 권한에서 알림을 허용해 주세요.'
                : `알림 설정 중 오류가 발생했습니다: ${err.message}`;

            alert(message);
        }
    }

    async function cancelNoti() {
        // Android WebView APK: native bridge unsubscribes from the FCM topic.
        if (window.GHASAndroidNotifications?.cancelNotifications) {
            window.GHASAndroidNotifications.cancelNotifications();
            alert('앱 알림 취소를 요청했습니다.');
            return;
        }

        if (notiTimer) {
            clearTimeout(notiTimer);
            notiTimer = null;
        }
        if (notiInterval) {
            clearInterval(notiInterval);
            notiInterval = null;
        }

        localStorage.removeItem('noti-enabled');
        localStorage.removeItem('fcm-token');
        updateNotiButton();

        if (typeof firebase !== 'undefined') {
            try {
                const firebaseConfig = getFirebaseConfig();
                if (!firebaseConfig) {
                    throw new Error('Firebase 설정을 찾지 못했습니다.');
                }

                if (!firebase.apps.length) {
                    firebase.initializeApp(firebaseConfig);
                }

                const messaging = firebase.messaging();
                const vapidKey = getFirebaseVapidKey();

                if (vapidKey && !vapidKey.includes('YOUR_') && 'serviceWorker' in navigator) {
                    const serviceWorkerRegistration = await navigator.serviceWorker.ready;
                    const currentToken = await messaging.getToken({
                        vapidKey,
                        serviceWorkerRegistration
                    });

                    if (currentToken) {
                        try {
                            await messaging.deleteToken(currentToken);
                        } catch (tokenDeleteError) {
                            console.warn('FCM token delete skipped:', tokenDeleteError);
                        }
                    }
                }
            } catch (error) {
                console.warn('Notification cancel cleanup failed:', error);
            }
        }

        alert('알림이 취소되었습니다.');
    }

    function setNativeNotificationEnabled(enabled) {
        if (enabled) {
            localStorage.setItem('noti-enabled', 'true');
        } else {
            localStorage.removeItem('noti-enabled');
            localStorage.removeItem('fcm-token');
        }
        updateNotiButton();
    }

    function scheduleDailyNotification() {
        if (!('Notification' in window) || !('serviceWorker' in navigator)) return;
        if (localStorage.getItem('noti-enabled') !== 'true') return;

        if (notiTimer) clearTimeout(notiTimer);
        if (notiInterval) clearInterval(notiInterval);

        const now = new Date();
        const target = new Date();
        target.setHours(7, 30, 0, 0);

        if (now > target) {
            target.setDate(target.getDate() + 1);
        }

        const delay = target.getTime() - now.getTime();

        notiTimer = setTimeout(() => {
            showLocalNotification();
            notiInterval = setInterval(showLocalNotification, 24 * 60 * 60 * 1000);
        }, delay);
    }

    async function showLocalNotification() {
        if (!('Notification' in window) || !('serviceWorker' in navigator)) return;
        if (Notification.permission !== 'granted') return;

        const targetDate = new Date();
        const ymd = formatDate(targetDate);

        try {
            const data = await fetchMealData({ from: ymd, to: ymd, pSize: 100 });
            const rows = extractMealRows(data);

            if (rows.length === 0) return;

            let bodyText = '오늘의 맛있는 급식 정보를 확인해보세요! ';
            const lunch = rows.find(r => r.MMEAL_SC_CODE === '2');
            if (lunch) {
                const menu = normalizeMenuText(lunch.DDISH_NM).replace(/\n/g, ', ');
                bodyText = ` 오늘 중식: ${menu.slice(0, 60)}${menu.length > 60 ? '...' : ''}`;
            }

            const registration = await navigator.serviceWorker.ready;
            registration.showNotification('GHAS 오늘의 급식', {
                body: bodyText,
                icon: 'icon1.png',
                badge: 'icon1.png',
                vibrate: [200, 100, 200],
                tag: 'daily-meal'
            });
        } catch (e) {
            console.error("Failed to check meals for notification", e);
        }
    }

    function initForegroundMessaging() {
        // Browser/PWA foreground messages are shown here. Android native FCM is handled in the APK service.
        if (typeof firebase === 'undefined') {
            return;
        }

        try {
            const firebaseConfig = getFirebaseConfig();
            if (!firebaseConfig) {
                return;
            }

            if (!firebase.apps.length) {
                firebase.initializeApp(firebaseConfig);
            }

            const messaging = firebase.messaging();
            messaging.onMessage((payload) => {
                const title = payload?.notification?.title;
                const body = payload?.notification?.body;

                if (!title || !('Notification' in window) || Notification.permission !== 'granted') {
                    return;
                }

                new Notification(title, {
                    body: body || '',
                    icon: 'icon1.png'
                });
            });
        } catch (messagingError) {
            console.warn('Foreground messaging init skipped:', messagingError);
        }
    }

    function initNotificationControls() {
        const btn = document.getElementById('btn-noti');
        if (btn) {
            btn.addEventListener('click', toggleNoti);
        }

        updateNotiButton();

        if (localStorage.getItem('noti-enabled') === 'true') {
            scheduleDailyNotification();
        }

        initForegroundMessaging();
    }

    window.toggleNoti = toggleNoti;
    window.setNativeNotificationEnabled = setNativeNotificationEnabled;
    window.updateNotiButton = updateNotiButton;
    window.scheduleDailyNotification = scheduleDailyNotification;
    window.showLocalNotification = showLocalNotification;

    initNotificationControls();
})();
