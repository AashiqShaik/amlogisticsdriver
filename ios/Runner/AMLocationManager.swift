import CoreLocation
import Flutter
import UIKit

/// iOS equivalent of the Android LocationForegroundService.
/// Uses CLLocationManager with `allowsBackgroundLocationUpdates = true` so
/// GPS fixes continue while the app is backgrounded or the screen is locked.
///
/// Channels (identical names to Android so Flutter code is platform-agnostic):
///   MethodChannel : com.example.amlogisticsdriver/location_service
///   EventChannel  : com.example.amlogisticsdriver/location_updates
class AMLocationManager: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {

    // MARK: - Singleton
    static let shared = AMLocationManager()

    // MARK: - Private state
    private let locationManager = CLLocationManager()
    private var eventSink: FlutterEventSink?
    private var isTracking = false

    // MARK: - Init
    private override init() {
        super.init()
        locationManager.delegate = self
        // High-accuracy GPS matching the Android 10 m / 10 s configuration
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10          // metres
        locationManager.pausesLocationUpdatesAutomatically = false
        // Required for background delivery
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Channel registration
    /// Called once from AppDelegate to wire up both Flutter channels.
    func registerChannels(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        // MethodChannel — start / stop commands
        let methodChannel = FlutterMethodChannel(
            name: "com.example.amlogisticsdriver/location_service",
            binaryMessenger: messenger
        )
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "startLocationService":
                self.startTracking()
                result(nil)
            case "stopLocationService":
                self.stopTracking()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // EventChannel — GPS fix stream
        let eventChannel = FlutterEventChannel(
            name: "com.example.amlogisticsdriver/location_updates",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)
    }

    // MARK: - Tracking control
    private func startTracking() {
        guard !isTracking else { return }

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else if status == .authorizedWhenInUse {
            // Upgrade to Always so background updates are allowed
            locationManager.requestAlwaysAuthorization()
        }

        locationManager.startUpdatingLocation()
        isTracking = true
    }

    private func stopTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        isTracking = false
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let loc = locations.last, let sink = eventSink else { return }

        let payload: [String: Any] = [
            "latitude":  loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "accuracy":  loc.horizontalAccuracy,
            "timestamp": Int64(loc.timestamp.timeIntervalSince1970 * 1000)
        ]
        sink(payload)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Non-fatal — log and continue; the stream will resume on next fix
        print("[AMLocationManager] location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && isTracking {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - FlutterStreamHandler
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
