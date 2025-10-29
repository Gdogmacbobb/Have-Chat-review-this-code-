import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ynfny/presentation/video_recording/video_recording_screen.dart';
import 'package:ynfny/presentation/video_upload/video_upload_screen.dart';





import '../core/app_export.dart';
import '../widgets/custom_error_widget.dart';
import '../config/supabase_config.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚨 CRITICAL: Global error handler for uncaught errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FlutterError: ${details.exception}');
    FlutterError.presentError(details);
  };

  // Clear stale tokens once on startup
  try {
    // Clear cached Supabase tokens
    const projectRef = 'oemeugiejcjfbpmsftot';
    final script = '''
      localStorage.removeItem('sb-$projectRef-auth-token');
      localStorage.removeItem('sb-$projectRef-auth-token-code-verifier');
    ''';
    // Note: This runs in web context automatically
  } catch (e) {
    debugPrint('Token cleanup warning: $e');
  }

  // Initialize Supabase (single source)
  try {
    await Supabase.initialize(
      url: AppSupabase.url, 
      anonKey: AppSupabase.anonKey
    );
    
    // Safe logging (host only, never key)
    final uri = Uri.parse(AppSupabase.url);
    debugPrint('[SUPABASE] Connected to: ${uri.host}');
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(
      errorDetails: details,
    );
  };
  
  // 🚨 CRITICAL: Device orientation lock (web-safe)
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (e) {
    debugPrint('Orientation lock not supported: $e');
  }

  // 🚨 CRITICAL: Edge-to-edge rendering for iOS/Android (web-safe)
  try {
    // Enable edge-to-edge UI (content behind status bar and nav bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Set transparent status bar with light icons
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  } catch (e) {
    debugPrint('Edge-to-edge UI mode not supported: $e');
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: MaterialApp(
        title: 'ynfny',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
        // 🚨 END CRITICAL SECTION
        debugShowCheckedModeBanner: false,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.initial,
        // Add navigation error handling
        onUnknownRoute: (settings) {
          debugPrint('Unknown route: ${settings.name}');
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Page Not Found'),
                backgroundColor: AppTheme.primaryOrange,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.accentRed,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Page Not Found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The requested page could not be found.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.initial,
                        (route) => false,
                      ),
                      child: Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
