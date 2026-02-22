import type { ReactNode } from 'react';
import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  ProjectRepository,
  WaypointRepository,
  PhotoRepository,
  FieldNoteRepository,
  MapRegionRepository,
  ExportHistoryRepository,
} from '@/database/repositories';
import { openDatabase } from '@/database/schema';
import type { SQLiteDatabase } from 'expo-sqlite';

interface DatabaseContextType {
  db: SQLiteDatabase | null;
  isReady: boolean;
  error: Error | null;
  projectRepository: ProjectRepository | null;
  waypointRepository: WaypointRepository | null;
  photoRepository: PhotoRepository | null;
  fieldNoteRepository: FieldNoteRepository | null;
  mapRegionRepository: MapRegionRepository | null;
  exportHistoryRepository: ExportHistoryRepository | null;
}

const DatabaseContext = createContext<DatabaseContextType>({
  db: null,
  isReady: false,
  error: null,
  projectRepository: null,
  waypointRepository: null,
  photoRepository: null,
  fieldNoteRepository: null,
  mapRegionRepository: null,
  exportHistoryRepository: null,
});

interface DatabaseProviderProps {
  children: ReactNode;
}

/**
 * Database provider component that initializes the SQLite database
 * and creates all repository instances.
 */
export function DatabaseProvider({ children }: DatabaseProviderProps) {
  const [db, setDb] = useState<SQLiteDatabase | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const [projectRepository, setProjectRepository] = useState<ProjectRepository | null>(null);
  const [waypointRepository, setWaypointRepository] = useState<WaypointRepository | null>(null);
  const [photoRepository, setPhotoRepository] = useState<PhotoRepository | null>(null);
  const [fieldNoteRepository, setFieldNoteRepository] = useState<FieldNoteRepository | null>(null);
  const [mapRegionRepository, setMapRegionRepository] = useState<MapRegionRepository | null>(null);
  const [exportHistoryRepository, setExportHistoryRepository] =
    useState<ExportHistoryRepository | null>(null);

  useEffect(() => {
    let mounted = true;

    async function initDatabase() {
      console.log('DatabaseProvider: Starting initialization...');

      try {
        const database = await openDatabase();
        console.log('DatabaseProvider: Database opened successfully');

        if (!mounted) {
          console.log('DatabaseProvider: Component unmounted during init');
          return;
        }

        setDb(database);
        setProjectRepository(new ProjectRepository(database));
        setWaypointRepository(new WaypointRepository(database));
        setPhotoRepository(new PhotoRepository(database));
        setFieldNoteRepository(new FieldNoteRepository(database));
        setMapRegionRepository(new MapRegionRepository(database));
        setExportHistoryRepository(new ExportHistoryRepository(database));
        setIsReady(true);

        console.log('DatabaseProvider: All repositories initialized');
      } catch (err) {
        console.error('DatabaseProvider: Failed to initialize database:', err);
        if (mounted) {
          setError(err instanceof Error ? err : new Error('Database initialization failed'));
        }
      }
    }

    initDatabase();

    return () => {
      mounted = false;
    };
  }, []);

  return (
    <DatabaseContext.Provider
      value={{
        db,
        isReady,
        error,
        projectRepository,
        waypointRepository,
        photoRepository,
        fieldNoteRepository,
        mapRegionRepository,
        exportHistoryRepository,
      }}
    >
      {children}
    </DatabaseContext.Provider>
  );
}

/**
 * Hook to access the database context and repositories.
 * Must be used within a DatabaseProvider.
 */
export function useDatabase() {
  const context = useContext(DatabaseContext);

  if (context === undefined) {
    throw new Error('useDatabase must be used within a DatabaseProvider');
  }

  return context;
}

export default useDatabase;
