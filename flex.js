const NEIS_BASE_URL = "https://open.neis.go.kr/hub/";
const NEIS_OFFICE_CODE = "J10";
const NEIS_SCHOOL_CODE = "7530908";
const BARCODE_KEY = "ghas-student-code-image";
const GRADE_KEY = "ghas-grade";
const CLASS_KEY = "ghas-class";
const TIMETABLE_PATH = "./src/data/classTimetable2026.js";
const TIMETABLE_VERSION = "20260611-flex";
const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];
const PERIOD_TIMES = [
    { period: 1, start: "09:00", end: "09:50" },
    { period: 2, start: "10:00", end: "10:50" },
    { period: 3, start: "11:00", end: "11:50" },
    { period: 4, start: "12:00", end: "12:50" },
    { period: 5, start: "13:50", end: "14:40" },
    { period: 6, start: "14:50", end: "15:40" },
    { period: 7, start: "15:50", end: "16:40" }
];

const SUBJECT_ALIASES = {
    국사: "한국사",
    국1: "국어",
    국2: "국어",
    문1: "문학",
    대수: "수학",
    과1: "과학",
    운동: "체육",
    기관: "자동차 기관",
    전정: "자동차 전기전자 정비",
    섀정: "자동차 섀시 정비",
    회로: "전기회로",
    도장: "자동차도장",
    프1: "프로그래밍",
    디일: "디자인 일반",
    응개: "응용프로그래밍 개발",
    응1: "응용프로그래밍",
    엔정: "엔진 정비",
    전차: "전기전자 장비정비",
    전기: "전기회로",
    차정: "차체 정비",
    주행: "자율주행",
    섀시: "자동차 섀시",
    화1: "화면구현",
    튜1: "튜닝",
    컴그: "컴퓨터 그래픽스"
};

const state = {
    activeTab: "meal",
    barcode: "",
    grade: "",
    classNum: "",
    timetableLoaded: false
};

function byId(id) {
    return document.getElementById(id);
}

function safeStorageGet(key) {
    try {
        return localStorage.getItem(key) || "";
    } catch (error) {
        return "";
    }
}

