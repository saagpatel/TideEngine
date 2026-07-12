import SwiftUI
@preconcurrency import SceneKit
import CoreLocation

struct GlobeView: UIViewRepresentable {
    let globeScene: GlobeScene
    var onTapCoastline: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(globeScene: globeScene)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = globeScene.scene
        scnView.pointOfView = globeScene.cameraNode
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        scnView.loops = true

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        scnView.addGestureRecognizer(tapGesture)
        context.coordinator.scnView = scnView
        context.coordinator.onTapCoastline = onTapCoastline

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onTapCoastline = onTapCoastline
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        let globeScene: GlobeScene
        var onTapCoastline: ((CLLocationCoordinate2D) -> Void)?
        weak var scnView: SCNView?
        private var lastUpdateTime: TimeInterval = 0

        init(globeScene: GlobeScene) {
            self.globeScene = globeScene
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Throttle tidal field recomputation to every 0.5s
            // (Moon moves only 0.5°/hour — 60fps recomputation is wasteful)
            guard time - lastUpdateTime > 0.5 else { return }
            lastUpdateTime = time

            let now = Date()
            let positions = Ephemeris.positions(at: now)
            guard let moon = positions.first(where: { $0.body == .moon }),
                  let sun = positions.first(where: { $0.body == .sun }) else { return }
            let field = TidalForce.computeHeightField(moon: moon, sun: sun)
            globeScene.update(positions: positions, field: field)
        }

        @MainActor @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [
                .boundingBoxOnly: NSNumber(value: false)
            ])

            // Find hit on the sphere geometry (ignore coastline lines)
            guard let hit = hitResults.first(where: { $0.node.geometry is SCNSphere }) else { return }

            // Convert world coordinates to geographic lat/lon
            let p = hit.worldCoordinates
            let r = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
            guard r > 0 else { return }
            let ny = p.y / r
            let nx = p.x / r
            let nz = p.z / r

            let lat = asin(Double(ny)) * 180.0 / .pi
            var lon = atan2(Double(-nz), Double(nx)) * 180.0 / .pi
            if lon > 180.0 { lon -= 360.0 }
            if lon < -180.0 { lon += 360.0 }

            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            onTapCoastline?(coordinate)
        }
    }
}
