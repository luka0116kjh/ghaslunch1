function formatDate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}

function setText(id, value) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = value;
}

function getStoredStudentName() {
    return localStorage.getItem(STUDENT_NAME_KEY) || '';
}

function getStoredStudentId() {
    return localStorage.getItem(STUDENT_ID_KEY) || '';
}

function getStoredStudentCodeImage() {
    return localStorage.getItem(STUDENT_CODE_IMAGE_KEY) || '';
}

const NEIS_BASE_URL = 'https://open.neis.go.kr/hub/';
const NEIS_OFFICE_CODE = 'J10';
const NEIS_SCHOOL_CODE = '7530908';
const FIREBASE_CONFIG = {
    apiKey: "AIzaSyDuqKOq-5dRC8dClv7fRBULA0lows-RHUg",
    authDomain: "ghaslunch1.firebaseapp.com",
    databaseURL: "https://ghaslunch1-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "ghaslunch1",
    storageBucket: "ghaslunch1.firebasestorage.app",
    messagingSenderId: "348512527529",
    appId: "1:348512527529:web:fee72bc56b6a44bfda75b8"
};
const FIREBASE_VAPID_KEY = "BBgDLFBJt3E1eA5UtvC1IOusTUzUinGk6zLqe1PLELuusOqZo0loSMNUdMbKt1Uldj2g1ueUU5vt_JFEPHyLU7U";
window.FIREBASE_CONFIG = FIREBASE_CONFIG;
window.FIREBASE_VAPID_KEY = FIREBASE_VAPID_KEY;
// 누적 방문자 = 페이지/앱 진입 횟수. 모든 전체 페이지 로드마다 +1 집계한다.
// 브라우저 저장소 가드는 사용하지 않으므로 새로고침·재진입은 다시 집계된다.
// 같은 문서 로드 안에서 initVisitorCounter 가 실수로 두 번 호출돼도 쓰기는 1회만
// 수행하도록 하는 인메모리 가드 (새로고침·새 WebView/탭 로드 시 자연히 초기화됨).
// (기존 Realtime Database 의 stats/visitCount 누적값을 그대로 사용한다 — 표시 보정값 없음)
let visitorCountIncrementStarted = false;
const STUDENT_NAME_KEY = 'ghas-student-name';
const STUDENT_ID_KEY = 'ghas-student-id';
const STUDENT_CODE_IMAGE_KEY = 'ghas-student-code-image';
const SCHEDULE_YEAR = window.GHAS_SCHEDULE_YEAR || 2026;
const SCHEDULE_SOURCE = window.GHAS_SCHEDULE_SOURCE || '';
const AFTER_SCHOOL_SCHEDULES = Array.isArray(window.GHAS_AFTER_SCHOOL_SCHEDULES)
    ? window.GHAS_AFTER_SCHOOL_SCHEDULES
    : [];
let SCHEDULE_EVENTS;
const CLASS_TIMETABLE_VERSION = '20260520';
const CLASS_TIMETABLE_RUNTIME_PATH = './src/data/classTimetable2026.js';
const TIMETABLE_DAYS = ['일', '월', '화', '수', '목', '금', '토'];
const TIMETABLE_PERIODS = [1, 2, 3, 4, 5, 6, 7];
let mealViewMode = 'today';
let scheduleViewMode = 'current';
let classTimetable2026Promise = null;
let classTimetable2026ImportStatus = 'not-started';
let barcodeScanModeActive = false;
const STUDENT_CODE_CROP_ASPECT = 3;
const STUDENT_CODE_CROP_OUTPUT_WIDTH = 1200;
const STUDENT_CODE_CROP_OUTPUT_HEIGHT = Math.round(STUDENT_CODE_CROP_OUTPUT_WIDTH / STUDENT_CODE_CROP_ASPECT);
const studentCodeCropperState = {
    image: null,
    baseWidth: 0,
    baseHeight: 0,
    scale: 1,
    minScale: 1,
    maxScale: 5,
    offsetX: 0,
    offsetY: 0,
    pointers: new Map(),
    dragStartX: 0,
    dragStartY: 0,
    startOffsetX: 0,
    startOffsetY: 0,
    pinchStartDistance: 0,
    pinchStartScale: 1,
    pinchStartMidX: 0,
    pinchStartMidY: 0
};

function buildNeisUrl(endpoint, params) {
    const url = new URL(endpoint, NEIS_BASE_URL);
    url.searchParams.set('Type', 'json');
    url.searchParams.set('ATPT_OFCDC_SC_CODE', NEIS_OFFICE_CODE);
    url.searchParams.set('SD_SCHUL_CODE', NEIS_SCHOOL_CODE);

    Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
            url.searchParams.set(key, value);
        }
    });

    return url.toString();
}

function startOfDay(date) {
    const next = new Date(date);
    next.setHours(0, 0, 0, 0);
    return next;
}

function createScheduleDate(month, day) {
    return new Date(SCHEDULE_YEAR, Number(month) - 1, Number(day));
}

function isSameScheduleDay(a, b) {
    return formatDate(a) === formatDate(b);
}

function formatScheduleDotDate(date) {
    return `${date.getFullYear()}.${String(date.getMonth() + 1).padStart(2, '0')}.${String(date.getDate()).padStart(2, '0')}`;
}

function formatDateHyphen(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function createDateFromYmd(ymd) {
    const [year, month, day] = String(ymd).split('-').map(Number);
    return new Date(year, month - 1, day);
}

function formatScheduleRange(event) {
    if (isSameScheduleDay(event.startDate, event.endDate)) {
        return formatScheduleDotDate(event.startDate);
    }
    return `${formatScheduleDotDate(event.startDate)} ~ ${formatScheduleDotDate(event.endDate)}`;
}

function parseScheduleSource(source) {
    return source
        .trim()
        .split('\n')
        .map((line, index) => {
            const normalized = line.trim().replace(/\s+/g, ' ');
            const lineWithoutMonthHeader = normalized.replace(/^\d{2} 월\s+/, '');
            const match = lineWithoutMonthHeader.match(/^(\d{2})\.(\d{2}) \([^)]+\) ~ (\d{2})\.(\d{2}) \([^)]+\) (.+)$/);

            if (!match) {
                console.warn('Invalid schedule line skipped:', line);
                return null;
            }

            const [, startMonth, startDay, endMonth, endDay, title] = match;
            return {
                id: `${SCHEDULE_YEAR}-${index}`,
                startDate: createScheduleDate(startMonth, startDay),
                endDate: createScheduleDate(endMonth, endDay),
                title: normalizeScheduleTitle(title)
            };
        })
        .filter(Boolean)
        .sort((a, b) => a.startDate - b.startDate || a.endDate - b.endDate || a.title.localeCompare(b.title, 'ko'));
}

function normalizeScheduleTitle(title) {
    const normalizedTitle = String(title || '')
        .trim()
        .replace(/\s+/g, ' ')
        .replace(/대체\s*공휴일/g, '대체공휴일')
        .replace(/대체\s*공유일/g, '대체공유일');

    return SUBJECT_ALIASES[normalizedTitle] || normalizedTitle;
}

function isHolidayScheduleTitle(title) {
    return /공휴일|대체공유일|노동절|현충일|추석|개천절|재량휴업일|지방선거|선거/.test(normalizeScheduleTitle(title));
}

function getScheduleEventName(event) {
    return normalizeScheduleTitle(event.title) || '행사 일정';
}

function getScheduleCategory(event) {
    if (event.category) return event.category;
    const title = getScheduleEventName(event);
    if (isHolidayScheduleTitle(title)) return '휴일';
    if (/시험|정기시험|평가|검정|합격|접수/.test(title)) return '시험/검정';
    if (/신입학|입학식|예비소집|원서접수|면접/.test(title)) return '입학/전형';
    return '행사';
}

