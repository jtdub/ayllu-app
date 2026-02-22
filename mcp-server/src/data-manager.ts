import * as fs from 'fs';
import * as path from 'path';
import { glob } from 'glob';

export interface Project {
  id: string;
  name: string;
  description: string | null;
  startDate: string;
  endDate: string | null;
  boundingBox: BoundingBox | null;
  defaultTags: string[];
  customFields: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLon: number;
  maxLon: number;
}

export interface Waypoint {
  id: string;
  projectId: string;
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  altitude: number | null;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  tags: string[];
  customFields: Record<string, unknown>;
  timestamp: string;
  createdAt: string;
  updatedAt: string;
}

export interface Photo {
  id: string;
  projectId: string;
  waypointId: string | null;
  filename: string;
  uri: string;
  thumbnailUri: string | null;
  width: number;
  height: number;
  latitude: number | null;
  longitude: number | null;
  altitude: number | null;
  bearing: number | null;
  capturedAt: string;
  caption: string | null;
  tags: string[];
  exifData: Record<string, unknown> | null;
  createdAt: string;
  updatedAt: string;
}

export interface FieldNote {
  id: string;
  projectId: string;
  waypointId: string | null;
  photoId: string | null;
  title: string | null;
  content: string;
  audioUri: string | null;
  audioDuration: number | null;
  transcriptionSource: string | null;
  transcriptionConfidence: number | null;
  tags: string[];
  latitude: number | null;
  longitude: number | null;
  timestamp: string;
  createdAt: string;
  updatedAt: string;
}

export interface FieldData {
  project: Project;
  waypoints: Waypoint[];
  photos: Photo[];
  notes: FieldNote[];
}

/**
 * DataManager handles reading field data exported from the mobile app
 */
export class DataManager {
  private dataDir: string;
  private cache: Map<string, FieldData> = new Map();

  constructor(dataDir: string) {
    this.dataDir = path.resolve(dataDir);
  }

  /**
   * Scan data directory for exported field data files
   */
  async scanDataFiles(): Promise<string[]> {
    const patterns = [
      path.join(this.dataDir, '**/*.geojson'),
      path.join(this.dataDir, '**/*.json'),
    ];

    const files: string[] = [];
    for (const pattern of patterns) {
      const matches = await glob(pattern);
      files.push(...matches);
    }

    return files;
  }

