<template>
  <div class="map-wrapper">
    <div class="controls">
      <h3>Waze-like</h3>

      <div class="section-title">🚩 Départ</div>
      <div class="control-group radio-group">
        <label>
          <input type="radio" value="gps" v-model="startMode"> Ma Position
        </label>
        <label>
          <input type="radio" value="address" v-model="startMode"> Adresse
        </label>
      </div>

      <div class="control-group" v-if="startMode === 'address'">
        <input type="text" v-model="startAddressText" placeholder="Ex: Gare de Lausanne" @keyup.enter="resolveStart">
      </div>

      <div class="section-title">🏁 Arrivée</div>
      <div class="control-group">
        <input type="text" v-model="destAddressText" placeholder="Ex: Place de la Riponne" @keyup.enter="resolveDest">
      </div>

      <div class="section-title">⚙️ Options</div>
      <div class="control-group">
        <select v-model="selectedProfile">
          <option value="driving-car">Voiture</option>
          <option value="cycling-road">Moto / Scooter</option>
          <option value="foot-walking">Piéton</option>
        </select>
      </div>
      <div class="control-group">
        <label><input type="checkbox" v-model="avoidHighways"> Éviter autoroutes</label>
      </div>

      <button @click="handleCalculation" :disabled="loading" class="action-btn">
        {{ loading ? 'Calcul...' : 'Y aller !' }}
      </button>

      <div v-if="routeInfo" class="route-info">
        <p><strong>Temps :</strong> {{ routeInfo.duration }} min</p>
        <p><strong>Distance :</strong> {{ routeInfo.distance }} km</p>
      </div>

      <p class="error-msg" v-if="errorMessage">{{ errorMessage }}</p>
    </div>

    <div id="mapContainer"></div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import L from 'leaflet';
import axios from 'axios';
import 'leaflet/dist/leaflet.css';

// --- VOTRE CLÉ API ---
const ORS_API_KEY = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1YzVjNWQwYTQ3ZTQ3YTc5ODJhZDA2NTc0ZDBlOTQ1IiwiaCI6Im11cm11cjY0In0=';
// ---------------------

const map = ref(null);
const routeLayer = ref(null);
const startMarker = ref(null);
const destMarker = ref(null);

// Variables Réactives
const startMode = ref('gps'); // 'gps' ou 'address'
const startAddressText = ref('');
const destAddressText = ref('');
const startCoords = ref(null); // {lat, lng}
const destCoords = ref(null);  // {lat, lng}

const selectedProfile = ref('driving-car');
const avoidHighways = ref(false);
const loading = ref(false);
const routeInfo = ref(null);
const errorMessage = ref('');

onMounted(() => {
  // Init Carte
  map.value = L.map('mapContainer').setView([46.5197, 6.6323], 13);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
  }).addTo(map.value);

  // Init Géolocalisation par défaut
  getUserLocation();
});

// Récupérer la position GPS navigateur
const getUserLocation = () => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(pos => {
      startCoords.value = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      updateMarkers();
    }, () => {
      errorMessage.value = "Géolocalisation refusée. Passez en mode 'Adresse'.";
    });
  }
};

// Transformer texte en coordonnées
const geocodeAddress = async (address) => {
  if (!address || address.length < 3) return null;
  try {
    const response = await axios.get(`https://api.openrouteservice.org/geocode/search`, {
      params: {
        api_key: ORS_API_KEY,
        text: address,
        size: 1
      }
    });
    if (response.data.features && response.data.features.length > 0) {
      const coords = response.data.features[0].geometry.coordinates;
      return { lat: coords[1], lng: coords[0] }; // ORS renvoie [Long, Lat], Leaflet veut [Lat, Long]
    }
    return null;
  } catch (err) {
    console.error("Erreur Geocoding", err);
    return null;
  }
};

