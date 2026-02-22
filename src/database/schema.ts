import * as SQLite from 'expo-sqlite';

export const DATABASE_NAME = 'ayllu.db';
export const DATABASE_VERSION = 1;

/**
 * SQL statements for all tables in the Ayllu database
 * Each entry is an array of individual SQL statements to execute
 */
export const SCHEMA: Record<string, string[]> = {
  projects: [
    `CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      start_date TEXT NOT NULL,
      end_date TEXT,
      bounding_box TEXT,
      default_tags TEXT NOT NULL DEFAULT '[]',
      custom_fields TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`,
    `CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name)`,
    `CREATE INDEX IF NOT EXISTS idx_projects_start_date ON projects(start_date)`,
  ],

  waypoints: [
    `CREATE TABLE IF NOT EXISTS waypoints (
      id TEXT PRIMARY KEY NOT NULL,
      project_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      altitude REAL,
      accuracy REAL,
      heading REAL,
      speed REAL,
      tags TEXT NOT NULL DEFAULT '[]',
      custom_fields TEXT NOT NULL DEFAULT '{}',
      timestamp TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS idx_waypoints_project_id ON waypoints(project_id)`,
    `CREATE INDEX IF NOT EXISTS idx_waypoints_timestamp ON waypoints(timestamp)`,
    `CREATE INDEX IF NOT EXISTS idx_waypoints_location ON waypoints(latitude, longitude)`,
  ],

  photos: [
    `CREATE TABLE IF NOT EXISTS photos (
      id TEXT PRIMARY KEY NOT NULL,
      project_id TEXT NOT NULL,
      waypoint_id TEXT,
      filename TEXT NOT NULL,
      uri TEXT NOT NULL,
      thumbnail_uri TEXT,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      latitude REAL,
      longitude REAL,
      altitude REAL,
      bearing REAL,
      captured_at TEXT NOT NULL,
      caption TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      exif_data TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
      FOREIGN KEY (waypoint_id) REFERENCES waypoints(id) ON DELETE SET NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_photos_project_id ON photos(project_id)`,
    `CREATE INDEX IF NOT EXISTS idx_photos_waypoint_id ON photos(waypoint_id)`,
    `CREATE INDEX IF NOT EXISTS idx_photos_captured_at ON photos(captured_at)`,
    `CREATE INDEX IF NOT EXISTS idx_photos_location ON photos(latitude, longitude)`,
  ],

  field_notes: [
    `CREATE TABLE IF NOT EXISTS field_notes (
      id TEXT PRIMARY KEY NOT NULL,
      project_id TEXT NOT NULL,
      waypoint_id TEXT,
      photo_id TEXT,
      title TEXT,
      content TEXT NOT NULL,
      audio_uri TEXT,
      audio_duration REAL,
      transcription_source TEXT,
      transcription_confidence REAL,
      tags TEXT NOT NULL DEFAULT '[]',
      latitude REAL,
      longitude REAL,
      timestamp TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
      FOREIGN KEY (waypoint_id) REFERENCES waypoints(id) ON DELETE SET NULL,
      FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE SET NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_field_notes_project_id ON field_notes(project_id)`,
    `CREATE INDEX IF NOT EXISTS idx_field_notes_waypoint_id ON field_notes(waypoint_id)`,
    `CREATE INDEX IF NOT EXISTS idx_field_notes_timestamp ON field_notes(timestamp)`,
  ],

  map_regions: [
    `CREATE TABLE IF NOT EXISTS map_regions (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      bounds TEXT NOT NULL,
      min_zoom INTEGER NOT NULL,
      max_zoom INTEGER NOT NULL,
      layers TEXT NOT NULL DEFAULT '["topo"]',
      tile_count INTEGER NOT NULL DEFAULT 0,
      downloaded_tiles INTEGER NOT NULL DEFAULT 0,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      error_message TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`,
    `CREATE INDEX IF NOT EXISTS idx_map_regions_status ON map_regions(status)`,
  ],

  tile_cache: [
    `CREATE TABLE IF NOT EXISTS tile_cache (
      id TEXT PRIMARY KEY NOT NULL,
      region_id TEXT,
      layer TEXT NOT NULL,
      z INTEGER NOT NULL,
      x INTEGER NOT NULL,
      y INTEGER NOT NULL,
      uri TEXT NOT NULL,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      last_accessed_at TEXT NOT NULL DEFAULT (datetime('now')),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (region_id) REFERENCES map_regions(id) ON DELETE SET NULL,
      UNIQUE(layer, z, x, y)
    )`,
    `CREATE INDEX IF NOT EXISTS idx_tile_cache_region_id ON tile_cache(region_id)`,
    `CREATE INDEX IF NOT EXISTS idx_tile_cache_layer ON tile_cache(layer)`,
    `CREATE INDEX IF NOT EXISTS idx_tile_cache_last_accessed ON tile_cache(last_accessed_at)`,
  ],

  export_history: [
    `CREATE TABLE IF NOT EXISTS export_history (
      id TEXT PRIMARY KEY NOT NULL,
      project_id TEXT NOT NULL,
      format TEXT NOT NULL,
      filename TEXT NOT NULL,
      file_path TEXT NOT NULL,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      waypoint_count INTEGER NOT NULL DEFAULT 0,
      photo_count INTEGER NOT NULL DEFAULT 0,
      note_count INTEGER NOT NULL DEFAULT 0,
      exported_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS idx_export_history_project_id ON export_history(project_id)`,
    `CREATE INDEX IF NOT EXISTS idx_export_history_exported_at ON export_history(exported_at)`,
  ],

  settings: [
    `CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`,
  ],
};

