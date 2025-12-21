// Simple Express proxy for Google Places / Geocoding APIs with CORS enabled.
// Usage:
//   GOOGLE_MAPS_API_KEY=your_key node index.js
// Example endpoints:
//   GET /autocomplete?input=mitchell
//   GET /details?place_id=PLACE_ID
//   GET /geocode?lat=...&lng=...

const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const KEY = process.env.GOOGLE_MAPS_API_KEY;
if (!KEY) {
  console.warn('Warning: GOOGLE_MAPS_API_KEY not set. Requests will likely fail.');
}

app.get('/autocomplete', async (req, res) => {
  const input = req.query.input;
  if (!input) return res.status(400).json({ error: 'missing input' });
  try {
    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&key=${KEY}&types=establishment|geocode`;
    const r = await fetch(url);
    const json = await r.json();
    // Forward status and body
    res.status(r.status).json(json);
  } catch (e) {
    console.error('autocomplete error', e);
    res.status(500).json({ error: 'proxy error' });
  }
});

app.get('/details', async (req, res) => {
  const placeId = req.query.place_id;
  if (!placeId) return res.status(400).json({ error: 'missing place_id' });
  try {
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(placeId)}&key=${KEY}&fields=geometry,formatted_address`;
    const r = await fetch(url);
    const json = await r.json();
    res.status(r.status).json(json);
  } catch (e) {
    console.error('details error', e);
    res.status(500).json({ error: 'proxy error' });
  }
});

app.get('/geocode', async (req, res) => {
  const lat = req.query.lat;
  const lng = req.query.lng;
  if (!lat || !lng) return res.status(400).json({ error: 'missing lat/lng' });
  try {
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${encodeURIComponent(lat)},${encodeURIComponent(lng)}&key=${KEY}`;
    const r = await fetch(url);
    const json = await r.json();
    res.status(r.status).json(json);
  } catch (e) {
    console.error('geocode error', e);
    res.status(500).json({ error: 'proxy error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`places-proxy listening on ${port}`);
});
