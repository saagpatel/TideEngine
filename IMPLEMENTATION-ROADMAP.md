# Tide Engine — Implementation Roadmap

## Architecture

### System Overview
```
[Pure-Swift Ephemeris (VSOP87)] → [TidalForce Calculator] → [HeightField Texture Buffer (64×32 Float)]
                                                                          ↓
                                                          [Metal Compute Shader → MTLTexture 512×256]
                                                                          ↓
                                                          [SceneKit Globe (SCNSphere, 128 segments)]
                                                                          ↓
                                                              [SwiftUI ContentView / GlobeView]
                                                              ↓                        ↓
                                               [Tap → CoastlineResolver]      [WidgetKit Extension]
                                                              ↓                        ↓
                                                   [LocationManager]         [Shared UserDefaults cache]
                                                   ↓             ↓
                                        [NOAAClient]    [WorldTidesClient]
                                        (US free)       (International, behind IAP)
                                                   ↓             ↓
                                              [TideCache (UserDefaults, 24h expiry)]
                                                              ↓
                                                     [LocalTideView (SwiftUI)]
                                                     [TideChartView (Swift Charts)]
```

### File Structure
```
TideEngine/
├── TideEngine.xcodeproj/
├── TideEngine/
│   ├── App/
│   │   ├── TideEngineApp.swift            # @main SwiftUI app entry point
│   │   └── ContentView.swift              # Root view; hosts GlobeView, handles navigation
│   ├── Globe/
│   │   ├── GlobeView.swift                # SwiftUI UIViewRepresentable wrapping SCNView
│   │   ├── GlobeScene.swift               # SCNScene setup: sphere, lighting, continent overlay
│   │   ├── HeightFieldRenderer.swift      # Metal pipeline setup; writes MTLTexture from heightfield
│   │   └── Shaders.metal                  # Ocean surface heightfield compute shader
│   ├── Ephemeris/
│   │   ├── Ephemeris.swift                # VSOP87 truncated: Moon + Sun ecliptic coordinates
│   │   └── TidalForce.swift               # Tidal forcing → 64×32 normalized heightfield
│   ├── Tides/
│   │   ├── NOAAClient.swift               # NOAA CO-OPS API client (US stations)
│   │   ├── WorldTidesClient.swift         # WorldTides API v3 client (international)
│   │   ├── TideCache.swift                # UserDefaults-backed 24h prediction cache
│   │   └── TideModels.swift               # Shared structs: TidePrediction, TideStation, etc.
│   ├── Location/
│   │   ├── LocationManager.swift          # CoreLocation wrapper, async location fetch
│   │   └── CoastlineResolver.swift        # SCNHitTestResult → geographic lat/lon
│   ├── Paywall/
│   │   ├── StoreManager.swift             # StoreKit 2: purchase + restore for international unlock
│   │   └── PaywallView.swift              # International unlock UI
│   ├── LocalTide/
│   │   ├── LocalTideView.swift            # Post-cut tide detail screen (station name, chart, next tide)
│   │   └── TideChartView.swift            # Swift Charts: 7-day tide height curve
│   └── Resources/
│       ├── Assets.xcassets                # Colors, app icon
│       └── Info.plist                     # NSLocationWhenInUseUsageDescription required
├── TideEngineWidget/
│   ├── TideWidget.swift                   # TimelineProvider: 48 entries spanning 24 hours
│   ├── TideWidgetView.swift               # SwiftUI: Gauge (pull strength) + next tide card
│   └── TideWidgetBundle.swift             # Widget bundle entry point
└── TideEngineTests/
    ├── EphemerisTests.swift               # Lunar/solar position accuracy vs JPL reference values
    └── TideAPITests.swift                 # NOAA + WorldTides JSON parsing with fixture data
```

### Swift Type Definitions

