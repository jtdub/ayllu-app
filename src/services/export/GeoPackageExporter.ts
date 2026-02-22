import type {
  Project,
  Waypoint,
  Photo,
  FieldNote,
  BoundingBox,
} from '@/types';

/**
 * GeoPackage exporter
 *
 * Note: Full GeoPackage creation requires native SQLite with spatial extensions.
 * This class provides JSON output formatted for GeoPackage conversion on desktop.
 * The MCP server can convert this to a proper GeoPackage file.
 */
export class GeoPackageExporter {
  /**
   * Export project data as JSON formatted for GeoPackage conversion
   */
  static exportAsGeoJSON(
    project: Project,
    waypoints: Waypoint[],
    photos: Photo[],
    notes: FieldNote[]
  ): string {
    const geoPackageData = {
      metadata: {
        identifier: project.id,
        description: project.description || `Field data for ${project.name}`,
        createdAt: new Date().toISOString(),
        boundingBox: this.calculateBounds(waypoints, photos, notes),
        srsId: 4326, // WGS84
      },
      tables: {
        waypoints: {
          geometryColumn: 'geometry',
          geometryType: 'POINT',
          srsId: 4326,
          features: waypoints.map(wp => ({
            id: wp.id,
            geometry: {
              type: 'Point',
              coordinates: [wp.longitude, wp.latitude, wp.altitude].filter(v => v !== null),
            },
            properties: {
              name: wp.name,
              description: wp.description,
              accuracy: wp.accuracy,
              heading: wp.heading,
              speed: wp.speed,
              tags: JSON.stringify(wp.tags),
              custom_fields: JSON.stringify(wp.customFields),
              timestamp: wp.timestamp,
              created_at: wp.createdAt,
              updated_at: wp.updatedAt,
            },
          })),
        },
        photos: {
          geometryColumn: 'geometry',
          geometryType: 'POINT',
          srsId: 4326,
          features: photos
            .filter(p => p.latitude !== null && p.longitude !== null)
            .map(p => ({
              id: p.id,
              geometry: {
                type: 'Point',
                coordinates: [p.longitude, p.latitude, p.altitude].filter(v => v !== null),
              },
              properties: {
                waypoint_id: p.waypointId,
                filename: p.filename,
                uri: p.uri,
                width: p.width,
                height: p.height,
                bearing: p.bearing,
                caption: p.caption,
                tags: JSON.stringify(p.tags),
                exif_data: p.exifData ? JSON.stringify(p.exifData) : null,
                captured_at: p.capturedAt,
                created_at: p.createdAt,
                updated_at: p.updatedAt,
              },
            })),
        },
        field_notes: {
          geometryColumn: 'geometry',
          geometryType: 'POINT',
          srsId: 4326,
          features: notes
            .filter(n => n.latitude !== null && n.longitude !== null)
            .map(n => ({
              id: n.id,
              geometry: {
                type: 'Point',
                coordinates: [n.longitude, n.latitude],
              },
              properties: {
                waypoint_id: n.waypointId,
                photo_id: n.photoId,
                title: n.title,
                content: n.content,
                audio_uri: n.audioUri,
                audio_duration: n.audioDuration,
                transcription_source: n.transcriptionSource,
                transcription_confidence: n.transcriptionConfidence,
                tags: JSON.stringify(n.tags),
                timestamp: n.timestamp,
                created_at: n.createdAt,
                updated_at: n.updatedAt,
              },
            })),
        },
      },
      project: {
        id: project.id,
        name: project.name,
        description: project.description,
        start_date: project.startDate,
        end_date: project.endDate,
        default_tags: project.defaultTags,
        custom_fields: project.customFields,
        created_at: project.createdAt,
        updated_at: project.updatedAt,
      },
    };

    return JSON.stringify(geoPackageData, null, 2);
  }

  /**
   * Calculate bounding box from all features
   */
  static calculateBounds(
    waypoints: Waypoint[],
    photos: Photo[],
    notes: FieldNote[]
  ): BoundingBox | null {
    const allCoords: Array<{ lat: number; lon: number }> = [];

    for (const wp of waypoints) {
      allCoords.push({ lat: wp.latitude, lon: wp.longitude });
    }

    for (const photo of photos) {
      if (photo.latitude !== null && photo.longitude !== null) {
        allCoords.push({ lat: photo.latitude, lon: photo.longitude });
      }
    }

    for (const note of notes) {
      if (note.latitude !== null && note.longitude !== null) {
        allCoords.push({ lat: note.latitude, lon: note.longitude });
      }
    }

    if (allCoords.length === 0) return null;

    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLon = Infinity;
    let maxLon = -Infinity;

    for (const coord of allCoords) {
      minLat = Math.min(minLat, coord.lat);
      maxLat = Math.max(maxLat, coord.lat);
      minLon = Math.min(minLon, coord.lon);
      maxLon = Math.max(maxLon, coord.lon);
    }

    return { minLat, maxLat, minLon, maxLon };
  }

