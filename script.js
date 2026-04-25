function formatDate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}

function formatDateWithOffset(unixSeconds, timezoneOffsetSeconds) {
    const shifted = new Date((unixSeconds + timezoneOffsetSeconds) * 1000);
    const y = shifted.getUTCFullYear();
    const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
    const d = String(shifted.getUTCDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}

function hourWithOffset(unixSeconds, timezoneOffsetSeconds) {
    const shifted = new Date((unixSeconds + timezoneOffsetSeconds) * 1000);
    return shifted.getUTCHours();
}

function setText(id, value) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = value;
}

function showOfflineUI(isOffline) {
    const offlineContainer = document.getElementById('offline-container');
    const mealContainer = document.getElementById('meal-container');
    const timetableContainer = document.getElementById('timetable-container');
    const weatherInfo = document.getElementById('weather-info');

    if (isOffline) {
        if (mealContainer) mealContainer.style.display = 'none';
        if (timetableContainer) timetableContainer.style.display = 'none';
        if (offlineContainer) offlineContainer.style.display = 'flex';
        if (weatherInfo) weatherInfo.textContent = '오프라인 (네트워크 끊김)';
    } else {
        if (offlineContainer) offlineContainer.style.display = 'none';
    }
}

window.addEventListener('online', () => {
    showOfflineUI(false);
    const activeBtn = document.querySelector('.btn-group button.active');
    if (activeBtn && activeBtn.id === 'btn-timetable') showTimetable();
    else if (activeBtn && activeBtn.id === 'btn-week') showMeals('week');
    else if (activeBtn && activeBtn.id === 'btn-tomorrow') showMeals('tomorrow');
    else showMeals('today');
});

window.addEventListener('offline', () => {
    showOfflineUI(true);
});

function getWeatherConfig() {
    const weatherConfig = (typeof CONFIG !== 'undefined' && CONFIG.WEATHER) ? CONFIG.WEATHER : {};
    return {
        proxyUrl: weatherConfig.PROXY_URL || '',
        apiKey: weatherConfig.API_KEY || '',
        lat: weatherConfig.LAT,
        lon: weatherConfig.LON,
        cityName: weatherConfig.CITY_NAME || ''
    };
}

