import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a single GPS fix received from the native location service.
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() =>
      'LocationUpdate(lat=$latitude, lng=$longitude, acc=${accuracy}m)';
}

/// Bridges Flutter to the native location service on both Android and iOS via
/// a MethodChannel (commands) and an EventChannel (location stream).
///
/// Android: delegates to LocationForegroundService (persistent notification,
///          FusedLocationProviderClient, continues while screen is locked).
///
/// iOS:     delegates to AMLocationManager (CLLocationManager with
///          allowsBackgroundLocationUpdates = true, continues while
///          backgrounded or screen is locked).
///
/// On web the service calls are no-ops and the stream emits nothing.
class LocationServiceChannel {
  LocationServiceChannel._();

  static final LocationServiceChannel instance = LocationServiceChannel._();

  static const _methodChannel = MethodChannel(
    'com.example.amlogisticsdriver/location_service',
  );
  static const _eventChannel = EventChannel(
    'com.example.amlogisticsdriver/location_updates',
  );

  StreamSubscription<dynamic>? _rawSub;
  final StreamController<LocationUpdate> _controller =
      StreamController<LocationUpdate>.broadcast();

  /// Live stream of GPS fixes while the native location service is running.
  Stream<LocationUpdate> get locationStream => _controller.stream;

  /// Starts the native location service (Android foreground service /
  /// iOS Core Location background session) and begins streaming GPS updates.
  /// Safe to call multiple times (idempotent on the native side).
  Future<void> startService() async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('startLocationService');
      _listenToEvents();
    } on PlatformException catch (e) {
      debugPrint('[LocationServiceChannel] startService error: $e');
    }
  }

  /// Stops the native location service and cancels the GPS stream.
  Future<void> stopService() async {
    if (!_isSupported) return;
    try {
      await _rawSub?.cancel();
      _rawSub = null;
      await _methodChannel.invokeMethod<void>('stopLocationService');
    } on PlatformException catch (e) {
      debugPrint('[LocationServiceChannel] stopService error: $e');
    }
  }

  void _listenToEvents() {
    _rawSub?.cancel();
    _rawSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          try {
            final update = LocationUpdate(
              latitude: (event['latitude'] as num).toDouble(),
              longitude: (event['longitude'] as num).toDouble(),
              accuracy: (event['accuracy'] as num).toDouble(),
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                (event['timestamp'] as num).toInt(),
              ),
            );
            _controller.add(update);
          } catch (e) {
            debugPrint('[LocationServiceChannel] parse error: $e');
          }
        }
      },
      onError: (dynamic err) {
        debugPrint('[LocationServiceChannel] stream error: $err');
      },
    );
  }

  /// True on Android and iOS (native location services available).
  /// False on web and other unsupported platforms.
  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