  /**
   * Generate GeoPackage SQL schema
   * This SQL can be executed against a SQLite database to create a GeoPackage
   */
  static generateSchema(): string {
    return `
-- GeoPackage required tables
CREATE TABLE IF NOT EXISTS gpkg_spatial_ref_sys (
  srs_name TEXT NOT NULL,
  srs_id INTEGER PRIMARY KEY,
  organization TEXT NOT NULL,
  organization_coordsys_id INTEGER NOT NULL,
  definition TEXT NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS gpkg_contents (
  table_name TEXT NOT NULL PRIMARY KEY,
  data_type TEXT NOT NULL,
  identifier TEXT UNIQUE,
  description TEXT DEFAULT '',
  last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  min_x DOUBLE,
  min_y DOUBLE,
  max_x DOUBLE,
  max_y DOUBLE,
  srs_id INTEGER,
  CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id)
);

CREATE TABLE IF NOT EXISTS gpkg_geometry_columns (
  table_name TEXT NOT NULL,
  column_name TEXT NOT NULL,
  geometry_type_name TEXT NOT NULL,
  srs_id INTEGER NOT NULL,
  z TINYINT NOT NULL,
  m TINYINT NOT NULL,
  CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name),
  CONSTRAINT fk_gc_tn FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name),
  CONSTRAINT fk_gc_srs FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys (srs_id)
);

-- Insert WGS84 spatial reference
INSERT OR IGNORE INTO gpkg_spatial_ref_sys (srs_name, srs_id, organization, organization_coordsys_id, definition)
VALUES ('WGS 84', 4326, 'EPSG', 4326, 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]');

-- Waypoints table
CREATE TABLE IF NOT EXISTS waypoints (
  id TEXT PRIMARY KEY,
  geometry BLOB,
  name TEXT NOT NULL,
  description TEXT,
  accuracy REAL,
  heading REAL,
  speed REAL,
  tags TEXT,
  custom_fields TEXT,
  timestamp TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Photos table
CREATE TABLE IF NOT EXISTS photos (
  id TEXT PRIMARY KEY,
  geometry BLOB,
  waypoint_id TEXT,
  filename TEXT NOT NULL,
  uri TEXT NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  bearing REAL,
  caption TEXT,
  tags TEXT,
  exif_data TEXT,
  captured_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Field notes table
CREATE TABLE IF NOT EXISTS field_notes (
  id TEXT PRIMARY KEY,
  geometry BLOB,
  waypoint_id TEXT,
  photo_id TEXT,
  title TEXT,
  content TEXT NOT NULL,
  audio_uri TEXT,
  audio_duration REAL,
  transcription_source TEXT,
  transcription_confidence REAL,
  tags TEXT,
  timestamp TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Register tables in gpkg_contents
INSERT OR REPLACE INTO gpkg_contents (table_name, data_type, identifier, srs_id)
VALUES ('waypoints', 'features', 'waypoints', 4326);

INSERT OR REPLACE INTO gpkg_contents (table_name, data_type, identifier, srs_id)
VALUES ('photos', 'features', 'photos', 4326);

INSERT OR REPLACE INTO gpkg_contents (table_name, data_type, identifier, srs_id)
VALUES ('field_notes', 'features', 'field_notes', 4326);

-- Register geometry columns
INSERT OR REPLACE INTO gpkg_geometry_columns (table_name, column_name, geometry_type_name, srs_id, z, m)
VALUES ('waypoints', 'geometry', 'POINT', 4326, 1, 0);

INSERT OR REPLACE INTO gpkg_geometry_columns (table_name, column_name, geometry_type_name, srs_id, z, m)
VALUES ('photos', 'geometry', 'POINT', 4326, 1, 0);

INSERT OR REPLACE INTO gpkg_geometry_columns (table_name, column_name, geometry_type_name, srs_id, z, m)
VALUES ('field_notes', 'geometry', 'POINT', 4326, 0, 0);
`;
  }
}
