export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname !== "/weather") {
      return new Response("Not Found", { status: 404 });
    }

    const apiKey = env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return json({ error: "OPENWEATHER_API_KEY is missing." }, 500);
    }

    const lat = url.searchParams.get("lat");
    const lon = url.searchParams.get("lon");
    const units = url.searchParams.get("units") || "metric";
    const lang = url.searchParams.get("lang") || "kr";

    if (!lat || !lon) {
      return json({ error: "lat and lon are required." }, 400);
    }

    const upstreamUrl = new URL("https://api.openweathermap.org/data/2.5/forecast");
    upstreamUrl.searchParams.set("lat", lat);
    upstreamUrl.searchParams.set("lon", lon);
    upstreamUrl.searchParams.set("units", units);
    upstreamUrl.searchParams.set("lang", lang);
    upstreamUrl.searchParams.set("appid", apiKey);

    const upstream = await fetch(upstreamUrl.toString(), {
      headers: { "Accept": "application/json" },
      cf: { cacheTtl: 300, cacheEverything: true }
    });

    const body = await upstream.text();
    const allowedOrigin = getAllowedOrigin(request.headers.get("Origin"), env.ALLOWED_ORIGINS);

    return new Response(body, {
      status: upstream.status,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": allowedOrigin,
        "Vary": "Origin"
      }
    });
  }
};

function getAllowedOrigin(origin, allowListRaw) {
  if (!origin) return "*";
  if (!allowListRaw) return "*";

  const allowList = allowListRaw.split(",").map((x) => x.trim()).filter(Boolean);
  if (allowList.includes("*")) return "*";
  if (allowList.includes(origin)) return origin;
  return "null";
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}
