import React, { useRef, useEffect, useState } from 'react';
import { View, StyleSheet, ActivityIndicator, Text } from 'react-native';
import type { MapLayer, BoundingBox, MarkerData } from '@/types';

// MapLibre imports - these will work after `npx expo prebuild`
// import MapLibreGL from '@maplibre/maplibre-react-native';

interface MapViewProps {
  initialCenter?: { latitude: number; longitude: number };
  initialZoom?: number;
  markers?: MarkerData[];
  selectedMarkerId?: string;
  mapLayer?: MapLayer;
  showUserLocation?: boolean;
  onMarkerPress?: (marker: MarkerData) => void;
  onMapPress?: (coordinate: { latitude: number; longitude: number }) => void;
  onRegionChange?: (bounds: BoundingBox) => void;
}

/**
 * MapView component wrapping MapLibre GL
 *
 * Note: Requires development build with native modules.
 * Run `npx expo prebuild` then `npx expo run:ios` or `npx expo run:android`
 */
export function MapView({
  initialCenter = { latitude: 0, longitude: 0 },
  initialZoom = 12,
  markers = [],
  selectedMarkerId,
  mapLayer = 'topo',
  showUserLocation = true,
  onMarkerPress,
  onMapPress,
  onRegionChange,
}: MapViewProps) {
  const [isMapLibreAvailable, setIsMapLibreAvailable] = useState(false);
  const mapRef = useRef(null);

  useEffect(() => {
    // Check if MapLibre is available (requires native build)
    try {
      // const MapLibreGL = require('@maplibre/maplibre-react-native');
      // MapLibreGL.setAccessToken(null);
      // setIsMapLibreAvailable(true);
      setIsMapLibreAvailable(false); // Set to false until native build
    } catch {
      setIsMapLibreAvailable(false);
    }
  }, []);

  const getStyleUrl = (layer: MapLayer): string => {
    switch (layer) {
      case 'satellite':
        return 'https://api.maptiler.com/maps/hybrid/style.json';
      case 'topo':
      default:
        return 'https://api.maptiler.com/maps/topo-v2/style.json';
    }
  };

  if (!isMapLibreAvailable) {
    return (
      <View style={styles.placeholder}>
        <ActivityIndicator size="large" color="#4a9eff" />
        <Text style={styles.placeholderTitle}>Map View</Text>
        <Text style={styles.placeholderText}>
          MapLibre requires a development build.{'\n'}
          Run `npx expo prebuild` then{'\n'}
          `npx expo run:ios` or `npx expo run:android`
        </Text>
      </View>
    );
  }

  // Full MapLibre implementation (uncomment after native build)
  /*
  return (
    <MapLibreGL.MapView
      ref={mapRef}
      style={styles.map}
      styleURL={getStyleUrl(mapLayer)}
      onPress={(e) => {
        if (onMapPress && e.geometry.coordinates) {
          onMapPress({
            latitude: e.geometry.coordinates[1],
            longitude: e.geometry.coordinates[0],
          });
        }
      }}
      onRegionDidChange={(e) => {
        if (onRegionChange && e.properties.visibleBounds) {
          const [ne, sw] = e.properties.visibleBounds;
          onRegionChange({
            minLat: sw[1],
            maxLat: ne[1],
            minLon: sw[0],
            maxLon: ne[0],
          });
        }
      }}
    >
      <MapLibreGL.Camera
        defaultSettings={{
          centerCoordinate: [initialCenter.longitude, initialCenter.latitude],
          zoomLevel: initialZoom,
        }}
      />

      {showUserLocation && (
        <MapLibreGL.UserLocation visible={true} />
      )}

      {markers.map((marker) => (
        <MapLibreGL.PointAnnotation
          key={marker.id}
          id={marker.id}
          coordinate={[marker.coordinate.longitude, marker.coordinate.latitude]}
          onSelected={() => onMarkerPress?.(marker)}
        >
          <WaypointMarker
            type={marker.type}
            selected={marker.id === selectedMarkerId}
          />
        </MapLibreGL.PointAnnotation>
      ))}
    </MapLibreGL.MapView>
  );
  */

  return null;
}

const styles = StyleSheet.create({
  map: {
    flex: 1,
  },
  placeholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#151525',
  },
  placeholderTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#fff',
    marginTop: 16,
  },
  placeholderText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 22,
  },
});

export default MapView;
