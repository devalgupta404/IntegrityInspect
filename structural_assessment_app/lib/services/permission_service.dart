import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request all required permissions for the structural assessment app
  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      // Request critical permissions first
      final criticalPermissions = [
        Permission.camera,
        Permission.location,
      ];

      // Request storage permissions based on Android version
      final storagePermissions = [
        Permission.photos, // For Android 13+ (API 33+)
        Permission.storage, // For older Android versions
      ];

      // Request microphone for video recording
      final otherPermissions = [
        Permission.microphone,
      ];

      Map<Permission, PermissionStatus> statuses = {};
      
      // Request critical permissions first
      for (Permission permission in criticalPermissions) {
        final status = await permission.request();
        statuses[permission] = status;
        print('Permission ${permission.toString()}: ${status.toString()}');
        
        if (!status.isGranted) {
          await _showPermissionDialog(context, permission);
        }
      }

      // Request storage permissions
      for (Permission permission in storagePermissions) {
        try {
          final status = await permission.request();
          statuses[permission] = status;
          print('Storage permission ${permission.toString()}: ${status.toString()}');
          
          // If photos permission is granted, we're good for storage
          if (permission == Permission.photos && status.isGranted) {
            break;
          }
        } catch (e) {
          print('Error requesting ${permission.toString()}: $e');
          // Continue with other permissions
        }
      }

      // Request other permissions
      for (Permission permission in otherPermissions) {
        final status = await permission.request();
        statuses[permission] = status;
        print('Permission ${permission.toString()}: ${status.toString()}');
      }

      // Check if critical permissions are granted
      bool criticalGranted = true;
      for (Permission permission in criticalPermissions) {
        if (!statuses[permission]!.isGranted) {
          criticalGranted = false;
          break;
        }
      }

      // Check if at least one storage permission is granted
      bool storageGranted = statuses[Permission.photos]?.isGranted == true || 
                           statuses[Permission.storage]?.isGranted == true;

      print('Critical permissions granted: $criticalGranted');
      print('Storage permissions granted: $storageGranted');

      return criticalGranted && storageGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if a permission is critical for app functionality
  static bool _isCriticalPermission(Permission permission) {
    return [
      Permission.camera,
      Permission.location,
      Permission.storage,
      Permission.photos, // Also critical for photo access
    ].contains(permission);
  }

  /// Show dialog explaining why permission is needed
  static Future<void> _showPermissionDialog(BuildContext context, Permission permission) async {
    String title = '';
    String message = '';

    switch (permission) {
      case Permission.camera:
        title = 'Camera Permission Required';
        message = 'This app needs camera access to capture photos of damaged structures for assessment.';
        break;
      case Permission.location:
        title = 'Location Permission Required';
        message = 'This app needs location access to record the exact coordinates of structural assessments.';
        break;
      case Permission.storage:
        title = 'Storage Permission Required';
        message = 'This app needs storage access to save assessment data and photos locally.';
        break;
      case Permission.photos:
        title = 'Photos Permission Required';
        message = 'This app needs access to photos to save and manage assessment images.';
        break;
      default:
        title = 'Permission Required';
        message = 'This permission is required for the app to function properly.';
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Check if specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Check all permissions status
  static Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.microphone,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (Permission permission in permissions) {
      statuses[permission] = await permission.status;
    }
    return statuses;
  }

  /// Request specific permission
  static Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }
}
