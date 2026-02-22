/**
 * @fileoverview GPS location service for field data collection
 *
 * Provides functionality for requesting permissions, getting current location,
 * and tracking location changes during fieldwork. Uses expo-location under the hood.
 *
 * @module services/location/LocationService
 */

import * as Location from 'expo-location';
import type { LocationCoordinates, BoundingBox } from '@/types';

/**
 * Service class for GPS location operations.
 *
 * Handles permission management, single location queries, and continuous
 * location tracking for field research activities.
 *
 * @example
 * ```typescript
 * // Request permissions
 * const granted = await LocationService.requestPermissions();
 *
 * // Get current location
 * const location = await LocationService.getCurrentLocation();
 *
 * // Start tracking
 * const service = new LocationService();
 * await service.startTracking((coords) => {
 *   console.log('New position:', coords);
 * });
 * ```
 */
export class LocationService {
  /** Active location subscription for tracking */
  private subscription: Location.LocationSubscription | null = null;

  /** Whether tracking is currently active */
  private isTracking = false;

  /**
   * Request location permissions from the user.
   *
   * Requests foreground permission (required) and background permission (optional).
   * Background permission enables location tracking when the app is minimized.
   *
   * @returns `true` if foreground permission was granted, `false` otherwise
   *
   * @example
   * ```typescript
   * const granted = await LocationService.requestPermissions();
   * if (!granted) {
   *   Alert.alert('Permission Required', 'Location access is needed for GPS logging');
   * }
   * ```
   */
  static async requestPermissions(): Promise<boolean> {
    const { status: foreground } = await Location.requestForegroundPermissionsAsync();
    if (foreground !== 'granted') return false;

    // Background permission is optional
    await Location.requestBackgroundPermissionsAsync();
    return true;
  }

  /**
   * Check current permission status without prompting the user.
   *
   * @returns Object indicating foreground and background permission status
   *
   * @example
   * ```typescript
   * const { foreground, background } = await LocationService.checkPermissions();
   * if (!foreground) {
   *   // Show permission request UI
   * }
   * ```
   */
  static async checkPermissions(): Promise<{
    foreground: boolean;
    background: boolean;
  }> {
    const { status: foreground } = await Location.getForegroundPermissionsAsync();
    const { status: background } = await Location.getBackgroundPermissionsAsync();

    return {
      foreground: foreground === 'granted',
      background: background === 'granted',
    };
  }

  /**
   * Get the current device location.
   *
   * Returns a single location reading with coordinates and accuracy data.
   * High accuracy mode uses GPS and may take longer but provides better precision.
   *
   * @param highAccuracy - Use high accuracy GPS mode (default: true)
   * @returns Location coordinates or null if location could not be determined
   *
   * @example
   * ```typescript
   * const location = await LocationService.getCurrentLocation(true);
   * if (location) {
   *   console.log(`Position: ${location.latitude}, ${location.longitude}`);
   *   console.log(`Accuracy: ±${location.accuracy}m`);
   * }
   * ```
   */
  static async getCurrentLocation(highAccuracy = true): Promise<LocationCoordinates | null> {
    try {
      const location = await Location.getCurrentPositionAsync({
        accuracy: highAccuracy ? Location.Accuracy.BestForNavigation : Location.Accuracy.Balanced,
      });

      return {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        altitude: location.coords.altitude,
        accuracy: location.coords.accuracy,
        heading: location.coords.heading,
        speed: location.coords.speed,
        timestamp: location.timestamp,
      };
    } catch (error) {
      console.error('Failed to get current location:', error);
      return null;
    }
  }

