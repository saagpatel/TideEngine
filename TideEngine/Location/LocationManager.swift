@preconcurrency import CoreLocation

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate, Observable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // coarse is fine for station lookup
    }

    func requestLocation() async throws -> CLLocation {
        guard continuation == nil, authorizationContinuation == nil else {
            throw LocationError.requestInProgress
        }

        let status = manager.authorizationStatus
        if status == .notDetermined {
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
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

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let continuation = authorizationContinuation else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                authorizationContinuation = nil
                continuation.resume()
            case .denied, .restricted:
                authorizationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            case .notDetermined:
                break
            @unknown default:
                authorizationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let continuation else { return }
            self.continuation = nil
            guard let location = locations.first else {
                continuation.resume(throwing: LocationError.noLocation)
                return
            }
            continuation.resume(returning: location)
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
    case noLocation
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Location access is required to find a nearby NOAA tide station."
        case .noLocation: "Your location could not be determined. Please try again."
        case .requestInProgress: "A location request is already in progress."
        }
    }
}
