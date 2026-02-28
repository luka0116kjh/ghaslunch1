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
    el.innerText = value;
}

function getWeatherConfig() {
    const weatherConfig = (typeof CONFIG !== 'undefined' && CONFIG.WEATHER) ? CONFIG.WEATHER : {};
    return {
        apiKey: weatherConfig.API_KEY || '',
        lat: weatherConfig.LAT,
        lon: weatherConfig.LON,
        cityName: weatherConfig.CITY_NAME || ''
    };
}

async function fetchWeather(targetDate) {
    setText('weather-info', '날씨 정보를 불러오는 중...');

    const { apiKey, lat, lon, cityName } = getWeatherConfig();
    if (!apiKey) {
        setText('weather-info', '날씨 API 키가 설정되지 않았습니다.');
        return;
    }

    if (typeof lat !== 'number' || typeof lon !== 'number') {
        setText('weather-info', '날씨 좌표(lat/lon)가 설정되지 않았습니다.');
        return;
    }

    const targetYmd = formatDate(targetDate);
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`OpenWeather API error: ${response.status}`);

        const data = await response.json();
        if (!Array.isArray(data.list) || data.list.length === 0) {
            throw new Error('Forecast data is empty.');
        }

        const timezoneOffset = typeof data.city?.timezone === 'number' ? data.city.timezone : 0;
        const sameDayForecasts = data.list.filter(item => formatDateWithOffset(item.dt, timezoneOffset) === targetYmd);

        const source = sameDayForecasts.length > 0 ? sameDayForecasts : data.list;
        const picked = source.slice().sort((a, b) => {
            const aDiff = Math.abs(hourWithOffset(a.dt, timezoneOffset) - 12);
            const bDiff = Math.abs(hourWithOffset(b.dt, timezoneOffset) - 12);
            return aDiff - bDiff;
        })[0];

        const temp = typeof picked.main?.temp === 'number' ? `${Math.round(picked.main.temp)}°C` : '기온 정보 없음';
        const description = picked.weather?.[0]?.description || '날씨 정보 없음';
        const popText = typeof picked.pop === 'number' ? `강수확률 ${Math.round(picked.pop * 100)}%` : '';
        const place = cityName || data.city?.name || '';

        const weatherLine = [
            `${temp}`,
            description,
            popText
        ].filter(Boolean).join(' | ');

        setText('weather-info', place ? `${weatherLine} (${place})` : weatherLine);
    } catch (error) {
        console.error('Weather load failed:', error);
        setText('weather-info', '날씨 정보를 불러오지 못했습니다. API 키/좌표를 확인하세요.');
    }
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
    setText('lunch-cal', '');
    setText('dinner-menu', '데이터를 불러오는 중...');
    setText('dinner-cal', '');

    const apiKey = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : '';
    let url = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_YMD=${ymd}`;

    if (apiKey && apiKey !== '여기에_발급받은_키를_넣으세요') {
        url += `&KEY=${apiKey}`;
    }

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error('NEIS API 응답 오류');

        const data = await response.json();
        const mealInfo = Array.isArray(data.mealServiceDietInfo)
            ? data.mealServiceDietInfo.find(section => Array.isArray(section.row))
            : null;
        const rows = mealInfo?.row || [];

        setText('lunch-menu', '정보가 없습니다.');
        setText('dinner-menu', '정보가 없습니다.');

        rows.forEach(row => {
            const cleanMenu = (row.DDISH_NM || '')
                .replace(/\([^)]*\)/g, '')
                .replace(/<br\s*\/?>/gi, '\n')
                .trim();

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

function showMeals(type) {
    const today = new Date();
    const targetDate = new Date();

    if (type === 'tomorrow') {
        targetDate.setDate(today.getDate() + 1);
        document.getElementById('btn-today').classList.remove('active');
        document.getElementById('btn-tomorrow').classList.add('active');
        setText('lunch-title', '🍱 내일의 중식 (Lunch)');
        setText('dinner-title', '🌙 내일의 석식 (Dinner)');
    } else {
        document.getElementById('btn-today').classList.add('active');
        document.getElementById('btn-tomorrow').classList.remove('active');
        setText('lunch-title', '🍱 오늘의 중식 (Lunch)');
        setText('dinner-title', '🌙 오늘의 석식 (Dinner)');
    }

    fetchMeals(targetDate);
    fetchWeather(targetDate);
}

showMeals('today');
