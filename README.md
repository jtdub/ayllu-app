# Ayllu - Field Research Companion

A React Native/Expo mobile app for archaeological and anthropological fieldwork, combining GPS waypoints, photo documentation, voice-to-text field notes, and offline maps with QGIS export.

## Features

- **GPS Waypoint Logging**: Record locations with full metadata (accuracy, altitude, heading, speed)
- **Photo Documentation**: Capture field photos with embedded GPS coordinates and EXIF data
- **Field Notes**: Text notes with optional voice recording and transcription
- **Offline Maps**: Download map regions for use without internet (topo + satellite)
- **GeoJSON/GeoPackage Export**: Export data for use in QGIS and other GIS applications
- **MCP Server**: Desktop integration for AI-assisted data management

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | React Native with Expo (development builds) |
| Navigation | Expo Router with typed routes |
| Storage | SQLite via expo-sqlite with FTS5 full-text search |
| Maps | MapLibre React Native (offline capable) |
| Camera | react-native-vision-camera with GPS/EXIF support |
| Location | expo-location with background tracking |
| Export | GeoJSON, GeoPackage (via MCP server), CSV |
| Testing | Jest + React Native Testing Library |
| Linting | ESLint + Prettier + Husky |

## Getting Started

### Prerequisites

- Node.js 18+
- Expo CLI: `npm install -g expo-cli`
- For iOS: Xcode 15+ and CocoaPods
- For Android: Android Studio with SDK 34+

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/ayllu-app.git
cd ayllu-app

# Install dependencies
npm install

# Set up Git hooks
npm run prepare
```

### Running the App

```bash
# Start Expo development server
npm start

# Run on iOS simulator
npm run ios

# Run on Android emulator
npm run android
```

### Development Build (Required for Full Features)

MapLibre and react-native-vision-camera require native code. Create a development build:

```bash
# Generate native projects
npx expo prebuild

# Run on iOS
npx expo run:ios

# Run on Android
npx expo run:android
```

## Project Structure

```
ayllu-app/
├── app/                          # Expo Router screens
│   ├── (tabs)/                   # Tab navigation
│   │   ├── index.tsx             # Dashboard
│   │   ├── map.tsx               # Map view
│   │   ├── notes.tsx             # Field notes
│   │   ├── photos.tsx            # Photo gallery
│   │   └── settings.tsx          # Settings & export
│   ├── project/[id].tsx          # Project detail
│   ├── waypoint/[id].tsx         # Waypoint detail
│   └── export/[projectId].tsx    # Export modal
├── src/
│   ├── components/               # UI components
│   │   ├── map/                  # MapView, WaypointMarker, LayerSelector
│   │   ├── camera/               # CameraView, PhotoPreview
│   │   ├── voice/                # VoiceRecorder, TranscriptionView
│   │   └── notes/                # NoteEditor, NoteCard
│   ├── database/
│   │   ├── schema.ts             # SQLite schema with FTS5
│   │   └── repositories/         # Data access layer
│   ├── services/
│   │   ├── location/             # GPS tracking service
│   │   ├── maps/                 # Offline tile management
│   │   ├── export/               # GeoJSON, GeoPackage exporters
│   │   ├── voice/                # Speech-to-text service
│   │   └── photo/                # Camera & EXIF handling
│   ├── hooks/                    # React hooks (useLocation, useVoice, etc.)
│   ├── types/                    # TypeScript type definitions
│   └── utils/                    # Utility functions
├── mcp-server/                   # Desktop MCP server
│   └── src/
│       ├── index.ts              # MCP entry point
│       ├── tools/                # Query and export tools
│       └── data-manager.ts       # Field data file parser
└── app.json                      # Expo configuration
```

## Database Schema

The app uses SQLite with the following tables:

| Table | Description |
|-------|-------------|
| **projects** | Field research projects with metadata and custom fields |
| **waypoints** | GPS points with full location data and tags |
| **photos** | Images with EXIF metadata and GPS coordinates |
| **field_notes** | Text notes with optional voice transcription |
| **field_notes_fts** | Full-text search index for notes |
| **map_regions** | Offline map download tracking |
| **tile_cache** | Cached map tiles with LRU eviction |
| **export_history** | Export file records |

## Development

### Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

Test files are located in `src/__tests__/` and cover:
- Utility functions
- Database repositories
- Services (GeoJSON export, etc.)
- React hooks
- Components

### Linting & Formatting

```bash
# Run ESLint
npm run lint

# Fix auto-fixable issues
npm run lint:fix

# Check formatting
npm run format:check

# Format all files
npm run format
```

The project uses:
- **ESLint** with TypeScript, React, and React Native plugins
- **Prettier** for code formatting
- **Husky** pre-commit hooks to ensure code quality

### Type Checking

```bash
# Run TypeScript compiler
npx tsc --noEmit
```

## Export Formats

### GeoJSON

Standard format for GIS applications. Contains all waypoints, photos, and notes with full metadata.

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-122.4194, 37.7749, 10]
      },
      "properties": {
        "featureType": "waypoint",
        "name": "WP001",
        "tags": ["survey", "artifact"]
      }
    }
  ],
  "properties": {
    "project": { "name": "Site Survey" },
    "exportedAt": "2024-01-15T10:30:00Z",
    "version": "1.0.0"
  }
}
```

### GeoPackage

SQLite-based OGC standard. Export as JSON from mobile, convert via MCP server using:
```bash
ogr2ogr -f GPKG output.gpkg input.geojson
```

### CSV

Simple spreadsheet format for waypoints only.

## Offline Maps

1. Open the Map tab
2. Navigate to your field area
3. In Settings, select "Download Region"
4. Choose zoom levels and map layers (topo/satellite)
5. Download tiles for offline use

**Tile Sources:**
- **Topographic**: OpenTopoMap
- **Satellite**: ESRI World Imagery

Map tiles are stored locally with configurable cache limits (default 2GB).

## MCP Server

The MCP server provides AI integration for desktop data management with Claude Desktop.

### Setup

```bash
cd mcp-server
npm install
npm run build
```

Add to Claude Desktop configuration:

```json
{
  "mcpServers": {
    "ayllu": {
      "command": "node",
      "args": ["/path/to/ayllu-app/mcp-server/dist/index.js"],
      "env": {
        "DATA_DIRECTORY": "/path/to/exported-field-data"
      }
    }
  }
}
```

### Available Tools

| Tool | Description |
|------|-------------|
| `query_waypoints` | Filter waypoints by tags, dates, bounding box |
| `query_photos` | Search photos by metadata |
| `export_to_qgis` | Generate QGIS-compatible exports |
| `spatial_analysis` | Buffer, convex hull, centroid calculations |
| `generate_report` | Summary reports from field data |

### Resources

- `field-data://projects` - List all projects
- `field-data://waypoints/{projectId}` - Waypoints for a project
- `field-data://photos/{projectId}` - Photos with metadata
- `field-data://notes/{projectId}` - Field notes

## Permissions Required

### iOS
- Location (foreground + background)
- Camera
- Microphone
- Photo Library

### Android
- ACCESS_FINE_LOCATION
- ACCESS_BACKGROUND_LOCATION
- CAMERA
- RECORD_AUDIO
- READ/WRITE_EXTERNAL_STORAGE

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Ensure linting passes (`npm run lint`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Follow ESLint and Prettier configurations
- Write tests for new functionality
- Add TSDoc comments to exported functions
- Keep commits focused and descriptive

## License

MIT
