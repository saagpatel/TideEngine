import CoreLocation

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate, Observable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // coarse is fine for station lookup
    }

    func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait briefly for authorization
            try await Task.sleep(for: .seconds(0.5))
        }

        let currentStatus = manager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.first ?? CLLocation())
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

enum LocationError: Error, LocalizedError {
    case permissionDenied
    var errorDescription: String? { "Location permission denied" }
}
