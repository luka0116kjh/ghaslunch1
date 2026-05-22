(function () {
    const SECTION_ID = "after-school-section";
    const UPDATE_NOTICE_TEXT = "방과후 수업 정보는 업데이트 중입니다.";
    const DAY_LABELS = ["월", "화", "수", "목", "금"];
    const DATA_VERSION = "2026-05-22-file-ready";
    let selectedProgramName = "";

    const afterSchoolData = {
        version: DATA_VERSION,
        status: "updating",
        programs: [
            { name: "공학리더반", classroom: null, days: [] },
            { name: "오토테크니션기초A반", classroom: null, days: [] },
            { name: "오토테크니션기초B반", classroom: null, days: [] },
            { name: "오토테크니션기초C반", classroom: null, days: [] },
            { name: "오토테크니션심화A반", classroom: null, days: [] },
            { name: "오토테크니션심화B반", classroom: null, days: [] },
            { name: "오토테크니션심화C반", classroom: null, days: [] },
            { name: "바디페인팅심화반", classroom: null, days: [] },
            { name: "바디리페어심화반", classroom: null, days: [] },
            { name: "컴퓨터활용기초반", classroom: null, days: [] },
            { name: "웹프로그래밍기초반", classroom: null, days: [] },
            { name: "웹프로그래밍심화반", classroom: null, days: [] },
            { name: "그래픽디자인반", classroom: null, days: [] },
            { name: "전기기능심화반", classroom: null, days: [] },
            { name: "컴퓨터활용기초(1-8)", classroom: null, days: [] }
        ]
    };

    const afterSchoolPrograms = afterSchoolData.programs
        .filter((program) => !String(program.name || "").includes("성합"));

    window.afterSchoolData = afterSchoolData;
    window.afterSchoolPrograms = afterSchoolPrograms;

    function removeExistingSection() {
        const existingSection = document.getElementById(SECTION_ID);
        if (existingSection) {
            existingSection.remove();
        }
    }

    function getSelectedProgram() {
        return afterSchoolPrograms.find((program) => program.name === selectedProgramName) || null;
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

        select.value = selectedProgramName;
        select.addEventListener("change", () => {
            selectedProgramName = select.value;
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
        const days = new Set((program?.days || []).map((day) => String(day).trim()));
        const wrap = document.createElement("div");
        wrap.id = "after-school-day-chips";
        wrap.className = "after-school-day-chips";
        wrap.setAttribute("aria-label", "방과후 수업 요일");

        DAY_LABELS.forEach((day) => {
            const chip = document.createElement("span");
            const active = days.has(day);
            chip.className = `after-school-day-chip${active ? " active" : ""}`;
            chip.textContent = day;
            wrap.append(chip);
        });

        return wrap;
    }

    function createSelectedProgramRow(program) {
        const row = document.createElement("div");
        row.className = "timetable-row after-school-row";

        const name = document.createElement("span");
        name.className = "subject";
        name.textContent = program?.name || "방과후 수업을 선택해 주세요";

        const status = document.createElement("span");
        status.className = "timetable-source-badge after-school-status-badge";
        status.textContent = program ? "방과후 있음" : "선택 필요";

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

        section.append(title, selectorWrap, createDayChips(getSelectedProgram()), createUpdateNotice(), result);
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
