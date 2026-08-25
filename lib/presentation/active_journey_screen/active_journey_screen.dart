import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/location_service_channel.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class ActiveJourneyScreen extends StatefulWidget {
  /// Passed from JourneyReadyScreen as extra: {'token': String, 'payload': DriverSessionPayload}
  final String token;
  final DriverSessionPayload payload;

  const ActiveJourneyScreen({
    super.key,
    required this.token,
    required this.payload,
  });

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen>
    with SingleTickerProviderStateMixin {
  bool _isEnding = false;
  bool _isStarting = false;
  bool _journeyStarted = false;
  String? _startError;

  late AnimationController _dotController;
  late Animation<double> _dotAnimation;

  /// Subscription to the foreground service location stream.
  StreamSubscription<LocationUpdate>? _locationSub;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _dotAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dotController, curve: Curves.easeInOut));

    // If the session is already active (resumed), mark as started
    if (widget.payload.status == 'active' ||
        widget.payload.status == 'paused') {
      _journeyStarted = true;
      // Resume foreground service for an already-active session
      LocationServiceChannel.instance.startService().then((_) {
        _startLocationTracking();
      });
    } else {
      // Pending — need to call driver_start_journey
      _callStartJourney();
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
    _dotController.dispose();
    super.dispose();
  }

  /// Subscribes to the GPS stream and uploads each fix via driver_record_location.
  void _startLocationTracking() {
    _locationSub?.cancel();
    _locationSub = LocationServiceChannel.instance.locationStream.listen(
      (LocationUpdate update) async {
        final recordedAt = update.timestamp.toUtc().toIso8601String();
        await SupabaseService.instance.recordLocation(
          token: widget.token,
          lat: update.latitude,
          lng: update.longitude,
          accuracy: update.accuracy,
          recordedAt: recordedAt,
        );
      },
      onError: (dynamic err) {
        debugPrint('[ActiveJourneyScreen] location stream error: $err');
      },
    );
  }

  /// Calls driver_start_journey with a real GPS fix from the foreground service.
  Future<void> _callStartJourney() async {
    setState(() {
      _isStarting = true;
      _startError = null;
    });

    // Use current timestamp for recorded_at
    final recordedAt = DateTime.now().toUtc().toIso8601String();

    // NOTE: In production, obtain real GPS coordinates before calling this.
    // Placeholder coordinates are used here for the RPC call structure.
    // The actual GPS integration (geolocator/location package) should provide
    // real lat/lng/accuracy values.
    final result = await SupabaseService.instance.startJourney(
      token: widget.token,
      lat: 0.0, // Replace with real GPS latitude
      lng: 0.0, // Replace with real GPS longitude
      accuracy: 0.0, // Replace with real GPS accuracy
      recordedAt: recordedAt,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isStarting = false;
        _startError = result.error;
      });
      return;
    }

    // Start foreground location service now that journey is confirmed active
    await LocationServiceChannel.instance.startService();

    // Begin uploading GPS observations to the backend
    _startLocationTracking();

    setState(() {
      _isStarting = false;
      _journeyStarted = true;
    });
  }

  void _onEndJourney() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(128),
      builder: (ctx) => _EndJourneyDialog(
        onConfirm: () async {
          Navigator.of(ctx).pop();
          setState(() => _isEnding = true);

          // Stop uploading location observations before ending the session
          await _locationSub?.cancel();
          _locationSub = null;

          final result = await SupabaseService.instance.setSessionState(
            token: widget.token,
            state: 'end',
          );

          if (!mounted) return;

          if (!result.success) {
            setState(() => _isEnding = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.error ?? 'Could not end journey. Please try again.',
                  style: GoogleFonts.manrope(fontSize: 13),
                ),
                backgroundColor: AppTheme.error,
              ),
            );
            return;
          }

          // Stop foreground location service before navigating away
          await LocationServiceChannel.instance.stopService();

          // Backend confirmed — clear token and navigate
          await SupabaseService.instance.clearToken();
          if (mounted) {
            context.go(AppRoutes.journeyStatusScreen, extra: 'completed');
          }
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;

    if (_isStarting) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _AppHeader(),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.brandNavy,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_startError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _AppHeader(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not start journey',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _startError!,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _callStartJourney,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'TRY AGAIN',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LiveStatusHeader(dotAnimation: _dotAnimation),
                          const SizedBox(height: 20),
                          _MapPanel(),
                          const SizedBox(height: 16),
                          _TrackingDetailCard(
                            route:
                                '${payload.pickupCity} → ${payload.destinationCity}',
                            consignment: payload.consignmentNumber,
                          ),
                          const SizedBox(height: 20),
                          _SafetyNote(),
                          const SizedBox(height: 28),
                          _EndJourneyButton(
                            isEnding: _isEnding,
                            onPressed: _onEndJourney,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: Image.asset(
          'assets/images/AM_Logo-1786960704002.png',
          height: 32,
          fit: BoxFit.contain,
          semanticLabel: 'AM Logistics logo',
        ),
      ),
    );
  }
}

