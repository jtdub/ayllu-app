/**
 * @fileoverview Repository for waypoint data access operations
 *
 * Provides CRUD operations and spatial queries for GPS waypoints stored in SQLite.
 * Waypoints are the primary geographic entities containing location data.
 *
 * @module database/repositories/WaypointRepository
 */

import type { SQLiteDatabase } from 'expo-sqlite';
import type { Waypoint, WaypointFilter, BoundingBox } from '@/types';
import { generateId, getCurrentTimestamp, safeJsonParse } from '@/utils';

/**
 * Data access repository for Waypoint entities.
 *
 * Handles all database operations for GPS waypoints including creation,
 * retrieval, filtering, spatial queries, and tag management.
 *
 * @example
 * ```typescript
 * const repository = new WaypointRepository(database);
 *
 * // Create a new waypoint
 * const waypoint = await repository.create({
 *   projectId: 'proj-123',
 *   name: 'WP001',
 *   latitude: 37.7749,
 *   longitude: -122.4194,
 *   // ... other fields
 * });
 *
 * // Query with filters
 * const results = await repository.query({
 *   projectId: 'proj-123',
 *   tags: ['survey'],
 *   startDate: '2024-01-01',
 * });
 *
 * // Find nearby waypoints
 * const nearby = await repository.findNearby(37.7749, -122.4194, 100);
 * ```
 */
