# Tide Engine — App Store Connect Metadata

## Identity

| Field | Value |
|-------|-------|
| **Name** | Tide Engine |
| **Subtitle** | Gravity meets the ocean |
| **Bundle ID** | com.tideengine.app |
| **SKU** | TIDEENGINE-001 |
| **Primary Category** | Weather |
| **Secondary Category** | Education |
| **Age Rating** | 4+ |
| **Price** | $1.99 (Tier 2) |
| **Availability** | All territories |

---

## Keywords

```
tides,tide chart,ocean,moon,gravity,simulation,NOAA,coastal,high tide,low tide,tidal,globe
```

*(100 character limit — these are 88 characters)*

---

## Description

Tides are gravity made visible. The Moon pulls, the Sun assists, and the oceans respond — twice daily, everywhere on Earth, without pause. Tide Engine makes that invisible force tangible.

Open the app to a 3D globe rendered in luminous indigo and teal, its oceans deforming in real time according to a gravitational simulation that updates every frame. Two tidal bulges track the Moon's position. The Sun adds its own pull. Tap any coastline and watch the camera zoom toward it — then cut to real tide predictions for that location, sourced from NOAA (US coasts, free) or WorldTides (international, one-time unlock).

**The globe:**
• Real-time gravitational tidal forcing — VSOP87 truncated ephemeris for Moon and Sun positions
• Metal heightfield shader on a SceneKit sphere — 512×256 tidal displacement texture updated live
• Dynamic lighting — Moon casts white-hot light, Sun casts warm amber, both positioned per orbital mechanics
• Continental outlines — simplified coastlines rotate with Earth in real time
• Tap-to-coastline — SCNHitTest resolves your tap to geographic coordinates; 0.4s camera zoom then a hard cut to local tide data

**Local tide data:**
• 7-day chart — Swift Charts tide height curve showing every high and low
• Next high and low — with countdown timer and height in meters
• Station name — matched to the nearest harmonic prediction station within 50km
• 24-hour cache — predictions load instantly after first fetch; stale data shown with a banner when offline

**Data sources:**
• US coasts — NOAA CO-OPS API. Completely free. No API key required.
• International coasts — WorldTides API v3. Unlock once for every coastline on Earth.

**Home screen widget:**
• Small widget — gravitational pull gauge showing current tidal force as a percentage
• Medium widget — pull gauge plus next tide time and height
• Updates within 30 minutes; reads from shared cache (no additional API calls from widget)

**One-time purchase, not a subscription.** US tide data (NOAA) is free forever. The international unlock ($1.99 suggested retail) is a single purchase that covers every non-US coastline permanently — no renewal, no credits, no recurring billing.

---

## Promotional Text

*(Optional — appears above description, can be updated without new app version)*

```
A real-time gravitational tide simulation on a 3D globe. Tap any coastline for NOAA or WorldTides predictions.
```

---

## Support URL

*(Enter your support URL — e.g. a GitHub repo or personal site)*

---

## Privacy Policy URL

*(Required — host a static page; note location data is only used in-memory for API queries)*

---

## Screenshots

### Required Sizes
- **6.7" Display** — 1290 × 2796 px (iPhone 16 Pro Max / iPhone 15 Pro Max)
- **6.1" Display** — 1179 × 2556 px (iPhone 16 / iPhone 15)

### Screenshot Plan (4 screenshots per size)

| # | Screen | Simulator State | Headline Overlay |
|---|--------|-----------------|------------------|
| 1 | GlobeView — full globe | Dark globe centered on Pacific; two tidal bulges visible as bright teal displacement bands; continental outlines faintly visible in dim gray; Moon-side bulge clearly brighter; atmosphere is deep indigo-to-black | "The Moon pulls. The ocean responds." |
| 2 | LocalTideView — San Francisco | Station name "San Francisco" at top; 7-day tide chart showing 4+ tidal cycles as a teal curve with high-tide dots marked; "Next High: 6h 14m — 1.74m" and "Next Low: 11h 50m — 0.21m" cards below the chart | "7 days of tides for any coastline." |
| 3 | GlobeView — zoomed toward California coast | Camera FOV reduced, globe tilted toward North America; California coast visible; cursor approaching the coastline; transition animation in progress (or just-completed zoom toward tap point) | "Tap any coast. See the tides." |
| 4 | Home screen showing widget | Medium-size widget on a dark home screen wallpaper — Gauge showing "62% Tidal Pull" with a teal indicator; "Next High: 4:32 AM · 1.8m" card below; Tide Engine app icon visible nearby | "Always on your home screen." |

