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
    let url = '';

    if (hasProxy) {
        const baseUrl = proxyUrl.replace(/\/+$/, '');
        url = `${baseUrl}?lat=${lat}&lon=${lon}&units=metric&lang=kr`;
    } else if (apiKey) {
        url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;
    } else {
        setText('weather-info', '날씨 프록시 URL 또는 API 키가 필요합니다.');
        return;
    }

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

        const weatherLine = [temp, description, popText].filter(Boolean).join(' | ');
        setText('weather-info', place ? `${weatherLine} (${place})` : weatherLine);
    } catch (error) {
        console.error('Weather load failed:', error);
        setText('weather-info', '날씨 정보를 불러오지 못했습니다. 프록시/좌표를 확인해주세요.');
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
        updateVoteUI(ymd);
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
    return lines.join('\n\n');
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

    setText('btn-today', '오늘');
    setText('btn-week', '이번 주');

    if (type === 'week') {
        showWeeklyMeals(targetDate);
        // Hide voting in weekly view
        document.querySelectorAll('.vote-control').forEach(el => el.style.display = 'none');
        return;
    }

    document.querySelectorAll('.vote-control').forEach(el => el.style.display = 'flex');
    document.getElementById('btn-today').classList.add('active');
    document.getElementById('btn-week').classList.remove('active');
    setText('lunch-title', '오늘 중식 (Lunch)');
    setText('dinner-title', '오늘 석식 (Dinner)');

    fetchMeals(targetDate);
    fetchWeather(targetDate);
}

// --- Voting Logic ---
function getVoteKey(ymd, type) {
    return `vote_${ymd}_${type}`;
}

function updateVoteUI(ymd) {
    ['lunch', 'dinner'].forEach(type => {
        const key = getVoteKey(ymd, type);
        const hasVoted = localStorage.getItem(key) === 'true';
        const btn = document.getElementById(`${type}-vote-btn`);
        const heart = document.getElementById(`${type}-heart`);

        if (hasVoted) {
            btn.classList.add('active');
            heart.textContent = '❤️';
        } else {
            btn.classList.remove('active');
            heart.textContent = '🤍';
        }
    });
}

function toggleVote(type) {
    const today = new Date();
    const ymd = formatDate(today);
    const key = getVoteKey(ymd, type);
    const hasVoted = localStorage.getItem(key) === 'true';

    if (hasVoted) {
        localStorage.removeItem(key);
    } else {
        localStorage.setItem(key, 'true');
    }

    updateVoteUI(ymd);
}

// --- Firebase Initialization ---
let database;
try {
    if (typeof firebase !== 'undefined' && typeof CONFIG !== 'undefined' && CONFIG.FIREBASE && CONFIG.FIREBASE.API_KEY !== "발급받은_API_KEY") {
        const firebaseConfig = {
            apiKey: CONFIG.FIREBASE.API_KEY,
            authDomain: CONFIG.FIREBASE.AUTH_DOMAIN,
            databaseURL: CONFIG.FIREBASE.DATABASE_URL,
            projectId: CONFIG.FIREBASE.PROJECT_ID,
            storageBucket: CONFIG.FIREBASE.STORAGE_BUCKET,
            messagingSenderId: CONFIG.FIREBASE.MESSAGING_SENDER_ID,
            appId: CONFIG.FIREBASE.APP_ID
        };
        firebase.initializeApp(firebaseConfig);
        database = firebase.database();
    } else {
        console.warn('Firebase가 설정되지 않았습니다. 실시간 공유 기능이 작동하지 않습니다.');
    }
} catch (e) {
    console.error('Firebase 초기화 실패:', e);
}

// --- Food Nomination & Voting Logic ---
let foodList = [];

function getMonthKey() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

// Subscribe to Firebase data
if (database) {
    const monthKey = getMonthKey();
    database.ref(`votes/${monthKey}`).on('value', (snapshot) => {
        const data = snapshot.val();
        if (data) {
            // Convert object to array and sort
            foodList = Object.keys(data).map(key => ({
                id: key,
                ...data[key]
            })).sort((a, b) => b.votes - a.votes);
        } else {
            foodList = [];
        }
        renderFoodList();
        renderMainRanking();
    });
}

