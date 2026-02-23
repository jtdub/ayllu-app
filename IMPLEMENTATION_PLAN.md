# Ayllu Field Research Companion App - Implementation Plan

## Overview

Native iOS app for archaeological, anthropological, and ecological fieldwork. Built with Swift/SwiftUI for the best iOS experience. Replaces 4-5 separate tools (GPS, camera, notes, offline maps, export) with a single offline-first companion.

**Target Users:** Archaeologists, anthropologists, conservation biologists, CRM professionals, field researchers.
**Platform:** iOS 17+ only (iPhone and iPad)

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Language** | Swift 5.9+ | Native performance, best iOS integration |
| **UI** | SwiftUI | Modern declarative UI, iOS 17 features |
| **Architecture** | MVVM with @Observable | Simple, testable, SwiftUI-native |
| **Database** | GRDB.swift | Best SQLite wrapper — full SQL control, migrations, offline reliability |
| **Maps** | MapLibre Native iOS | Open source, excellent offline tile support, no usage costs |
| **State** | @Observable + @Environment | iOS 17 native, minimal boilerplate |
| **Voice STT** | SFSpeechRecognizer | On-device recognition, no network needed |
| **Coordinates** | Lat/Lon + UTM | Standard field research formats |
| **Min iOS** | 17.0 | Required for @Observable, good device coverage |

### Why GRDB.swift over SwiftData
- Full SQL control for spatial queries (bounding box, nearby waypoints)
- Reliable migration system for app updates in the field
- WAL mode for concurrent read/write
- No Apple lock-in — battle-tested in production
- SwiftData still has performance limitations for offline-heavy apps

### Why MapLibre over MapKit
- MapKit cannot reliably pre-cache offline regions
- MapLibre has MGLOfflineStorage for true offline tile packs
- Open source, no per-user costs
- Compatible with free tile servers (OpenTopoMap, etc.)

---

## Project Structure

```
Ayllu/
├── App/
│   ├── AylluApp.swift              # @main entry point
│   └── Info.plist                  # Permissions
│
├── Core/
│   ├── Database/
│   │   ├── DatabaseManager.swift   # GRDB setup, migrations
│   │   ├── Migrations/
│   │   │   └── Migration_v1.swift
│   │   └── Repositories/
│   │       ├── ProjectRepository.swift
│   │       ├── WaypointRepository.swift
│   │       ├── PhotoRepository.swift
│   │       ├── NoteRepository.swift
│   │       ├── TrackRepository.swift
│   │       └── MapRegionRepository.swift
│   │
│   ├── Models/
│   │   ├── Project.swift
│   │   ├── Waypoint.swift
│   │   ├── Photo.swift
│   │   ├── FieldNote.swift
│   │   ├── Track.swift
│   │   ├── TrackPoint.swift
│   │   └── MapRegion.swift
│   │
│   ├── Services/
│   │   ├── Location/
│   │   │   ├── LocationService.swift
│   │   │   └── CoordinateFormatter.swift
│   │   ├── Camera/
│   │   │   └── CameraService.swift
│   │   ├── Speech/
│   │   │   └── SpeechService.swift
│   │   ├── Maps/
│   │   │   ├── OfflineMapService.swift
│   │   │   └── TileSourceManager.swift
│   │   └── Export/
│   │       ├── GeoJSONExporter.swift
│   │       ├── GPXExporter.swift
│   │       └── KMLExporter.swift
│   │
│   └── Extensions/
│       └── CLLocation+Extensions.swift
│
├── Features/
│   ├── Projects/
│   │   ├── Views/
│   │   │   ├── ProjectListView.swift
│   │   │   ├── ProjectDetailView.swift
│   │   │   └── ProjectFormView.swift
│   │   └── ViewModels/
│   │       └── ProjectListViewModel.swift
│   │
│   ├── Waypoints/
│   │   ├── Views/
│   │   │   ├── WaypointListView.swift
│   │   │   ├── WaypointDetailView.swift
│   │   │   └── WaypointFormView.swift
│   │   └── ViewModels/
│   │       └── WaypointListViewModel.swift
│   │
│   ├── Notes/
│   │   ├── Views/
│   │   │   ├── NoteListView.swift
│   │   │   ├── NoteEditorView.swift
│   │   │   └── VoiceRecordingButton.swift
│   │   └── ViewModels/
│   │       └── NoteEditorViewModel.swift
│   │
│   ├── Map/
│   │   ├── Views/
│   │   │   ├── MapContainerView.swift
│   │   │   ├── OfflineRegionManagerView.swift
│   │   │   └── WaypointAnnotationView.swift
│   │   └── ViewModels/
│   │       └── MapViewModel.swift
│   │
│   └── Settings/
│       └── SettingsView.swift
│
├── Shared/
│   ├── TabBarView.swift
│   └── Styles/
│       └── Colors.swift
│
├── Resources/
│   └── Assets.xcassets
│
└── Tests/
    ├── AylluTests/
    │   ├── RepositoryTests/
    │   ├── ServiceTests/
    │   └── ViewModelTests/
    └── AylluUITests/
```

