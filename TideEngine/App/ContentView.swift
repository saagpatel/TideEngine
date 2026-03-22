import SwiftUI
import CoreLocation
import StoreKit

struct ContentView: View {
    @State private var globeScene: GlobeScene?
    @State private var error: String?
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var showLocalTide = false
    @State private var showPaywall = false
    @State private var locationManager = LocationManager()
    @State private var hasAttemptedAutoNav = false
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.055, blue: 0.10)
                    .ignoresSafeArea()

                if let globeScene {
                    GlobeView(globeScene: globeScene, onTapCoastline: { coordinate in
                        globeScene.animateCameraZoom(toward: coordinate) {
                            tappedCoordinate = coordinate
                            // Pre-check: try loading data to detect if paywall needed
                            Task {
                                do {
                                    _ = try await TideDataService.shared.loadTideData(for: coordinate)
                                    await MainActor.run { showLocalTide = true }
                                } catch TideError.internationalLocked {
                                    await MainActor.run {
                                        globeScene.resetCamera()
                                        showPaywall = true
                                    }
                                } catch {
                                    // Other errors — let LocalTideView handle them
                                    await MainActor.run { showLocalTide = true }
                                }
                            }
                        }
                    })
                    .ignoresSafeArea()
                } else if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationDestination(isPresented: $showLocalTide) {
                if let coord = tappedCoordinate {
                    LocalTideView(coordinate: coord)
                        .onDisappear {
                            globeScene?.resetCamera()
                        }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(storeManager: storeManager, onPurchased: {
                    // After purchase, navigate to tide view
                    if tappedCoordinate != nil {
                        showLocalTide = true
                    }
                })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await setupGlobe()

            // First-launch auto-navigation to user's nearest coastline
            if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore"), !hasAttemptedAutoNav {
                hasAttemptedAutoNav = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                do {
                    try await Task.sleep(for: .seconds(1.5))
                    let location = try await locationManager.requestLocation()
                    let coord = location.coordinate
                    globeScene?.animateCameraZoom(toward: coord) {
                        tappedCoordinate = coord
                        showLocalTide = true
                    }
                } catch {
                    // Permission denied or timeout — silently skip
                }
            }
        }
    }

    private func setupGlobe() async {
        do {
            let renderer = try HeightFieldRenderer()
            let scene = GlobeScene(renderer: renderer)

            // Initial render with current ephemeris
            let positions = Ephemeris.positions(at: .now)
            if let moon = positions.first(where: { $0.body == .moon }),
               let sun = positions.first(where: { $0.body == .sun }) {
                let field = TidalForce.computeHeightField(moon: moon, sun: sun)
                scene.update(positions: positions, field: field)
            }

            await MainActor.run {
                self.globeScene = scene
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
