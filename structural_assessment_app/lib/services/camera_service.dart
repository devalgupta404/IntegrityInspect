import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final ImagePicker _picker = ImagePicker();
  List<CameraDescription>? _cameras;
  CameraController? _controller;

  Future<void> initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  Future<CameraController?> initializeCameraController({
    int cameraIndex = 0,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    if (_cameras == null || _cameras!.isEmpty) {
      await initializeCameras();
    }

    if (_cameras == null || _cameras!.isEmpty) {
      return null;
    }

    try {
      _controller = CameraController(
        _cameras![cameraIndex],
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      return _controller;
    } catch (e) {
      print('Error initializing camera controller: $e');
      return null;
    }
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; 
  }

  Future<String?> capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Camera not initialized for capture');
      return null;
    }

    try {
      print('Starting photo capture...');
      final XFile photo = await _controller!.takePicture();
      print('Photo captured at: ${photo.path}');
      
      final compressedPath = await compressImage(photo.path);
      print('Photo compressed and saved at: $compressedPath');
      return compressedPath;
    } catch (e) {
      print('Error capturing photo: $e');
      return null;
    }
  }

  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConstants.imageQuality,
      );

      if (image != null) {
        final compressedPath = await compressImage(image.path);
        return compressedPath;
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: AppConstants.imageQuality,
      );

      if (images.isEmpty) return [];

      final List<String> compressedPaths = [];
      for (final image in images) {
        final compressedPath = await compressImage(image.path);
        if (compressedPath != null) {
          compressedPaths.add(compressedPath);
        }
      }

      return compressedPaths;
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }

  Future<String?> compressImage(String imagePath) async {
    try {

      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();


      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      if (image.width > 1920 || image.height > 1920) {
        if (image.width > image.height) {
          image = img.copyResize(image, width: 1920);
        } else {
          image = img.copyResize(image, height: 1920);
        }
      }


      final List<int> compressedBytes = img.encodeJpg(
        image,
        quality: AppConstants.imageQuality,
      );

      if (compressedBytes.length > AppConstants.maxImageSizeMB * 1024 * 1024) {

        final List<int> moreCompressed = img.encodeJpg(
          image,
          quality: 70,
        );
        return await _saveCompressedImage(moreCompressed, imagePath);
      }

      return await _saveCompressedImage(compressedBytes, imagePath);
    } catch (e) {
      print('Error compressing image: $e');
      return imagePath; 
    }
  }

  Future<String> _saveCompressedImage(
    List<int> bytes,
    String originalPath,
  ) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'IMG_${DateTime.now().millisecondsSinceEpoch}_${path.basename(originalPath)}';
      final String filePath = path.join(appDir.path, 'images', fileName);


      final Directory imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final File compressedFile = File(filePath);
      await compressedFile.writeAsBytes(bytes);


      if (originalPath.contains('cache')) {
        try {
          await File(originalPath).delete();
        } catch (e) {
          print('Could not delete temp file: $e');
        }
      }

      return filePath;
    } catch (e) {
      print('Error saving compressed image: $e');
      return originalPath;
    }
  }

  Future<File?> addWatermark(String imagePath, String watermarkText) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return null;


      final img.Image watermarked = img.drawString(
        image,
        watermarkText,
        font: img.arial48,
        x: 20,
        y: image.height - 60,
        color: img.ColorRgba8(255, 255, 255, 180),
      );


      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'WM_${path.basename(imagePath)}';
      final String filePath = path.join(appDir.path, 'images', fileName);

      final File watermarkedFile = File(filePath);
      await watermarkedFile.writeAsBytes(img.encodeJpg(watermarked));

      return watermarkedFile;
    } catch (e) {
      print('Error adding watermark: $e');
      return null;
    }
  }

  Future<void> deleteImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  Future<void> deleteMultipleImages(List<String> imagePaths) async {
    for (final path in imagePaths) {
      await deleteImage(path);
    }
  }

  Future<int> getImageSize(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final int bytes = await imageFile.length();
      return bytes;
    } catch (e) {
      print('Error getting image size: $e');
      return 0;
    }
  }

  String formatImageSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}
