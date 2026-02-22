import { WaypointRepository } from '../../database/repositories/WaypointRepository';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { WaypointFilter } from '../../types';

describe('WaypointRepository', () => {
  let mockDb: jest.Mocked<SQLiteDatabase>;
  let repository: WaypointRepository;

  beforeEach(() => {
    mockDb = {
      runAsync: jest.fn().mockResolvedValue({ changes: 1 }),
      getFirstAsync: jest.fn(),
      getAllAsync: jest.fn().mockResolvedValue([]),
      execAsync: jest.fn(),
    } as unknown as jest.Mocked<SQLiteDatabase>;

    repository = new WaypointRepository(mockDb);
  });

  describe('create', () => {
    it('should create a new waypoint', async () => {
      const waypointData = {
        projectId: 'project-123',
        name: 'WP001',
        description: 'Test waypoint',
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
        accuracy: 5,
        heading: 90,
        speed: 0,
        tags: ['survey', 'marker'],
        customFields: { siteType: 'excavation' },
        timestamp: '2024-01-15T10:30:00Z',
      };

      const waypoint = await repository.create(waypointData);

      expect(waypoint.name).toBe('WP001');
      expect(waypoint.latitude).toBe(37.7749);
      expect(waypoint.longitude).toBe(-122.4194);
      expect(waypoint.tags).toEqual(['survey', 'marker']);
      expect(waypoint.id).toBeDefined();
      expect(mockDb.runAsync).toHaveBeenCalled();
    });
  });

  describe('getByProject', () => {
    it('should return waypoints for a project', async () => {
      mockDb.getAllAsync.mockResolvedValue([
        {
          id: 'wp-1',
          project_id: 'project-123',
          name: 'WP001',
          description: null,
          latitude: 37.7749,
          longitude: -122.4194,
          altitude: null,
          accuracy: 5,
          heading: null,
          speed: null,
          tags: '["survey"]',
          custom_fields: '{}',
          timestamp: '2024-01-15T10:30:00Z',
          created_at: '2024-01-15T10:30:00Z',
          updated_at: '2024-01-15T10:30:00Z',
        },
      ]);

      const waypoints = await repository.getByProject('project-123');

      expect(waypoints).toHaveLength(1);
      expect(waypoints[0].name).toBe('WP001');
      expect(waypoints[0].tags).toEqual(['survey']);
    });
  });

  describe('query', () => {
    it('should filter by tags', async () => {
      mockDb.getAllAsync.mockResolvedValue([]);

      const filter: WaypointFilter = {
        projectId: 'project-123',
        tags: ['survey', 'excavation'],
      };

      await repository.query(filter);

      expect(mockDb.getAllAsync).toHaveBeenCalledWith(
        expect.stringContaining('tags LIKE'),
        expect.arrayContaining(['project-123', '%"survey"%', '%"excavation"%'])
      );
    });

    it('should filter by date range', async () => {
      mockDb.getAllAsync.mockResolvedValue([]);

      const filter: WaypointFilter = {
        projectId: 'project-123',
        startDate: '2024-01-01T00:00:00Z',
        endDate: '2024-01-31T23:59:59Z',
      };

      await repository.query(filter);

      expect(mockDb.getAllAsync).toHaveBeenCalledWith(
        expect.stringContaining('timestamp >='),
        expect.arrayContaining([
          'project-123',
          '2024-01-01T00:00:00Z',
          '2024-01-31T23:59:59Z',
        ])
      );
    });

    it('should filter by bounding box', async () => {
      mockDb.getAllAsync.mockResolvedValue([]);

      const filter: WaypointFilter = {
        projectId: 'project-123',
        bounds: {
          minLat: 37.0,
          maxLat: 38.0,
          minLon: -123.0,
          maxLon: -122.0,
        },
      };

      await repository.query(filter);

      expect(mockDb.getAllAsync).toHaveBeenCalledWith(
        expect.stringContaining('latitude >= ? AND latitude <= ?'),
        expect.arrayContaining([37.0, 38.0, -123.0, -122.0])
      );
    });

    it('should filter by search text', async () => {
      mockDb.getAllAsync.mockResolvedValue([]);

      const filter: WaypointFilter = {
        projectId: 'project-123',
        searchText: 'excavation',
      };

      await repository.query(filter);

      expect(mockDb.getAllAsync).toHaveBeenCalledWith(
        expect.stringContaining('name LIKE'),
        expect.arrayContaining(['%excavation%', '%excavation%'])
      );
    });
  });

  describe('getBoundingBox', () => {
    it('should return null for empty project', async () => {
      mockDb.getFirstAsync.mockResolvedValue({
        min_lat: null,
        max_lat: null,
        min_lon: null,
        max_lon: null,
      });

      const bounds = await repository.getBoundingBox('empty-project');

      expect(bounds).toBeNull();
    });

    it('should return bounding box for project', async () => {
      mockDb.getFirstAsync.mockResolvedValue({
        min_lat: 37.0,
        max_lat: 38.0,
        min_lon: -123.0,
        max_lon: -122.0,
      });

      const bounds = await repository.getBoundingBox('project-123');

      expect(bounds).toEqual({
        minLat: 37.0,
        maxLat: 38.0,
        minLon: -123.0,
        maxLon: -122.0,
      });
    });
  });

  describe('getTags', () => {
    it('should return unique tags', async () => {
      mockDb.getAllAsync.mockResolvedValue([
        { tags: '["survey", "marker"]' },
        { tags: '["survey", "excavation"]' },
        { tags: '["photo"]' },
      ]);

      const tags = await repository.getTags('project-123');

      expect(tags).toContain('survey');
      expect(tags).toContain('marker');
      expect(tags).toContain('excavation');
      expect(tags).toContain('photo');
      expect(tags).toHaveLength(4);
    });
  });

  describe('findNearby', () => {
    it('should find waypoints within radius', async () => {
      mockDb.getAllAsync.mockResolvedValue([
        {
          id: 'wp-1',
          project_id: 'project-123',
          name: 'Nearby WP',
          description: null,
          latitude: 37.7750,
          longitude: -122.4195,
          altitude: null,
          accuracy: 5,
          heading: null,
          speed: null,
          tags: '[]',
          custom_fields: '{}',
          timestamp: '2024-01-15T10:30:00Z',
          created_at: '2024-01-15T10:30:00Z',
          updated_at: '2024-01-15T10:30:00Z',
        },
      ]);

      const nearby = await repository.findNearby(37.7749, -122.4194, 100);

      expect(nearby).toHaveLength(1);
      expect(nearby[0].name).toBe('Nearby WP');
    });
  });

  describe('getCount', () => {
    it('should return waypoint count for project', async () => {
      mockDb.getFirstAsync.mockResolvedValue({ count: 42 });

      const count = await repository.getCount('project-123');

      expect(count).toBe(42);
    });
  });

  describe('delete', () => {
    it('should delete waypoint', async () => {
      mockDb.runAsync.mockResolvedValue({ changes: 1 } as any);

      const result = await repository.delete('wp-123');

      expect(result).toBe(true);
    });
  });
});
