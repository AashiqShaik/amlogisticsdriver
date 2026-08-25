import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

enum JourneyStatusType {
  completed,
  expired,
  cancelled,
  reassigned,
  permissionDenied,
  locationServicesOff,
  networkError,
  invalidToken,
  locationPermissionPermanentlyDenied,
}

class JourneyStatusModel {
  final JourneyStatusType type;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String headline;
  final String subtext;
  final String? primaryButtonLabel;
  final String? secondaryButtonLabel;

  const JourneyStatusModel({
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.headline,
    required this.subtext,
    this.primaryButtonLabel,
    this.secondaryButtonLabel,
  });
}

class JourneyStatusScreen extends StatefulWidget {
  final String statusType;
  const JourneyStatusScreen({super.key, required this.statusType});

  @override
  State<JourneyStatusScreen> createState() => _JourneyStatusScreenState();
}

class _JourneyStatusScreenState extends State<JourneyStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const Map<String, JourneyStatusModel> _statusModels = {
    'completed': JourneyStatusModel(
      type: JourneyStatusType.completed,
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppTheme.success,
      iconBg: AppTheme.successMuted,
      headline: 'Journey completed',
      subtext:
          'Your consignment has been delivered. Thank you for completing this journey with AM Logistics.',
    ),
    'expired': JourneyStatusModel(
      type: JourneyStatusType.expired,
      icon: Icons.timer_off_outlined,
      iconColor: AppTheme.warning,
      iconBg: AppTheme.warningMuted,
      headline: 'Link expired',
      subtext:
          'This journey link is no longer valid. Please contact AM Logistics to receive a new link.',
      primaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'cancelled': JourneyStatusModel(
      type: JourneyStatusType.cancelled,
      icon: Icons.cancel_outlined,
      iconColor: AppTheme.error,
      iconBg: AppTheme.errorMuted,
      headline: 'Journey cancelled',
      subtext:
          'This consignment has been cancelled. Please contact AM Logistics if you have any questions.',
      primaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'reassigned': JourneyStatusModel(
      type: JourneyStatusType.reassigned,
      icon: Icons.swap_horiz_rounded,
      iconColor: AppTheme.info,
      iconBg: AppTheme.infoMuted,
      headline: 'Journey no longer available',
      subtext:
          'This journey has been reassigned. Please contact AM Logistics for your updated assignment.',
      primaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'permission_denied': JourneyStatusModel(
      type: JourneyStatusType.permissionDenied,
      icon: Icons.location_off_outlined,
      iconColor: AppTheme.error,
      iconBg: AppTheme.errorMuted,
      headline: 'Location access is required',
      subtext:
          'AM Logistics needs your location while this journey is active. Please allow location access to start tracking.',
      primaryButtonLabel: 'TRY AGAIN',
      secondaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'permission_permanently_denied': JourneyStatusModel(
      type: JourneyStatusType.locationPermissionPermanentlyDenied,
      icon: Icons.location_off_outlined,
      iconColor: AppTheme.error,
      iconBg: AppTheme.errorMuted,
      headline: 'Location access blocked',
      subtext:
          'Location access has been blocked. Open your phone\'s Settings, find AM Logistics Driver, and turn on Location.',
      primaryButtonLabel: 'TRY AGAIN',
      secondaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'location_off': JourneyStatusModel(
      type: JourneyStatusType.locationServicesOff,
      icon: Icons.gps_off_rounded,
      iconColor: AppTheme.warning,
      iconBg: AppTheme.warningMuted,
      headline: 'Turn on location',
      subtext:
          'Your phone\'s location service is currently turned off. Please turn it on to start journey tracking.',
      primaryButtonLabel: 'TRY AGAIN',
      secondaryButtonLabel: 'CALL AM LOGISTICS',
    ),
    'network_error': JourneyStatusModel(
      type: JourneyStatusType.networkError,
      icon: Icons.wifi_off_rounded,
      iconColor: AppTheme.warning,
      iconBg: AppTheme.warningMuted,
      headline: 'Connection problem',
      subtext:
          'We couldn\'t connect to AM Logistics. Please check your internet connection and try again.',
      primaryButtonLabel: 'TRY AGAIN',
    ),
    'invalid_token': JourneyStatusModel(
      type: JourneyStatusType.invalidToken,
      icon: Icons.link_off_rounded,
      iconColor: AppTheme.error,
      iconBg: AppTheme.errorMuted,
      headline: 'Link not valid',
      subtext:
          'This link does not appear to be valid. Please use the link sent to you by AM Logistics on WhatsApp.',
      primaryButtonLabel: 'CALL AM LOGISTICS',
    ),
  };

  JourneyStatusModel get _currentStatus =>
      _statusModels[widget.statusType] ?? _statusModels['invalid_token']!;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _onPrimaryAction() {
    switch (widget.statusType) {
      case 'permission_denied':
      case 'permission_permanently_denied':
      case 'location_off':
      case 'network_error':
        context.go(AppRoutes.journeyReadyScreen);
        break;
      default:
        // TODO: Open phone dialer to AM Logistics
        break;
    }
  }

  void _onSecondaryAction() {
    // TODO: Open phone dialer to AM Logistics
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Icon
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: status.iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  status.icon,
                                  color: status.iconColor,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Title
                            Text(
                              status.headline,
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            // Body
                            Text(
                              status.subtext,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            // Button stack
                            if (status.primaryButtonLabel != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _onPrimaryAction,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.brandNavy,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _primaryIcon(widget.statusType),
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            status.primaryButtonLabel!,
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (status.secondaryButtonLabel != null) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 56,
                                      child: OutlinedButton(
                                        onPressed: _onSecondaryAction,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.textPrimary,
                                          side: const BorderSide(
                                            color: AppTheme.border,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              status.secondaryButtonLabel!,
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
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

  IconData _primaryIcon(String statusType) {
    switch (statusType) {
      case 'permission_denied':
      case 'permission_permanently_denied':
      case 'location_off':
      case 'network_error':
        return Icons.refresh_rounded;
      default:
        return Icons.phone_outlined;
    }
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
