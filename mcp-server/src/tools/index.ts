import * as fs from 'fs';
import * as path from 'path';
import * as turf from '@turf/turf';
import { DataManager, BoundingBox, Waypoint, Photo } from '../data-manager.js';

export interface QueryWaypointsArgs {
  projectId: string;
  tags?: string[];
  startDate?: string;
  endDate?: string;
  bounds?: BoundingBox;
}

export interface QueryPhotosArgs {
  projectId: string;
  waypointId?: string;
  tags?: string[];
  hasCaption?: boolean;
}

export interface ExportToQgisArgs {
  projectId: string;
  format: 'geojson' | 'geopackage';
  outputPath: string;
  includePhotos?: boolean;
  includeNotes?: boolean;
}

export interface SpatialAnalysisArgs {
  projectId: string;
  operation: 'buffer' | 'convex_hull' | 'centroid' | 'bounding_box' | 'total_distance';
  bufferRadius?: number;
}

export interface GenerateReportArgs {
  projectId: string;
  format?: 'text' | 'markdown' | 'json';
}

export async function queryWaypoints(
  dm: DataManager,
  args: QueryWaypointsArgs
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  let waypoints = await dm.getWaypoints(args.projectId);

  // Filter by tags
  if (args.tags && args.tags.length > 0) {
    waypoints = waypoints.filter((wp) =>
      args.tags!.some((tag) => wp.tags.includes(tag))
    );
  }

  // Filter by date range
  if (args.startDate) {
    const start = new Date(args.startDate);
    waypoints = waypoints.filter((wp) => new Date(wp.timestamp) >= start);
  }

  if (args.endDate) {
    const end = new Date(args.endDate);
    waypoints = waypoints.filter((wp) => new Date(wp.timestamp) <= end);
  }

  // Filter by bounding box
  if (args.bounds) {
    waypoints = waypoints.filter(
      (wp) =>
        wp.latitude >= args.bounds!.minLat &&
        wp.latitude <= args.bounds!.maxLat &&
        wp.longitude >= args.bounds!.minLon &&
        wp.longitude <= args.bounds!.maxLon
    );
  }

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(waypoints, null, 2),
      },
    ],
  };
}

export async function queryPhotos(
  dm: DataManager,
  args: QueryPhotosArgs
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  let photos = await dm.getPhotos(args.projectId);

  // Filter by waypoint
  if (args.waypointId) {
    photos = photos.filter((p) => p.waypointId === args.waypointId);
  }

  // Filter by tags
  if (args.tags && args.tags.length > 0) {
    photos = photos.filter((p) =>
      args.tags!.some((tag) => p.tags.includes(tag))
    );
  }

  // Filter by caption presence
  if (args.hasCaption !== undefined) {
    photos = photos.filter((p) =>
      args.hasCaption ? p.caption !== null : p.caption === null
    );
  }

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(photos, null, 2),
      },
    ],
  };
}

