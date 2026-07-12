# Tide Engine

Native iPhone app using SwiftUI, SceneKit, Metal, WidgetKit, CoreLocation, and NOAA Tides and Currents.

## Product boundary

- The globe is an educational gravitational visualization.
- Live predictions are available only near supported NOAA stations.
- Location is optional, user-initiated, and used on-device to select a NOAA station.
- The app has no accounts, analytics, advertising, tracking, subscriptions, or in-app purchases.
- The widget reads shared cached data; it does not call NOAA directly.

## Engineering constraints

- Generate the project with `xcodegen generate`; do not hand-edit the generated project as the source of truth.
- Keep SceneKit responsible for geometry and Metal responsible for the height-field texture.
- Keep UI state on `@MainActor` and preserve strict-concurrency builds.
- Construct NOAA requests with `URLComponents`, use HTTPS, and retain timeouts and response-size limits.
- Keep bundle IDs, App Group entitlements, privacy manifests, metadata, and runtime behavior aligned.
- Never embed a paid third-party API credential or trust a client-writable purchase flag.

## Commands

- `make test`
- `make release`
- `make archive`

See `HANDOFF.md` for verified release posture and remaining owner actions. `IMPLEMENTATION-ROADMAP.md` is historical design material, not current product truth.
