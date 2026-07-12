# Tide Engine — App Store Connect Metadata Draft

This is a release-owner draft. Confirm the bundle ID, category, price, URLs, screenshots, and territory availability in App Store Connect before submission.

## Identity

| Field | Draft value |
|---|---|
| Name | Tide Engine |
| Subtitle | Gravity meets the ocean |
| Bundle ID | `com.tideengine.app` |
| SKU | `TIDEENGINE-001` |
| Primary category | Education |
| Secondary category | Weather |
| Age rating | Complete in App Store Connect |
| Price | Decide before release |

## Keywords

`tides,ocean,moon,gravity,simulation,NOAA,coastal,high tide,low tide,globe`

## Description

Tides are gravity made visible. Tide Engine turns the relationship between Earth, Moon, Sun, and ocean into an interactive 3D visualization.

Spin the globe to explore a live modeled tidal-force field. For supported U.S. coastal regions, request official seven-day high, low, and hourly tide predictions from NOAA Tides and Currents. A home-screen widget keeps recent station data and the current modeled tidal-force gauge close at hand.

Features:

- Interactive SceneKit globe with a Metal-rendered tidal-force texture
- Custom lunar and solar ephemeris calculations
- NOAA tide predictions near supported stations
- Seven-day chart, upcoming high and low times, and station details
- Optional, user-initiated location lookup
- Small and medium home-screen widgets
- No accounts, advertising, analytics, tracking, or subscriptions

The gravitational display is an educational model. Tide predictions come from NOAA. Do not use Tide Engine as the sole source for navigation or safety decisions.

## Promotional text

`Explore a live gravitational tide visualization and NOAA predictions near supported U.S. stations.`

## URLs

- Support: https://github.com/saagpatel/TideEngine/issues
- Privacy: https://github.com/saagpatel/TideEngine/blob/main/PRIVACY.md

## App Review notes

Tide Engine makes unauthenticated HTTPS requests to `api.tidesandcurrents.noaa.gov` for station metadata and tide predictions. It does not send the device's precise coordinate to NOAA. Location is optional and requested only after the reviewer taps the location button; the coordinate is used on-device to select a nearby NOAA station.

To test without location permission:

1. Launch the app and interact with the globe.
2. Tap a U.S. coastline near a NOAA-supported station.
3. Verify the local view shows NOAA station data and a seven-day chart.
4. Add the small or medium Tide Engine widget and verify it renders.

No reviewer account or in-app purchase is required.

## Release-owner checklist

- [ ] Confirm `com.tideengine.app`, `com.tideengine.app.widget`, and `group.com.tideengine` in Apple Developer and App Store Connect.
- [ ] Confirm distribution certificate and provisioning profiles; run a signed archive and Validate App.
- [ ] Confirm the privacy nutrition label matches `PRIVACY.md` and actual behavior.
- [ ] Capture the currently required iPhone screenshots from the release build.
- [ ] Test location allow, deny, restricted, and Settings recovery paths on a physical device.
- [ ] Compare representative station results with NOAA and verify offline cache behavior.
- [ ] Test both widget sizes on a physical device.
- [ ] Decide price, territories, category, age-rating answers, copyright, and support ownership.
- [ ] Complete TestFlight review before App Store submission.