function getScheduleStatus(event) {
    const today = startOfDay(new Date());
    const start = startOfDay(event.startDate);
    const end = startOfDay(event.endDate);

    if (today >= start && today <= end) {
        return { label: isSameScheduleDay(start, end) ? '오늘' : '진행중', className: 'today' };
    }
    if (start > today) {
        return { label: '예정', className: 'upcoming' };
    }
    return { label: '완료', className: 'past' };
}

function getScheduleBaseMonth() {
    const baseDate = new Date();
    if (scheduleViewMode === 'next') {
        baseDate.setMonth(baseDate.getMonth() + 1, 1);
    }
    return new Date(baseDate.getFullYear(), baseDate.getMonth(), 1);
}

function getScheduleRange() {
    const start = getScheduleBaseMonth();
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 0);
    return { start, end };
}

function isRangeOverlapping(startA, endA, startB, endB) {
    return startOfDay(startA) <= startOfDay(endB) && startOfDay(endA) >= startOfDay(startB);
}

function getVisibleScheduleEvents() {
    const { start, end } = getScheduleRange();
    const today = startOfDay(new Date());
    return getAllScheduleEvents().filter((event) => {
        return startOfDay(event.endDate) >= today && isRangeOverlapping(event.startDate, event.endDate, start, end);
    });
}

function getAfterschoolDayInfo(targetDate) {
    const ymd = formatDateHyphen(targetDate);

    for (const schedule of AFTER_SCHOOL_SCHEDULES) {
        const exception = schedule.exceptions?.[ymd];
        if (exception) {
            return {
                type: 'exception',
                schedule,
                date: ymd,
                title: exception.title,
                message: exception.message
            };
        }

        if (Array.isArray(schedule.operatingDates) && schedule.operatingDates.includes(ymd)) {
            return {
                type: 'operating',
                schedule,
                date: ymd,
                message: '오늘 방과후 있음'
            };
        }
    }

    return null;
}

function getAfterschoolScheduleEvents() {
    return AFTER_SCHOOL_SCHEDULES.flatMap((schedule) => {
        if (!Array.isArray(schedule.operatingDates)) return [];

        return schedule.operatingDates.map((ymd) => ({
            id: `${schedule.id}-${ymd}`,
            startDate: createDateFromYmd(ymd),
            endDate: createDateFromYmd(ymd),
            title: schedule.scheduleTitle || schedule.title,
            category: '방과후',
            timeText: schedule.classTime,
            detailTitle: schedule.title,
            courseRooms: Array.isArray(schedule.courseRooms) ? schedule.courseRooms : []
        }));
    });
}

function getAllScheduleEvents() {
    return [
        ...SCHEDULE_EVENTS,
        ...getAfterschoolScheduleEvents()
    ].sort((a, b) => a.startDate - b.startDate || a.endDate - b.endDate || getScheduleEventName(a).localeCompare(getScheduleEventName(b), 'ko'));
}

function getScheduleDisplayDate(event) {
    const { start } = getScheduleRange();
    const eventStart = startOfDay(event.startDate);
    const rangeStart = startOfDay(start);
    return eventStart < rangeStart ? rangeStart : event.startDate;
}

function renderScheduleRow(event) {
    const status = getScheduleStatus(event);
    const displayDate = getScheduleDisplayDate(event);
    const meta = [
        formatScheduleRange(event),
        event.timeText,
        getScheduleCategory(event)
    ].filter(Boolean).join(' · ');
    const detailHtml = renderScheduleDetail(event);

    return `
        <div class="schedule-row ${status.className === 'today' ? 'is-today' : ''}">
            <div class="date-badge">
                <span class="date-day">${displayDate.getDate()}</span>
                <span class="date-weekday">${displayDate.toLocaleDateString('ko-KR', { weekday: 'short' })}</span>
            </div>
            <div class="schedule-content">
                <div class="schedule-line">
                    <div class="schedule-title">${escapeHTML(getScheduleEventName(event))}</div>
                    <span class="status-pill ${status.className}">${status.label}</span>
                </div>
                <div class="schedule-meta">${escapeHTML(meta)}</div>
                ${detailHtml}
            </div>
        </div>
    `;
}

function renderScheduleDetail(event) {
    if (!Array.isArray(event.courseRooms) || event.courseRooms.length === 0) {
        return '';
    }

    return `
        <details class="schedule-detail">
            <summary>${escapeHTML(event.detailTitle || '상세 보기')}</summary>
            <div class="schedule-detail-list">
                ${event.courseRooms.map((course) => `
                    <div class="schedule-detail-row">
                        <span>${escapeHTML(course.name)}</span>
                        <span>${escapeHTML(course.room)}</span>
                    </div>
                `).join('')}
            </div>
        </details>
    `;
}

function getHolidayEventForDate(targetDate) {
    const day = startOfDay(targetDate);

    return SCHEDULE_EVENTS.find((event) => {
        const start = startOfDay(event.startDate);
        const end = startOfDay(event.endDate);
        return day >= start && day <= end && isHolidayScheduleTitle(event.title);
    }) || null;
}

function renderScheduleList() {
    const list = document.getElementById('schedule-list');
    if (!list) return;

    const visibleEvents = getVisibleScheduleEvents();
    if (visibleEvents.length === 0) {
        list.innerHTML = '<div class="schedule-empty">등록된 행사 일정이 없습니다.</div>';
        return;
    }

    const groups = visibleEvents.reduce((acc, event) => {
        const month = getScheduleDisplayDate(event).getMonth() + 1;
        if (!acc[month]) acc[month] = [];
        acc[month].push(event);
        return acc;
    }, {});

    list.innerHTML = Object.entries(groups).map(([month, events]) => `
        <div class="schedule-month-title">${Number(month)}월</div>
        ${events.map(renderScheduleRow).join('')}
    `).join('');
}

function updateScheduleHeader() {
    const baseMonth = getScheduleBaseMonth();
    const label = `${baseMonth.getMonth() + 1}월 일정표`;
    const titlePrefix = scheduleViewMode === 'next' ? '다음달' : '이번달';
    const buttonText = scheduleViewMode === 'next' ? '이번달 일정표' : '다음달 일정표';
    const button = document.getElementById('btn-schedule-switch');

    setText('schedule-view-title', `${titlePrefix} 일정표`);
    setText('today-date', `${SCHEDULE_YEAR}년 ${label}`);
    if (button) button.textContent = buttonText;
}

function toggleScheduleView() {
    scheduleViewMode = scheduleViewMode === 'current' ? 'next' : 'current';
    showSchedule();
}

function ensureAfterschoolTodayCard() {
    let card = document.getElementById('afterschool-today-card');
    if (card) return card;

    const toolbarCard = document.getElementById('meal-toolbar-card');
    if (!toolbarCard || !toolbarCard.parentNode) return null;

    card = document.createElement('article');
    card.id = 'afterschool-today-card';
    card.className = 'meal-card afterschool-today-card';
    toolbarCard.insertAdjacentElement('afterend', card);
    return card;
}

