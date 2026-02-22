import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import type { SQLiteDatabase } from 'expo-sqlite';
import { openDatabase } from '@/database/schema';
import {
  ProjectRepository,
  WaypointRepository,
  PhotoRepository,
  FieldNoteRepository,
  MapRegionRepository,
  ExportHistoryRepository,
} from '@/database/repositories';

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

export function DatabaseProvider({ children }: DatabaseProviderProps) {
  const [db, setDb] = useState<SQLiteDatabase | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const [projectRepository, setProjectRepository] = useState<ProjectRepository | null>(null);
  const [waypointRepository, setWaypointRepository] = useState<WaypointRepository | null>(null);
  const [photoRepository, setPhotoRepository] = useState<PhotoRepository | null>(null);
  const [fieldNoteRepository, setFieldNoteRepository] = useState<FieldNoteRepository | null>(null);
  const [mapRegionRepository, setMapRegionRepository] = useState<MapRegionRepository | null>(null);
  const [exportHistoryRepository, setExportHistoryRepository] = useState<ExportHistoryRepository | null>(null);

  useEffect(() => {
    let mounted = true;

    async function initDatabase() {
      try {
        const database = await openDatabase();

        if (!mounted) return;

        setDb(database);
        setProjectRepository(new ProjectRepository(database));
        setWaypointRepository(new WaypointRepository(database));
        setPhotoRepository(new PhotoRepository(database));
        setFieldNoteRepository(new FieldNoteRepository(database));
        setMapRegionRepository(new MapRegionRepository(database));
        setExportHistoryRepository(new ExportHistoryRepository(database));
        setIsReady(true);

        console.log('Database initialized successfully');
      } catch (err) {
        console.error('Failed to initialize database:', err);
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

export function useDatabase() {
  const context = useContext(DatabaseContext);

  if (context === undefined) {
    throw new Error('useDatabase must be used within a DatabaseProvider');
  }

  return context;
}

export default useDatabase;
