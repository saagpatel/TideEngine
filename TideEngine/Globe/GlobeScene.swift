import Foundation
@preconcurrency import SceneKit
import UIKit
import CoreLocation

final class GlobeScene: @unchecked Sendable {
    let scene: SCNScene
    let cameraNode: SCNNode
    private let sphereNode: SCNNode
    private let moonLightNode: SCNNode
    private let sunLightNode: SCNNode
    private let renderer: HeightFieldRenderer
    private let emissionProperty: SCNMaterialProperty

    init(renderer: HeightFieldRenderer) {
        self.renderer = renderer

        let scene = SCNScene()
        scene.background.contents = UIColor.black
        self.scene = scene

        // --- Sphere ---
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 128

        let material = SCNMaterial()
        material.lightingModel = .phong
        material.diffuse.contents = UIColor(red: 0.035, green: 0.16, blue: 0.24, alpha: 1.0)
        material.emission.contents = renderer.outputTexture
        material.emission.intensity = 0.72
        material.shininess = 0.2
        material.specular.contents = UIColor(white: 0.35, alpha: 1.0)
        material.isDoubleSided = false
        sphere.materials = [material]

        let sphereNode = SCNNode(geometry: sphere)
        self.sphereNode = sphereNode
        scene.rootNode.addChildNode(sphereNode)

        // Store emission property for per-frame contentsTransform updates
        self.emissionProperty = material.emission

        // --- Camera ---
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.automaticallyAdjustsZRange = true

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4)
        self.cameraNode = cameraNode
        scene.rootNode.addChildNode(cameraNode)

        // --- Ambient light ---
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 420
        ambient.color = UIColor.white

        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // --- Moon light ---
        let moonLight = SCNLight()
        moonLight.type = .omni
        moonLight.intensity = 200
        moonLight.color = UIColor.white

        let moonLightNode = SCNNode()
        moonLightNode.light = moonLight
        moonLightNode.position = SCNVector3(0, 0, 10)
        self.moonLightNode = moonLightNode
        scene.rootNode.addChildNode(moonLightNode)

        // --- Sun light ---
        let sunLight = SCNLight()
        sunLight.type = .omni
        sunLight.intensity = 400
        sunLight.color = UIColor(red: 1.0, green: 0.702, blue: 0.278, alpha: 1.0)

        let sunLightNode = SCNNode()
        sunLightNode.light = sunLight
        sunLightNode.position = SCNVector3(10, 0, 0)
        self.sunLightNode = sunLightNode
        scene.rootNode.addChildNode(sunLightNode)

        // --- Coastline overlay ---
        let coastlineNode = buildCoastlineNode()
        sphereNode.addChildNode(coastlineNode)

        // --- Per-frame GMST-driven rotation ---
        let rotateAction = SCNAction.customAction(duration: 1.0) { [weak self] node, _ in
            guard let self else { return }
            let gmstDeg = Ephemeris.gmstDegrees(at: Date())
            let gmstRad = Float(gmstDeg * .pi / 180.0)
            node.eulerAngles.y = gmstRad
            let uOffset = Float(gmstDeg / 360.0)
            self.emissionProperty.contentsTransform = SCNMatrix4MakeTranslation(uOffset, 0, 0)
        }
        sphereNode.runAction(SCNAction.repeatForever(rotateAction))
    }

    // MARK: - Coastline

    private func buildCoastlineNode() -> SCNNode {
        let container = SCNNode()
        container.renderingOrder = 1
        container.castsShadow = false

        let coastlineMaterial = SCNMaterial()
        coastlineMaterial.lightingModel = .constant
        coastlineMaterial.diffuse.contents = UIColor(red: 0.165, green: 0.180, blue: 0.243, alpha: 1.0)

        for polyline in CoastlineData.polylines {
            guard polyline.count >= 2 else { continue }

            var vertices: [SCNVector3] = []
            var indices: [Int32] = []

            for point in polyline {
                let latRad = Float(point.lat) * .pi / 180.0
                let lonRad = Float(point.lon) * .pi / 180.0
                let r: Float = 1.002
                let x = r * cos(latRad) * cos(lonRad)
                let y = r * sin(latRad)
                let z = -r * cos(latRad) * sin(lonRad)
                vertices.append(SCNVector3(x, y, z))
            }

            // Build line segment indices (pairs of adjacent vertices)
            for i in 0..<(vertices.count - 1) {
                indices.append(Int32(i))
                indices.append(Int32(i + 1))
            }

            let vertexSource = SCNGeometrySource(vertices: vertices)
            let element = SCNGeometryElement(
                indices: indices,
                primitiveType: .line
            )
            let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
            geometry.materials = [coastlineMaterial]

            let lineNode = SCNNode(geometry: geometry)
            lineNode.renderingOrder = 1
            lineNode.castsShadow = false
            container.addChildNode(lineNode)
        }

        return container
    }

    // MARK: - Camera Animation

    func animateCameraZoom(toward coordinate: CLLocationCoordinate2D, completion: @escaping () -> Void) {
        let latRad = coordinate.latitude * .pi / 180.0
        let lonRad = coordinate.longitude * .pi / 180.0
        let dx = Float(cos(latRad) * cos(lonRad) * 0.4)
        let dy = Float(sin(latRad) * 0.4)
        let dz = Float(-cos(latRad) * sin(lonRad) * 0.4)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = completion
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(dx, dy, 3.0 + dz)
        SCNTransaction.commit()
    }

    func resetCamera() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 0, 3)
        SCNTransaction.commit()
    }

    // MARK: - Update

    func update(positions: [CelestialPosition], field: TidalForceField) {
        // Re-render the heightfield into the shared texture SceneKit already references
        renderer.render(field: field)

        // Update light positions from ecliptic coordinates
        for position in positions {
            let lon = position.eclipticLongitude * .pi / 180.0
            let lat = position.eclipticLatitude  * .pi / 180.0

            let x = Float(cos(lat) * cos(lon) * 10.0)
            let y = Float(sin(lat) * 10.0)
            let z = Float(-cos(lat) * sin(lon) * 10.0)

            let scnPosition = SCNVector3(x, y, z)

            switch position.body {
            case .moon:
                moonLightNode.position = scnPosition
            case .sun:
                sunLightNode.position = scnPosition
            }
        }
    }
}
