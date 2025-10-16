import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/building_assessment.dart';
import '../models/analysis_result.dart';
import '../models/hazard.dart';
import '../utils/constants.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late Box<BuildingAssessment> _assessmentBox;
  late Box<AnalysisResult> _analysisBox;
  late Box<dynamic> _settingsBox;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {

      final appDocumentDir = await getApplicationDocumentsDirectory();


      await Hive.initFlutter(appDocumentDir.path);


      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(BuildingAssessmentAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(HazardAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AnalysisResultAdapter());
      }


      _assessmentBox = await Hive.openBox<BuildingAssessment>(
        AppConstants.assessmentBoxName,
      );
      _analysisBox = await Hive.openBox<AnalysisResult>(
        AppConstants.analysisBoxName,
      );
      _settingsBox = await Hive.openBox(
        AppConstants.settingsBoxName,
      );

      _isInitialized = true;
      print('Local storage initialized successfully');
    } catch (e) {
      print('Error initializing local storage: $e');
      rethrow;
    }
  }


  Future<void> saveAssessment(BuildingAssessment assessment) async {
    await _assessmentBox.put(assessment.id, assessment);
  }

  BuildingAssessment? getAssessment(String id) {
    return _assessmentBox.get(id);
  }

  List<BuildingAssessment> getAllAssessments() {
    return _assessmentBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<BuildingAssessment> getUnsyncedAssessments() {
    return _assessmentBox.values.where((a) => !a.isSynced).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> deleteAssessment(String id) async {
    await _assessmentBox.delete(id);
  }

  Future<void> updateAssessmentSyncStatus(String id, bool isSynced) async {
    final assessment = _assessmentBox.get(id);
    if (assessment != null) {
      final updated = assessment.copyWith(isSynced: isSynced);
      await _assessmentBox.put(id, updated);
    }
  }

  Future<void> updateAssessmentAnalysisId(
    String assessmentId,
    String analysisId,
  ) async {
    final assessment = _assessmentBox.get(assessmentId);
    if (assessment != null) {
      final updated = assessment.copyWith(analysisResultId: analysisId);
      await _assessmentBox.put(assessmentId, updated);
    }
  }


  Future<void> saveAnalysisResult(AnalysisResult result) async {
    await _analysisBox.put(result.id, result);
  }

  AnalysisResult? getAnalysisResult(String id) {
    return _analysisBox.get(id);
  }

  AnalysisResult? getAnalysisResultByAssessmentId(String assessmentId) {
    return _analysisBox.values.firstWhere(
      (r) => r.assessmentId == assessmentId,
      orElse: () => throw StateError('No analysis found'),
    );
  }

  List<AnalysisResult> getAllAnalysisResults() {
    return _analysisBox.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  Future<void> deleteAnalysisResult(String id) async {
    await _analysisBox.delete(id);
  }

  Future<void> updateAnalysisVideoDownloadStatus({
    required String id,
    required bool isDownloaded,
    required String? localPath,
  }) async {
    final result = _analysisBox.get(id);
    if (result != null) {
      final updated = result.copyWith(
        isVideoDownloaded: isDownloaded,
        localVideoPath: localPath,
      );
      await _analysisBox.put(id, updated);
    }
  }
  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  Future<void> clearAllData() async {
    await _assessmentBox.clear();
    await _analysisBox.clear();
    await _settingsBox.clear();
  }

  Future<void> clearSyncedAssessments() async {
    final syncedKeys = _assessmentBox.values
        .where((a) => a.isSynced)
        .map((a) => a.id)
        .toList();

    for (final key in syncedKeys) {
      await _assessmentBox.delete(key);
    }
  }


  int get totalAssessments => _assessmentBox.length;
  int get unsyncedAssessmentsCount =>
      _assessmentBox.values.where((a) => !a.isSynced).length;
  int get totalAnalysisResults => _analysisBox.length;

  Map<String, int> getAssessmentsByRiskLevel() {
    final results = getAllAnalysisResults();
    final stats = <String, int>{};

    for (final result in results) {
      stats[result.riskLevel] = (stats[result.riskLevel] ?? 0) + 1;
    }

    return stats;
  }


  Future<String> exportAssessmentsToJson() async {
    final assessments = getAllAssessments();
    final jsonList = assessments.map((a) => a.toJson()).toList();
    return jsonList.toString();
  }


  Future<void> dispose() async {
    await _assessmentBox.close();
    await _analysisBox.close();
    await _settingsBox.close();
    _isInitialized = false;
  }
}
