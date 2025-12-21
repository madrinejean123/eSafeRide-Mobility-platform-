# Places Proxy (example)

This is a tiny example Express proxy that forwards requests to Google Maps
Places/Geocoding HTTP endpoints and adds CORS headers so your web app can
call them during development.

WARNING: This is only an example for development. Do not use this in
production without proper authentication, rate limiting, and secret management.

Quick start

1. Install deps

```bash
cd tools/places-proxy
npm install
```

2. Run (set your API key in env):

```bash
GOOGLE_MAPS_API_KEY=YOUR_KEY npm start
```

3. Example requests

- Autocomplete:
  `GET http://localhost:8080/autocomplete?input=mitchell`
- Place details:
  `GET http://localhost:8080/details?place_id=PLACE_ID`
- Reverse geocode:
  `GET http://localhost:8080/geocode?lat=0.0&lng=0.0`

Using from the Flutter web app

Change your web calls to point at the proxy (for example, from `geocode_service_io.dart`),
or set up your dev environment to forward calls to `http://localhost:8080`.

Notes

- Keep your real API key secret. Put it in environment variables or a secrets
  manager and avoid committing it to source control.
- For production, prefer server-side proxies behind authentication, or use
  OAuth/service accounts as appropriate.
