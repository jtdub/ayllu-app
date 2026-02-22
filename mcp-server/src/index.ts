#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { DataManager } from './data-manager.js';
import * as tools from './tools/index.js';

const server = new Server(
  {
    name: 'ayllu-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      resources: {},
      tools: {},
    },
  }
);

// Data manager instance
let dataManager: DataManager | null = null;

// Initialize data manager with data directory
function initDataManager(dataDir?: string): DataManager {
  if (!dataManager) {
    dataManager = new DataManager(dataDir || process.env.AYLLU_DATA_DIR || '.');
  }
  return dataManager;
}

// List available resources
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  const dm = initDataManager();
  const projects = await dm.getProjects();

  const resources = [
    {
      uri: 'field-data://projects',
      name: 'All Projects',
      description: 'List of all field research projects',
      mimeType: 'application/json',
    },
  ];

  // Add project-specific resources
  for (const project of projects) {
    resources.push(
      {
        uri: `field-data://waypoints/${project.id}`,
        name: `Waypoints: ${project.name}`,
        description: `GPS waypoints for ${project.name}`,
        mimeType: 'application/json',
      },
      {
        uri: `field-data://photos/${project.id}`,
        name: `Photos: ${project.name}`,
        description: `Field photos for ${project.name}`,
        mimeType: 'application/json',
      },
      {
        uri: `field-data://notes/${project.id}`,
        name: `Notes: ${project.name}`,
        description: `Field notes for ${project.name}`,
        mimeType: 'application/json',
      }
    );
  }

  return { resources };
});

// Read resource content
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const dm = initDataManager();
  const uri = request.params.uri;

  if (uri === 'field-data://projects') {
    const projects = await dm.getProjects();
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(projects, null, 2),
        },
      ],
    };
  }

  const waypointsMatch = uri.match(/^field-data:\/\/waypoints\/(.+)$/);
  if (waypointsMatch) {
    const projectId = waypointsMatch[1];
    const waypoints = await dm.getWaypoints(projectId);
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(waypoints, null, 2),
        },
      ],
    };
  }

  const photosMatch = uri.match(/^field-data:\/\/photos\/(.+)$/);
  if (photosMatch) {
    const projectId = photosMatch[1];
    const photos = await dm.getPhotos(projectId);
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(photos, null, 2),
        },
      ],
    };
  }

  const notesMatch = uri.match(/^field-data:\/\/notes\/(.+)$/);
  if (notesMatch) {
    const projectId = notesMatch[1];
    const notes = await dm.getNotes(projectId);
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(notes, null, 2),
        },
      ],
    };
  }

  throw new Error(`Unknown resource: ${uri}`);
});

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'query_waypoints',
        description: 'Query waypoints with filters (tags, date range, bounding box)',
        inputSchema: {
          type: 'object',
          properties: {
            projectId: { type: 'string', description: 'Project ID' },
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: 'Filter by tags',
            },
            startDate: { type: 'string', description: 'Start date (ISO format)' },
            endDate: { type: 'string', description: 'End date (ISO format)' },
            bounds: {
              type: 'object',
              properties: {
                minLat: { type: 'number' },
                maxLat: { type: 'number' },
                minLon: { type: 'number' },
                maxLon: { type: 'number' },
              },
              description: 'Bounding box filter',
            },
          },
          required: ['projectId'],
        },
      },
      {
        name: 'query_photos',
        description: 'Query photos with filters',
        inputSchema: {
          type: 'object',
          properties: {
            projectId: { type: 'string', description: 'Project ID' },
            waypointId: { type: 'string', description: 'Filter by waypoint' },
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: 'Filter by tags',
            },
            hasCaption: { type: 'boolean', description: 'Filter by caption presence' },
          },
          required: ['projectId'],
        },
      },
      {
        name: 'export_to_qgis',
        description: 'Export project data to QGIS-compatible formats (GeoJSON, GeoPackage)',
        inputSchema: {
          type: 'object',
          properties: {
            projectId: { type: 'string', description: 'Project ID' },
            format: {
              type: 'string',
              enum: ['geojson', 'geopackage'],
              description: 'Output format',
            },
            outputPath: { type: 'string', description: 'Output file path' },
            includePhotos: { type: 'boolean', description: 'Include photo locations' },
            includeNotes: { type: 'boolean', description: 'Include note locations' },
          },
          required: ['projectId', 'format', 'outputPath'],
        },
      },
      {
        name: 'spatial_analysis',
        description: 'Perform spatial analysis on waypoints (buffer, convex hull, centroid, distance)',
        inputSchema: {
          type: 'object',
          properties: {
            projectId: { type: 'string', description: 'Project ID' },
            operation: {
              type: 'string',
              enum: ['buffer', 'convex_hull', 'centroid', 'bounding_box', 'total_distance'],
              description: 'Spatial operation to perform',
            },
            bufferRadius: {
              type: 'number',
              description: 'Buffer radius in meters (for buffer operation)',
            },
          },
          required: ['projectId', 'operation'],
        },
      },
      {
        name: 'generate_report',
        description: 'Generate a summary report of field data',
        inputSchema: {
          type: 'object',
          properties: {
            projectId: { type: 'string', description: 'Project ID' },
            format: {
              type: 'string',
              enum: ['text', 'markdown', 'json'],
              description: 'Report format',
            },
          },
          required: ['projectId'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const dm = initDataManager();
  const { name, arguments: args } = request.params;

  switch (name) {
    case 'query_waypoints':
      return tools.queryWaypoints(dm, args as tools.QueryWaypointsArgs);

    case 'query_photos':
      return tools.queryPhotos(dm, args as tools.QueryPhotosArgs);

    case 'export_to_qgis':
      return tools.exportToQgis(dm, args as tools.ExportToQgisArgs);

    case 'spatial_analysis':
      return tools.spatialAnalysis(dm, args as tools.SpatialAnalysisArgs);

    case 'generate_report':
      return tools.generateReport(dm, args as tools.GenerateReportArgs);

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Ayllu MCP Server running on stdio');
}

main().catch(console.error);
