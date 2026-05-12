# Tide Engine — Portfolio Disposition

**Status:** Release Frozen (iOS App Store) — Swift + SwiftUI + Metal
3D-globe iOS tidal simulator pairing a real-time gravitational
physics engine with **live NOAA station data** on `origin/main`,
with full App Store submission scaffolding (`APPSTORE-METADATA.md`,
DEVELOPMENT_TEAM, Privacy Manifest, scheme generation, copyright in
metadata + ExportOptions, privacy policy, XcodeGen-driven
xcodeproj). Includes StoreKit IAP, WidgetKit widget, VSOP87 + Meeus
astronomical ephemeris. Per memory: 62 tests, v1.0 ready. **Fifth
member of the iOS App Store cluster** — and a member of the
local-first sub-shape that reads from **third-party APIs (NOAA,
WorldTides)** rather than operating its own backend.

> Disposition uses strict `origin/main` verification.
> **Important local-state caution: local `main` is ahead of
> `origin/main` by 1 commit** (Apple Pay entitlement fix), and a
> separate feature branch `fix/remove-merchant-id` has additional
> uncommitted work. This disposition documents `origin/main`, not
> the local divergence.

---

## Verification posture

This repo has **only `origin`** (`saagpatel/TideEngine`) — no
`legacy-origin` remote. Clean migration state.

**Local-branch caution** observed during this audit (carryover for
next session, not blocking):

- Local `main` is **ahead of `origin/main` by 1 commit**:
  `17252ef fix: remove Apple Pay entitlement, add manual signing for
  App Store`. This unpushed work belongs to the merchant-ID removal
  arc.
- A local feature branch `fix/remove-merchant-id` exists at
  `c33560f fix: configure manual signing for widget target and add
  app icon for App Store` — operator's in-flight work on widget
  signing.
- An active Claude Code worktree
  (`.claude/worktrees/agent-a01c7a66`) sits at `d4622f8` —
  ephemeral, can be cleaned up.

These do **not** affect the disposition (we audit `origin/main`),
but the operator should resolve the unpushed merchant-ID work and
the widget-signing feature branch before the App Store submission
push, since they likely affect ship-readiness.

Specifically verified on `origin/main`:

- Tip: `d4622f8` chore: add privacy policy and update metadata URLs
- Substantive App Store prep commits on `origin/main`:
  - `d4622f8` chore: add privacy policy and update metadata URLs
  - `6c3489b` chore: add copyright to metadata and ExportOptions.plist
  - `f2adf93` fix: remove stale xcodeVersion from project.yml
  - `ffc7867` chore(docs): add App Store Connect metadata
  - `5a8f73e` chore: App Store prep — DEVELOPMENT_TEAM, Privacy
    Manifest, scheme generation
  - `d686acf` chore: add session handoff
- **Full OSS scaffolding wave on canonical main:** CHANGELOG, PR
  template, issue templates, CoC, Makefile, Dependabot, contributing,
  security policy, MIT license, README docs
- `project.yml` (XcodeGen driver, like Ghost Routes — xcodeproj
  regenerated from declarative spec)
- Default branch: `main`

---

## Current state in one paragraph

Tide Engine is an iOS tidal simulation app — "the ocean on your
phone, physics and all" — pairing a Swift gravitational physics
engine (using VSOP87 + Meeus astronomical ephemeris for accurate
sun/moon position) with **live NOAA CO-OPS station data** and
**WorldTides API** for cross-reference. The user spins a 3D globe
(Metal shader), taps a coastline, and the app shows a physics-driven
tidal breakdown alongside official tide predictions. Adds StoreKit
(IAP), WidgetKit (home-screen widget for upcoming tides),
XcodeGen-driven project structure. Per memory: 62 tests, v1.0 App
Store-ready. The release commits on canonical main confirm the
operator has done DEVELOPMENT_TEAM + Privacy Manifest + APPSTORE
metadata + copyright + privacy policy. The local branch state
(unpushed Apple Pay removal + widget-signing feature branch)
suggests the operator is mid-final-cleanup before submission.

For full detail see:
- `README.md` on `origin/main`
- `APPSTORE-METADATA.md`

---

## Why "Release Frozen (iOS App Store)" — fifth cluster member

