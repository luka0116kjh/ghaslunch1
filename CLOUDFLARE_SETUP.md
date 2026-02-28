# Cloudflare Worker Setup (Weather Proxy)

This setup keeps the OpenWeather API key out of GitHub Pages.

## 1. Install and login

```powershell
npm i -g wrangler
wrangler login
```

## 2. Prepare worker files

```powershell
cd cloudflare-worker
Copy-Item wrangler.toml.example wrangler.toml
```

## 3. Set secrets and CORS allowlist

```powershell
wrangler secret put OPENWEATHER_API_KEY
```

When prompted, paste your OpenWeather key.

Set allowed origins (replace with your real GitHub Pages URL):

```powershell
wrangler secret put ALLOWED_ORIGINS
```

Value example:

```text
https://YOUR_ID.github.io,http://127.0.0.1:5500
```

## 4. Deploy worker

```powershell
wrangler deploy
```

After deploy, copy the worker URL:

```text
https://<worker-name>.<subdomain>.workers.dev/weather
```

## 5. Update frontend config

In `config.js`:

```js
WEATHER: {
  PROXY_URL: "https://<worker-name>.<subdomain>.workers.dev/weather",
  LAT: 37.380,
  LON: 126.803,
  CITY_NAME: "Siheung"
}
```

No weather API key is needed in frontend anymore.
