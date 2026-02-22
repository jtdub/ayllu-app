/**
 * @fileoverview Type definitions for the Ayllu Field Research Companion App
 *
 * This module exports all TypeScript interfaces and types used throughout the
 * application, including database entities, GeoJSON structures, filter types,
 * and component props.
 *
 * @module types
 */

// ============================================================================
// Database Entity Types
// ============================================================================

/**
 * Represents a field research project containing waypoints, photos, and notes.
 *
 * Projects serve as the top-level organizational unit for all field data.
 * Each project has a defined time range and may include a geographic bounding box.
 *
 * @example
 * ```typescript
 * const project: Project = {
 *   id: 'proj-123',
 *   name: 'Site Survey 2024',
 *   description: 'Archaeological survey of the northern sector',
 *   startDate: '2024-01-01T00:00:00Z',
 *   endDate: null,
 *   boundingBox: { minLat: 37.0, maxLat: 38.0, minLon: -123.0, maxLon: -122.0 },
 *   defaultTags: ['survey', 'archaeology'],
 *   customFields: {},
 *   createdAt: '2024-01-01T00:00:00Z',
 *   updatedAt: '2024-01-01T00:00:00Z',
 * };
 * ```
 */
export interface Project {
  /** Unique identifier (UUID) */
  id: string;
  /** Human-readable project name */
  name: string;
  /** Optional detailed description */
  description: string | null;
  /** ISO 8601 timestamp when the project began */
  startDate: string;
  /** ISO 8601 timestamp when the project ended, null if ongoing */
  endDate: string | null;
  /** Geographic bounds of the project area */
  boundingBox: BoundingBox | null;
  /** Tags automatically applied to new waypoints in this project */
  defaultTags: string[];
  /** Custom field definitions for structured data collection */
  customFields: Record<string, CustomFieldDefinition>;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
  /** ISO 8601 timestamp of last update */
  updatedAt: string;
}

/**
 * Defines a rectangular geographic region using latitude/longitude bounds.
 *
 * Used for defining project areas, filtering queries, and offline map regions.
 */
export interface BoundingBox {
  /** Southern boundary (minimum latitude in decimal degrees) */
  minLat: number;
  /** Northern boundary (maximum latitude in decimal degrees) */
  maxLat: number;
  /** Western boundary (minimum longitude in decimal degrees) */
  minLon: number;
  /** Eastern boundary (maximum longitude in decimal degrees) */
  maxLon: number;
}

/**
 * Defines a custom field for structured data collection on waypoints.
 *
 * Custom fields allow researchers to define project-specific attributes
 * that can be collected at each waypoint.
 */
export interface CustomFieldDefinition {
  /** Display name for the field */
  name: string;
  /** Data type determining the input control */
  type: 'text' | 'number' | 'date' | 'select';
  /** Available options when type is 'select' */
  options?: string[];
  /** Whether the field must be filled when logging a waypoint */
  required?: boolean;
}

/**
 * Represents a GPS waypoint logged during field work.
 *
 * Waypoints are the primary geographic entities, containing location data
 * along with metadata, tags, and custom field values.
 *
 * @example
 * ```typescript
 * const waypoint: Waypoint = {
 *   id: 'wp-001',
 *   projectId: 'proj-123',
 *   name: 'WP001',
 *   description: 'Feature found at base of cliff',
 *   latitude: 37.7749,
 *   longitude: -122.4194,
 *   altitude: 15.5,
 *   accuracy: 3.2,
 *   heading: 90,
 *   speed: 0,
 *   tags: ['feature', 'artifact'],
 *   customFields: { siteType: 'excavation' },
 *   timestamp: '2024-01-15T10:30:00Z',
 *   createdAt: '2024-01-15T10:30:00Z',
 *   updatedAt: '2024-01-15T10:30:00Z',
 * };
 * ```
 */
export interface Waypoint {
  /** Unique identifier (UUID) */
  id: string;
  /** Reference to parent project */
  projectId: string;
  /** Sequential or custom waypoint name (e.g., "WP001") */
  name: string;
  /** Optional description of the waypoint */
  description: string | null;
  /** Latitude in decimal degrees (WGS84) */
  latitude: number;
  /** Longitude in decimal degrees (WGS84) */
  longitude: number;
  /** Altitude in meters above sea level */
  altitude: number | null;
  /** Horizontal accuracy in meters */
  accuracy: number | null;
  /** Compass heading in degrees (0-360) */
  heading: number | null;
  /** Speed in meters per second */
  speed: number | null;
  /** Categorization tags */
  tags: string[];
  /** Values for project-defined custom fields */
  customFields: Record<string, string | number | null>;
  /** ISO 8601 timestamp when the waypoint was logged */
  timestamp: string;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
  /** ISO 8601 timestamp of last update */
  updatedAt: string;
}

