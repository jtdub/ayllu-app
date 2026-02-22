import type { SQLiteDatabase } from 'expo-sqlite';
import type { FieldNote, NoteFilter } from '@/types';
import { generateId, getCurrentTimestamp, safeJsonParse } from '@/utils';

export class FieldNoteRepository {
  constructor(private db: SQLiteDatabase) {}

  /**
   * Create a new field note
   */
  async create(
    data: Omit<FieldNote, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<FieldNote> {
    const id = generateId();
    const now = getCurrentTimestamp();

    await this.db.runAsync(
      `INSERT INTO field_notes (
        id, project_id, waypoint_id, photo_id, title, content,
        audio_uri, audio_duration, transcription_source, transcription_confidence,
        tags, latitude, longitude, timestamp, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.projectId,
        data.waypointId,
        data.photoId,
        data.title,
        data.content,
        data.audioUri,
        data.audioDuration,
        data.transcriptionSource,
        data.transcriptionConfidence,
        JSON.stringify(data.tags),
        data.latitude,
        data.longitude,
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
   * Get field note by ID
   */
  async getById(id: string): Promise<FieldNote | null> {
    const row = await this.db.getFirstAsync<FieldNoteRow>(
      'SELECT * FROM field_notes WHERE id = ?',
      [id]
    );

    return row ? this.mapRowToFieldNote(row) : null;
  }

  /**
   * Get all field notes for a project
   */
  async getByProject(projectId: string): Promise<FieldNote[]> {
    const rows = await this.db.getAllAsync<FieldNoteRow>(
      'SELECT * FROM field_notes WHERE project_id = ? ORDER BY timestamp DESC',
      [projectId]
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Get field notes for a waypoint
   */
  async getByWaypoint(waypointId: string): Promise<FieldNote[]> {
    const rows = await this.db.getAllAsync<FieldNoteRow>(
      'SELECT * FROM field_notes WHERE waypoint_id = ? ORDER BY timestamp DESC',
      [waypointId]
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Get field notes for a photo
   */
  async getByPhoto(photoId: string): Promise<FieldNote[]> {
    const rows = await this.db.getAllAsync<FieldNoteRow>(
      'SELECT * FROM field_notes WHERE photo_id = ? ORDER BY timestamp DESC',
      [photoId]
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Query field notes with filters
   */
  async query(filter: NoteFilter): Promise<FieldNote[]> {
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

    if (filter.photoId) {
      conditions.push('photo_id = ?');
      values.push(filter.photoId);
    }

    if (filter.tags && filter.tags.length > 0) {
      const tagConditions = filter.tags.map(() => 'tags LIKE ?');
      conditions.push(`(${tagConditions.join(' OR ')})`);
      values.push(...filter.tags.map(tag => `%"${tag}"%`));
    }

    if (filter.transcriptionSource) {
      conditions.push('transcription_source = ?');
      values.push(filter.transcriptionSource);
    }

    const whereClause = conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    const rows = await this.db.getAllAsync<FieldNoteRow>(
      `SELECT * FROM field_notes ${whereClause} ORDER BY timestamp DESC`,
      values
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Full-text search in field notes
   */
  async search(projectId: string, searchText: string): Promise<FieldNote[]> {
    // Use FTS5 for full-text search
    const rows = await this.db.getAllAsync<FieldNoteRow>(
      `SELECT f.* FROM field_notes f
       INNER JOIN field_notes_fts fts ON f.rowid = fts.rowid
       WHERE f.project_id = ? AND field_notes_fts MATCH ?
       ORDER BY rank`,
      [projectId, searchText]
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Update field note
   */
  async update(
    id: string,
    data: Partial<Omit<FieldNote, 'id' | 'projectId' | 'createdAt' | 'updatedAt'>>
  ): Promise<FieldNote | null> {
    const existing = await this.getById(id);
    if (!existing) return null;

    const updates: string[] = [];
    const values: unknown[] = [];

    if (data.waypointId !== undefined) {
      updates.push('waypoint_id = ?');
      values.push(data.waypointId);
    }
    if (data.photoId !== undefined) {
      updates.push('photo_id = ?');
      values.push(data.photoId);
    }
    if (data.title !== undefined) {
      updates.push('title = ?');
      values.push(data.title);
    }
    if (data.content !== undefined) {
      updates.push('content = ?');
      values.push(data.content);
    }
    if (data.audioUri !== undefined) {
      updates.push('audio_uri = ?');
      values.push(data.audioUri);
    }
    if (data.audioDuration !== undefined) {
      updates.push('audio_duration = ?');
      values.push(data.audioDuration);
    }
    if (data.transcriptionSource !== undefined) {
      updates.push('transcription_source = ?');
      values.push(data.transcriptionSource);
    }
    if (data.transcriptionConfidence !== undefined) {
      updates.push('transcription_confidence = ?');
      values.push(data.transcriptionConfidence);
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
      `UPDATE field_notes SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    return this.getById(id);
  }

  /**
   * Delete field note
   */
  async delete(id: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'DELETE FROM field_notes WHERE id = ?',
      [id]
    );

    return result.changes > 0;
  }

  /**
   * Delete all field notes for a project
   */
  async deleteByProject(projectId: string): Promise<number> {
    const result = await this.db.runAsync(
      'DELETE FROM field_notes WHERE project_id = ?',
      [projectId]
    );

    return result.changes;
  }

  /**
   * Get field note count for a project
   */
  async getCount(projectId: string): Promise<number> {
    const result = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM field_notes WHERE project_id = ?',
      [projectId]
    );

    return result?.count ?? 0;
  }

