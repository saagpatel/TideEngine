# Tide Engine — Session Handoff

## Status: Complete (v1.0 feature-complete)

## Branch: `main` (merged from `feat/phase0-foundation-metal-shader`)

## Completed This Session

All 4 phases built from scratch in a single session:

- **Phase 0**: Meeus ELP2000/82 Moon + VSOP87 Sun ephemeris, Metal compute shader (bilinear interp + tidal gradient), SceneKit globe
- **Phase 1**: 60fps animation via SCNSceneRendererDelegate, GMST-driven rotation + contentsTransform counter-rotation, 1180-vertex Natural Earth coastlines, tap→CoastlineResolver→LocalTideView
- **Phase 2**: NOAAClient (station lookup via Haversine, hi/lo + hourly predictions), TideCache (App Group UserDefaults, 24h expiry), TideChartView (Swift Charts 7-day curve), LocationManager (first-launch auto-nav)
- **Phase 3**: WidgetKit (real timeline with ephemeris pull + cached predictions), StoreKit 2 IAP ($2.99 one-time), WorldTidesClient (API v3, Keychain-stored key), PaywallView, NOAA→WorldTides routing at 200km threshold

**Stats**: 36 files changed, 4835 lines, 62 tests (23 ephemeris + 18 tide API + 21 Phase 3), BUILD SUCCEEDED

## In Progress: None

## Blocked: None

## Next Steps

1. **Physical device testing** — Metal + Widget behavior may differ from simulator
2. **Verify contentsTransform sign** — DEBUG log prints GMST on first frame; check if tidal bulge stays fixed
3. **Replace placeholder API key** — XOR-encode real WorldTides key in StoreManager.provisionWorldTidesKey()
4. **App Store Connect** — privacy policy URL, metadata, screenshots, privacy labels, archive validation
5. **Delete feature branch** — `git branch -d feat/phase0-foundation-metal-shader`

## Key Decisions

| Decision | Choice | Why |
|---|---|---|
| Moon ephemeris | Meeus ELP2000/82 (not VSOP87) | VSOP87 has no lunar series — roadmap was wrong |
| Earth rotation | Approach B: rotate sphere + contentsTransform | Continents ride as children, texture stays fixed |
| Tidal field update rate | 0.5s throttle (not 60fps) | Moon moves 0.5°/hour — 60fps recomputation is waste |
| NOAA data | Two concurrent requests (hilo + hourly) | Smooth chart curve without interpolation artifacts |
| US/International detection | Haversine distance > 200km from nearest NOAA station | Simple, no hardcoded boundary data |
| Widget data | Cache-only, no API calls | WidgetKit best practice, ephemeris computed offline |
| API key storage | Keychain with obfuscated provisioning after purchase | CLAUDE.md: never in UserDefaults/plist/source |
