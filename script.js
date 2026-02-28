const today = new Date();

const y = today.getFullYear();
const m = String(today.getMonth() + 1).padStart(2, '0');
const d = String(today.getDate()).padStart(2, '0');
const ymd = `${y}${m}${d}`;

document.getElementById('today-date').innerText = today.toLocaleDateString('ko-KR', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' });

async function fetchMeals() {
    document.getElementById('lunch-menu').innerText = "데이터를 불러오는 중...";
    document.getElementById('lunch-cal').innerText = "";
    document.getElementById('dinner-menu').innerText = "데이터를 불러오는 중...";
    document.getElementById('dinner-cal').innerText = "";

    const API_KEY = typeof CONFIG !== 'undefined' ? CONFIG.API_KEY : "";
    let URL = `https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7530908&MLSV_YMD=${ymd}`;

    if (API_KEY && API_KEY !== "기에_발급받은_키를_넣으세요") {
        URL += `&KEY=${API_KEY}`;
    }

    try {
        const response = await fetch(URL);
        if (!response.ok) throw new Error("API 응답 오류");
        const data = await response.json();

        if (data.mealServiceDietInfo) {
            const rows = data.mealServiceDietInfo[1].row;

            document.getElementById('lunch-menu').innerText = "정보가 없습니다.";
            document.getElementById('dinner-menu').innerText = "정보가 없습니다.";

            rows.forEach(row => {

                const cleanMenu = row.DDISH_NM.replace(/\([^)]*\)/g, '').replace(/<br\/>/g, '<br>');

                if (row.MMEAL_SC_CODE === "2") {
                    document.getElementById('lunch-menu').innerHTML = cleanMenu;
                    document.getElementById('lunch-cal').innerText = row.CAL_INFO;
                } else if (row.MMEAL_SC_CODE === "3") {
                    document.getElementById('dinner-menu').innerHTML = cleanMenu;
                    document.getElementById('dinner-cal').innerText = row.CAL_INFO;
                }
            });
        } else {
            const msg = "오늘은 급식 정보가 없습니다.";
            document.getElementById('lunch-menu').innerText = msg;
            document.getElementById('dinner-menu').innerText = msg;
        }
    } catch (error) {
        console.error("데이터 로드 실패:", error);
        const errorMsg = "정보를 불러오지 못했습니다.";
        document.getElementById('lunch-menu').innerText = errorMsg;
        document.getElementById('dinner-menu').innerText = errorMsg;
    }
}

fetchMeals();