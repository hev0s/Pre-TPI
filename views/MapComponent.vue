<template>
  <div id="mapContainer"></div>

  <button @click="testRoute" class="route-btn">Tester Itinéraire</button>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet-routing-machine/dist/leaflet-routing-machine.css'; // CSS pour l'itinéraire
import 'leaflet-routing-machine'; // Import du JS pour le routing
import { io } from 'socket.io-client';

// Important : Fix pour les icôns Leaflet qui buggent parfois avec Vite/Webpack
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

// Configuration des icônes par défaut
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: markerIcon,
  iconRetinaUrl: markerIcon2x,
  shadowUrl: markerShadow,
});

const socket = io('http://localhost:3000');
const map = ref(null);
const routingControl = ref(null);

onMounted(() => {
  // 1. Initialiser la carte (Lausanne)
  map.value = L.map('mapContainer').setView([46.5197, 6.6323], 13);

  // 2. Ajouter les tuiles GRATUITES (OpenStreetMap)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap'
  }).addTo(map.value);

  // 3. Géolocalisation de l'utilisateur
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition((position) => {
      const { latitude, longitude } = position.coords;

      // Marqueur utilisateur
      L.marker([latitude, longitude])
          .addTo(map.value)
          .bindPopup("Vous êtes ici")
          .openPopup();

      map.value.setView([latitude, longitude], 14);
    });
  }

  // 4. Gestion des incidents (Temps réel via Socket.io)
  socket.on('receive_incident', (incident) => {
    // On peut changer l'icône selon le type d'incident ici
    L.marker([incident.lat, incident.lng])
        .addTo(map.value)
        .bindPopup(`<b>${incident.type}</b><br>${incident.description}`);
  });
});

// Fonction pour tracer un itinéraire (Point A -> Point B)
// C'est ça qui remplace l'API Google Directions payante
const testRoute = () => {
  if (routingControl.value) {
    map.value.removeControl(routingControl.value); // Nettoyer l'ancien itinéraire
  }

  // Utilisation de OSRM (Service gratuit par défaut)
  routingControl.value = L.Routing.control({
    waypoints: [
      L.latLng(46.5197, 6.6323), // Départ: Lausanne Centre (exemple)
      L.latLng(46.5333, 6.6667)  // Arrivée: Pully (exemple)
    ],
    routeWhileDragging: true,
    language: 'fr', // Instructions en français
    showAlternatives: false
  }).addTo(map.value);
};
</script>

<style scoped>
#mapContainer {
  height: 100vh;
  width: 100%;
  z-index: 1;
}

.route-btn {
  position: absolute;
  top: 10px;
  right: 10px;
  z-index: 1000; /* Au-dessus de la carte */
  padding: 10px 20px;
  background-color: #2c3e50;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
}
</style>