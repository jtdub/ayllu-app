import type { SQLiteDatabase } from 'expo-sqlite';
import type { ExportHistory, ExportFormat } from '@/types';
import { generateId, getCurrentTimestamp } from '@/utils';

export class ExportHistoryRepository {
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new export history entry
   */
  async create(
    data: Omit<ExportHistory, 'id' | 'exportedAt'>
  ): Promise<ExportHistory> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO export_history (
        id, project_id, format, filename, file_path, size_bytes,
        waypoint_count, photo_count, note_count, exported_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.projectId,
        data.format,
        data.filename,
        data.filePath,
        data.sizeBytes,
        data.waypointCount,
        data.photoCount,
        data.noteCount,
        now,
      ]
    );

    return {
      id,
      ...data,
      exportedAt: now,
    };
  }

  /**
   * Get export history entry by ID
   */
  async getById(id: string): Promise<ExportHistory | null> {
    const row = await this.db.getFirstAsync<ExportHistoryRow>(
      'SELECT * FROM export_history WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToExportHistory(row) : null;
  }

  /**
   * Get all export history for a project
   */
  async getByProject(projectId: string): Promise<ExportHistory[]> {
    const rows = await this.db.getAllAsync<ExportHistoryRow>(
      'SELECT * FROM export_history WHERE project_id = ? ORDER BY exported_at DESC',
      [projectId]
    );

    return rows.map(this.mapRowToExportHistory);
  }

  /**
   * Get all export history
   */
  async getAll(): Promise<ExportHistory[]> {
    const rows = await this.db.getAllAsync<ExportHistoryRow>(
      'SELECT * FROM export_history ORDER BY exported_at DESC'
    );

    return rows.map(this.mapRowToExportHistory);
  }

  /**
   * Get recent exports (last N entries)
   */
  async getRecent(limit: number = 10): Promise<ExportHistory[]> {
    const rows = await this.db.getAllAsync<ExportHistoryRow>(
      'SELECT * FROM export_history ORDER BY exported_at DESC LIMIT ?',
      [limit]
    );

    return rows.map(this.mapRowToExportHistory);
  }

  /**
   * Get exports by format
   */
  async getByFormat(format: ExportFormat): Promise<ExportHistory[]> {
    const rows = await this.db.getAllAsync<ExportHistoryRow>(
      'SELECT * FROM export_history WHERE format = ? ORDER BY exported_at DESC',
      [format]
    );

    return rows.map(this.mapRowToExportHistory);
  }

  /**
   * Delete export history entry
   */
  async delete(id: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'DELETE FROM export_history WHERE id = ?',
      [id]
    );

    return result.changes > 0;
  }

  /**
   * Delete all export history for a project
   */
  async deleteByProject(projectId: string): Promise<number> {
    const result = await this.db.runAsync(
      'DELETE FROM export_history WHERE project_id = ?',
      [projectId]
    );

    return result.changes;
  }

  /**
   * Get total export count for a project
   */
  async getCount(projectId: string): Promise<number> {
    const result = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM export_history WHERE project_id = ?',
      [projectId]
    );

    return result?.count ?? 0;
  }

  /**
   * Get total exported data size
   */
  async getTotalSize(): Promise<number> {
    const result = await this.db.getFirstAsync<{ total: number }>(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM export_history'
    );

    return result?.total ?? 0;
  }

  /**
   * Clean up old export history entries (keep last N per project)
   */
  async cleanup(keepPerProject: number = 10): Promise<number> {
    // Get all project IDs
    const projects = await this.db.getAllAsync<{ project_id: string }>(
      'SELECT DISTINCT project_id FROM export_history'
    );

    let totalDeleted = 0;

    for (const { project_id } of projects) {
      // Get IDs to keep (most recent N)
      const toKeep = await this.db.getAllAsync<{ id: string }>(
        `SELECT id FROM export_history
         WHERE project_id = ?
         ORDER BY exported_at DESC
         LIMIT ?`,
        [project_id, keepPerProject]
      );

      const keepIds = toKeep.map(r => r.id);

      if (keepIds.length === 0) continue;

      // Delete older entries
      const placeholders = keepIds.map(() => '?').join(',');
      const result = await this.db.runAsync(
        `DELETE FROM export_history
         WHERE project_id = ? AND id NOT IN (${placeholders})`,
        [project_id, ...keepIds]
      );

      totalDeleted += result.changes;
    }

    return totalDeleted;
  }

  private mapRowToExportHistory(row: ExportHistoryRow): ExportHistory {
    return {
      id: row.id,
      projectId: row.project_id,
      format: row.format as ExportFormat,
      filename: row.filename,
      filePath: row.file_path,
      sizeBytes: row.size_bytes,
      waypointCount: row.waypoint_count,
      photoCount: row.photo_count,
      noteCount: row.note_count,
      exportedAt: row.exported_at,
    };
  }
}

interface ExportHistoryRow {
  id: string;
  project_id: string;
  format: string;
  filename: string;
  file_path: string;
  size_bytes: number;
  waypoint_count: number;
  photo_count: number;
  note_count: number;
  exported_at: string;
}
