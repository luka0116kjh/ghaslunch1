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
                    const sameDayForecasts = data.list.filter(item => formatDateWithOffset(item.dt, timezoneOffset) === targetYmd);
                    const source = sameDayForecasts.length > 0 ? sameDayForecasts : data.list;
                    const picked = source.slice().sort((a, b) => {
                        const aDiff = Math.abs(hourWithOffset(a.dt, timezoneOffset) - 12);
                        const bDiff = Math.abs(hourWithOffset(b.dt, timezoneOffset) - 12);
                        return aDiff - bDiff;
                    })[0];

                    weatherData = {
                        temp: Math.round(picked.main.temp),
                        description: picked.weather?.[0]?.description,
                        pop: Math.round(picked.pop * 100)
                    };
                    if (!place) place = data.city?.name;
                }
            }
        }

        // Fallback to Open-Meteo if OpenWeather fails or is not configured
        if (!weatherData) {
            const isoDate = `${targetYmd.slice(0, 4)}-${targetYmd.slice(4, 6)}-${targetYmd.slice(6, 8)}`;
            const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,weathercode,precipitation_probability&timezone=Asia%2FSeoul&start_date=${isoDate}&end_date=${isoDate}`;
            const response = await fetch(url);
            if (!response.ok) throw new Error('Weather API fallback failed');

            const data = await response.json();
            if (data.hourly && data.hourly.time) {
                // Find index for 12:00 or closest
                const hourIndex = data.hourly.time.findIndex(t => t.includes('T12:00')) || 12;
                const code = data.hourly.weathercode[hourIndex];
                const weatherMap = {
                    0: '맑음', 1: '대체로 맑음', 2: '부분적으로 흐림', 3: '흐림',
                    45: '안개', 48: '서리 안개', 51: '가벼운 이슬비', 53: '이슬비', 55: '진한 이슬비',
                    61: '약한 비', 63: '보통 비', 65: '강한 비', 71: '약한 눈', 73: '보통 눈', 75: '강한 눈',
                    77: '눈알갱이', 80: '약한 소나기', 81: '보통 소나기', 82: '강한 소나기',
                    85: '약한 눈 소나기', 86: '강한 눈 소나기', 95: '뇌우', 96: '뇌우와 약한 우박', 99: '뇌우와 강한 우박'
                };

                weatherData = {
                    temp: Math.round(data.hourly.temperature_2m[hourIndex]),
                    description: weatherMap[code] || '날씨 정보 없음',
                    pop: data.hourly.precipitation_probability[hourIndex]
                };
            }
        }

        if (weatherData) {
            const { temp, description, pop } = weatherData;
            const tempText = `${temp}°C`;
            const popText = typeof pop === 'number' ? `강수확률 ${pop}%` : '';
            const weatherLine = [tempText, description, popText].filter(Boolean).join(' | ');
            setText('weather-info', place ? `${weatherLine} (${place})` : weatherLine);
        } else {
            throw new Error('No weather data available');
        }
    } catch (error) {
        console.error('Weather load failed:', error);
        setText('weather-info', '날씨 정보를 불러오지 못했습니다. 지역/좌표를 확인해주세요.');
    }
}

function normalizeMenuText(rawMenu) {
    return (rawMenu || '')
        .replace(/\([^)]*\)/g, '')
        .replace(/<br\s*\/?>/gi, '\n')
        .trim();
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
                setText('lunch-menu', cleanMenu || '정보가 없습니다.');
                setText('lunch-cal', row.CAL_INFO || '');
            } else if (row.MMEAL_SC_CODE === '3') {
                setText('dinner-menu', cleanMenu || '정보가 없습니다.');
                setText('dinner-cal', row.CAL_INFO || '');
            }
        });

    } catch (error) {
        console.error('Meal load failed:', error);
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
        const menu = mealMap[ymd]?.[mealCode] || '정보가 없습니다.';
        lines.push(`${formatMonthDay(date)} (${weekday})\n${menu}`);
    }
    return lines.join('\n\n────────────────\n\n');
}

async function showWeeklyMeals(baseDate) {
    const weekBaseDate = new Date(baseDate);
    const dayOfWeek = weekBaseDate.getDay(); // 0: Sun, 6: Sat
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    if (dayOfWeek === 6) weekBaseDate.setDate(weekBaseDate.getDate() + 2); // Sat -> next Monday
    if (dayOfWeek === 0) weekBaseDate.setDate(weekBaseDate.getDate() + 1); // Sun -> next Monday

    const monday = getMonday(weekBaseDate);
    const friday = new Date(monday);
    friday.setDate(monday.getDate() + 4);
    const weekLabel = isWeekend ? '다음 주' : '이번 주';

    document.getElementById('btn-today').classList.remove('active');
    if (document.getElementById('btn-tomorrow')) document.getElementById('btn-tomorrow').classList.remove('active');
    document.getElementById('btn-week').classList.add('active');
    setText('lunch-title', `${weekLabel} 중식 (Lunch)`);
    setText('dinner-title', `${weekLabel} 석식 (Dinner)`);
    setText('today-date', `${formatMonthDay(monday)} ~ ${formatMonthDay(friday)}`);
    setText('weather-info', `${weekLabel} 모드에서는 날씨를 표시하지 않습니다.`);
    setText('lunch-menu', '데이터를 불러오는 중...');
    setText('dinner-menu', '데이터를 불러오는 중...');
    setText('lunch-cal', '');
    setText('dinner-cal', '');

    const fromYmd = formatDate(monday);
    const toYmd = formatDate(friday);
    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';

    // 중식(2)과 석식(3) 각각 따로 호출하여 데이터 누락 방지
    async function fetchMealByCode(code) {
        let url = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_FROM_YMD=${fromYmd}&MLSV_TO_YMD=${toYmd}&MMEAL_SC_CODE=${code}&pSize=50`;
        if (apiKey) url += `&KEY=${apiKey}`;

        try {
            const response = await fetch(url);
            const data = await response.json();
            const rows = extractMealRows(data);
            const map = {};
            rows.forEach(row => {
                map[row.MLSV_YMD] = normalizeMenuText(row.DDISH_NM);
            });
            return map;
        } catch (e) {
            console.error(`Weekly Fetch Error (Code ${code}):`, e);
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

        setText('lunch-menu', buildMealTextByWeek(mealMap, '2', monday));
        setText('dinner-menu', buildMealTextByWeek(mealMap, '3', monday));
    } catch (error) {
        console.error('Weekly meal load failed:', error);
        const msg = '급식 정보를 불러오지 못했습니다.';
        setText('lunch-menu', msg);
        setText('dinner-menu', msg);
    }
}

