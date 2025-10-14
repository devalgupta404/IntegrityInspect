import 'package:hive/hive.dart';

part 'hazard.g.dart';

@HiveType(typeId: 1)
class Hazard extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // gas_leak, electrical, water, structural

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final String severity; // low, medium, high, critical

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String? photoUrl;

  Hazard({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.description,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'description': description,
      'photo_url': photoUrl,
    };
  }

  factory Hazard.fromJson(Map<String, dynamic> json) {
    return Hazard(
      id: json['id'] as String,
      type: json['type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      severity: json['severity'] as String,
      description: json['description'] as String,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Hazard copyWith({
    String? id,
    String? type,
    double? latitude,
    double? longitude,
    String? severity,
    String? description,
    String? photoUrl,
  }) {
    return Hazard(
      id: id ?? this.id,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
