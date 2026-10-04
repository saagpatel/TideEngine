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

`tides,ocean,moon,gravity,simulation,NOAA,coastal,high tide,low tide,globe`

## Description

Tides are gravity made visible. Tide Engine turns the relationship between Earth, Moon, Sun, and ocean into an interactive 3D visualization.

Spin the globe to explore a changing model of tidal forces. Tap near a supported U.S. NOAA station to see a seven-day tide-height chart and upcoming high and low predictions. Times are shown in your device's time zone.

Home-screen widgets use station predictions saved by the app. The small widget shows modeled gravitational pull. The medium widget adds the next predicted tide. Both show the age of the saved predictions. If those predictions are more than 48 hours old or contain no future tide, new widget entries ask you to open the app. iOS controls refresh timing. Open the app to load station data.

Features:

- Interactive 3D globe driven by lunar and solar calculations
- NOAA predictions less than 200 km from a supported station
- Seven-day chart, upcoming high and low times in your device's time zone, and station name and distance
- Optional, user-initiated location lookup
- Small and medium home-screen widgets
- No accounts, advertising, analytics, tracking, or subscriptions

The gravitational display is an educational model. Tide predictions come from NOAA. Do not use Tide Engine as the sole source for navigation or safety decisions.

## Promotional text

`Spin the globe to explore modeled tidal forces. See NOAA tide predictions near supported U.S. stations, with times in your device's time zone.`

## URLs

- Support: https://github.com/saagpatel/TideEngine/issues
- Privacy: https://github.com/saagpatel/TideEngine/blob/main/PRIVACY.md

## App Review notes

Tide Engine makes unauthenticated HTTPS requests to `api.tidesandcurrents.noaa.gov` for station metadata and tide predictions. It does not send the device's precise coordinate to NOAA. The selected station identifier is sent in prediction requests. Location is optional. The arrow icon at the upper right has the accessibility label "Show tides near me"; tapping it requests location access and uses the coordinate on-device to select a station.

To test without location permission:

1. Launch the app. The globe screen reads "TIDE ENGINE" and "Gravity, made visible". Drag to rotate the globe.
2. With an internet connection, rotate to California and tap the coast near San Francisco Bay (approximately 37.8 N, 122.4 W). Taps use the sphere's local coordinates. There is no station search or coordinate-entry control in the app.
3. After the request succeeds, the detail view shows the station name, distance, and "Live NOAA" or "Cached". Look for "Gravitational Pull", "Surface Displacement", "Moon Angle", "7-Day Tide Heights", and "Tide Predictions". Scroll to see upcoming "High Tide" and "Low Tide" rows. The gravitational metrics are modeled, not measured water levels.
4. NOAA predictions are requested in GMT and parsed as UTC. Displayed clock times use the device's time zone, which may differ from the station's. The app does not store station time zones. For a NOAA comparison, use GMT predictions and convert to the device's time zone.
5. After loading station predictions, add "Tide Engine" from the Home Screen widget gallery. The small widget shows a pull gauge and station name. The medium widget also shows "High" or "Low", relative time, and height. Both populated widgets show "Updated ... ago". The widget reads the last selected station's cache and makes no NOAA requests. At each scheduled entry, it accepts predictions fetched no more than 48 hours earlier only if a future tide remains. Without usable data, both sizes show "Open Tide Engine" and "to get started". Open the app and load station data again; iOS controls when the widget refreshes.

The globe and modeled metrics do not require a nearby station. NOAA predictions require a supported reference station less than 200 km from the selected point. Elsewhere, the detail view shows "Chart unavailable", "No data available", and "NOAA tide predictions are currently available near supported U.S. stations only". Network failures can also prevent data from loading; the error banner includes "Retry". Cached results show "Cached" and "Cached data from ...". Offline results depend on previously saved station-list and prediction data; a first launch offline cannot load NOAA data.

For optional location testing, tap the arrow icon labeled "Show tides near me". A reviewer's location outside station coverage will not produce NOAA predictions. In a simulator, supply a simulated San Francisco location before using this button; an unset or unsupported simulated location does not demonstrate station coverage. If access is denied or a location cannot be obtained, expect "Location Unavailable" with "OK". Globe taps remain available without permission.

No reviewer account or in-app purchase is required.

## Screenshot plan

Capture the actual release UI at **6.9-inch iPhone 1320x2868** portrait. The app and widget target device family `1` (iPhone); no iPad set is planned. If the shipped app adds family `2`, also capture **13-inch iPad 2064x2752** portrait.

1. Globe screen: "TIDE ENGINE", "Gravity, made visible", and the modeled field. Caption: "Explore modeled tidal forces".
2. Loaded station detail: station name, distance, model metrics, and "7-Day Tide Heights". Use a successful NOAA request and retain the actual "Live NOAA" or "Cached" badge. Caption: "NOAA predictions near supported stations".
3. Scrolled detail: "Tide Predictions", "High Tide" and "Low Tide" rows with actual times and heights. Caption: "Tide times in your device's time zone".
4. Home Screen with populated small and medium widgets: gauge, station name, and update-age labels; the next tide appears only in the medium widget. Caption: "Cached station data, with its update age".

Do not substitute placeholder data or promise station-local times, global prediction coverage, automatic NOAA widget fetching, or a next tide in the small widget. Capture loaded states only after real data is available. Screenshots have not been captured in this copy pass.

## Release-owner checklist

- [ ] Confirm `com.tideengine.TideEngine`, `com.tideengine.TideEngine.widget`, and `group.com.tideengine.TideEngine` in Apple Developer and App Store Connect.
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