/**
 * Represents a photo captured during field work.
 *
 * Photos can be standalone or linked to a waypoint. They include
 * GPS coordinates from EXIF data and support captions and tags.
 */
export interface Photo {
  /** Unique identifier (UUID) */
  id: string;
  /** Reference to parent project */
  projectId: string;
  /** Optional reference to associated waypoint */
  waypointId: string | null;
  /** Original filename of the photo */
  filename: string;
  /** Local filesystem URI to the full-size image */
  uri: string;
  /** Local filesystem URI to the thumbnail image */
  thumbnailUri: string | null;
  /** Image width in pixels */
  width: number;
  /** Image height in pixels */
  height: number;
  /** GPS latitude from EXIF or manual entry */
  latitude: number | null;
  /** GPS longitude from EXIF or manual entry */
  longitude: number | null;
  /** GPS altitude from EXIF or manual entry */
  altitude: number | null;
  /** Camera bearing/direction in degrees (0-360) */
  bearing: number | null;
  /** ISO 8601 timestamp when the photo was taken */
  capturedAt: string;
  /** User-provided description of the photo */
  caption: string | null;
  /** Categorization tags */
  tags: string[];
  /** Extracted EXIF metadata */
  exifData: ExifData | null;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
  /** ISO 8601 timestamp of last update */
  updatedAt: string;
}

/**
 * EXIF metadata extracted from a photo.
 *
 * Contains camera and capture settings that may be useful for documentation.
 */
export interface ExifData {
  /** Camera manufacturer */
  make?: string;
  /** Camera model */
  model?: string;
  /** Focal length in millimeters */
  focalLength?: number;
  /** Aperture f-number */
  aperture?: number;
  /** ISO sensitivity */
  iso?: number;
  /** Exposure time as a string fraction (e.g., "1/125") */
  exposureTime?: string;
  /** Whether flash was used */
  flash?: boolean;
  /** Image orientation (1-8 per EXIF spec) */
  orientation?: number;
}

/**
 * Represents a field note with optional voice transcription.
 *
 * Field notes can be standalone, linked to a waypoint, or linked to a photo.
 * They support both manual text entry and voice-to-text transcription.
 *
 * @example
 * ```typescript
 * const note: FieldNote = {
 *   id: 'note-001',
 *   projectId: 'proj-123',
 *   waypointId: 'wp-001',
 *   photoId: null,
 *   title: 'Ceramic Fragment',
 *   content: 'Found ceramic fragments with red slip, possibly late period.',
 *   audioUri: '/path/to/recording.m4a',
 *   audioDuration: 45000,
 *   transcriptionSource: 'whisper',
 *   transcriptionConfidence: 0.95,
 *   tags: ['ceramics', 'artifact'],
 *   latitude: 37.7749,
 *   longitude: -122.4194,
 *   timestamp: '2024-01-15T10:32:00Z',
 *   createdAt: '2024-01-15T10:32:00Z',
 *   updatedAt: '2024-01-15T10:32:00Z',
 * };
 * ```
 */
export interface FieldNote {
  /** Unique identifier (UUID) */
  id: string;
  /** Reference to parent project */
  projectId: string;
  /** Optional reference to associated waypoint */
  waypointId: string | null;
  /** Optional reference to associated photo */
  photoId: string | null;
  /** Optional title for the note */
  title: string | null;
  /** The note content (text or transcription) */
  content: string;
  /** Local filesystem URI to the audio recording */
  audioUri: string | null;
  /** Duration of audio recording in milliseconds */
  audioDuration: number | null;
  /** Source of the transcription */
  transcriptionSource: 'manual' | 'whisper' | 'native' | null;
  /** Confidence score of transcription (0-1) */
  transcriptionConfidence: number | null;
  /** Categorization tags */
  tags: string[];
  /** GPS latitude where note was created */
  latitude: number | null;
  /** GPS longitude where note was created */
  longitude: number | null;
  /** ISO 8601 timestamp when the note was created */
  timestamp: string;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
  /** ISO 8601 timestamp of last update */
  updatedAt: string;
}

/**
 * Represents an offline map region downloaded for field use.
 *
 * Map regions track the download status and storage usage of
 * cached map tiles for a specific geographic area.
 */
export interface MapRegion {
  /** Unique identifier (UUID) */
  id: string;
  /** User-defined name for the region */
  name: string;
  /** Geographic bounds of the downloaded area */
  bounds: BoundingBox;
  /** Minimum zoom level downloaded */
  minZoom: number;
  /** Maximum zoom level downloaded */
  maxZoom: number;
  /** Map layers included in this region */
  layers: MapLayer[];
  /** Total number of tiles to download */
  tileCount: number;
  /** Number of tiles successfully downloaded */
  downloadedTiles: number;
  /** Total size of downloaded tiles in bytes */
  sizeBytes: number;
  /** Current download status */
  status: 'pending' | 'downloading' | 'complete' | 'error' | 'paused';
  /** Error message if status is 'error' */
  errorMessage: string | null;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
  /** ISO 8601 timestamp of last update */
  updatedAt: string;
}

