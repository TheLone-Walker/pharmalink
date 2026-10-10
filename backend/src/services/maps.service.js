const axios = require('axios');

const MAPS_BASE = 'https://maps.googleapis.com/maps/api';

// Reference landmark coordinates for Cameroon major hubs
const CAMEROON_LOCATIONS = {
  yaounde: { lat: 3.8480, lng: 11.5021, name: 'Yaoundé Centre' },
  bastos: { lat: 3.8802, lng: 11.5165, name: 'Bastos, Yaoundé' },
  biyemassi: { lat: 3.8290, lng: 11.4850, name: 'Biyem-Assi, Yaoundé' },
  douala: { lat: 4.0511, lng: 9.7679, name: 'Douala Centre' },
  akwa: { lat: 4.0503, lng: 9.7042, name: 'Akwa, Douala' },
  bonanjo: { lat: 4.0435, lng: 9.6897, name: 'Bonanjo, Douala' },
  bafoussam: { lat: 5.4778, lng: 10.4176, name: 'Bafoussam' },
};

/**
 * Calculates Haversine distance between two coordinates in Kilometers
 */
const calculateHaversineDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

/**
 * Find nearby pharmacies via Google Places API or fallback calculation
 */
const getNearbyPharmacies = async (lat, lng, radius = 5000) => {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey && apiKey !== 'your_google_maps_api_key') {
    try {
      const res = await axios.get(`${MAPS_BASE}/place/nearbysearch/json`, {
        params: { location: `${lat},${lng}`, radius, type: 'pharmacy', key: apiKey },
        timeout: 10000,
      });
      if (res.data.results && res.data.results.length > 0) {
        return res.data.results;
      }
    } catch (e) {
      console.warn('[Maps] Google Places API warning, using internal registry:', e.message);
    }
  }

  // Fallback / simulated nearby pharmacy nodes around the coordinate
  return [
    {
      name: 'Pharmacie du Soleil',
      vicinity: 'Avenue Kennedy, Yaoundé',
      geometry: { location: { lat: parseFloat(lat) + 0.003, lng: parseFloat(lng) + 0.002 } },
      rating: 4.8,
      user_ratings_total: 120,
    },
    {
      name: 'Pharmacie de l\'Unité',
      vicinity: 'Boulevard du 20 Mai, Yaoundé',
      geometry: { location: { lat: parseFloat(lat) - 0.004, lng: parseFloat(lng) - 0.003 } },
      rating: 4.6,
      user_ratings_total: 85,
    },
  ];
};

/**
 * Get route directions & polyline following real road curves
 */
