import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/annotation.dart';

class AssessmentCompletionService {
  static final AssessmentCompletionService _instance = AssessmentCompletionService._internal();
  factory AssessmentCompletionService() => _instance;
  AssessmentCompletionService._internal();

  static const String _baseUrl = 'http://192.168.1.20:8000/api/v1'; 
  static const String _submitAssessmentEndpoint = '/assessments/submit';
  static const String _uploadPhotosEndpoint = '/assessments/upload-photos';
  static const String _getAnalysisEndpoint = '/assessments/status';
  static const String _physicsSimulationEndpoint = '/simulation/analyze';
  static const String _simulationVideoEndpoint = '/simulation/video';
  static const String _simulationStatusEndpoint = '/simulation/status';


  Future<AssessmentResult> submitCompleteAssessment({
    required AssessmentData assessmentData,
    required List<String> photoPaths,
    required List<Annotation> annotations,
  }) async {
    try {
      print('══════════════════════════════════════════════════════════');
      print('🚀 ASSESSMENT SUBMISSION STARTED');
      print('══════════════════════════════════════════════════════════');
      print('📋 Building Type: ${assessmentData.buildingType}');
      print('🏢 Floors: ${assessmentData.numberOfFloors}');
      print('🧱 Material: ${assessmentData.primaryMaterial}');
      print('📅 Year Built: ${assessmentData.yearBuilt}');
      print('⚠️  Damage Types: ${assessmentData.damageTypes}');
      print('📸 Photos: ${photoPaths.length}');
      print('📍 Annotations: ${annotations.length}');
      print('──────────────────────────────────────────────────────────');

      print('🔗 Calling physics simulation backend...');
      print('Backend URL: $_baseUrl$_physicsSimulationEndpoint');


      final Map<String, dynamic> simulationRequest = {
        'building_type': assessmentData.buildingType,
        'number_of_floors': assessmentData.numberOfFloors,
        'primary_material': assessmentData.primaryMaterial,
        'year_built': assessmentData.yearBuilt,
        'damage_types': assessmentData.damageTypes,
        'damage_description': assessmentData.damageDescription,
        'latitude': assessmentData.latitude,
        'longitude': assessmentData.longitude,
        'annotations': annotations.map((a) => {
          'id': a.id,
          'position': {'x': a.position.dx, 'y': a.position.dy},
          'issueType': a.issueType,
          'description': a.description,
          'color': a.color.toString(),
          'timestamp': a.timestamp.toIso8601String(),
        }).toList(),
        'photo_paths': photoPaths,
      };

      print('📤 Sending HTTP POST request...');
      final requestJson = jsonEncode(simulationRequest);
      print('📦 Request size: ${requestJson.length} characters');


      final startTime = DateTime.now();
      final response = await http.post(
        Uri.parse('$_baseUrl$_physicsSimulationEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: requestJson,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ Request timed out after 30 seconds');
          throw Exception('Physics simulation request timed out');
        },
      );

      final requestDuration = DateTime.now().difference(startTime);
      print('⏱️  Request completed in ${requestDuration.inSeconds}s');
      print('📊 Response Status: ${response.statusCode}');
      print('📦 Response Size: ${response.body.length} characters');

      if (response.statusCode == 200) {
        print('──────────────────────────────────────────────────────────');
        print('✅ Physics simulation completed successfully!');

        final responseData = jsonDecode(response.body);
        print('🎯 Simulation ID: ${responseData['simulation_id']}');
        print('⚠️  Risk Level: ${responseData['risk_level']}');
        print('🔒 Safety Factor: ${responseData['safety_factor']}');
        print('📈 Failure Probability: ${responseData['failure_probability']}');
        print('🎥 Video URL: ${responseData['video_url']}');
        print('──────────────────────────────────────────────────────────');

        final AssessmentResult result = AssessmentResult(
          assessmentId: responseData['simulation_id'],
          riskLevel: responseData['risk_level'],
          analysis: responseData['engineering_analysis'],
          failureMode: responseData['collapse_simulation']['failure_mode'] ?? 'Unknown',
          recommendations: _extractRecommendations(responseData['engineering_analysis']),
          videoUrl: responseData['video_url'],
          generatedAt: DateTime.parse(responseData['generated_at']),
          confidence: responseData['confidence'],
          detailedMetrics: {
            'safety_factor': responseData['safety_factor'],
            'failure_probability': responseData['failure_probability'],
            'fea_results': responseData['fea_results'],
            'collapse_simulation': responseData['collapse_simulation'],
            'building_type': assessmentData.buildingType,
            'floors': assessmentData.numberOfFloors,
          },
        );

        print('✅✅✅ ASSESSMENT RESULT CREATED SUCCESSFULLY! ✅✅✅');
        print('══════════════════════════════════════════════════════════');
        return result;
      } else {
        print('──────────────────────────────────────────────────────────');
        print('❌ Physics simulation failed!');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        print('──────────────────────────────────────────────────────────');
        print('🔄 Falling back to offline analysis...');

        return await _runPhysicsAnalysis(assessmentData, annotations);
      }
    } catch (e, stackTrace) {
      print('══════════════════════════════════════════════════════════');
      print('❌❌❌ CRITICAL ERROR IN ASSESSMENT SUBMISSION ❌❌❌');
      print('Error: $e');
      print('Stack Trace:');
      print(stackTrace);
      print('══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  Future<List<String>> _uploadPhotos(List<String> photoPaths) async {
    try {
      final List<String> uploadedUrls = [];
      
      for (final photoPath in photoPaths) {
        print('Uploading photo: $photoPath');
        
        final File photoFile = File(photoPath);
        if (!await photoFile.exists()) {
          print('Photo file does not exist: $photoPath');
          continue;
        }

        final List<int> photoBytes = await photoFile.readAsBytes();
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl$_uploadPhotosEndpoint'),
        );
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            photoBytes,
            filename: photoFile.path.split('/').last,
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          uploadedUrls.add(responseData['url']);
          print('Photo uploaded successfully: ${responseData['url']}');
        } else {
          print('Failed to upload photo: ${response.statusCode} - ${response.body}');
        }
      }
      
      return uploadedUrls;
    } catch (e) {
      print('Error uploading photos: $e');
      rethrow;
    }
  }

  Future<AssessmentResult> _pollForAnalysisResults(String assessmentId) async {
    const int maxAttempts = 60; 
    const Duration pollInterval = Duration(seconds: 5);
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        print('Polling for results (attempt ${attempt + 1}/$maxAttempts)...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl$_getAnalysisEndpoint/$assessmentId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final String status = responseData['status'];
          
          print('Analysis status: $status');
          
          if (status == 'completed') {
            final Map<String, dynamic> result = responseData['result'];
            return AssessmentResult.fromJson(result);
          } else if (status == 'failed') {
            throw Exception('Analysis failed: ${responseData['error']}');
          }
          

          await Future.delayed(pollInterval);
        } else {
          print('Error polling results: ${response.statusCode} - ${response.body}');
          await Future.delayed(pollInterval);
        }
      } catch (e) {
        print('Error polling for results: $e');
        await Future.delayed(pollInterval);
      }
    }
    
    throw Exception('Analysis timed out after ${maxAttempts * 5} seconds');
  }


  Future<AssessmentResult> _runPhysicsAnalysis(AssessmentData assessmentData, List<Annotation> annotations) async {

    await Future.delayed(Duration(seconds: 1));
    

    final int buildingAge = DateTime.now().year - assessmentData.yearBuilt;
    final int annotationCount = annotations.length;
    final int damageTypeCount = assessmentData.damageTypes.length;
    final int floors = assessmentData.numberOfFloors;
    final String material = assessmentData.primaryMaterial;
    

    final double ageFactor = _calculateAgeDegradationFactor(buildingAge);
    final double damageFactor = _calculateDamageFactor(damageTypeCount, annotationCount);
    final double loadFactor = _calculateLoadFactor(floors, material);
    final double safetyFactor = _calculateSafetyFactor(ageFactor, damageFactor, loadFactor);
    final double failureProbability = _calculateFailureProbability(safetyFactor, damageFactor);
    

    String riskLevel = _determineRiskLevel(safetyFactor, failureProbability);
    String analysis = _generateEngineeringAnalysis(
      buildingAge, floors, material, safetyFactor, failureProbability, annotationCount
    );
    String? failureMode = _predictFailureMode(safetyFactor, damageTypeCount, material);
    List<String> recommendations = _generateEngineeringRecommendations(
      riskLevel, safetyFactor, failureProbability, floors, material
    );
    

    if (annotations.isNotEmpty) {
      analysis += '\n\nANNOTATION ANALYSIS:';
      for (final annotation in annotations) {
        analysis += '\n- ${annotation.issueType.toUpperCase()}: Located at coordinates (${annotation.position.dx}, ${annotation.position.dy})';
      }
      analysis += '\n\nTotal annotated issues: ${annotations.length}';
    }

    if (assessmentData.primaryMaterial == 'wood' && buildingAge > 20) {
      recommendations.add('Wooden structures over 20 years old require specialized assessment');
    }
    if (assessmentData.numberOfFloors > 3 && riskLevel != 'low') {
      recommendations.add('Multi-story buildings require additional safety measures');
    }
    

    final String videoUrl = 'http://192.168.1.20:8000/api/v1/simulation/video/placeholder/offline_${DateTime.now().millisecondsSinceEpoch}';
    
    return AssessmentResult(
      assessmentId: DateTime.now().millisecondsSinceEpoch.toString(),
      riskLevel: riskLevel,
      analysis: analysis,
      failureMode: failureMode,
      recommendations: recommendations,
      videoUrl: videoUrl,
      generatedAt: DateTime.now(),
      confidence: 'high',
      detailedMetrics: {
        'building_age': buildingAge,
        'annotation_count': annotationCount,
        'damage_types': damageTypeCount,
        'floors': assessmentData.numberOfFloors,
        'material': assessmentData.primaryMaterial,
        'risk_score': _calculateRiskScore(buildingAge, damageTypeCount, annotationCount),
      },
    );
  }
  

  double _calculateAgeDegradationFactor(int age) {

    return math.exp(-age * 0.02).clamp(0.1, 1.0);
  }
  
  
  double _calculateDamageFactor(int damageTypes, int annotations) {
    return (1.0 + damageTypes * 0.3 + annotations * 0.1).clamp(1.0, 3.0);
  }
  
 
  double _calculateLoadFactor(int floors, String material) {
    double baseLoad = floors * 1.0;
    double materialFactor = _getMaterialFactor(material);
    return baseLoad * materialFactor;
  }
  
 
  double _getMaterialFactor(String material) {
    switch (material.toLowerCase()) {
      case 'steel': return 1.0;
      case 'concrete': return 0.8;
      case 'brick': return 0.6;
      case 'wood': return 0.4;
      default: return 0.7;
    }
  }

  double _calculateSafetyFactor(double ageFactor, double damageFactor, double loadFactor) {
    return (ageFactor * 2.0) / (damageFactor * loadFactor);
  }
  
  double _calculateFailureProbability(double safetyFactor, double damageFactor) {
    if (safetyFactor >= 2.0) return 0.01;
    if (safetyFactor >= 1.5) return 0.05;
    if (safetyFactor >= 1.0) return 0.2;
    if (safetyFactor >= 0.5) return 0.6;
    return 0.9;
  }
  

  String _determineRiskLevel(double safetyFactor, double failureProbability) {
    if (safetyFactor < 0.5 || failureProbability > 0.8) return 'critical';
    if (safetyFactor < 1.0 || failureProbability > 0.5) return 'high';
    if (safetyFactor < 1.5 || failureProbability > 0.2) return 'medium';
    return 'low';
  }
  

  String _generateEngineeringAnalysis(int age, int floors, String material, 
                                   double safetyFactor, double failureProbability, int annotations) {
    return '''
ENGINEERING STRUCTURAL ANALYSIS REPORT

BUILDING PARAMETERS:
- Age: $age years
- Floors: $floors
- Material: ${material.toUpperCase()}
- Damage Annotations: $annotations

STRUCTURAL CALCULATIONS:
- Safety Factor: ${safetyFactor.toStringAsFixed(2)}
- Failure Probability: ${(failureProbability * 100).toStringAsFixed(1)}%
- Age Degradation: ${((1 - _calculateAgeDegradationFactor(age)) * 100).toStringAsFixed(1)}%

ENGINEERING ASSESSMENT:
${_getEngineeringAssessment(safetyFactor, failureProbability)}
''';
  }
  

  String _getEngineeringAssessment(double safetyFactor, double failureProbability) {
    if (safetyFactor < 0.5) {
      return 'CRITICAL: Safety factor below minimum acceptable limit. Immediate structural intervention required.';
    } else if (safetyFactor < 1.0) {
      return 'HIGH RISK: Safety factor below design standards. Structural reinforcement or evacuation recommended.';
    } else if (safetyFactor < 1.5) {
      return 'MEDIUM RISK: Safety factor below optimal but within acceptable range. Monitoring and maintenance required.';
    } else {
      return 'LOW RISK: Safety factor within acceptable range. Standard maintenance protocols apply.';
    }
  }
  

  String _predictFailureMode(double safetyFactor, int damageTypes, String material) {
    if (safetyFactor < 0.5) {
      return 'Progressive collapse due to multiple structural failures';
    } else if (safetyFactor < 1.0) {
      return 'Partial collapse due to structural weakness';
    } else if (damageTypes > 2) {
      return 'Localized structural damage with potential for propagation';
    } else {
      return 'Minor structural damage with limited impact';
    }
  }
  

  List<String> _generateEngineeringRecommendations(String riskLevel, double safetyFactor, 
                                                 double failureProbability, int floors, String material) {
    List<String> recommendations = [];
    
    if (riskLevel == 'critical') {
      recommendations.addAll([
        'IMMEDIATE EVACUATION REQUIRED',
        'Establish 100m safety perimeter',
        'Notify emergency services immediately',
        'Do not allow entry under any circumstances',
        'Document for insurance and legal purposes'
      ]);
    } else if (riskLevel == 'high') {
      recommendations.addAll([
        'Restrict access to building immediately',
        'Conduct emergency structural inspection',
        'Consider temporary support measures',
        'Evacuate surrounding buildings if necessary',
        'Monitor for further damage progression'
      ]);
    } else if (riskLevel == 'medium') {
      recommendations.addAll([
        'Conduct detailed structural inspection',
        'Implement monitoring systems',
        'Consider temporary support measures',
        'Plan for necessary repairs',
        'Regular safety assessments required'
      ]);
    } else {
      recommendations.addAll([
        'Routine maintenance recommended',
        'Monitor for any structural changes',
        'Standard safety protocols apply',
        'Regular inspections advised'
      ]);
    }
    
   
    if (material == 'wood' && floors > 2) {
      recommendations.add('Wooden multi-story structures require specialized assessment');
    }
    if (material == 'brick' && safetyFactor < 1.5) {
      recommendations.add('Brick structures may require additional reinforcement');
    }
    
    return recommendations;
  }
  

  List<String> _extractRecommendations(String analysis) {

    List<String> recommendations = [];
    
    if (analysis.contains('CRITICAL') || analysis.contains('IMMEDIATE EVACUATION')) {
      recommendations.addAll([
        'IMMEDIATE EVACUATION REQUIRED',
        'Establish safety perimeter',
        'Notify emergency services',
        'Do not enter building'
      ]);
    } else if (analysis.contains('HIGH RISK')) {
      recommendations.addAll([
        'Restrict access to building',
        'Conduct emergency inspection',
        'Consider temporary support',
        'Monitor for further damage'
      ]);
    } else if (analysis.contains('MEDIUM RISK')) {
      recommendations.addAll([
        'Conduct detailed inspection',
        'Monitor damage progression',
        'Plan necessary repairs',
        'Regular safety assessments'
      ]);
    } else {
      recommendations.addAll([
        'Routine maintenance recommended',
        'Monitor for changes',
        'Standard safety protocols'
      ]);
    }
    
    return recommendations;
  }
  

  int _calculateRiskScore(int age, int damageTypes, int annotations) {
    int score = 0;
    score += (age / 2).round(); // Age factor
    score += damageTypes * 15; // Damage factor
    score += annotations * 10; // Annotation factor
    return score.clamp(0, 100);
  }
}