export async function exportToQgis(
  dm: DataManager,
  args: ExportToQgisArgs
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const data = await dm.getFieldData(args.projectId);

  if (!data) {
    return {
      content: [{ type: 'text', text: `Project not found: ${args.projectId}` }],
    };
  }

  const features: turf.helpers.Feature[] = [];

  // Add waypoints
  for (const wp of data.waypoints) {
    features.push(
      turf.point([wp.longitude, wp.latitude, wp.altitude || 0], {
        id: wp.id,
        name: wp.name,
        description: wp.description,
        type: 'waypoint',
        tags: wp.tags,
        timestamp: wp.timestamp,
      })
    );
  }

  // Add photos if requested
  if (args.includePhotos !== false) {
    for (const photo of data.photos) {
      if (photo.latitude !== null && photo.longitude !== null) {
        features.push(
          turf.point([photo.longitude, photo.latitude], {
            id: photo.id,
            name: photo.filename,
            caption: photo.caption,
            type: 'photo',
            tags: photo.tags,
            timestamp: photo.capturedAt,
          })
        );
      }
    }
  }

  // Add notes if requested
  if (args.includeNotes !== false) {
    for (const note of data.notes) {
      if (note.latitude !== null && note.longitude !== null) {
        features.push(
          turf.point([note.longitude, note.latitude], {
            id: note.id,
            title: note.title,
            content: note.content.substring(0, 200),
            type: 'field_note',
            tags: note.tags,
            timestamp: note.timestamp,
          })
        );
      }
    }
  }

  const featureCollection = turf.featureCollection(features);

  // Ensure output directory exists
  const outputDir = path.dirname(args.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write GeoJSON
  const geojsonPath =
    args.format === 'geopackage'
      ? args.outputPath.replace(/\.gpkg$/, '.geojson')
      : args.outputPath;

  fs.writeFileSync(geojsonPath, JSON.stringify(featureCollection, null, 2));

  let message = `Exported ${features.length} features to ${geojsonPath}`;

  if (args.format === 'geopackage') {
    message +=
      '\n\nTo convert to GeoPackage, run:\n' +
      `ogr2ogr -f GPKG ${args.outputPath} ${geojsonPath}`;
  }

  return {
    content: [{ type: 'text', text: message }],
  };
}

export async function spatialAnalysis(
  dm: DataManager,
  args: SpatialAnalysisArgs
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const waypoints = await dm.getWaypoints(args.projectId);

  if (waypoints.length === 0) {
    return {
      content: [{ type: 'text', text: 'No waypoints found for this project' }],
    };
  }

  const points = waypoints.map((wp) =>
    turf.point([wp.longitude, wp.latitude])
  );
  const pointsCollection = turf.featureCollection(points);

  let result: any;

  switch (args.operation) {
    case 'buffer':
      const radius = args.bufferRadius || 100;
      const buffered = points.map((p) =>
        turf.buffer(p, radius, { units: 'meters' })
      );
      result = {
        type: 'buffer',
        radiusMeters: radius,
        buffers: turf.featureCollection(buffered),
      };
      break;

    case 'convex_hull':
      const hull = turf.convex(pointsCollection);
      result = {
        type: 'convex_hull',
        hull,
        areaSquareMeters: hull ? turf.area(hull) : 0,
      };
      break;

    case 'centroid':
      const centroid = turf.centroid(pointsCollection);
      result = {
        type: 'centroid',
        centroid,
        coordinates: centroid.geometry.coordinates,
      };
      break;

    case 'bounding_box':
      const bbox = turf.bbox(pointsCollection);
      result = {
        type: 'bounding_box',
        bbox: {
          minLon: bbox[0],
          minLat: bbox[1],
          maxLon: bbox[2],
          maxLat: bbox[3],
        },
        polygon: turf.bboxPolygon(bbox),
      };
      break;

    case 'total_distance':
      if (waypoints.length < 2) {
        result = { type: 'total_distance', distanceMeters: 0 };
      } else {
        // Sort by timestamp and calculate path distance
        const sorted = [...waypoints].sort(
          (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
        );
        const lineCoords = sorted.map((wp) => [wp.longitude, wp.latitude]);
        const line = turf.lineString(lineCoords);
        const distance = turf.length(line, { units: 'meters' });
        result = {
          type: 'total_distance',
          distanceMeters: distance,
          distanceKm: distance / 1000,
          waypointCount: waypoints.length,
        };
      }
      break;

    default:
      result = { error: `Unknown operation: ${args.operation}` };
  }

  return {
    content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
  };
}

export async function generateReport(
  dm: DataManager,
  args: GenerateReportArgs
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const data = await dm.getFieldData(args.projectId);

  if (!data) {
    return {
      content: [{ type: 'text', text: `Project not found: ${args.projectId}` }],
    };
  }

  const { project, waypoints, photos, notes } = data;
  const format = args.format || 'markdown';

  // Calculate statistics
  const photoWithLocation = photos.filter(
    (p) => p.latitude !== null && p.longitude !== null
  );
  const notesWithLocation = notes.filter(
    (n) => n.latitude !== null && n.longitude !== null
  );
  const voiceNotes = notes.filter((n) => n.audioUri !== null);

  // Calculate date range
  const allTimestamps = [
    ...waypoints.map((w) => new Date(w.timestamp)),
    ...photos.map((p) => new Date(p.capturedAt)),
    ...notes.map((n) => new Date(n.timestamp)),
  ].filter((d) => !isNaN(d.getTime()));

  const dateRange =
    allTimestamps.length > 0
      ? {
          start: new Date(Math.min(...allTimestamps.map((d) => d.getTime()))),
          end: new Date(Math.max(...allTimestamps.map((d) => d.getTime()))),
        }
      : null;

  // Calculate total distance
  let totalDistance = 0;
  if (waypoints.length >= 2) {
    const sorted = [...waypoints].sort(
      (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );
    const lineCoords = sorted.map((wp) => [wp.longitude, wp.latitude]);
    const line = turf.lineString(lineCoords);
    totalDistance = turf.length(line, { units: 'meters' });
  }

  // Collect all tags
  const allTags = new Set<string>();
  waypoints.forEach((w) => w.tags.forEach((t) => allTags.add(t)));
  photos.forEach((p) => p.tags.forEach((t) => allTags.add(t)));
  notes.forEach((n) => n.tags.forEach((t) => allTags.add(t)));

  const reportData = {
    project: {
      name: project.name,
      description: project.description,
      startDate: project.startDate,
      endDate: project.endDate,
    },
    statistics: {
      waypoints: waypoints.length,
      photos: photos.length,
      photosWithLocation: photoWithLocation.length,
      notes: notes.length,
      notesWithLocation: notesWithLocation.length,
      voiceNotes: voiceNotes.length,
      totalDistanceMeters: Math.round(totalDistance),
      totalDistanceKm: (totalDistance / 1000).toFixed(2),
      uniqueTags: Array.from(allTags),
    },
    dateRange: dateRange
      ? {
          start: dateRange.start.toISOString(),
          end: dateRange.end.toISOString(),
          durationDays: Math.ceil(
            (dateRange.end.getTime() - dateRange.start.getTime()) /
              (1000 * 60 * 60 * 24)
          ),
        }
      : null,
    generatedAt: new Date().toISOString(),
  };

  let output: string;

  switch (format) {
    case 'json':
      output = JSON.stringify(reportData, null, 2);
      break;

    case 'text':
      output = `
Field Research Report: ${reportData.project.name}
${'='.repeat(50)}

Description: ${reportData.project.description || 'N/A'}

Statistics:
- Waypoints: ${reportData.statistics.waypoints}
- Photos: ${reportData.statistics.photos} (${reportData.statistics.photosWithLocation} with GPS)
- Notes: ${reportData.statistics.notes} (${reportData.statistics.notesWithLocation} with GPS)
- Voice Notes: ${reportData.statistics.voiceNotes}
- Total Distance: ${reportData.statistics.totalDistanceKm} km

Date Range: ${
        reportData.dateRange
          ? `${reportData.dateRange.start.split('T')[0]} to ${
              reportData.dateRange.end.split('T')[0]
            } (${reportData.dateRange.durationDays} days)`
          : 'N/A'
      }

Tags Used: ${reportData.statistics.uniqueTags.join(', ') || 'None'}

Generated: ${reportData.generatedAt}
`.trim();
      break;

    case 'markdown':
    default:
      output = `
# Field Research Report: ${reportData.project.name}

${reportData.project.description ? `> ${reportData.project.description}` : ''}

## Statistics

| Metric | Value |
|--------|-------|
| Waypoints | ${reportData.statistics.waypoints} |
| Photos | ${reportData.statistics.photos} (${reportData.statistics.photosWithLocation} with GPS) |
| Notes | ${reportData.statistics.notes} (${reportData.statistics.notesWithLocation} with GPS) |
| Voice Notes | ${reportData.statistics.voiceNotes} |
| Total Distance | ${reportData.statistics.totalDistanceKm} km |

## Date Range

${
  reportData.dateRange
    ? `**Start:** ${reportData.dateRange.start.split('T')[0]}
**End:** ${reportData.dateRange.end.split('T')[0]}
**Duration:** ${reportData.dateRange.durationDays} days`
    : '_No data collected yet_'
}

## Tags

${
  reportData.statistics.uniqueTags.length > 0
    ? reportData.statistics.uniqueTags.map((t) => `\`${t}\``).join(' ')
    : '_No tags used_'
}

---

_Generated: ${reportData.generatedAt}_
`.trim();
      break;
  }

  return {
    content: [{ type: 'text', text: output }],
  };
}