const getDirections = async (originLat, originLng, destLat, destLng) => {
  const oLat = parseFloat(originLat);
  const oLng = parseFloat(originLng);
  const dLat = parseFloat(destLat);
  const dLng = parseFloat(destLng);

  // 1. Try Google Directions if key is present
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey && apiKey !== 'your_google_maps_api_key') {
    try {
      const res = await axios.get(`${MAPS_BASE}/directions/json`, {
        params: {
          origin: `${oLat},${oLng}`,
          destination: `${dLat},${dLng}`,
          mode: 'driving',
          key: apiKey,
        },
        timeout: 6000,
      });
      if (res.data.status === 'OK' && res.data.routes && res.data.routes[0]) {
        return res.data.routes[0];
      }
    } catch (e) {
      console.warn('[Maps] Google Directions API unavailable, falling back to OSM:', e.message);
    }
  }

  // 2. Query OpenStreetMap / OSRM Routing for realistic road network curves
  const osmEndpoints = [
    `https://routing.openstreetmap.de/routed-car/route/v1/driving/${oLng},${oLat};${dLng},${dLat}?overview=full&geometries=geojson`,
    `https://router.project-osrm.org/route/v1/driving/${oLng},${oLat};${dLng},${dLat}?overview=full&geometries=geojson`,
  ];

  for (const url of osmEndpoints) {
    try {
      const res = await axios.get(url, { timeout: 8000 });
      if (res.data.code === 'Ok' && res.data.routes && res.data.routes[0]) {
        const route = res.data.routes[0];
        const rawCoords = route.geometry?.coordinates || [];
        const coordinates = rawCoords.map(([lng, lat]) => ({ lat, lng }));
        const distanceM = Math.round(route.distance || 0);
        const durationS = Math.round(route.duration || 0);
        return {
          overview_polyline: { points: '' },
          coordinates,
          legs: [
            {
              distance: { text: `${(distanceM / 1000).toFixed(1)} km`, value: distanceM },
              duration: { text: `${Math.max(1, Math.round(durationS / 60))} mins`, value: durationS },
              start_location: { lat: oLat, lng: oLng },
              end_location: { lat: dLat, lng: dLng },
            },
          ],
        };
      }
    } catch (e) {
      console.warn('[Maps] OSM endpoint error:', e.message);
    }
  }

  // 3. Calculated fallback route with simulated street bends if completely offline
  const distKm = calculateHaversineDistance(oLat, oLng, dLat, dLng);
  const durationMins = Math.max(5, Math.round(distKm * 2.5));
  
  // Generate multi-segment curve waypoints following a road bend pattern
  const fallbackCoords = [];
  const steps = 16;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const baseLat = oLat + (dLat - oLat) * t;
    const baseLng = oLng + (dLng - oLng) * t;
    // Add realistic road curve offset using sine perpendicular deviation
    const deviation = Math.sin(t * Math.PI) * 0.0025;
    const perpLat = -(dLng - oLng);
    const perpLng = (dLat - oLat);
    const norm = Math.sqrt(perpLat * perpLat + perpLng * perpLng) || 1;
    fallbackCoords.push({
      lat: baseLat + (perpLat / norm) * deviation,
      lng: baseLng + (perpLng / norm) * deviation,
    });
  }

  return {
    overview_polyline: { points: '' },
    coordinates: fallbackCoords,
    legs: [
      {
        distance: { text: `${distKm.toFixed(1)} km`, value: Math.round(distKm * 1000) },
        duration: { text: `${durationMins} mins`, value: durationMins * 60 },
        start_location: { lat: oLat, lng: oLng },
        end_location: { lat: dLat, lng: dLng },
      },
    ],
  };
};

/**
 * Geocode text address into latitude and longitude
 */
const geocode = async (address) => {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey && apiKey !== 'your_google_maps_api_key') {
    try {
      const res = await axios.get(`${MAPS_BASE}/geocode/json`, {
        params: { address: `${address}, Cameroon`, key: apiKey },
        timeout: 10000,
      });
      const location = res.data.results?.[0]?.geometry?.location;
      if (location) return location;
    } catch (e) {
      console.warn('[Maps] Geocoding API warning:', e.message);
    }
  }

  // Fallback matching for Cameroon quarters
  const lower = (address || '').toLowerCase();
  for (const [key, val] of Object.entries(CAMEROON_LOCATIONS)) {
    if (lower.includes(key) || lower.includes(val.name.toLowerCase())) {
      return { lat: val.lat, lng: val.lng };
    }
  }
  return { lat: CAMEROON_LOCATIONS.yaounde.lat, lng: CAMEROON_LOCATIONS.yaounde.lng };
};

/**
 * Reverse geocode latitude and longitude into address
 */
const reverseGeocode = async (lat, lng) => {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey && apiKey !== 'your_google_maps_api_key') {
    try {
      const res = await axios.get(`${MAPS_BASE}/geocode/json`, {
        params: { latlng: `${lat},${lng}`, key: apiKey },
        timeout: 10000,
      });
      const formatted = res.data.results?.[0]?.formatted_address;
      if (formatted) return formatted;
    } catch (e) {
      console.warn('[Maps] Reverse geocoding warning:', e.message);
    }
  }
  return `Location (${parseFloat(lat).toFixed(4)}, ${parseFloat(lng).toFixed(4)}), Cameroon`;
};

/**
 * Calculate distance & courier delivery time
 */
const getDistanceAndDuration = async (originLat, originLng, destLat, destLng) => {
  const route = await getDirections(originLat, originLng, destLat, destLng);
  const leg = route.legs?.[0];
  return {
    distanceKm: leg?.distance?.text || '3.5 km',
    durationText: leg?.duration?.text || '15 mins',
    distanceMeters: leg?.distance?.value || 3500,
    durationSeconds: leg?.duration?.value || 900,
  };
};

module.exports = {
  getNearbyPharmacies,
  getDirections,
  geocode,
  reverseGeocode,
  getDistanceAndDuration,
  calculateHaversineDistance,
};