---

## Swift Package Dependencies

```swift
dependencies: [
    // Database
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),

    // Maps
    .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "6.0.0"),

    // Coordinate Transforms (UTM)
    .package(url: "https://github.com/wtw-software/UTMConversion.git", from: "1.0.0"),

    // GPX Export
    .package(url: "https://github.com/vincentneo/CoreGPX.git", from: "0.9.0"),

    // Snapshot Testing
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
]
```

---

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| **projects** | Research projects (name, description, dates) |
| **waypoints** | GPS points (lat/lon, altitude, accuracy, tags, custom fields) |
| **photos** | Geotagged images (file path, EXIF, caption) |
| **field_notes** | Text/voice notes (content, audio path, transcription) |
| **tracks** | GPS breadcrumb trails (Phase 2) |
| **track_points** | Individual GPS fixes in a track (Phase 2) |
| **map_regions** | Offline tile regions (bounds, zoom, download status) |

### Key Features
- Foreign keys with CASCADE delete
- Indexes on projectId, timestamp, lat/lon
- JSON columns for tags and custom fields
- WAL mode for concurrent access
- Migration system using GRDB's DatabaseMigrator

---

## Phase 1 Implementation Tasks

### 1. Xcode Project Setup
- [ ] Create new SwiftUI App project (iOS 17+)
- [ ] Add Swift Package dependencies
- [ ] Configure Info.plist permissions (Location, Camera, Microphone, Speech)
- [ ] Create folder structure
- [ ] Set up Git repository

### 2. Database Layer
- [ ] Implement DatabaseManager with GRDB pool
- [ ] Create Migration_v1 with full schema
- [ ] Implement ProjectRepository (CRUD + stats)
- [ ] Implement WaypointRepository (CRUD + spatial queries)
- [ ] Implement NoteRepository (CRUD)
- [ ] Implement MapRegionRepository (download management)
- [ ] Write unit tests for repositories

### 3. Core Models
- [ ] Define Project, Waypoint, FieldNote, MapRegion structs
- [ ] Implement GRDB FetchableRecord + PersistableRecord conformance
- [ ] Define associations (Project hasMany Waypoints, etc.)

### 4. GPS Service
- [ ] Implement LocationService (CLLocationManager wrapper)
- [ ] Handle permission flows (When In Use + Always)
- [ ] Implement CoordinateFormatter (Decimal, DMS, UTM)
- [ ] Write unit tests for coordinate formatting

### 5. Navigation & Tab Bar
- [ ] Create TabBarView (Projects, Map, Notes, Settings)
- [ ] Set up NavigationStack for each tab
- [ ] Inject database and services via @Environment

### 6. Project Management
- [ ] ProjectListView with search
- [ ] ProjectDetailView with stats (waypoint/note counts)
- [ ] ProjectFormView for create/edit
- [ ] ProjectListViewModel with @Observable

