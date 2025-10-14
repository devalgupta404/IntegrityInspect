import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/annotation.dart';

class ImageAnnotationService {
  static final ImageAnnotationService _instance = ImageAnnotationService._internal();
  factory ImageAnnotationService() => _instance;
  ImageAnnotationService._internal();

  /// Generate an annotated image with all annotations overlaid
  Future<String?> generateAnnotatedImage(
    String originalImagePath,
    List<Annotation> annotations,
  ) async {
    try {
      print('Generating annotated image for: $originalImagePath');
      print('Number of annotations: ${annotations.length}');

      // Read the original image
      final File originalFile = File(originalImagePath);
      final Uint8List imageBytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        print('Failed to decode image');
        return null;
      }

      print('Original image size: ${image.width}x${image.height}');

      // Draw annotations on the image
      for (final annotation in annotations) {
        image = _drawAnnotationOnImage(image!, annotation);
      }

      // Save the annotated image
      final String annotatedImagePath = await _saveAnnotatedImage(image!, originalImagePath);
      print('Annotated image saved to: $annotatedImagePath');

      return annotatedImagePath;
    } catch (e) {
      print('Error generating annotated image: $e');
      return null;
    }
  }

  /// Draw a single annotation on the image
  img.Image _drawAnnotationOnImage(img.Image image, Annotation annotation) {
    try {
      // Convert Flutter Offset to image coordinates
      final int x = (annotation.position.dx * image.width).round();
      final int y = (annotation.position.dy * image.height).round();

      // Ensure coordinates are within image bounds
      final int clampedX = x.clamp(0, image.width - 1);
      final int clampedY = y.clamp(0, image.height - 1);

      print('Drawing annotation at: ($clampedX, $clampedY) for issue: ${annotation.issueType}');

      // Draw a larger, more visible circle for the annotation marker
      final int radius = 20;
      final img.ColorRgb8 colorValue = _colorToImageColor(annotation.color);

      // Draw filled circle with higher opacity
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          final int px = clampedX + dx;
          final int py = clampedY + dy;
          
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            final double distance = math.sqrt(dx * dx + dy * dy);
            if (distance <= radius) {
              // Create a more opaque color
              final img.ColorRgb8 opaqueColor = img.ColorRgb8(
                (colorValue.r * 0.8).round(),
                (colorValue.g * 0.8).round(),
                (colorValue.b * 0.8).round(),
              );
              image.setPixel(px, py, opaqueColor);
            }
          }
        }
      }

      // Draw thick white border circle
      final img.ColorRgb8 borderColor = img.ColorRgb8(255, 255, 255);
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          final int px = clampedX + dx;
          final int py = clampedY + dy;
          
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            final double distance = math.sqrt(dx * dx + dy * dy);
            if (distance > radius - 4 && distance <= radius) {
              image.setPixel(px, py, borderColor);
            }
          }
        }
      }

      // Draw issue type icon (larger cross)
      _drawCross(image, clampedX, clampedY, Colors.white);

      print('Annotation drawn successfully');
      return image;
    } catch (e) {
      print('Error drawing annotation: $e');
      return image;
    }
  }

  /// Draw a cross icon at the annotation position
  void _drawCross(img.Image image, int x, int y, Color color) {
    final img.ColorRgb8 colorValue = _colorToImageColor(color);
    final int size = 12; // Larger cross

    // Draw thick horizontal line
    for (int dx = -size; dx <= size; dx++) {
      for (int thickness = -1; thickness <= 1; thickness++) {
        final int px = x + dx;
        final int py = y + thickness;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, colorValue);
        }
      }
    }

    // Draw thick vertical line
    for (int dy = -size; dy <= size; dy++) {
      for (int thickness = -1; thickness <= 1; thickness++) {
        final int px = x + thickness;
        final int py = y + dy;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, colorValue);
        }
      }
    }
  }

  /// Convert Flutter Color to image color
  img.ColorRgb8 _colorToImageColor(Color color) {
    return img.ColorRgb8(color.red, color.green, color.blue);
  }

  /// Save the annotated image to a new file
  Future<String> _saveAnnotatedImage(img.Image image, String originalPath) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory annotatedDir = Directory(path.join(appDir.path, 'annotated_images'));
      
      if (!await annotatedDir.exists()) {
        await annotatedDir.create(recursive: true);
      }

      // Generate filename
      final String originalFileName = path.basename(originalPath);
      final String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
      final String extension = path.extension(originalFileName);
      final String annotatedFileName = '${nameWithoutExt}_annotated$extension';
      final String annotatedImagePath = path.join(annotatedDir.path, annotatedFileName);

      // Encode and save the image
      final List<int> encodedImage = img.encodeJpg(image, quality: 90);
      final File annotatedFile = File(annotatedImagePath);
      await annotatedFile.writeAsBytes(encodedImage);

      print('Annotated image saved: $annotatedImagePath');
      return annotatedImagePath;
    } catch (e) {
      print('Error saving annotated image: $e');
      rethrow;
    }
  }

  /// Generate a legend image showing all annotation types
  Future<String?> generateAnnotationLegend(List<Annotation> annotations) async {
    try {
      if (annotations.isEmpty) return null;

      // Get unique issue types
      final Set<String> uniqueIssueTypes = annotations.map((a) => a.issueType).toSet();
      
      // Create a simple legend image
      final int legendWidth = 300;
      final int legendHeight = (uniqueIssueTypes.length * 40) + 40;
      
      img.Image legend = img.Image(width: legendWidth, height: legendHeight);
      
      // Fill with white background
      legend = img.fill(legend, color: img.ColorRgb8(255, 255, 255));
      
      // Draw title
      img.drawString(
        legend,
        'Annotation Legend',
        font: img.arial14,
        x: 10,
        y: 10,
        color: img.ColorRgb8(0, 0, 0),
      );

      int yOffset = 40;
      for (final issueType in uniqueIssueTypes) {
        final annotation = annotations.firstWhere((a) => a.issueType == issueType);
        final issueName = _getIssueName(issueType);
        
        // Draw colored circle
        final img.ColorRgb8 colorValue = _colorToImageColor(annotation.color);
        for (int dy = 0; dy < 20; dy++) {
          for (int dx = 0; dx < 20; dx++) {
            final double distance = math.sqrt((dx - 10) * (dx - 10) + (dy - 10) * (dy - 10));
            if (distance <= 10) {
              legend.setPixel(10 + dx, yOffset + dy, colorValue);
            }
          }
        }
        
        // Draw text
        img.drawString(
          legend,
          issueName,
          font: img.arial14,
          x: 40,
          y: yOffset + 5,
          color: img.ColorRgb8(0, 0, 0),
        );
        
        yOffset += 30;
      }

      // Save legend
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String legendPath = path.join(appDir.path, 'annotation_legend.png');
      final File legendFile = File(legendPath);
      await legendFile.writeAsBytes(img.encodePng(legend));
      
      return legendPath;
    } catch (e) {
      print('Error generating legend: $e');
      return null;
    }
  }

  String _getIssueName(String issueType) {
    final issue = IssueType.structuralIssues.firstWhere(
      (i) => i.id == issueType,
      orElse: () => IssueType.structuralIssues.first,
    );
    return issue.name;
  }
}
