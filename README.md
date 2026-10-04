# Tide Engine

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> The ocean on your phone, physics and all

Tide Engine is an iOS tidal simulation app that pairs a real-time gravitational physics engine with live NOAA station data. Spin a 3D globe, tap any coastline, and see a physics-driven tidal breakdown alongside official tide predictions near supported NOAA stations.

## Features

- **Interactive 3D globe** — SceneKit-rendered Earth with a live tidal height field updating every 0.5 seconds as the Moon and Sun move
- **Custom ephemeris engine** — Moon position via Meeus ELP 2000/82 (truncated), Sun position via VSOP87; no third-party astronomy libraries
- **Local tide detail** — gravitational pull percentage, modeled surface displacement, Moon angle, a 7-day NOAA height chart, and upcoming high/low times
- **NOAA tide data** — fetches official predictions for locations less than 200 km from a supported NOAA station and caches them for offline reuse
- **Home screen widget** — small and medium WidgetKit widgets showing current gravitational pull gauge, with next tide time in the medium widget from shared App Group cache
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

The app bundle ID is `com.tideengine.TideEngine`; the widget uses
`com.tideengine.TideEngine.widget`. Both share `group.com.tideengine`.

## Verification

Run from the repository root on macOS with full Xcode selected, XcodeGen, and
an installed iOS Simulator runtime. `xcodebuild -version` and
`xcrun simctl list devices available` identify the local prerequisites.
The Makefile generates the Xcode project before building or testing:

```bash
make build
make test
make release
```

These targets disable signing. `make release` is an unsigned build, not a
deployment or App Store submission. The Makefile defaults to `iPhone 17 Pro`;
[CI](.github/workflows/ci.yml) uses `iPhone 17`. If the default is unavailable,
choose an installed compatible simulator, for example:

```bash
make test DESTINATION='platform=iOS Simulator,name=iPhone 17'
```

For focused XCTest changes, run `make project`, then use the same project/scheme
with XCTest's selector (substitute the changed test class):

```bash
xcodebuild test -project TideEngine.xcodeproj -scheme TideEngine \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TideEngineTests/EphemerisTests CODE_SIGNING_ALLOWED=NO
```

There is no separate lint, format, or typecheck target; Swift compilation and
XCTest are the maintained gates. Missing Xcode/runtime is an unavailable lane,
not a successful build. Use a disposable simulator for changed globe, tide
detail, or widget behavior; inspect the affected screen and accessibility.
NOAA requests, location permission, and App Group cache writes are runtime
effects, so use synthetic/mocked data for bounded verification and do not enable
personal location or replace existing simulator data as a smoke. This native
iOS UI has no browser verification lane or packaged offline UI fixture mode.
If safe synthetic data cannot be supplied, record that runtime UI lane as
unavailable and use the fixture-backed XCTest lane instead.

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

The tidal heightfield recomputes at ~2 Hz (every 0.5 s) via `SCNSceneRendererDelegate`'s `renderer(_:updateAtTime:)` callback, computing lunar and solar sub-body geographic coordinates and the tidal displacement field across a 32×64 latitude/longitude grid. A Metal compute shader upsamples this grid to a 512×256 color texture that drives the sphere's emission material in real time. NOAA prediction data is fetched on demand, decoded with `Codable`, and cached in App Group UserDefaults for sharing with the WidgetKit extension; the station list is cached in standard UserDefaults. The globe is an educational visualization; use official local guidance for navigation or safety decisions.

## License

MIT
