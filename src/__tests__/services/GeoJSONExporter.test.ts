import { GeoJSONExporter } from '../../services/export/GeoJSONExporter';
import type { Project, Waypoint, Photo, FieldNote } from '../../types';

describe('GeoJSONExporter', () => {
  const mockProject: Project = {
    id: 'project-123',
    name: 'Test Project',
    description: 'A test project',
    startDate: '2024-01-01T00:00:00Z',
    endDate: null,
    boundingBox: null,
    defaultTags: ['archaeology'],
    customFields: {},
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
  };

  const mockWaypoints: Waypoint[] = [
    {
      id: 'wp-1',
      projectId: 'project-123',
      name: 'WP001',
      description: 'First waypoint',
      latitude: 37.7749,
      longitude: -122.4194,
      altitude: 10,
      accuracy: 5,
      heading: 90,
      speed: 0,
      tags: ['survey'],
      customFields: {},
      timestamp: '2024-01-15T10:30:00Z',
      createdAt: '2024-01-15T10:30:00Z',
      updatedAt: '2024-01-15T10:30:00Z',
    },
    {
      id: 'wp-2',
      projectId: 'project-123',
      name: 'WP002',
      description: null,
      latitude: 37.775,
      longitude: -122.4195,
      altitude: null,
      accuracy: 10,
      heading: null,
      speed: null,
      tags: [],
      customFields: {},
      timestamp: '2024-01-15T10:35:00Z',
      createdAt: '2024-01-15T10:35:00Z',
      updatedAt: '2024-01-15T10:35:00Z',
    },
  ];

  const mockPhotos: Photo[] = [
    {
      id: 'photo-1',
      projectId: 'project-123',
      waypointId: 'wp-1',
      filename: 'photo001.jpg',
      uri: '/path/to/photo.jpg',
      thumbnailUri: null,
      width: 4032,
      height: 3024,
      latitude: 37.7749,
      longitude: -122.4194,
      altitude: 10,
      bearing: 90,
      capturedAt: '2024-01-15T10:30:00Z',
      caption: 'Test photo',
      tags: ['site'],
      exifData: null,
      createdAt: '2024-01-15T10:30:00Z',
      updatedAt: '2024-01-15T10:30:00Z',
    },
  ];

  const mockNotes: FieldNote[] = [
    {
      id: 'note-1',
      projectId: 'project-123',
      waypointId: 'wp-1',
      photoId: null,
      title: 'Field observation',
      content: 'Observed ceramic fragments',
      audioUri: null,
      audioDuration: null,
      transcriptionSource: null,
      transcriptionConfidence: null,
      tags: ['ceramics'],
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: '2024-01-15T10:32:00Z',
      createdAt: '2024-01-15T10:32:00Z',
      updatedAt: '2024-01-15T10:32:00Z',
    },
  ];

  describe('exportProject', () => {
    it('should export project as valid GeoJSON', () => {
      const geojson = GeoJSONExporter.exportProject(
        mockProject,
        mockWaypoints,
        mockPhotos,
        mockNotes
      );

      const parsed = JSON.parse(geojson);

      expect(parsed.type).toBe('FeatureCollection');
      expect(Array.isArray(parsed.features)).toBe(true);
    });

    it('should include all waypoints as features', () => {
      const geojson = GeoJSONExporter.exportProject(mockProject, mockWaypoints, [], []);

      const parsed = JSON.parse(geojson);

      expect(parsed.features).toHaveLength(2);
      expect(parsed.features[0].properties.featureType).toBe('waypoint');
      expect(parsed.features[0].properties.name).toBe('WP001');
    });

    it('should include photos with location', () => {
      const geojson = GeoJSONExporter.exportProject(mockProject, [], mockPhotos, []);

      const parsed = JSON.parse(geojson);

      expect(parsed.features).toHaveLength(1);
      expect(parsed.features[0].properties.featureType).toBe('photo');
    });

    it('should include notes with location', () => {
      const geojson = GeoJSONExporter.exportProject(mockProject, [], [], mockNotes);

      const parsed = JSON.parse(geojson);

      expect(parsed.features).toHaveLength(1);
      expect(parsed.features[0].properties.featureType).toBe('field_note');
    });

    it('should exclude photos without location', () => {
      const photosWithoutLocation: Photo[] = [
        {
          ...mockPhotos[0],
          latitude: null,
          longitude: null,
        },
      ];

      const geojson = GeoJSONExporter.exportProject(mockProject, [], photosWithoutLocation, []);

      const parsed = JSON.parse(geojson);

      expect(parsed.features).toHaveLength(0);
    });

    it('should include project metadata in properties', () => {
      const geojson = GeoJSONExporter.exportProject(
        mockProject,
        mockWaypoints,
        mockPhotos,
        mockNotes
      );

      const parsed = JSON.parse(geojson);

      expect(parsed.properties.project.name).toBe('Test Project');
      expect(parsed.properties.exportedAt).toBeDefined();
      expect(parsed.properties.version).toBe('1.0.0');
    });
  });

  describe('waypointToFeature', () => {
    it('should convert waypoint to GeoJSON Point feature', () => {
      const feature = GeoJSONExporter.waypointToFeature(mockWaypoints[0]);

      expect(feature.type).toBe('Feature');
      expect(feature.id).toBe('wp-1');
      expect(feature.geometry.type).toBe('Point');
      expect(feature.geometry.coordinates).toEqual([-122.4194, 37.7749, 10]);
    });

    it('should include altitude in coordinates when present', () => {
      const feature = GeoJSONExporter.waypointToFeature(mockWaypoints[0]);

      expect(feature.geometry.coordinates).toHaveLength(3);
      expect(feature.geometry.coordinates[2]).toBe(10);
    });

    it('should exclude altitude when null', () => {
      const feature = GeoJSONExporter.waypointToFeature(mockWaypoints[1]);

      expect(feature.geometry.coordinates).toHaveLength(2);
    });

    it('should include all properties', () => {
      const feature = GeoJSONExporter.waypointToFeature(mockWaypoints[0]);

      expect(feature.properties.featureType).toBe('waypoint');
      expect(feature.properties.name).toBe('WP001');
      expect(feature.properties.description).toBe('First waypoint');
      expect(feature.properties.accuracy).toBe(5);
      expect(feature.properties.tags).toEqual(['survey']);
      expect(feature.properties.timestamp).toBe('2024-01-15T10:30:00Z');
    });
  });

  describe('exportWaypoints', () => {
    it('should export only waypoints', () => {
      const geojson = GeoJSONExporter.exportWaypoints(mockWaypoints);
      const parsed = JSON.parse(geojson);

      expect(parsed.type).toBe('FeatureCollection');
      expect(parsed.features).toHaveLength(2);
      expect(parsed.features.every((f: any) => f.properties.featureType === 'waypoint')).toBe(true);
    });
  });

  describe('parse', () => {
    it('should parse valid GeoJSON', () => {
      const geojson = GeoJSONExporter.exportWaypoints(mockWaypoints);
      const parsed = GeoJSONExporter.parse(geojson);

      expect(parsed.type).toBe('FeatureCollection');
      expect(parsed.features).toHaveLength(2);
    });

    it('should throw for invalid type', () => {
      const invalid = JSON.stringify({ type: 'Feature', geometry: {} });

      expect(() => GeoJSONExporter.parse(invalid)).toThrow('must be a FeatureCollection');
    });

    it('should throw for missing features array', () => {
      const invalid = JSON.stringify({ type: 'FeatureCollection' });

      expect(() => GeoJSONExporter.parse(invalid)).toThrow('features must be an array');
    });
  });
});
