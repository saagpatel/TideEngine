import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var globeScene: GlobeScene?
    @State private var error: String?
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var showLocalTide = false
    @State private var locationManager = LocationManager()
    @State private var isLocating = false
    @State private var locationError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.055, blue: 0.10)
                    .ignoresSafeArea()

                if let globeScene {
                    GlobeView(globeScene: globeScene, onTapCoastline: { coordinate in
                        globeScene.animateCameraZoom(toward: coordinate) {
                            tappedCoordinate = coordinate
                            showLocalTide = true
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

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TIDE ENGINE")
                                .font(.caption.weight(.bold))
                                .tracking(2.4)
                            Text("Gravity, made visible")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                        Spacer()
                        Button {
                            locateUser()
                        } label: {
                            Group {
                                if isLocating {
                                    ProgressView()
                                } else {
                                    Image(systemName: "location.fill")
                                }
                            }
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                        }
                        .disabled(isLocating || globeScene == nil)
                        .accessibilityLabel("Show tides near me")
                    }
                    Spacer()

                    Text("Drag to explore • Tap a supported U.S. coast for NOAA tides")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityLabel("Drag to explore. Tap a supported United States coast for NOAA tides.")
                }
                .padding()
            }
            .navigationDestination(isPresented: $showLocalTide) {
                if let coord = tappedCoordinate {
                    LocalTideView(coordinate: coord)
                        .onDisappear {
                            globeScene?.resetCamera()
                        }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Location Unavailable", isPresented: Binding(
                get: { locationError != nil },
                set: { if !$0 { locationError = nil } }
            )) {
                Button("OK", role: .cancel) { locationError = nil }
            } message: {
                Text(locationError ?? "Tide Engine could not determine your location.")
            }
        }
        .task {
            await setupGlobe()
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

    private func locateUser() {
        isLocating = true
        locationError = nil
        Task {
            do {
                let location = try await locationManager.requestLocation()
                let coordinate = location.coordinate
                globeScene?.animateCameraZoom(toward: coordinate) {
                    tappedCoordinate = coordinate
                    showLocalTide = true
                }
            } catch {
                locationError = error.localizedDescription
            }
            isLocating = false
        }
    }
}

#Preview {
    ContentView()
}
