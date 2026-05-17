# Tide Engine

## Overview
Tide Engine is a native iPhone app (SwiftUI + SceneKit + Metal, iOS 17+) that renders a real-time
gravitational simulation of lunar and solar tidal forcing on a stylized dark globe. Tapping any
coastline cuts to a local tide detail view powered by NOAA CO-OPS (US, free) or WorldTides API v3
(international, one-time IAP unlock). The app makes invisible gravitational physics viscerally visible.

## Tech Stack
- Swift: 5.10+
- SwiftUI: iOS 17+ (declarative UI, WidgetKit, Charts)
- SceneKit: iOS 17+ (3D globe geometry, camera, lighting)
- Metal: iOS 17+ (custom ocean surface heightfield shader)
- WidgetKit: iOS 17+ (home screen widget)
- StoreKit 2: iOS 17+ (one-time IAP for international unlock)
- CoreLocation: iOS 17+ (user location for tide lookup)
- URLSession: built-in (NOAA + WorldTides API calls)
- Keychain Services: built-in (WorldTides API key storage)

## Development Conventions
- Swift strict concurrency: async/await throughout, no DispatchQueue unless required by SceneKit/Metal
- No third-party SPM packages — all dependencies are Apple frameworks
- File naming: PascalCase for types and files, camelCase for functions/vars
- Unit tests for ephemeris accuracy and API response parsing before committing those modules
- Metal shaders live in Shaders.metal; no inline shader strings in Swift files
- All API calls wrapped in do/catch with user-facing error handling (no silent failures)

## Current Phase
**Phase 0: Foundation + Metal Shader Proof**
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and verification checklist.

## Key Decisions
| Decision | Choice | Why |
|---|---|---|
| Ephemeris | Pure-Swift VSOP87 truncated | Fully offline, no external dependency, validatable |
| International data | WorldTides API v3 | Global coverage, per-user caching allowed, clean REST |
| Globe transition | Cut (0.4s camera zoom → hard cut) | Reliable, cinematic; morph was a UX risk |
| Visual language | Luminous dark — indigo/teal/white-hot gradient | Differentiates from every realistic tide app |
| Monetization | One-time IAP — US free (NOAA) / international paid (WorldTides) | No recurring billing friction |
| Widget | SwiftUI WidgetKit only — pull gauge + next tide time | WidgetKit does not support Metal or SceneKit |
| Credentials | WorldTides API key in iOS Keychain only | Never UserDefaults, never hardcoded |

## Do NOT
- Do not use Metal for the globe geometry — SceneKit handles geometry; Metal handles the texture shader only
- Do not store the WorldTides API key in UserDefaults, Info.plist, or source code — Keychain only
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not build for iPad — iPhone only, no adaptive layout work until v2
- Do not use DispatchQueue.main for UI updates — use @MainActor and Swift concurrency
- Do not call NOAA or WorldTides APIs from the widget extension — use shared cached data from UserDefaults

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Tide Engine is a native iPhone app (SwiftUI + SceneKit + Metal, iOS 17+) that renders a real-time
gravitational simulation of lunar and solar tidal forcing on a stylized dark globe. Tapping any
coastline cuts to a local tide detail view powered by NOAA CO-OPS (US, free) or WorldTides API v3
(international, one-time IAP unlock). The app makes invisible gravitational physics viscerally visible.

## Current State

**Phase 0: Foundation + Metal Shader Proof**
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and verification checklist.

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

Finish the Phase 0 foundation and Metal shader proof from `IMPLEMENTATION-ROADMAP.md`, then verify SceneKit geometry, Metal heightfield rendering, NOAA/WorldTides caching, and WidgetKit shared-data boundaries before adding later features.

<!-- portfolio-context:end -->
