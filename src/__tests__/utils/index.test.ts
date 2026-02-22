import {
  generateId,
  getCurrentTimestamp,
  formatCoordinates,
  decimalToDMS,
  calculateDistance,
  formatDistance,
  isPointInBounds,
  calculateBoundingBox,
  expandBounds,
  calculateTileCount,
  estimateDownloadSize,
  formatFileSize,
  formatDate,
  debounce,
  throttle,
  safeJsonParse,
  sanitizeFilename,
  generateFilename,
} from '../../utils';
import type { BoundingBox } from '../../types';

describe('Utils', () => {
  describe('generateId', () => {
    it('should generate a valid UUID v4', () => {
      const id = generateId();
      expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
    });

    it('should generate unique IDs', () => {
      const ids = new Set(Array.from({ length: 100 }, () => generateId()));
      expect(ids.size).toBe(100);
    });
  });

  describe('getCurrentTimestamp', () => {
    it('should return a valid ISO timestamp', () => {
      const timestamp = getCurrentTimestamp();
      expect(() => new Date(timestamp)).not.toThrow();
      expect(new Date(timestamp).toISOString()).toBe(timestamp);
    });
  });

  describe('formatCoordinates', () => {
    it('should format coordinates in decimal format', () => {
      const result = formatCoordinates(37.7749, -122.4194, 'decimal');
      expect(result).toBe('37.774900, -122.419400');
    });

    it('should format coordinates in DMS format', () => {
      const result = formatCoordinates(37.7749, -122.4194, 'dms');
      expect(result).toContain('N');
      expect(result).toContain('W');
    });

    it('should use decimal as default format', () => {
      const result = formatCoordinates(37.7749, -122.4194);
      expect(result).toBe('37.774900, -122.419400');
    });
  });

  describe('decimalToDMS', () => {
    it('should convert positive latitude correctly', () => {
      const result = decimalToDMS(37.7749, 'lat');
      expect(result).toContain('37°');
      expect(result).toContain('N');
    });

    it('should convert negative latitude correctly', () => {
      const result = decimalToDMS(-33.8688, 'lat');
      expect(result).toContain('33°');
      expect(result).toContain('S');
    });

    it('should convert positive longitude correctly', () => {
      const result = decimalToDMS(151.2093, 'lon');
      expect(result).toContain('151°');
      expect(result).toContain('E');
    });

    it('should convert negative longitude correctly', () => {
      const result = decimalToDMS(-122.4194, 'lon');
      expect(result).toContain('122°');
      expect(result).toContain('W');
    });
  });

  describe('calculateDistance', () => {
    it('should return 0 for same coordinates', () => {
      const distance = calculateDistance(37.7749, -122.4194, 37.7749, -122.4194);
      expect(distance).toBe(0);
    });

    it('should calculate distance between two points', () => {
      // San Francisco to Los Angeles (~559 km)
      const distance = calculateDistance(37.7749, -122.4194, 34.0522, -118.2437);
      expect(distance).toBeGreaterThan(550000);
      expect(distance).toBeLessThan(570000);
    });

    it('should be symmetric', () => {
      const d1 = calculateDistance(37.7749, -122.4194, 34.0522, -118.2437);
      const d2 = calculateDistance(34.0522, -118.2437, 37.7749, -122.4194);
      expect(d1).toBeCloseTo(d2, 5);
    });
  });

  describe('formatDistance', () => {
    it('should format small distances in meters', () => {
      expect(formatDistance(500)).toBe('500 m');
      expect(formatDistance(999)).toBe('999 m');
    });

    it('should format large distances in kilometers', () => {
      expect(formatDistance(1500)).toBe('1.50 km');
      expect(formatDistance(10000)).toBe('10.00 km');
    });

    it('should format distances in feet', () => {
      expect(formatDistance(100, 'feet')).toContain('ft');
    });

    it('should format large distances in miles', () => {
      expect(formatDistance(10000, 'feet')).toContain('mi');
    });
  });

  describe('isPointInBounds', () => {
    const bounds: BoundingBox = {
      minLat: 37.0,
      maxLat: 38.0,
      minLon: -123.0,
      maxLon: -122.0,
    };

    it('should return true for point inside bounds', () => {
      expect(isPointInBounds(37.5, -122.5, bounds)).toBe(true);
    });

    it('should return true for point on bounds edge', () => {
      expect(isPointInBounds(37.0, -122.5, bounds)).toBe(true);
      expect(isPointInBounds(37.5, -123.0, bounds)).toBe(true);
    });

    it('should return false for point outside bounds', () => {
      expect(isPointInBounds(36.5, -122.5, bounds)).toBe(false);
      expect(isPointInBounds(37.5, -121.5, bounds)).toBe(false);
    });
  });

  describe('calculateBoundingBox', () => {
    it('should return null for empty array', () => {
      expect(calculateBoundingBox([])).toBeNull();
    });

    it('should calculate bounding box for single point', () => {
      const coords = [{ latitude: 37.7749, longitude: -122.4194 }];
      const bounds = calculateBoundingBox(coords);
      expect(bounds).toEqual({
        minLat: 37.7749,
        maxLat: 37.7749,
        minLon: -122.4194,
        maxLon: -122.4194,
      });
    });

    it('should calculate bounding box for multiple points', () => {
      const coords = [
        { latitude: 37.0, longitude: -123.0 },
        { latitude: 38.0, longitude: -122.0 },
        { latitude: 37.5, longitude: -122.5 },
      ];
      const bounds = calculateBoundingBox(coords);
      expect(bounds).toEqual({
        minLat: 37.0,
        maxLat: 38.0,
        minLon: -123.0,
        maxLon: -122.0,
      });
    });
  });

  describe('expandBounds', () => {
    it('should expand bounds by percentage', () => {
      const bounds: BoundingBox = {
        minLat: 37.0,
        maxLat: 38.0,
        minLon: -123.0,
        maxLon: -122.0,
      };
      const expanded = expandBounds(bounds, 10);
      expect(expanded.minLat).toBeLessThan(bounds.minLat);
      expect(expanded.maxLat).toBeGreaterThan(bounds.maxLat);
      expect(expanded.minLon).toBeLessThan(bounds.minLon);
      expect(expanded.maxLon).toBeGreaterThan(bounds.maxLon);
    });
  });

  describe('calculateTileCount', () => {
    it('should calculate tile count for a region', () => {
      const bounds: BoundingBox = {
        minLat: 37.7,
        maxLat: 37.8,
        minLon: -122.5,
        maxLon: -122.4,
      };
      const count = calculateTileCount(bounds, 10, 12);
      expect(count).toBeGreaterThan(0);
    });

    it('should increase with zoom range', () => {
      const bounds: BoundingBox = {
        minLat: 37.7,
        maxLat: 37.8,
        minLon: -122.5,
        maxLon: -122.4,
      };
      const count1 = calculateTileCount(bounds, 10, 12);
      const count2 = calculateTileCount(bounds, 10, 14);
      expect(count2).toBeGreaterThan(count1);
    });
  });

  describe('estimateDownloadSize', () => {
    it('should estimate ~15KB per tile', () => {
      const size = estimateDownloadSize(100);
      expect(size).toBe(100 * 15 * 1024);
    });
  });

  describe('formatFileSize', () => {
    it('should format bytes', () => {
      expect(formatFileSize(500)).toBe('500 B');
    });

    it('should format kilobytes', () => {
      expect(formatFileSize(1536)).toBe('1.5 KB');
    });

    it('should format megabytes', () => {
      expect(formatFileSize(1048576)).toBe('1.0 MB');
    });

    it('should format gigabytes', () => {
      expect(formatFileSize(1073741824)).toBe('1.00 GB');
    });
  });

  describe('formatDate', () => {
    it('should format date without time', () => {
      const result = formatDate('2024-01-15T10:30:00Z', false);
      expect(result).toContain('2024');
      expect(result).toContain('15');
    });

    it('should format date with time', () => {
      const result = formatDate('2024-01-15T10:30:00Z', true);
      expect(result).toContain('2024');
    });
  });

  describe('debounce', () => {
    jest.useFakeTimers();

    it('should debounce function calls', () => {
      const fn = jest.fn();
      const debounced = debounce(fn, 100);

      debounced();
      debounced();
      debounced();

      expect(fn).not.toHaveBeenCalled();

      jest.advanceTimersByTime(100);

      expect(fn).toHaveBeenCalledTimes(1);
    });
  });

  describe('throttle', () => {
    jest.useFakeTimers();

    it('should throttle function calls', () => {
      const fn = jest.fn();
      const throttled = throttle(fn, 100);

      throttled();
      throttled();
      throttled();

      expect(fn).toHaveBeenCalledTimes(1);

      jest.advanceTimersByTime(100);
      throttled();

      expect(fn).toHaveBeenCalledTimes(2);
    });
  });

  describe('safeJsonParse', () => {
    it('should parse valid JSON', () => {
      expect(safeJsonParse('{"key": "value"}', {})).toEqual({ key: 'value' });
    });

    it('should return fallback for invalid JSON', () => {
      expect(safeJsonParse('not json', { default: true })).toEqual({ default: true });
    });

    it('should return fallback for null', () => {
      expect(safeJsonParse(null, [])).toEqual([]);
    });

    it('should return fallback for undefined', () => {
      expect(safeJsonParse(undefined, 'fallback')).toBe('fallback');
    });
  });

  describe('sanitizeFilename', () => {
    it('should replace invalid characters with underscores', () => {
      expect(sanitizeFilename('file/with:invalid*chars')).toBe('file_with_invalid_chars');
    });

    it('should collapse multiple underscores', () => {
      expect(sanitizeFilename('file___name')).toBe('file_name');
    });

    it('should preserve valid characters', () => {
      expect(sanitizeFilename('valid-file_name.jpg')).toBe('valid-file_name.jpg');
    });

    it('should truncate long filenames', () => {
      const longName = 'a'.repeat(300);
      expect(sanitizeFilename(longName).length).toBeLessThanOrEqual(255);
    });
  });

  describe('generateFilename', () => {
    it('should generate filename with prefix and extension', () => {
      const filename = generateFilename('photo', 'jpg');
      expect(filename).toMatch(/^photo_.*\.jpg$/);
    });

    it('should include timestamp', () => {
      const filename = generateFilename('waypoint', 'geojson');
      expect(filename).toMatch(/\d{4}-\d{2}-\d{2}/);
    });
  });
});
