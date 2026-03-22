import CoreLocation
import SceneKit

/// Converts a SceneKit hit test result on the globe sphere to geographic coordinates.
struct CoastlineResolver {

    /// Resolve a hit on the sphere to geographic (lat, lon).
    ///
    /// Uses `worldCoordinates` which account for the sphere's GMST rotation.
    /// SceneKit coordinate convention:
    ///   x = cos(lat) * cos(lon)
    ///   y = sin(lat)
    ///   z = -cos(lat) * sin(lon)
    static func resolve(hitResult: SCNHitTestResult) -> CLLocationCoordinate2D {
        let p = hitResult.worldCoordinates

        // Normalize to unit vector
        let r = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
        guard r > 0 else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let nx = Double(p.x / r)
        let ny = Double(p.y / r)
        let nz = Double(p.z / r)

        // y = sin(lat)
        let lat = asin(ny) * 180.0 / .pi

        // x = cos(lat)*cos(lon), z = -cos(lat)*sin(lon) → lon = atan2(-z, x)
        var lon = atan2(-nz, nx) * 180.0 / .pi
        if lon > 180.0 { lon -= 360.0 }
        if lon < -180.0 { lon += 360.0 }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