```swift
// MARK: - Ephemeris

struct CelestialPosition {
    let body: CelestialBody
    let eclipticLongitude: Double   // degrees [0, 360)
    let eclipticLatitude: Double    // degrees [-90, 90]
    let distanceAU: Double          // astronomical units
    let timestamp: Date
}

enum CelestialBody {
    case moon
    case sun
}

// MARK: - Tidal Force

struct TidalForceField {
    let timestamp: Date
    // Row-major [latitude][longitude], 64 cols × 32 rows
    // latitude index 0 = -90°, 31 = +90° (step 5.625°)
    // longitude index 0 = 0°, 63 = 354.375° (step 5.625°)
    let heightField: [[Float]]      // values in [-1.0, 1.0]
    let maxDisplacementMeters: Double
}

// MARK: - Tide Data

enum TideType: String, Codable {
    case high = "H"
    case low = "L"
}

enum DataSource: String, Codable {
    case noaa
    case worldTides
}

struct TideStation: Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let dataSource: DataSource
}

struct TidePrediction: Codable {
    let timestamp: Date
    let heightMeters: Double
    let type: TideType
    let station: TideStation
}

struct CachedTideData: Codable {
    let stationId: String
    let predictions: [TidePrediction]
    let fetchedAt: Date
    let expiresAt: Date             // fetchedAt + 86400 seconds (24 hours)
}

// MARK: - NOAA API Response

struct NOAAResponse: Codable {
    let predictions: [NOAAPrediction]
}

struct NOAAPrediction: Codable {
    let t: String                   // "2026-03-22 06:14"
    let v: String                   // height as string, e.g. "1.234"
    let type: String                // "H" or "L"
}

// MARK: - WorldTides API Response

struct WorldTidesResponse: Codable {
    let status: Int
    let extremes: [WorldTidesExtreme]
}

struct WorldTidesExtreme: Codable {
    let dt: Int                     // Unix timestamp
    let height: Double
    let type: String                // "High" or "Low"
}

// MARK: - Widget Timeline Entry

struct TideWidgetEntry: TimelineEntry {
    let date: Date
    let gravitationalPullPercent: Int   // 0–100
    let nextTide: TidePrediction?
    let stationName: String
}
```

### API Contracts

**External APIs:**

| Service | Endpoint Pattern | Method | Auth | Rate Limit | Purpose |
|---|---|---|---|---|---|
| NOAA Predictions | `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&datum=MLLW&time_zone=lst_ldt&interval=hilo&units=metric&format=json&begin_date={YYYYMMDD}&range=168&station={stationId}` | GET | None | ~1000/day (unauthenticated) | 7-day high/low predictions |
| NOAA Station List | `https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions&units=english` | GET | None | Cache 30 days | All harmonic prediction stations |
| WorldTides v3 | `https://www.worldtides.info/api/v3?extremes&lat={lat}&lon={lon}&length=604800&key={apiKey}` | GET | API key (query param, from Keychain) | Credit-based: 1 credit per call | 7-day international extremes |

**Error handling:**
- NOAA: HTTP 200 with `{"error": {"message": "..."}}` on data errors — check for `error` key before parsing `predictions`
- WorldTides: `status != 200` in response body indicates error — surface `message` field to user
- Both: wrap all calls in `do/catch`; on failure, check cache for stale data and show it with "Data may be outdated" banner

### Dependencies

```bash
# No SPM packages required. All dependencies are Apple frameworks bundled with iOS 17 SDK:
# SwiftUI, SceneKit, Metal, MetalKit, WidgetKit, StoreKit, CoreLocation, MapKit,
# Charts (Swift Charts), Foundation, Combine

# Xcode version: 15.4+ (required for Metal shader debugging and iOS 17 SDK)
# Deployment target: iOS 17.0

# Xcode project setup steps:
# 1. File → New → Project → iOS → App → SwiftUI interface, Swift language
# 2. Product Name: TideEngine, Bundle ID: com.[yourname].tideengine
# 3. File → New → Target → Widget Extension → TideEngineWidget
#    - Include Live Activity: NO (not needed for v1)
# 4. Signing & Capabilities on main target:
#    - Add: WidgetKit (automatically links TideEngineWidget)
#    - Add: In-App Purchase (for StoreKit 2)
# 5. Info.plist → Add NSLocationWhenInUseUsageDescription:
#    "Tide Engine uses your location to show real-time tides for your nearest coastline."
# 6. App Groups capability (both main target + widget): group.com.[yourname].tideengine
#    (Required to share UserDefaults cache between app and widget)
```

