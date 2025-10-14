import 'package:flutter/material.dart';

class Annotation {
  final String id;
  final Offset position;
  final String issueType;
  final String description;
  final Color color;
  final DateTime timestamp;

  Annotation({
    required this.id,
    required this.position,
    required this.issueType,
    required this.description,
    required this.color,
    required this.timestamp,
  });

  Annotation copyWith({
    String? id,
    Offset? position,
    String? issueType,
    String? description,
    Color? color,
    DateTime? timestamp,
  }) {
    return Annotation(
      id: id ?? this.id,
      position: position ?? this.position,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      color: color ?? this.color,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': {'x': position.dx, 'y': position.dy},
      'issueType': issueType,
      'description': description,
      'color': color.value,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'],
      position: Offset(
        json['position']['x'].toDouble(),
        json['position']['y'].toDouble(),
      ),
      issueType: json['issueType'],
      description: json['description'],
      color: Color(json['color']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class IssueType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const IssueType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const List<IssueType> structuralIssues = [
    IssueType(
      id: 'crack',
      name: 'Crack',
      description: 'Structural crack in the building',
      icon: Icons.linear_scale,
      color: Colors.red,
    ),
    IssueType(
      id: 'tilting',
      name: 'Tilting',
      description: 'Building or structural element is tilting',
      icon: Icons.trending_flat,
      color: Colors.orange,
    ),
    IssueType(
      id: 'spalling',
      name: 'Spalling',
      description: 'Concrete spalling or surface damage',
      icon: Icons.texture,
      color: Colors.brown,
    ),
    IssueType(
      id: 'corrosion',
      name: 'Corrosion',
      description: 'Metal corrosion or rust',
      icon: Icons.water_drop,
      color: Colors.blue,
    ),
    IssueType(
      id: 'separation',
      name: 'Separation',
      description: 'Separation between structural elements',
      icon: Icons.crop_free,
      color: Colors.purple,
    ),
    IssueType(
      id: 'deformation',
      name: 'Deformation',
      description: 'Structural deformation or bending',
      icon: Icons.transform,
      color: Colors.green,
    ),
    IssueType(
      id: 'water_damage',
      name: 'Water Damage',
      description: 'Water damage or moisture issues',
      icon: Icons.water,
      color: Colors.cyan,
    ),
    IssueType(
      id: 'fire_damage',
      name: 'Fire Damage',
      description: 'Fire damage or heat-related issues',
      icon: Icons.local_fire_department,
      color: Colors.deepOrange,
    ),
  ];
}
