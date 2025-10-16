class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'OPENAI_API_KEY'; // Replace with actual URL
  static const String apiVersion = 'v1';

  // Building Types
  static const List<String> buildingTypes = [
    'residential',
    'commercial',
    'industrial',
    'mixed_use',
  ];

  static const Map<String, String> buildingTypeLabels = {
    'residential': 'Residential',
    'commercial': 'Commercial',
    'industrial': 'Industrial',
    'mixed_use': 'Mixed Use',
  };

  // Material Types
  static const List<String> materialTypes = [
    'concrete',
    'brick',
    'steel',
    'wood',
    'mixed',
  ];

  static const Map<String, String> materialTypeLabels = {
    'concrete': 'Concrete',
    'brick': 'Brick',
    'steel': 'Steel',
    'wood': 'Wood',
    'mixed': 'Mixed Materials',
  };

  // Damage Types
  static const List<String> damageTypes = [
    'cracks',
    'tilting',
    'partial_collapse',
    'column_damage',
    'wall_damage',
    'foundation_issues',
    'roof_damage',
    'window_breakage',
  ];

  static const Map<String, String> damageTypeLabels = {
    'cracks': 'Cracks',
    'tilting': 'Tilting',
    'partial_collapse': 'Partial Collapse',
    'column_damage': 'Column Damage',
    'wall_damage': 'Wall Damage',
    'foundation_issues': 'Foundation Issues',
    'roof_damage': 'Roof Damage',
    'window_breakage': 'Window Breakage',
  };

  // Hazard Types
  static const List<String> hazardTypes = [
    'gas_leak',
    'electrical',
    'water',
    'structural',
    'fire',
    'chemical',
  ];

  static const Map<String, String> hazardTypeLabels = {
    'gas_leak': 'Gas Leak',
    'electrical': 'Electrical Hazard',
    'water': 'Water Hazard',
    'structural': 'Structural Hazard',
    'fire': 'Fire Hazard',
    'chemical': 'Chemical Hazard',
  };

  // Severity Levels
  static const List<String> severityLevels = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  static const Map<String, String> severityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'critical': 'Critical',
  };

  // Risk Levels
  static const List<String> riskLevels = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  // Sync Settings
  static const int syncRetryAttempts = 3;
  static const Duration syncRetryDelay = Duration(seconds: 5);
  static const Duration autoSaveInterval = Duration(seconds: 30);
  static const Duration pollInterval = Duration(seconds: 5);
  static const int maxPollAttempts = 120; // 10 minutes max

  // Image Settings
  static const int maxImageSizeMB = 2;
  static const int imageQuality = 85;
  static const int maxPhotosPerAssessment = 10;

  // Hive Box Names
  static const String assessmentBoxName = 'assessments';
  static const String analysisBoxName = 'analysis_results';
  static const String settingsBoxName = 'settings';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Map Settings
  static const double defaultMapZoom = 15.0;
  static const double defaultMapTilt = 0.0;
}

class AppTheme {
  // Primary Colors
  static const int primaryColor = 0xFF2196F3; // Blue
  static const int primaryDarkColor = 0xFF1976D2;
  static const int accentColor = 0xFFFF5722; // Deep Orange

  // Risk Colors
  static const int lowRiskColor = 0xFF4CAF50; // Green
  static const int mediumRiskColor = 0xFFFFC107; // Amber
  static const int highRiskColor = 0xFFFF9800; // Orange
  static const int criticalRiskColor = 0xFFF44336; // Red

  // Status Colors
  static const int successColor = 0xFF4CAF50;
  static const int warningColor = 0xFFFF9800;
  static const int errorColor = 0xFFF44336;
  static const int infoColor = 0xFF2196F3;

  // Neutral Colors
  static const int backgroundColor = 0xFFF5F5F5;
  static const int cardColor = 0xFFFFFFFF;
  static const int dividerColor = 0xFFE0E0E0;
  static const int textPrimaryColor = 0xFF212121;
  static const int textSecondaryColor = 0xFF757575;
}
