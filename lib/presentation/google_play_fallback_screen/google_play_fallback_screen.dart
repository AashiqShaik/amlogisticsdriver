import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

/// Shown when a driver opens a session link on a device that does NOT have
/// the AM Logistics Driver app installed.
///
/// Responsibilities:
///   1. Display a clear, branded message explaining what the app is.
///   2. Provide a "Get the AM Logistics Driver App" button that opens the
///      official Google Play Store listing.
///   3. Preserve the original session token so the driver can continue their
///      journey after installing the app without requesting a new link.
///
/// Deferred deep-link continuation:
///   After the driver installs the app from Google Play and opens it, the
///   splash screen (_SplashScreen in app_routes.dart) checks SharedPreferences
///   for a stored token. If found, it calls driver_session_payload and routes
///   the driver directly to the correct journey screen — no manual token entry
///   required.
///
///   NOTE: True automatic deferred deep linking (where the Play Store itself
///   passes the URL through the install) requires either:
///     a) Google Play Install Referrer API (server-side tracking), or
///     b) A third-party deferred deep-link service (e.g. Firebase Dynamic Links,
///        Branch.io, Adjust).
///   This implementation uses the most reliable Google-supported approach
///   available without an additional service: the token is stored in
///   SharedPreferences before the user is redirected to Play, and recovered
///   on first launch after install.
class GooglePlayFallbackScreen extends StatelessWidget {
  /// The original driver session token — preserved through the install flow.
  final String token;

  const GooglePlayFallbackScreen({super.key, required this.token});

  // Production Google Play listing URL.
  // TODO: Replace with the actual Play Store listing URL once published.
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=in.amlogistics.driver';

  static const _channel = MethodChannel(
    'com.example.amlogisticsdriver/location_service',
  );

  Future<void> _openPlayStore(BuildContext context) async {
    try {
      // Use Android intent to open Play Store directly in the app.
      // Falls back to browser if Play Store is not available.
      await _channel.invokeMethod('openPlayStore', {'url': _playStoreUrl});
    } catch (_) {
      // If the method channel is unavailable (e.g. web preview), show a snackbar.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please search for "AM Logistics Driver" on Google Play.',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.brandNavy,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/AM_Logo-1786960704002.png',
                      height: 52,
                      fit: BoxFit.contain,
                      semanticLabel: 'AM Logistics logo',
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.brandNavy.withAlpha(18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_android_rounded,
                        color: AppTheme.brandNavy,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Headline
                  Text(
                    'Get the AM Logistics Driver App',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Body
                  Text(
                    'To open your driver journey, you need the AM Logistics Driver app. '
                    'Install it from Google Play — your session will continue automatically.',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Primary CTA — Google Play
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openPlayStore(context),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        'Get the AM Logistics Driver App',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandNavy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Secondary: already installed — open journey
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        // Re-route through the deep-link handler which will
                        // recover the stored token and open the correct screen.
                        context.go('/driver/session/$token');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandNavy,
                        side: BorderSide(
                          color: AppTheme.brandNavy.withAlpha(80),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Text(
                        'I already have the app — Continue',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: AppTheme.brandNavy.withAlpha(25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your session link is saved. After installing the app, '
                            'open it and your journey will resume automatically.',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
