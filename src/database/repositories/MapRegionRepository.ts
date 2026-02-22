import type { MapRegion, BoundingBox, MapLayer } from '@/types';
import { generateId, getCurrentTimestamp, safeJsonParse } from '@/utils';
import type { SQLiteDatabase } from 'expo-sqlite';

export class MapRegionRepository {
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new map region for offline download
   */
  async create(
    data: Omit<
      MapRegion,
      'id' | 'downloadedTiles' | 'sizeBytes' | 'status' | 'errorMessage' | 'createdAt' | 'updatedAt'
    >
  ): Promise<MapRegion> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO map_regions (
        id, name, bounds, min_zoom, max_zoom, layers, tile_count,
        downloaded_tiles, size_bytes, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 'pending', ?, ?)`,
      [
        id,
        data.name,
        JSON.stringify(data.bounds),
        data.minZoom,
        data.maxZoom,
        JSON.stringify(data.layers),
        data.tileCount,
        now,
        now,
      ]
    );

    return {
      id,
      ...data,
      downloadedTiles: 0,
      sizeBytes: 0,
      status: 'pending',
      errorMessage: null,
      createdAt: now,
      updatedAt: now,
    };
  }

  /**
   * Get map region by ID
   */
  async getById(id: string): Promise<MapRegion | null> {
    const row = await this.db.getFirstAsync<MapRegionRow>(
      'SELECT * FROM map_regions WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToMapRegion(row) : null;
  }

  /**
   * Get all map regions
   */
  async getAll(): Promise<MapRegion[]> {
    const rows = await this.db.getAllAsync<MapRegionRow>(
      'SELECT * FROM map_regions ORDER BY created_at DESC'
    );

    return rows.map(this.mapRowToMapRegion);
  }

  /**
   * Get map regions by status
   */
  async getByStatus(status: MapRegion['status']): Promise<MapRegion[]> {
    const rows = await this.db.getAllAsync<MapRegionRow>(
      'SELECT * FROM map_regions WHERE status = ? ORDER BY created_at DESC',
      [status]
    );

    return rows.map(this.mapRowToMapRegion);
  }

  /**
   * Update download progress
   */
  async updateProgress(id: string, downloadedTiles: number, sizeBytes: number): Promise<void> {
    await this.db.runAsync(
      `UPDATE map_regions
       SET downloaded_tiles = ?, size_bytes = ?, updated_at = ?
       WHERE id = ?`,
      [downloadedTiles, sizeBytes, getCurrentTimestamp(), id]
    );
  }

  /**
   * Update region status
   */
  async updateStatus(
    id: string,
    status: MapRegion['status'],
    errorMessage?: string
  ): Promise<void> {
    await this.db.runAsync(
      `UPDATE map_regions
       SET status = ?, error_message = ?, updated_at = ?
       WHERE id = ?`,
      [status, errorMessage ?? null, getCurrentTimestamp(), id]
    );
  }

  /**
   * Mark region as complete
   */
  async markComplete(id: string): Promise<void> {
    const region = await this.getById(id);
    if (!region) return;

    await this.db.runAsync(
      `UPDATE map_regions
       SET status = 'complete', downloaded_tiles = tile_count, updated_at = ?
       WHERE id = ?`,
      [getCurrentTimestamp(), id]
    );
  }

  /**
   * Delete map region and its cached tiles
   */
  async delete(id: string): Promise<boolean> {
    // First delete associated tile cache entries
    await this.db.runAsync('DELETE FROM tile_cache WHERE region_id = ?', [id]);

    const result = await this.db.runAsync('DELETE FROM map_regions WHERE id = ?', [id]);

    return result.changes > 0;
  }

  /**
   * Get total size of all downloaded regions
   */
  async getTotalSize(): Promise<number> {
    const result = await this.db.getFirstAsync<{ total: number }>(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM map_regions'
    );

    return result?.total ?? 0;
  }

  /**
   * Check if a region overlaps with bounds
   */
  async findOverlapping(bounds: BoundingBox): Promise<MapRegion[]> {
    const rows = await this.db.getAllAsync<MapRegionRow>(
      'SELECT * FROM map_regions WHERE status = ?',
      ['complete']
    );

    return rows
      .map(this.mapRowToMapRegion)
      .filter((region) => this.boundsOverlap(region.bounds, bounds));
  }

  /**
   * Check if two bounding boxes overlap
   */
  private boundsOverlap(a: BoundingBox, b: BoundingBox): boolean {
    return !(
      a.maxLon < b.minLon ||
      a.minLon > b.maxLon ||
      a.maxLat < b.minLat ||
      a.minLat > b.maxLat
    );
  }

  /**
   * Rename a region
   */
  async rename(id: string, name: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'UPDATE map_regions SET name = ?, updated_at = ? WHERE id = ?',
      [name, getCurrentTimestamp(), id]
    );

    return result.changes > 0;
  }

  private mapRowToMapRegion(row: MapRegionRow): MapRegion {
    return {
      id: row.id,
      name: row.name,
      bounds: safeJsonParse<BoundingBox>(row.bounds, {
        minLat: 0,
        maxLat: 0,
        minLon: 0,
        maxLon: 0,
      }),
      minZoom: row.min_zoom,
      maxZoom: row.max_zoom,
      layers: safeJsonParse<MapLayer[]>(row.layers, ['topo']),
      tileCount: row.tile_count,
      downloadedTiles: row.downloaded_tiles,
      sizeBytes: row.size_bytes,
      status: row.status as MapRegion['status'],
      errorMessage: row.error_message,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

interface MapRegionRow {
  id: string;
  name: string;
  bounds: string;
  min_zoom: number;
  max_zoom: number;
  layers: string;
  tile_count: number;
  downloaded_tiles: number;
  size_bytes: number;
  status: string;
  error_message: string | null;
  created_at: string;
  updated_at: string;
}
