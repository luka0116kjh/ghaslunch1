export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const corsHeaders = getCorsHeaders(request, env);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: corsHeaders ? 204 : 403,
        headers: corsHeaders || {}
      });
    }

    if (request.method !== "GET") {
      return json({ error: "Method not allowed." }, 405, corsHeaders);
    }

    if (!corsHeaders) {
      return json({ error: "Origin is not allowed." }, 403);
    }

    if (url.pathname !== "/weather") {
      return json({ error: "Not found." }, 404, corsHeaders);
    }

    const apiKey = env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return json({ error: "OPENWEATHER_API_KEY is missing." }, 500, corsHeaders);
    }

    const lat = Number(url.searchParams.get("lat"));
    const lon = Number(url.searchParams.get("lon"));
    const units = url.searchParams.get("units") || "metric";
    const lang = url.searchParams.get("lang") || "kr";

    if (!Number.isFinite(lat) || lat < -90 || lat > 90 || !Number.isFinite(lon) || lon < -180 || lon > 180) {
      return json({ error: "Valid lat and lon are required." }, 400, corsHeaders);
    }

    if (!["standard", "metric", "imperial"].includes(units)) {
      return json({ error: "Invalid units." }, 400, corsHeaders);
    }

    if (!/^[a-z]{2,5}$/i.test(lang)) {
      return json({ error: "Invalid lang." }, 400, corsHeaders);
    }

    const upstreamUrl = new URL("https://api.openweathermap.org/data/2.5/forecast");
    upstreamUrl.searchParams.set("lat", String(lat));
    upstreamUrl.searchParams.set("lon", String(lon));
    upstreamUrl.searchParams.set("units", units);
    upstreamUrl.searchParams.set("lang", lang);
    upstreamUrl.searchParams.set("appid", apiKey);

    const upstream = await fetch(upstreamUrl.toString(), {
      headers: { "Accept": "application/json" },
      cf: { cacheTtl: 300, cacheEverything: true }
    });

    const body = await upstream.text();

    return new Response(body, {
      status: upstream.status,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=300",
        ...corsHeaders
      }
    });
  }
};

function getCorsHeaders(request, env) {
  const origin = request.headers.get("Origin");
  const allowedOrigin = getAllowedOrigin(origin, env.ALLOWED_ORIGINS);
  if (!allowedOrigin) return null;

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer"
  };
}

function getAllowedOrigin(origin, allowListRaw) {
  if (!origin) return "https://ghaslunch1.web.app";

  const defaultAllowList = ["https://ghaslunch1.web.app"];
  const configuredAllowList = allowListRaw
    ? allowListRaw.split(",").map((x) => x.trim()).filter(Boolean)
    : [];
  const allowList = configuredAllowList.length > 0 ? configuredAllowList : defaultAllowList;

  if (allowList.includes("*")) return "*";
  if (allowList.includes(origin)) return origin;
  return "";
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders
    }
  });
}