function formatYmd(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}${month}${day}`;
}

function buildNeisUrl(endpoint, params) {
    const url = new URL(endpoint, NEIS_BASE_URL);
    url.searchParams.set("Type", "json");
    url.searchParams.set("ATPT_OFCDC_SC_CODE", NEIS_OFFICE_CODE);
    url.searchParams.set("SD_SCHUL_CODE", NEIS_SCHOOL_CODE);
    Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== "") {
            url.searchParams.set(key, value);
        }
    });
    return url.toString();
}

function setTodayHeader() {
    const now = new Date();
    byId("today-date").textContent = now.toLocaleDateString("ko-KR", {
        month: "short",
        day: "numeric",
        weekday: "short"
    });
    byId("timetable-date").textContent = `${now.getMonth() + 1}/${now.getDate()} ${WEEKDAYS[now.getDay()]}`;
}

function readUserState() {
    state.grade = safeStorageGet(GRADE_KEY);
    state.classNum = safeStorageGet(CLASS_KEY);
    state.barcode = safeStorageGet(BARCODE_KEY);

    const classStatus = byId("class-status");
    if (state.grade && state.classNum) {
        classStatus.textContent = `${state.grade}학년 ${state.classNum}반`;
        classStatus.hidden = false;
    }
}

function cleanMealItems(rawMenu) {
    return String(rawMenu || "")
        .split(/<br\s*\/?>/gi)
        .map((item) => item
            .replace(/\([^)]*\)/g, "")
            .replace(/\d+(?:\.\d+)*/g, "")
            .replace(/\s{2,}/g, " ")
            .trim())
        .filter(Boolean);
}

function renderMealItems(element, rawMenu, emptyMessage) {
    const items = cleanMealItems(rawMenu);
    if (!items.length) {
        element.textContent = emptyMessage;
        return;
    }

    const fragment = document.createDocumentFragment();
    items.forEach((item, index) => {
        if (index > 0) fragment.append(document.createElement("br"));
        fragment.append(document.createTextNode(item));
    });
    element.replaceChildren(fragment);
}

function extractRows(data, sectionName) {
    const section = Array.isArray(data?.[sectionName])
        ? data[sectionName].find((item) => Array.isArray(item.row))
        : null;
    return section?.row || [];
}

async function loadMeals() {
    const lunchMenu = byId("lunch-menu");
    const dinnerMenu = byId("dinner-menu");
    const note = byId("meal-note");
    lunchMenu.textContent = "급식을 불러오는 중...";
    dinnerMenu.textContent = "급식을 불러오는 중...";
    byId("lunch-calorie").textContent = "";
    byId("dinner-calorie").textContent = "";
    note.textContent = "";

    try {
        const response = await fetch(buildNeisUrl("mealServiceDietInfo", {
            MLSV_YMD: formatYmd(new Date()),
            pSize: 20
        }));
        if (!response.ok) throw new Error("Meal request failed");
        const rows = extractRows(await response.json(), "mealServiceDietInfo");
        const lunch = rows.find((row) => row.MMEAL_SC_CODE === "2");
        const dinner = rows.find((row) => row.MMEAL_SC_CODE === "3");

        renderMealItems(lunchMenu, lunch?.DDISH_NM, "중식 정보가 없어요.");
        renderMealItems(dinnerMenu, dinner?.DDISH_NM, "석식 정보가 없어요.");
        byId("lunch-calorie").textContent = lunch?.CAL_INFO || "";
        byId("dinner-calorie").textContent = dinner?.CAL_INFO || "";
    } catch (error) {
        lunchMenu.textContent = "급식 정보를 불러오지 못했어요.";
        dinnerMenu.textContent = "네트워크 연결을 확인해 주세요.";
        note.textContent = "새로고침 버튼으로 다시 시도할 수 있어요.";
    }
}

function decodeSubject(subject) {
    const clean = String(subject || "").replace(/\*/g, "").trim();
    return SUBJECT_ALIASES[clean] || clean || "공강";
}

async function loadFallbackTimetable() {
    const module = await import(`${TIMETABLE_PATH}?v=${TIMETABLE_VERSION}`);
    const timetable = module.classTimetable2026 || {};
    const classKey = `${state.grade}-${state.classNum}`;
    const dayName = WEEKDAYS[new Date().getDay()];
    const subjects = timetable[classKey]?.[dayName];

    if (!Array.isArray(subjects)) return [];
    return subjects.map((subject, index) => ({
        period: index + 1,
        subject: decodeSubject(subject),
        source: "fallback"
    }));
}

function minutesNow() {
    const now = new Date();
    return now.getHours() * 60 + now.getMinutes();
}

function timeToMinutes(value) {
    const [hour, minute] = value.split(":").map(Number);
    return hour * 60 + minute;
}

function getActiveClass(rows) {
    const now = minutesNow();
    const withClass = PERIOD_TIMES.map((time) => ({
        ...time,
        subject: rows.find((row) => row.period === time.period)?.subject || "공강"
    }));
    const current = withClass.find((item) => now >= timeToMinutes(item.start) && now <= timeToMinutes(item.end));
    if (current) return { ...current, label: "현재 수업" };

    const next = withClass.find((item) => now < timeToMinutes(item.start) && item.subject !== "공강");
    if (next) return { ...next, label: "다음 수업" };
    return null;
}

function renderTimetable(rows) {
    const list = byId("timetable-list");
    const active = getActiveClass(rows);

    if (new Date().getDay() === 0 || new Date().getDay() === 6) {
        list.innerHTML = '<p class="empty-state">주말 및 휴일입니다.</p>';
        byId("now-label").textContent = "오늘은";
        byId("now-subject").textContent = "수업이 없어요";
        byId("now-period").textContent = "휴일";
        return;
    }

    if (!rows.length) {
        list.innerHTML = '<p class="empty-state">오늘 시간표 정보가 없습니다.</p>';
        return;
    }

    list.replaceChildren(...rows.map((row) => {
        const item = document.createElement("div");
        item.className = `timetable-row${active?.period === row.period ? " is-current" : ""}`;
        const period = document.createElement("span");
        period.textContent = `${row.period}교시`;
        const subject = document.createElement("strong");
        subject.textContent = row.subject;
        item.append(period, subject);
        return item;
    }));

    if (active) {
        byId("now-label").textContent = active.label;
        byId("now-subject").textContent = active.subject;
        byId("now-period").textContent = `${active.period}교시`;
    } else {
        byId("now-label").textContent = "오늘 수업";
        byId("now-subject").textContent = "모든 수업이 끝났어요";
        byId("now-period").textContent = "완료";
    }
}

async function loadTimetable() {
    if (state.timetableLoaded) return;
    state.timetableLoaded = true;
    const note = byId("timetable-note");

    if (!state.grade || !state.classNum) {
        note.textContent = "메인 앱의 시간표 탭에서 학년과 반을 선택해 주세요.";
        return;
    }

    byId("now-subject").textContent = "시간표를 불러오는 중...";
    try {
        const fallbackRows = await loadFallbackTimetable();
        renderTimetable(fallbackRows);
        note.textContent = fallbackRows.length ? "보정 시간표 기준" : "보정 시간표 정보가 없어요.";
    } catch (error) {
        console.error("Flex fallback timetable load failed:", error);
        renderTimetable([]);
        note.textContent = "보정 시간표를 불러오지 못했어요.";
    }
}

function setupBarcode() {
    const frame = byId("barcode-frame");
    const empty = byId("barcode-empty");
    const image = byId("barcode-image");
    const openButton = byId("open-barcode");
    const hint = byId("barcode-hint");

    if (!state.barcode) return;
    image.src = state.barcode;
    byId("barcode-focus-image").src = state.barcode;
    frame.hidden = false;
    empty.hidden = true;
    hint.hidden = false;
    openButton.disabled = false;
}

function setNativeBarcodeMode(enabled) {
    try {
        const bridge = window.GHASAndroidApp;
        const method = enabled ? "enableBarcodeScanMode" : "disableBarcodeScanMode";
        bridge?.[method]?.();
    } catch (error) {
        /* Native brightness control is optional. */
    }
}

function syncNativeBarcodeMode() {
    const shouldEnable = state.activeTab === "barcode"
        && document.visibilityState !== "hidden";
    setNativeBarcodeMode(shouldEnable);
}

function openBarcodeFocus() {
    if (!state.barcode) return;
    const focus = byId("barcode-focus");
    focus.classList.add("is-open");
    focus.setAttribute("aria-hidden", "false");
    document.body.classList.add("barcode-open");
    syncNativeBarcodeMode();
    byId("close-barcode").focus();
}

function closeBarcodeFocus() {
    const focus = byId("barcode-focus");
    focus.classList.remove("is-open");
    focus.setAttribute("aria-hidden", "true");
    document.body.classList.remove("barcode-open");
    syncNativeBarcodeMode();
    byId("open-barcode").focus();
}

function selectTab(tabName) {
    state.activeTab = tabName;
    document.querySelectorAll("[data-panel]").forEach((panel) => {
        const active = panel.dataset.panel === tabName;
        panel.hidden = !active;
        panel.classList.toggle("is-active", active);
    });
    document.querySelectorAll("[data-tab]").forEach((button) => {
        const active = button.dataset.tab === tabName;
        button.classList.toggle("is-active", active);
        button.setAttribute("aria-selected", String(active));
    });
    if (tabName === "timetable") loadTimetable();
    syncNativeBarcodeMode();
}

function registerEvents() {
    document.querySelectorAll("[data-tab]").forEach((button) => {
        button.addEventListener("click", () => selectTab(button.dataset.tab));
    });
    byId("refresh-meal").addEventListener("click", loadMeals);
    byId("open-barcode").addEventListener("click", openBarcodeFocus);
    byId("close-barcode").addEventListener("click", closeBarcodeFocus);
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && byId("barcode-focus").classList.contains("is-open")) {
            closeBarcodeFocus();
        }
    });
    window.addEventListener("pagehide", () => setNativeBarcodeMode(false));
    document.addEventListener("visibilitychange", () => {
        syncNativeBarcodeMode();
    });
}

setTodayHeader();
readUserState();
setupBarcode();
registerEvents();
loadMeals();
