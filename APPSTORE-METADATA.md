# Tide Engine: App Store Connect Metadata Draft

This is a release-owner draft. Confirm the bundle ID, category, price, URLs, screenshots, and territory availability in App Store Connect before submission.

## Identity

| Field | Draft value |
|---|---|
| Name | Tide Engine |
| Subtitle | Gravity meets the ocean |
| Bundle ID | `com.tideengine.TideEngine` |
| SKU | `TIDEENGINE-001` |
| Primary category | Education |
| Secondary category | Weather |
| Age rating | Complete in App Store Connect |
| Price | Decide before release |

## Keywords

`ocean,sea,moon,sun,gravity,NOAA,coastal,chart,times,widget,globe,physics,education`

## Description

Tides are gravity made visible. Tide Engine turns the relationship between Earth, Moon, Sun, and ocean into an interactive 3D visualization.

Spin the globe and watch the tidal bulge track the Moon and Sun, recomputed from their calculated positions as you watch. Tap near a supported NOAA reference station and you get that station's hourly seven-day tide chart plus the upcoming highs and lows, shown in your device's time zone.

Two home-screen widgets keep your last station close by, with no network use of their own. The small one shows the modeled gravitational pull; the medium one adds the next high or low tide. Both say how long ago the predictions were fetched, and once they are more than two days old, or have no future tide, the widget asks you to open the app for fresh ones.

Features:

- A 3D globe driven by calculated lunar and solar positions
- NOAA predictions for points under 200 km from a supported NOAA reference station
- Hourly seven-day chart, upcoming highs and lows, station name and distance
- Optional one-tap location to find the station nearest you
- Small and medium home-screen widgets

No accounts, ads, or tracking.

The globe is an educational model of tidal forces, so do not rely on this app alone for navigation or safety.

## Promotional text

`A 3D globe of the Moon and Sun pulling on the ocean, updated live. Tap near a NOAA station for a seven-day tide chart and upcoming highs and lows.`

## URLs

- Support: https://github.com/saagpatel/TideEngine/issues
- Privacy: https://github.com/saagpatel/TideEngine/blob/main/PRIVACY.md

## App Review notes

Tide Engine makes unauthenticated HTTPS requests to `api.tidesandcurrents.noaa.gov` for station metadata and tide predictions. It does not send the device's precise coordinate to NOAA. The selected station identifier is sent in prediction requests. Location is optional. The arrow icon at the upper right has the accessibility label "Show tides near me"; tapping it requests location access and uses the coordinate on-device to select a station.

To test without location permission:

1. Launch the app. The globe screen reads "TIDE ENGINE" and "Gravity, made visible". Drag to rotate the globe.
2. With an internet connection, rotate to California and tap the coast near San Francisco Bay (approximately 37.8 N, 122.4 W). Taps use the sphere's local coordinates. There is no station search or coordinate-entry control in the app.
3. After the request succeeds, the detail view shows the station name, distance, and "Live NOAA" or "Cached". Look for "Gravitational Pull", "Surface Displacement", "Moon Angle", "7-Day Tide Heights", and "Tide Predictions". Scroll to see upcoming "High Tide" and "Low Tide" rows. The gravitational metrics are modeled, not measured water levels.
4. NOAA predictions are requested in GMT and parsed as UTC. The 168-hour range starts at today's UTC midnight, so it covers about six to seven days ahead. Displayed clock times use the device's time zone, which may differ from the station's. The app does not store station time zones. For a NOAA comparison, use GMT predictions and convert to the device's time zone.
5. After loading station predictions, add "Tide Engine" from the Home Screen widget gallery. The small widget shows a pull gauge and station name. The medium widget also shows "High" or "Low", relative time, and height. Both populated widgets show "Updated ... ago". The widget reads the last selected station's cache and makes no NOAA requests. At each scheduled entry, it accepts predictions fetched no more than 48 hours earlier only if a future tide remains. Without usable data, both sizes show "Open Tide Engine" and "to get started". Open the app and load station data again; iOS controls when the widget refreshes.

The globe and modeled metrics do not require a nearby station. NOAA predictions require a supported NOAA reference station less than 200 km from the selected point. Elsewhere, the detail view shows "Chart unavailable", "No data available", and a station-coverage error. Network failures can also prevent data from loading; the error banner includes "Retry". Cached results show "Cached" and "Cached data from ...". Offline results depend on previously saved station-list and prediction data; a first launch offline cannot load NOAA data.

