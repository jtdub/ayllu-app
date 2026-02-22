/**
 * @fileoverview Repository for project data access operations
 *
 * Provides CRUD operations and queries for research projects stored in SQLite.
 * Projects are the top-level organizational unit for all field data.
 *
 * @module database/repositories/ProjectRepository
 */

import type { SQLiteDatabase } from 'expo-sqlite';
import type { Project, BoundingBox, CustomFieldDefinition } from '@/types';
import { generateId, getCurrentTimestamp, safeJsonParse } from '@/utils';

/**
 * Data access repository for Project entities.
 *
 * Handles all database operations for research projects including creation,
 * retrieval, updating, deletion, and statistics.
 *
 * @example
 * ```typescript
 * const repository = new ProjectRepository(database);
 *
 * // Create a new project
 * const project = await repository.create({
 *   name: 'Site Survey 2024',
 *   description: 'Archaeological survey',
 *   startDate: new Date().toISOString(),
 *   endDate: null,
 *   boundingBox: null,
 *   defaultTags: ['survey'],
 *   customFields: {},
 * });
 *
 * // Get all projects
 * const projects = await repository.getAll();
 *
 * // Get project statistics
 * const stats = await repository.getStats(project.id);
 * ```
 */
export class ProjectRepository {
  /**
   * Create a new ProjectRepository instance.
   *
   * @param db - SQLite database connection
   */
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new project in the database.
   *
   * Generates a unique ID and timestamps automatically.
   *
   * @param data - Project data (without id, createdAt, updatedAt)
   * @returns The created project with generated fields
   *
   * @example
   * ```typescript
   * const project = await repository.create({
   *   name: 'Site Survey 2024',
   *   description: 'Archaeological survey of northern sector',
   *   startDate: '2024-01-01T00:00:00Z',
   *   endDate: null,
   *   boundingBox: null,
   *   defaultTags: ['survey', 'archaeology'],
   *   customFields: {},
   * });
   * ```
   */
  async create(
    data: Omit<Project, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<Project> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO projects (
        id, name, description, start_date, end_date,
        bounding_box, default_tags, custom_fields, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.name,
        data.description,
        data.startDate,
        data.endDate,
        data.boundingBox ? JSON.stringify(data.boundingBox) : null,
        JSON.stringify(data.defaultTags),
        JSON.stringify(data.customFields),
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
   * Retrieve a project by its unique identifier.
   *
   * @param id - Project UUID
   * @returns The project if found, null otherwise
   *
   * @example
   * ```typescript
   * const project = await repository.getById('abc-123');
   * if (project) {
   *   console.log(`Found project: ${project.name}`);
   * }
   * ```
   */
  async getById(id: string): Promise<Project | null> {
    const row = await this.db.getFirstAsync<ProjectRow>(
      'SELECT * FROM projects WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToProject(row) : null;
  }

  /**
   * Get all projects ordered by start date (newest first).
   *
   * @returns Array of all projects
   *
   * @example
   * ```typescript
   * const projects = await repository.getAll();
   * console.log(`Found ${projects.length} projects`);
   * ```
   */
  async getAll(): Promise<Project[]> {
    const rows = await this.db.getAllAsync<ProjectRow>(
      'SELECT * FROM projects ORDER BY start_date DESC'
    );

    return rows.map(this.mapRowToProject);
  }

  /**
   * Update an existing project.
   *
   * Only the fields provided in the data object will be updated.
   * The updatedAt timestamp is automatically set.
   *
   * @param id - Project UUID to update
   * @param data - Partial project data to update
   * @returns The updated project, or null if not found
   *
   * @example
   * ```typescript
   * const updated = await repository.update('abc-123', {
   *   name: 'Updated Project Name',
   *   description: 'New description',
   * });
   * ```
   */
  async update(
    id: string,
    data: Partial<Omit<Project, 'id' | 'createdAt' | 'updatedAt'>>
  ): Promise<Project | null> {
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
    if (data.startDate !== undefined) {
      updates.push('start_date = ?');
      values.push(data.startDate);
    }
    if (data.endDate !== undefined) {
      updates.push('end_date = ?');
      values.push(data.endDate);
    }
    if (data.boundingBox !== undefined) {
      updates.push('bounding_box = ?');
      values.push(data.boundingBox ? JSON.stringify(data.boundingBox) : null);
    }
    if (data.defaultTags !== undefined) {
      updates.push('default_tags = ?');
      values.push(JSON.stringify(data.defaultTags));
    }
    if (data.customFields !== undefined) {
      updates.push('custom_fields = ?');
      values.push(JSON.stringify(data.customFields));
    }

    if (updates.length === 0) return existing;

    const now = getCurrentTimestamp();
    updates.push('updated_at = ?');
    values.push(now);
    values.push(id);

    await this.db.runAsync(
      `UPDATE projects SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    return this.getById(id);
  }

  /**
   * Delete a project and all related data (cascade delete).
   *
   * Due to foreign key constraints, this will also delete all associated
   * waypoints, photos, and field notes.
   *
   * @param id - Project UUID to delete
   * @returns `true` if deleted, `false` if not found
   *
   * @example
   * ```typescript
   * const deleted = await repository.delete('abc-123');
   * if (deleted) {
   *   console.log('Project and all related data deleted');
   * }
   * ```
   */
  async delete(id: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'DELETE FROM projects WHERE id = ?',
      [id]
    );

    return result.changes > 0;
  }

  /**
   * Search projects by name or description.
   *
   * Performs case-insensitive partial matching on both name and description.
   *
   * @param query - Search term
   * @returns Array of matching projects ordered by start date
   *
   * @example
   * ```typescript
   * const results = await repository.search('survey');
   * console.log(`Found ${results.length} matching projects`);
   * ```
   */
  async search(query: string): Promise<Project[]> {
    const searchTerm = `%${query}%`;
    const rows = await this.db.getAllAsync<ProjectRow>(
      `SELECT * FROM projects
       WHERE name LIKE ? OR description LIKE ?
       ORDER BY start_date DESC`,
      [searchTerm, searchTerm]
    );

    return rows.map(this.mapRowToProject);
  }

  /**
   * Get statistics for a project including counts and date ranges.
   *
   * @param projectId - Project UUID
   * @returns Statistics object with counts and date range
   *
   * @example
   * ```typescript
   * const stats = await repository.getStats('abc-123');
   * console.log(`Project has ${stats.waypointCount} waypoints`);
   * console.log(`Date range: ${stats.dateRange.start} to ${stats.dateRange.end}`);
   * ```
   */
  async getStats(projectId: string): Promise<ProjectStats> {
    const waypointCount = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM waypoints WHERE project_id = ?',
      [projectId]
    );

    const photoCount = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM photos WHERE project_id = ?',
      [projectId]
    );

    const noteCount = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM field_notes WHERE project_id = ?',
      [projectId]
    );

    const dateRange = await this.db.getFirstAsync<{
      min_date: string | null;
      max_date: string | null;
    }>(
      `SELECT MIN(timestamp) as min_date, MAX(timestamp) as max_date
       FROM waypoints WHERE project_id = ?`,
      [projectId]
    );

    return {
      waypointCount: waypointCount?.count ?? 0,
      photoCount: photoCount?.count ?? 0,
      noteCount: noteCount?.count ?? 0,
      dateRange: {
        start: dateRange?.min_date ?? null,
        end: dateRange?.max_date ?? null,
      },
    };
  }

  /**
   * Map a database row to a Project entity.
   *
   * @param row - Raw database row
   * @returns Mapped Project object
   * @internal
   */
  private mapRowToProject(row: ProjectRow): Project {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      startDate: row.start_date,
      endDate: row.end_date,
      boundingBox: safeJsonParse<BoundingBox | null>(row.bounding_box, null),
      defaultTags: safeJsonParse<string[]>(row.default_tags, []),
      customFields: safeJsonParse<Record<string, CustomFieldDefinition>>(
        row.custom_fields,
        {}
      ),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

/**
 * Raw database row structure for projects table.
 * @internal
 */
interface ProjectRow {
  id: string;
  name: string;
  description: string | null;
  start_date: string;
  end_date: string | null;
  bounding_box: string | null;
  default_tags: string;
  custom_fields: string;
  created_at: string;
  updated_at: string;
}

/**
 * Project statistics including data counts and date ranges.
 */
export interface ProjectStats {
  /** Total number of waypoints in the project */
  waypointCount: number;
  /** Total number of photos in the project */
  photoCount: number;
  /** Total number of field notes in the project */
  noteCount: number;
  /** Date range of waypoint timestamps */
  dateRange: {
    /** Earliest waypoint timestamp, or null if no waypoints */
    start: string | null;
    /** Latest waypoint timestamp, or null if no waypoints */
    end: string | null;
  };
}