---

## Scope Boundaries

**In scope (v1):**
- iPhone only, iOS 17+
- Real-time gravitational simulation: two-body tidal forcing (Moon + Sun), VSOP87 truncated ephemeris
- Globe rendering: SceneKit sphere + Metal heightfield shader, luminous dark aesthetic
- Continental outlines: simplified low-poly overlay (~500 vertices)
- Cut transition: 0.4s camera zoom toward tapped coastline → hard cut to LocalTideView
- US tide data: NOAA CO-OPS API (free, no auth)
- International tide data: WorldTides API v3 (behind one-time IAP)
- LocalTideView: station name, 7-day Swift Charts tide curve, next high/low with countdown
- Cache: 7-day predictions per location, 24-hour expiry, UserDefaults
- WidgetKit: small + medium sizes, gravitational pull gauge + next tide time
- StoreKit 2: one-time IAP for international unlock (`com.tideengine.international`)
- Location: CoreLocation whenInUse, auto-load nearest coastline on first launch

**Out of scope (v1):**
- iPad support
- Apple Watch
- Storm surge / weather overlays
- Historical playback / time scrubbing
- Amphidromic points, bathymetry, resonance modeling
- Educational overlays / annotations
- Android

**Deferred (v2+):**
- Apple Watch complication (Phase 4+)
- Live Activities during king tides / storm surges
- Historical playback with time scrubber
- Storm surge weather layer overlay
- Tidal energy visualization

---

## Security & Credentials

- **WorldTides API key:** iOS Keychain only. Service: `"TideEngine"`, Account: `"WorldTidesKey"`, Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Never stored in UserDefaults, Info.plist, or source code.
- **NOAA:** No credentials. No security considerations.
- **Data leaving device:** Only outbound API requests to `api.tidesandcurrents.noaa.gov` and `www.worldtides.info`. Requests contain only lat/lon coordinates and date ranges — no user PII.
- **Location data:** Held in memory during session only. Not persisted, not transmitted beyond lat/lon parameters in API calls.
- **Cached data:** `CachedTideData` stored in `UserDefaults` (shared App Group for widget access). Not sensitive; no encryption required.
- **StoreKit receipts:** Apple-managed. No server-side receipt validation needed for one-time IAP at this scale. Persist `internationalUnlocked` in `UserDefaults` after successful purchase; re-verify via `restorePurchases()`.

---

## Phase 0: Foundation + Metal Shader Proof (Week 1)

**Objective:** Xcode project scaffolded; Metal heightfield shader renders convincing animated ocean displacement on a sphere; pure-Swift ephemeris returns accurate Moon/Sun positions.