function showMeals(type) {
    const targetDate = new Date();

    if (type === 'tomorrow') {
        targetDate.setDate(targetDate.getDate() + 1);
    }

    if (type === 'week') {
        showWeeklyMeals(new Date());
    } else {
        const btnToday = document.getElementById('btn-today');
        const btnTomorrow = document.getElementById('btn-tomorrow');
        const btnWeek = document.getElementById('btn-week');

        if (btnToday) btnToday.classList.toggle('active', type === 'today');
        if (btnTomorrow) btnTomorrow.classList.toggle('active', type === 'tomorrow');
        if (btnWeek) btnWeek.classList.toggle('active', false);

        const titlePrefix = type === 'tomorrow' ? '내일' : '오늘';
        setText('lunch-title', `${titlePrefix} 중식 (Lunch)`);
        setText('dinner-title', `${titlePrefix} 석식 (Dinner)`);

        fetchMeals(targetDate);
        fetchWeather(targetDate);
    }
}

async function requestNoti() {
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
        alert('알림이 설정되었습니다! 매일 오전 7:30에 급식 정보를 확인하세요.');
        scheduleDailyNotification();
    } else {
        alert('알림 권한을 허용해야 알림을 받을 수 있습니다.');
    }
}

function scheduleDailyNotification() {
    // 로컬 스토리지에 예약 상태 저장
    localStorage.setItem('noti-enabled', 'true');

    const now = new Date();
    let target = new Date();
    target.setHours(7, 30, 0, 0);

    if (now > target) {
        target.setDate(target.getDate() + 1);
    }

    const delay = target.getTime() - now.getTime();

    setTimeout(() => {
        showLocalNotification();
        setInterval(showLocalNotification, 24 * 60 * 60 * 1000);
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

// 페이지 로드 시 앱이 열려있다면 기존 예약 확인
if (localStorage.getItem('noti-enabled') === 'true') {
    scheduleDailyNotification();
}

showMeals('today');
