import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();


  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {

      final criticalPermissions = [
        Permission.camera,
        Permission.location,
      ];


      final storagePermissions = [
        Permission.photos, 
        Permission.storage, 
      ];


      final otherPermissions = [
        Permission.microphone,
      ];

      Map<Permission, PermissionStatus> statuses = {};
      

      for (Permission permission in criticalPermissions) {
        final status = await permission.request();
        statuses[permission] = status;
        print('Permission ${permission.toString()}: ${status.toString()}');
        
        if (!status.isGranted) {
          await _showPermissionDialog(context, permission);
        }
      }

      for (Permission permission in storagePermissions) {
        try {
          final status = await permission.request();
          statuses[permission] = status;
          print('Storage permission ${permission.toString()}: ${status.toString()}');
          

          if (permission == Permission.photos && status.isGranted) {
            break;
          }
        } catch (e) {
          print('Error requesting ${permission.toString()}: $e');

        }
      }

 
      for (Permission permission in otherPermissions) {
        final status = await permission.request();
        statuses[permission] = status;
        print('Permission ${permission.toString()}: ${status.toString()}');
      }

      bool criticalGranted = true;
      for (Permission permission in criticalPermissions) {
        if (!statuses[permission]!.isGranted) {
          criticalGranted = false;
          break;
        }
      }

  
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


  static bool _isCriticalPermission(Permission permission) {
    return [
      Permission.camera,
      Permission.location,
      Permission.storage,
      Permission.photos,
    ].contains(permission);
  }


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


  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }


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


  static Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }
}
