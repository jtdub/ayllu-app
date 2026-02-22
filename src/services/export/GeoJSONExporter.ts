/**
 * @fileoverview GeoJSON export service for field research data
 *
 * Provides functionality to convert project data (waypoints, photos, notes)
 * into GeoJSON format for use in GIS applications like QGIS.
 *
 * @module services/export/GeoJSONExporter
 */

import type {
  Project,
  Waypoint,
  Photo,
  FieldNote,
  GeoJSONFeatureCollection,
  GeoJSONFeature,
} from '@/types';

/**
 * Service class for exporting field research data to GeoJSON format.
 *
 * GeoJSON is the primary export format, providing interoperability with
 * desktop GIS software and web mapping applications.
 *
 * @example
 * ```typescript
 * // Export a complete project
 * const geojson = GeoJSONExporter.exportProject(
 *   project,
 *   waypoints,
 *   photos,
 *   notes
 * );
 *
 * // Write to file or share
 * await FileSystem.writeAsStringAsync(filePath, geojson);
 * ```
 */
export class GeoJSONExporter {
  /**
   * Export a complete project with all waypoints, photos, and notes as GeoJSON.
   *
   * Creates a FeatureCollection containing all geographic entities from the project.
   * Photos and notes without location data are excluded from the export.
   *
   * @param project - The project metadata
   * @param waypoints - Array of waypoints to include
   * @param photos - Array of photos to include (only those with lat/lon)
   * @param notes - Array of field notes to include (only those with lat/lon)
   * @returns Formatted GeoJSON string with project metadata in properties
   *
   * @example
   * ```typescript
   * const geojson = GeoJSONExporter.exportProject(
   *   project,
   *   waypoints,
   *   photos,
   *   notes
   * );
   * ```
   */
  static exportProject(
    project: Project,
    waypoints: Waypoint[],
    photos: Photo[],
    notes: FieldNote[]
  ): string {
    const features: GeoJSONFeature[] = [];

    // Add waypoint features
    for (const waypoint of waypoints) {
      features.push(this.waypointToFeature(waypoint));
    }

    // Add photo features (only those with location)
    for (const photo of photos) {
      if (photo.latitude !== null && photo.longitude !== null) {
        features.push(this.photoToFeature(photo));
      }
    }

    // Add note features (only those with location)
    for (const note of notes) {
      if (note.latitude !== null && note.longitude !== null) {
        features.push(this.noteToFeature(note));
      }
    }

    const featureCollection: GeoJSONFeatureCollection = {
      type: 'FeatureCollection',
      features,
      properties: {
        project: {
          id: project.id,
          name: project.name,
          description: project.description,
          startDate: project.startDate,
          endDate: project.endDate,
          boundingBox: project.boundingBox,
          defaultTags: project.defaultTags,
          customFields: project.customFields,
          createdAt: project.createdAt,
          updatedAt: project.updatedAt,
        },
        exportedAt: new Date().toISOString(),
        version: '1.0.0',
      },
    };

    return JSON.stringify(featureCollection, null, 2);
  }

  /**
   * Export waypoints only as a GeoJSON FeatureCollection.
   *
   * Useful when only waypoint data is needed, without photos or notes.
   *
   * @param waypoints - Array of waypoints to export
   * @returns Formatted GeoJSON string
   */
  static exportWaypoints(waypoints: Waypoint[]): string {
    const features = waypoints.map(wp => this.waypointToFeature(wp));

    const featureCollection: GeoJSONFeatureCollection = {
      type: 'FeatureCollection',
      features,
    };

    return JSON.stringify(featureCollection, null, 2);
  }

  /**
   * Export photos with location data as a GeoJSON FeatureCollection.
   *
   * Photos without latitude/longitude coordinates are filtered out.
   *
   * @param photos - Array of photos to export
   * @returns Formatted GeoJSON string containing only geolocated photos
   */
  static exportPhotos(photos: Photo[]): string {
    const features = photos
      .filter(p => p.latitude !== null && p.longitude !== null)
      .map(p => this.photoToFeature(p));

    const featureCollection: GeoJSONFeatureCollection = {
      type: 'FeatureCollection',
      features,
    };

    return JSON.stringify(featureCollection, null, 2);
  }

