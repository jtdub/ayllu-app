import { v4 as uuidv4 } from 'uuid';
import type { BoundingBox, LocationCoordinates } from '@/types';

/**
 * Generate a UUID v4
 */
export function generateId(): string {
  return uuidv4();
}

/**
 * Get current ISO timestamp
 */
export function getCurrentTimestamp(): string {
  return new Date().toISOString();
}

/**
 * Format coordinates for display
 */
export function formatCoordinates(
  lat: number,
  lon: number,
  format: 'decimal' | 'dms' | 'utm' = 'decimal'
): string {
  switch (format) {
    case 'dms':
      return `${decimalToDMS(lat, 'lat')}, ${decimalToDMS(lon, 'lon')}`;
    case 'utm':
      return formatUTM(lat, lon);
    default:
      return `${lat.toFixed(6)}, ${lon.toFixed(6)}`;
  }
}

/**
 * Convert decimal degrees to DMS format
 */
export function decimalToDMS(decimal: number, type: 'lat' | 'lon'): string {
  const absolute = Math.abs(decimal);
  const degrees = Math.floor(absolute);
  const minutesNotTruncated = (absolute - degrees) * 60;
  const minutes = Math.floor(minutesNotTruncated);
  const seconds = ((minutesNotTruncated - minutes) * 60).toFixed(2);

  const direction = type === 'lat' ? (decimal >= 0 ? 'N' : 'S') : decimal >= 0 ? 'E' : 'W';

  return `${degrees}°${minutes}'${seconds}"${direction}`;
}

/**
 * Format coordinates as UTM (simplified)
 */
export function formatUTM(lat: number, lon: number): string {
  // Calculate UTM zone
  const zone = Math.floor((lon + 180) / 6) + 1;
  const hemisphere = lat >= 0 ? 'N' : 'S';

  // Simplified UTM conversion (approximate)
  const k0 = 0.9996;
  const a = 6378137; // WGS84 semi-major axis

  const latRad = (lat * Math.PI) / 180;
  const lonRad = (lon * Math.PI) / 180;
  const lon0Rad = (((zone - 1) * 6 - 180 + 3) * Math.PI) / 180;

  const n = Math.sin(latRad);
  const c = Math.cos(latRad);
  const t = Math.tan(latRad);
  const l = lonRad - lon0Rad;

  const easting = 500000 + k0 * a * l * c;
  const northing = k0 * a * latRad + (lat < 0 ? 10000000 : 0);

  return `${zone}${hemisphere} ${Math.round(easting)}E ${Math.round(northing)}N`;
}

/**
 * Calculate distance between two points in meters (Haversine formula)
 */
export function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
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
 * Format distance for display
 */
export function formatDistance(meters: number, unit: 'meters' | 'feet' = 'meters'): string {
  if (unit === 'feet') {
    const feet = meters * 3.28084;
    if (feet < 5280) {
      return `${Math.round(feet)} ft`;
    }
    return `${(feet / 5280).toFixed(2)} mi`;
  }

  if (meters < 1000) {
    return `${Math.round(meters)} m`;
  }
  return `${(meters / 1000).toFixed(2)} km`;
}

/**
 * Check if a point is within a bounding box
 */
export function isPointInBounds(lat: number, lon: number, bounds: BoundingBox): boolean {
  return (
    lat >= bounds.minLat && lat <= bounds.maxLat && lon >= bounds.minLon && lon <= bounds.maxLon
  );
}

/**
 * Calculate bounding box from array of coordinates
 */
export function calculateBoundingBox(
  coordinates: Array<{ latitude: number; longitude: number }>
): BoundingBox | null {
  if (coordinates.length === 0) return null;

  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLon = Infinity;
  let maxLon = -Infinity;

  for (const coord of coordinates) {
    minLat = Math.min(minLat, coord.latitude);
    maxLat = Math.max(maxLat, coord.latitude);
    minLon = Math.min(minLon, coord.longitude);
    maxLon = Math.max(maxLon, coord.longitude);
  }

  return { minLat, maxLat, minLon, maxLon };
}

/**
 * Expand bounding box by a percentage
 */
export function expandBounds(bounds: BoundingBox, percent: number = 10): BoundingBox {
  const latRange = bounds.maxLat - bounds.minLat;
  const lonRange = bounds.maxLon - bounds.minLon;
  const latExpand = latRange * (percent / 100);
  const lonExpand = lonRange * (percent / 100);

  return {
    minLat: bounds.minLat - latExpand,
    maxLat: bounds.maxLat + latExpand,
    minLon: bounds.minLon - lonExpand,
    maxLon: bounds.maxLon + lonExpand,
  };
}

/**
 * Calculate number of tiles for a region at given zoom levels
 */
export function calculateTileCount(bounds: BoundingBox, minZoom: number, maxZoom: number): number {
  let total = 0;

  for (let z = minZoom; z <= maxZoom; z++) {
    const n = Math.pow(2, z);

    const xMin = Math.floor(((bounds.minLon + 180) / 360) * n);
    const xMax = Math.floor(((bounds.maxLon + 180) / 360) * n);

    const yMin = Math.floor(
      ((1 -
        Math.log(
          Math.tan((bounds.maxLat * Math.PI) / 180) + 1 / Math.cos((bounds.maxLat * Math.PI) / 180)
        ) /
          Math.PI) /
        2) *
        n
    );
    const yMax = Math.floor(
      ((1 -
        Math.log(
          Math.tan((bounds.minLat * Math.PI) / 180) + 1 / Math.cos((bounds.minLat * Math.PI) / 180)
        ) /
          Math.PI) /
        2) *
        n
    );

    total += (xMax - xMin + 1) * (yMax - yMin + 1);
  }

  return total;
}

/**
 * Estimate download size for tiles (rough average of 15KB per tile)
 */
export function estimateDownloadSize(tileCount: number): number {
  return tileCount * 15 * 1024; // ~15KB average per tile
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

/**
 * Format date for display
 */
export function formatDate(isoString: string, includeTime: boolean = false): string {
  const date = new Date(isoString);

  const dateStr = date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });

  if (!includeTime) return dateStr;

  const timeStr = date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
  });

  return `${dateStr} ${timeStr}`;
}

/**
 * Debounce function
 */
export function debounce<T extends (...args: unknown[]) => unknown>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout | null = null;

  return (...args: Parameters<T>) => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

/**
 * Throttle function
 */
export function throttle<T extends (...args: unknown[]) => unknown>(
  func: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle = false;

  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}

/**
 * Parse JSON safely with fallback
 */
export function safeJsonParse<T>(json: string | null | undefined, fallback: T): T {
  if (!json) return fallback;
  try {
    return JSON.parse(json) as T;
  } catch {
    return fallback;
  }
}

/**
 * Sanitize filename for filesystem
 */
export function sanitizeFilename(name: string): string {
  return name
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_+/g, '_')
    .substring(0, 255);
}

/**
 * Generate a unique filename with timestamp
 */
export function generateFilename(prefix: string, extension: string): string {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const id = generateId().substring(0, 8);
  return `${prefix}_${timestamp}_${id}.${extension}`;
}
