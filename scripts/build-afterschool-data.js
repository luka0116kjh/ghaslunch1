#!/usr/bin/env node
/**
 * 구글 "방과후" 시트 → afterschoolScheduleData.js 생성기
 *
 * 브라우저(index.html)에 API 키를 노출하지 않기 위해, 시트 읽기는 이 빌드 단계에서만 하고
 * 그 결과를 정적 파일 afterschoolScheduleData.js 로 써 넣는다. index.html은 기존과 동일하게
 * 그 파일의 window.GHAS_AFTER_SCHOOL_SCHEDULES 를 읽는다.
 *
 * 실행: node scripts/build-afterschool-data.js
 *
 * 시트에서 파싱하는 것: 프로그램 제목 / 강좌명·강의실 / 운영일(방과후 있음인 날짜)
 * 시트에 없어 상수로 보존하는 것: 식사·수업 시간, 소요시간, 예외일, id 등
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { SPREADSHEET_ID, SHEET_GID, resolveSheetTitle, fetchSheetValues } = require('./fetch-afterschool-timetable');

// ── 시트에 없는 메타데이터 (여기서 관리) ──────────────────
// 시트에 없어 상수로 관리하는 메타데이터. (모두 소비자 코드에서 사용 중)
const META = {
  id: '2026-4-after-school-employment', // getAfterschoolScheduleEvents 이벤트 id
  scheduleTitle: '4차 방과후수업', // 캘린더 이벤트 제목
  dinnerTime: '17:00~17:50', // 오늘 카드 석식 시간
  classTime: '18:00~19:40', // 오늘 카드/공지 수업 시간
};

const OUTPUT_FILE = path.resolve(__dirname, '..', 'afterschoolScheduleData.js');

// 전체 운영 캘린더의 기준이 되는 강좌 행. 이 강좌가 운영이면 그 날짜는 전체 운영일,
// 아니면(없음/휴강/X/x/빈칸) 전체 미운영일로 본다.
const MASTER_COURSE = '공학리더반';

// ── 시트 파싱 ─────────────────────────────────────────────
/**
 * "07월 06일" + 연도 → "2026-07-06"
 */
function toIsoDate(label, year) {
  const m = /(\d{1,2})\s*월\s*(\d{1,2})\s*일/.exec(label);
  if (!m) return null;
  const mm = String(m[1]).padStart(2, '0');
  const dd = String(m[2]).padStart(2, '0');
  return `${year}-${mm}-${dd}`;
}

/**
 * 시트 2차원 값에서 웹에 필요한 스케줄 정보를 뽑는다.
 * @param {string[][]} rows
 * @returns {{title:string, courseRooms:{name:string,room:string}[], operatingDates:string[]}}
 */
