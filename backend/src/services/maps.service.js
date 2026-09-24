const axios = require('axios');

const MAPS_BASE = 'https://maps.googleapis.com/maps/api';

const getNearbyPharmacies = async (lat, lng, radius = 5000) => {
  const res = await axios.get(`${MAPS_BASE}/place/nearbysearch/json`, {
    params: { location: `${lat},${lng}`, radius, type: 'pharmacy', key: process.env.GOOGLE_MAPS_API_KEY },
  });
  return res.data.results;
};

const getDirections = async (originLat, originLng, destLat, destLng) => {
  const res = await axios.get(`${MAPS_BASE}/directions/json`, {
    params: {
      origin: `${originLat},${originLng}`,
      destination: `${destLat},${destLng}`,
      mode: 'driving',
      key: process.env.GOOGLE_MAPS_API_KEY,
    },
  });
  return res.data.routes?.[0] || null;
};

const geocode = async (address) => {
  const res = await axios.get(`${MAPS_BASE}/geocode/json`, {
    params: { address, key: process.env.GOOGLE_MAPS_API_KEY },
  });
  const location = res.data.results?.[0]?.geometry?.location;
  return location || null;
};

module.exports = { getNearbyPharmacies, getDirections, geocode };
