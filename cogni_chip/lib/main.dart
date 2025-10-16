import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/camera_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  await _initializeServices();

  runApp(const StructuralAssessmentApp());
}

Future<void> _initializeServices() async {
  try {
    // Initialize local storage
    await LocalStorageService().init();

    // Initialize cameras
    await CameraService().initializeCameras();

    print('All services initialized successfully');
  } catch (e) {
    print('Error initializing services: $e');
  }
}

class StructuralAssessmentApp extends StatelessWidget {
  const StructuralAssessmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add providers here as needed
        Provider<LocalStorageService>(
          create: (_) => LocalStorageService(),
        ),
        Provider<CameraService>(
          create: (_) => CameraService(),
        ),
      ],
      child: MaterialApp(
        title: 'Integrity Inspect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
