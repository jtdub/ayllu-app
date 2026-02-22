import { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Location from 'expo-location';
import { useDatabase } from '@/hooks/useDatabase';
import { useLocation } from '@/hooks/useLocation';
import type { Waypoint, Project, LocationCoordinates } from '@/types';
import { formatCoordinates, getCurrentTimestamp } from '@/utils';

export default function MapScreen() {
  const { waypointRepository, projectRepository } = useDatabase();
  const { location, startTracking, stopTracking, isTracking, error: locationError } = useLocation();
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProject, setSelectedProject] = useState<Project | null>(null);
  const [waypoints, setWaypoints] = useState<Waypoint[]>([]);
  const [mapReady, setMapReady] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, [projectRepository]);

  const loadData = async () => {
    if (!projectRepository) return;

    try {
      const projectList = await projectRepository.getAll();
      setProjects(projectList);

      if (projectList.length > 0 && !selectedProject) {
        setSelectedProject(projectList[0]);
      }
    } catch (error) {
      console.error('Failed to load projects:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (selectedProject && waypointRepository) {
      loadWaypoints();
    }
  }, [selectedProject, waypointRepository]);

  const loadWaypoints = async () => {
    if (!waypointRepository || !selectedProject) return;

    try {
      const data = await waypointRepository.getByProject(selectedProject.id);
      setWaypoints(data);
    } catch (error) {
      console.error('Failed to load waypoints:', error);
    }
  };

  const handleLogWaypoint = async () => {
    if (!location || !selectedProject || !waypointRepository) {
      Alert.alert(
        'Cannot Log Waypoint',
        !selectedProject
          ? 'Please select a project first'
          : 'Location not available. Please enable location services.'
      );
      return;
    }

    const waypointNumber = waypoints.length + 1;

    Alert.prompt(
      'Log Waypoint',
      `Enter a name for this waypoint (${formatCoordinates(location.latitude, location.longitude)}):`,
      async (name) => {
        const waypointName = name?.trim() || `WP${waypointNumber.toString().padStart(3, '0')}`;

        try {
          const waypoint = await waypointRepository.create({
            projectId: selectedProject.id,
            name: waypointName,
            description: null,
            latitude: location.latitude,
            longitude: location.longitude,
            altitude: location.altitude,
            accuracy: location.accuracy,
            heading: location.heading,
            speed: location.speed,
            tags: selectedProject.defaultTags,
            customFields: {},
            timestamp: getCurrentTimestamp(),
          });

          setWaypoints((prev) => [waypoint, ...prev]);
          Alert.alert('Success', `Waypoint "${waypointName}" logged`);
        } catch (error) {
          console.error('Failed to log waypoint:', error);
          Alert.alert('Error', 'Failed to log waypoint');
        }
      },
      'plain-text',
      `WP${waypointNumber.toString().padStart(3, '0')}`
    );
  };

  const handleSelectProject = () => {
    if (projects.length === 0) {
      Alert.alert('No Projects', 'Create a project first from the Dashboard');
      return;
    }

    Alert.alert(
      'Select Project',
      'Choose a project for waypoint logging:',
      projects.map((p) => ({
        text: p.name,
        onPress: () => setSelectedProject(p),
      }))
    );
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#4a9eff" />
        <Text style={styles.loadingText}>Loading map...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Map placeholder - MapLibre requires native build */}
      <View style={styles.mapPlaceholder}>
        <Ionicons name="map-outline" size={80} color="#444" />
        <Text style={styles.placeholderTitle}>Map View</Text>
        <Text style={styles.placeholderText}>
          MapLibre requires a development build.{'\n'}
          Run `npx expo prebuild` then `npx expo run:ios`
        </Text>

        {location && (
          <View style={styles.locationDisplay}>
            <Text style={styles.locationLabel}>Current Location:</Text>
            <Text style={styles.locationCoords}>
              {formatCoordinates(location.latitude, location.longitude)}
            </Text>
            {location.altitude !== null && (
              <Text style={styles.locationAlt}>
                Alt: {location.altitude.toFixed(1)}m
              </Text>
            )}
            {location.accuracy !== null && (
              <Text style={styles.locationAccuracy}>
                Accuracy: ±{location.accuracy.toFixed(1)}m
              </Text>
            )}
          </View>
        )}

        {locationError && (
          <Text style={styles.errorText}>{locationError}</Text>
        )}
      </View>

      {/* Project selector */}
      <TouchableOpacity
        style={styles.projectSelector}
        onPress={handleSelectProject}
      >
        <Ionicons name="folder" size={18} color="#4a9eff" />
        <Text style={styles.projectName}>
          {selectedProject?.name || 'Select Project'}
        </Text>
        <Ionicons name="chevron-down" size={18} color="#888" />
      </TouchableOpacity>

      {/* Waypoint count */}
      {selectedProject && (
        <View style={styles.waypointCount}>
          <Ionicons name="location" size={16} color="#4a9eff" />
          <Text style={styles.waypointCountText}>
            {waypoints.length} waypoints
          </Text>
        </View>
      )}

      {/* Control buttons */}
      <View style={styles.controls}>
        <TouchableOpacity
          style={[styles.controlButton, isTracking && styles.activeButton]}
          onPress={isTracking ? stopTracking : startTracking}
        >
          <Ionicons
            name={isTracking ? 'pause' : 'navigate'}
            size={24}
            color="#fff"
          />
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.controlButton, styles.primaryButton]}
          onPress={handleLogWaypoint}
        >
          <Ionicons name="add-circle" size={24} color="#fff" />
          <Text style={styles.buttonLabel}>Log Waypoint</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  centerContainer: {
    flex: 1,
    backgroundColor: '#0f0f1a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    color: '#888',
    marginTop: 12,
  },
  mapPlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#151525',
  },
  placeholderTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#fff',
    marginTop: 16,
  },
  placeholderText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 20,
  },
  locationDisplay: {
    marginTop: 24,
    padding: 16,
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    alignItems: 'center',
  },
  locationLabel: {
    fontSize: 12,
    color: '#888',
    marginBottom: 4,
  },
  locationCoords: {
    fontSize: 16,
    color: '#fff',
    fontFamily: 'monospace',
  },
  locationAlt: {
    fontSize: 13,
    color: '#aaa',
    marginTop: 4,
  },
  locationAccuracy: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  errorText: {
    fontSize: 14,
    color: '#ff6b6b',
    marginTop: 16,
    textAlign: 'center',
  },
  projectSelector: {
    position: 'absolute',
    top: 16,
    left: 16,
    right: 16,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  projectName: {
    flex: 1,
    color: '#fff',
    fontSize: 16,
    marginLeft: 8,
  },
  waypointCount: {
    position: 'absolute',
    top: 76,
    left: 16,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  waypointCountText: {
    color: '#aaa',
    fontSize: 13,
    marginLeft: 6,
  },
  controls: {
    position: 'absolute',
    bottom: 32,
    left: 16,
    right: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  controlButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2a2a4e',
    paddingHorizontal: 20,
    paddingVertical: 14,
    borderRadius: 12,
  },
  primaryButton: {
    backgroundColor: '#4a9eff',
    flex: 1,
    marginLeft: 12,
    justifyContent: 'center',
  },
  activeButton: {
    backgroundColor: '#ff6b6b',
  },
  buttonLabel: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
});
