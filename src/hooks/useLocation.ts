/**
 * @fileoverview React hook for GPS location management
 *
 * Provides a convenient hook interface for location permissions, tracking,
 * and retrieving the current device position in React components.
 *
 * @module hooks/useLocation
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import * as Location from 'expo-location';
import type { LocationCoordinates } from '@/types';

/**
 * Configuration options for the useLocation hook.
 */
interface UseLocationOptions {
  /** Use high accuracy GPS mode (default: true) */
  enableHighAccuracy?: boolean;
  /** Minimum distance (meters) between location updates (default: 10) */
  distanceInterval?: number;
  /** Minimum time (ms) between location updates (default: 5000) */
  timeInterval?: number;
  /** Automatically fetch location on mount when permission is granted (default: true) */
  autoStart?: boolean;
}

/**
 * Return value of the useLocation hook.
 */
interface UseLocationReturn {
  /** Current location coordinates, or null if not yet available */
  location: LocationCoordinates | null;
  /** Error message if location operations fail, or null */
  error: string | null;
  /** Whether continuous location tracking is active */
  isTracking: boolean;
  /** Whether location permission has been granted (null until checked) */
  hasPermission: boolean | null;
  /** Start continuous location tracking */
  startTracking: () => Promise<void>;
  /** Stop continuous location tracking */
  stopTracking: () => void;
  /** Get current location once */
  getCurrentLocation: () => Promise<LocationCoordinates | null>;
  /** Request location permissions from the user */
  requestPermission: () => Promise<boolean>;
}

/**
 * React hook for managing device location.
 *
 * Provides reactive state for location data, permission status, and tracking state.
 * Automatically checks permissions on mount and optionally fetches initial location.
 *
 * @param options - Configuration options for location tracking
 * @returns Object with location state and control functions
 *
 * @example
 * ```typescript
 * function MapScreen() {
 *   const {
 *     location,
 *     error,
 *     isTracking,
 *     hasPermission,
 *     startTracking,
 *     stopTracking,
 *     getCurrentLocation,
 *     requestPermission,
 *   } = useLocation({
 *     enableHighAccuracy: true,
 *     distanceInterval: 5,
 *     autoStart: true,
 *   });
 *
 *   if (!hasPermission) {
 *     return (
 *       <Button onPress={requestPermission}>
 *         Grant Location Permission
 *       </Button>
 *     );
 *   }
 *
 *   return (
 *     <View>
 *       {location && (
 *         <Text>
 *           Position: {location.latitude}, {location.longitude}
 *         </Text>
 *       )}
 *       {error && <Text style={styles.error}>{error}</Text>}
 *       <Button
 *         onPress={isTracking ? stopTracking : startTracking}
 *       >
 *         {isTracking ? 'Stop Tracking' : 'Start Tracking'}
 *       </Button>
 *     </View>
 *   );
 * }
 * ```
 */
export function useLocation(options: UseLocationOptions = {}): UseLocationReturn {
  const {
    enableHighAccuracy = true,
    distanceInterval = 10, // meters
    timeInterval = 5000, // ms
    autoStart = true,
  } = options;

  const [location, setLocation] = useState<LocationCoordinates | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isTracking, setIsTracking] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);

  const subscriptionRef = useRef<Location.LocationSubscription | null>(null);

  /**
   * Request foreground and background location permissions.
   *
   * @returns `true` if foreground permission was granted
   */
  const requestPermission = useCallback(async (): Promise<boolean> => {
    try {
      const { status: foregroundStatus } = await Location.requestForegroundPermissionsAsync();

      if (foregroundStatus !== 'granted') {
        setError('Location permission denied');
        setHasPermission(false);
        return false;
      }

      // Request background permission for tracking during fieldwork
      const { status: backgroundStatus } = await Location.requestBackgroundPermissionsAsync();

      // Background permission is optional, foreground is enough for basic use
      setHasPermission(true);
      setError(null);
      return true;
    } catch (err) {
      setError('Failed to request location permission');
      setHasPermission(false);
      return false;
    }
  }, []);

  /**
   * Get the current device location.
   *
   * Automatically requests permission if not already granted.
   *
   * @returns Current location coordinates or null on failure
   */
  const getCurrentLocation = useCallback(async (): Promise<LocationCoordinates | null> => {
    try {
      if (!hasPermission) {
        const granted = await requestPermission();
        if (!granted) return null;
      }

      const locationResult = await Location.getCurrentPositionAsync({
        accuracy: enableHighAccuracy
          ? Location.Accuracy.BestForNavigation
          : Location.Accuracy.Balanced,
      });

      const coords: LocationCoordinates = {
        latitude: locationResult.coords.latitude,
        longitude: locationResult.coords.longitude,
        altitude: locationResult.coords.altitude,
        accuracy: locationResult.coords.accuracy,
        heading: locationResult.coords.heading,
        speed: locationResult.coords.speed,
        timestamp: locationResult.timestamp,
      };

      setLocation(coords);
      setError(null);
      return coords;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to get location';
      setError(message);
      return null;
    }
  }, [hasPermission, enableHighAccuracy, requestPermission]);

  /**
   * Start continuous location tracking.
   *
   * Location updates are received based on distanceInterval and timeInterval settings.
   * Does nothing if tracking is already active.
   */
  const startTracking = useCallback(async (): Promise<void> => {
    if (isTracking) return;

    try {
      if (!hasPermission) {
        const granted = await requestPermission();
        if (!granted) return;
      }

      subscriptionRef.current = await Location.watchPositionAsync(
        {
          accuracy: enableHighAccuracy
            ? Location.Accuracy.BestForNavigation
            : Location.Accuracy.Balanced,
          distanceInterval,
          timeInterval,
        },
        (locationResult) => {
          const coords: LocationCoordinates = {
            latitude: locationResult.coords.latitude,
            longitude: locationResult.coords.longitude,
            altitude: locationResult.coords.altitude,
            accuracy: locationResult.coords.accuracy,
            heading: locationResult.coords.heading,
            speed: locationResult.coords.speed,
            timestamp: locationResult.timestamp,
          };

          setLocation(coords);
          setError(null);
        }
      );

      setIsTracking(true);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to start tracking';
      setError(message);
    }
  }, [isTracking, hasPermission, enableHighAccuracy, distanceInterval, timeInterval, requestPermission]);

  /**
   * Stop continuous location tracking.
   *
   * Safe to call even if tracking is not active.
   */
  const stopTracking = useCallback((): void => {
    if (subscriptionRef.current) {
      subscriptionRef.current.remove();
      subscriptionRef.current = null;
    }
    setIsTracking(false);
  }, []);

  // Check permission on mount and optionally fetch initial location
  useEffect(() => {
    (async () => {
      const { status } = await Location.getForegroundPermissionsAsync();
      setHasPermission(status === 'granted');

      if (status === 'granted' && autoStart) {
        getCurrentLocation();
      }
    })();

    // Cleanup subscription on unmount
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.remove();
      }
    };
  }, []);

  return {
    location,
    error,
    isTracking,
    hasPermission,
    startTracking,
    stopTracking,
    getCurrentLocation,
    requestPermission,
  };
}

export default useLocation;
