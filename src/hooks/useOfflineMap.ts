import { useState, useCallback, useRef, useEffect } from 'react';
import { OfflineMapService } from '@/services/maps';
import type { BoundingBox, MapLayer, MapRegion } from '@/types';
import { generateId, getCurrentTimestamp, calculateTileCount, estimateDownloadSize } from '@/utils';
import { useDatabase } from './useDatabase';

interface UseOfflineMapReturn {
  regions: MapRegion[];
  isDownloading: boolean;
  downloadProgress: number;
  currentDownloadId: string | null;
  downloadRegion: (config: DownloadRegionConfig) => Promise<void>;
  cancelDownload: () => void;
  deleteRegion: (regionId: string) => Promise<void>;
  refreshRegions: () => Promise<void>;
  getTotalSize: () => Promise<number>;
  estimateSize: (
    bounds: BoundingBox,
    minZoom: number,
    maxZoom: number,
    layers: MapLayer[]
  ) => number;
}

interface DownloadRegionConfig {
  name: string;
  bounds: BoundingBox;
  minZoom: number;
  maxZoom: number;
  layers: MapLayer[];
}

/**
 * Hook for managing offline map regions
 */
export function useOfflineMap(): UseOfflineMapReturn {
  const { mapRegionRepository } = useDatabase();
  const [regions, setRegions] = useState<MapRegion[]>([]);
  const [isDownloading, setIsDownloading] = useState(false);
  const [downloadProgress, setDownloadProgress] = useState(0);
  const [currentDownloadId, setCurrentDownloadId] = useState<string | null>(null);

  const serviceRef = useRef<OfflineMapService | null>(null);
  const cancelledRef = useRef(false);

  // Initialize service
  useEffect(() => {
    serviceRef.current = new OfflineMapService();
  }, []);

  // Load regions on mount
  useEffect(() => {
    refreshRegions();
  }, [mapRegionRepository]);

  const refreshRegions = useCallback(async () => {
    if (!mapRegionRepository) return;

    try {
      const data = await mapRegionRepository.getAll();
      setRegions(data);
    } catch (error) {
      console.error('Failed to load map regions:', error);
    }
  }, [mapRegionRepository]);

  const downloadRegion = useCallback(
    async (config: DownloadRegionConfig) => {
      if (!mapRegionRepository || !serviceRef.current || isDownloading) {
        return;
      }

      const tileCount =
        calculateTileCount(config.bounds, config.minZoom, config.maxZoom) * config.layers.length;

      // Create region record
      const region = await mapRegionRepository.create({
        name: config.name,
        bounds: config.bounds,
        minZoom: config.minZoom,
        maxZoom: config.maxZoom,
        layers: config.layers,
        tileCount,
      });

      setCurrentDownloadId(region.id);
      setIsDownloading(true);
      setDownloadProgress(0);
      cancelledRef.current = false;

      try {
        await mapRegionRepository.updateStatus(region.id, 'downloading');

        const result = await serviceRef.current.downloadRegion(
          config.bounds,
          config.minZoom,
          config.maxZoom,
          config.layers,
          (downloaded, total, sizeBytes) => {
            if (cancelledRef.current) {
              throw new Error('Download cancelled');
            }

            const progress = total > 0 ? downloaded / total : 0;
            setDownloadProgress(progress);

            // Update progress in database
            mapRegionRepository.updateProgress(region.id, downloaded, sizeBytes);
          }
        );

        if (result.success) {
          await mapRegionRepository.markComplete(region.id);
        } else {
          await mapRegionRepository.updateStatus(region.id, 'error', 'Download failed');
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        if (message === 'Download cancelled') {
          await mapRegionRepository.updateStatus(region.id, 'paused');
        } else {
          await mapRegionRepository.updateStatus(region.id, 'error', message);
        }
      } finally {
        setIsDownloading(false);
        setCurrentDownloadId(null);
        setDownloadProgress(0);
        await refreshRegions();
      }
    },
    [mapRegionRepository, isDownloading, refreshRegions]
  );

  const cancelDownload = useCallback(() => {
    cancelledRef.current = true;
  }, []);

  const deleteRegion = useCallback(
    async (regionId: string) => {
      if (!mapRegionRepository) return;

      try {
        await mapRegionRepository.delete(regionId);
        setRegions((prev) => prev.filter((r) => r.id !== regionId));
      } catch (error) {
        console.error('Failed to delete region:', error);
      }
    },
    [mapRegionRepository]
  );

  const getTotalSize = useCallback(async () => {
    if (!mapRegionRepository) return 0;
    return await mapRegionRepository.getTotalSize();
  }, [mapRegionRepository]);

  const estimateSize = useCallback(
    (bounds: BoundingBox, minZoom: number, maxZoom: number, layers: MapLayer[]) => {
      const tileCount = calculateTileCount(bounds, minZoom, maxZoom) * layers.length;
      return estimateDownloadSize(tileCount);
    },
    []
  );

  return {
    regions,
    isDownloading,
    downloadProgress,
    currentDownloadId,
    downloadRegion,
    cancelDownload,
    deleteRegion,
    refreshRegions,
    getTotalSize,
    estimateSize,
  };
}

export default useOfflineMap;
