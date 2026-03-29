# Tide Engine

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> The ocean on your phone, physics and all

Tide Engine is an iOS tidal simulation app that pairs a real-time gravitational physics engine with live NOAA station data. Spin a 3D globe, tap any coastline, and see a physics-driven tidal breakdown alongside official tide predictions.

## Features

- **Interactive 3D globe** — SceneKit-rendered Earth with a live tidal height field updating every 0.5 seconds as the Moon and Sun move
- **Custom ephemeris engine** — Moon position via Meeus ELP 2000/82 (truncated), Sun position via VSOP87; no third-party astronomy libraries
- **Local tide detail** — gravitational pull percentage, surface displacement, Moon angle, a 7-day height chart, and upcoming high/low times
- **NOAA + WorldTides data** — fetches official predictions from NOAA CO-OPS for US stations; WorldTides as international fallback, cached 24 hours on-device
- **Home screen widget** — small and medium WidgetKit widgets showing current gravitational pull gauge and next tide time via shared App Group cache
- **In-app purchase** — international WorldTides data as an optional StoreKit 2 unlock

## Quick Start

### Prerequisites
- Xcode 16+
- iOS 17.0+ device or simulator
- XcodeGen: `brew install xcodegen`

### Installation
```bash
git clone https://github.com/saagpatel/TideEngine
cd TideEngine
xcodegen generate
open TideEngine.xcodeproj
```

### Usage
Build and run the `TideEngine` scheme on a device or simulator.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 5.10, strict concurrency |
| UI | SwiftUI + SceneKit (globe) + Metal (height field shader) |
| Data | NOAA CO-OPS REST API, WorldTides API |
| Astronomy | Custom Meeus/VSOP87 ephemeris |
| Widget | WidgetKit + App Groups |
| Payments | StoreKit 2 |
| Project config | XcodeGen |

## Architecture

The physics engine runs on a dedicated `Task` at 2 Hz, computing lunar and solar unit vectors and the tidal potential field across a 64×32 latitude/longitude grid. The Metal shader reads this grid as a texture and displaces the globe mesh vertices in real time. NOAA data is fetched lazily on coastline tap, decoded with a custom `Codable` pipeline, and cached in App Group UserDefaults for sharing with the WidgetKit extension.

## License

MIT