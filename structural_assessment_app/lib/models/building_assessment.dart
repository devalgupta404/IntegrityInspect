import 'package:hive/hive.dart';
import 'hazard.dart';

part 'building_assessment.g.dart';

@HiveType(typeId: 0)
class BuildingAssessment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String buildingType; // residential, commercial, industrial, mixed_use

  @HiveField(3)
  final int numberOfFloors;

  @HiveField(4)
  final String primaryMaterial; // concrete, brick, steel, wood, mixed

  @HiveField(5)
  final int yearBuilt;

  @HiveField(6)
  final List<String> damageTypes; // cracks, tilting, collapse, etc.

  @HiveField(7)
  final String damageDescription;

  @HiveField(8)
  final List<String> photoUrls; // local paths when offline

  @HiveField(9)
  final double latitude;

  @HiveField(10)
  final double longitude;

  @HiveField(11)
  final List<Hazard> hazards;

  @HiveField(12)
  final bool isSynced;

  @HiveField(13)
  final String? analysisResultId;

  @HiveField(14)
  final String? address;

  @HiveField(15)
  final String? notes;

  BuildingAssessment({
    required this.id,
    required this.timestamp,
    required this.buildingType,
    required this.numberOfFloors,
    required this.primaryMaterial,
    required this.yearBuilt,
    required this.damageTypes,
    required this.damageDescription,
    required this.photoUrls,
    required this.latitude,
    required this.longitude,
    required this.hazards,
    this.isSynced = false,
    this.analysisResultId,
    this.address,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'building_type': buildingType,
      'number_of_floors': numberOfFloors,
      'primary_material': primaryMaterial,
      'year_built': yearBuilt,
      'damage_types': damageTypes,
      'damage_description': damageDescription,
      'photo_urls': photoUrls,
      'latitude': latitude,
      'longitude': longitude,
      'hazards': hazards.map((h) => h.toJson()).toList(),
      'is_synced': isSynced,
      'analysis_result_id': analysisResultId,
      'address': address,
      'notes': notes,
    };
  }

  factory BuildingAssessment.fromJson(Map<String, dynamic> json) {
    return BuildingAssessment(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      buildingType: json['building_type'] as String,
      numberOfFloors: json['number_of_floors'] as int,
      primaryMaterial: json['primary_material'] as String,
      yearBuilt: json['year_built'] as int,
      damageTypes: List<String>.from(json['damage_types'] as List),
      damageDescription: json['damage_description'] as String,
      photoUrls: List<String>.from(json['photo_urls'] as List),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      hazards: (json['hazards'] as List)
          .map((h) => Hazard.fromJson(h as Map<String, dynamic>))
          .toList(),
      isSynced: json['is_synced'] as bool? ?? false,
      analysisResultId: json['analysis_result_id'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
    );
  }

  BuildingAssessment copyWith({
    String? id,
    DateTime? timestamp,
    String? buildingType,
    int? numberOfFloors,
    String? primaryMaterial,
    int? yearBuilt,
    List<String>? damageTypes,
    String? damageDescription,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
    List<Hazard>? hazards,
    bool? isSynced,
    String? analysisResultId,
    String? address,
    String? notes,
  }) {
    return BuildingAssessment(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      buildingType: buildingType ?? this.buildingType,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      primaryMaterial: primaryMaterial ?? this.primaryMaterial,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      damageTypes: damageTypes ?? this.damageTypes,
      damageDescription: damageDescription ?? this.damageDescription,
      photoUrls: photoUrls ?? this.photoUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hazards: hazards ?? this.hazards,
      isSynced: isSynced ?? this.isSynced,
      analysisResultId: analysisResultId ?? this.analysisResultId,
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }
}
