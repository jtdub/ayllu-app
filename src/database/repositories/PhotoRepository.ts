import type { SQLiteDatabase } from 'expo-sqlite';
import type { Photo, PhotoFilter, ExifData } from '@/types';
import { generateId, getCurrentTimestamp, safeJsonParse } from '@/utils';

export class PhotoRepository {
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new photo record
   */
  async create(
    data: Omit<Photo, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<Photo> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO photos (
        id, project_id, waypoint_id, filename, uri, thumbnail_uri,
        width, height, latitude, longitude, altitude, bearing,
        captured_at, caption, tags, exif_data, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.projectId,
        data.waypointId,
        data.filename,
        data.uri,
        data.thumbnailUri,
        data.width,
        data.height,
        data.latitude,
        data.longitude,
        data.altitude,
        data.bearing,
        data.capturedAt,
        data.caption,
        JSON.stringify(data.tags),
        data.exifData ? JSON.stringify(data.exifData) : null,
        now,
        now,
      ]
    );

    return {
      id,
      ...data,
      createdAt: now,
      updatedAt: now,
    };
  }

  /**
   * Get photo by ID
   */
  async getById(id: string): Promise<Photo | null> {
    const row = await this.db.getFirstAsync<PhotoRow>(
      'SELECT * FROM photos WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToPhoto(row) : null;
  }

  /**
   * Get all photos for a project
   */
  async getByProject(projectId: string): Promise<Photo[]> {
    const rows = await this.db.getAllAsync<PhotoRow>(
      'SELECT * FROM photos WHERE project_id = ? ORDER BY captured_at DESC',
      [projectId]
    );

    return rows.map(this.mapRowToPhoto);
  }

  /**
   * Get photos for a waypoint
   */
  async getByWaypoint(waypointId: string): Promise<Photo[]> {
    const rows = await this.db.getAllAsync<PhotoRow>(
      'SELECT * FROM photos WHERE waypoint_id = ? ORDER BY captured_at DESC',
      [waypointId]
    );

    return rows.map(this.mapRowToPhoto);
  }

  /**
   * Query photos with filters
   */
  async query(filter: PhotoFilter): Promise<Photo[]> {
    const conditions: string[] = [];
    const values: unknown[] = [];

    if (filter.projectId) {
      conditions.push('project_id = ?');
      values.push(filter.projectId);
    }

    if (filter.waypointId) {
      conditions.push('waypoint_id = ?');
      values.push(filter.waypointId);
    }

    if (filter.startDate) {
      conditions.push('captured_at >= ?');
      values.push(filter.startDate);
    }

    if (filter.endDate) {
      conditions.push('captured_at <= ?');
      values.push(filter.endDate);
    }

    if (filter.tags && filter.tags.length > 0) {
      const tagConditions = filter.tags.map(() => 'tags LIKE ?');
      conditions.push(`(${tagConditions.join(' OR ')})`);
      values.push(...filter.tags.map(tag => `%"${tag}"%`));
    }

    if (filter.hasCaption === true) {
      conditions.push('caption IS NOT NULL AND caption != ""');
    } else if (filter.hasCaption === false) {
      conditions.push('(caption IS NULL OR caption = "")');
    }

    const whereClause = conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    const rows = await this.db.getAllAsync<PhotoRow>(
      `SELECT * FROM photos ${whereClause} ORDER BY captured_at DESC`,
      values
    );

    return rows.map(this.mapRowToPhoto);
  }

  /**
   * Update photo
   */
  async update(
    id: string,
    data: Partial<Omit<Photo, 'id' | 'projectId' | 'createdAt' | 'updatedAt'>>
  ): Promise<Photo | null> {
    const existing = await this.getById(id);
    if (!existing) return null;

    const updates: string[] = [];
    const values: unknown[] = [];

    if (data.waypointId !== undefined) {
      updates.push('waypoint_id = ?');
      values.push(data.waypointId);
    }
    if (data.filename !== undefined) {
      updates.push('filename = ?');
      values.push(data.filename);
    }
    if (data.uri !== undefined) {
      updates.push('uri = ?');
      values.push(data.uri);
    }
    if (data.thumbnailUri !== undefined) {
      updates.push('thumbnail_uri = ?');
      values.push(data.thumbnailUri);
    }
    if (data.caption !== undefined) {
      updates.push('caption = ?');
      values.push(data.caption);
    }
    if (data.tags !== undefined) {
      updates.push('tags = ?');
      values.push(JSON.stringify(data.tags));
    }
    if (data.latitude !== undefined) {
      updates.push('latitude = ?');
      values.push(data.latitude);
    }
    if (data.longitude !== undefined) {
      updates.push('longitude = ?');
      values.push(data.longitude);
    }
    if (data.altitude !== undefined) {
      updates.push('altitude = ?');
      values.push(data.altitude);
    }
    if (data.bearing !== undefined) {
      updates.push('bearing = ?');
      values.push(data.bearing);
    }
    if (data.exifData !== undefined) {
      updates.push('exif_data = ?');
      values.push(data.exifData ? JSON.stringify(data.exifData) : null);
    }

    if (updates.length === 0) return existing;

    const now = getCurrentTimestamp();
    updates.push('updated_at = ?');
    values.push(now);
    values.push(id);

    await this.db.runAsync(
      `UPDATE photos SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    return this.getById(id);
  }

  /**
   * Delete photo
   */
  async delete(id: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'DELETE FROM photos WHERE id = ?',
      [id]
    );

    return result.changes > 0;
  }

  /**
   * Delete all photos for a project
   */
  async deleteByProject(projectId: string): Promise<number> {
    const result = await this.db.runAsync(
      'DELETE FROM photos WHERE project_id = ?',
      [projectId]
    );

    return result.changes;
  }

  /**
   * Get photo count for a project
   */
  async getCount(projectId: string): Promise<number> {
    const result = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM photos WHERE project_id = ?',
      [projectId]
    );

    return result?.count ?? 0;
  }

  /**
   * Get unique tags used across all photos in a project
   */
  async getTags(projectId: string): Promise<string[]> {
    const rows = await this.db.getAllAsync<{ tags: string }>(
      'SELECT DISTINCT tags FROM photos WHERE project_id = ?',
      [projectId]
    );

    const tagSet = new Set<string>();
    for (const row of rows) {
      const tags = safeJsonParse<string[]>(row.tags, []);
      tags.forEach(tag => tagSet.add(tag));
    }

    return Array.from(tagSet).sort();
  }

  /**
   * Link photo to waypoint
   */
  async linkToWaypoint(photoId: string, waypointId: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'UPDATE photos SET waypoint_id = ?, updated_at = ? WHERE id = ?',
      [waypointId, getCurrentTimestamp(), photoId]
    );

    return result.changes > 0;
  }

  /**
   * Unlink photo from waypoint
   */
  async unlinkFromWaypoint(photoId: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'UPDATE photos SET waypoint_id = NULL, updated_at = ? WHERE id = ?',
      [getCurrentTimestamp(), photoId]
    );

    return result.changes > 0;
  }

  /**
   * Get photos without waypoints
   */
  async getUnlinkedPhotos(projectId: string): Promise<Photo[]> {
    const rows = await this.db.getAllAsync<PhotoRow>(
      `SELECT * FROM photos
       WHERE project_id = ? AND waypoint_id IS NULL
       ORDER BY captured_at DESC`,
      [projectId]
    );

    return rows.map(this.mapRowToPhoto);
  }

  private mapRowToPhoto(row: PhotoRow): Photo {
    return {
      id: row.id,
      projectId: row.project_id,
      waypointId: row.waypoint_id,
      filename: row.filename,
      uri: row.uri,
      thumbnailUri: row.thumbnail_uri,
      width: row.width,
      height: row.height,
      latitude: row.latitude,
      longitude: row.longitude,
      altitude: row.altitude,
      bearing: row.bearing,
      capturedAt: row.captured_at,
      caption: row.caption,
      tags: safeJsonParse<string[]>(row.tags, []),
      exifData: safeJsonParse<ExifData | null>(row.exif_data, null),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

interface PhotoRow {
  id: string;
  project_id: string;
  waypoint_id: string | null;
  filename: string;
  uri: string;
  thumbnail_uri: string | null;
  width: number;
  height: number;
  latitude: number | null;
  longitude: number | null;
  altitude: number | null;
  bearing: number | null;
  captured_at: string;
  caption: string | null;
  tags: string;
  exif_data: string | null;
  created_at: string;
  updated_at: string;
}
