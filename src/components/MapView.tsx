"use client";
import { useEffect } from "react";
import Link from "next/link";
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from "react-leaflet";
import "leaflet/dist/leaflet.css";

export type MapPoint = {
  id: string;
  lat: number;
  lng: number;
  type: string;
  title: string;
};

function Fit({ points }: { points: MapPoint[] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length === 0) return;
    if (points.length === 1) {
      map.setView([points[0].lat, points[0].lng], 14);
      return;
    }
    map.fitBounds(
      points.map((p) => [p.lat, p.lng] as [number, number]),
      { padding: [40, 40], maxZoom: 13 }
    );
  }, [points, map]);
  return null;
}

export default function MapView({
  points,
  height = 320,
  popups = true,
}: {
  points: MapPoint[];
  height?: number;
  popups?: boolean;
}) {
  return (
    <MapContainer
      center={[22.9734, 78.6569]}
      zoom={5}
      style={{ height, width: "100%" }}
    >
      <TileLayer
        attribution="&copy; OpenStreetMap contributors"
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Fit points={points} />
      {points.map((p) => (
        <CircleMarker
          key={p.id}
          center={[p.lat, p.lng]}
          radius={9}
          pathOptions={{
            color: "#0e1a3a",
            weight: 2,
            fillColor: p.type === "lost" ? "#c23b20" : "#14815a",
            fillOpacity: 0.9,
          }}
        >
          {popups && (
            <Popup>
              <div style={{ minWidth: 140 }}>
                <strong>{p.title}</strong>
                <br />
                {p.type === "lost" ? "Lost" : "Found"}
                <br />
                <Link href={`/items/${p.id}`} style={{ color: "#162fa3", textDecoration: "underline" }}>
                  View details
                </Link>
              </div>
            </Popup>
          )}
        </CircleMarker>
      ))}
    </MapContainer>
  );
}
