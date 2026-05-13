const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const neisApiKey = defineSecret("NEIS_API_KEY");

const NEIS_URL = "https://open.neis.go.kr/hub/";
const OFFICE_CODE = "J10";
const SCHOOL_CODE = "7530908";
const ALLOWED_ORIGINS = new Set([
  "https://ghaslunch1.web.app",
  "https://ghaslunch1.firebaseapp.com",
  "http://localhost:5000",
  "http://127.0.0.1:5000",
]);

function setCorsHeaders(request, response) {
  const origin = request.get("origin");
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    response.set("Access-Control-Allow-Origin", origin);
    response.set("Vary", "Origin");
  }
  response.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");
  response.set("X-Content-Type-Options", "nosniff");
  response.set("Referrer-Policy", "no-referrer");
}

function isAllowedBrowserOrigin(request) {
  const origin = request.get("origin");
  return !origin || ALLOWED_ORIGINS.has(origin);
}

function sendJson(response, status, body) {
  response.status(status).json(body);
}

function isYmd(value) {
  return typeof value === "string" && /^\d{8}$/.test(value);
}

function getFirstQueryValue(value) {
  return Array.isArray(value) ? value[0] : value;
}

exports.meals = onRequest(
  {
    region: "asia-east1",
    secrets: [neisApiKey],
    timeoutSeconds: 30,
  },
  async (request, response) => {
    setCorsHeaders(request, response);
    if (!isAllowedBrowserOrigin(request)) return sendJson(response, 403, { error: "Origin is not allowed" });
    if (request.method === "OPTIONS") return response.status(204).send("");
    if (request.method !== "GET") return sendJson(response, 405, { error: "Method not allowed" });

    const ymd = getFirstQueryValue(request.query.ymd);
    const fromYmd = getFirstQueryValue(request.query.from);
    const toYmd = getFirstQueryValue(request.query.to);
    const mealCode = getFirstQueryValue(request.query.mealCode);
    const pSize = getFirstQueryValue(request.query.pSize) || "100";

    const hasSingleDate = isYmd(ymd);
    const hasDateRange = isYmd(fromYmd) && isYmd(toYmd);

    if (!hasSingleDate && !hasDateRange) {
      return sendJson(response, 400, { error: "Use ymd=YYYYMMDD or from/to=YYYYMMDD." });
    }

    if (mealCode && !/^[1-3]$/.test(mealCode)) {
      return sendJson(response, 400, { error: "mealCode must be 1, 2, or 3." });
    }

    const size = Math.min(Math.max(Number.parseInt(pSize, 10) || 100, 1), 100);
    const upstreamUrl = new URL(NEIS_URL + "mealServiceDietInfo");
    upstreamUrl.searchParams.set("Type", "json");
    upstreamUrl.searchParams.set("ATPT_OFCDC_SC_CODE", OFFICE_CODE);
    upstreamUrl.searchParams.set("SD_SCHUL_CODE", SCHOOL_CODE);
    upstreamUrl.searchParams.set("pSize", String(size));
    upstreamUrl.searchParams.set("KEY", neisApiKey.value());

    if (hasSingleDate) {
      upstreamUrl.searchParams.set("MLSV_YMD", ymd);
    } else {
      upstreamUrl.searchParams.set("MLSV_FROM_YMD", fromYmd);
      upstreamUrl.searchParams.set("MLSV_TO_YMD", toYmd);
    }

    if (mealCode) {
      upstreamUrl.searchParams.set("MMEAL_SC_CODE", mealCode);
    }

    try {
      const upstreamResponse = await fetch(upstreamUrl);
      const text = await upstreamResponse.text();

      response.set("Cache-Control", "public, max-age=300, s-maxage=1800");
      response.status(upstreamResponse.status);
      response.type(upstreamResponse.headers.get("content-type") || "application/json");
      response.send(text);
    } catch (error) {
      console.error("NEIS meal proxy failed:", error);
      sendJson(response, 502, { error: "Failed to fetch meal data." });
    }
  }
);

exports.timetable = onRequest(
  {
    region: "asia-east1",
    secrets: [neisApiKey],
    timeoutSeconds: 30,
  },
  async (request, response) => {
    setCorsHeaders(request, response);
    if (!isAllowedBrowserOrigin(request)) return sendJson(response, 403, { error: "Origin is not allowed" });
    if (request.method === "OPTIONS") return response.status(204).send("");
    if (request.method !== "GET") return sendJson(response, 405, { error: "Method not allowed" });

    const ymd = getFirstQueryValue(request.query.ymd);
    const grade = getFirstQueryValue(request.query.grade);
    const classNum = getFirstQueryValue(request.query.classNum);
    const pSize = getFirstQueryValue(request.query.pSize) || "100";

    if (!isYmd(ymd)) return sendJson(response, 400, { error: "ymd=YYYYMMDD is required." });
    if (!grade || !classNum) return sendJson(response, 400, { error: "grade and classNum are required." });

    const size = Math.min(Math.max(Number.parseInt(pSize, 10) || 100, 1), 100);
    const upstreamUrl = new URL(NEIS_URL + "hisTimetable");
    upstreamUrl.searchParams.set("Type", "json");
    upstreamUrl.searchParams.set("ATPT_OFCDC_SC_CODE", OFFICE_CODE);
    upstreamUrl.searchParams.set("SD_SCHUL_CODE", SCHOOL_CODE);
    upstreamUrl.searchParams.set("pSize", String(size));
    upstreamUrl.searchParams.set("KEY", neisApiKey.value());
    upstreamUrl.searchParams.set("ALL_TI_YMD", ymd);
    upstreamUrl.searchParams.set("GRADE", grade);
    upstreamUrl.searchParams.set("CLASS_NM", classNum);

    try {
      const upstreamResponse = await fetch(upstreamUrl);
      const text = await upstreamResponse.text();

      response.set("Cache-Control", "public, max-age=300, s-maxage=1800");
      response.status(upstreamResponse.status);
      response.type(upstreamResponse.headers.get("content-type") || "application/json");
      response.send(text);
    } catch (error) {
      console.error("NEIS timetable proxy failed:", error);
      sendJson(response, 502, { error: "Failed to fetch timetable data." });
    }
  }
);