function renderAfterschoolTodayCard(targetDate, mode) {
    const card = ensureAfterschoolTodayCard();
    if (!card) return;

    if (mode !== 'today') {
        card.hidden = true;
        card.innerHTML = '';
        return;
    }

    const dayInfo = getAfterschoolDayInfo(targetDate);
    if (!dayInfo) {
        card.hidden = true;
        card.innerHTML = '';
        return;
    }

    card.hidden = false;
    if (dayInfo.type === 'exception') {
        card.classList.add('is-exception');
        card.innerHTML = `
            <div class="meal-type">방과후 수업</div>
            <div class="afterschool-today-message">${escapeHTML(dayInfo.message)}</div>
        `;
        return;
    }

    const schedule = dayInfo.schedule;
    card.classList.remove('is-exception');
    card.innerHTML = `
        <div class="meal-type">방과후 수업</div>
        <div class="afterschool-today-message">오늘 방과후 있음</div>
        <div class="afterschool-today-time">석식 ${escapeHTML(schedule.dinnerTime)} · 수업 ${escapeHTML(schedule.classTime)}</div>
    `;
}

function showOfflineUI(isOffline) {
    const offlineContainer = document.getElementById('offline-container');
    const mealContainer = document.getElementById('meal-container');
    const timetableContainer = document.getElementById('timetable-container');
    const scheduleContainer = document.getElementById('schedule-container');

    if (isOffline) {
        if (mealContainer) mealContainer.style.display = 'none';
        if (timetableContainer) timetableContainer.style.display = 'none';
        if (scheduleContainer) scheduleContainer.style.display = 'none';
        if (offlineContainer) offlineContainer.style.display = 'flex';
    } else {
        if (offlineContainer) offlineContainer.style.display = 'none';
    }
}

window.addEventListener('online', () => {
    showOfflineUI(false);
    const activeBtn = document.querySelector('.btn-group button.active');
    if (activeBtn && activeBtn.id === 'btn-timetable') showTimetable();
    else if (activeBtn && activeBtn.id === 'btn-schedule') showSchedule();
    else if (activeBtn && activeBtn.id === 'btn-week') showMeals('week');
    else showMeals('today');
});

window.addEventListener('offline', () => {
    const activeBtn = document.querySelector('.btn-group button.active');
    if (activeBtn && activeBtn.id === 'btn-schedule') {
        showSchedule();
    } else {
        showOfflineUI(true);
    }
});

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

function renderMealMenuHtml(menuText, calorieText = '') {
    const items = String(menuText || '')
        .split('\n')
        .map(item => item.trim())
        .filter(Boolean);

    if (items.length === 0) {
        return escapeHTML('정보가 없습니다.');
    }

    const lines = [];
    for (let index = 0; index < items.length; index += 2) {
        lines.push(items.slice(index, index + 2).map(escapeHTML).join(' / '));
    }

    const calorie = String(calorieText || '').trim();
    if (calorie) {
        lines[lines.length - 1] = `${lines[lines.length - 1]} · ${escapeHTML(calorie)}`;
    }

    return lines.join('<br>');
}

function extractMealRows(data) {
    const mealInfo = Array.isArray(data.mealServiceDietInfo)
        ? data.mealServiceDietInfo.find(section => Array.isArray(section.row))
        : null;
    return mealInfo?.row || [];
}

function extractTimetableRows(data) {
    const timetableInfo = Array.isArray(data?.hisTimetable)
        ? data.hisTimetable.find(section => Array.isArray(section.row))
        : null;

    if (timetableInfo) {
        return timetableInfo.row;
    }

    const result = Array.isArray(data?.RESULT) ? data.RESULT[0] : data?.RESULT;
    const resultMessage = result?.MESSAGE || result?.CODE;
    if (resultMessage) {
        console.warn('Timetable API returned no rows:', resultMessage);
    } else {
        console.warn('Timetable API response did not include rows.');
    }

    return [];
}

