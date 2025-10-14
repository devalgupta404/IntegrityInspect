import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/annotation.dart';
import 'dart:math' as math;

class AnnotationStorageService {
  static final AnnotationStorageService _instance = AnnotationStorageService._internal();
  factory AnnotationStorageService() => _instance;
  AnnotationStorageService._internal();

  static const String _annotationsDir = 'annotations';

  /// Save annotations for a specific image
  Future<void> saveAnnotations(String imagePath, List<Annotation> annotations) async {
    try {
      print('Saving ${annotations.length} annotations for image: $imagePath');
      
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory annotationsDir = Directory(path.join(appDir.path, _annotationsDir));
      
      if (!await annotationsDir.exists()) {
        await annotationsDir.create(recursive: true);
      }

      // Create a unique filename based on image path
      final String imageFileName = path.basename(imagePath);
      final String nameWithoutExt = path.basenameWithoutExtension(imageFileName);
      final String annotationFileName = '${nameWithoutExt}_annotations.json';
      final String annotationFilePath = path.join(annotationsDir.path, annotationFileName);

      // Convert annotations to JSON
      final List<Map<String, dynamic>> annotationsJson = annotations.map((a) => a.toJson()).toList();
      final String jsonString = jsonEncode({
        'imagePath': imagePath,
        'annotations': annotationsJson,
        'savedAt': DateTime.now().toIso8601String(),
      });

      // Save to file
      final File annotationFile = File(annotationFilePath);
      await annotationFile.writeAsString(jsonString);
      
      print('Annotations saved to: $annotationFilePath');
    } catch (e) {
      print('Error saving annotations: $e');
      rethrow;
    }
  }

  /// Load annotations for a specific image
  Future<List<Annotation>> loadAnnotations(String imagePath) async {
    try {
      print('Loading annotations for image: $imagePath');
      
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imageFileName = path.basename(imagePath);
      final String nameWithoutExt = path.basenameWithoutExtension(imageFileName);
      final String annotationFileName = '${nameWithoutExt}_annotations.json';
      final String annotationFilePath = path.join(appDir.path, _annotationsDir, annotationFileName);

      final File annotationFile = File(annotationFilePath);
      
      if (!await annotationFile.exists()) {
        print('No annotations found for this image');
        return [];
      }

      final String jsonString = await annotationFile.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      final List<dynamic> annotationsJson = data['annotations'] as List<dynamic>;
      final List<Annotation> annotations = annotationsJson
          .map((json) => Annotation.fromJson(json as Map<String, dynamic>))
          .toList();

      print('Loaded ${annotations.length} annotations');
      return annotations;
    } catch (e) {
      print('Error loading annotations: $e');
      return [];
    }
  }

  /// Delete annotations for a specific image
  Future<void> deleteAnnotations(String imagePath) async {
    try {
      print('Deleting annotations for image: $imagePath');
      
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imageFileName = path.basename(imagePath);
      final String nameWithoutExt = path.basenameWithoutExtension(imageFileName);
      final String annotationFileName = '${nameWithoutExt}_annotations.json';
      final String annotationFilePath = path.join(appDir.path, _annotationsDir, annotationFileName);

      final File annotationFile = File(annotationFilePath);
      
      if (await annotationFile.exists()) {
        await annotationFile.delete();
        print('Annotations deleted for image: $imagePath');
      }
    } catch (e) {
      print('Error deleting annotations: $e');
    }
  }

  /// Get all annotation files
  Future<List<String>> getAllAnnotationFiles() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory annotationsDir = Directory(path.join(appDir.path, _annotationsDir));
      
      if (!await annotationsDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await annotationsDir.list().toList();
      return files
          .where((file) => file is File && file.path.endsWith('.json'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error getting annotation files: $e');
      return [];
    }
  }
}
