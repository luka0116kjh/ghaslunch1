(function () {
    const SECTION_ID = "after-school-section";
    const UPDATE_NOTICE_TEXT = "2026 4차 방과후수업(취업역량강화)";
    const DAY_LABELS = ["월", "화", "수", "목", "금"];
    const DATA_VERSION = "2026-06-01-4th";
    const SELECTED_PROGRAM_KEY = "ghas-after-school-selected-program";
    const PROGRAM_ALIASES = {
        "오토테크니션심화A반": "오토테크니션심화반",
        "오토테크니션심화B반": "오토테크니션심화반",
        "오토테크니션심화C반": "오토테크니션심화반",
        "컴퓨터활용기초(1-8)": "1-8컴활",
        "컴퓨터활용기초1-8": "1-8컴활",
        "1-8 컴활": "1-8컴활"
    };
    const currentSchedule = Array.isArray(window.GHAS_AFTER_SCHOOL_SCHEDULES)
        ? window.GHAS_AFTER_SCHOOL_SCHEDULES[0]
        : null;

    const storedProgramName = readStoredProgramName();
    let selectedProgramName = normalizeProgramName(storedProgramName);

    const afterSchoolData = buildAfterSchoolData();

    const afterSchoolPrograms = afterSchoolData.programs
        .filter((program) => !String(program.name || "").includes("성합"));

    window.afterSchoolData = afterSchoolData;
    window.afterSchoolPrograms = afterSchoolPrograms;

    if (storedProgramName && selectedProgramName && storedProgramName !== selectedProgramName) {
        saveStoredProgramName(selectedProgramName);
    }

    function removeExistingSection() {
        const existingSection = document.getElementById(SECTION_ID);
        if (existingSection) {
            existingSection.remove();
        }
    }

    function buildAfterSchoolData() {
        const courseRooms = Array.isArray(currentSchedule?.courseRooms) ? currentSchedule.courseRooms : [];

        return {
            version: DATA_VERSION,
            status: currentSchedule ? "ready" : "missing",
            schedule: currentSchedule,
            programs: courseRooms.map((course) => {
                // 강좌별 운영일 (공학리더반 기준 캘린더에서 개별 휴강 제외한 날짜)
                const operatingDates = Array.isArray(course.operatingDates) ? course.operatingDates : [];
                return {
                    name: course.name,
                    classroom: course.room,
                    operatingDates,
                    days: getOperatingWeekdays(operatingDates)
                };
            })
        };
    }

    function readStoredProgramName() {
        try {
            return window.localStorage?.getItem(SELECTED_PROGRAM_KEY) || "";
        } catch (error) {
            return "";
        }
    }

    function saveStoredProgramName(name) {
        try {
            window.localStorage?.setItem(SELECTED_PROGRAM_KEY, name);
        } catch (error) {
            /* 저장 실패는 화면 표시에는 영향이 없다. */
        }
    }

    function normalizeProgramName(name) {
        const normalized = String(name || "").trim().replace(/\s+/g, "");
        if (!normalized) return "";

        const aliasKey = Object.keys(PROGRAM_ALIASES).find((key) => key.replace(/\s+/g, "") === normalized);
        if (aliasKey) return PROGRAM_ALIASES[aliasKey];

        const matchedProgram = currentSchedule?.courseRooms?.find((course) => {
            return String(course.name || "").trim().replace(/\s+/g, "") === normalized;
        });

        return matchedProgram?.name || String(name || "").trim();
    }

    function formatDateHyphen(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, "0");
        const d = String(date.getDate()).padStart(2, "0");
        return `${y}-${m}-${d}`;
    }

    function getOperatingWeekdays(dates) {
        const weekdays = new Set();
        dates.forEach((ymd) => {
            const [year, month, day] = String(ymd).split("-").map(Number);
            const date = new Date(year, month - 1, day);
            const label = DAY_LABELS[date.getDay() - 1];
            if (label) weekdays.add(label);
        });
        return DAY_LABELS.filter((label) => weekdays.has(label));
    }

    function createDateFromYmd(ymd) {
        const [year, month, day] = String(ymd || "").split("-").map(Number);
        if (!year || !month || !day) return new Date();
        return new Date(year, month - 1, day);
    }

    function addDays(date, days) {
        const nextDate = new Date(date);
        nextDate.setDate(nextDate.getDate() + days);
        return nextDate;
    }

    function getWeekdayDates(baseDate) {
        const referenceDate = new Date(baseDate);
        const day = referenceDate.getDay();
        const mondayOffset = day === 6 ? 2 : day === 0 ? 1 : 1 - day;
        const monday = addDays(referenceDate, mondayOffset);

        return DAY_LABELS.map((label, index) => {
            const date = addDays(monday, index);
            return {
                label,
                date,
                ymd: formatDateHyphen(date)
            };
        });
    }

    function getReferenceDate() {
        return createDateFromYmd(window.GHAS_AFTER_SCHOOL_REFERENCE_DATE || formatDateHyphen(new Date()));
    }

    // 선택된 강좌의 운영일. 미선택 시 스케줄 전체(합집합)로 폴백.
    function getProgramOperatingDates(program) {
        if (program && Array.isArray(program.operatingDates)) return program.operatingDates;
        return Array.isArray(currentSchedule?.operatingDates) ? currentSchedule.operatingDates : [];
    }

    function getScheduleStatusForDate(ymd, program) {
        if (!currentSchedule) return "missing";
        // 강좌별 운영일(공학리더반 기준 캘린더에서 개별 휴강 제외)에 포함되면 operating
        return getProgramOperatingDates(program).includes(ymd) ? "operating" : "closed";
    }

    function getTodayScheduleStatus(program) {
        if (!currentSchedule) return { type: "missing", label: "정보 없음" };

        const today = formatDateHyphen(new Date());
        if (getScheduleStatusForDate(today, program) === "operating") {
            return { type: "operating", label: "방과후 있음" };
        }
        return { type: "closed", label: "운영일 아님" };
    }

    function getSelectedProgram() {
        const canonicalName = normalizeProgramName(selectedProgramName);
        if (canonicalName !== selectedProgramName) {
            selectedProgramName = canonicalName;
            if (selectedProgramName) saveStoredProgramName(selectedProgramName);
        }
        return afterSchoolPrograms.find((program) => program.name === canonicalName) || null;
    }

    function createProgramSelect() {
        const select = document.createElement("select");
        select.className = "after-school-select";
        select.setAttribute("aria-label", "방과후 수업 선택");

        const placeholder = document.createElement("option");
        placeholder.value = "";
        placeholder.textContent = "방과후 수업 선택";
        select.append(placeholder);

        afterSchoolPrograms.forEach((program) => {
            const option = document.createElement("option");
            option.value = program.name;
            option.textContent = program.name;
            select.append(option);
        });

        select.value = normalizeProgramName(selectedProgramName);
        select.addEventListener("change", () => {
            selectedProgramName = normalizeProgramName(select.value);
            saveStoredProgramName(selectedProgramName);
            updateSelectedProgramDetails();
        });

        return select;
    }

    function createUpdateNotice() {
        const notice = document.createElement("p");
        notice.className = "after-school-notice";
        notice.textContent = UPDATE_NOTICE_TEXT;
        return notice;
    }

    function createDayChips(program) {
        const selected = Boolean(program);
        const referenceDate = getReferenceDate();
        const referenceYmd = formatDateHyphen(referenceDate);
        const weekdayDates = getWeekdayDates(referenceDate);
        const wrap = document.createElement("div");
        wrap.id = "after-school-day-chips";
        wrap.className = "after-school-day-chips";
        wrap.setAttribute("aria-label", "방과후 수업 요일");

        weekdayDates.forEach(({ label, ymd }) => {
            const chip = document.createElement("span");
            const isReferenceDate = ymd === referenceYmd;
            const active = selected && getScheduleStatusForDate(ymd, program) === "operating";
            chip.className = [
                "after-school-day-chip",
                active ? "active" : "",
                isReferenceDate ? "today" : ""
            ].filter(Boolean).join(" ");
            chip.textContent = label;
            chip.dataset.date = ymd;
            wrap.append(chip);
        });

        return wrap;
    }

    function createSelectedProgramRow(program) {
        const row = document.createElement("div");
        row.className = "timetable-row after-school-row";
        const todayStatus = getTodayScheduleStatus(program);

        const name = document.createElement("span");
        name.className = "subject";
        name.textContent = program?.name || "방과후 수업을 선택해 주세요";

        const status = document.createElement("span");
        status.className = "timetable-source-badge after-school-status-badge";
        status.textContent = program ? todayStatus.label : "선택 필요";

        const classroom = document.createElement("span");
        classroom.className = "timetable-source-badge";
        classroom.textContent = program ? program.classroom || "교실 위치 업데이트 중" : "교실 위치";

        row.append(name, status, classroom);
        return row;
    }

    function updateSelectedProgramDetails() {
        const result = document.getElementById("after-school-selected-result");
        if (result) {
            result.replaceChildren(createSelectedProgramRow(getSelectedProgram()));
        }

        const dayChips = document.getElementById("after-school-day-chips");
        if (dayChips) {
            dayChips.replaceWith(createDayChips(getSelectedProgram()));
        }

        const notice = document.getElementById("after-school-notice");
        if (notice) {
            notice.textContent = getNoticeText();
        }
    }

    function getNoticeText() {
        const todayStatus = getTodayScheduleStatus(getSelectedProgram());
        if (todayStatus.type === "missing") return "오늘 방과후가 없거나 혹은 데이터가 없을 것 같습니다.";
        if (todayStatus.type === "closed") return "오늘은 방과후 운영일이 아닙니다.";
        if (currentSchedule) return `${currentSchedule.title} · 수업 ${currentSchedule.classTime}`;
        return "오늘 방과후가 없거나 혹은 데이터가 없을 것 같습니다.";
    }

    function renderAfterSchoolSection() {
        const timetableContainer = document.getElementById("timetable-container");
        if (!timetableContainer) {
            console.warn("After-school section skipped: timetable container not found.");
            return;
        }

        removeExistingSection();

        const section = document.createElement("article");
        section.id = SECTION_ID;
        section.className = "meal-card";

        const title = document.createElement("div");
        title.className = "meal-type";
        title.textContent = "방과후 수업";

        const selectorWrap = document.createElement("div");
        selectorWrap.className = "class-selector after-school-selector";
        selectorWrap.append(createProgramSelect());

        const result = document.createElement("div");
        result.id = "after-school-selected-result";
        result.className = "meal-list after-school-list";
        result.append(createSelectedProgramRow(getSelectedProgram()));

        const notice = createUpdateNotice();
        notice.id = "after-school-notice";
        notice.textContent = getNoticeText();

        section.append(title, selectorWrap, createDayChips(getSelectedProgram()), notice, result);
        timetableContainer.append(section);
    }

    function observeTimetableRender() {
        const timetableList = document.getElementById("timetable-list");
        if (!timetableList) {
            console.warn("After-school render observer skipped: timetable list not found.");
            return;
        }

        let renderTimer = null;
        const observer = new MutationObserver(() => {
            window.clearTimeout(renderTimer);
            renderTimer = window.setTimeout(renderAfterSchoolSection, 0);
        });

        observer.observe(timetableList, {
            childList: true,
            subtree: true
        });

        renderAfterSchoolSection();
    }

    window.renderAfterSchoolSection = renderAfterSchoolSection;

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", observeTimetableRender);
    } else {
        observeTimetableRender();
    }
}());