/**
 * FTS5 schema - separated because it may fail if FTS5 is not enabled
 */
export const FTS_SCHEMA: string[] = [
  `CREATE VIRTUAL TABLE IF NOT EXISTS field_notes_fts USING fts5(
    title,
    content,
    content='field_notes',
    content_rowid='rowid'
  )`,
  `CREATE TRIGGER IF NOT EXISTS field_notes_ai AFTER INSERT ON field_notes BEGIN
    INSERT INTO field_notes_fts(rowid, title, content)
    VALUES (NEW.rowid, NEW.title, NEW.content);
  END`,
  `CREATE TRIGGER IF NOT EXISTS field_notes_ad AFTER DELETE ON field_notes BEGIN
    INSERT INTO field_notes_fts(field_notes_fts, rowid, title, content)
    VALUES('delete', OLD.rowid, OLD.title, OLD.content);
  END`,
  `CREATE TRIGGER IF NOT EXISTS field_notes_au AFTER UPDATE ON field_notes BEGIN
    INSERT INTO field_notes_fts(field_notes_fts, rowid, title, content)
    VALUES('delete', OLD.rowid, OLD.title, OLD.content);
    INSERT INTO field_notes_fts(rowid, title, content)
    VALUES (NEW.rowid, NEW.title, NEW.content);
  END`,
];

/**
 * Initialize the database with all tables
 */
export async function initializeDatabase(db: SQLite.SQLiteDatabase): Promise<void> {
  console.log('Starting database initialization...');

  // Enable foreign keys
  await db.execAsync('PRAGMA foreign_keys = ON;');
  console.log('Foreign keys enabled');

  // Create all tables
  for (const [tableName, statements] of Object.entries(SCHEMA)) {
    for (const statement of statements) {
      try {
        await db.execAsync(statement);
      } catch (error) {
        console.error(`Error executing statement for ${tableName}:`, error);
        throw error;
      }
    }
    console.log(`Created table: ${tableName}`);
  }

  // Try to create FTS tables (may fail if FTS5 not enabled, which is ok)
  for (const statement of FTS_SCHEMA) {
    try {
      await db.execAsync(statement);
    } catch (error) {
      console.warn('FTS5 setup skipped (not available):', error);
      // Don't throw - FTS is optional
      break;
    }
  }
  console.log('FTS setup attempted');

  // Set database version
  await db.execAsync(`PRAGMA user_version = ${DATABASE_VERSION};`);

  console.log('Database initialized successfully');
}

/**
 * Get the current database version
 */
export async function getDatabaseVersion(db: SQLite.SQLiteDatabase): Promise<number> {
  const result = await db.getFirstAsync<{ user_version: number }>('PRAGMA user_version;');
  return result?.user_version ?? 0;
}

/**
 * Check if database needs migration
 */
export async function needsMigration(db: SQLite.SQLiteDatabase): Promise<boolean> {
  const currentVersion = await getDatabaseVersion(db);
  return currentVersion < DATABASE_VERSION;
}

/**
 * Open and initialize the database
 */
export async function openDatabase(): Promise<SQLite.SQLiteDatabase> {
  console.log('Opening database...');
  const db = await SQLite.openDatabaseAsync(DATABASE_NAME);
  console.log('Database opened');

  const currentVersion = await getDatabaseVersion(db);
  console.log(`Current database version: ${currentVersion}`);

  if (currentVersion === 0) {
    // Fresh database, initialize
    await initializeDatabase(db);
  } else if (currentVersion < DATABASE_VERSION) {
    // Run migrations
    await runMigrations(db, currentVersion);
  }

  return db;
}

/**
 * Run database migrations from current version to latest
 */
export async function runMigrations(db: SQLite.SQLiteDatabase, fromVersion: number): Promise<void> {
  console.log(`Running migrations from version ${fromVersion} to ${DATABASE_VERSION}`);

  // Add migration logic here as the schema evolves
  // Example:
  // if (fromVersion < 2) {
  //   await db.execAsync('ALTER TABLE waypoints ADD COLUMN new_field TEXT;');
  // }

  await db.execAsync(`PRAGMA user_version = ${DATABASE_VERSION};`);
  console.log('Migrations complete');
}

/**
 * Close the database connection
 */
export async function closeDatabase(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.closeAsync();
}

/**
 * Delete the database (for testing/reset)
 */
export async function deleteDatabase(): Promise<void> {
  await SQLite.deleteDatabaseAsync(DATABASE_NAME);
}
