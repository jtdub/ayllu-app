import { useState, useCallback, useRef, useEffect } from 'react';
import { PhotoService } from '@/services/photo';
import type { ExifData, LocationCoordinates } from '@/types';

interface UsePhotoReturn {
  savePhoto: (sourceUri: string) => Promise<SavedPhoto | null>;
  deletePhoto: (uri: string, thumbnailUri?: string | null) => Promise<void>;
  readExif: (uri: string) => Promise<ExifData | null>;
  writeGps: (uri: string, location: LocationCoordinates) => Promise<boolean>;
  generateThumbnail: (uri: string) => Promise<string | null>;
  saveToLibrary: (uri: string) => Promise<string | null>;
  getStorageSize: () => Promise<number>;
}

interface SavedPhoto {
  uri: string;
  filename: string;
  thumbnailUri: string | null;
  width: number;
  height: number;
}

/**
 * Hook for photo capture and management
 */
export function usePhoto(): UsePhotoReturn {
  const serviceRef = useRef<PhotoService | null>(null);

  useEffect(() => {
    serviceRef.current = new PhotoService();
    serviceRef.current.initialize();
  }, []);

  const savePhoto = useCallback(async (sourceUri: string): Promise<SavedPhoto | null> => {
    if (!serviceRef.current) return null;

    try {
      const { uri, filename } = await serviceRef.current.savePhoto(sourceUri);
      const dimensions = await serviceRef.current.getPhotoDimensions(uri);
      const thumbnailUri = await serviceRef.current.generateThumbnail(uri);

      return {
        uri,
        filename,
        thumbnailUri,
        width: dimensions.width,
        height: dimensions.height,
      };
    } catch (error) {
      console.error('Failed to save photo:', error);
      return null;
    }
  }, []);

  const deletePhoto = useCallback(
    async (uri: string, thumbnailUri?: string | null) => {
      if (!serviceRef.current) return;
      await serviceRef.current.deletePhoto(uri, thumbnailUri);
    },
    []
  );

  const readExif = useCallback(async (uri: string): Promise<ExifData | null> => {
    if (!serviceRef.current) return null;
    return serviceRef.current.readExifData(uri);
  }, []);

  const writeGps = useCallback(
    async (uri: string, location: LocationCoordinates): Promise<boolean> => {
      if (!serviceRef.current) return false;
      return serviceRef.current.writeGpsToExif(uri, location);
    },
    []
  );

  const generateThumbnail = useCallback(async (uri: string): Promise<string | null> => {
    if (!serviceRef.current) return null;
    return serviceRef.current.generateThumbnail(uri);
  }, []);

  const saveToLibrary = useCallback(async (uri: string): Promise<string | null> => {
    if (!serviceRef.current) return null;
    return serviceRef.current.saveToMediaLibrary(uri);
  }, []);

  const getStorageSize = useCallback(async (): Promise<number> => {
    if (!serviceRef.current) return 0;
    return serviceRef.current.getStorageSize();
  }, []);

  return {
    savePhoto,
    deletePhoto,
    readExif,
    writeGps,
    generateThumbnail,
    saveToLibrary,
    getStorageSize,
  };
}

export default usePhoto;
