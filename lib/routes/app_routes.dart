import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../presentation/active_journey_screen/active_journey_screen.dart';
import '../presentation/journey_ready_screen/journey_ready_screen.dart';
import '../presentation/journey_status_screen/journey_status_screen.dart';
import '../presentation/google_play_fallback_screen/google_play_fallback_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AppRoutes {
  static const String initial = '/';
  static const String journeyReadyScreen = '/journey-ready-screen';
  static const String activeJourneyScreen = '/active-journey-screen';
  static const String journeyStatusScreen = '/journey-status-screen';
  static const String googlePlayFallback = '/driver/install/:token';
  // Deep-link entry point — matches https://amlogistics.co.in/driver/session/<TOKEN>
  static const String driverSession = '/driver/session/:token';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const _SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    // ── Deep-link handler: /driver/session/<TOKEN> ──────────────────────────
    GoRoute(
      path: AppRoutes.driverSession,
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: _DeepLinkHandlerScreen(token: token),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
    // ── Google Play fallback: shown when app is not installed ───────────────
    GoRoute(
      path: AppRoutes.googlePlayFallback,
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: GooglePlayFallbackScreen(token: token),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.journeyReadyScreen,
      pageBuilder: (context, state) {
        // Optional token passed via extra (e.g. from deep-link)
        final token = state.extra as String?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: JourneyReadyScreen(token: token),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.activeJourneyScreen,
      pageBuilder: (context, state) {
        // Expects extra: {'token': String, 'payload': DriverSessionPayload}
        final extra = state.extra as Map<String, dynamic>?;
        final token = extra?['token'] as String? ?? '';
        final payload =
            extra?['payload'] as DriverSessionPayload? ??
            const DriverSessionPayload(
              status: 'active',
              consignmentNumber: '',
              driverName: '',
              vehicleReg: '',
              pickupCity: '',
              destinationCity: '',
            );
        return CustomTransitionPage(
          key: state.pageKey,
          child: ActiveJourneyScreen(token: token, payload: payload),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.journeyStatusScreen,
      pageBuilder: (context, state) {
        final statusType = state.extra as String? ?? 'completed';
        return CustomTransitionPage(
          key: state.pageKey,
          child: JourneyStatusScreen(statusType: statusType),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
  ],
);

// ─── Deep-Link Handler Screen ─────────────────────────────────────────────────
//
// Shown when the app is opened via https://amlogistics.co.in/driver/session/<TOKEN>.
// Responsibilities:
//   1. Validate the token is non-empty.
//   2. Store the token securely (no logging, no display).
//   3. Call driver_session_payload with the token.
//   4. Route to the correct screen based on the authoritative backend response.

class _DeepLinkHandlerScreen extends StatefulWidget {
  final String token;
  const _DeepLinkHandlerScreen({required this.token});

  @override
  State<_DeepLinkHandlerScreen> createState() => _DeepLinkHandlerScreenState();
}

class _DeepLinkHandlerScreenState extends State<_DeepLinkHandlerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Process the deep-link token immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
  }

  Future<void> _handleDeepLink() async {
    if (!mounted) return;

    final token = widget.token.trim();

    // Guard: empty or obviously invalid token
    if (token.isEmpty) {
      if (mounted) {
        context.go(AppRoutes.journeyStatusScreen, extra: 'invalid_token');
      }
      return;
    }

    // Store the token securely — never log or display it.
    // This enables deferred deep-link recovery after a Play Store install:
    // the splash screen reads this stored token on first launch.
    await SupabaseService.instance.storeToken(token);

    if (!mounted) return;

    // Call the backend — it is the sole authority on session state
    final result = await SupabaseService.instance.getSessionPayload(token);

    if (!mounted) return;

    if (!result.success) {
      // Network / server error — go to ready screen which will retry
      context.go(AppRoutes.journeyReadyScreen);
      return;
    }

    final payload = result.data!;

    switch (payload.status) {
      case 'pending':
        // Journey not yet started — show the ready screen
        context.go(AppRoutes.journeyReadyScreen, extra: token);
        break;
      case 'active':
      case 'paused':
        // Journey already in progress — resume it
        context.go(
          AppRoutes.activeJourneyScreen,
          extra: {'token': token, 'payload': payload},
        );
        break;
      case 'completed':
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'completed');
        break;
      case 'expired':
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'expired');
        break;
      default:
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'invalid_token');
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/AM_Logo-1786960704002.png',
                height: 56,
                fit: BoxFit.contain,
                semanticLabel: 'AM Logistics logo',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.brandNavy.withAlpha(102),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verifying your session…',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Splash / Session Recovery Screen ────────────────────────────────────────
//
// On first launch after a Play Store install, this screen checks for a stored
// token (saved before the driver was redirected to Play Store) and recovers
// the original driver session automatically — no manual token entry required.

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  static const MethodChannel _deepLinkChannel = MethodChannel(
    'in.amlogistics.driver/deep_link',
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Check for a cold-start deep-link URI first, then fall back to stored token
    Future.delayed(const Duration(milliseconds: 400), _checkColdStartLink);
  }

  /// Checks whether the app was launched by tapping an App Link (cold start).
  /// If so, navigates directly to the deep-link route.
  /// Otherwise falls back to stored-token session recovery.
  Future<void> _checkColdStartLink() async {
    if (!mounted) return;

    // Ask the native side for the URI that launched the activity
    String? initialUri;
    try {
      if (!kIsWeb) {
        initialUri = await _deepLinkChannel.invokeMethod<String>(
          'getInitialLink',
        );
      }
    } catch (_) {
      initialUri = null;
    }

    if (initialUri != null && initialUri.isNotEmpty) {
      final uri = Uri.tryParse(initialUri);
      final segments = uri?.pathSegments ?? [];
      // Match /driver/session/<TOKEN>
      if (segments.length >= 3 &&
          segments[0] == 'driver' &&
          segments[1] == 'session') {
        final token = segments[2];
        if (token.isNotEmpty && mounted) {
          // Navigate via the deep-link handler route — it will call the backend
          context.go('/driver/session/$token');
          return;
        }
      }
    }

    // No cold-start deep-link — attempt deferred session recovery
    Future.delayed(const Duration(milliseconds: 800), _recoverSession);
  }

  /// Checks for a stored token and calls driver_session_payload to determine
  /// the current session state. Routes accordingly.
  /// This is the deferred deep-link recovery mechanism: if the driver was
  /// redirected to Play Store before installing, the token stored in
  /// SharedPreferences is recovered here on first launch.
  Future<void> _recoverSession() async {
    if (!mounted) return;

    final token = await SupabaseService.instance.getStoredToken();

    if (token == null || token.isEmpty) {
      // No stored token — show journey ready screen (will show invalid_token state)
      if (mounted) context.go(AppRoutes.journeyReadyScreen);
      return;
    }

    final result = await SupabaseService.instance.getSessionPayload(token);

    if (!mounted) return;

    if (!result.success) {
      // Network error — go to ready screen which will retry
      context.go(AppRoutes.journeyReadyScreen);
      return;
    }

    final payload = result.data!;

    switch (payload.status) {
      case 'active':
      case 'paused':
        // Resume active journey
        context.go(
          AppRoutes.activeJourneyScreen,
          extra: {'token': token, 'payload': payload},
        );
        break;
      case 'pending':
        // Show journey ready screen
        context.go(AppRoutes.journeyReadyScreen, extra: token);
        break;
      case 'completed':
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'completed');
        break;
      case 'expired':
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'expired');
        break;
      default:
        await SupabaseService.instance.clearToken();
        context.go(AppRoutes.journeyStatusScreen, extra: 'invalid_token');
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/AM_Logo-1786960704002.png',
                height: 56,
                fit: BoxFit.contain,
                semanticLabel: 'AM Logistics logo',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.brandNavy.withAlpha(102),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Opening your journey…',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
