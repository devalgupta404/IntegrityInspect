import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/annotation.dart';
import '../services/annotation_storage_service.dart';
import '../services/image_annotation_service.dart';

class ImageAnnotationScreen extends StatefulWidget {
  final String imagePath;
  final List<Annotation>? existingAnnotations;

  const ImageAnnotationScreen({
    super.key,
    required this.imagePath,
    this.existingAnnotations,
  });

  @override
  State<ImageAnnotationScreen> createState() => _ImageAnnotationScreenState();
}

class _ImageAnnotationScreenState extends State<ImageAnnotationScreen> {
  List<Annotation> _annotations = [];
  Annotation? _selectedAnnotation;
  bool _isAddingAnnotation = false;
  Offset? _newAnnotationPosition;
  bool _isSaving = false;
  Timer? _saveTimer;
  String? _annotatedImagePath;

  final AnnotationStorageService _storageService = AnnotationStorageService();
  final ImageAnnotationService _imageService = ImageAnnotationService();

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    try {
      print('Loading existing annotations...');
      final annotations = await _storageService.loadAnnotations(widget.imagePath);
      setState(() {
        _annotations = annotations;
      });
      print('Loaded ${annotations.length} annotations');
    } catch (e) {
      print('Error loading annotations: $e');
      setState(() {
        _annotations = widget.existingAnnotations ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotate Image'),
        actions: [
          IconButton(
            onPressed: _toggleAnnotationMode,
            icon: Icon(
              _isAddingAnnotation ? Icons.close : Icons.add_location,
              color: _isAddingAnnotation ? Colors.red : Colors.white,
            ),
          ),
          if (_annotations.isNotEmpty)
            IconButton(
              onPressed: _showAnnotationList,
              icon: const Icon(Icons.list),
            ),
          IconButton(
            onPressed: _isSaving ? null : _saveAnnotations,
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildImageViewer(),
          _buildAnnotations(),
          if (_isAddingAnnotation) _buildAnnotationOverlay(),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildAnnotations() {
    return Stack(
      children: _annotations.map((annotation) {
        return _buildAnnotationMarker(annotation);
      }).toList(),
    );
  }

  Widget _buildAnnotationMarker(Annotation annotation) {
    final isSelected = _selectedAnnotation?.id == annotation.id;
    
    return Positioned(
      left: annotation.position.dx - 20,
      top: annotation.position.dy - 20,
      child: GestureDetector(
        onTap: () => _selectAnnotation(annotation),
        onPanUpdate: (details) => _moveAnnotation(annotation, details.delta),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: annotation.color.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getIssueIcon(annotation.issueType),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationOverlay() {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _newAnnotationPosition = details.localPosition;
        });
        _showIssueTypeDialog();
      },
      child: Container(
        color: Colors.transparent,
        child: const Center(
          child: Text(
            'Tap to add annotation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_annotatedImagePath != null)
          FloatingActionButton(
            heroTag: 'view_annotated',
            onPressed: _viewAnnotatedImage,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.visibility),
          ),
        if (_annotatedImagePath != null) const SizedBox(height: 12),
        if (_annotations.isNotEmpty)
          FloatingActionButton(
            heroTag: 'clear',
            onPressed: _clearAllAnnotations,
            backgroundColor: Colors.red,
            child: const Icon(Icons.clear_all),
          ),
        if (_annotations.isNotEmpty) const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: _toggleAnnotationMode,
          backgroundColor: _isAddingAnnotation ? Colors.red : Colors.blue,
          child: Icon(_isAddingAnnotation ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  void _toggleAnnotationMode() {
    setState(() {
      _isAddingAnnotation = !_isAddingAnnotation;
      _selectedAnnotation = null;
    });
  }

  void _selectAnnotation(Annotation annotation) {
    setState(() {
      _selectedAnnotation = annotation;
      _isAddingAnnotation = false;
    });
    _showAnnotationDetails(annotation);
  }

  void _moveAnnotation(Annotation annotation, Offset delta) {
    setState(() {
      final index = _annotations.indexWhere((a) => a.id == annotation.id);
      if (index != -1) {
        _annotations[index] = annotation.copyWith(
          position: annotation.position + delta,
        );
      }
    });
    
    // Auto-save after moving annotation (with debounce)
    _debouncedSave();
  }

  void _showIssueTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Issue Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: IssueType.structuralIssues.length,
            itemBuilder: (context, index) {
              final issueType = IssueType.structuralIssues[index];
              return _buildIssueTypeCard(issueType);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isAddingAnnotation = false;
                _newAnnotationPosition = null;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTypeCard(IssueType issueType) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _addAnnotation(issueType);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                issueType.icon,
                color: issueType.color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                issueType.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addAnnotation(IssueType issueType) {
    if (_newAnnotationPosition == null) return;

    final annotation = Annotation(
      id: const Uuid().v4(),
      position: _newAnnotationPosition!,
      issueType: issueType.id,
      description: issueType.description,
      color: issueType.color,
      timestamp: DateTime.now(),
    );

    setState(() {
      _annotations.add(annotation);
      _isAddingAnnotation = false;
      _newAnnotationPosition = null;
    });

    // Auto-save after adding annotation (with debounce)
    _debouncedSave();
    _showAnnotationDetails(annotation);
  }

  void _showAnnotationDetails(Annotation annotation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getIssueName(annotation.issueType)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${annotation.description}'),
            const SizedBox(height: 8),
            Text('Added: ${_formatDateTime(annotation.timestamp)}'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Add any additional observations...',
              ),
              maxLines: 3,
              onChanged: (value) {
                // Update annotation with additional notes
                final index = _annotations.indexWhere((a) => a.id == annotation.id);
                if (index != -1) {
                  setState(() {
                    _annotations[index] = annotation.copyWith(
                      description: '${annotation.description}\n\nAdditional Notes: $value',
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnnotation(annotation);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAnnotation(Annotation annotation) {
    setState(() {
      _annotations.removeWhere((a) => a.id == annotation.id);
      if (_selectedAnnotation?.id == annotation.id) {
        _selectedAnnotation = null;
      }
    });
  }

  void _clearAllAnnotations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Annotations'),
        content: const Text('Are you sure you want to remove all annotations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _annotations.clear();
                _selectedAnnotation = null;
              });
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAnnotationList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annotations'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _annotations.length,
            itemBuilder: (context, index) {
              final annotation = _annotations[index];
              return ListTile(
                leading: Icon(
                  _getIssueIcon(annotation.issueType),
                  color: annotation.color,
                ),
                title: Text(_getIssueName(annotation.issueType)),
                subtitle: Text(_formatDateTime(annotation.timestamp)),
                onTap: () {
                  Navigator.pop(context);
                  _selectAnnotation(annotation);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteAnnotation(annotation),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIssueIcon(String issueType) {
    final issue = IssueType.structuralIssues.firstWhere(
      (i) => i.id == issueType,
      orElse: () => IssueType.structuralIssues.first,
    );
    return issue.icon;
  }

  String _getIssueName(String issueType) {
    final issue = IssueType.structuralIssues.firstWhere(
      (i) => i.id == issueType,
      orElse: () => IssueType.structuralIssues.first,
    );
    return issue.name;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _viewAnnotatedImage() async {
    if (_annotatedImagePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _AnnotatedImageViewer(
            imagePath: _annotatedImagePath!,
            originalPath: widget.imagePath,
          ),
        ),
      );
    } else if (_annotations.isNotEmpty) {
      // Generate annotated image if not already generated
      print('Generating annotated image for viewing...');
      final annotatedPath = await _imageService.generateAnnotatedImage(
        widget.imagePath,
        _annotations,
      );
      
      if (annotatedPath != null) {
        setState(() => _annotatedImagePath = annotatedPath);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _AnnotatedImageViewer(
              imagePath: annotatedPath,
              originalPath: widget.imagePath,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No annotations to display')),
      );
    }
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(milliseconds: 500), () {
      _saveAnnotations();
    });
  }

  Future<void> _saveAnnotations() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      print('Saving ${_annotations.length} annotations...');
      
      // Save annotation data
      await _storageService.saveAnnotations(widget.imagePath, _annotations);
      
      // Generate annotated image
      if (_annotations.isNotEmpty) {
        print('Generating annotated image...');
        final annotatedImagePath = await _imageService.generateAnnotatedImage(
          widget.imagePath,
          _annotations,
        );
        
        if (annotatedImagePath != null) {
          setState(() {
            _annotatedImagePath = annotatedImagePath;
          });
          print('Annotated image generated: $annotatedImagePath');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_annotations.length} annotation(s) saved'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving annotations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

class _AnnotatedImageViewer extends StatelessWidget {
  final String imagePath;
  final String originalPath;

  const _AnnotatedImageViewer({
    required this.imagePath,
    required this.originalPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotated Image'),
        actions: [
          IconButton(
            onPressed: () => _showImageComparison(context),
            icon: const Icon(Icons.compare),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }

  void _showImageComparison(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Comparison'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Original', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Image.file(File(originalPath), fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    const Text('Annotated', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Image.file(File(imagePath), fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}
