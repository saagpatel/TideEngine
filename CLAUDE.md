# Tide Engine

## Overview
Native iPhone app (SwiftUI + SceneKit + Metal, iOS 17+) rendering a real-time gravitational simulation of lunar and solar tidal forcing on a stylized dark globe. Tapping any coastline cuts to a local tide detail view powered by NOAA CO-OPS (US, free) or WorldTides API v3 (international, one-time IAP unlock).

## Tech Stack
- Swift 5.10+, SwiftUI iOS 17+, SceneKit (globe geometry/lighting), Metal (ocean surface heightfield shader)
- WidgetKit iOS 17+ (home screen widget), StoreKit 2 (one-time IAP), CoreLocation, URLSession, Keychain Services

## Development Conventions
- Swift strict concurrency: async/await throughout; use `@MainActor` for UI updates (not `DispatchQueue.main`)
- No third-party SPM packages — Apple frameworks only
- File naming: PascalCase for types/files, camelCase for functions/vars
- Unit tests for ephemeris accuracy and API response parsing before committing those modules
- Metal shaders live in `Shaders.metal`; no inline shader strings in Swift files
- All API calls wrapped in `do/catch` with user-facing error handling

## Architecture Constraints
- **Globe rendering split:** SceneKit owns geometry; Metal handles the texture shader only — do not move geometry into Metal
- **WorldTides API key:** store in iOS Keychain only — not UserDefaults, Info.plist, or source code
- **Widget data:** call NOAA or WorldTides APIs from the app target only; the widget extension reads shared cached data from UserDefaults
- **Target:** iPhone only — no adaptive layout for iPad until v2

## Key Decisions
| Decision | Choice | Why |
|---|---|---|
| Ephemeris | Meeus ELP2000/82 (Moon) + VSOP87 (Sun) | Fully offline, no external dependency, validatable |
| International data | WorldTides API v3 | Global coverage, per-user caching allowed, clean REST |
| Globe transition | Cut (0.4s camera zoom → hard cut) | Reliable, cinematic; morph was a UX risk |
| Visual language | Luminous dark — indigo/teal/white-hot gradient | Differentiates from every realistic tide app |
| Monetization | One-time IAP — US free (NOAA) / international paid (WorldTides) | No recurring billing friction |
| Widget | SwiftUI WidgetKit only — pull gauge + next tide time | WidgetKit does not support Metal or SceneKit |
| Credentials | WorldTides API key in iOS Keychain only | Never UserDefaults, never hardcoded |

See `IMPLEMENTATION-ROADMAP.md` for full phase details and `HANDOFF.md` for build stats and next steps.

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Tide Engine is a native iPhone app (SwiftUI + SceneKit + Metal, iOS 17+) that renders a real-time
gravitational simulation of lunar and solar tidal forcing on a stylized dark globe. Tapping any
coastline cuts to a local tide detail view powered by NOAA CO-OPS (US, free) or WorldTides API v3
(international, one-time IAP unlock). The app makes invisible gravitational physics viscerally visible.

## Current State

**Complete — all 4 phases shipped (v1.0)**
See HANDOFF.md for build stats (36 files, 4835 lines, 62 tests) and next steps.

## Stack

- Swift: 5.10+
- SwiftUI: iOS 17+ (declarative UI, WidgetKit, Charts)
- SceneKit: iOS 17+ (3D globe geometry, camera, lighting)
- Metal: iOS 17+ (custom ocean surface heightfield shader)
- WidgetKit: iOS 17+ (home screen widget)
- StoreKit 2: iOS 17+ (one-time IAP for international unlock)
- CoreLocation: iOS 17+ (user location for tide lookup)
- URLSession: built-in (NOAA + WorldTides API calls)
- Keychain Services: built-in (WorldTides API key storage)

## How To Run

Build and run the `TideEngine` scheme on a device or simulator.

## Known Risks

- Do not use Metal for the globe geometry — SceneKit handles geometry; Metal handles the texture shader only
- Do not store the WorldTides API key in UserDefaults, Info.plist, or source code — Keychain only
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not build for iPad — iPhone only, no adaptive layout work until v2
- Do not use DispatchQueue.main for UI updates — use @MainActor and Swift concurrency
- Do not call NOAA or WorldTides APIs from the widget extension — use shared cached data from UserDefaults

## Next Recommended Move

Physical device testing (Metal + Widget may differ from simulator), replace placeholder WorldTides API key, complete App Store Connect metadata (privacy policy, screenshots, privacy labels), and archive for App Store submission.

<!-- portfolio-context:end -->

<!-- secondbrain-breadcrumb -->
## SecondBrain knowledge vault

Prior lessons, decisions, and context for this project live in SecondBrain at `wiki/maps/projects/tide-engine.md`. The whole vault is searchable via the `engraph` MCP — query it for this project + its stack before non-trivial work.
