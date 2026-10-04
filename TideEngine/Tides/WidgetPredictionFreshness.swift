import Foundation

enum WidgetPredictionFreshness {
    /// Allow a short offline fallback beyond the app's 24-hour cache expiry.
    static let maximumAge: TimeInterval = 48 * 60 * 60

    static func isUsable(_ cached: CachedTideData, at date: Date) -> Bool {
        let age = date.timeIntervalSince(cached.fetchedAt)
        return age >= 0 && age <= maximumAge
            && cached.predictions.contains { $0.timestamp > date }
    }
}
