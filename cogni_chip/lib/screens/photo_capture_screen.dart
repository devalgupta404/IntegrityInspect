import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../utils/constants.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final List<String> existingPhotos;

  const PhotoCaptureScreen({
    super.key,
    this.existingPhotos = const [],
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  List<String> _photos = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.existingPhotos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Photos'),
        actions: [
          if (_photos.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _photos),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPhotoCounter(),
          Expanded(
            child: _photos.isEmpty
                ? _buildEmptyState()
                : _buildPhotoGrid(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _isProcessing ? null : _captureFromCamera,
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: _isProcessing ? null : _pickFromGallery,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.photo_library),
          ),
        ],
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildPhotoCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.photo_camera,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_photos.length} Photo${_photos.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _photos.length < AppConstants.maxPhotosPerAssessment
                      ? 'Add up to ${AppConstants.maxPhotosPerAssessment} photos'
                      : 'Maximum photos reached',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo,
            size: 120,
            color: Colors.grey[300],
          ).animate().fadeIn().scale(),
          const SizedBox(height: 24),
          Text(
            'No photos yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Tap the camera button to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionHint(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                color: const Color(0xFFFF5722),
              ),
              const SizedBox(width: 24),
              _buildActionHint(
                icon: Icons.photo_library,
                label: 'From Gallery',
                color: const Color(0xFF4CAF50),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildActionHint({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return _buildPhotoCard(_photos[index], index);
      },
    );
  }

  Widget _buildPhotoCard(String photoPath, int index) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Image.file(
            File(photoPath),
            fit: BoxFit.cover,
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),

          // Photo number
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Photo ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
            ),
          ),

          // Delete button
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _deletePhoto(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // View button
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _viewPhoto(photoPath),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 50))
        .slideY(begin: 0.2, end: 0);
  }

  Future<void> _captureFromCamera() async {
    if (_photos.length >= AppConstants.maxPhotosPerAssessment) {
      _showMaxPhotosDialog();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cameraService = context.read<CameraService>();

      // Request permission
      final hasPermission = await cameraService.requestCameraPermission();
      if (!hasPermission) {
        throw Exception('Camera permission denied');
      }

      // Capture photo
      final photoPath = await cameraService.capturePhoto();

      if (photoPath != null) {
        setState(() {
          _photos.add(photoPath);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo captured and compressed'),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= AppConstants.maxPhotosPerAssessment) {
      _showMaxPhotosDialog();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cameraService = context.read<CameraService>();

      // Pick multiple photos
      final remainingSlots = AppConstants.maxPhotosPerAssessment - _photos.length;
      final photoPaths = await cameraService.pickMultipleImages();

      if (photoPaths.isNotEmpty) {
        final photosToAdd = photoPaths.take(remainingSlots).toList();

        setState(() {
          _photos.addAll(photosToAdd);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${photosToAdd.length} photo(s) added and compressed'),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _deletePhoto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _photos.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
  }

  void _viewPhoto(String photoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoViewScreen(photoPath: photoPath),
      ),
    );
  }

  void _showMaxPhotosDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Photos Reached'),
        content: Text(
          'You can add up to ${AppConstants.maxPhotosPerAssessment} photos per assessment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Full screen photo viewer
class _PhotoViewScreen extends StatelessWidget {
  final String photoPath;

  const _PhotoViewScreen({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(photoPath)),
        ),
      ),
    );
  }
}
