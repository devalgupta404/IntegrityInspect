import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionDebug {
  static Future<void> debugAllPermissions() async {
    print('=== PERMISSION DEBUG ===');
    
    final allPermissions = [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.microphone,
    ];

    for (Permission permission in allPermissions) {
      try {
        final status = await permission.status;
        print('${permission.toString()}: ${status.toString()}');
        
        // Try to request it
        final requestStatus = await permission.request();
        print('${permission.toString()} after request: ${requestStatus.toString()}');
      } catch (e) {
        print('Error with ${permission.toString()}: $e');
      }
    }
    
    print('=== END PERMISSION DEBUG ===');
  }

  static Future<Map<String, String>> getPermissionStatuses() async {
    Map<String, String> statuses = {};
    
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location,
      Permission.microphone,
    ];

    for (Permission permission in permissions) {
      try {
        final status = await permission.status;
        statuses[permission.toString()] = status.toString();
      } catch (e) {
        statuses[permission.toString()] = 'Error: $e';
      }
    }
    
    return statuses;
  }
}