function openVoteModal() {
    document.getElementById('vote-modal').style.display = 'flex';
    renderFoodList();
}

function closeVoteModal() {
    document.getElementById('vote-modal').style.display = 'none';
}

function addFoodItem() {
    if (!database) {
        alert('실시간 기능을 사용하려면 Firebase 설정이 필요합니다.');
        return;
    }

    const input = document.getElementById('food-input');
    const name = input.value.trim();

    if (!name) return;

    // 길이 제한
    if (name.length < 2 || name.length > 20) {
        alert('음식 이름은 2~20자 사이로 입력해주세요.');
        return;
    }

    // 특수문자 제한
    const validPattern = /^[가-힣a-zA-Z0-9\s]+$/;
    if (!validPattern.test(name)) {
        alert('특수문자는 사용할 수 없습니다.');
        return;
    }

    // 금칙어 필터
    const bannedWords = ["섹스","야동","sex","porn","따먹고싶노","걸래","여자","남자","보지","자지","씨발","좆","개새끼","병신","미친놈","느금마","딱","존나","짱깨","쪽바리","김치녀","된장녀","한남충","일베충"];
    const lowerName = name.toLowerCase();

    if (bannedWords.some(word => lowerName.includes(word))) {
        alert("부적절한 단어가 포함되어 있습니다.");
        return;
    }

    // 중복 음식 방지
    if (foodList.some(item => item.name === name)) {
        alert('이미 목록에 있는 음식입니다!');
        return;
    }

    const monthKey = getMonthKey();
    const newFoodRef = database.ref(`votes/${monthKey}`).push();

    newFoodRef.set({
        name: name,
        votes: 0
    });

    input.value = '';
}

function voteFood(id) {
    if (!database) {
        // Fallback for non-Firebase mode if needed, but here we require it for real voting
        alert('실시간 기능을 사용하려면 Firebase 설정이 필요합니다.');
        return;
    }

    const voteKey = `voted_food_${id}`;
    if (localStorage.getItem(voteKey)) {
        alert('이미 투표하셨습니다!');
        return;
    }

    const monthKey = getMonthKey();
    const foodRef = database.ref(`votes/${monthKey}/${id}/votes`);

    // Increment votes using transaction
    foodRef.transaction((currentVotes) => {
        return (currentVotes || 0) + 1;
    });

    localStorage.setItem(voteKey, 'true');
}

function renderMainRanking() {
    const rankListEl = document.getElementById('ranking-list');
    if (!rankListEl) return;

    rankListEl.innerHTML = '';

    if (foodList.length === 0) {
        rankListEl.innerHTML = '<div style="text-align:center; color:#777; padding:20px;">아직 투표된 음식이 없습니다.</div>';
        return;
    }

    foodList.slice(0, 3).forEach((item, index) => {
        const div = document.createElement('div');
        div.className = 'rank-card';
        div.innerHTML = `
            <div class="rank-number">${index + 1}</div>
            <div class="rank-info">
                <div class="rank-menu">${item.name}</div>
                <div class="rank-date">실시간 투표 현황</div>
            </div>
            <div class="rank-votes">🔥 ${item.votes}</div>
        `;
        rankListEl.appendChild(div);
    });
}

function renderFoodList() {
    const listEl = document.getElementById('food-vote-list');
    if (!listEl) return;

    listEl.innerHTML = '';

    foodList.forEach(item => {
        const hasVoted = localStorage.getItem(`voted_food_${item.id}`);
        const div = document.createElement('div');
        div.className = 'vote-item';
        div.innerHTML = `
            <div class="food-name">${item.name}</div>
            <div class="item-actions">
                <span class="like-count">🔥 ${item.votes}</span>
                <button class="vote-btn ${hasVoted ? 'active' : ''}" onclick="voteFood('${item.id}')">
                    ${hasVoted ? '✅' : '👍'}
                </button>
            </div>
        `;
        listEl.appendChild(div);
    });
}

showMeals('today');