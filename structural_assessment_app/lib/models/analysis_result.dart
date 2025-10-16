import 'package:hive/hive.dart';

part 'analysis_result.g.dart';

@HiveType(typeId: 2)
class AnalysisResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String assessmentId;

  @HiveField(2)
  final String riskLevel; 

  @HiveField(3)
  final String analysis;

  @HiveField(4)
  final String? failureMode;

  @HiveField(5)
  final List<String> recommendations;

  @HiveField(6)
  final String? videoUrl;

  @HiveField(7)
  final DateTime generatedAt;

  @HiveField(8)
  final Map<String, dynamic>? detailedMetrics;

  @HiveField(9)
  final String? confidence;

  @HiveField(10)
  final bool isVideoDownloaded;

  @HiveField(11)
  final String? localVideoPath;

  AnalysisResult({
    required this.id,
    required this.assessmentId,
    required this.riskLevel,
    required this.analysis,
    this.failureMode,
    required this.recommendations,
    this.videoUrl,
    required this.generatedAt,
    this.detailedMetrics,
    this.confidence,
    this.isVideoDownloaded = false,
    this.localVideoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assessment_id': assessmentId,
      'risk_level': riskLevel,
      'analysis': analysis,
      'failure_mode': failureMode,
      'recommendations': recommendations,
      'video_url': videoUrl,
      'generated_at': generatedAt.toIso8601String(),
      'detailed_metrics': detailedMetrics,
      'confidence': confidence,
      'is_video_downloaded': isVideoDownloaded,
      'local_video_path': localVideoPath,
    };
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as String,
      assessmentId: json['assessment_id'] as String,
      riskLevel: json['risk_level'] as String,
      analysis: json['analysis'] as String,
      failureMode: json['failure_mode'] as String?,
      recommendations: List<String>.from(json['recommendations'] as List),
      videoUrl: json['video_url'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      detailedMetrics: json['detailed_metrics'] as Map<String, dynamic>?,
      confidence: json['confidence'] as String?,
      isVideoDownloaded: json['is_video_downloaded'] as bool? ?? false,
      localVideoPath: json['local_video_path'] as String?,
    );
  }

  AnalysisResult copyWith({
    String? id,
    String? assessmentId,
    String? riskLevel,
    String? analysis,
    String? failureMode,
    List<String>? recommendations,
    String? videoUrl,
    DateTime? generatedAt,
    Map<String, dynamic>? detailedMetrics,
    String? confidence,
    bool? isVideoDownloaded,
    String? localVideoPath,
  }) {
    return AnalysisResult(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      riskLevel: riskLevel ?? this.riskLevel,
      analysis: analysis ?? this.analysis,
      failureMode: failureMode ?? this.failureMode,
      recommendations: recommendations ?? this.recommendations,
      videoUrl: videoUrl ?? this.videoUrl,
      generatedAt: generatedAt ?? this.generatedAt,
      detailedMetrics: detailedMetrics ?? this.detailedMetrics,
      confidence: confidence ?? this.confidence,
      isVideoDownloaded: isVideoDownloaded ?? this.isVideoDownloaded,
      localVideoPath: localVideoPath ?? this.localVideoPath,
    );
  }

  int getRiskColor() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return 0xFF4CAF50; // Green
      case 'medium':
        return 0xFFFFC107; // Amber
      case 'high':
        return 0xFFFF9800; // Orange
      case 'critical':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }


  String getRiskIcon() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return '✓';
      case 'medium':
        return '⚠';
      case 'high':
        return '⚠';
      case 'critical':
        return '⚠';
      default:
        return '?';
    }
  }
}