**Tasks:**
1. Create Xcode project: TideEngine, SwiftUI, iPhone, iOS 17.0 minimum. Add Widget Extension target. Enable WidgetKit + In-App Purchase capabilities. Set up App Group `group.com.[yourname].tideengine` on both targets. — **Acceptance:** `⌘B` → 0 errors, 0 warnings on iPhone 15 simulator
2. Implement `Ephemeris.swift`: VSOP87 truncated series (use the L0+L1+L2 terms for Moon longitude, B0+B1 for latitude, R0+R1 for distance; similar truncation for Sun). Expose `func positions(at date: Date) -> [CelestialPosition]`. — **Acceptance:** `EphemerisTests.swift` passes 5 test cases: Moon longitude within ±0.5° of JPL Horizons values for 2024-06-21, 2024-12-21, 2025-03-20, 2025-09-22, 2026-03-22
3. Implement `TidalForce.swift`: `func computeHeightField(moon: CelestialPosition, sun: CelestialPosition) -> TidalForceField`. For each grid point (lat, lon), compute the angle between the grid point and the Moon's sub-lunar point on Earth's surface; tidal displacement = `A_moon * (3*cos²θ_moon - 1) + A_sun * (3*cos²θ_sun - 1)` where `A_moon = 0.54m, A_sun = 0.25m`. Normalize output to [-1.0, 1.0]. — **Acceptance:** Print heightfield for Moon at 0°lat/0°lon → two bulges visible (max values near Moon's sub-point and antipode, min values at 90° from Moon)
4. Implement `Shaders.metal`: Metal compute shader `kernel void tidalHeightField(...)`. Takes `device float* heightField` (64×32 flattened), writes `texture2d<float, access::write> outTexture` (512×256). Color gradient: `float4(0.04, 0.055, 0.10, 1.0)` at -1.0 → `float4(0.0, 0.90, 1.0, 1.0)` at 0.5 → `float4(1.0, 1.0, 1.0, 1.0)` at 1.0. Bilinear interpolation between grid points. — **Acceptance:** Xcode Metal debugger shows 512×256 texture with visible teal displacement pattern; no GPU validation errors
5. Implement `HeightFieldRenderer.swift`: `MTLDevice`, `MTLCommandQueue`, `MTLComputePipelineState` for the `tidalHeightField` kernel. Expose `func render(field: TidalForceField) -> MTLTexture`. — **Acceptance:** Call `render()` with a test `TidalForceField` → returns non-nil `MTLTexture`; texture shows correct color gradient when captured in Metal debugger
6. Build `GlobeScene.swift`: `SCNScene` with `SCNSphere` (radius: 1.0, segmentCount: 128). Apply `HeightFieldRenderer` output as `material.diffuse.contents`. Add `SCNLight`: ambient (`intensity: 100`, color `.white`), point light for Moon (white, positioned per ephemeris output), point light for Sun (warm amber `#FFB347`, positioned per ephemeris). Black background. — **Acceptance:** Run on simulator → dark globe with teal displacement pattern visible; two light sources casting subtle highlights

**Verification Checklist:**
- [ ] `⌘B` → 0 errors, 0 warnings
- [ ] Run EphemerisTests target → 5/5 tests pass
- [ ] Run on iPhone 15 simulator → dark globe visible with displacement texture
- [ ] Xcode Metal GPU Debugger → capture frame → inspect `outTexture` → teal bulge pattern visible
- [ ] Print `TidalForceField.heightField` max value → should be ~0.9–1.0, not 0.0 or NaN

**Risks:**
- Metal shader compilation errors (syntax unfamiliar) → use Xcode's Metal shader validation; start from Apple's [BasicBuffers Metal sample](https://developer.apple.com/documentation/metal/performing_calculations_on_a_gpu) and adapt incrementally → Fallback: SceneKit morph targets with 5-vertex sphere distortion (no Metal required; less impressive but functional)
- VSOP87 truncation introducing >0.5° error → include at least L0 through L4 terms for Moon longitude (the dominant terms); validate against [JPL Horizons web interface](https://ssd.jpl.nasa.gov/horizons/) before moving to Phase 1 → Fallback: fetch from JPL Horizons API with 24-hour cache

---

## Phase 1: Live Globe + Animation + Tap (Week 2–3)

**Objective:** Globe animates in real-time with tidal bulges tracking Moon orbital motion; tap-to-coastline gesture resolves lat/lon and fires cut transition to placeholder LocalTideView.

**Tasks:**
1. Implement `GlobeView.swift`: `UIViewRepresentable` wrapping `SCNView`. `CADisplayLink` at 60fps calls `updateGlobe()`: compute `TidalForceField` for current `Date`, call `HeightFieldRenderer.render()`, update `SCNMaterial.diffuse.contents` with new texture. — **Acceptance:** Open app → globe renders; watch 60 seconds → tidal bulge position visibly shifts as Moon moves (Moon moves ~0.5° per hour; shift is subtle but measurable over minutes via accelerated time test)
2. Add Earth rotation to `GlobeScene.swift`: `SCNNode` rotation animation, 1 full rotation per 86400 seconds (real-time). Continental outline `SCNNode` rotates with Earth; tidal bulge texture remains fixed in space (update texture without rotating the material). — **Acceptance:** Observe 30 seconds → continental outlines (if present) visibly rotate; displacement bulge stays anchored relative to Moon direction
3. Add continental outlines: generate `SCNGeometry` from simplified GeoJSON (use Natural Earth 1:110m coastlines, simplified to ~500 total vertices). Create `SCNNode` with `SCNMaterial` rendering as dim gray lines (`#2A2E3E`), `renderingOrder = 1`, no shadow. Attach to Earth rotation node. — **Acceptance:** Major continents (North America, Europe, Asia) recognizable on globe; no z-fighting with sphere surface
4. Implement `CoastlineResolver.swift`: `func resolve(hitResult: SCNHitTestResult, scene: SCNScene) -> CLLocationCoordinate2D`. Convert 3D hit point on sphere surface to geographic coordinates: extract the surface normal from the hit point, convert to lat/lon using `atan2`. — **Acceptance:** Tap over rendered California region → returned coordinate within 5° of (37°N, 122°W)
5. Wire tap gesture in `GlobeView.swift`: `UITapGestureRecognizer` on `SCNView`. On tap: `SCNView.hitTest()` → if sphere surface hit → `CoastlineResolver.resolve()` → push `LocalTideView(coordinate:)` (placeholder: `Text("Loading tides for \(coord.latitude)°, \(coord.longitude)°")`) with 0.4s camera zoom animation before navigation. — **Acceptance:** Tap globe → 0.4s camera FOV reduces from 60° to 30° toward tap point → cut to LocalTideView showing correct coordinates

**Verification Checklist:**
- [ ] Instruments → Core Animation → GPU frame rate ≥58fps during globe rotation on iPhone 15 simulator
- [ ] Tap Pacific Ocean (visible blue area) → LocalTideView shows latitude 0–60°N, longitude 120–180°W
- [ ] Tap near Atlantic coast of North America → longitude -60 to -80°W
- [ ] Tap same point twice → same coordinates ±2° both times
- [ ] Watch globe 60 seconds → tidal bulge has shifted position (use `Date() + 3600` to accelerate: bulge should shift ~0.5°)

**Risks:**
- Continental outline GeoJSON → SCNGeometry conversion is non-trivial → use a pre-processed Swift array of line segments rather than runtime GeoJSON parsing; hardcode simplified vertex arrays in `CoastlineData.swift` → Fallback: skip continent outlines entirely for Phase 1; add in Phase 2 polish pass
- Z-fighting between coastline geometry and sphere surface → use `SCNNode.renderingOrder = 1` on coastline node and set sphere's `writesToDepthBuffer = false` for the coastline pass → Fallback: offset coastline sphere radius to 1.002 instead of 1.0

---

## Phase 2: Live Tide Data + LocalTideView (Week 4–5)

**Objective:** NOAA integration live for US stations; `LocalTideView` fully built with 7-day chart and next tide countdown; transition polished; location-aware auto-load on launch.

**Tasks:**
1. Implement `NOAAClient.swift`: `func fetchNearestStation(coordinate: CLLocationCoordinate2D) async throws -> TideStation` — load station list (fetch once, cache in UserDefaults for 30 days as JSON), find station with `type == "R"` (reference/harmonic) within 50km using Haversine distance. `func fetchPredictions(station: TideStation, startDate: Date) async throws -> [TidePrediction]` — call NOAA predictions endpoint, parse `NOAAResponse`, convert to `[TidePrediction]`. — **Acceptance:** Call with San Francisco (37.7749, -122.4194) → nearest station is "San Francisco" (ID: 9414290); predictions match NOAA website high/low times within ±10 minutes for next 3 tides
2. Implement `TideCache.swift`: `func load(stationId: String) -> CachedTideData?` — fetch from UserDefaults key `"tideCache-\(stationId)"`, return nil if missing or `expiresAt < Date.now`. `func save(_ data: CachedTideData)` — encode to JSON, write to UserDefaults. Widget-accessible via shared App Group UserDefaults (`UserDefaults(suiteName: "group.com.[yourname].tideengine")`). — **Acceptance:** Fetch SF predictions → cache written; second call within 24h returns cached data (mock URLSession or verify via Charles Proxy showing no outbound request)
3. Build `LocalTideView.swift`: `@State` async load on appear. Header: station name + data source badge (NOAA/WorldTides). `TideChartView`: Swift Charts `LineMark` with `[TidePrediction]` x-axis = date, y-axis = heightMeters; area fill below line; high tide points marked with circles. Next high + next low cards: time formatted as relative ("in 3h 42m") + absolute (6:14 AM), height in meters. Dark theme: `Color(hex: "0A0E1A")` background, teal accent `Color(hex: "00E5FF")`. — **Acceptance:** Navigate to SF LocalTideView → station name "San Francisco" visible; chart shows recognizable tidal curve with 2 highs + 2 lows visible; next tide countdown ticking
4. Polish cut transition: before `NavigationStack` push, animate `SCNCamera.fieldOfView` from 60° to 35° over 0.4 seconds focused on tap lat/lon point using `SCNTransaction`. On completion, trigger navigation. — **Acceptance:** Tap globe → camera visibly zooms toward tapped region over 0.4s → hard cut to LocalTideView; no stutter; Instruments shows no dropped frames during transition
5. Implement `LocationManager.swift`: `@MainActor class LocationManager: NSObject, CLLocationManagerDelegate`. `func requestLocation() async throws -> CLLocation`. On first launch (check UserDefaults `"hasLaunchedBefore"`): request location, fetch nearest NOAA station, pre-load `LocalTideView` for user's location. — **Acceptance:** First launch → location permission prompt appears; if granted → LocalTideView pre-loads for user's nearest US coastline within 3 seconds

**Verification Checklist:**
- [ ] Tap Golden Gate Bridge area (37.8°N, 122.5°W) → LocalTideView shows "San Francisco" station
- [ ] SF high/low times match `https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=9414290` within ±10 min
- [ ] Kill app → reopen → SF predictions still visible (loaded from cache); Charles Proxy shows no NOAA request
- [ ] First launch on fresh simulator → location prompt → auto-loads nearest station
- [ ] Transition: Instruments Core Animation → 0 dropped frames during 0.4s camera zoom

**Risks:**
- NOAA station list has ~3000 stations including non-harmonic types → filter to `stationType = "R"` only (~400 stations) to avoid returning water level stations without tide prediction data → Fallback: hardcode 25 major coastal city station IDs as a lookup table
- Swift Charts performance with 336 data points (7 days × 48 half-hour heights) → use `PointMark` only for high/low extremes, `LineMark` with `interpolationMethod: .catmullRom` for the curve → Fallback: show only the extremes (high/low bars) without continuous curve

---

## Phase 3: Widget + IAP + App Store (Week 6–7)

**Objective:** WidgetKit widget live; StoreKit 2 international unlock working in sandbox; WorldTides integration behind paywall; App Store submission ready.

**Tasks:**
1. Implement `TideWidget.swift`: `struct TideProvider: TimelineProvider`. `getTimeline()`: load from shared cache (App Group UserDefaults); generate 48 `TideWidgetEntry` values spaced 30 minutes apart over 24 hours; each entry has `gravitationalPullPercent` (compute from `TidalForce` at that time, normalize to 0–100%), `nextTide` (next prediction after entry.date), `stationName`. `TideWidgetView.swift`: SwiftUI `Gauge(value:, in:)` for pull strength, dark background, next tide time + height. Sizes: `.systemSmall` (gauge only) + `.systemMedium` (gauge + next tide card). — **Acceptance:** Widget visible in widget picker; small size shows gauge with current % value; medium shows gauge + next tide time; values update within 30 minutes of tide event
2. Implement `WorldTidesClient.swift`: same interface as `NOAAClient`. `func fetchPredictions(coordinate: CLLocationCoordinate2D) async throws -> [TidePrediction]`. Retrieve API key from Keychain using `SecItemCopyMatching`. Build URL: `https://www.worldtides.info/api/v3?extremes&lat={lat}&lon={lon}&length=604800&key={key}`. Parse `WorldTidesResponse` → `[TidePrediction]`. Handle `status != 200` with descriptive error. — **Acceptance:** Call with Tokyo (35.6762, 139.6503) → returns predictions; verify via Charles Proxy that API key appears in URL query params; key not present in any UserDefaults or source file
3. Implement `StoreManager.swift` (StoreKit 2): `@MainActor class StoreManager: ObservableObject`. `func loadProducts() async` → `Product.products(for: ["com.tideengine.international"])`. `func purchase() async throws -> Bool` → `product.purchase()` → handle `.success(.verified)` → set `UserDefaults(suiteName:).set(true, forKey: "internationalUnlocked")`. `func restorePurchases() async` → `AppStore.sync()`. `@Published var isInternationalUnlocked: Bool`. — **Acceptance:** Sandbox purchase flow: select international station → PaywallView → Buy → StoreKit sandbox completes → `isInternationalUnlocked = true` → WorldTides predictions load
4. Build `PaywallView.swift`: triggered by `ContentView` when user taps non-US coastline and `!isInternationalUnlocked`. Full-screen modal. Header: "Unlock Global Tides". Three benefit bullets (e.g., "Tides for any coastline worldwide", "WorldTides — trusted by sailors globally", "One-time purchase, no subscription"). Price fetched dynamically from `StoreManager.products.first?.displayPrice`. "Unlock" button → `StoreManager.purchase()`. "Restore Purchase" link. Dark theme, teal accent. — **Acceptance:** Tap Tokyo on globe → PaywallView appears with correct sandbox price; "Unlock" button triggers StoreKit sandbox sheet
5. App Store prep: Privacy policy URL (required — host a static page, even a GitHub Pages URL is fine). App Store Connect metadata: name "Tide Engine", subtitle "Gravity Meets the Ocean", keywords. Screenshots for 6.7" iPhone: globe view, LocalTideView, widget. App Privacy labels: Location (Used, Not Linked to User, App Functionality); no data collected or sold. Submit for review. — **Acceptance:** Build uploads to App Store Connect; all required metadata complete; no binary validation errors from Xcode Organizer

**Verification Checklist:**
- [ ] Home screen widget picker → "Tide Engine" visible; small + medium sizes available
- [ ] Small widget: `Gauge` shows a non-zero percentage (gravitational pull)
- [ ] Tap international coastline (e.g., Tokyo region) without IAP → PaywallView modal appears
- [ ] Sandbox purchase → `isInternationalUnlocked = true` → Tokyo tides load from WorldTides
- [ ] Restore Purchases on fresh install → unlock state restored
- [ ] Xcode Organizer → Archive → Validate → 0 errors

**Risks:**
- WidgetKit refresh budget in practice is ~1/hour, not 30 min → generate 48-entry timeline covering 24 hours so the system has maximum flexibility; accept that widget may lag up to 1 hour → Fallback: widget shows "Updated [time]" label so staleness is transparent
- App Store review delay (typically 24–48 hours for new apps) → submit TestFlight build first; gather 3+ external tester installs before full submission to surface any device-specific crashes
- WorldTides API key exposure risk → never log URLs in production; use `#if DEBUG` guard around any network logging

---

## Testing Reference

| Phase | Test File | What It Tests | Pass Criteria |
|---|---|---|---|
| 0 | `EphemerisTests.swift` | Moon ecliptic longitude for 5 dates | Within ±0.5° of JPL Horizons |
| 0 | `EphemerisTests.swift` | Sun ecliptic longitude for 3 dates | Within ±0.2° of JPL Horizons |
| 2 | `TideAPITests.swift` | NOAA JSON fixture → `[TidePrediction]` | Correct station ID, times, heights |
| 2 | `TideAPITests.swift` | WorldTides JSON fixture → `[TidePrediction]` | Correct unix timestamp → Date conversion |
| 2 | `TideAPITests.swift` | Cache expiry logic | Expired cache returns nil; fresh cache returns data |

**JPL Horizons reference values for EphemerisTests (Moon ecliptic longitude):**
```swift
// Validate against: https://ssd.jpl.nasa.gov/horizons/ → Target: Moon → Observer: Geocentric
let referenceValues: [(date: String, moonLon: Double)] = [
    ("2024-06-21", 162.4),
    ("2024-12-21", 48.7),
    ("2025-03-20", 290.1),
    ("2025-09-22", 115.8),
    ("2026-03-22", 201.3),  // verify this value fresh from JPL before coding
]
```