async function fetchWeather(targetDate) {
    setText('weather-info', '날씨 정보를 불러오는 중...');

    const { proxyUrl, apiKey, lat, lon, cityName } = getWeatherConfig();

    if (typeof lat !== 'number' || typeof lon !== 'number') {
        setText('weather-info', '날씨 좌표(lat/lon)가 설정되지 않았습니다.');
        return;
    }

    const targetYmd = formatDate(targetDate);
    const hasProxy = Boolean(proxyUrl) && !proxyUrl.includes('YOUR_WORKER_SUBDOMAIN');
    const hasValidApiKey = apiKey && apiKey !== '1' && !apiKey.includes('YOUR_');

    try {
        let weatherData = null;
        let place = cityName;

        if (hasProxy || hasValidApiKey) {
            let url = '';
            if (hasProxy) {
                const baseUrl = proxyUrl.replace(/\/+$/, '');
                url = `${baseUrl}?lat=${lat}&lon=${lon}&units=metric&lang=kr`;
            } else {
                url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;
            }

            const response = await fetch(url);
            if (response.ok) {
                const data = await response.json();
                if (Array.isArray(data.list) && data.list.length > 0) {
                    const timezoneOffset = typeof data.city?.timezone === 'number' ? data.city.timezone : 0;
                    const sameDayForecasts = data.list.filter((item) => formatDateWithOffset(item.dt, timezoneOffset) === targetYmd);
                    const source = sameDayForecasts.length > 0 ? sameDayForecasts : data.list;
                    const picked = source.slice().sort((a, b) => {
                        const aDiff = Math.abs(hourWithOffset(a.dt, timezoneOffset) - 12);
                        const bDiff = Math.abs(hourWithOffset(b.dt, timezoneOffset) - 12);
                        return aDiff - bDiff;
                    })[0];

                    weatherData = {
                        temp: Math.round(picked.main.temp),
                        description: picked.weather?.[0]?.description,
                        pop: Math.round((picked.pop || 0) * 100)
                    };
                    if (!place) place = data.city?.name;
                }
            }
        }

        if (!weatherData) {
            const isoDate = `${targetYmd.slice(0, 4)}-${targetYmd.slice(4, 6)}-${targetYmd.slice(6, 8)}`;
            const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,weathercode,precipitation_probability&timezone=Asia%2FSeoul&start_date=${isoDate}&end_date=${isoDate}`;
            const response = await fetch(url);
            if (!response.ok) throw new Error('Weather API fallback failed');

            const data = await response.json();
            if (data.hourly && data.hourly.time) {
                const middayIndex = data.hourly.time.findIndex((time) => time.includes('T12:00'));
                const hourIndex = middayIndex >= 0 ? middayIndex : Math.min(12, data.hourly.time.length - 1);
                const code = data.hourly.weathercode[hourIndex];
                const weatherMap = {
                    0: '맑음',
                    1: '대체로 맑음',
                    2: '부분적으로 흐림',
                    3: '흐림',
                    45: '안개',
                    48: '서리 안개',
                    51: '가벼운 이슬비',
                    53: '이슬비',
                    55: '진한 이슬비',
                    61: '약한 비',
                    63: '보통 비',
                    65: '강한 비',
                    71: '약한 눈',
                    73: '보통 눈',
                    75: '강한 눈',
                    77: '눈알갱이',
                    80: '약한 소나기',
                    81: '보통 소나기',
                    82: '강한 소나기',
                    85: '약한 눈 소나기',
                    86: '강한 눈 소나기',
                    95: '뇌우',
                    96: '뇌우와 약한 우박',
                    99: '뇌우와 강한 우박'
                };

                weatherData = {
                    temp: Math.round(data.hourly.temperature_2m[hourIndex]),
                    description: weatherMap[code] || '날씨 정보 없음',
                    pop: data.hourly.precipitation_probability[hourIndex]
                };
            }
        }

        if (!weatherData) {
            throw new Error('No weather data available');
        }

        const { temp, description, pop } = weatherData;
        const tempText = `${temp}°C`;
        const popText = typeof pop === 'number' ? `강수확률 ${pop}%` : '';
        const weatherLine = [tempText, description, popText].filter(Boolean).join(' | ');
        setText('weather-info', place ? `${weatherLine} (${place})` : weatherLine);
    } catch (error) {
        console.error('Weather load failed:', error);
        if (!navigator.onLine) {
            showOfflineUI(true);
            return;
        }
        setText('weather-info', '날씨 정보를 불러오지 못했습니다. 지역/좌표를 확인해주세요.');
    }
}

function escapeHTML(str) {
    if (!str) return "";
    return str.replace(/[&<>"']/g, function (m) {
        return {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }[m];
    });
}

function normalizeMenuText(rawMenu) {
    // 1. 브라켓() 내용 제거 및 <br> 태그를 공백으로 치환
    let clean = (rawMenu || '')
        .replace(/\([^)]*\)/g, '')
        .replace(/<br\s*\/?>/gi, ' ');

    // 2. 모든 종류의 공백(스페이스, 엔터, 탭 등)을 기준으로 나누고, 빈칸을 제거한 뒤 딱 한 번의 줄바꿈(\n)으로 연결
    return clean.split(/\s+/).filter(Boolean).join('\n');
}

function extractMealRows(data) {
    const mealInfo = Array.isArray(data.mealServiceDietInfo)
        ? data.mealServiceDietInfo.find(section => Array.isArray(section.row))
        : null;
    return mealInfo?.row || [];
}

async function fetchMeals(targetDate) {
    const ymd = formatDate(targetDate);
    const dateStr = targetDate.toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        weekday: 'long'
    });

    setText('today-date', dateStr);
    setText('lunch-menu', '데이터를 불러오는 중...');
    setText('dinner-menu', '데이터를 불러오는 중...');
    setText('lunch-cal', '');
    setText('dinner-cal', '');

    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';
    let url = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_YMD=${ymd}&pSize=100`;
    if (apiKey) {
        url += `&KEY=${apiKey}`;
    }

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error('NEIS API 응답 오류');

        const data = await response.json();
        const rows = extractMealRows(data);

        setText('lunch-menu', '정보가 없습니다.');
        setText('dinner-menu', '정보가 없습니다.');

        rows.forEach(row => {
            const cleanMenu = normalizeMenuText(row.DDISH_NM);
            if (row.MMEAL_SC_CODE === '2') {
                const lunchEl = document.getElementById('lunch-menu');
                if (lunchEl) lunchEl.innerHTML = escapeHTML(cleanMenu || '정보가 없습니다.').replace(/\n/g, '<br>');
                setText('lunch-cal', row.CAL_INFO || '');
            } else if (row.MMEAL_SC_CODE === '3') {
                const dinnerEl = document.getElementById('dinner-menu');
                if (dinnerEl) dinnerEl.innerHTML = escapeHTML(cleanMenu || '정보가 없습니다.').replace(/\n/g, '<br>');
                setText('dinner-cal', row.CAL_INFO || '');
            }
        });

    } catch (error) {
        console.error('Meal load failed:', error);
        if (!navigator.onLine) {
            showOfflineUI(true);
            return;
        }
        const msg = '급식 정보를 불러오지 못했습니다.';
        setText('lunch-menu', msg);
        setText('dinner-menu', msg);
    }
}

function getMonday(date) {
    const monday = new Date(date);
    const day = monday.getDay(); // 0: Sunday, 1: Monday, ..., 6: Saturday
    const diff = day === 0 ? -6 : 1 - day;
    monday.setDate(monday.getDate() + diff);
    monday.setHours(0, 0, 0, 0);
    return monday;
}

function formatMonthDay(date) {
    return `${date.getMonth() + 1}/${date.getDate()}`;
}

function buildMealTextByWeek(mealMap, mealCode, monday) {
    const lines = [];
    for (let i = 0; i < 5; i += 1) {
        const date = new Date(monday);
        date.setDate(monday.getDate() + i);
        const ymd = formatDate(date);
        const weekday = date.toLocaleDateString('ko-KR', { weekday: 'short' });
        const menu = escapeHTML(mealMap[ymd]?.[mealCode] || '정보가 없습니다.').replace(/\n/g, '<br>');
        lines.push(`
            <div style="margin-bottom: 20px; padding-bottom: 12px; border-bottom: 1px solid var(--border-color);">
                <div style="font-weight: 800; color: var(--primary-color); font-size: 14px; margin-bottom: 6px;">
                    ${formatMonthDay(date)} (${weekday})
                </div>
                <div style="line-height: 1.6; font-size: 15px;">${menu}</div>
            </div>
        `);
    }
    return lines.join('');
}

async function showWeeklyMeals(baseDate) {
    const weekBaseDate = new Date(baseDate);
    const dayOfWeek = weekBaseDate.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    if (dayOfWeek === 6) weekBaseDate.setDate(weekBaseDate.getDate() + 2);
    if (dayOfWeek === 0) weekBaseDate.setDate(weekBaseDate.getDate() + 1);

    const monday = getMonday(weekBaseDate);
    const friday = new Date(monday);
    friday.setDate(monday.getDate() + 4);
    const weekLabel = isWeekend ? '다음 주' : '이번 주';

    document.getElementById('meal-container').style.display = 'block';
    document.getElementById('timetable-container').style.display = 'none';
    document.getElementById('btn-today').classList.remove('active');
    if (document.getElementById('btn-tomorrow')) document.getElementById('btn-tomorrow').classList.remove('active');
    document.getElementById('btn-week').classList.add('active');
    if (document.getElementById('btn-timetable')) document.getElementById('btn-timetable').classList.remove('active');
    setText('lunch-title', `${weekLabel} 중식`);
    setText('dinner-title', `${weekLabel} 석식`);
    setText('today-date', `${formatMonthDay(monday)} ~ ${formatMonthDay(friday)}`);
    setText('weather-info', `${weekLabel} 모드에서는 날씨를 표시하지 않습니다.`);
    setText('lunch-menu', '데이터를 불러오는 중...');
    setText('dinner-menu', '데이터를 불러오는 중...');
    setText('lunch-cal', '');
    setText('dinner-cal', '');

    const fromYmd = formatDate(monday);
    const toYmd = formatDate(friday);
    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';

    async function fetchMealByCode(code) {
        let url = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_FROM_YMD=${fromYmd}&MLSV_TO_YMD=${toYmd}&MMEAL_SC_CODE=${code}&pSize=50`;
        if (apiKey) url += `&KEY=${apiKey}`;

        try {
            const response = await fetch(url);
            const data = await response.json();
            const rows = extractMealRows(data);
            const map = {};
            rows.forEach((row) => {
                map[row.MLSV_YMD] = normalizeMenuText(row.DDISH_NM);
            });
            return map;
        } catch (error) {
            console.error(`Weekly Fetch Error (Code ${code}):`, error);
            return null;
        }
    }

    try {
        const [lunchData, dinnerData] = await Promise.all([
            fetchMealByCode('2'),
            fetchMealByCode('3')
        ]);

        const mealMap = {};
        if (lunchData) {
            Object.entries(lunchData).forEach(([ymd, menu]) => {
                if (!mealMap[ymd]) mealMap[ymd] = {};
                mealMap[ymd]['2'] = menu;
            });
        }
        if (dinnerData) {
            Object.entries(dinnerData).forEach(([ymd, menu]) => {
                if (!mealMap[ymd]) mealMap[ymd] = {};
                mealMap[ymd]['3'] = menu;
            });
        }

        const lunchListEl = document.getElementById('lunch-menu');
        const dinnerListEl = document.getElementById('dinner-menu');

        if (lunchListEl) lunchListEl.innerHTML = buildMealTextByWeek(mealMap, '2', monday);
        if (dinnerListEl) dinnerListEl.innerHTML = buildMealTextByWeek(mealMap, '3', monday);
    } catch (error) {
        console.error('Weekly meal load failed:', error);
        if (!navigator.onLine) {
            showOfflineUI(true);
            return;
        }
        const msg = '급식 정보를 불러오지 못했습니다.';
        setText('lunch-menu', msg);
        setText('dinner-menu', msg);
    }
}

// 공유하기 기능 (나중에 스토어 등록 시 주소를 업데이트 하세요)
async function shareApp() {
    const storeUrl = 'https://ghaslunch1.web.app'; // 나중에 구글 플레이 스토어 주소로 변경하세요.
    const shareData = {
        title: 'GHAS 오늘의 급식',
        text: '경기자동차과학고등학교 급식 및 시간표 확인 앱!',
        url: storeUrl
    };

    try {
        if (navigator.share) {
            await navigator.share(shareData);
        } else {
            // Web Share API 미지원 시 클립보드 복사
            await navigator.clipboard.writeText(storeUrl);
            alert('앱 링크가 클립보드에 복사되었습니다. 필요한 곳에 붙여넣어 공유하세요!');
        }
    } catch (err) {
        console.error('공유 실패:', err);
    }
}

function showMeals(type) {
    if (!navigator.onLine) {
        showOfflineUI(true);
        return;
    }
    showOfflineUI(false);

    const targetDate = new Date();

    if (type === 'tomorrow') {
        targetDate.setDate(targetDate.getDate() + 1);
    }

    if (type === 'week') {
        showWeeklyMeals(new Date());
    } else {
        document.getElementById('meal-container').style.display = 'block';
        document.getElementById('timetable-container').style.display = 'none';

        const btnToday = document.getElementById('btn-today');
        const btnTomorrow = document.getElementById('btn-tomorrow');
        const btnWeek = document.getElementById('btn-week');
        const btnTimetable = document.getElementById('btn-timetable');

        if (btnToday) btnToday.classList.toggle('active', type === 'today');
        if (btnTomorrow) btnTomorrow.classList.toggle('active', type === 'tomorrow');
        if (btnWeek) btnWeek.classList.toggle('active', false);
        if (btnTimetable) btnTimetable.classList.toggle('active', false);

        // 타이틀 접두사 제거 (카카오 스타일은 심플함이 생명)
        setText('lunch-title', `중식`);
        setText('dinner-title', `석식`);

        fetchMeals(targetDate);
        fetchWeather(targetDate);
    }
}

let notiTimer = null;
let notiInterval = null;

async function requestNoti() {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
        alert('알림 권한을 허용해야 알림을 받을 수 있습니다.');
        return;
    }

    try {
        if (typeof firebase === 'undefined' || typeof CONFIG === 'undefined' || !CONFIG.FIREBASE) {
            throw new Error('Firebase 설정을 찾지 못했습니다.');
        }

        if (!firebase.apps.length) {
            firebase.initializeApp({
                apiKey: CONFIG.FIREBASE.API_KEY,
                authDomain: CONFIG.FIREBASE.AUTH_DOMAIN,
                databaseURL: CONFIG.FIREBASE.DATABASE_URL,
                projectId: CONFIG.FIREBASE.PROJECT_ID,
                storageBucket: CONFIG.FIREBASE.STORAGE_BUCKET,
                messagingSenderId: CONFIG.FIREBASE.MESSAGING_SENDER_ID,
                appId: CONFIG.FIREBASE.APP_ID
            });
        }

        const messaging = firebase.messaging();
        const vapidKey = CONFIG.FIREBASE.VAPID_KEY;

        if (!vapidKey || vapidKey.includes('YOUR_')) {
            console.warn('VAPID 키가 설정되지 않았습니다. config.js에서 설정이 필요합니다.');
            localStorage.setItem('noti-enabled', 'true');
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

        console.log('FCM Token:', currentToken);
        localStorage.setItem('noti-enabled', 'true');
        localStorage.setItem('fcm-token', currentToken);

        try {
            const db = firebase.database();
            const tokenRef = db.ref('tokens/' + currentToken.replace(/\W/g, '_'));
            await tokenRef.set({
                lastUpdated: firebase.database.ServerValue.TIMESTAMP,
                platform: 'web'
            });
        } catch (tokenSaveError) {
            console.warn('FCM token save failed:', tokenSaveError);
        }

        alert('푸시 알림 설정이 완료되었습니다. 이제 실시간 알림을 받을 수 있습니다.');
    } catch (err) {
        console.error('FCM 설정 중 오류:', err);

        const message = err?.code === 'messaging/permission-blocked'
            ? '브라우저 알림 권한이 차단되어 있습니다. 사이트 권한에서 알림을 허용해 주세요.'
            : `알림 설정 중 오류가 발생했습니다: ${err.message}`;

        alert(message);
    }
}

function scheduleDailyNotification() {
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
    if (Notification.permission !== 'granted') return;

    const targetDate = new Date();
    const ymd = formatDate(targetDate);
    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';
    let url = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_YMD=${ymd}`;
    if (apiKey) url += `&KEY=${apiKey}`;

    try {
        const response = await fetch(url);
        const data = await response.json();
        const rows = extractMealRows(data);

        if (rows.length === 0) {
            console.log("No meals today, skipping notification.");
            return;
        }

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

// 과목명 매핑 딕셔너리 
const SUBJECT_ALIASES = {
    "공통국어1": "국어",
    "공통국어2": "국어",
    "문학": "국어",
    "화법과 언어": "국어",
    "공통수학1": "수학",
    "공통수학2": "수학",
    "대수": "수학",
    "미적분Ⅰ": "수학",
    "공통영어1": "영어",
    "공통영어2": "영어",
    "영어Ⅰ": "영어",
    "영어Ⅱ": "영어",
    "직무 영어": "영어",
    "한국사1": "한국사",
    "한국사2": "한국사",
    "통합사회1": "사회",
    "통합사회2": "사회",
    "통합과학1": "과학",
    "통합과학2": "과학",
    "체육1": "체육",
    "체육2": "체육",
    "진로활동": "진로",
    "동아리활동": "동아리",
    "창의적 체험활동": "창체",
    "정보 처리와 관리": "정보 처리",
    "SSQL": "SQL",
    "베이스·클리어 도장 작업": "자동차도장",
    "자동차 등화장치 정비": "자동차정비"
};

function decodeSubject(rawName) {
    if (!rawName) return "공강";
    const trimmed = rawName.trim();
    // 딕셔너리에 매핑된 값이 있으면 그 값을, 없으면 원본을 그대로 반환
    return SUBJECT_ALIASES[trimmed] || trimmed;
}

async function fetchTimetable(grade, classNum, targetDate) {
    const ymd = formatDate(targetDate);
    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';

    let url = `https://open.neis.go.kr/hub/hisTimetable?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&GRADE=${grade}&CLASS_NM=${classNum}&ALL_TI_YMD=${ymd}&pSize=100`;
    if (apiKey) url += `&KEY=${apiKey}`;

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (data.hisTimetable) {
            const rows = data.hisTimetable[1].row;

            const uniqueRows = [];
            const seenPeriods = new Set();

            rows.forEach(row => {
                if (!seenPeriods.has(row.PERIO)) {
                    seenPeriods.add(row.PERIO);
                    uniqueRows.push({
                        period: row.PERIO,                 // 교시
                        originalSubject: row.ITRT_CNTNT,   // API 원본 과목명
                        subject: decodeSubject(row.ITRT_CNTNT) // 변환된 친숙한 과목명
                    });
                }
            });

            return uniqueRows.sort((a, b) => a.period - b.period);
        } else {
            return [];
        }
    } catch (e) {
        console.error('Timetable Fetch Error:', e);
        if (!navigator.onLine) {
            showOfflineUI(true);
        }
        return null;
    }
}


function getCurrentSchoolDate(baseDate = new Date()) {
    const currentDate = new Date(baseDate);
    const day = currentDate.getDay();

    if (day === 6) currentDate.setDate(currentDate.getDate() + 2);
    else if (day === 0) currentDate.setDate(currentDate.getDate() + 1);

    return currentDate;
}

function getNextSchoolDate(baseDate) {
    const nextDate = new Date(baseDate);
    nextDate.setDate(nextDate.getDate() + 1);

    while (nextDate.getDay() === 0 || nextDate.getDay() === 6) {
        nextDate.setDate(nextDate.getDate() + 1);
    }

    return nextDate;
}

function isNextCalendarDay(baseDate, targetDate) {
    const start = new Date(baseDate);
    const end = new Date(targetDate);
    start.setHours(0, 0, 0, 0);
    end.setHours(0, 0, 0, 0);
    return end.getTime() - start.getTime() === 24 * 60 * 60 * 1000;
}

function formatTimetableDateLabel(targetDate) {
    const weekdays = ['\uC77C', '\uC6D4', '\uD654', '\uC218', '\uBAA9', '\uAE08', '\uD1A0'];
    return `${targetDate.getMonth() + 1}/${targetDate.getDate()} (${weekdays[targetDate.getDay()]})`;
}

function renderTimetableSection(title, targetDate, rows) {
    if (rows === null) {
        return `
            <div class="timetable-section">
                <div class="timetable-subtitle">
                    <span>${title}</span>
                    <span class="timetable-date-label">${formatTimetableDateLabel(targetDate)}</span>
                </div>
                <div class="timetable-empty">\uB370\uC774\uD130\uB97C \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.</div>
            </div>
        `;
    }

    const normalizedRows = applyFridayFreePeriods(rows, targetDate);
    const content = normalizedRows.length === 0
        ? `<div class="timetable-empty">\uC2DC\uAC04\uD45C \uC815\uBCF4\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.</div>`
        : normalizedRows.map(row => `
            <div class="timetable-row">
                <span class="period">${row.period}\uAD50\uC2DC</span>
                <span class="subject">${escapeHTML(row.subject)}</span>
            </div>
        `).join('');

    return `
        <div class="timetable-section">
            <div class="timetable-subtitle">
                <span>${title}</span>
                <span class="timetable-date-label">${formatTimetableDateLabel(targetDate)}</span>
            </div>
            ${content}
        </div>
    `;
}

let timetableViewMode = 'current';

function ensureTimetableControls() {
    const list = document.getElementById('timetable-list');
    if (!list || document.getElementById('btn-timetable-switch')) {
        return;
    }

    const card = list.closest('.meal-card');
    if (!card) {
        return;
    }

    const toolbar = document.createElement('div');
    toolbar.className = 'timetable-toolbar';

    const title = document.createElement('div');
    title.id = 'timetable-title';
    title.className = 'meal-type';

    const button = document.createElement('button');
    button.id = 'btn-timetable-switch';
    button.className = 'timetable-switch-btn';
    button.type = 'button';
    button.addEventListener('click', toggleTimetableView);

    toolbar.append(title, button);

    const meta = document.createElement('div');
    meta.id = 'timetable-date-label';
    meta.className = 'timetable-meta';

    card.insertBefore(toolbar, list);
    card.insertBefore(meta, list);
}

function renderTimetableRows(rows, targetDate) {
    if (rows === null) {
        return '<div class="timetable-empty">데이터를 불러오지 못했습니다.</div>';
    }

    const normalizedRows = applyFridayFreePeriods(rows, targetDate);
    if (normalizedRows.length === 0) {
        return '<div class="timetable-empty">시간표 정보가 없습니다.</div>';
    }

    return normalizedRows.map(row => `
        <div class="timetable-row">
            <span class="period">${row.period}교시</span>
            <span class="subject">${escapeHTML(row.subject)}</span>
        </div>
    `).join('');
}

function updateTimetableHeader(titleText, targetDate, nextButtonText) {
    const titleEl = document.getElementById('timetable-title');
    const dateEl = document.getElementById('timetable-date-label');
    const buttonEl = document.getElementById('btn-timetable-switch');

    if (titleEl) titleEl.textContent = titleText;
    if (dateEl) dateEl.textContent = formatTimetableDateLabel(targetDate);
    if (buttonEl) buttonEl.textContent = nextButtonText;
}

function getTimetableLabel(referenceDate, targetDate, fallbackLabel = '다음 시간표') {
    const reference = new Date(referenceDate);
    const target = new Date(targetDate);
    reference.setHours(0, 0, 0, 0);
    target.setHours(0, 0, 0, 0);

    const diffDays = Math.round((target.getTime() - reference.getTime()) / (24 * 60 * 60 * 1000));
    if (diffDays === 0) return '오늘 시간표';
    if (diffDays === 1) return '내일 시간표';
    return fallbackLabel;
}

function toggleTimetableView() {
    timetableViewMode = timetableViewMode === 'current' ? 'next' : 'current';
    updateTimetable();
}

async function updateTimetable() {
    const grade = document.getElementById('grade-select').value;
    const classNum = document.getElementById('class-select').value;
    const container = document.getElementById('timetable-list');

    localStorage.setItem('ghas-grade', grade);
    localStorage.setItem('ghas-class', classNum);

    ensureTimetableControls();
    container.innerHTML = '시간표를 불러오는 중...';

    const today = new Date();
    const currentDate = getCurrentSchoolDate(today);
    const nextDate = getNextSchoolDate(currentDate);
    const showNext = timetableViewMode === 'next';
    const targetDate = showNext ? nextDate : currentDate;
    const currentTitle = getTimetableLabel(today, currentDate, '다음 시간표');
    const nextTitle = getTimetableLabel(
        today,
        nextDate,
        currentTitle === '다음 시간표' ? '그다음 시간표' : '다음 시간표'
    );
    const titleText = showNext ? nextTitle : currentTitle;
    const buttonText = showNext ? currentTitle : nextTitle;

    const rows = await fetchTimetable(grade, classNum, targetDate);

    updateTimetableHeader(titleText, targetDate, buttonText);
    container.innerHTML = renderTimetableRows(rows, targetDate);
    fetchWeather(targetDate);
    return;
}

function applyFridayFreePeriods(rows, targetDate) {
    if (targetDate.getDay() !== 5) {
        return rows;
    }

    const periodMap = new Map(rows.map(row => [Number(row.period), row]));

    [4, 5].forEach((period) => {
        if (!periodMap.has(period)) {
            periodMap.set(period, {
                period,
                originalSubject: '자유시간',
                subject: '자유시간'
            });
        }
    });

    return Array.from(periodMap.values()).sort((a, b) => Number(a.period) - Number(b.period));
}

function showTimetable() {
    if (!navigator.onLine) {
        showOfflineUI(true);
        return;
    }
    showOfflineUI(false);

    document.getElementById('meal-container').style.display = 'none';
    document.getElementById('timetable-container').style.display = 'block';

    const btns = ['btn-today', 'btn-tomorrow', 'btn-week', 'btn-timetable'];
    btns.forEach(id => {
        const btn = document.getElementById(id);
        if (btn) btn.classList.toggle('active', id === 'btn-timetable');
    });

    const savedGrade = localStorage.getItem('ghas-grade');
    const savedClass = localStorage.getItem('ghas-class');
    if (savedGrade) document.getElementById('grade-select').value = savedGrade;
    if (savedClass) document.getElementById('class-select').value = savedClass;

    timetableViewMode = 'current';
    updateTimetable();
}

// 페이지 로드 시 앱이 열려있다면 기존 예약 확인
if (localStorage.getItem('noti-enabled') === 'true') {
    scheduleDailyNotification();
}

function toggleTheme() {
    const body = document.body;
    const themeBtn = document.getElementById('btn-theme');
    const isDark = body.classList.contains('dark-theme') ||
        (!body.classList.contains('light-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);

    if (isDark) {
        body.classList.remove('dark-theme');
        body.classList.add('light-theme');
        themeBtn.textContent = '☀️';
        localStorage.setItem('theme', 'light');
    } else {
        body.classList.remove('light-theme');
        body.classList.add('dark-theme');
        themeBtn.textContent = '🌙';
        localStorage.setItem('theme', 'dark');
    }
}

function initTheme() {
    const savedTheme = localStorage.getItem('theme');
    const themeBtn = document.getElementById('btn-theme');
    if (savedTheme === 'dark') {
        document.body.classList.add('dark-theme');
        if (themeBtn) themeBtn.textContent = '🌙';
    } else if (savedTheme === 'light') {
        document.body.classList.add('light-theme');
        if (themeBtn) themeBtn.textContent = '☀️';
    } else {
        // System preference
        const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        if (themeBtn) themeBtn.textContent = isDark ? '🌙' : '☀️';
    }
}

// Firebase 및 누적 방문자 카운터 초기화
function initVisitorCounter() {
    if (typeof firebase === 'undefined' || typeof CONFIG === 'undefined' || !CONFIG.FIREBASE) {
        return;
    }

    try {
        const firebaseConfig = {
            apiKey: CONFIG.FIREBASE.API_KEY,
            authDomain: CONFIG.FIREBASE.AUTH_DOMAIN,
            databaseURL: CONFIG.FIREBASE.DATABASE_URL,
            projectId: CONFIG.FIREBASE.PROJECT_ID,
            storageBucket: CONFIG.FIREBASE.STORAGE_BUCKET,
            messagingSenderId: CONFIG.FIREBASE.MESSAGING_SENDER_ID,
            appId: CONFIG.FIREBASE.APP_ID
        };

        if (!firebase.apps.length) {
            firebase.initializeApp(firebaseConfig);
        }

        const db = firebase.database();
        const visitRef = db.ref('stats/visitCount');

        if (!sessionStorage.getItem('hasVisitedCounted')) {
            visitRef.transaction((currentValue) => (currentValue || 0) + 1);
            sessionStorage.setItem('hasVisitedCounted', 'true');
        }

        visitRef.on('value', (snapshot) => {
            const count = snapshot.val() || 0;
            const countEl = document.getElementById('visit-count');
            const labelEl = document.getElementById('visitor-label');
            if (countEl) {
                countEl.textContent = count.toLocaleString();
            }
            if (labelEl) {
                labelEl.textContent = '누적 방문자: ';
            }
        });
    } catch (e) {
        console.error('Firebase 초기화 실패:', e);
        return;
    }

    try {
        const messaging = firebase.messaging();
        messaging.onMessage((payload) => {
            console.log('Foreground message received:', payload);
            const title = payload?.notification?.title;
            const body = payload?.notification?.body;

            if (!title || Notification.permission !== 'granted') {
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

// 초기화 호출
initTheme();
showMeals('today');
initVisitorCounter();