  /**
   * Get unique tags used across all notes in a project
   */
  async getTags(projectId: string): Promise<string[]> {
    const rows = await this.db.getAllAsync<{ tags: string }>(
      'SELECT DISTINCT tags FROM field_notes WHERE project_id = ?',
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
   * Get notes with voice recordings
   */
  async getVoiceNotes(projectId: string): Promise<FieldNote[]> {
    const rows = await this.db.getAllAsync<FieldNoteRow>(
      `SELECT * FROM field_notes
       WHERE project_id = ? AND audio_uri IS NOT NULL
       ORDER BY timestamp DESC`,
      [projectId]
    );

    return rows.map(this.mapRowToFieldNote);
  }

  /**
   * Link note to waypoint
   */
  async linkToWaypoint(noteId: string, waypointId: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'UPDATE field_notes SET waypoint_id = ?, updated_at = ? WHERE id = ?',
      [waypointId, getCurrentTimestamp(), noteId]
    );

    return result.changes > 0;
  }

  /**
   * Link note to photo
   */
  async linkToPhoto(noteId: string, photoId: string): Promise<boolean> {
    const result = await this.db.runAsync(
      'UPDATE field_notes SET photo_id = ?, updated_at = ? WHERE id = ?',
      [photoId, getCurrentTimestamp(), noteId]
    );

    return result.changes > 0;
  }

  private mapRowToFieldNote(row: FieldNoteRow): FieldNote {
    return {
      id: row.id,
      projectId: row.project_id,
      waypointId: row.waypoint_id,
      photoId: row.photo_id,
      title: row.title,
      content: row.content,
      audioUri: row.audio_uri,
      audioDuration: row.audio_duration,
      transcriptionSource: row.transcription_source as FieldNote['transcriptionSource'],
      transcriptionConfidence: row.transcription_confidence,
      tags: safeJsonParse<string[]>(row.tags, []),
      latitude: row.latitude,
      longitude: row.longitude,
      timestamp: row.timestamp,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

interface FieldNoteRow {
  id: string;
  project_id: string;
  waypoint_id: string | null;
  photo_id: string | null;
  title: string | null;
  content: string;
  audio_uri: string | null;
  audio_duration: number | null;
  transcription_source: string | null;
  transcription_confidence: number | null;
  tags: string;
  latitude: number | null;
  longitude: number | null;
  timestamp: string;
  created_at: string;
  updated_at: string;
}
