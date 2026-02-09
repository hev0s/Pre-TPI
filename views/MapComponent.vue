<template>
  <div class="map-wrapper">
    <div class="controls">
      <h3>Navigation Waze-like</h3>

      <div class="control-group">
        <label>Véhicule :</label>
        <select v-model="selectedProfile">
          <option value="driving-car">Voiture</option>
          <option value="cycling-road">Moto / Scooter</option>
          <option value="foot-walking">Piéton</option>
        </select>
      </div>

      <div class="control-group">
        <label>
          <input type="checkbox" v-model="avoidHighways"> Éviter autoroutes
        </label>
      </div>

      <button @click="calculateRoute" :disabled="loading">
        {{ loading ? 'Calcul en cours...' : 'Calculer Itinéraire' }}
      </button>

      <div v-if="routeInfo" class="route-info">
        <p><strong>Temps :</strong> {{ routeInfo.duration }} min</p>
        <p><strong>Distance :</strong> {{ routeInfo.distance }} km</p>
      </div>

      <p class="instruction" v-if="!destination">📍 Cliquez sur la carte pour choisir une destination.</p>
    </div>

    <div id="mapContainer"></div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import L from 'leaflet';
import axios from 'axios';
import 'leaflet/dist/leaflet.css';

// --- VOTRE CLE API (Celle de votre image qui commence par "ey...") ---
const ORS_API_KEY = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1YzVjNWQwYTQ3ZTQ3YTc5ODJhZDA2NTc0ZDBlOTQ1IiwiaCI6Im11cm11cjY0In0=';
// ---------------------

const map = ref(null);
const userPos = ref(null);
const destination = ref(null);
const routeLayer = ref(null);
const destMarker = ref(null);

// État
const selectedProfile = ref('driving-car');
const avoidHighways = ref(false);
const loading = ref(false);
const routeInfo = ref(null);

onMounted(() => {
  // 1. Init Carte (Centrée sur la Suisse par défaut)
  map.value = L.map('mapContainer').setView([46.5197, 6.6323], 13);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
  }).addTo(map.value);

  // 2. Gestion du clic pour définir l'arrivée
  map.value.on('click', (e) => {
    setDestination(e.latlng.lat, e.latlng.lng);
  });

  // 3. Géolocalisation de l'utilisateur
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(pos => {
      userPos.value = {
        lat: pos.coords.latitude,
        lng: pos.coords.longitude
      };

      // Marqueur "Vous êtes ici"
      L.marker([userPos.value.lat, userPos.value.lng])
          .addTo(map.value)
          .bindPopup("Départ (Vous)")
          .openPopup();

      map.value.setView([userPos.value.lat, userPos.value.lng], 14);
    }, () => {
      alert("Géolocalisation impossible. Vérifiez vos permissions.");
    });
  }
});

// Fonction pour placer le marqueur d'arrivée
const setDestination = (lat, lng) => {
  destination.value = { lat, lng };

  // Supprime l'ancien marqueur si existant
  if (destMarker.value) map.value.removeLayer(destMarker.value);

  // Ajoute le nouveau
  destMarker.value = L.marker([lat, lng])
      .addTo(map.value)
      .bindPopup("Arrivée")
      .openPopup();
};

const calculateRoute = async () => {
  if (!userPos.value) return alert("Attente de votre position...");
  if (!destination.value) return alert("Cliquez sur la carte pour définir l'arrivée !");

  loading.value = true;

  // Nettoyage ancienne route
  if (routeLayer.value) map.value.removeLayer(routeLayer.value);

  try {
    const options = {};
    if (avoidHighways.value) options.avoid_features = ["highways"];

    // Appel API
    const response = await axios.post(
        `https://api.openrouteservice.org/v2/directions/${selectedProfile.value}/geojson`,
        {
          coordinates: [
            [userPos.value.lng, userPos.value.lat], // Longitude d'abord !
            [destination.value.lng, destination.value.lat]
          ],
          options: options
        },
        {
          headers: {
            'Authorization': ORS_API_KEY, // Utilisation directe de la clé "ey..."
            'Content-Type': 'application/json'
          }
        }
    );

    // Affichage
    const route = response.data.features[0];
    routeLayer.value = L.geoJSON(route, {
      style: { color: '#007bff', weight: 6, opacity: 0.8 }
    }).addTo(map.value);

    // Zoom sur le trajet
    map.value.fitBounds(routeLayer.value.getBounds(), { padding: [50, 50] });

    // Infos
    const summary = route.properties.summary;
    routeInfo.value = {
      duration: Math.round(summary.duration / 60),
      distance: (summary.distance / 1000).toFixed(1)
    };

  } catch (error) {
    console.error("Erreur API:", error);
    alert("Erreur lors du calcul. Vérifiez la console (F12) pour les détails.");
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped>
.map-wrapper { position: relative; height: 100vh; width: 100%; }
#mapContainer { height: 100%; width: 100%; z-index: 1; }

.controls {
  position: absolute; top: 20px; left: 20px; z-index: 1000;
  background: white; padding: 20px; border-radius: 12px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2); width: 280px;
  font-family: sans-serif;
}
.control-group { margin-bottom: 15px; }
select { width: 100%; padding: 8px; margin-top: 5px; border-radius: 5px; border: 1px solid #ccc; }
button {
  width: 100%; padding: 10px; background-color: #28a745; color: white;
  border: none; border-radius: 5px; font-weight: bold; cursor: pointer;
  transition: background 0.3s;
}
button:hover { background-color: #218838; }
button:disabled { background-color: #ccc; cursor: not-allowed; }
.route-info { margin-top: 15px; padding-top: 10px; border-top: 1px solid #eee; }
.instruction { font-size: 0.9em; color: #666; margin-top: 10px; font-style: italic; }
</style>