# Ayllu

**Offline-first field research companion for iOS**

Ayllu replaces 4-5 separate tools (GPS, camera, notes, offline maps, data export) with a single app designed for archaeological, anthropological, and ecological fieldwork.

## Features

- **Project Management** - Organize fieldwork by project with statistics and date tracking
- **GPS Waypoints** - Record locations with automatic coordinate capture, categories, and custom tags
- **Multiple Coordinate Formats** - Decimal degrees, DMS, and UTM with one-tap copying
- **Offline Maps** - Download map regions for use without connectivity (OpenTopoMap tiles)
- **Field Notes** - Text notes linked to projects and waypoints
- **Voice Transcription** - On-device speech-to-text for hands-free note taking
- **Offline-First** - All core features work without network connectivity

## Requirements

- iOS 17.0+
- iPhone or iPad

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/jtdub/ayllu-app.git
   cd ayllu-app
   ```

2. Open in Xcode:
   ```bash
   open Ayllu.xcodeproj
   ```

3. Build and run on your device or simulator (iOS 17+)

## Architecture

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Architecture | MVVM with @Observable |
| Database | GRDB.swift (SQLite) |
| Maps | MapLibre Native iOS |
| Voice | SFSpeechRecognizer (on-device) |

## Project Structure

```
Ayllu/
├── App/                 # Entry point
├── Core/
│   ├── Database/        # GRDB setup, migrations, repositories
│   ├── Models/          # Data models
│   ├── Services/        # Location, Speech, Maps
│   └── Extensions/      # Swift extensions
├── Features/
│   ├── Projects/        # Project management
│   ├── Waypoints/       # GPS waypoint recording
│   ├── Notes/           # Field notes
│   ├── Map/             # MapLibre integration
│   └── Settings/        # App settings
└── Shared/              # Common UI components
```

## Development

Build the project:
```bash
xcodebuild -project Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator build
```

Run tests:
```bash
xcodebuild test -project Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Roadmap

See [GitHub Milestones](https://github.com/jtdub/ayllu-app/milestones) for planned features:

- **Phase 2: Polish** - Photos, GPX export, navigation, UX improvements
- **Phase 3: Pro Features** - Custom forms, hierarchical data, polygons
- **Phase 4: Advanced** - Team collaboration, 3D scanning, video

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Issues and feature requests: [GitHub Issues](https://github.com/jtdub/ayllu-app/issues)

## License

MIT License - see [LICENSE](LICENSE) for details.

## About

**Ayllu** (Quechua: community, kinship group) reflects the collaborative nature of field research and the communities we work with and study.