/**
 * Available map layer types.
 * - `topo`: Topographic map (OpenTopoMap)
 * - `satellite`: Satellite imagery (ESRI World Imagery)
 */
export type MapLayer = 'topo' | 'satellite';

/**
 * Represents a cached map tile in local storage.
 */
export interface TileCache {
  /** Unique identifier (UUID) */
  id: string;
  /** Reference to associated map region, null if orphaned */
  regionId: string | null;
  /** Map layer type */
  layer: MapLayer;
  /** Zoom level (0-22) */
  z: number;
  /** Tile X coordinate */
  x: number;
  /** Tile Y coordinate */
  y: number;
  /** Local filesystem URI to the tile image */
  uri: string;
  /** File size in bytes */
  sizeBytes: number;
  /** ISO 8601 timestamp of last access (for LRU eviction) */
  lastAccessedAt: string;
  /** ISO 8601 timestamp of record creation */
  createdAt: string;
}

/**
 * Records a data export operation for tracking and history.
 */
export interface ExportHistory {
  /** Unique identifier (UUID) */
  id: string;
  /** Reference to exported project */
  projectId: string;
  /** Export file format */
  format: ExportFormat;
  /** Generated filename */
  filename: string;
  /** Local filesystem path to the export file */
  filePath: string;
  /** File size in bytes */
  sizeBytes: number;
  /** Number of waypoints included in export */
  waypointCount: number;
  /** Number of photos included in export */
  photoCount: number;
  /** Number of notes included in export */
  noteCount: number;
  /** ISO 8601 timestamp when export was created */
  exportedAt: string;
}

/**
 * Supported export file formats.
 * - `geojson`: GeoJSON FeatureCollection (native support)
 * - `geopackage`: OGC GeoPackage (requires desktop conversion)
 * - `shapefile`: ESRI Shapefile (requires desktop conversion)
 * - `csv`: Comma-separated values (tabular data only)
 */
export type ExportFormat = 'geojson' | 'geopackage' | 'shapefile' | 'csv';

// ============================================================================
// GeoJSON Types
// ============================================================================

/**
 * GeoJSON FeatureCollection with optional project metadata.
 *
 * Used as the primary export format for project data.
 * Conforms to RFC 7946 GeoJSON specification.
 *
 * @see {@link https://tools.ietf.org/html/rfc7946}
 */
export interface GeoJSONFeatureCollection {
  /** Must be "FeatureCollection" */
  type: 'FeatureCollection';
  /** Array of Feature objects */
  features: GeoJSONFeature[];
  /** Optional metadata properties */
  properties?: {
    /** Project information */
    project?: Project;
    /** ISO 8601 timestamp of export */
    exportedAt?: string;
    /** Export format version */
    version?: string;
  };
}

/**
 * GeoJSON Feature representing a single geographic entity.
 */
export interface GeoJSONFeature {
  /** Must be "Feature" */
  type: 'Feature';
  /** Optional feature identifier */
  id?: string;
  /** Geographic geometry */
  geometry: GeoJSONGeometry;
  /** Feature attributes */
  properties: Record<string, unknown>;
}

/**
 * Union type for supported GeoJSON geometry types.
 */
export type GeoJSONGeometry = GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon;

/**
 * GeoJSON Point geometry.
 *
 * Coordinates are in [longitude, latitude] or [longitude, latitude, altitude] format.
 */
export interface GeoJSONPoint {
  /** Must be "Point" */
  type: 'Point';
  /** Position as [longitude, latitude] or [longitude, latitude, altitude] */
  coordinates: [number, number] | [number, number, number];
}

/**
 * GeoJSON LineString geometry.
 *
 * Represents a series of connected points.
 */
export interface GeoJSONLineString {
  /** Must be "LineString" */
  type: 'LineString';
  /** Array of positions */
  coordinates: Array<[number, number] | [number, number, number]>;
}

/**
 * GeoJSON Polygon geometry.
 *
 * Represents a closed shape. The first and last positions must be identical.
 * The first array is the exterior ring; subsequent arrays are holes.
 */
export interface GeoJSONPolygon {
  /** Must be "Polygon" */
  type: 'Polygon';
  /** Array of linear rings (first is exterior, rest are holes) */
  coordinates: Array<Array<[number, number] | [number, number, number]>>;
}

// ============================================================================
// Location Types
// ============================================================================

/**
 * Represents a location reading from the GPS sensor.
 */
