#!/usr/bin/env node
/**
 * 2026 4차 방과후수업 시간표 스프레드시트 읽기 스크립트
 *
 * Google Sheets API v4 (spreadsheets.values.get)를 사용해 "링크가 있는 모든 사용자"로
 * 공개된 시트를 API 키 인증으로 읽어와 콘솔에 표 형태로 출력한다.
 *
 * 인증: 환경변수 GOOGLE_API_KEY (.env 파일에서 로드)
 *
 * 참고
 * - 값 읽기(values.get)에는 Google Sheets API만 있으면 되고 Google Drive API는 필요 없다.
 *   Drive API는 파일 메타데이터/공유설정 조회 등에 쓰이며, API 키의 스코프에는 포함돼 있으나
 *   이 스크립트의 읽기 동작에는 사용하지 않는다.
 * - values.get은 gid가 아니라 "시트 이름"을 A1 범위로 요구하므로,
 *   먼저 spreadsheets.get(메타데이터)로 gid -> 시트 이름을 변환한다.
 *
 * 실행: npm install && node scripts/fetch-afterschool-timetable.js
 */

'use strict';

const path = require('path');

// .env 파일에서 GOOGLE_API_KEY 등 환경변수 로드 (프로젝트 루트 기준)
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

// ── 연결 정보 ─────────────────────────────────────────────
const SPREADSHEET_ID = '1OKs10X7cq1j185Pzk1ZKfZ6bDVx25QG0tsfuCKT_ocI'; // 문서명: 방과후
const SHEET_GID = 0;
const API_BASE = 'https://sheets.googleapis.com/v4/spreadsheets';

// ── HTTP 헬퍼 ─────────────────────────────────────────────
/**
 * Google API GET 요청. 실패 시 상태코드와 API 에러 메시지를 담아 throw 한다.
 * @param {string} url
 * @returns {Promise<object>}
 */
async function apiGet(url) {
  let res;
  try {
    res = await fetch(url);
  } catch (networkErr) {
    throw new Error(`네트워크 요청 실패: ${networkErr.message}`);
  }

  const bodyText = await res.text();
  let body;
  try {
    body = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    body = { raw: bodyText };
  }

  if (!res.ok) {
    const apiMessage =
      (body && body.error && body.error.message) || res.statusText || '알 수 없는 오류';
    const status = (body && body.error && body.error.status) || res.status;
    throw new Error(`API 오류 (HTTP ${res.status} / ${status}): ${apiMessage}`);
  }

  return body;
}

// ── gid → 시트 이름 변환 ──────────────────────────────────
/**
 * spreadsheets.get 메타데이터로 gid에 해당하는 시트 이름을 찾는다.
 * @param {string} apiKey
 * @param {number} gid
 * @returns {Promise<string>}
 */
async function resolveSheetTitle(apiKey, gid) {
  const url =
    `${API_BASE}/${SPREADSHEET_ID}` +
    `?fields=${encodeURIComponent('sheets.properties(sheetId,title)')}` +
    `&key=${encodeURIComponent(apiKey)}`;

  const data = await apiGet(url);
  const sheets = (data && data.sheets) || [];
  const match = sheets.find((s) => s.properties && s.properties.sheetId === gid);

  if (!match) {
    const available = sheets
      .map((s) => `${s.properties.title}(gid=${s.properties.sheetId})`)
      .join(', ');
    throw new Error(`gid=${gid} 에 해당하는 시트를 찾을 수 없습니다. 사용 가능한 시트: ${available}`);
  }

  return match.properties.title;
}

// ── 값 읽기 (spreadsheets.values.get) ────────────────────
/**
 * 지정한 시트의 전체 값을 2차원 배열로 반환한다.
 * @param {string} apiKey
 * @param {string} sheetTitle
 * @returns {Promise<string[][]>}
 */
async function fetchSheetValues(apiKey, sheetTitle) {
  // 시트 이름에 특수문자/공백이 있어도 안전하도록 작은따옴표로 감싼다.
  const range = `'${sheetTitle.replace(/'/g, "''")}'`;
  const url =
    `${API_BASE}/${SPREADSHEET_ID}/values/${encodeURIComponent(range)}` +
    `?majorDimension=ROWS&key=${encodeURIComponent(apiKey)}`;

  const data = await apiGet(url);
  return (data && data.values) || [];
}

// ── 표 형태 콘솔 출력 ─────────────────────────────────────
/**
 * 2차원 배열을 정렬된 텍스트 표로 출력한다.
 * @param {string[][]} rows
 */
function printTable(rows) {
  if (!rows.length) {
    console.log('(데이터가 없습니다)');
    return;
  }

  const colCount = rows.reduce((max, r) => Math.max(max, r.length), 0);

  // 문자열 표시 폭(한글=2, 그 외=1)을 고려해 열 너비 계산
  const displayWidth = (str) => {
    let w = 0;
    for (const ch of String(str)) {
      w += ch.charCodeAt(0) > 0x1100 ? 2 : 1; // 대략적인 전각/한글 판정
    }
    return w;
  };
  const pad = (str, width) => String(str) + ' '.repeat(Math.max(0, width - displayWidth(str)));

  const colWidths = new Array(colCount).fill(0);
  for (const row of rows) {
    for (let c = 0; c < colCount; c++) {
      colWidths[c] = Math.max(colWidths[c], displayWidth(row[c] != null ? row[c] : ''));
    }
  }

  const sep = '+' + colWidths.map((w) => '-'.repeat(w + 2)).join('+') + '+';
  const renderRow = (row) =>
    '| ' +
    colWidths.map((w, c) => pad(row[c] != null ? row[c] : '', w)).join(' | ') +
    ' |';

  console.log(sep);
  console.log(renderRow(rows[0])); // 헤더
  console.log(sep);
  for (let r = 1; r < rows.length; r++) console.log(renderRow(rows[r]));
  console.log(sep);
  console.log(`\n총 ${rows.length}행 x ${colCount}열`);
}

// ── 메인 ──────────────────────────────────────────────────
async function main() {
  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error(
      'GOOGLE_API_KEY가 설정되지 않았습니다. 프로젝트 루트 .env 파일에 GOOGLE_API_KEY=... 를 추가하세요.'
    );
  }

  console.log(`스프레드시트: ${SPREADSHEET_ID}`);
  console.log(`대상 gid: ${SHEET_GID}\n`);

  const sheetTitle = await resolveSheetTitle(apiKey, SHEET_GID);
  console.log(`시트 이름 확인: "${sheetTitle}"\n`);

  const values = await fetchSheetValues(apiKey, sheetTitle);
  printTable(values);
}

// 직접 실행했을 때만 표를 출력. (require로 불러와 함수만 재사용하는 경우 실행 안 함)
if (require.main === module) {
  main().catch((err) => {
    console.error('\n❌ 실패:', err.message);
    process.exitCode = 1;
  });
}

// 생성기 등 다른 스크립트에서 재사용할 수 있도록 export
module.exports = {
  SPREADSHEET_ID,
  SHEET_GID,
  resolveSheetTitle,
  fetchSheetValues,
};
