# Tide Engine — Release Handoff

## Current state

The hardened v1 product is an iPhone app with an interactive gravitational visualization, NOAA predictions near supported stations, and a WidgetKit extension. The unsafe client-side WorldTides credential and mutable purchase-unlock path have been removed. There is no in-app purchase in this build.

## Verified locally

- XcodeGen project generation
- 49 unit tests on iPhone 17 Pro simulator
- Release build and unsigned archive
- Main and widget privacy manifests bundled
- Opaque 1024×1024 app icon
- Simulator launch and visual inspection
- Bundle IDs: `com.tideengine.app` and `com.tideengine.app.widget`
- App Group: `group.com.tideengine`

## Release-owner work still required

1. Confirm the bundle IDs and App Group in Apple Developer and App Store Connect.
2. Resolve signing/provisioning and run a signed archive plus Validate App.
3. Test Metal rendering, location states, NOAA data, offline cache, and both widgets on physical devices.
4. Confirm the App Store privacy label and metadata against `PRIVACY.md` and `APPSTORE-METADATA.md`.
5. Capture current screenshots and complete TestFlight review.

Do not restore a third-party global tide API key in the client. Any future paid global-data feature needs a server-verified entitlement and credential broker with its own privacy and operational review.
