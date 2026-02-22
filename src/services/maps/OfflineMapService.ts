import * as FileSystem from 'expo-file-system';
import type { BoundingBox, MapLayer, MapRegion } from '@/types';
import { calculateTileCount, estimateDownloadSize, generateId, getCurrentTimestamp } from '@/utils';

/**
 * Tile source URLs
 */
const TILE_SOURCES: Record<MapLayer, string> = {
  topo: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
  satellite:
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
};

/**
 * Offline map service for downloading and managing map tiles
 *
 * Note: Full offline functionality requires MapLibre React Native and a development build.
 * This service provides tile download management that works with MapLibre's OfflineManager.
 */
export class OfflineMapService {
  private cacheDir: string;
  private maxCacheSize: number;

  constructor(maxCacheSize: number = 2 * 1024 * 1024 * 1024) {
    // 2GB default
    this.cacheDir = `${FileSystem.cacheDirectory}map-tiles/`;
    this.maxCacheSize = maxCacheSize;
  }

  /**
   * Initialize the cache directory
   */
  async initialize(): Promise<void> {
    const dirInfo = await FileSystem.getInfoAsync(this.cacheDir);
    if (!dirInfo.exists) {
      await FileSystem.makeDirectoryAsync(this.cacheDir, { intermediates: true });
    }
  }

  /**
   * Calculate the number of tiles and estimated size for a region
   */
  calculateRegionStats(
    bounds: BoundingBox,
    minZoom: number,
    maxZoom: number,
    layers: MapLayer[]
  ): { tileCount: number; estimatedSize: number } {
    const tilesPerLayer = calculateTileCount(bounds, minZoom, maxZoom);
    const tileCount = tilesPerLayer * layers.length;
    const estimatedSize = estimateDownloadSize(tileCount);

    return { tileCount, estimatedSize };
  }

  /**
   * Get tiles that need to be downloaded for a region
   */
  getTilesToDownload(
    bounds: BoundingBox,
    minZoom: number,
    maxZoom: number,
    layer: MapLayer
  ): Array<{ z: number; x: number; y: number; url: string }> {
    const tiles: Array<{ z: number; x: number; y: number; url: string }> = [];

    for (let z = minZoom; z <= maxZoom; z++) {
      const n = Math.pow(2, z);

      const xMin = Math.floor(((bounds.minLon + 180) / 360) * n);
      const xMax = Math.floor(((bounds.maxLon + 180) / 360) * n);

      const yMin = Math.floor(
        ((1 -
          Math.log(
            Math.tan((bounds.maxLat * Math.PI) / 180) +
              1 / Math.cos((bounds.maxLat * Math.PI) / 180)
          ) /
            Math.PI) /
          2) *
          n
      );
      const yMax = Math.floor(
        ((1 -
          Math.log(
            Math.tan((bounds.minLat * Math.PI) / 180) +
              1 / Math.cos((bounds.minLat * Math.PI) / 180)
          ) /
            Math.PI) /
          2) *
          n
      );

      for (let x = xMin; x <= xMax; x++) {
        for (let y = yMin; y <= yMax; y++) {
          const url = TILE_SOURCES[layer]
            .replace('{z}', z.toString())
            .replace('{x}', x.toString())
            .replace('{y}', y.toString());

          tiles.push({ z, x, y, url });
        }
      }
    }

    return tiles;
  }

  /**
   * Download a single tile
   */
  async downloadTile(
    layer: MapLayer,
    z: number,
    x: number,
    y: number
  ): Promise<{ uri: string; size: number } | null> {
    const url = TILE_SOURCES[layer]
      .replace('{z}', z.toString())
      .replace('{x}', x.toString())
      .replace('{y}', y.toString());

    const localPath = `${this.cacheDir}${layer}/${z}/${x}/${y}.png`;
    const dirPath = `${this.cacheDir}${layer}/${z}/${x}/`;

    try {
      // Ensure directory exists
      const dirInfo = await FileSystem.getInfoAsync(dirPath);
      if (!dirInfo.exists) {
        await FileSystem.makeDirectoryAsync(dirPath, { intermediates: true });
      }

      // Download tile
      const result = await FileSystem.downloadAsync(url, localPath);

      if (result.status === 200) {
        const info = await FileSystem.getInfoAsync(localPath);
        const size = info.exists ? (info as { size: number }).size : 0;
        return { uri: localPath, size };
      }

      return null;
    } catch (error) {
      console.error(`Failed to download tile ${z}/${x}/${y}:`, error);
      return null;
    }
  }

  /**
   * Download all tiles for a region
   */
  async downloadRegion(
    bounds: BoundingBox,
    minZoom: number,
    maxZoom: number,
    layers: MapLayer[],
    onProgress?: (downloaded: number, total: number, sizeBytes: number) => void
  ): Promise<{ success: boolean; downloadedTiles: number; sizeBytes: number }> {
    await this.initialize();

    let downloadedTiles = 0;
    let totalSize = 0;

    for (const layer of layers) {
      const tiles = this.getTilesToDownload(bounds, minZoom, maxZoom, layer);
      const totalTiles = tiles.length;

      for (const tile of tiles) {
        const result = await this.downloadTile(layer, tile.z, tile.x, tile.y);

        if (result) {
          downloadedTiles++;
          totalSize += result.size;
        }

        if (onProgress) {
          onProgress(downloadedTiles, totalTiles * layers.length, totalSize);
        }
      }
    }

    return {
      success: true,
      downloadedTiles,
      sizeBytes: totalSize,
    };
  }

  /**
   * Check if a tile is cached
   */
  async isTileCached(layer: MapLayer, z: number, x: number, y: number): Promise<boolean> {
    const localPath = `${this.cacheDir}${layer}/${z}/${x}/${y}.png`;
    const info = await FileSystem.getInfoAsync(localPath);
    return info.exists;
  }

  /**
   * Get cached tile URI
   */
  getTileUri(layer: MapLayer, z: number, x: number, y: number): string {
    return `${this.cacheDir}${layer}/${z}/${x}/${y}.png`;
  }

  /**
   * Get total cache size
   */
  async getCacheSize(): Promise<number> {
    try {
      const info = await FileSystem.getInfoAsync(this.cacheDir);
      if (!info.exists) return 0;

      // This is a simplified size calculation
      // A full implementation would recursively calculate directory size
      return (info as { size?: number }).size || 0;
    } catch {
      return 0;
    }
  }

  /**
   * Clear entire tile cache
   */
  async clearCache(): Promise<void> {
    try {
      await FileSystem.deleteAsync(this.cacheDir, { idempotent: true });
      await this.initialize();
    } catch (error) {
      console.error('Failed to clear cache:', error);
    }
  }

  /**
   * Clear cache for a specific layer
   */
  async clearLayerCache(layer: MapLayer): Promise<void> {
    try {
      await FileSystem.deleteAsync(`${this.cacheDir}${layer}/`, { idempotent: true });
    } catch (error) {
      console.error(`Failed to clear ${layer} cache:`, error);
    }
  }
}
