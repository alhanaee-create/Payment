import CoreLocation

/// يجيب الموقع الحالي مرة وحدة.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var isAuthorized: Bool {
        let s = manager.authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation(timeout: Double = 8) async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            guard waiting.count == 1 else { return }
            manager.requestLocation()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.finish(self.manager.location)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        let pending = waiting
        waiting.removeAll()
        pending.forEach { $0.resume(returning: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finish(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(self.manager.location) }
    }

    /// يحوّل الإحداثيات لاسم مكان (الحي، المدينة).
    static func placeName(for location: CLLocation) async -> String {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return "" }
        return describe(placemark)
    }

    static func describe(_ placemark: CLPlacemark) -> String {
        let parts = [placemark.subLocality, placemark.locality].compactMap { $0 }.filter { !$0.isEmpty }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        if unique.isEmpty { return placemark.name ?? "" }
        return unique.joined(separator: "، ")
    }
}