  /**
   * Convert a waypoint to a GeoJSON Point feature.
   *
   * The feature includes all waypoint metadata in properties and
   * uses [longitude, latitude, altitude?] coordinate format per GeoJSON spec.
   *
   * @param waypoint - The waypoint to convert
   * @returns GeoJSON Feature with Point geometry
   */
  static waypointToFeature(waypoint: Waypoint): GeoJSONFeature {
    const coordinates: [number, number, number] | [number, number] =
      waypoint.altitude !== null
        ? [waypoint.longitude, waypoint.latitude, waypoint.altitude]
        : [waypoint.longitude, waypoint.latitude];

    return {
      type: 'Feature',
      id: waypoint.id,
      geometry: {
        type: 'Point',
        coordinates,
      },
      properties: {
        featureType: 'waypoint',
        name: waypoint.name,
        description: waypoint.description,
        accuracy: waypoint.accuracy,
        heading: waypoint.heading,
        speed: waypoint.speed,
        tags: waypoint.tags,
        customFields: waypoint.customFields,
        timestamp: waypoint.timestamp,
        createdAt: waypoint.createdAt,
        updatedAt: waypoint.updatedAt,
      },
    };
  }

  /**
   * Convert a photo to a GeoJSON Point feature.
   *
   * @param photo - The photo to convert (must have latitude and longitude)
   * @returns GeoJSON Feature with Point geometry
   * @throws Error if photo does not have location coordinates
   */
  static photoToFeature(photo: Photo): GeoJSONFeature {
    if (photo.latitude === null || photo.longitude === null) {
      throw new Error('Photo must have location to convert to GeoJSON feature');
    }

    const coordinates: [number, number, number] | [number, number] =
      photo.altitude !== null
        ? [photo.longitude, photo.latitude, photo.altitude]
        : [photo.longitude, photo.latitude];

    return {
      type: 'Feature',
      id: photo.id,
      geometry: {
        type: 'Point',
        coordinates,
      },
      properties: {
        featureType: 'photo',
        filename: photo.filename,
        uri: photo.uri,
        width: photo.width,
        height: photo.height,
        bearing: photo.bearing,
        caption: photo.caption,
        tags: photo.tags,
        exifData: photo.exifData,
        waypointId: photo.waypointId,
        capturedAt: photo.capturedAt,
        createdAt: photo.createdAt,
        updatedAt: photo.updatedAt,
      },
    };
  }

  /**
   * Convert a field note to a GeoJSON Point feature.
   *
   * @param note - The field note to convert (must have latitude and longitude)
   * @returns GeoJSON Feature with Point geometry
   * @throws Error if note does not have location coordinates
   */
  static noteToFeature(note: FieldNote): GeoJSONFeature {
    if (note.latitude === null || note.longitude === null) {
      throw new Error('Note must have location to convert to GeoJSON feature');
    }

    return {
      type: 'Feature',
      id: note.id,
      geometry: {
        type: 'Point',
        coordinates: [note.longitude, note.latitude],
      },
      properties: {
        featureType: 'field_note',
        title: note.title,
        content: note.content,
        hasAudio: note.audioUri !== null,
        audioDuration: note.audioDuration,
        transcriptionSource: note.transcriptionSource,
        transcriptionConfidence: note.transcriptionConfidence,
        tags: note.tags,
        waypointId: note.waypointId,
        photoId: note.photoId,
        timestamp: note.timestamp,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      },
    };
  }

  /**
   * Parse a GeoJSON string and validate its structure.
   *
   * Ensures the parsed object is a valid FeatureCollection with a features array.
   *
   * @param geojsonString - Raw GeoJSON string to parse
   * @returns Parsed and validated GeoJSONFeatureCollection
   * @throws Error if the GeoJSON is invalid or not a FeatureCollection
   *
   * @example
   * ```typescript
   * try {
   *   const collection = GeoJSONExporter.parse(rawString);
   *   console.log(`Loaded ${collection.features.length} features`);
   * } catch (error) {
   *   console.error('Invalid GeoJSON:', error.message);
   * }
   * ```
   */
  static parse(geojsonString: string): GeoJSONFeatureCollection {
    const parsed = JSON.parse(geojsonString);

    if (parsed.type !== 'FeatureCollection') {
      throw new Error('Invalid GeoJSON: must be a FeatureCollection');
    }

    if (!Array.isArray(parsed.features)) {
      throw new Error('Invalid GeoJSON: features must be an array');
    }

    return parsed as GeoJSONFeatureCollection;
  }
}