// Gestionnaires de mise à jour des points
const updateMarkers = () => {
  // Marker Départ
  if (startCoords.value) {
    if (startMarker.value) map.value.removeLayer(startMarker.value);
    startMarker.value = L.marker([startCoords.value.lat, startCoords.value.lng])
        .addTo(map.value).bindPopup("Départ").openPopup();
  }
  // Marker Arrivée
  if (destCoords.value) {
    if (destMarker.value) map.value.removeLayer(destMarker.value);
    destMarker.value = L.marker([destCoords.value.lat, destCoords.value.lng])
        .addTo(map.value).bindPopup("Arrivée");
  }
  // Centrer la vue si on a les deux points
  if (startCoords.value && destCoords.value) {
    const group = new L.featureGroup([startMarker.value, destMarker.value]);
    map.value.fitBounds(group.getBounds(), { padding: [50, 50] });
  } else if (startCoords.value) {
    map.value.setView([startCoords.value.lat, startCoords.value.lng], 14);
  }
};

// Lancement du calcul global
const handleCalculation = async () => {
  loading.value = true;
  errorMessage.value = '';
  routeInfo.value = null;

  try {
    // 1. Résoudre le point de DÉPART
    if (startMode.value === 'gps') {
      if (!startCoords.value) { // Si pas encore localisé, on réessaie
        await new Promise((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(pos => {
            startCoords.value = { lat: pos.coords.latitude, lng: pos.coords.longitude };
            resolve();
          }, reject);
        });
      }
    } else {
      // Mode adresse manuelle
      const coords = await geocodeAddress(startAddressText.value);
      if (!coords) throw new Error("Adresse de départ introuvable.");
      startCoords.value = coords;
    }

    // 2. Résoudre le point d'ARRIVÉE
    const destRes = await geocodeAddress(destAddressText.value);
    if (!destRes) throw new Error("Adresse d'arrivée introuvable.");
    destCoords.value = destRes;

    updateMarkers();

    // 3. Calculer l'itinéraire
    await calculateRouteAPI();

  } catch (error) {
    errorMessage.value = error.message || "Erreur lors du calcul.";
  } finally {
    loading.value = false;
  }
};

const calculateRouteAPI = async () => {
  if (routeLayer.value) map.value.removeLayer(routeLayer.value);

  const options = {};
  if (avoidHighways.value) options.avoid_features = ["highways"];

  const response = await axios.post(
      `https://api.openrouteservice.org/v2/directions/${selectedProfile.value}/geojson`,
      {
        coordinates: [
          [startCoords.value.lng, startCoords.value.lat],
          [destCoords.value.lng, destCoords.value.lat]
        ],
        options: options
      },
      {
        headers: {
          'Authorization': ORS_API_KEY,
          'Content-Type': 'application/json'
        }
      }
  );

  const route = response.data.features[0];
  routeLayer.value = L.geoJSON(route, {
    style: { color: '#007bff', weight: 6, opacity: 0.8 }
  }).addTo(map.value);

  map.value.fitBounds(routeLayer.value.getBounds(), { padding: [50, 50] });

  const summary = route.properties.summary;
  routeInfo.value = {
    duration: Math.round(summary.duration / 60),
    distance: (summary.distance / 1000).toFixed(1)
  };
};
</script>

<style scoped>
.map-wrapper { position: relative; height: 100vh; width: 100%; }
#mapContainer { height: 100%; width: 100%; z-index: 1; }

.controls {
  position: absolute; top: 20px; left: 20px; z-index: 1000;
  background: white; padding: 20px; border-radius: 12px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2); width: 300px;
  max-height: 90vh; overflow-y: auto; font-family: sans-serif;
}
.section-title { font-weight: bold; margin-bottom: 5px; color: #333; font-size: 0.9em; margin-top: 10px; }
.control-group { margin-bottom: 10px; }
.radio-group { display: flex; gap: 15px; font-size: 0.9em; }
input[type="text"], select { width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 5px; box-sizing: border-box; }
.action-btn {
  width: 100%; padding: 12px; background-color: #28a745; color: white;
  border: none; border-radius: 5px; font-weight: bold; cursor: pointer; margin-top: 10px;
}
.action-btn:hover { background-color: #218838; }
.action-btn:disabled { background-color: #ccc; }
.error-msg { color: red; font-size: 0.85em; margin-top: 5px; }
</style>