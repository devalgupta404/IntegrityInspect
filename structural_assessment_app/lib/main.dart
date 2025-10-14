import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/camera_service.dart';
import 'services/permission_service.dart';
import 'services/permission_debug.dart';
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
        home: const PermissionWrapper(),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _permissionsGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      // Debug permissions first
      await PermissionDebug.debugAllPermissions();
      
      // Add timeout to prevent hanging
      final granted = await PermissionService.requestAllPermissions(context)
          .timeout(const Duration(seconds: 30));
      
      if (mounted) {
        setState(() {
          _permissionsGranted = granted;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      if (mounted) {
        setState(() {
          _permissionsGranted = false;
          _isLoading = false;
        });
      }
    }
  }

  void _skipPermissions() {
    if (mounted) {
      setState(() {
        _permissionsGranted = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Requesting permissions...'),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs camera, location, and storage permissions to assess structural damage. Please grant these permissions to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _requestPermissions,
                  child: const Text('Grant Permissions'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open App Settings'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _skipPermissions,
                  child: const Text('Skip for Testing'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SplashScreen();
  }
}