export class WaypointRepository {
  /**
   * Create a new WaypointRepository instance.
   *
   * @param db - SQLite database connection
   */
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new waypoint in the database.
   *
   * Generates a unique ID and timestamps automatically.
   *
   * @param data - Waypoint data (without id, createdAt, updatedAt)
   * @returns The created waypoint with generated fields
   *
   * @example
   * ```typescript
   * const waypoint = await repository.create({
   *   projectId: 'proj-123',
   *   name: 'WP001',
   *   description: 'Feature at cliff base',
   *   latitude: 37.7749,
   *   longitude: -122.4194,
   *   altitude: 15.5,
   *   accuracy: 3.2,
   *   heading: 90,
   *   speed: 0,
   *   tags: ['feature', 'artifact'],
   *   customFields: {},
   *   timestamp: new Date().toISOString(),
   * });
   * ```
   */
  async create(
    data: Omit<Waypoint, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<Waypoint> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO waypoints (
        id, project_id, name, description, latitude, longitude,
        altitude, accuracy, heading, speed, tags, custom_fields,
        timestamp, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.projectId,
        data.name,
        data.description,
        data.latitude,
        data.longitude,
        data.altitude,
        data.accuracy,
        data.heading,
        data.speed,
        JSON.stringify(data.tags),
        JSON.stringify(data.customFields),
        data.timestamp,
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
   * Retrieve a waypoint by its unique identifier.
   *
   * @param id - Waypoint UUID
   * @returns The waypoint if found, null otherwise
   */
  async getById(id: string): Promise<Waypoint | null> {
    const row = await this.db.getFirstAsync<WaypointRow>(
      'SELECT * FROM waypoints WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToWaypoint(row) : null;
  }

  /**
   * Get all waypoints for a project ordered by timestamp (newest first).
   *
   * @param projectId - Project UUID
   * @returns Array of waypoints belonging to the project
   *
   * @example
   * ```typescript
   * const waypoints = await repository.getByProject('proj-123');
   * console.log(`Project has ${waypoints.length} waypoints`);
   * ```
   */
  async getByProject(projectId: string): Promise<Waypoint[]> {
    const rows = await this.db.getAllAsync<WaypointRow>(
      'SELECT * FROM waypoints WHERE project_id = ? ORDER BY timestamp DESC',
      [projectId]
    );

    return rows.map(this.mapRowToWaypoint);
  }

  /**
   * Query waypoints with multiple filter criteria.
   *
   * Supports filtering by project, tags, date range, bounding box, and text search.
   * Multiple filters are combined with AND logic. Tags use OR logic (any match).
   *
   * @param filter - Filter criteria object
   * @returns Array of matching waypoints ordered by timestamp
   *
   * @example
   * ```typescript
   * // Find waypoints with specific tags in a date range
   * const results = await repository.query({
   *   projectId: 'proj-123',
   *   tags: ['survey', 'excavation'],
   *   startDate: '2024-01-01T00:00:00Z',
   *   endDate: '2024-01-31T23:59:59Z',
   * });
   *
   * // Find waypoints within a bounding box
   * const results = await repository.query({
   *   bounds: {
   *     minLat: 37.0,
   *     maxLat: 38.0,
   *     minLon: -123.0,
   *     maxLon: -122.0,
   *   },
   * });
   * ```
   */
  async query(filter: WaypointFilter): Promise<Waypoint[]> {
    const conditions: string[] = [];
    const values: unknown[] = [];

    if (filter.projectId) {
      conditions.push('project_id = ?');
      values.push(filter.projectId);
    }

    if (filter.startDate) {
      conditions.push('timestamp >= ?');
      values.push(filter.startDate);
    }

    if (filter.endDate) {
      conditions.push('timestamp <= ?');
      values.push(filter.endDate);
    }

    if (filter.bounds) {
      conditions.push('latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?');
      values.push(
        filter.bounds.minLat,
        filter.bounds.maxLat,
        filter.bounds.minLon,
        filter.bounds.maxLon
      );
    }

    if (filter.tags && filter.tags.length > 0) {
      // Check if any of the filter tags exist in the waypoint's tags JSON array
      const tagConditions = filter.tags.map(() => 'tags LIKE ?');
      conditions.push(`(${tagConditions.join(' OR ')})`);
      values.push(...filter.tags.map(tag => `%"${tag}"%`));
    }

    if (filter.searchText) {
      conditions.push('(name LIKE ? OR description LIKE ?)');
      const searchTerm = `%${filter.searchText}%`;
      values.push(searchTerm, searchTerm);
    }

    const whereClause = conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    const rows = await this.db.getAllAsync<WaypointRow>(
      `SELECT * FROM waypoints ${whereClause} ORDER BY timestamp DESC`,
      values
    );

    return rows.map(this.mapRowToWaypoint);
  }

  /**
   * Update an existing waypoint.
   *
   * Only the fields provided in the data object will be updated.
   * The updatedAt timestamp is automatically set.
   *
   * @param id - Waypoint UUID to update
   * @param data - Partial waypoint data to update (projectId cannot be changed)
   * @returns The updated waypoint, or null if not found
   */
  async update(
    id: string,
    data: Partial<Omit<Waypoint, 'id' | 'projectId' | 'createdAt' | 'updatedAt'>>
  ): Promise<Waypoint | null> {
    const existing = await this.getById(id);
    if (!existing) return null;

    const updates: string[] = [];
    const values: unknown[] = [];

    if (data.name !== undefined) {
      updates.push('name = ?');
      values.push(data.name);
    }
    if (data.description !== undefined) {
      updates.push('description = ?');
      values.push(data.description);
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
    if (data.accuracy !== undefined) {
      updates.push('accuracy = ?');
      values.push(data.accuracy);
    }
    if (data.heading !== undefined) {
      updates.push('heading = ?');
      values.push(data.heading);
    }
    if (data.speed !== undefined) {
      updates.push('speed = ?');
      values.push(data.speed);
    }
    if (data.tags !== undefined) {
      updates.push('tags = ?');
      values.push(JSON.stringify(data.tags));
    }
    if (data.customFields !== undefined) {
      updates.push('custom_fields = ?');
      values.push(JSON.stringify(data.customFields));
    }
    if (data.timestamp !== undefined) {
      updates.push('timestamp = ?');
      values.push(data.timestamp);
    }

    if (updates.length === 0) return existing;

    const now = getCurrentTimestamp();
    updates.push('updated_at = ?');
    values.push(now);
    values.push(id);

    await this.db.runAsync(
      `UPDATE waypoints SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    return this.getById(id);
  }

  /**
   * Delete a waypoint by ID.
   *
   * @param id - Waypoint UUID to delete
   * @returns `true` if deleted, `false` if not found
   */
  async delete(id: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'DELETE FROM waypoints WHERE id = ?',
      [id]
    );

    return result.changes > 0;
  }

  /**
   * Delete all waypoints belonging to a project.
   *
   * @param projectId - Project UUID
   * @returns Number of waypoints deleted
   */
  async deleteByProject(projectId: string): Promise<number> {
    const result = await this.db.runAsync(
      'DELETE FROM waypoints WHERE project_id = ?',
      [projectId]
    );

    return result.changes;
  }

  /**
   * Calculate the bounding box containing all waypoints in a project.
   *
   * @param projectId - Project UUID
   * @returns Bounding box, or null if project has no waypoints
   *
   * @example
   * ```typescript
   * const bounds = await repository.getBoundingBox('proj-123');
   * if (bounds) {
   *   console.log(`Project spans ${bounds.minLat} to ${bounds.maxLat} latitude`);
   * }
   * ```
   */
  async getBoundingBox(projectId: string): Promise<BoundingBox | null> {
    const result = await this.db.getFirstAsync<{
      min_lat: number | null;
      max_lat: number | null;
      min_lon: number | null;
      max_lon: number | null;
    }>(
      `SELECT
        MIN(latitude) as min_lat,
        MAX(latitude) as max_lat,
        MIN(longitude) as min_lon,
        MAX(longitude) as max_lon
       FROM waypoints WHERE project_id = ?`,
      [projectId]
    );

    if (!result || result.min_lat === null) return null;

    return {
      minLat: result.min_lat,
      maxLat: result.max_lat!,
      minLon: result.min_lon!,
      maxLon: result.max_lon!,
    };
  }

  /**
   * Get all unique tags used across waypoints in a project.
   *
   * @param projectId - Project UUID
   * @returns Sorted array of unique tag strings
   *
   * @example
   * ```typescript
   * const tags = await repository.getTags('proj-123');
   * console.log(`Available tags: ${tags.join(', ')}`);
   * ```
   */
  async getTags(projectId: string): Promise<string[]> {
    const rows = await this.db.getAllAsync<{ tags: string }>(
      'SELECT DISTINCT tags FROM waypoints WHERE project_id = ?',
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
   * Get the total waypoint count for a project.
   *
   * @param projectId - Project UUID
   * @returns Number of waypoints
   */
  async getCount(projectId: string): Promise<number> {
    const result = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM waypoints WHERE project_id = ?',
      [projectId]
    );

    return result?.count ?? 0;
  }

  /**
   * Find waypoints within a specified radius of a point.
   *
   * Uses a bounding box for initial filtering, then applies the Haversine
   * formula for accurate distance calculation.
   *
   * @param latitude - Center point latitude in decimal degrees
   * @param longitude - Center point longitude in decimal degrees
   * @param radiusMeters - Search radius in meters
   * @param projectId - Optional project ID to limit search
   * @returns Array of waypoints within the radius, sorted by distance
   *
   * @example
   * ```typescript
   * // Find all waypoints within 100 meters
   * const nearby = await repository.findNearby(37.7749, -122.4194, 100);
   *
   * // Find waypoints within 50 meters in a specific project
   * const nearby = await repository.findNearby(37.7749, -122.4194, 50, 'proj-123');
   * ```
   */
  async findNearby(
    latitude: number,
    longitude: number,
    radiusMeters: number,
    projectId?: string
  ): Promise<Waypoint[]> {
    // Approximate degrees for bounding box query
    const latDelta = radiusMeters / 111000; // ~111km per degree latitude
    const lonDelta = radiusMeters / (111000 * Math.cos(latitude * Math.PI / 180));

    const conditions = [
      'latitude BETWEEN ? AND ?',
      'longitude BETWEEN ? AND ?',
    ];
    const values: unknown[] = [
      latitude - latDelta,
      latitude + latDelta,
      longitude - lonDelta,
      longitude + lonDelta,
    ];

    if (projectId) {
      conditions.push('project_id = ?');
      values.push(projectId);
    }

    const rows = await this.db.getAllAsync<WaypointRow>(
      `SELECT * FROM waypoints WHERE ${conditions.join(' AND ')}`,
      values
    );

    // Filter by actual distance (Haversine)
    return rows
      .map(this.mapRowToWaypoint)
      .filter(wp => {
        const distance = this.haversineDistance(
          latitude, longitude,
          wp.latitude, wp.longitude
        );
        return distance <= radiusMeters;
      });
  }

  /**
   * Calculate distance between two points using the Haversine formula.
   *
   * @param lat1 - First point latitude
   * @param lon1 - First point longitude
   * @param lat2 - Second point latitude
   * @param lon2 - Second point longitude
   * @returns Distance in meters
   * @internal
   */
  private haversineDistance(
    lat1: number, lon1: number,
    lat2: number, lon2: number
  ): number {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Map a database row to a Waypoint entity.
   *
   * @param row - Raw database row
   * @returns Mapped Waypoint object
   * @internal
   */
  private mapRowToWaypoint(row: WaypointRow): Waypoint {
    return {
      id: row.id,
      projectId: row.project_id,
      name: row.name,
      description: row.description,
      latitude: row.latitude,
      longitude: row.longitude,
      altitude: row.altitude,
      accuracy: row.accuracy,
      heading: row.heading,
      speed: row.speed,
      tags: safeJsonParse<string[]>(row.tags, []),
      customFields: safeJsonParse<Record<string, string | number | null>>(
        row.custom_fields,
        {}
      ),
      timestamp: row.timestamp,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

/**
 * Raw database row structure for waypoints table.
 * @internal
 */
interface WaypointRow {
  id: string;
  project_id: string;
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  altitude: number | null;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  tags: string;
  custom_fields: string;
  timestamp: string;
  created_at: string;
  updated_at: string;
}