function parseSchedule(rows) {
  // 1) 프로그램 제목: "...방과후수업(...)"을 담은 셀에서 뒤쪽 날짜범위 표기를 제거
  let bigTitle = '';
  for (const row of rows) {
    const cell = (row.find((c) => /방과후수업/.test(c || '')) || '').trim();
    if (cell) {
      bigTitle = cell;
      break;
    }
  }
  const title = bigTitle.replace(/\s*\(\d.*$/, '').trim(); // " (6/1 ~ 6/19) 14일간" 제거
  const yearMatch = /(\d{4})/.exec(title);
  const year = yearMatch ? yearMatch[1] : String(new Date().getFullYear());

  // 2) 셀 수집: 강좌별 (날짜 -> 셀값) 맵을 만든다. 헤더 블록(강좌명 행)마다 날짜 열 위치를 갱신.
  //    같은 강좌가 여러 블록(주차)에 나뉘어 있어도 날짜를 누적한다.
  const courseCells = new Map(); // name -> { room, cells: Map<ISO, value> } (첫 등장 순서 유지)
  let dateCols = []; // [{ col, iso }]

  const isHeaderRow = (row) => (row[1] || '').trim() === '강좌명';
  // 명시적으로 비운영(개별 휴강)을 뜻하는 셀: "없음"/"방과후 없음", "휴강", "X"/"x".
  const isClosedCell = (v) => /없음|휴강/.test(v) || /^x$/i.test(v);
  // 명시적으로 운영을 뜻하는 셀: "방과후 있음"(있음 포함, 없음 아님). 기준행 판정에 사용.
  const isOperatingCell = (v) => v.includes('있음') && !v.includes('없음');

  for (const row of rows) {
    if (isHeaderRow(row)) {
      dateCols = [];
      for (let c = 3; c < row.length; c++) {
        const iso = toIsoDate((row[c] || '').trim(), year);
        if (iso) dateCols.push({ col: c, iso });
      }
      continue;
    }

    const name = (row[1] || '').trim();
    if (!name) continue;

    let entry = courseCells.get(name);
    if (!entry) {
      const room = (row[2] || '').trim().replace(/\s*\/\s*/g, ' / '); // "1-7/..." → "1-7 / ..."
      entry = { room, cells: new Map() };
      courseCells.set(name, entry);
    }

    for (const { col, iso } of dateCols) {
      entry.cells.set(iso, (row[col] || '').trim());
    }
  }

  // 3) 기준행(공학리더반) = 전체 운영 캘린더. 이 행이 "방과후 있음"인 날짜만 전체 운영일.
  //    (없음/휴강/X/x/빈칸 → 전체 미운영일 → 어떤 강좌도 그 날짜에 표시 안 함)
  const masterEntry = courseCells.get(MASTER_COURSE);
  let masterDates;
  if (masterEntry) {
    masterDates = Array.from(masterEntry.cells.entries())
      .filter(([, v]) => isOperatingCell(v))
      .map(([iso]) => iso)
      .sort();
  } else {
    throw new Error(`기준 강좌 "${MASTER_COURSE}" 행을 찾지 못했습니다. 시트 강좌명을 확인하세요.`);
  }

  // 4) 강좌별 운영일 = 전체 운영일 중, 해당 강좌 셀이 개별 휴강(없음/휴강/X/x)이 아닌 날.
  //    (강좌 셀이 빈칸이거나 "방과후 있음"이면 그 전체 운영일에 표시)
  const courseRooms = Array.from(courseCells, ([name, e]) => ({
    name,
    room: e.room,
    operatingDates: masterDates.filter((iso) => !isClosedCell(e.cells.get(iso) || '')),
  }));

  // 스케줄 전체 운영일 = 기준행 운영일 (달력 범위·요일 계산용)
  const operatingDates = masterDates.slice();

  return { title, courseRooms, operatingDates };
}

// ── 출력 파일 생성 ────────────────────────────────────────
function renderFile({ title, courseRooms, operatingDates }) {
  const courseLines = courseRooms
    .map((c) => {
      const dates = c.operatingDates.map((d) => JSON.stringify(d)).join(', ');
      return (
        `        {\n` +
        `            name: ${JSON.stringify(c.name)},\n` +
        `            room: ${JSON.stringify(c.room)},\n` +
        `            operatingDates: [${dates}]\n` +
        `        }`
      );
    })
    .join(',\n');
  const dateLines = operatingDates.map((d) => `        ${JSON.stringify(d)}`).join(',\n');

  return `// 자동 생성 파일 — 직접 수정하지 마세요.
// 생성: node scripts/build-afterschool-data.js (구글 "방과후" 시트에서 생성)
// 생성 시각: ${new Date().toISOString()}
(function () {
    const courseRooms = [
${courseLines}
    ];

    const operatingDates = [
${dateLines}
    ];

    window.GHAS_AFTER_SCHOOL_SCHEDULES = [
        {
            id: ${JSON.stringify(META.id)},
            title: ${JSON.stringify(title)},
            scheduleTitle: ${JSON.stringify(META.scheduleTitle)},
            dinnerTime: ${JSON.stringify(META.dinnerTime)},
            classTime: ${JSON.stringify(META.classTime)},
            operatingDates,
            courseRooms
        }
    ];
})();
`;
}

// ── 메인 ──────────────────────────────────────────────────
async function main() {
  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error('GOOGLE_API_KEY가 설정되지 않았습니다. 프로젝트 루트 .env 파일을 확인하세요.');
  }

  console.log(`시트 읽는 중: ${SPREADSHEET_ID} (gid=${SHEET_GID})`);
  const sheetTitle = await resolveSheetTitle(apiKey, SHEET_GID);
  const values = await fetchSheetValues(apiKey, sheetTitle);

  const parsed = parseSchedule(values);
  console.log(`  제목: ${parsed.title}`);
  console.log(`  강좌 수: ${parsed.courseRooms.length}개`);
  console.log(`  운영일: ${parsed.operatingDates.length}일 (${parsed.operatingDates[0]} ~ ${parsed.operatingDates[parsed.operatingDates.length - 1]})`);

  if (!parsed.courseRooms.length || !parsed.operatingDates.length) {
    throw new Error('시트에서 강좌 또는 운영일을 찾지 못했습니다. 시트 형식(강좌명/강의실/날짜 헤더)을 확인하세요.');
  }

  fs.writeFileSync(OUTPUT_FILE, renderFile(parsed), 'utf8');
  console.log(`\n✅ 생성 완료: ${path.relative(process.cwd(), OUTPUT_FILE)}`);
  console.log('   index.html을 새로고침하면 반영됩니다.');
}

if (require.main === module) {
  main().catch((err) => {
    console.error('\n❌ 실패:', err.message);
    process.exitCode = 1;
  });
}

// 테스트/재사용용 export
module.exports = { parseSchedule, renderFile };