export interface LocationCoordinates {
  /** Latitude in decimal degrees (WGS84) */
  latitude: number;
  /** Longitude in decimal degrees (WGS84) */
  longitude: number;
  /** Altitude in meters above sea level */
  altitude: number | null;
  /** Horizontal accuracy in meters */
  accuracy: number | null;
  /** Compass heading in degrees (0-360) */
  heading: number | null;
  /** Speed in meters per second */
  speed: number | null;
  /** Unix timestamp in milliseconds */
  timestamp: number;
}

// ============================================================================
// Map Configuration Types
// ============================================================================

/**
 * Configuration for a map tile style/source.
 */
export interface MapStyle {
  /** Unique style identifier */
  id: string;
  /** Display name */
  name: string;
  /** Tile URL template or style JSON URL */
  url: string;
  /** Layer type */
  type: MapLayer;
}

/**
 * Configuration for downloading an offline map region.
 */
export interface OfflineRegionConfig {
  /** User-defined name for the region */
  name: string;
  /** Geographic bounds to download */
  bounds: BoundingBox;
  /** Minimum zoom level to download */
  minZoom: number;
  /** Maximum zoom level to download */
  maxZoom: number;
  /** Map layers to include */
  layers: MapLayer[];
}

// ============================================================================
// Voice/Transcription Types
// ============================================================================

/**
 * Result of a voice transcription operation.
 */
export interface TranscriptionResult {
  /** Transcribed text */
  text: string;
  /** Overall confidence score (0-1) */
  confidence: number;
  /** Transcription engine used */
  source: 'whisper' | 'native';
  /** Duration of audio in milliseconds */
  duration: number;
  /** Optional word/phrase-level segments */
  segments?: TranscriptionSegment[];
}

/**
 * A segment of transcribed text with timing information.
 */
export interface TranscriptionSegment {
  /** Transcribed text for this segment */
  text: string;
  /** Start time in milliseconds */
  startTime: number;
  /** End time in milliseconds */
  endTime: number;
  /** Confidence score for this segment (0-1) */
  confidence: number;
}

// ============================================================================
// Query Filter Types
// ============================================================================

/**
 * Filter criteria for querying waypoints.
 */
export interface WaypointFilter {
  /** Filter by project ID */
  projectId?: string;
  /** Filter by tags (AND logic) */
  tags?: string[];
  /** Filter by minimum timestamp */
  startDate?: string;
  /** Filter by maximum timestamp */
  endDate?: string;
  /** Filter by geographic bounds */
  bounds?: BoundingBox;
  /** Full-text search in name and description */
  searchText?: string;
}

/**
 * Filter criteria for querying photos.
 */
export interface PhotoFilter {
  /** Filter by project ID */
  projectId?: string;
  /** Filter by associated waypoint ID */
  waypointId?: string;
  /** Filter by tags (AND logic) */
  tags?: string[];
  /** Filter by minimum capture date */
  startDate?: string;
  /** Filter by maximum capture date */
  endDate?: string;
  /** Filter by caption presence */
  hasCaption?: boolean;
}

/**
 * Filter criteria for querying field notes.
 */
export interface NoteFilter {
  /** Filter by project ID */
  projectId?: string;
  /** Filter by associated waypoint ID */
  waypointId?: string;
  /** Filter by associated photo ID */
  photoId?: string;
  /** Filter by tags (AND logic) */
  tags?: string[];
  /** Full-text search in title and content */
  searchText?: string;
  /** Filter by transcription source */
  transcriptionSource?: FieldNote['transcriptionSource'];
}

// ============================================================================
// App State Types
// ============================================================================

/**
 * Application settings and preferences.
 */
export interface AppSettings {
  /** Default project ID to use when creating new data */
  defaultProject: string | null;
  /** Preferred map layer */
  mapStyle: MapLayer;
  /** Maximum cache size for offline tiles in bytes */
  offlineCacheLimit: number;
  /** Automatically save notes while typing */
  autoSaveNotes: boolean;
  /** Automatically tag new items with current location */
  autoTagLocation: boolean;
  /** Preferred transcription engine */
  voiceTranscriptionEngine: 'whisper' | 'native' | 'auto';
  /** Coordinate display format */
  coordinateFormat: 'decimal' | 'dms' | 'utm';
  /** Distance measurement unit */
  distanceUnit: 'meters' | 'feet';
}

// ============================================================================
// Component Prop Types
// ============================================================================

/**
 * Data structure for map markers.
 */
export interface MarkerData {
  /** Unique marker identifier */
  id: string;
  /** Geographic position */
  coordinate: {
    latitude: number;
    longitude: number;
  };
  /** Optional marker label */
  title?: string;
  /** Type determines marker icon/color */
  type: 'waypoint' | 'photo' | 'note';
}
