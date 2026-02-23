# Ayllu Field Research Companion App

## Project Overview

Native iOS app for archaeological, anthropological, and ecological fieldwork. Replaces 4-5 separate tools (GPS, camera, notes, offline maps, export) with a single offline-first companion.

**Target Users:** Archaeologists, anthropologists, conservation biologists, CRM professionals, field researchers.
**Platform:** iOS 17+ only (iPhone and iPad)

## Quick Reference

### Build Commands
```bash
# Build the project
xcodebuild -project Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -configuration Debug build

# Run tests
xcodebuild test -project Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Clean build
xcodebuild clean build -project Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator

# Open in Xcode
open Ayllu.xcodeproj
```

### Swift Package Manager
```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update
```

## Architecture

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Language | Swift 5.9+ | Native performance, best iOS integration |
| UI | SwiftUI | Modern declarative UI, iOS 17 features |
| Architecture | MVVM with @Observable | Simple, testable, SwiftUI-native |
| Database | GRDB.swift | Full SQL control, migrations, offline reliability |
| Maps | MapLibre Native iOS | Open source, excellent offline tile support |
| State | @Observable + @Environment | iOS 17 native, minimal boilerplate |
| Voice STT | SFSpeechRecognizer | On-device recognition, no network needed |
| Coordinates | Lat/Lon + UTM | Standard field research formats |
| Min iOS | 17.0 | Required for @Observable |

### Why GRDB.swift over SwiftData
- Full SQL control for spatial queries (bounding box, nearby waypoints)
- Reliable migration system for app updates in the field
- WAL mode for concurrent read/write
- Battle-tested in production apps

### Why MapLibre over MapKit
- MapKit cannot reliably pre-cache offline regions
- MapLibre has MGLOfflineStorage for true offline tile packs
- Open source, no per-user costs
- Compatible with free tile servers (OpenTopoMap)

## Project Structure

```
Ayllu/
├── App/                          # @main entry point, Info.plist
├── Core/
│   ├── Database/                 # GRDB setup, migrations, repositories
│   ├── Models/                   # Data models (Project, Waypoint, etc.)
│   ├── Services/                 # Location, Camera, Speech, Maps, Export
│   └── Extensions/               # Swift extensions
├── Features/
│   ├── Projects/                 # Project management views/viewmodels
│   ├── Waypoints/                # Waypoint CRUD views/viewmodels
│   ├── Notes/                    # Field notes with voice-to-text
│   ├── Map/                      # MapLibre integration, offline tiles
│   └── Settings/                 # App settings
├── Shared/                       # TabBarView, shared styles
├── Resources/                    # Assets
└── Tests/                        # Unit and UI tests
```

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| GRDB.swift | 7.0+ | SQLite database |
| MapLibre | 6.0+ | Offline maps |
| UTMConversion | 1.4+ | UTM coordinate transforms |
| CoreGPX | 0.9+ | GPX export |
| swift-snapshot-testing | 1.15+ | Snapshot tests |

## Database Schema

### Tables
- **projects** - Research projects (name, description, dates)
- **waypoints** - GPS points (lat/lon, altitude, accuracy, tags)
- **photos** - Geotagged images (file path, EXIF, caption)
- **field_notes** - Text/voice notes (content, audio path, transcription)
- **tracks** - GPS breadcrumb trails
- **track_points** - Individual GPS fixes in tracks
- **map_regions** - Offline tile regions (bounds, zoom, status)

### Key Features
- Foreign keys with CASCADE delete
- Indexes on projectId, timestamp, lat/lon
- JSON columns for tags and custom fields
- WAL mode for concurrent access

## Development Guidelines

### Code Style
- Use SwiftUI and iOS 17+ APIs
- Follow MVVM with @Observable
- Keep views thin, logic in ViewModels
- Use dependency injection via @Environment

### Testing
- Unit tests for repositories and formatters (90% coverage)
- ViewModel tests for state transitions (80% coverage)
- UI tests for critical user flows
- Snapshot tests for key views

### Offline-First Principles
- All core features must work without network
- Database writes are synchronous and reliable
- Map tiles pre-downloaded for field areas
- Speech recognition uses on-device model

### Permissions Required
- Location (When In Use + Always for tracking)
- Camera (geotagged photos)
- Microphone (voice notes)
- Speech Recognition (on-device transcription)

## Development Workflow

### GitHub Issues
- **Do not close issues directly** - Issues should only be closed via pull requests
- Link PRs to issues using "Closes #XX" or "Fixes #XX" in PR description
- All work should have a corresponding issue

### Milestones
- **Phase 1: MVP** - Core offline-first features (COMPLETE)
- **Phase 2: Polish** - UX improvements, export, photos, navigation
- **Phase 3: Pro Features** - Custom forms, hierarchical data, polygons
- **Phase 4: Advanced** - Collaboration, 3D scanning, video

## Phase 1 MVP Features (Complete)

1. Project management (CRUD, statistics)
2. Waypoint recording with GPS (auto-fill coordinates)
3. Multiple coordinate formats (Decimal, DMS, UTM)
4. Offline map with OpenTopoMap tiles
5. Offline tile region download
6. Field notes with text input
7. Voice-to-text transcription (offline)
8. Settings (units, formats, storage)

## Phase 2 Features (Current)

1. PhotoRepository and photo capture (#47, #46)
2. GPX export for waypoints (#48)
3. TrackRepository for GPS trails (#49)
4. Distance/bearing calculator (#50)
5. Compass heading display (#51)
6. Waypoint category picker (#52)
7. Onboarding flow (#53)
8. Locate me button on map (#54)
9. Local database backup (#55)
10. Dark mode support (#56)
11. Unified global search (#57)
12. Network status indicator (#58)
13. Undo and trash for deleted items (#59)
14. Navigate to waypoint (#63)

## Common Tasks

### Adding a New Model
1. Create model struct in `Core/Models/`
2. Add GRDB conformance (FetchableRecord, PersistableRecord)
3. Add migration in `Core/Database/Migrations/`
4. Create repository in `Core/Database/Repositories/`
5. Write unit tests

### Adding a New Feature
1. Create feature folder in `Features/`
2. Add Views/ and ViewModels/ subdirectories
3. Create ViewModel with @Observable
4. Create SwiftUI views
5. Add navigation in TabBarView or parent view
6. Write tests

### Working with Maps
- MapContainerView wraps MGLMapView via UIViewRepresentable
- Use OfflineMapService for tile downloads
- TileSourceManager configures OpenTopoMap source
- WaypointAnnotationView for custom markers
