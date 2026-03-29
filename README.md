![Swift](https://img.shields.io/badge/Swift-5.10-orange?logo=swift) ![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue?logo=apple) ![License](https://img.shields.io/badge/license-MIT-green)

# Tide Engine

A tidal simulation app for iPhone that combines real-time gravitational physics with live NOAA station data. Spin an interactive 3D globe, tap any coastline, and get a physics-driven tidal breakdown for that location alongside official tide predictions.

## Features

- **Interactive 3D Globe** — SceneKit-rendered Earth with coastline data and a live tidal height field derived from real-time lunar and solar positions. The height field updates every 0.5 seconds as the Moon and Sun move.
- **Gravitational physics engine** — Moon position computed using Meeus ELP 2000/82 (truncated), Sun position via VSOP87 truncated series. No third-party astronomy libraries.
- **Local tide detail view** — Tap any point on the globe to see gravitational pull percentage, surface displacement, Moon angle, a 7-day tide height chart, and upcoming high/low predictions.
- **NOAA + WorldTides data** — Fetches tide predictions from NOAA CO-OPS (US stations) with WorldTides as a fallback for international locations. Predictions are cached on-device for 24 hours.
- **Home Screen Widget** — Small and medium WidgetKit widgets showing current gravitational pull gauge and next tide time/height. Widget uses the shared App Group cache so no network call is needed.
- **In-App Purchase** — International tide data (WorldTides) is an optional unlock via StoreKit 2.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.10, strict concurrency |
| UI | SwiftUI, SceneKit (globe), Metal (height field shader) |
| Data | NOAA CO-OPS REST API, WorldTides API |
| Astronomy | Custom Meeus/VSOP87 ephemeris (no external deps) |
| Widget | WidgetKit, App Groups shared cache |
| Payments | StoreKit 2 |
| Tooling | XcodeGen (`project.yml`) |

## Prerequisites

- Xcode 15.4 or later
- iOS 17.0+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A free [NOAA CO-OPS](https://api.tidesandcurrents.noaa.gov/) API key is not required for US stations
- Optional: WorldTides API key for international data (set via environment or config)

## Getting Started

```bash
# 1. Clone
git clone https://github.com/saagpatel/TideEngine.git
cd TideEngine

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode
open TideEngine.xcodeproj
```

Build and run the **TideEngine** scheme on a simulator or device. The globe loads immediately; tide predictions require a network connection on first launch and are cached thereafter.

## Project Structure

```
TideEngine/
├── TideEngine/
│   ├── App/                  # App entry point, ContentView
│   ├── Ephemeris/            # Moon (ELP 2000/82) + Sun (VSOP87) position engine
│   ├── Globe/                # SceneKit globe, Metal height field renderer, coastline data
│   ├── LocalTide/            # Detail view: gravitational pull, tide chart, predictions
│   ├── Location/             # CoreLocation manager, coastline resolver
│   ├── Tides/                # NOAA + WorldTides API clients, data service, cache
│   └── Paywall/              # StoreKit 2 IAP, paywall UI, Keychain helper
├── TideEngineWidget/         # WidgetKit extension (small + medium)
├── TideEngineTests/          # Unit tests (ephemeris, tide API, Phase 3 scenarios)
└── project.yml               # XcodeGen project spec
```

## Screenshots

<!-- Add screenshots here -->
| Globe | Local Tide | Widget |
|-------|-----------|--------|
| _coming soon_ | _coming soon_ | _coming soon_ |

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright (c) 2026 Saag Patel
