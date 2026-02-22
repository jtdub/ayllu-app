import { ProjectRepository } from '../../database/repositories/ProjectRepository';
import type { SQLiteDatabase } from 'expo-sqlite';

describe('ProjectRepository', () => {
  let mockDb: jest.Mocked<SQLiteDatabase>;
  let repository: ProjectRepository;

  beforeEach(() => {
    mockDb = {
      runAsync: jest.fn().mockResolvedValue({ changes: 1 }),
      getFirstAsync: jest.fn(),
      getAllAsync: jest.fn().mockResolvedValue([]),
      execAsync: jest.fn(),
    } as unknown as jest.Mocked<SQLiteDatabase>;

    repository = new ProjectRepository(mockDb);
  });

  describe('create', () => {
    it('should create a new project', async () => {
      const projectData = {
        name: 'Test Project',
        description: 'A test project',
        startDate: '2024-01-01T00:00:00Z',
        endDate: null,
        boundingBox: null,
        defaultTags: ['archaeology', 'survey'],
        customFields: {},
      };

      const project = await repository.create(projectData);

      expect(project.name).toBe('Test Project');
      expect(project.description).toBe('A test project');
      expect(project.defaultTags).toEqual(['archaeology', 'survey']);
      expect(project.id).toBeDefined();
      expect(project.createdAt).toBeDefined();
      expect(project.updatedAt).toBeDefined();
      expect(mockDb.runAsync).toHaveBeenCalled();
    });

    it('should store boundingBox as JSON', async () => {
      const projectData = {
        name: 'Project with bounds',
        description: null,
        startDate: '2024-01-01T00:00:00Z',
        endDate: null,
        boundingBox: {
          minLat: 37.0,
          maxLat: 38.0,
          minLon: -123.0,
          maxLon: -122.0,
        },
        defaultTags: [],
        customFields: {},
      };

      await repository.create(projectData);

      expect(mockDb.runAsync).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([expect.stringContaining('"minLat":37')])
      );
    });
  });

  describe('getById', () => {
    it('should return null when project not found', async () => {
      mockDb.getFirstAsync.mockResolvedValue(null);

      const project = await repository.getById('nonexistent-id');

      expect(project).toBeNull();
    });

    it('should return project when found', async () => {
      mockDb.getFirstAsync.mockResolvedValue({
        id: 'test-id',
        name: 'Test Project',
        description: 'Description',
        start_date: '2024-01-01T00:00:00Z',
        end_date: null,
        bounding_box: null,
        default_tags: '["tag1"]',
        custom_fields: '{}',
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      });

      const project = await repository.getById('test-id');

      expect(project).not.toBeNull();
      expect(project?.id).toBe('test-id');
      expect(project?.name).toBe('Test Project');
      expect(project?.defaultTags).toEqual(['tag1']);
    });
  });

  describe('getAll', () => {
    it('should return empty array when no projects', async () => {
      mockDb.getAllAsync.mockResolvedValue([]);

      const projects = await repository.getAll();

      expect(projects).toEqual([]);
    });

    it('should return all projects', async () => {
      mockDb.getAllAsync.mockResolvedValue([
        {
          id: 'id-1',
          name: 'Project 1',
          description: null,
          start_date: '2024-01-01T00:00:00Z',
          end_date: null,
          bounding_box: null,
          default_tags: '[]',
          custom_fields: '{}',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
        },
        {
          id: 'id-2',
          name: 'Project 2',
          description: 'Second project',
          start_date: '2024-02-01T00:00:00Z',
          end_date: null,
          bounding_box: null,
          default_tags: '["survey"]',
          custom_fields: '{}',
          created_at: '2024-02-01T00:00:00Z',
          updated_at: '2024-02-01T00:00:00Z',
        },
      ]);

      const projects = await repository.getAll();

      expect(projects).toHaveLength(2);
      expect(projects[0].name).toBe('Project 1');
      expect(projects[1].name).toBe('Project 2');
    });
  });

  describe('update', () => {
    it('should return null when project not found', async () => {
      mockDb.getFirstAsync.mockResolvedValue(null);

      const result = await repository.update('nonexistent', { name: 'New Name' });

      expect(result).toBeNull();
    });

    it('should update project fields', async () => {
      // Mock getById for existing project
      mockDb.getFirstAsync
        .mockResolvedValueOnce({
          id: 'test-id',
          name: 'Old Name',
          description: null,
          start_date: '2024-01-01T00:00:00Z',
          end_date: null,
          bounding_box: null,
          default_tags: '[]',
          custom_fields: '{}',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
        })
        .mockResolvedValueOnce({
          id: 'test-id',
          name: 'New Name',
          description: 'New Description',
          start_date: '2024-01-01T00:00:00Z',
          end_date: null,
          bounding_box: null,
          default_tags: '[]',
          custom_fields: '{}',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-02T00:00:00Z',
        });

      const result = await repository.update('test-id', {
        name: 'New Name',
        description: 'New Description',
      });

      expect(result).not.toBeNull();
      expect(result?.name).toBe('New Name');
      expect(mockDb.runAsync).toHaveBeenCalled();
    });

    it('should return existing project when no updates provided', async () => {
      mockDb.getFirstAsync.mockResolvedValue({
        id: 'test-id',
        name: 'Project',
        description: null,
        start_date: '2024-01-01T00:00:00Z',
        end_date: null,
        bounding_box: null,
        default_tags: '[]',
        custom_fields: '{}',
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      });

      const result = await repository.update('test-id', {});

      expect(result).not.toBeNull();
      expect(mockDb.runAsync).not.toHaveBeenCalled();
    });
  });

  describe('delete', () => {
    it('should return true when project deleted', async () => {
      mockDb.runAsync.mockResolvedValue({ changes: 1 } as any);

      const result = await repository.delete('test-id');

      expect(result).toBe(true);
      expect(mockDb.runAsync).toHaveBeenCalledWith('DELETE FROM projects WHERE id = ?', [
        'test-id',
      ]);
    });

    it('should return false when project not found', async () => {
      mockDb.runAsync.mockResolvedValue({ changes: 0 } as any);

      const result = await repository.delete('nonexistent');

      expect(result).toBe(false);
    });
  });

  describe('search', () => {
    it('should search projects by name and description', async () => {
      mockDb.getAllAsync.mockResolvedValue([
        {
          id: 'id-1',
          name: 'Archaeological Survey',
          description: 'Site investigation',
          start_date: '2024-01-01T00:00:00Z',
          end_date: null,
          bounding_box: null,
          default_tags: '[]',
          custom_fields: '{}',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
        },
      ]);

      const results = await repository.search('survey');

      expect(results).toHaveLength(1);
      expect(results[0].name).toBe('Archaeological Survey');
      expect(mockDb.getAllAsync).toHaveBeenCalledWith(expect.stringContaining('LIKE'), [
        '%survey%',
        '%survey%',
      ]);
    });
  });

  describe('getStats', () => {
    it('should return project statistics', async () => {
      mockDb.getFirstAsync
        .mockResolvedValueOnce({ count: 10 }) // waypoints
        .mockResolvedValueOnce({ count: 5 }) // photos
        .mockResolvedValueOnce({ count: 3 }) // notes
        .mockResolvedValueOnce({
          // date range
          min_date: '2024-01-01T00:00:00Z',
          max_date: '2024-01-15T00:00:00Z',
        });

      const stats = await repository.getStats('project-id');

      expect(stats.waypointCount).toBe(10);
      expect(stats.photoCount).toBe(5);
      expect(stats.noteCount).toBe(3);
      expect(stats.dateRange.start).toBe('2024-01-01T00:00:00Z');
      expect(stats.dateRange.end).toBe('2024-01-15T00:00:00Z');
    });

    it('should handle null date range', async () => {
      mockDb.getFirstAsync
        .mockResolvedValueOnce({ count: 0 })
        .mockResolvedValueOnce({ count: 0 })
        .mockResolvedValueOnce({ count: 0 })
        .mockResolvedValueOnce({ min_date: null, max_date: null });

      const stats = await repository.getStats('empty-project');

      expect(stats.waypointCount).toBe(0);
      expect(stats.dateRange.start).toBeNull();
      expect(stats.dateRange.end).toBeNull();
    });
  });
});