// ─── Live Status Header ───────────────────────────────────────────────────────

class _LiveStatusHeader extends StatelessWidget {
  final Animation<double> dotAnimation;
  const _LiveStatusHeader({required this.dotAnimation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: dotAnimation,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TRACKING ACTIVE',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Journey in progress',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your location is being shared with AM Logistics.',
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Map Panel ────────────────────────────────────────────────────────────────

class _MapPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 256,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8EDF5), Color(0xFFD4DCE8)],
              ),
            ),
          ),
          CustomPaint(size: Size.infinite, painter: _MapGridPainter()),
          Center(
            child: CustomPaint(
              size: const Size(280, 180),
              painter: _RouteLinePainter(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tracking active',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.brandAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandAccent.withAlpha(102),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: AbsorbPointer(child: Container(color: Colors.transparent)),
          ),
          Positioned(
            bottom: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Live location',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withAlpha(77)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.brandNavy.withAlpha(153)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.15);
    path.cubicTo(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.4,
      size.height * 0.4,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.6,
      size.height * 0.6,
      size.width * 0.8,
      size.height * 0.7,
      size.width * 0.9,
      size.height * 0.85,
    );
    canvas.drawPath(path, paint);

    final completedPaint = Paint()
      ..color = AppTheme.brandAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final completedPath = Path();
    completedPath.moveTo(size.width * 0.1, size.height * 0.15);
    completedPath.cubicTo(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.4,
      size.height * 0.4,
      size.width * 0.5,
      size.height * 0.5,
    );
    canvas.drawPath(completedPath, completedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Tracking Detail Card ─────────────────────────────────────────────────────

class _TrackingDetailCard extends StatelessWidget {
  final String route;
  final String consignment;
  const _TrackingDetailCard({required this.route, required this.consignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        children: [
          _Row(label: 'Route', value: route),
          const Divider(height: 1, color: AppTheme.border),
          _Row(label: 'Consignment', value: consignment),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Safety Note ──────────────────────────────────────────────────────────────

class _SafetyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.warningMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For your safety, do not use your phone while driving.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── End Journey Button ───────────────────────────────────────────────────────

class _EndJourneyButton extends StatelessWidget {
  final bool isEnding;
  final VoidCallback onPressed;
  const _EndJourneyButton({required this.isEnding, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isEnding ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: const BorderSide(color: AppTheme.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          isEnding ? 'Please wait…' : 'END JOURNEY',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── End Journey Dialog ───────────────────────────────────────────────────────

class _EndJourneyDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _EndJourneyDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.errorMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.stop_circle_outlined,
                color: AppTheme.error,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'End this journey?',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location tracking will stop and your journey will be marked as complete.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'End Journey',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  'Keep Tracking',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
