import * as FileSystem from 'expo-file-system';
import * as MediaLibrary from 'expo-media-library';
import type { Photo, ExifData, LocationCoordinates } from '@/types';
import { generateId, getCurrentTimestamp, generateFilename } from '@/utils';

// EXIF handling - requires react-native-exify in native build
// import { writeExif, readExif } from 'react-native-exify';

/**
 * Photo capture and EXIF management service
 */
export class PhotoService {
  private photoDir: string;
  private thumbnailDir: string;

  constructor() {
    this.photoDir = `${FileSystem.documentDirectory}photos/`;
    this.thumbnailDir = `${FileSystem.documentDirectory}thumbnails/`;
  }

  /**
   * Initialize directories
   */
  async initialize(): Promise<void> {
    for (const dir of [this.photoDir, this.thumbnailDir]) {
      const dirInfo = await FileSystem.getInfoAsync(dir);
      if (!dirInfo.exists) {
        await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
      }
    }
  }

  /**
   * Request media library permissions
   */
  static async requestPermissions(): Promise<boolean> {
    const { status } = await MediaLibrary.requestPermissionsAsync();
    return status === 'granted';
  }

  /**
   * Save captured photo to app storage
   */
  async savePhoto(
    sourceUri: string,
    filename?: string
  ): Promise<{ uri: string; filename: string }> {
    await this.initialize();

    const name = filename || generateFilename('photo', 'jpg');
    const destUri = `${this.photoDir}${name}`;

    await FileSystem.copyAsync({
      from: sourceUri,
      to: destUri,
    });

    return { uri: destUri, filename: name };
  }

  /**
   * Get photo dimensions
   */
  async getPhotoDimensions(uri: string): Promise<{ width: number; height: number }> {
    // In a full implementation with react-native-vision-camera,
    // dimensions would come from the photo metadata
    // This is a placeholder that returns default values
    return { width: 4032, height: 3024 };
  }

  /**
   * Read EXIF data from photo
   *
   * Note: Requires react-native-exify in native build
   */
  async readExifData(uri: string): Promise<ExifData | null> {
    try {
      // Placeholder for EXIF reading
      // In a full implementation with react-native-exify:
      // const exif = await readExif(uri);
      // return this.parseExifData(exif);

      console.log('EXIF reading not implemented - requires native build with react-native-exify');
      return null;
    } catch (error) {
      console.error('Failed to read EXIF:', error);
      return null;
    }
  }

  /**
   * Write GPS coordinates to photo EXIF
   *
   * Note: Requires react-native-exify in native build
   */
  async writeGpsToExif(
    uri: string,
    location: LocationCoordinates
  ): Promise<boolean> {
    try {
      // Placeholder for EXIF writing
      // In a full implementation with react-native-exify:
      // await writeExif(uri, {
      //   GPSLatitude: location.latitude,
      //   GPSLongitude: location.longitude,
      //   GPSAltitude: location.altitude,
      // });

      console.log('EXIF writing not implemented - requires native build with react-native-exify');
      return false;
    } catch (error) {
      console.error('Failed to write GPS EXIF:', error);
      return false;
    }
  }

  /**
   * Generate thumbnail for photo
   */
  async generateThumbnail(
    uri: string,
    maxSize: number = 300
  ): Promise<string | null> {
    await this.initialize();

    try {
      // In a full implementation, this would use an image manipulation library
      // For now, we'll just copy the original as the "thumbnail"
      // A proper implementation would use expo-image-manipulator

      const filename = `thumb_${Date.now()}.jpg`;
      const thumbnailUri = `${this.thumbnailDir}${filename}`;

      // Placeholder: just copy the file
      // Real implementation would resize the image
      await FileSystem.copyAsync({
        from: uri,
        to: thumbnailUri,
      });

      return thumbnailUri;
    } catch (error) {
      console.error('Failed to generate thumbnail:', error);
      return null;
    }
  }

  /**
   * Delete photo and its thumbnail
   */
  async deletePhoto(uri: string, thumbnailUri?: string | null): Promise<void> {
    try {
      await FileSystem.deleteAsync(uri, { idempotent: true });
      if (thumbnailUri) {
        await FileSystem.deleteAsync(thumbnailUri, { idempotent: true });
      }
    } catch (error) {
      console.error('Failed to delete photo:', error);
    }
  }

  /**
   * Save photo to device media library
   */
  async saveToMediaLibrary(uri: string): Promise<string | null> {
    try {
      const hasPermission = await PhotoService.requestPermissions();
      if (!hasPermission) return null;

      const asset = await MediaLibrary.createAssetAsync(uri);
      return asset.uri;
    } catch (error) {
      console.error('Failed to save to media library:', error);
      return null;
    }
  }

  /**
   * Get total size of stored photos
   */
  async getStorageSize(): Promise<number> {
    try {
      let totalSize = 0;

      for (const dir of [this.photoDir, this.thumbnailDir]) {
        const dirInfo = await FileSystem.getInfoAsync(dir);
        if (dirInfo.exists) {
          // Note: FileSystem.getInfoAsync doesn't provide directory size
          // A full implementation would iterate through files
          totalSize += (dirInfo as { size?: number }).size || 0;
        }
      }

      return totalSize;
    } catch {
      return 0;
    }
  }

  /**
   * Parse raw EXIF data into our ExifData type
   */
  private parseExifData(rawExif: Record<string, unknown>): ExifData {
    return {
      make: rawExif.Make as string | undefined,
      model: rawExif.Model as string | undefined,
      focalLength: rawExif.FocalLength as number | undefined,
      aperture: rawExif.ApertureValue as number | undefined,
      iso: rawExif.ISOSpeedRatings as number | undefined,
      exposureTime: rawExif.ExposureTime as string | undefined,
      flash: rawExif.Flash !== undefined ? Boolean(rawExif.Flash) : undefined,
      orientation: rawExif.Orientation as number | undefined,
    };
  }

  /**
   * Extract GPS coordinates from EXIF data
   */
  extractGpsFromExif(exif: Record<string, unknown>): {
    latitude: number;
    longitude: number;
    altitude: number | null;
  } | null {
    const lat = exif.GPSLatitude as number | undefined;
    const lon = exif.GPSLongitude as number | undefined;
    const latRef = exif.GPSLatitudeRef as string | undefined;
    const lonRef = exif.GPSLongitudeRef as string | undefined;

    if (lat === undefined || lon === undefined) return null;

    const latitude = latRef === 'S' ? -lat : lat;
    const longitude = lonRef === 'W' ? -lon : lon;
    const altitude = (exif.GPSAltitude as number) || null;

    return { latitude, longitude, altitude };
  }
}

export default PhotoService;