  /**
   * Load and parse a field data file
   */
  async loadFieldData(filePath: string): Promise<FieldData | null> {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const data = JSON.parse(content);

      // Check if it's a GeoJSON export or raw JSON export
      if (data.type === 'FeatureCollection') {
        return this.parseGeoJSON(data);
      } else if (data.project && data.tables) {
        return this.parseGeoPackageJSON(data);
      }

      return null;
    } catch (error) {
      console.error(`Failed to load ${filePath}:`, error);
      return null;
    }
  }

  /**
   * Parse GeoJSON FeatureCollection into FieldData
   */
  private parseGeoJSON(geojson: any): FieldData {
    const project: Project = geojson.properties?.project || {
      id: 'unknown',
      name: 'Imported Data',
      description: null,
      startDate: new Date().toISOString(),
      endDate: null,
      boundingBox: null,
      defaultTags: [],
      customFields: {},
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const waypoints: Waypoint[] = [];
    const photos: Photo[] = [];
    const notes: FieldNote[] = [];

    for (const feature of geojson.features || []) {
      const props = feature.properties || {};
      const coords = feature.geometry?.coordinates || [];

      switch (props.featureType) {
        case 'waypoint':
          waypoints.push({
            id: feature.id || props.id,
            projectId: project.id,
            name: props.name || 'Waypoint',
            description: props.description,
            latitude: coords[1],
            longitude: coords[0],
            altitude: coords[2] || null,
            accuracy: props.accuracy,
            heading: props.heading,
            speed: props.speed,
            tags: props.tags || [],
            customFields: props.customFields || {},
            timestamp: props.timestamp || new Date().toISOString(),
            createdAt: props.createdAt || new Date().toISOString(),
            updatedAt: props.updatedAt || new Date().toISOString(),
          });
          break;

        case 'photo':
          photos.push({
            id: feature.id || props.id,
            projectId: project.id,
            waypointId: props.waypointId,
            filename: props.filename || 'photo.jpg',
            uri: props.uri || '',
            thumbnailUri: props.thumbnailUri,
            width: props.width || 0,
            height: props.height || 0,
            latitude: coords[1],
            longitude: coords[0],
            altitude: coords[2] || null,
            bearing: props.bearing,
            capturedAt: props.capturedAt || new Date().toISOString(),
            caption: props.caption,
            tags: props.tags || [],
            exifData: props.exifData,
            createdAt: props.createdAt || new Date().toISOString(),
            updatedAt: props.updatedAt || new Date().toISOString(),
          });
          break;

        case 'field_note':
          notes.push({
            id: feature.id || props.id,
            projectId: project.id,
            waypointId: props.waypointId,
            photoId: props.photoId,
            title: props.title,
            content: props.content || '',
            audioUri: props.audioUri,
            audioDuration: props.audioDuration,
            transcriptionSource: props.transcriptionSource,
            transcriptionConfidence: props.transcriptionConfidence,
            tags: props.tags || [],
            latitude: coords[1],
            longitude: coords[0],
            timestamp: props.timestamp || new Date().toISOString(),
            createdAt: props.createdAt || new Date().toISOString(),
            updatedAt: props.updatedAt || new Date().toISOString(),
          });
          break;
      }
    }

    return { project, waypoints, photos, notes };
  }

  /**
   * Parse GeoPackage JSON format
   */
  private parseGeoPackageJSON(data: any): FieldData {
    const project: Project = {
      id: data.project?.id || 'unknown',
      name: data.project?.name || 'Imported Data',
      description: data.project?.description,
      startDate: data.project?.start_date || new Date().toISOString(),
      endDate: data.project?.end_date,
      boundingBox: data.metadata?.boundingBox,
      defaultTags: data.project?.default_tags || [],
      customFields: data.project?.custom_fields || {},
      createdAt: data.project?.created_at || new Date().toISOString(),
      updatedAt: data.project?.updated_at || new Date().toISOString(),
    };

    const waypoints: Waypoint[] = (data.tables?.waypoints?.features || []).map(
      (f: any) => ({
        id: f.id,
        projectId: project.id,
        name: f.properties?.name || 'Waypoint',
        description: f.properties?.description,
        latitude: f.geometry?.coordinates?.[1] || 0,
        longitude: f.geometry?.coordinates?.[0] || 0,
        altitude: f.geometry?.coordinates?.[2],
        accuracy: f.properties?.accuracy,
        heading: f.properties?.heading,
        speed: f.properties?.speed,
        tags: JSON.parse(f.properties?.tags || '[]'),
        customFields: JSON.parse(f.properties?.custom_fields || '{}'),
        timestamp: f.properties?.timestamp || new Date().toISOString(),
        createdAt: f.properties?.created_at || new Date().toISOString(),
        updatedAt: f.properties?.updated_at || new Date().toISOString(),
      })
    );

    const photos: Photo[] = (data.tables?.photos?.features || []).map(
      (f: any) => ({
        id: f.id,
        projectId: project.id,
        waypointId: f.properties?.waypoint_id,
        filename: f.properties?.filename || 'photo.jpg',
        uri: f.properties?.uri || '',
        thumbnailUri: null,
        width: f.properties?.width || 0,
        height: f.properties?.height || 0,
        latitude: f.geometry?.coordinates?.[1],
        longitude: f.geometry?.coordinates?.[0],
        altitude: f.geometry?.coordinates?.[2],
        bearing: f.properties?.bearing,
        capturedAt: f.properties?.captured_at || new Date().toISOString(),
        caption: f.properties?.caption,
        tags: JSON.parse(f.properties?.tags || '[]'),
        exifData: f.properties?.exif_data ? JSON.parse(f.properties.exif_data) : null,
        createdAt: f.properties?.created_at || new Date().toISOString(),
        updatedAt: f.properties?.updated_at || new Date().toISOString(),
      })
    );

    const notes: FieldNote[] = (data.tables?.field_notes?.features || []).map(
      (f: any) => ({
        id: f.id,
        projectId: project.id,
        waypointId: f.properties?.waypoint_id,
        photoId: f.properties?.photo_id,
        title: f.properties?.title,
        content: f.properties?.content || '',
        audioUri: f.properties?.audio_uri,
        audioDuration: f.properties?.audio_duration,
        transcriptionSource: f.properties?.transcription_source,
        transcriptionConfidence: f.properties?.transcription_confidence,
        tags: JSON.parse(f.properties?.tags || '[]'),
        latitude: f.geometry?.coordinates?.[1],
        longitude: f.geometry?.coordinates?.[0],
        timestamp: f.properties?.timestamp || new Date().toISOString(),
        createdAt: f.properties?.created_at || new Date().toISOString(),
        updatedAt: f.properties?.updated_at || new Date().toISOString(),
      })
    );

    return { project, waypoints, photos, notes };
  }

  /**
   * Get all projects from cached data
   */
  async getProjects(): Promise<Project[]> {
    await this.refreshCache();
    return Array.from(this.cache.values()).map((fd) => fd.project);
  }

  /**
   * Get waypoints for a project
   */
  async getWaypoints(projectId: string): Promise<Waypoint[]> {
    await this.refreshCache();
    return this.cache.get(projectId)?.waypoints || [];
  }

  /**
   * Get photos for a project
   */
  async getPhotos(projectId: string): Promise<Photo[]> {
    await this.refreshCache();
    return this.cache.get(projectId)?.photos || [];
  }

  /**
   * Get notes for a project
   */
  async getNotes(projectId: string): Promise<FieldNote[]> {
    await this.refreshCache();
    return this.cache.get(projectId)?.notes || [];
  }

  /**
   * Get full field data for a project
   */
  async getFieldData(projectId: string): Promise<FieldData | null> {
    await this.refreshCache();
    return this.cache.get(projectId) || null;
  }

  /**
   * Refresh the data cache by scanning for new files
   */
  private async refreshCache(): Promise<void> {
    const files = await this.scanDataFiles();

    for (const file of files) {
      const data = await this.loadFieldData(file);
      if (data) {
        this.cache.set(data.project.id, data);
      }
    }
  }
}