class AssessmentData {
  final String buildingType;
  final int numberOfFloors;
  final String primaryMaterial;
  final int yearBuilt;
  final List<String> damageTypes;
  final String damageDescription;
  final double latitude;
  final double longitude;
  final List<Map<String, dynamic>> hazards;
  final String notes;

  AssessmentData({
    required this.buildingType,
    required this.numberOfFloors,
    required this.primaryMaterial,
    required this.yearBuilt,
    required this.damageTypes,
    required this.damageDescription,
    required this.latitude,
    required this.longitude,
    required this.hazards,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'building_type': buildingType,
      'number_of_floors': numberOfFloors,
      'primary_material': primaryMaterial,
      'year_built': yearBuilt,
      'damage_types': damageTypes,
      'damage_description': damageDescription,
      'latitude': latitude,
      'longitude': longitude,
      'hazards': hazards,
      'notes': notes,
    };
  }
}


class AssessmentResult {
  final String assessmentId;
  final String riskLevel;
  final String analysis;
  final String? failureMode;
  final List<String> recommendations;
  final String? videoUrl;
  final DateTime generatedAt;
  final String confidence;
  final Map<String, dynamic>? detailedMetrics;

  AssessmentResult({
    required this.assessmentId,
    required this.riskLevel,
    required this.analysis,
    this.failureMode,
    required this.recommendations,
    this.videoUrl,
    required this.generatedAt,
    required this.confidence,
    this.detailedMetrics,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      assessmentId: json['assessment_id'],
      riskLevel: json['risk_level'],
      analysis: json['analysis'],
      failureMode: json['failure_mode'],
      recommendations: List<String>.from(json['recommendations'] ?? []),
      videoUrl: json['video_url'],
      generatedAt: DateTime.parse(json['generated_at']),
      confidence: json['confidence'] ?? 'medium',
      detailedMetrics: json['detailed_metrics'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_id': assessmentId,
      'risk_level': riskLevel,
      'analysis': analysis,
      'failure_mode': failureMode,
      'recommendations': recommendations,
      'video_url': videoUrl,
      'generated_at': generatedAt.toIso8601String(),
      'confidence': confidence,
      'detailed_metrics': detailedMetrics,
    };
  }
}