async function fetchMealData(params) {
    const response = await fetch(buildNeisUrl('mealServiceDietInfo', {
        MLSV_YMD: params.ymd,
        MLSV_FROM_YMD: params.from,
        MLSV_TO_YMD: params.to,
        MMEAL_SC_CODE: params.mealCode,
        pSize: params.pSize || 100
    }));
    if (!response.ok) throw new Error('급식 API 응답 오류');
    return response.json();
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

    try {
        const data = await fetchMealData({ from: ymd, to: ymd, pSize: 100 });
        const rows = extractMealRows(data);

        const emptyMessage = '급식 정보가 없습니다. (주말/휴일일 수 있습니다.)';
        setText('lunch-menu', emptyMessage);
        setText('dinner-menu', emptyMessage);

        rows.forEach(row => {
            const cleanMenu = normalizeMenuText(row.DDISH_NM);
            if (row.MMEAL_SC_CODE === '2') {
                const lunchEl = document.getElementById('lunch-menu');
                if (lunchEl) lunchEl.innerHTML = renderMealMenuHtml(cleanMenu, row.CAL_INFO);
                setText('lunch-cal', '');
            } else if (row.MMEAL_SC_CODE === '3') {
                const dinnerEl = document.getElementById('dinner-menu');
                if (dinnerEl) dinnerEl.innerHTML = renderMealMenuHtml(cleanMenu, row.CAL_INFO);
                setText('dinner-cal', '');
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
        const meal = mealMap[ymd]?.[mealCode];
        const menu = renderMealMenuHtml(meal?.menu || '정보가 없습니다.', meal?.calorie || '');
        lines.push(`
            <div class="weekly-meal-day">
                <div class="weekly-meal-date">
                    ${formatMonthDay(date)} (${weekday})
                </div>
                <div class="weekly-meal-menu">${menu}</div>
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
    const scheduleContainer = document.getElementById('schedule-container');
    if (scheduleContainer) scheduleContainer.style.display = 'none';
    const mealToolbarCard = document.getElementById('meal-toolbar-card');
    if (mealToolbarCard) mealToolbarCard.style.display = 'none';
    renderAfterschoolTodayCard(monday, 'week');
    document.getElementById('btn-today').classList.remove('active');
    if (document.getElementById('btn-schedule')) document.getElementById('btn-schedule').classList.remove('active');
    document.getElementById('btn-week').classList.add('active');
    if (document.getElementById('btn-timetable')) document.getElementById('btn-timetable').classList.remove('active');
    renderStudentCodeCard();
    setText('lunch-title', `${weekLabel} 중식`);
    setText('dinner-title', `${weekLabel} 석식`);
    setText('today-date', `${formatMonthDay(monday)} ~ ${formatMonthDay(friday)}`);
    setText('lunch-menu', '데이터를 불러오는 중...');
    setText('dinner-menu', '데이터를 불러오는 중...');
    setText('lunch-cal', '');
    setText('dinner-cal', '');

    const fromYmd = formatDate(monday);
    const toYmd = formatDate(friday);

    async function fetchMealByCode(code) {
        try {
            const data = await fetchMealData({
                from: fromYmd,
                to: toYmd,
                mealCode: code,
                pSize: 50
            });
            const rows = extractMealRows(data);
            const map = {};
            rows.forEach((row) => {
                map[row.MLSV_YMD] = {
                    menu: normalizeMenuText(row.DDISH_NM),
                    calorie: row.CAL_INFO || ''
                };
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
            Object.entries(lunchData).forEach(([ymd, meal]) => {
                if (!mealMap[ymd]) mealMap[ymd] = {};
                mealMap[ymd]['2'] = meal;
            });
        }
        if (dinnerData) {
            Object.entries(dinnerData).forEach(([ymd, meal]) => {
                if (!mealMap[ymd]) mealMap[ymd] = {};
                mealMap[ymd]['3'] = meal;
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

function updateMealSwitchUI(type) {
    const title = type === 'tomorrow' ? '내일의 급식' : '오늘의 급식';
    const buttonText = type === 'tomorrow' ? '오늘의 급식' : '내일의 급식';
    const button = document.getElementById('btn-meal-switch');

    setText('meal-view-title', title);
    if (button) button.textContent = buttonText;
}

function toggleMealView() {
    const nextType = mealViewMode === 'today' ? 'tomorrow' : 'today';
    showMeals(nextType);
}

function renderStudentCodeCard() {
    const studentId = getStoredStudentId();
    const storedImage = getStoredStudentCodeImage();
    const shouldShowImage = Boolean(storedImage);
    const placeholder = document.getElementById('student-card-placeholder');
    const imageEl = document.getElementById('student-code-image');
    const imageWrap = document.getElementById('student-card-image');
    const inlineEmpty = document.getElementById('student-code-inline-empty');
    const inlineImageEl = document.getElementById('student-code-inline-image');
    const inlineImageWrap = document.getElementById('student-code-inline-image-wrap');
    const inlineChangeAction = document.querySelector('.student-code-small-action');

    if (placeholder) {
        placeholder.hidden = shouldShowImage;
    }

    if (imageWrap) {
        imageWrap.hidden = !shouldShowImage;
    }

    if (!imageEl) return;

    if (shouldShowImage) {
        imageEl.src = storedImage;
        imageEl.alt = '저장된 학생 코드 사진';
    } else {
        imageEl.removeAttribute('src');
        imageEl.alt = '';
    }

    if (inlineEmpty) {
        inlineEmpty.hidden = shouldShowImage;
    }

    if (inlineImageWrap) {
        inlineImageWrap.hidden = !shouldShowImage;
    }

    if (inlineChangeAction) {
        inlineChangeAction.hidden = !shouldShowImage;
    }

    if (!inlineImageEl) return;

    if (shouldShowImage) {
        inlineImageEl.src = storedImage;
        inlineImageEl.alt = studentId ? `저장된 학생 코드 ${studentId}` : '저장된 바코드/QR 이미지';
    } else {
        inlineImageEl.removeAttribute('src');
        inlineImageEl.alt = '';
    }
}

function setStudentCodeUploadStatus(message) {
    const statusIds = ['student-code-upload-status', 'student-code-inline-status'];
    statusIds.forEach((id) => {
        const statusEl = document.getElementById(id);
        if (statusEl) statusEl.textContent = message;
    });
}

function getNativeBarcodeBridge() {
    return window.AndroidBridge || window.GHASAndroidApp || null;
}

function enableBarcodeScanMode() {
    if (barcodeScanModeActive) return;
    barcodeScanModeActive = true;

    try {
        const bridge = getNativeBarcodeBridge();
        if (typeof bridge?.enableBarcodeScanMode === 'function') {
            bridge.enableBarcodeScanMode();
        }
    } catch (error) {
        console.warn('Native barcode scan mode enable failed:', error);
    }
}

function disableBarcodeScanMode() {
    if (!barcodeScanModeActive) return;
    barcodeScanModeActive = false;

    try {
        const bridge = getNativeBarcodeBridge();
        if (typeof bridge?.disableBarcodeScanMode === 'function') {
            bridge.disableBarcodeScanMode();
        }
    } catch (error) {
        console.warn('Native barcode scan mode disable failed:', error);
    }
}

function openStudentCodeModal() {
    const modal = document.getElementById('student-code-modal');

    setStudentCodeUploadStatus('');
    renderStudentCodeCard();

    if (modal) {
        modal.classList.add('open');
        modal.setAttribute('aria-hidden', 'false');
        enableBarcodeScanMode();
    }
}

function closeStudentCodeModal() {
    const modal = document.getElementById('student-code-modal');
    if (!modal) {
        closeStudentCodeEditor();
        disableBarcodeScanMode();
        return;
    }
    modal.classList.remove('open');
    modal.setAttribute('aria-hidden', 'true');
    closeStudentCodeEditor();
    disableBarcodeScanMode();
}

function isStudentCodeModalOpen() {
    return document.getElementById('student-code-modal')?.classList.contains('open') === true;
}

function loadImageFromFile(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        const image = new Image();

        image.onload = () => {
            resolve(image);
        };

        image.onerror = () => {
            reject(new Error('IMAGE_LOAD_FAILED'));
        };

        reader.onload = () => {
            const dataUrl = String(reader.result || '');
            if (!dataUrl) {
                reject(new Error('IMAGE_READ_EMPTY'));
                return;
            }
            image.src = dataUrl;
        };
        reader.onerror = () => reject(new Error('IMAGE_READ_FAILED'));
        reader.readAsDataURL(file);
    });
}

async function handleStudentCodeImageUpload(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
        setStudentCodeUploadStatus('사진에서 바코드 영역을 맞춰 주세요.');
        await openStudentCodeEditor(file);
    } catch (error) {
        console.error('Student code image edit failed:', error);
        setStudentCodeUploadStatus('사진을 불러오지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    } finally {
        event.target.value = '';
    }
}

async function openStudentCodeEditor(file) {
    const image = await loadImageFromFile(file);
    const editor = document.getElementById('student-code-editor');
    const cropperImage = document.getElementById('student-code-cropper-image');
    if (!editor || !cropperImage) return;

    const modal = document.getElementById('student-code-modal');
    if (modal && !modal.classList.contains('open')) {
        renderStudentCodeCard();
        modal.classList.add('open');
        modal.setAttribute('aria-hidden', 'false');
        enableBarcodeScanMode();
    }

    const studentCard = document.getElementById('student-card');
    if (studentCard) studentCard.hidden = true;

    resetStudentCodeCropperImageSource();
    studentCodeCropperState.image = image;
    cropperImage.src = image.src;
    cropperImage.alt = '편집할 바코드 사진';
    editor.hidden = false;

    requestAnimationFrame(() => requestAnimationFrame(resetStudentCodeCropperTransform));
}

function resetStudentCodeCropperImageSource() {
    studentCodeCropperState.image = null;
    studentCodeCropperState.pointers.clear();
}

function closeStudentCodeEditor() {
    const editor = document.getElementById('student-code-editor');
    const cropperImage = document.getElementById('student-code-cropper-image');
    if (editor) editor.hidden = true;
    if (cropperImage) {
        cropperImage.removeAttribute('src');
        cropperImage.alt = '';
        cropperImage.style.removeProperty('width');
        cropperImage.style.removeProperty('height');
        cropperImage.style.removeProperty('transform');
    }
    resetStudentCodeCropperImageSource();
    const studentCard = document.getElementById('student-card');
    if (studentCard) studentCard.hidden = false;
    setStudentCodeUploadStatus('');
}

function cropperElements() {
    return {
        viewport: document.getElementById('student-code-cropper'),
        frame: document.querySelector('.student-code-crop-frame'),
        imageEl: document.getElementById('student-code-cropper-image')
    };
}

function resetStudentCodeCropperTransform() {
    const { viewport, frame, imageEl } = cropperElements();
    const image = studentCodeCropperState.image;
    if (!viewport || !frame || !imageEl || !image) return;

    const frameRect = frame.getBoundingClientRect();
    if (!frameRect.width || !image.naturalWidth || !image.naturalHeight) return;
    const coverScale = Math.max(
        frameRect.width / image.naturalWidth,
        frameRect.height / image.naturalHeight
    );

    studentCodeCropperState.baseWidth = image.naturalWidth * coverScale;
    studentCodeCropperState.baseHeight = image.naturalHeight * coverScale;
    studentCodeCropperState.scale = 1;
    studentCodeCropperState.minScale = 1;
    studentCodeCropperState.offsetX = 0;
    studentCodeCropperState.offsetY = 0;

    imageEl.style.width = `${studentCodeCropperState.baseWidth}px`;
    imageEl.style.height = `${studentCodeCropperState.baseHeight}px`;
    applyStudentCodeCropperTransform();
}

function clampStudentCodeCropperOffset() {
    const { frame } = cropperElements();
    if (!frame) return;

    const frameRect = frame.getBoundingClientRect();
    const scaledWidth = studentCodeCropperState.baseWidth * studentCodeCropperState.scale;
    const scaledHeight = studentCodeCropperState.baseHeight * studentCodeCropperState.scale;
    const maxOffsetX = Math.max(0, (scaledWidth - frameRect.width) / 2);
    const maxOffsetY = Math.max(0, (scaledHeight - frameRect.height) / 2);

    studentCodeCropperState.offsetX = Math.min(
        maxOffsetX,
        Math.max(-maxOffsetX, studentCodeCropperState.offsetX)
    );
    studentCodeCropperState.offsetY = Math.min(
        maxOffsetY,
        Math.max(-maxOffsetY, studentCodeCropperState.offsetY)
    );
}

function applyStudentCodeCropperTransform() {
    const { imageEl } = cropperElements();
    if (!imageEl) return;

    clampStudentCodeCropperOffset();
    const { offsetX, offsetY, scale } = studentCodeCropperState;
    imageEl.style.transform = `translate(-50%, -50%) translate(${offsetX}px, ${offsetY}px) scale(${scale})`;
}

function distanceBetweenPointers(points) {
    const [a, b] = points;
    return Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
}

function midpointBetweenPointers(points) {
    const [a, b] = points;
    return {
        x: (a.clientX + b.clientX) / 2,
        y: (a.clientY + b.clientY) / 2
    };
}

function setStudentCodeCropperScale(nextScale, anchorX, anchorY) {
    const { viewport } = cropperElements();
    if (!viewport) return;

    const previousScale = studentCodeCropperState.scale;
    const clampedScale = Math.min(
        studentCodeCropperState.maxScale,
        Math.max(studentCodeCropperState.minScale, nextScale)
    );
    if (previousScale === clampedScale) return;

    const viewportRect = viewport.getBoundingClientRect();
    const centerX = viewportRect.left + viewportRect.width / 2;
    const centerY = viewportRect.top + viewportRect.height / 2;
    const localAnchorX = anchorX - centerX;
    const localAnchorY = anchorY - centerY;
    const ratio = clampedScale / previousScale;

    studentCodeCropperState.offsetX = localAnchorX - (localAnchorX - studentCodeCropperState.offsetX) * ratio;
    studentCodeCropperState.offsetY = localAnchorY - (localAnchorY - studentCodeCropperState.offsetY) * ratio;
    studentCodeCropperState.scale = clampedScale;
    applyStudentCodeCropperTransform();
}

function handleStudentCodeCropperPointerDown(event) {
    const { viewport } = cropperElements();
    if (!viewport || !studentCodeCropperState.image) return;

    viewport.setPointerCapture?.(event.pointerId);
    studentCodeCropperState.pointers.set(event.pointerId, event);

    if (studentCodeCropperState.pointers.size === 1) {
        studentCodeCropperState.dragStartX = event.clientX;
        studentCodeCropperState.dragStartY = event.clientY;
        studentCodeCropperState.startOffsetX = studentCodeCropperState.offsetX;
        studentCodeCropperState.startOffsetY = studentCodeCropperState.offsetY;
    } else if (studentCodeCropperState.pointers.size === 2) {
        const points = Array.from(studentCodeCropperState.pointers.values());
        const midpoint = midpointBetweenPointers(points);
        studentCodeCropperState.pinchStartDistance = distanceBetweenPointers(points);
        studentCodeCropperState.pinchStartScale = studentCodeCropperState.scale;
        studentCodeCropperState.pinchStartMidX = midpoint.x;
        studentCodeCropperState.pinchStartMidY = midpoint.y;
        studentCodeCropperState.startOffsetX = studentCodeCropperState.offsetX;
        studentCodeCropperState.startOffsetY = studentCodeCropperState.offsetY;
    }
}

function handleStudentCodeCropperPointerMove(event) {
    if (!studentCodeCropperState.pointers.has(event.pointerId)) return;
    studentCodeCropperState.pointers.set(event.pointerId, event);

    if (studentCodeCropperState.pointers.size === 1) {
        studentCodeCropperState.offsetX = studentCodeCropperState.startOffsetX + event.clientX - studentCodeCropperState.dragStartX;
        studentCodeCropperState.offsetY = studentCodeCropperState.startOffsetY + event.clientY - studentCodeCropperState.dragStartY;
        applyStudentCodeCropperTransform();
        return;
    }

    if (studentCodeCropperState.pointers.size === 2) {
        const points = Array.from(studentCodeCropperState.pointers.values());
        const midpoint = midpointBetweenPointers(points);
        const distance = distanceBetweenPointers(points);
        const nextScale = studentCodeCropperState.pinchStartScale * (distance / studentCodeCropperState.pinchStartDistance);
        const clampedScale = Math.min(
            studentCodeCropperState.maxScale,
            Math.max(studentCodeCropperState.minScale, nextScale)
        );

        studentCodeCropperState.scale = clampedScale;
        studentCodeCropperState.offsetX = studentCodeCropperState.startOffsetX + midpoint.x - studentCodeCropperState.pinchStartMidX;
        studentCodeCropperState.offsetY = studentCodeCropperState.startOffsetY + midpoint.y - studentCodeCropperState.pinchStartMidY;
        applyStudentCodeCropperTransform();
    }
}

function handleStudentCodeCropperPointerEnd(event) {
    studentCodeCropperState.pointers.delete(event.pointerId);
    if (studentCodeCropperState.pointers.size === 1) {
        const [remaining] = Array.from(studentCodeCropperState.pointers.values());
        studentCodeCropperState.dragStartX = remaining.clientX;
        studentCodeCropperState.dragStartY = remaining.clientY;
        studentCodeCropperState.startOffsetX = studentCodeCropperState.offsetX;
        studentCodeCropperState.startOffsetY = studentCodeCropperState.offsetY;
    }
}

function handleStudentCodeCropperWheel(event) {
    if (!studentCodeCropperState.image) return;
    event.preventDefault();
    const direction = event.deltaY > 0 ? -1 : 1;
    setStudentCodeCropperScale(
        studentCodeCropperState.scale * (direction > 0 ? 1.08 : 0.92),
        event.clientX,
        event.clientY
    );
}

function createCroppedStudentCodeImage() {
    const { viewport, frame } = cropperElements();
    const image = studentCodeCropperState.image;
    if (!viewport || !frame || !image) throw new Error('CROPPER_NOT_READY');

    const viewportRect = viewport.getBoundingClientRect();
    const frameRect = frame.getBoundingClientRect();
    const displayScale = (studentCodeCropperState.baseWidth * studentCodeCropperState.scale) / image.naturalWidth;
    if (!frameRect.width || !frameRect.height || !displayScale || !Number.isFinite(displayScale)) {
        throw new Error('CROPPER_NOT_READY');
    }
    const imageLeft = viewportRect.left + viewportRect.width / 2 + studentCodeCropperState.offsetX
        - (studentCodeCropperState.baseWidth * studentCodeCropperState.scale) / 2;
    const imageTop = viewportRect.top + viewportRect.height / 2 + studentCodeCropperState.offsetY
        - (studentCodeCropperState.baseHeight * studentCodeCropperState.scale) / 2;
    const sourceX = Math.max(0, (frameRect.left - imageLeft) / displayScale);
    const sourceY = Math.max(0, (frameRect.top - imageTop) / displayScale);
    const sourceWidth = Math.min(image.naturalWidth - sourceX, frameRect.width / displayScale);
    const sourceHeight = Math.min(image.naturalHeight - sourceY, frameRect.height / displayScale);

    const canvas = document.createElement('canvas');
    canvas.width = STUDENT_CODE_CROP_OUTPUT_WIDTH;
    canvas.height = STUDENT_CODE_CROP_OUTPUT_HEIGHT;
    const context = canvas.getContext('2d');
    context.fillStyle = '#FFFFFF';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.imageSmoothingEnabled = false;
    context.drawImage(image, sourceX, sourceY, sourceWidth, sourceHeight, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/png');
}

function saveStudentCodeCrop() {
    try {
        const croppedDataUrl = createCroppedStudentCodeImage();
        localStorage.setItem(STUDENT_CODE_IMAGE_KEY, croppedDataUrl);
        localStorage.removeItem(STUDENT_NAME_KEY);
        renderStudentCodeCard();
        closeStudentCodeEditor();
    } catch (error) {
        console.error('Student code crop save failed:', error);
        setStudentCodeUploadStatus('편집한 이미지를 저장하지 못했습니다. 다시 시도해 주세요.');
    }
}

function showSchedule() {
    showOfflineUI(false);

    const mealContainer = document.getElementById('meal-container');
    const timetableContainer = document.getElementById('timetable-container');
    const scheduleContainer = document.getElementById('schedule-container');

    if (mealContainer) mealContainer.style.display = 'none';
    if (timetableContainer) timetableContainer.style.display = 'none';
    if (scheduleContainer) scheduleContainer.style.display = 'block';

    const btns = ['btn-today', 'btn-week', 'btn-timetable', 'btn-schedule'];
    btns.forEach(id => {
        const btn = document.getElementById(id);
        if (btn) btn.classList.toggle('active', id === 'btn-schedule');
    });

    updateScheduleHeader();
    renderScheduleList();
}

function showMeals(type) {
    if (!navigator.onLine) {
        showOfflineUI(true);
        return;
    }
    showOfflineUI(false);

    const targetDate = new Date();

    if (type === 'week') {
        showWeeklyMeals(new Date());
    } else {
        mealViewMode = type === 'tomorrow' ? 'tomorrow' : 'today';
        if (mealViewMode === 'tomorrow') {
            targetDate.setDate(targetDate.getDate() + 1);
        }

        document.getElementById('meal-container').style.display = 'block';
        document.getElementById('timetable-container').style.display = 'none';
        const scheduleContainer = document.getElementById('schedule-container');
        if (scheduleContainer) scheduleContainer.style.display = 'none';
        const mealToolbarCard = document.getElementById('meal-toolbar-card');
        if (mealToolbarCard) mealToolbarCard.style.display = 'block';

        const btnToday = document.getElementById('btn-today');
        const btnSchedule = document.getElementById('btn-schedule');
        const btnWeek = document.getElementById('btn-week');
        const btnTimetable = document.getElementById('btn-timetable');

        if (btnToday) btnToday.classList.toggle('active', true);
        if (btnSchedule) btnSchedule.classList.toggle('active', false);
        if (btnWeek) btnWeek.classList.toggle('active', false);
        if (btnTimetable) btnTimetable.classList.toggle('active', false);
        updateMealSwitchUI(mealViewMode);
        renderStudentCodeCard();
        renderAfterschoolTodayCard(targetDate, mealViewMode);

        // 타이틀 접두사 제거 (카카오 스타일은 심플함이 생명)
        setText('lunch-title', `중식`);
        setText('dinner-title', `석식`);

        fetchMeals(targetDate);
    }
}

// 과목명 매핑 딕셔너리
const SUBJECT_ALIASES = {
    "공통국어1": "국어",
    "공통국어2": "국어",
    "화법과 언어": "국어",
    "국1": "국어",
    "국2": "국어",
    "문1": "문학",

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
    "국사": "한국사",

    "통합사회1": "사회",
    "통합사회2": "사회",

    "통합과학1": "과학",
    "통합과학2": "과학",
    "과1": "과학",

    "체육1": "체육",
    "체육2": "체육",
    "운동": "체육",

    "진로활동": "진로",
    "동아리활동": "동아리",
    "창의적 체험활동": "창체",
    "자율": "자율",

    "정보 처리와 관리": "정보 처리",
    "SSQL": "SQL",

    "베이스·클리어 도장 작업": "자동차도장",
    "자동차 등화장치 정비": "자동차정비",
    "기관": "자동차 기관",
    "전정": "자동차 전기전자 정비",
    "섀정": "자동차 섀시 정비",
    "회로": "전기회로",
    "도장": "자동차도장",

    // 추가 매핑
    "프1": "프로그래밍",
    "디일": "디자인 일반",
    "응개": "응용프로그래밍 개발",
    "응1" : "응용프로그래밍",
    "엔정": "엔진 정비",
    "전차": "전기전자 장비정비",
    "전기": "전기회로",
    "차정": "차체 정비",
    "주행": "자율주행",
    "섀시": "자동차 섀시",
    "화1": "화면구현",
    "튜1": "튜닝",
    "컴그": "컴퓨터 그래픽스",
    //모름 예상
    "엔진": "엔진 정비",
    "전장": "전기전자 장비정비",
};

SCHEDULE_EVENTS = parseScheduleSource(SCHEDULE_SOURCE);

function cleanTimetableSubject(rawName) {
    return normalizeScheduleTitle(String(rawName || '').replace(/\*/g, '').trim());
}

function decodeSubject(rawName) {
    const trimmed = cleanTimetableSubject(rawName);
    if (!trimmed) return "공강";
    return trimmed;
}

function loadClassTimetable2026() {
    if (!classTimetable2026Promise) {
        classTimetable2026ImportStatus = 'loading';
        classTimetable2026Promise = import(`${CLASS_TIMETABLE_RUNTIME_PATH}?v=${CLASS_TIMETABLE_VERSION}`)
            .then((module) => {
                classTimetable2026ImportStatus = 'success';
                console.debug('Class timetable fallback import success', {
                    path: CLASS_TIMETABLE_RUNTIME_PATH,
                    version: CLASS_TIMETABLE_VERSION
                });
                return module.classTimetable2026 || {};
            })
            .catch((error) => {
                classTimetable2026ImportStatus = 'fail';
                console.error('Class timetable fallback import failed:', error);
                console.warn('Class timetable fallback load failed:', error);
                return {};
            });
    }

    return classTimetable2026Promise;
}

async function fetchTimetable(grade, classNum, targetDate) {
    const ymd = formatDate(targetDate);
    const url = buildNeisUrl('hisTimetable', {
        ALL_TI_YMD: ymd,
        GRADE: grade,
        CLASS_NM: classNum,
        pSize: 100
    });

    try {
        console.debug('Timetable API request', {
            url,
            grade,
            classNum,
            date: ymd,
            schoolCode: NEIS_SCHOOL_CODE,
            officeCode: NEIS_OFFICE_CODE
        });

        const response = await fetch(url);
        if (!response.ok) throw new Error('Timetable API 응답 오류');
        
        const data = await response.json();
        console.debug('Timetable API raw response JSON', data);

        const rows = extractTimetableRows(data);
        console.debug('Timetable API extracted rows before merge', {
            count: rows.length,
            rows
        });

        const uniqueRows = [];
        const seenPeriods = new Set();
        const skippedRows = [];

        rows.forEach(row => {
            if (!row?.PERIO) {
                skippedRows.push({ reason: 'missing-period', row });
                return;
            }
            if (seenPeriods.has(row.PERIO)) {
                skippedRows.push({ reason: 'duplicate-period', row });
                return;
            }

            seenPeriods.add(row.PERIO);
            uniqueRows.push({
                period: row.PERIO,                 // 교시
                originalSubject: row.ITRT_CNTNT,   // API 원본 과목명
                subject: decodeSubject(row.ITRT_CNTNT) // 변환된 친숙한 과목명
            });
        });

        const parsedRows = uniqueRows.sort((a, b) => Number(a.period) - Number(b.period));
        console.debug('Timetable API parsed rows before merge', {
            count: parsedRows.length,
            rows: parsedRows,
            skippedRows,
            emptyReason: rows.length === 0
                ? 'api-response-empty-or-no-row-section'
                : parsedRows.length === 0
                    ? 'parsing-or-filtering-removed-all-rows'
                    : null
        });

        return parsedRows;
    } catch (e) {
        console.warn('Timetable fetch failed:', e);
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
    return `${targetDate.getMonth() + 1}/${targetDate.getDate()} (${TIMETABLE_DAYS[targetDate.getDay()]})`;
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

function renderTimetableRows(rows, targetDate, titleText = '오늘 시간표') {
    if (rows === null) {
        return '<div class="timetable-empty">데이터를 불러오지 못했습니다.</div>';
    }

    const normalizedRows = rows;
    if (normalizedRows.length === 0) {
        return `<div class="timetable-empty">${escapeHTML(titleText)} 정보가 없습니다.</div>`;
    }

    return normalizedRows.map(row => {
        if (row.source === 'holiday') {
            return `<div class="timetable-empty timetable-holiday">${escapeHTML(row.subject)}입니다.</div>`;
        }

        return `
            <div class="timetable-row ${row.source === 'fallback' ? 'is-fallback' : ''}">
                <span class="period">${row.period}교시</span>
                <span class="subject">${escapeHTML(row.subject)}</span>
                ${row.source === 'fallback' ? '<span class="timetable-source-badge">보정 시간표</span>' : ''}
            </div>
        `;
    }).join('');
}

function updateTimetableHeader(titleText, targetDate, nextButtonText) {
    const titleEl = document.getElementById('timetable-title');
    const dateEl = document.getElementById('timetable-date-label');
    const buttonEl = document.getElementById('btn-timetable-switch');

    if (titleEl) titleEl.textContent = titleText;
    if (dateEl) dateEl.textContent = formatTimetableDateLabel(targetDate);
    if (buttonEl) buttonEl.textContent = nextButtonText;
}

function registerAppEventHandlers() {
    const clickHandlers = [
        ['btn-share', shareApp],
        ['btn-today', () => showMeals('today')],
        ['btn-week', () => showMeals('week')],
        ['btn-timetable', showTimetable],
        ['btn-schedule', () => {
            scheduleViewMode = 'current';
            showSchedule();
        }],
        ['btn-meal-switch', toggleMealView],
        ['btn-schedule-switch', toggleScheduleView],
        ['btn-close-student-code', closeStudentCodeModal],
        ['btn-cancel-student-code-edit', closeStudentCodeEditor],
        ['btn-save-student-code-crop', saveStudentCodeCrop],
        ['btn-theme', toggleTheme],
        ['btn-retry', () => window.location.reload()]
    ];

    clickHandlers.forEach(([id, handler]) => {
        const element = document.getElementById(id);
        if (element) element.addEventListener('click', handler);
    });

    ['grade-select', 'class-select'].forEach((id) => {
        const element = document.getElementById(id);
        if (element) element.addEventListener('change', updateTimetable);
    });

    const modal = document.getElementById('student-code-modal');
    if (modal) {
        modal.addEventListener('click', (event) => {
            if (event.target === modal) {
                closeStudentCodeModal();
            }
        });
    }

    const studentCodeInlineImageWrap = document.getElementById('student-code-inline-image-wrap');
    if (studentCodeInlineImageWrap) {
        studentCodeInlineImageWrap.addEventListener('click', () => {
            if (getStoredStudentCodeImage()) {
                openStudentCodeModal();
            }
        });
    }

    const studentCodeImageInput = document.getElementById('student-code-image-input');
    if (studentCodeImageInput) {
        studentCodeImageInput.addEventListener('change', handleStudentCodeImageUpload);
    }

    const studentCodeCropper = document.getElementById('student-code-cropper');
    if (studentCodeCropper) {
        studentCodeCropper.addEventListener('pointerdown', handleStudentCodeCropperPointerDown);
        studentCodeCropper.addEventListener('pointermove', handleStudentCodeCropperPointerMove);
        studentCodeCropper.addEventListener('pointerup', handleStudentCodeCropperPointerEnd);
        studentCodeCropper.addEventListener('pointercancel', handleStudentCodeCropperPointerEnd);
        studentCodeCropper.addEventListener('wheel', handleStudentCodeCropperWheel, { passive: false });
    }

    window.addEventListener('resize', () => {
        if (studentCodeCropperState.image) resetStudentCodeCropperTransform();
    });

    window.addEventListener('pagehide', disableBarcodeScanMode);
    window.addEventListener('beforeunload', disableBarcodeScanMode);
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden') {
            disableBarcodeScanMode();
        } else if (isStudentCodeModalOpen()) {
            enableBarcodeScanMode();
        }
    });
}

function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) {
        return;
    }

    window.addEventListener('load', () => {
        navigator.serviceWorker.register('sw.js').catch((error) => {
            console.warn('Service worker registration failed:', error);
        });
    });
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

function getFallbackTimetableRows(classTimetable2026, grade, classNum, targetDate) {
    const selectedClassKey = `${grade}-${classNum}`;
    const dayName = TIMETABLE_DAYS[targetDate.getDay()];
    const subjects = classTimetable2026?.[selectedClassKey]?.[dayName];

    if (!Array.isArray(subjects)) {
        return [];
    }

    return TIMETABLE_PERIODS.map((period, index) => ({
        period,
        originalSubject: subjects[index] || '',
        subject: decodeSubject(subjects[index] || '공강'),
        source: 'fallback'
    }));
}

function mergeTimetableWithFallback(neisRows, fallbackRows) {
    const neisMap = new Map(
        (Array.isArray(neisRows) ? neisRows : [])
            .filter(row => row?.period && row?.subject && row.subject !== '공강')
            .map(row => [Number(row.period), { ...row, source: 'neis' }])
    );
    const fallbackMap = new Map(fallbackRows.map(row => [Number(row.period), row]));

    return TIMETABLE_PERIODS.map((period) => {
        return neisMap.get(period) || fallbackMap.get(period) || {
            period,
            originalSubject: '',
            subject: '공강',
            source: 'empty'
        };
    });
}

function getTimetableHolidayTitle(targetDate, neisRows) {
    const apiHolidayRow = (Array.isArray(neisRows) ? neisRows : [])
        .find(row => isHolidayScheduleTitle(row?.subject || row?.originalSubject));
    if (apiHolidayRow) {
        return normalizeScheduleTitle(apiHolidayRow.subject || apiHolidayRow.originalSubject);
    }

    const scheduleHolidayEvent = getHolidayEventForDate(targetDate);
    return scheduleHolidayEvent ? getScheduleEventName(scheduleHolidayEvent) : '';
}

function logTimetableMergeSummary(neisRows, fallbackRows, displayRows) {
    const neisPeriodsCount = (Array.isArray(neisRows) ? neisRows : [])
        .filter(row => row?.period && row?.subject && row.subject !== '공강')
        .length;
    const fallbackPeriodsCount = (Array.isArray(fallbackRows) ? fallbackRows : [])
        .filter(row => row?.period && row?.subject && row.subject !== '공강')
        .length;
    const finalMergedTimetableCount = (Array.isArray(displayRows) ? displayRows : [])
        .filter(row => row?.period && row?.subject && row.subject !== '공강')
        .length;
    const fallbackPeriods = (Array.isArray(displayRows) ? displayRows : [])
        .filter(row => row?.source === 'fallback')
        .map(row => Number(row.period))
        .sort((a, b) => a - b);

    console.debug('Timetable merge summary', {
        neisPeriodsCount,
        fallbackPeriodsCount,
        finalMergedTimetableCount,
        fallbackPeriods,
        fallbackImportStatus: classTimetable2026ImportStatus
    });
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

    const [rows, classTimetable2026] = await Promise.all([
        fetchTimetable(grade, classNum, targetDate),
        loadClassTimetable2026()
    ]);
    const holidayTitle = getTimetableHolidayTitle(targetDate, rows);
    const fallbackRows = holidayTitle
        ? []
        : getFallbackTimetableRows(classTimetable2026, grade, classNum, targetDate);
    const displayRows = holidayTitle
        ? [{ subject: holidayTitle, source: 'holiday' }]
        : fallbackRows.length > 0
        ? mergeTimetableWithFallback(rows, fallbackRows)
        : rows;
    console.debug('Timetable render rows', {
        grade,
        classNum,
        date: formatDate(targetDate),
        schoolCode: NEIS_SCHOOL_CODE,
        officeCode: NEIS_OFFICE_CODE,
        fallbackImportStatus: classTimetable2026ImportStatus,
        rawNeisRows: rows,
        rawFallbackRows: fallbackRows,
        holidayTitle,
        finalDisplayRows: displayRows,
        apiRowsVisibleCount: (Array.isArray(displayRows) ? displayRows : [])
            .filter(row => row?.source === 'neis')
            .length
    });
    logTimetableMergeSummary(rows, fallbackRows, displayRows);

    updateTimetableHeader(titleText, targetDate, buttonText);
    container.innerHTML = renderTimetableRows(displayRows, targetDate, titleText);
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
    const scheduleContainer = document.getElementById('schedule-container');
    if (scheduleContainer) scheduleContainer.style.display = 'none';

    const btns = ['btn-today', 'btn-week', 'btn-timetable', 'btn-schedule'];
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

function getAndroidAppBridge() {
    return window.GHASAndroidApp || window.GHASAndroidNotifications;
}

function getThemeCookie() {
    return document.cookie
        .split('; ')
        .find((row) => row.startsWith('theme='))
        ?.split('=')[1];
}

function getSavedThemePreference() {
    try {
        const localTheme = localStorage.getItem('theme');
        if (localTheme === 'dark' || localTheme === 'light') return localTheme;
    } catch (error) {
        console.warn('Theme preference read failed:', error);
    }

    try {
        const nativeTheme = getAndroidAppBridge()?.getTheme?.();
        if (nativeTheme === 'dark' || nativeTheme === 'light') return nativeTheme;
    } catch (error) {
        console.warn('Native theme preference read failed:', error);
    }

    const cookieTheme = getThemeCookie();
    return cookieTheme === 'dark' || cookieTheme === 'light' ? cookieTheme : null;
}

function saveThemePreference(theme) {
    try {
        localStorage.setItem('theme', theme);
    } catch (error) {
        console.warn('Theme preference save failed:', error);
    }

    document.cookie = `theme=${theme}; Max-Age=31536000; Path=/; SameSite=Lax; Secure`;

    try {
        getAndroidAppBridge()?.setTheme?.(theme);
    } catch (error) {
        console.warn('Native theme preference save failed:', error);
    }
}

function applyThemePreference(theme) {
    const themeBtn = document.getElementById('btn-theme');
    const isDark = theme === 'dark';
    const isLight = theme === 'light';

    document.documentElement.classList.toggle('dark-theme', isDark);
    document.documentElement.classList.toggle('light-theme', isLight);
    document.body.classList.toggle('dark-theme', isDark);
    document.body.classList.toggle('light-theme', isLight);

    if (themeBtn && (isDark || isLight)) {
        themeBtn.textContent = isDark ? '🌙' : '☀️';
    }
}

function animateThemeButton() {
    const themeBtn = document.getElementById('btn-theme');
    if (!themeBtn) return;

    themeBtn.classList.remove('theme-toggle-animate');
    void themeBtn.offsetWidth;
    themeBtn.classList.add('theme-toggle-animate');
}

function toggleTheme() {
    const body = document.body;
    const isDark = body.classList.contains('dark-theme') ||
        (!body.classList.contains('light-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
    const nextTheme = isDark ? 'light' : 'dark';

    animateThemeButton();
    applyThemePreference(nextTheme);
    saveThemePreference(nextTheme);
}

function initTheme() {
    const savedTheme = getSavedThemePreference();
    const themeBtn = document.getElementById('btn-theme');
    if (savedTheme === 'dark') {
        applyThemePreference('dark');
    } else if (savedTheme === 'light') {
        applyThemePreference('light');
    } else {
        // System preference
        const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        if (themeBtn) themeBtn.textContent = isDark ? '🌙' : '☀️';
    }
}

// Realtime Database 기반 누적 방문자 카운터 초기화
function initVisitorCounter() {
    // 같은 로드 안에서 중복 호출 시 두 번 증가하지 않도록 인메모리 가드로 막는다.
    // 새로고침·새 WebView/탭 로드에서는 이 플래그가 초기화되므로 매 로드마다 1회 집계된다.
    if (visitorCountIncrementStarted) {
        return;
    }
    visitorCountIncrementStarted = true;

    const counterEl = document.getElementById('visitor-counter');
    const countEl = document.getElementById('visit-count');
    const labelEl = document.getElementById('visitor-label');
    let hasRenderedCount = false;

    const renderCount = (rawCount) => {
        hasRenderedCount = true;
        if (counterEl) counterEl.style.display = 'block';
        if (labelEl) labelEl.textContent = '누적 방문자: ';
        // RTDB 에 저장된 누적값을 그대로 표시한다 (표시 보정값 없음).
        const total = Number(rawCount || 0);
        if (countEl) countEl.textContent = total.toLocaleString();
    };

    const showUnavailable = () => {
        if (hasRenderedCount) return;
        if (counterEl) counterEl.style.display = 'block';
        if (labelEl) labelEl.textContent = '누적 방문자: ';
        if (countEl) countEl.textContent = '확인 불가';
    };

    if (typeof firebase === 'undefined' || !firebase.database) {
        showUnavailable();
        return;
    }

    let visitRef;
    try {
        if (!firebase.apps.length) {
            firebase.initializeApp(FIREBASE_CONFIG);
        }
        visitRef = firebase.database().ref('stats/visitCount');
    } catch (error) {
        console.error('Firebase 초기화 실패:', error);
        showUnavailable();
        return;
    }

    // 트랜잭션으로 원자적 +1 증가 → 동시 방문에도 집계 손실이 없다.
    // 보안 규칙에서 정확히 +1 만 허용하므로 다른 조작은 거부된다.
    // 매 페이지 로드마다 1회 실행되며, 브라우저 저장소 가드는 사용하지 않는다.
    visitRef.transaction(
        (currentValue) => {
            const currentCount = Number(currentValue) || 0;
            return currentCount + 1;
        },
        (error, committed, snapshot) => {
            if (error) {
                console.warn('Visit count increment failed:', error);
                showUnavailable();
                return;
            }
            if (committed && snapshot) {
                // 트랜잭션이 커밋한 서버 값(= 이전 값 + 1)을 표시한다.
                renderCount(snapshot.val());
            } else {
                showUnavailable();
            }
        }
    );
}

// 초기화 호출
registerServiceWorker();
registerAppEventHandlers();
initTheme();
showMeals('today');
initVisitorCounter();