The iOS App Store prep signature applies for a fifth iOS app. The
local-first sub-shape (Calibrate / Chromafield / Ghost Routes /
**TideEngine**) is now 4 members; the cloud-backed sub-shape
(Nocturne) is 1.

Tide Engine is **local-first with third-party API reads** —
distinguished from the cloud-backed shape:

| Aspect | Local-first (Calibrate, Chromafield, Ghost Routes) | **Local-first + API read (Tide Engine)** | Cloud-backed (Nocturne) |
|---|---|---|---|
| Backend the operator runs | None | None | Required |
| Third-party API dependency | None | **NOAA CO-OPS + WorldTides** | Open-Meteo (read) + own server (read/write) |
| Operator concerns | App Store Review only | App Store Review + **API rate limits / outages / vendor stability** | App Store Review + backend hosting + abuse / GDPR |

The API-read posture sits between local-first and cloud-backed.
Calling out the operator concerns it adds (API key management, rate
limits, vendor reliability) without forcing a new sub-shape — it's
an annotation on local-first, not a separate slot.

---

## Cluster taxonomy update

| Cluster | Count | Sub-shapes |
|---|---|---|
| Signing (Apple desktop) | 23 | (no sub-shapes) |
| **iOS App Store** | **5** | local-first (4) / cloud-backed (1) |
| Static-host (web) | 3 sub-shapes | PWA / static SPA / SSR+Supabase |
| Self-hosted service | 1 | (n/a) |
| PyPI distribution | 2 | Release Frozen / Active |
| Local-first pipeline | 1 | (n/a) |
| Operator-tool / dogfood | 1 | (n/a) |
| Chrome MV3 extension | 1 | (no sub-shapes yet) |

iOS App Store cluster crosses 5 members — formally now a "large"
cluster comparable to signing (23). Remaining iOS candidates per
memory: Liminal / Redact / RoomTone / Seismoscope / Terroir /
Wavelength (6 more). Cluster will likely reach 11+ in 2 more rounds.

---

## Unblock trigger (operator)

When ready to ship publicly:

1. **Resolve local-state divergence first.** Before submitting to
   App Store Connect:
   - Push the local-main-ahead-1 commit (`17252ef fix: remove Apple
     Pay entitlement, add manual signing for App Store`) — this is
     load-bearing for App Store submission (Apple Pay merchant ID
     scrutiny is a common rejection reason if entitlements claim a
     capability not actually used).
   - Decide the fate of `fix/remove-merchant-id` branch (widget
     manual signing + app icon for App Store). Either merge to main
     or close as superseded.
   - Clean up the stale Claude Code worktree
     `.claude/worktrees/agent-a01c7a66`.
2. **App Store Connect record** with the bundle ID matching the
   xcodeproj (verify after merchant-ID resolution).
3. **NOAA CO-OPS API key management** — verify rate limit posture
   for production traffic. NOAA CO-OPS is generally generous but
   has unannounced outages; consider a graceful "predictions
   unavailable, physics-only mode" fallback.
4. **WorldTides API** — paid SaaS. Verify pricing tier matches
   expected traffic, API key not exposed in client bundle.
5. **VSOP87 + Meeus ephemeris data** — bundled or computed? If
   bundled, verify update cadence (the orbital elements drift over
   centuries; for a tide app shipping in 2026, this is not
   load-bearing, but worth a note).
6. **StoreKit IAP products** in App Store Connect (verify config
   matches in-app StoreKit declarations).
7. **WidgetKit privacy** — the widget reads location; verify
   widget bundle Info.plist has the right purpose strings and
   the widget supports "no permission" graceful degradation.
8. **Required screenshots** + fastlane deliver dry-run.
9. **Submit for Review.**