For optional location testing, tap the arrow icon labeled "Show tides near me". A reviewer's location outside station coverage will not produce NOAA predictions. In a simulator, supply a simulated San Francisco location before using this button; an unset or unsupported simulated location does not demonstrate station coverage. If access is denied or a location cannot be obtained, expect "Location Unavailable" with "OK". Globe taps remain available without permission.

No reviewer account or in-app purchase is required.

## Screenshot plan

Capture the real app UI at **6.9-inch iPhone 1320x2868** portrait on **iPhone 18 Pro Max**. The app and widget target device family `1` (iPhone); no iPad set is planned. If the shipped app adds family `2`, also capture **13-inch iPad 2064x2752** portrait; that size is not part of the current script.

| n | State and caption | Device sizes | Capture |
|---|---|---|---|
| 1 | Globe screen: "TIDE ENGINE", "Gravity, made visible", and the modeled field. Caption: "Explore modeled tidal forces". | 6.9-inch iPhone, 1320x2868 portrait | Simulator |
| 2 | Loaded San Francisco station detail: station name, distance, model metrics, and "7-Day Tide Heights". Retain the real "Cached" badge. Caption: "NOAA predictions near supported stations". | 6.9-inch iPhone, 1320x2868 portrait | Simulator, deterministic fixture cache |
| 3 | Scrolled detail: "Tide Predictions", "High Tide" and "Low Tide" rows with fixture times and heights. Caption: "Tide times in your device's time zone". | 6.9-inch iPhone, 1320x2868 portrait | Simulator, deterministic fixture cache |

Run `bash scripts/capture-screenshots.sh` on the dispatcher's Mac with Xcode and the named simulator installed. It builds Debug once and launches `-AppStoreScreenshot 1`, `2`, and `3`; output is `screenshots/appstore/iphone-18-pro-max/01.png` through `03.png`. Before the first capture on each device, it launches shot 1, waits 2 seconds, and terminates the app so subsequent launches have no cross-app back link. Termination is tolerated when the app is not running. The default settling wait is 4 seconds; use `SHOT_WAIT` or per-shot `SHOT_WAIT_1`, `SHOT_WAIT_2`, `SHOT_WAIT_3` if the simulator needs longer. `DERIVED` overrides `.build/shots`. A missing or ambiguously named device or a pixel-size mismatch fails the script.

For these numbered app shots, this Debug capture procedure supersedes the older Release-build capture instruction in the checklist below.

Debug screenshot mode fixes the modeled field, clock, and relative labels at **2026-03-22 00:10 UTC**, with English text, UTC device display time, standard text size, and dark appearance. It uses an isolated in-memory station/prediction cache for NOAA station **9414290**, seeded from `TideAPITests`' San Francisco fixtures. The four hi/lo values repeat daily over seven days; hourly heights reuse the first four fixture values and interpolate between repeated extremes thereafter. This is synthetic fixture data, not a retained seven-day NOAA response or proof of a successful live request. Review this fixture provenance before uploading the resulting PNGs. Normal Release data loading is unchanged.

Home Screen widget screenshots are excluded: `simctl launch` cannot arrange or capture populated Home Screen widgets. No current numbered shot requires hardware unavailable to the simulator, so there are no `OPERATOR: capture on device` rows. Do not promise station-local times, global prediction coverage, automatic NOAA widget fetching, or a next tide in the small widget. Screenshots have not been captured in this worker pass.

## Release-owner checklist

- [ ] Confirm `com.tideengine.TideEngine`, `com.tideengine.TideEngine.widget`, and `group.com.tideengine` in Apple Developer and App Store Connect.
- [ ] Confirm distribution certificate and provisioning profiles; run a signed archive and Validate App.
- [ ] Confirm the privacy nutrition label matches `PRIVACY.md` and actual behavior.
- [ ] Capture the screenshot plan at 1320x2868 from the release build; add 2064x2752 iPad screenshots only if the shipped app includes device family `2`.
- [ ] Test location allow, deny, restricted, and Settings recovery paths on a physical device.
- [ ] Follow the no-permission San Francisco globe-tap review path on a device; confirm the selected station is near the tapped coast after rotating the globe.
- [ ] Compare representative predictions with NOAA GMT results converted to the device's time zone, including a device zone different from the station's.
- [ ] Verify first-launch offline errors and previously cached results, including station-list expiry; do not promise unconditional offline predictions.
- [ ] Test both widget sizes on a physical device: small gauge, medium next tide, update-age labels, and the empty state with missing or over-48-hour predictions. Allow for iOS refresh scheduling.
- [ ] Decide price, territories, category, age-rating answers, copyright, and support ownership.
- [ ] Complete TestFlight review before App Store submission.
