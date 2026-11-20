"use client";
import { MapContainer, TileLayer, CircleMarker, useMapEvents, useMap } from "react-leaflet";
import "leaflet/dist/leaflet.css";

type Props = {
  lat: number | null;
  lng: number | null;
  onPick: (lat: number, lng: number) => void;
};

function ClickHandler({ onPick }: { onPick: Props["onPick"] }) {
  useMapEvents({
    click(e) {
      onPick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

function FlyTo({ lat, lng }: { lat: number | null; lng: number | null }) {
  const map = useMap();
  if (lat !== null && lng !== null) {
    map.setView([lat, lng], Math.max(map.getZoom(), 14));
  }
  return null;
}

export default function MapPicker({ lat, lng, onPick }: Props) {
  return (
    <MapContainer
      center={[22.9734, 78.6569]}
      zoom={5}
      style={{ height: 260, width: "100%", borderRadius: 8 }}
    >
      <TileLayer
        attribution="&copy; OpenStreetMap contributors"
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <ClickHandler onPick={onPick} />
      <FlyTo lat={lat} lng={lng} />
      {lat !== null && lng !== null && (
        <CircleMarker
          center={[lat, lng]}
          radius={10}
          pathOptions={{ color: "#dc2626", fillColor: "#dc2626", fillOpacity: 0.7 }}
        />
      )}
    </MapContainer>
  );
}