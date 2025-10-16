import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../models/annotation.dart';
import 'image_annotation_screen.dart';

class LiveCameraScreen extends StatefulWidget {
  final List<String> existingPhotos;

  const LiveCameraScreen({
    super.key,
    this.existingPhotos = const [],
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isCapturing = false;
  List<String> _photos = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.existingPhotos);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('Initializing camera...');
      final cameraService = context.read<CameraService>();

      final hasPermission = await cameraService.requestCameraPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Camera permission denied';
        });
        return;
      }

      _cameraController = await cameraService.initializeCameraController();
      
      if (_cameraController != null) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
        print('Camera initialized successfully');
      } else {
        setState(() {
          _errorMessage = 'Failed to initialize camera';
        });
        print('Failed to initialize camera');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera initialization error: $e';
      });
      print('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera'),
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
      body: _buildBody(),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return Column(
      children: [
        _buildPhotoCounter(),
        Expanded(
          child: Stack(
            children: [
              _buildCameraPreview(),
              _buildCameraOverlay(),
            ],
          ),
        ),
        if (_photos.isNotEmpty) _buildPhotoThumbnails(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Error',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeCamera,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing camera...'),
        ],
      ),
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
            child: const Icon(
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
                const Text(
                  'Tap to capture, hold to focus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildCameraOverlay() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Grid overlay
          _buildGridOverlay(),
          // Focus indicator
          _buildFocusIndicator(),
        ],
      ),
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(
      painter: GridPainter(),
      size: Size.infinite,
    );
  }

  Widget _buildFocusIndicator() {
    return const Center(
      child: Icon(
        Icons.add,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildPhotoThumbnails() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          return _buildThumbnail(_photos[index], index);
        },
      ),
    );
  }

  Widget _buildThumbnail(String photoPath, int index) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photoPath),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'capture',
          onPressed: _isCapturing ? null : _capturePhoto,
          backgroundColor: _isCapturing ? Colors.grey : Colors.red,
          child: _isCapturing
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
          onPressed: _pickFromGallery,
          backgroundColor: const Color(0xFF4CAF50),
          child: const Icon(Icons.photo_library),
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not ready for capture');
      return;
    }

    setState(() => _isCapturing = true);

    try {
      print('Capturing photo...');
      final cameraService = context.read<CameraService>();
      final photoPath = await cameraService.capturePhoto();

      if (photoPath != null) {
        setState(() {
          _photos.add(photoPath);
        });

        print('Photo captured successfully: $photoPath');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured!'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('Failed to capture photo');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture photo'),
              backgroundColor: Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      print('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final cameraService = context.read<CameraService>();
      final photoPaths = await cameraService.pickMultipleImages();

      if (photoPaths.isNotEmpty) {
        setState(() {
          _photos.addAll(photoPaths);
        });

        print('Added ${photoPaths.length} photos from gallery');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${photoPaths.length} photo(s) added'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {

      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      

      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
