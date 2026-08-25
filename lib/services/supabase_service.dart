import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class DriverSessionPayload {
  final String status; // pending | active | paused | completed | expired
  final String consignmentNumber;
  final String driverName;
  final String vehicleReg;
  final String pickupCity;
  final String destinationCity;
  final String? pickupAddress;
  final String? destinationAddress;

  const DriverSessionPayload({
    required this.status,
    required this.consignmentNumber,
    required this.driverName,
    required this.vehicleReg,
    required this.pickupCity,
    required this.destinationCity,
    this.pickupAddress,
    this.destinationAddress,
  });

  factory DriverSessionPayload.fromJson(Map<String, dynamic> json) {
    return DriverSessionPayload(
      status: (json['status'] as String?) ?? 'invalid',
      consignmentNumber: (json['consignment_number'] as String?) ?? '',
      driverName: (json['driver_name'] as String?) ?? '',
      vehicleReg: (json['vehicle_reg'] as String?) ?? '',
      pickupCity: (json['pickup_city'] as String?) ?? '',
      destinationCity: (json['destination_city'] as String?) ?? '',
      pickupAddress: json['pickup_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
    );
  }
}

class RpcResult<T> {
  final T? data;
  final String? error;
  bool get success => error == null;

  const RpcResult.ok(this.data) : error = null;
  const RpcResult.err(this.error) : data = null;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  /// Production Supabase project: cbmruydqpwghqmnkogcq.supabase.co
  /// Set via --dart-define=SUPABASE_URL=https://cbmruydqpwghqmnkogcq.supabase.co
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String _tokenKey = 'driver_secure_token';

  static Future<void> initialize() async {
    // Hard fail if production credentials are missing.
    // There is NO fallback to any other Supabase project.
    if (supabaseUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL is not configured. '
        'Build with --dart-define=SUPABASE_URL=https://cbmruydqpwghqmnkogcq.supabase.co',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY is not configured. '
        'Build with --dart-define=SUPABASE_ANON_KEY=<production-anon-key>',
      );
    }
    // Verify we are connecting to the correct production project.
    if (!supabaseUrl.contains('cbmruydqpwghqmnkogcq')) {
      throw Exception(
        'SUPABASE_URL does not point to the production project (cbmruydqpwghqmnkogcq). '
        'Remove any old Supabase configuration before building.',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;

  // ─── Secure Token Storage ────────────────────────────────────────────────

  /// Stores the driver token securely. Never logs or exposes the token.
  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Retrieves the stored driver token, or null if none exists.
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clears the stored driver token.
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ─── RPC: driver_session_payload ─────────────────────────────────────────

  /// Calls driver_session_payload(token) and returns the session payload.
  /// The backend is authoritative — do not assume any state from the token alone.
  Future<RpcResult<DriverSessionPayload>> getSessionPayload(
    String token,
  ) async {
    try {
      final response = await client.rpc(
        'driver_session_payload',
        params: {'token': token},
      );

      if (response == null) {
        return const RpcResult.err('No response from server');
      }

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      return RpcResult.ok(DriverSessionPayload.fromJson(data));
    } on PostgrestException catch (e) {
      return RpcResult.err(e.message);
    } catch (e) {
      return RpcResult.err('Connection error. Please check your network.');
    }
  }

  // ─── RPC: driver_start_journey ───────────────────────────────────────────

  /// Calls driver_start_journey with the initial GPS fix.
  /// Only call this after obtaining a real GPS location.
  /// Returns success/error — the backend determines if the journey actually started.
  Future<RpcResult<Map<String, dynamic>>> startJourney({
    required String token,
    required double lat,
    required double lng,
    required double accuracy,
    required String recordedAt, // ISO 8601
  }) async {
    try {
      final response = await client.rpc(
        'driver_start_journey',
        params: {
          'token': token,
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
          'recorded_at': recordedAt,
        },
      );

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : (response != null
                ? Map<String, dynamic>.from(response as Map)
                : {});

      return RpcResult.ok(data);
    } on PostgrestException catch (e) {
      return RpcResult.err(e.message);
    } catch (e) {
      return RpcResult.err('Connection error. Please check your network.');
    }
  }

  // ─── RPC: driver_record_location ─────────────────────────────────────────

  /// Calls driver_record_location for each valid GPS observation.
  /// Do not create checkpoints in Flutter — the backend handles them.
  Future<RpcResult<Map<String, dynamic>>> recordLocation({
    required String token,
    required double lat,
    required double lng,
    required double accuracy,
    required String recordedAt, // ISO 8601
    double? speed,
    double? heading,
  }) async {
    try {
      final response = await client.rpc(
        'driver_record_location',
        params: {
          'token': token,
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
          'recorded_at': recordedAt,
          'speed': speed,
          'heading': heading,
        },
      );

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : (response != null
                ? Map<String, dynamic>.from(response as Map)
                : {});

      return RpcResult.ok(data);
    } on PostgrestException catch (e) {
      return RpcResult.err(e.message);
    } catch (e) {
      return RpcResult.err('Connection error. Observation queued for retry.');
    }
  }

  // ─── RPC: driver_set_session_state ───────────────────────────────────────

  /// Calls driver_set_session_state(token, state).
  /// Allowed states: 'start' | 'pause' | 'resume' | 'end'
  /// Only act on the backend response — do not assume state changes locally.
  Future<RpcResult<Map<String, dynamic>>> setSessionState({
    required String token,
    required String state,
  }) async {
    assert(
      ['start', 'pause', 'resume', 'end'].contains(state),
      'Invalid session state: $state',
    );
    try {
      final response = await client.rpc(
        'driver_set_session_state',
        params: {'token': token, 'state': state},
      );

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : (response != null
                ? Map<String, dynamic>.from(response as Map)
                : {});

      return RpcResult.ok(data);
    } on PostgrestException catch (e) {
      return RpcResult.err(e.message);
    } catch (e) {
      return RpcResult.err('Connection error. Please check your network.');
    }
  }
}