  /**
   * Start continuous location tracking.
   *
   * Begins watching position changes and calls the callback with each update.
   * Updates are triggered by distance traveled or time elapsed, whichever comes first.
   *
   * @param onLocation - Callback invoked with each location update
   * @param options - Tracking configuration options
   * @param options.distanceInterval - Minimum distance (meters) between updates (default: 10)
   * @param options.timeInterval - Minimum time (ms) between updates (default: 5000)
   * @param options.highAccuracy - Use high accuracy GPS mode (default: true)
   *
   * @example
   * ```typescript
   * const service = new LocationService();
   *
   * await service.startTracking(
   *   (coords) => {
   *     console.log('New position:', coords);
   *     saveWaypoint(coords);
   *   },
   *   { distanceInterval: 5, timeInterval: 3000 }
   * );
   *
   * // Later...
   * service.stopTracking();
   * ```
   */
  async startTracking(
    onLocation: (location: LocationCoordinates) => void,
    options: {
      distanceInterval?: number;
      timeInterval?: number;
      highAccuracy?: boolean;
    } = {}
  ): Promise<void> {
    if (this.isTracking) return;

    const { distanceInterval = 10, timeInterval = 5000, highAccuracy = true } = options;

    this.subscription = await Location.watchPositionAsync(
      {
        accuracy: highAccuracy ? Location.Accuracy.BestForNavigation : Location.Accuracy.Balanced,
        distanceInterval,
        timeInterval,
      },
      (location) => {
        onLocation({
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          altitude: location.coords.altitude,
          accuracy: location.coords.accuracy,
          heading: location.coords.heading,
          speed: location.coords.speed,
          timestamp: location.timestamp,
        });
      }
    );

    this.isTracking = true;
  }

  /**
   * Stop location tracking.
   *
   * Removes the active location subscription and cleans up resources.
   * Safe to call even if tracking is not active.
   */
  stopTracking(): void {
    if (this.subscription) {
      this.subscription.remove();
      this.subscription = null;
    }
    this.isTracking = false;
  }

  /**
   * Check if device location services are enabled.
   *
   * @returns `true` if location services are available and enabled
   *
   * @example
   * ```typescript
   * const enabled = await LocationService.isLocationEnabled();
   * if (!enabled) {
   *   Alert.alert('Enable Location', 'Please enable location services in Settings');
   * }
   * ```
   */
  static async isLocationEnabled(): Promise<boolean> {
    return await Location.hasServicesEnabledAsync();
  }

  /**
   * Check if a geographic point is within a bounding box.
   *
   * @param lat - Latitude to check
   * @param lon - Longitude to check
   * @param bounds - Bounding box to test against
   * @returns `true` if the point is within the bounds
   *
   * @example
   * ```typescript
   * const inProject = LocationService.isInBounds(
   *   37.7749,
   *   -122.4194,
   *   projectBounds
   * );
   * ```
   */
  static isInBounds(lat: number, lon: number, bounds: BoundingBox): boolean {
    return (
      lat >= bounds.minLat && lat <= bounds.maxLat && lon >= bounds.minLon && lon <= bounds.maxLon
    );
  }

  /**
   * Calculate the distance between two geographic points using the Haversine formula.
   *
   * The Haversine formula accounts for the Earth's curvature and provides
   * accurate results for distances up to thousands of kilometers.
   *
   * @param lat1 - Latitude of first point in decimal degrees
   * @param lon1 - Longitude of first point in decimal degrees
   * @param lat2 - Latitude of second point in decimal degrees
   * @param lon2 - Longitude of second point in decimal degrees
   * @returns Distance in meters
   *
   * @example
   * ```typescript
   * const distance = LocationService.calculateDistance(
   *   37.7749, -122.4194,  // San Francisco
   *   34.0522, -118.2437   // Los Angeles
   * );
   * console.log(`Distance: ${distance / 1000} km`);
   * ```
   */
  static calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371000; // Earth's radius in meters
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
  }

  /**
   * Calculate the compass bearing from one point to another.
   *
   * Returns the initial bearing (forward azimuth) that would be followed
   * to travel from point 1 to point 2 along a great-circle arc.
   *
   * @param lat1 - Latitude of starting point in decimal degrees
   * @param lon1 - Longitude of starting point in decimal degrees
   * @param lat2 - Latitude of destination point in decimal degrees
   * @param lon2 - Longitude of destination point in decimal degrees
   * @returns Bearing in degrees (0-360, where 0 = North, 90 = East)
   *
   * @example
   * ```typescript
   * const bearing = LocationService.calculateBearing(
   *   37.7749, -122.4194,  // From SF
   *   34.0522, -118.2437   // To LA
   * );
   * console.log(`Head ${bearing}° from North`);
   * ```
   */
  static calculateBearing(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const lat1Rad = (lat1 * Math.PI) / 180;
    const lat2Rad = (lat2 * Math.PI) / 180;

    const y = Math.sin(dLon) * Math.cos(lat2Rad);
    const x =
      Math.cos(lat1Rad) * Math.sin(lat2Rad) -
      Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLon);

    const bearing = (Math.atan2(y, x) * 180) / Math.PI;
    return (bearing + 360) % 360;
  }
}
