(function () {
    const TEACHER_FALLBACK_TEXT = "담당 교사 정보 준비중";
    const SECTION_ID = "after-school-section";
    let selectedProgramName = "";

    const afterSchoolPrograms = [
        { name: "공학리더반", teacher: null },
        { name: "오토테크니션기초A반", teacher: null },
        { name: "오토테크니션기초B반", teacher: null },
        { name: "오토테크니션기초C반", teacher: null },
        { name: "오토테크니션심화A반", teacher: null },
        { name: "오토테크니션심화B반", teacher: null },
        { name: "오토테크니션심화C반", teacher: null },
        { name: "바디페인팅심화반", teacher: null },
        { name: "바디리페어심화반", teacher: null },
        { name: "컴퓨터활용기초반", teacher: null },
        { name: "웹프로그래밍기초반", teacher: null },
        { name: "웹프로그래밍심화반", teacher: null },
        { name: "그래픽디자인반", teacher: null },
        { name: "전기기능심화반", teacher: null },
        { name: "컴퓨터활용기초(1-8)", teacher: null }
    ];

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
            updateSelectedProgramTeacher();
        });

        return select;
    }

    function createSelectedProgramRow(program) {
        const row = document.createElement("div");
        row.className = "timetable-row after-school-row";

        const name = document.createElement("span");
        name.className = "subject";
        name.textContent = program?.name || "방과후 수업을 선택해 주세요";

        const teacher = document.createElement("span");
        teacher.className = "timetable-source-badge";
        teacher.textContent = program ? program.teacher || TEACHER_FALLBACK_TEXT : "선택 필요";

        row.append(name, teacher);
        return row;
    }

    function updateSelectedProgramTeacher() {
        const result = document.getElementById("after-school-selected-result");
        if (!result) {
            return;
        }

        result.replaceChildren(createSelectedProgramRow(getSelectedProgram()));
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

        section.append(title, selectorWrap, result);
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
