import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class JourneyReadyScreen extends StatefulWidget {
  /// The driver token extracted from the deep-link URL.
  /// If null, the screen will attempt to load a stored token.
  final String? token;
  const JourneyReadyScreen({super.key, this.token});

  @override
  State<JourneyReadyScreen> createState() => _JourneyReadyScreenState();
}

class _JourneyReadyScreenState extends State<JourneyReadyScreen> {
  bool _isLoading = true;
  bool _isStarting = false;
  String? _errorMessage;
  DriverSessionPayload? _payload;
  String? _activeToken;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Prefer token from deep-link; fall back to stored token
    String? token = widget.token;
    if (token == null || token.isEmpty) {
      token = await SupabaseService.instance.getStoredToken();
    }

    if (token == null || token.isEmpty) {
      if (mounted) {
        context.go(AppRoutes.journeyStatusScreen, extra: 'invalid_token');
      }
      return;
    }

    // Store the token securely (never log it)
    await SupabaseService.instance.storeToken(token);
    _activeToken = token;

    final result = await SupabaseService.instance.getSessionPayload(token);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
      return;
    }

    final payload = result.data!;

    // Route based on backend-authoritative session status
    switch (payload.status) {
      case 'active':
        // Journey already started — go directly to active screen
        context.go(
          AppRoutes.activeJourneyScreen,
          extra: {'token': token, 'payload': payload},
        );
        return;
      case 'completed':
        context.go(AppRoutes.journeyStatusScreen, extra: 'completed');
        return;
      case 'expired':
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'expired');
        return;
      case 'paused':
        // Paused journey — resume from active screen
        context.go(
          AppRoutes.activeJourneyScreen,
          extra: {'token': token, 'payload': payload},
        );
        return;
      case 'pending':
        // Show the journey ready screen
        setState(() {
          _isLoading = false;
          _payload = payload;
        });
        break;
      default:
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'invalid_token');
        return;
    }
  }

  void _onStartJourney() async {
    if (_activeToken == null || _payload == null) return;

    // Step 1: Check current permission status
    final status = await Permission.locationWhenInUse.status;

    if (status.isPermanentlyDenied) {
      // Permission was permanently denied — guide user to settings
      if (!mounted) return;
      await _showPermissionSettingsDialog();
      return;
    }

    if (!status.isGranted) {
      // Step 2: Show rationale dialog before triggering the native prompt
      if (!mounted) return;
      final shouldRequest = await _showLocationRationaleDialog();
      if (!mounted) return;
      if (!shouldRequest) return;

      // Step 3: Trigger the native iOS/Android permission prompt
      final result = await Permission.locationWhenInUse.request();
      if (!mounted) return;

      if (!result.isGranted) {
        if (result.isPermanentlyDenied) {
          await _showPermissionSettingsDialog();
        }
        return;
      }
    }

    // Permission granted — proceed
    setState(() => _isStarting = true);
    if (mounted) {
      context.go(
        AppRoutes.activeJourneyScreen,
        extra: {'token': _activeToken!, 'payload': _payload!},
      );
    }
  }

  Future<bool> _showLocationRationaleDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 28,
                    color: AppTheme.brandNavy,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Location Access Required',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'AM Logistics needs your location during the active journey to track delivery progress and keep your dispatcher informed in real time.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Not Now',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Allow Location',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showPermissionSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 28,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Location Permission Denied',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'To start the journey, please enable location access for AM Logistics in your device settings.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _AppHeader(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.brandNavy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
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
                          'Connection problem',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadSession,
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

    final payload = _payload!;

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
                          _JourneyHeading(),
                          const SizedBox(height: 24),
                          _DetailCard(
                            rows: [
                              _DetailRow(
                                label: 'Consignment',
                                value: payload.consignmentNumber,
                              ),
                              _DetailRow(
                                label: 'Driver',
                                value: payload.driverName,
                              ),
                              _DetailRow(
                                label: 'Vehicle',
                                value: payload.vehicleReg,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _RouteCard(
                            pickup: payload.pickupCity,
                            destination: payload.destinationCity,
                          ),
                          const SizedBox(height: 28),
                          _StartJourneyButton(
                            isStarting: _isStarting,
                            onPressed: _onStartJourney,
                          ),
                          const SizedBox(height: 20),
                          _SafetyNote(),
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

// ─── Heading ──────────────────────────────────────────────────────────────────

class _JourneyHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your journey is ready',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review the details below and start tracking before you begin driving.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Detail Card ──────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<_DetailRow> rows;
  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .map(
              (entry) => Column(
                children: [
                  entry.value,
                  if (entry.key < rows.length - 1)
                    const Divider(height: 1, color: AppTheme.border),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

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
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final String pickup;
  final String destination;
  const _RouteCard({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.brandAccent,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 36, color: AppTheme.border),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.brandNavy,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  destination,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'From',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'To',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Start Journey Button ─────────────────────────────────────────────────────

class _StartJourneyButton extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onPressed;
  const _StartJourneyButton({
    required this.isStarting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: isStarting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandNavy,
          disabledBackgroundColor: AppTheme.brandNavy.withAlpha(153),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isStarting)
              const Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: Colors.white,
              ),
            if (!isStarting) const SizedBox(width: 8),
            Text(
              isStarting ? 'STARTING…' : 'START JOURNEY',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