Estimated operator time once local divergence is resolved + App
Store Connect record exists: ~4-5 hours.

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store, local-first + API read)` |
| Distribution channel | **App Store Connect** |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Local main divergence resolved + push, (b) submission to App Store Review, (c) NOAA CO-OPS or WorldTides API breaking change, (d) v1.1 (more accurate ephemeris, more coastline coverage), or (e) widget-signing arc closes |
| Co-batch with | iOS App Store cluster: Calibrate / Chromafield / Ghost Routes / Nocturne / **Tide Engine** — **now 5 repos** |
| Sub-shape | **Local-first + third-party-API-read.** Local-first sibling sub-shape (no operator backend), but with NOAA + WorldTides as external dependencies. |
| Special concern | **Local-state divergence MUST be resolved before App Store submission.** Apple Pay entitlement removal + widget manual signing are ship-blockers. |
| Special concern | **NOAA / WorldTides API reliability.** Plan graceful degradation when APIs are unavailable (physics-only fallback for NOAA outages). |
| Special concern | **WorldTides API key in client bundle.** If the API key is bundled, extraction is trivial. Use a server-side proxy or operator-managed proxy if traffic justifies. |
| Special concern | **WidgetKit location permission UX.** Widget asking for location independently of main app is jarring; align with main app's permission flow. |
| Special concern | **VSOP87 + Meeus accuracy.** Astronomical computations have known edge cases (eclipses, perigee/apogee transitions). Tests (62 per memory) should cover the obvious ones. |

---

## Why this row sub-classifies as "local-first + API read"

The iOS App Store cluster now has clear sub-shape geometry:

- **Pure local-first** (3 apps): data in, data stays. No network
  dependency at runtime.
- **Local-first + API read** (Tide Engine): data on device, plus
  reads from third-party APIs. No operator backend.
- **Cloud-backed** (Nocturne): operator runs a backend; data
  flows out.

Future iOS apps that depend on third-party APIs but don't operate
backends classify here. Examples in operator memory: weather apps,
news readers, finance trackers, etc. None of the remaining iOS
candidates obviously fit (Liminal, Redact, RoomTone, Seismoscope,
Terroir, Wavelength all look local-first by description).

---

## Reactivation procedure (for the next code session)

1. **Resolve local-state divergence first** (see Unblock trigger
   #1). The local main + `fix/remove-merchant-id` branch + active
   worktree need disposition before any further work.
2. Verify `git branch -vv` after cleanup — `main` should track
   `origin/main` cleanly.
3. Review the local stash (`r13-tideengine-stash`) — contains
   modifications to `CLAUDE.md` and `fastlane/Fastfile`, plus
   untracked `AGENTS.md`, `fastlane/README.md`,
   `fastlane/metadata/`, `fastlane/report.xml`. **The fastlane
   metadata directory is significant — operator may have run
   `fastlane deliver init` and started populating metadata
   locally. Inspect before discarding.**
4. **Open `TideEngine.xcodeproj`** (regenerated from `project.yml`
   via XcodeGen) — confirm signing is clean post-merchant-ID
   removal.
5. **Audit `APPSTORE-METADATA.md`** for content drift.
6. **Audit NOAA CO-OPS + WorldTides API key handling** for
   production posture.
7. **Run XCTest target** — 62 tests per memory should still pass.
8. **Test widget** in Simulator with location permission flows.
9. **`fastlane deliver` dry run** once metadata directory is
   committed.

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `d4622f8` chore: add privacy policy and update metadata URLs |
| Last substantive commit | `5a8f73e` chore: App Store prep — DEVELOPMENT_TEAM, Privacy Manifest, scheme generation |
| Default branch | `main` (local main ahead by 1 unpushed commit) |
| Build system | **iOS / Swift / SwiftUI / Metal / XcodeGen / XCTest** |
| Phases shipped | v1.0 per memory; 62 tests |
| Release scaffolding | **`APPSTORE-METADATA.md` + DEVELOPMENT_TEAM + Privacy Manifest + ExportOptions.plist + copyright + privacy policy + `project.yml`** |
| Distribution channel | **App Store Connect** |
| Tech distinguisher | VSOP87 + Meeus astronomical ephemeris + Metal 3D globe + StoreKit IAP + WidgetKit + NOAA CO-OPS + WorldTides API |
| API dependencies | **NOAA CO-OPS (free, US-only)** + **WorldTides (paid, global)** |
| Blocker | Resolve local main divergence + `fix/remove-merchant-id` branch + App Store Connect submission (operator-only) |
| Migration state | **No `legacy-origin` remote** — clean (but local-branch state is messy) |
| Distinguishing feature | **Fifth iOS App Store cluster member.** First member to sub-classify as "local-first + third-party API read" (NOAA + WorldTides). Local-state divergence (ahead-1 + feature branch) flagged as pre-submission cleanup. |