### 7. Waypoint CRUD
- [ ] WaypointListView with filters
- [ ] WaypointDetailView with coordinate display (all formats)
- [ ] WaypointFormView with auto-GPS fill
- [ ] Quick waypoint creation (one-tap from any screen)
- [ ] WaypointListViewModel with @Observable

### 8. Map Integration
- [ ] MapContainerView (UIViewRepresentable for MGLMapView)
- [ ] Configure OpenTopoMap tile source
- [ ] Display user location
- [ ] Add WaypointAnnotationView markers
- [ ] Tap marker to show details

### 9. Offline Tile Download
- [ ] OfflineMapService using MGLOfflineStorage
- [ ] OfflineRegionManagerView (list regions, download new)
- [ ] Download progress tracking
- [ ] Storage usage display

### 10. Field Notes
- [ ] NoteListView with search
- [ ] NoteEditorView with text input
- [ ] Link notes to waypoints
- [ ] NoteEditorViewModel

### 11. Voice-to-Text
- [ ] SpeechService using SFSpeechRecognizer
- [ ] On-device recognition (requiresOnDeviceRecognition = true)
- [ ] VoiceRecordingButton with animation
- [ ] Audio file saving (M4A)
- [ ] Live transcription display

### 12. Settings
- [ ] Coordinate format selector (Decimal / DMS / UTM)
- [ ] Distance unit selector (meters / feet)
- [ ] Storage management (clear tiles)
- [ ] About section

### 13. Testing
- [ ] Unit tests: Repositories, CoordinateFormatter, ViewModels
- [ ] UI tests: Project flow, Waypoint creation, Note creation
- [ ] 80%+ coverage on Core/ directory

### 14. Build Verification
- [ ] Clean build (Debug + Release)
- [ ] Run on iOS Simulator (iPhone 15 Pro)
- [ ] Run on physical device
- [ ] Verify all permissions work
- [ ] Verify offline map download
- [ ] Verify speech recognition offline

---

## Testing Strategy

| Layer | Tool | Coverage Target |
|-------|------|-----------------|
| Unit | XCTest | 90% on repositories, formatters |
| ViewModel | XCTest | 80% on state transitions |
| UI | XCUITest | Critical flows |
| Snapshot | swift-snapshot-testing | Key views |

---

## Build Verification Checklist

- [ ] `xcodebuild clean build` succeeds
- [ ] All unit tests pass
- [ ] All UI tests pass
- [ ] App launches on iOS 17 simulator
- [ ] App launches on physical device
- [ ] Location permission flow works
- [ ] Camera permission flow works
- [ ] Microphone permission flow works
- [ ] Speech recognition works **offline**
- [ ] Map loads with OpenTopoMap tiles
- [ ] Offline region downloads successfully
- [ ] Database persists after app restart
- [ ] Waypoints appear on map

---

## Phases Summary

| Phase | Focus | Key Deliverables |
|-------|-------|------------------|
| **1 (MVP)** | Foundation | Xcode setup, database, GPS, waypoints, map, offline tiles, notes, voice-to-text, tests |
| **2** | Core Features | Photo capture with EXIF, track recording, photo gallery, satellite layer, GPX/KML/GeoJSON export |
| **3** | Advanced | Photo annotation, GeoPackage export, custom tile layers, PDF reports, import, full-text search |
| **4** | Polish | iCloud sync (optional), iPad optimization, widgets, App Store submission |

---

## GitHub Issues

See the GitHub repository for all 30 Phase 1 issues with labels and dependencies.

### Labels
- `setup` — Project configuration
- `database` — GRDB schema and repositories
- `models` — Data models
- `gps` — Location services
- `maps` — MapLibre and offline tiles
- `offline` — Offline-first features
- `ui` — SwiftUI views
- `navigation` — App navigation
- `projects` — Project management
- `waypoints` — Waypoint features
- `notes` — Field notes
- `speech` — Voice-to-text
- `settings` — App settings
- `testing` — Tests
- `build` — Build verification
- `priority:high` — Critical path
