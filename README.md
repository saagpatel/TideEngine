# Tide Engine

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> The ocean on your phone, physics and all

Tide Engine is an iOS tidal simulation app that pairs a real-time gravitational physics engine with live NOAA station data. Spin a 3D globe, tap any coastline, and see a physics-driven tidal breakdown alongside official tide predictions.

## Features

- **Interactive 3D globe** — SceneKit-rendered Earth with a live tidal height field updating every 0.5 seconds as the Moon and Sun move
- **Custom ephemeris engine** — Moon position via Meeus ELP 2000/82 (truncated), Sun position via VSOP87; no third-party astronomy libraries
- **Local tide detail** — gravitational pull percentage, modeled surface displacement, Moon angle, a 7-day NOAA height chart, and upcoming high/low times
- **NOAA tide data** — fetches official predictions for locations within 200 km of a supported NOAA station and caches them for offline reuse
- **Home screen widget** — small and medium WidgetKit widgets showing current gravitational pull gauge and next tide time via shared App Group cache
- **Privacy-aware location** — location is requested only when you tap the location button and stays on-device while the app selects a NOAA station

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
| Data | NOAA CO-OPS REST API |
| Astronomy | Custom Meeus/VSOP87 ephemeris |
| Widget | WidgetKit + App Groups |
| Project config | XcodeGen |

## Architecture

The tidal heightfield recomputes at ~2 Hz (every 0.5 s) via `SCNSceneRendererDelegate`'s `renderer(_:updateAtTime:)` callback, computing lunar and solar unit vectors and the tidal potential field across a 64×32 latitude/longitude grid. A Metal compute shader upsamples this grid to a 512×256 color texture that drives the sphere's emission material in real time. NOAA data is fetched on demand, decoded with `Codable`, and cached in App Group UserDefaults for sharing with the WidgetKit extension. The globe is an educational visualization; use official local guidance for navigation or safety decisions.

## License

MIT
