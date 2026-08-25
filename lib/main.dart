import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import './services/supabase_service.dart';
import './theme/app_theme.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';

// ── Deep-link channel name (must match MainActivity.kt) ──────────────────────
const String _deepLinkChannel = 'in.amlogistics.driver/deep_link';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });
      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // Mobile-only: orientation lock and system UI styling
  // These APIs are not supported on Flutter Web and must be guarded.
  if (!kIsWeb) {
    await Future.wait([
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      Future(
        () => SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppTheme.background,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
    ]);
  }

  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _channel = MethodChannel(_deepLinkChannel);

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// Sets up the MethodChannel callback that receives warm-start deep-link
  /// URIs from MainActivity.onNewIntent (app already running).
  void _initDeepLinks() {
    if (kIsWeb) return; // Deep-link channel is Android/iOS only

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final uri = call.arguments as String?;
        if (uri != null && uri.isNotEmpty) {
          _handleIncomingUri(uri);
        }
      }
    });
  }

  /// Parses an incoming URI and navigates to the correct route.
  /// Handles both:
  ///   https://amlogistics.co.in/driver/session/<TOKEN>
  ///   amlogistics://driver/session/<TOKEN>
  void _handleIncomingUri(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      final segments = uri.pathSegments;

      // Match /driver/session/<TOKEN>
      if (segments.length >= 3 &&
          segments[0] == 'driver' &&
          segments[1] == 'session') {
        final token = segments[2];
        if (token.isNotEmpty) {
          appRouter.go('/driver/session/$token');
        }
      }
    } catch (_) {
      // Malformed URI — ignore silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp.router(
          title: 'AM Logistics Driver',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
        );
      },
    );
  }
}