### How to Take Screenshots
1. Open Xcode → Simulator → select iPhone 16 Pro Max
2. Build and run TideEngine target; let the globe render
3. For screenshot 1: let the globe rotate naturally; capture when tidal bulge alignment is visually clear
4. For screenshot 2: tap the Pacific coast near San Francisco; let LocalTideView load NOAA data
5. For screenshot 3: pause mid-zoom by capturing during the 0.4s camera animation (use Simulator slow-motion if needed), or position the globe so California is tappable and compose the shot without the transition
6. For screenshot 4: add the medium widget to a dark home screen in the simulator; capture from the home screen
7. **Xcode menu: Product → Simulator → Take Screenshot** (saves to Desktop)
   OR: `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
8. Repeat for iPhone 16 (6.1") by switching simulator
9. Add marketing text overlays in Sketch, Figma, or Canva before uploading

---

## App Review Notes

```
Tide Engine makes two categories of network requests:
1. NOAA CO-OPS API (https://api.tidesandcurrents.noaa.gov) — free, unauthenticated, US tide predictions
2. WorldTides API (https://www.worldtides.info/api/v3) — international tide predictions, requires API key
   stored in iOS Keychain (never in UserDefaults or source). WorldTides is behind a one-time IAP.

Location permission (NSLocationWhenInUseUsageDescription) is used only to auto-load the nearest
coastline on first launch. The app does not track location; lat/lon coordinates are passed as query
parameters to NOAA/WorldTides but are not stored or shared beyond those API calls.

In-app purchase:
- Product ID: com.tideengine.international
- Type: Non-consumable (one-time unlock)
- Unlocks access to WorldTides API for any non-US coastline
- Restore Purchases is implemented via AppStore.sync()

To test core features (US, no IAP required):
1. Grant location permission → app auto-loads the nearest US coast
2. Tap any visible US coastline on the globe → 0.4s camera zoom → LocalTideView with NOAA data
3. Verify 7-day chart shows tide curve; verify next high/low countdown is ticking
4. Add the medium widget to home screen → verify gauge shows a non-zero percentage

To test international IAP (sandbox):
1. Tap a non-US coastline (e.g., UK, Japan) → PaywallView appears
2. Tap "Unlock" → StoreKit sandbox sheet → complete sandbox purchase
3. WorldTides predictions load for the tapped location

No reviewer credentials required for US functionality. For IAP testing, use Apple's standard sandbox reviewer account.
```

---

## Checklist Before Submission

- [ ] Bundle ID `com.tideengine.app` registered in Apple Developer portal
- [ ] App icon 1024×1024 appears correctly in Xcode asset catalog (no warnings)
- [ ] `NSLocationWhenInUseUsageDescription` in Info.plist with plain-English string
- [ ] `PrivacyInfo.xcprivacy` present in main target — Location API declared, `NSPrivacyTracking = false`
- [ ] App Group `group.com.tideengine.app` configured on both main target and widget extension
- [ ] In-App Purchase capability enabled; product `com.tideengine.international` created in App Store Connect
- [ ] WorldTides API key stored in Keychain only — verify it does not appear in UserDefaults, Info.plist, or any source file
- [ ] Archive succeeds for both main target and widget extension: `Product → Archive` with no errors
- [ ] Validate App passes with 0 errors
- [ ] All 8 screenshots uploaded (4 per required size: 6.7" + 6.1")
- [ ] Description, keywords, subtitle filled in App Store Connect
- [ ] Price set to $1.99 (Tier 2) in Pricing and Availability
- [ ] Age rating questionnaire complete (4+)
- [ ] Support URL and Privacy Policy URL provided
- [ ] Privacy nutrition label: Location (Used, Not Linked to User, App Functionality); no data sold; no tracking
- [ ] Sandbox IAP test complete: PaywallView appears for international tap, purchase succeeds, restore works on fresh install
- [ ] Widget appears in widget picker, small + medium sizes, values update
- [ ] NOAA data verified for San Francisco station (9414290) — high/low times match NOAA website within ±10 min
- [ ] TestFlight build accepted by App Store Connect before full review submission
- [ ] Submit for Review
