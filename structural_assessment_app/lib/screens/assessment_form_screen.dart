import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/building_assessment.dart';
import '../models/hazard.dart';
import '../services/local_storage_service.dart';
import '../services/assessment_completion_service.dart';
import '../services/annotation_storage_service.dart';
import '../models/annotation.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';
import 'photo_capture_screen.dart';
import 'assessment_results_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Form controllers
  final _numberOfFloorsController = TextEditingController();
  final _yearBuiltController = TextEditingController();
  final _damageDescriptionController = TextEditingController();
  final _notesController = TextEditingController();

  // Form data
  String _buildingType = AppConstants.buildingTypes[0];
  int _numberOfFloors = 1;
  String _primaryMaterial = AppConstants.materialTypes[0];
  int _yearBuilt = DateTime.now().year;
  List<String> _selectedDamageTypes = [];
  String _damageDescription = '';
  String _notes = '';
  List<String> _photoUrls = [];
  double _latitude = 0.0;
  double _longitude = 0.0;
  String _address = '';
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  List<Hazard> _hazards = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _getCurrentLocation();
  }

  void _initializeControllers() {
    _numberOfFloorsController.text = _numberOfFloors.toString();
    _yearBuiltController.text = _yearBuilt.toString();
    _damageDescriptionController.text = _damageDescription;
    _notesController.text = _notes;
  }

  @override
  void dispose() {
    _numberOfFloorsController.dispose();
    _yearBuiltController.dispose();
    _damageDescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Assessment'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: _onStepContinue,
                onStepCancel: _onStepCancel,
                controlsBuilder: _buildStepControls,
                type: StepperType.horizontal,
                steps: [
                  Step(
                    title: const Text('Type'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    content: _buildBuildingTypeStep(),
                  ),
                  Step(
                    title: const Text('Details'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    content: _buildBuildingDetailsStep(),
                  ),
                  Step(
                    title: const Text('Damage'),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    content: _buildDamageStep(),
                  ),
                  Step(
                    title: const Text('Photos'),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                    content: _buildPhotosStep(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 4',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                ),
              ),
              Text(
                '${((_currentStep + 1) / 4 * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              minHeight: 6,
              backgroundColor: const Color(0xFFE3F2FD),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildBuildingTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Building Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),
        ...AppConstants.buildingTypes.map((type) {
          final isSelected = _buildingType == type;
          return _buildOptionCard(
            title: AppConstants.buildingTypeLabels[type]!,
            icon: _getBuildingIcon(type),
            isSelected: isSelected,
            onTap: () => setState(() => _buildingType = type),
          );
        }).toList(),
      ],
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  Widget _buildBuildingDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Building Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),

        // Number of Floors
        TextFormField(
          controller: _numberOfFloorsController,
          decoration: const InputDecoration(
            labelText: 'Number of Floors',
            hintText: 'Enter number of floors',
            prefixIcon: Icon(Icons.layers),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter number of floors';
            }
            final number = int.tryParse(value);
            if (number == null || number < 1) {
              return 'Please enter a valid number';
            }
            return null;
          },
          onSaved: (value) => _numberOfFloors = int.parse(value!),
        ),
        const SizedBox(height: 16),

        // Primary Material
        DropdownButtonFormField<String>(
          value: _primaryMaterial,
          decoration: const InputDecoration(
            labelText: 'Primary Material',
            prefixIcon: Icon(Icons.construction),
          ),
          items: AppConstants.materialTypes.map((material) {
            return DropdownMenuItem(
              value: material,
              child: Text(AppConstants.materialTypeLabels[material]!),
            );
          }).toList(),
          onChanged: (value) => setState(() => _primaryMaterial = value!),
        ),
        const SizedBox(height: 16),

        // Year Built
        TextFormField(
          controller: _yearBuiltController,
          decoration: const InputDecoration(
            labelText: 'Year Built',
            hintText: 'Enter construction year',
            prefixIcon: Icon(Icons.calendar_today),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter year built';
            }
            final year = int.tryParse(value);
            if (year == null || year < 1800 || year > DateTime.now().year) {
              return 'Please enter a valid year';
            }
            return null;
          },
          onSaved: (value) => _yearBuilt = int.parse(value!),
        ),
        const SizedBox(height: 16),

        // Location
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF2196F3)),
                    const SizedBox(width: 8),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoadingLocation)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _getCurrentLocation,
                        iconSize: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Lat: ${_latitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Color(0xFF757575)),
                ),
                Text(
                  'Lng: ${_longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  Widget _buildDamageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Damage Assessment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Select Damage Types',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.damageTypes.map((damage) {
            final isSelected = _selectedDamageTypes.contains(damage);
            return FilterChip(
              label: Text(AppConstants.damageTypeLabels[damage]!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDamageTypes.add(damage);
                  } else {
                    _selectedDamageTypes.remove(damage);
                  }
                });
              },
              selectedColor: const Color(0xFF2196F3).withOpacity(0.2),
              checkmarkColor: const Color(0xFF2196F3),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        TextFormField(
          controller: _damageDescriptionController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Damage Description *',
            hintText: 'Describe the damage in detail...',
            alignLabelWithHint: true,
          ),
          onChanged: (value) => _damageDescription = value,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please describe the damage';
            }
            return null;
          },
          onSaved: (value) => _damageDescription = value!,
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (Optional)',
            hintText: 'Any additional observations...',
            alignLabelWithHint: true,
          ),
          onChanged: (value) => _notes = value,
          onSaved: (value) => _notes = value ?? '',
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  Widget _buildPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo Documentation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),

        if (_photoUrls.isEmpty)
          Card(
            child: InkWell(
              onTap: _navigateToPhotoCapture,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to capture photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'At least 1 photo required',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photoUrls.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoUrls[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 16),
                            color: Colors.white,
                            onPressed: () {
                              setState(() => _photoUrls.removeAt(index));
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _navigateToPhotoCapture,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add More Photos'),
              ),
            ],
          ),

        const SizedBox(height: 16),

        if (_photoUrls.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_photoUrls.length} photo${_photoUrls.length > 1 ? 's' : ''} added',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2196F3).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF212121),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF2196F3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBuildingIcon(String type) {
    switch (type) {
      case 'residential':
        return Icons.home;
      case 'commercial':
        return Icons.business;
      case 'industrial':
        return Icons.factory;
      case 'mixed_use':
        return Icons.apartment;
      default:
        return Icons.business;
    }
  }

  Widget _buildStepControls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                print('Back button pressed');
                details.onStepCancel?.call();
              },
              child: const Text('Back'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                print('Continue button pressed for step $_currentStep');
                details.onStepContinue?.call();
              },
              child: Text(_currentStep == 3 ? 'Submit' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    print('=== STEP CONTINUE DEBUG ===');
    print('Current step: $_currentStep');
    print('Damage types: $_selectedDamageTypes');
    print('Damage description: "$_damageDescription"');
    print('Damage description length: ${_damageDescription.length}');
    print('Damage description trimmed: "${_damageDescription.trim()}"');
    print('Damage description trimmed length: ${_damageDescription.trim().length}');
    
    if (_currentStep == 0) {
      print('Step 0: Building type selected, continuing...');
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      print('Step 1: Validating building details...');
      print('Step 1: Number of floors: $_numberOfFloors');
      print('Step 1: Primary material: $_primaryMaterial');
      print('Step 1: Year built: $_yearBuilt');
      print('Step 1: Latitude: $_latitude');
      print('Step 1: Longitude: $_longitude');
      
      // Manual validation instead of form validation
      if (_numberOfFloorsController.text.isEmpty || int.tryParse(_numberOfFloorsController.text) == null) {
        print('Step 1: Number of floors validation failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number of floors')),
        );
        return;
      }
      
      if (_yearBuiltController.text.isEmpty || int.tryParse(_yearBuiltController.text) == null) {
        print('Step 1: Year built validation failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid year')),
        );
        return;
      }
      
      // Update variables from controllers
      _numberOfFloors = int.parse(_numberOfFloorsController.text);
      _yearBuilt = int.parse(_yearBuiltController.text);
      
      print('Step 1: Manual validation passed, moving to next step');
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      print('Step 2: Validating damage assessment...');
      
      // Check damage types
      if (_selectedDamageTypes.isEmpty) {
        print('Step 2: No damage types selected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one damage type')),
        );
        return;
      }
      print('Step 2: Damage types selected: $_selectedDamageTypes');
      
      // Check damage description
      if (_damageDescription.trim().isEmpty) {
        print('Step 2: Damage description is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please describe the damage')),
        );
        return;
      }
      print('Step 2: Damage description is valid');
      
      print('Step 2: All validations passed, moving to next step');
      setState(() => _currentStep++);
    } else if (_currentStep == 3) {
      print('Step 3: Final submission...');
      if (_photoUrls.isEmpty) {
        print('Step 3: No photos added');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one photo')),
        );
        return;
      }
      print('Step 3: Submitting assessment...');
      _submitAssessment();
    }
    print('=== END STEP CONTINUE DEBUG ===');
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _navigateToPhotoCapture() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoCaptureScreen(existingPhotos: _photoUrls),
      ),
    );

    if (result != null) {
      setState(() => _photoUrls = result);
    }
  }

  Future<void> _submitAssessment() async {
    try {
      setState(() => _isSubmitting = true);

      print('Starting assessment submission...');
      print('Photos: ${_photoUrls.length}');
      print('Damage types: $_selectedDamageTypes');
      print('Description: $_damageDescription');

      // Collect all annotations from photos
      final List<Annotation> allAnnotations = [];
      final AnnotationStorageService storageService = AnnotationStorageService();
      
      for (final photoPath in _photoUrls) {
        try {
          final annotations = await storageService.loadAnnotations(photoPath);
          allAnnotations.addAll(annotations);
          print('Loaded ${annotations.length} annotations from $photoPath');
        } catch (e) {
          print('Error loading annotations from $photoPath: $e');
        }
      }

      print('Total annotations collected: ${allAnnotations.length}');

      // Create assessment data
      final assessmentData = AssessmentData(
        buildingType: _buildingType,
        numberOfFloors: _numberOfFloors,
        primaryMaterial: _primaryMaterial,
        yearBuilt: _yearBuilt,
        damageTypes: _selectedDamageTypes,
        damageDescription: _damageDescription,
        latitude: _latitude,
        longitude: _longitude,
        hazards: _hazards.map((h) => h.toJson()).toList(),
        notes: _notes,
      );

      
      final AssessmentCompletionService completionService = AssessmentCompletionService();
      final AssessmentResult result = await completionService.submitCompleteAssessment(
        assessmentData: assessmentData,
        photoPaths: _photoUrls,
        annotations: allAnnotations,
      );

      print('Assessment completed successfully!');
      print('Risk level: ${result.riskLevel}');
      print('Recommendations: ${result.recommendations.length}');

      if (mounted) {
        // Navigate to results screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AssessmentResultsScreen(result: result),
          ),
        );
      }
    } catch (e) {
      print('Error submitting assessment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting assessment: $e'),
            backgroundColor: const Color(0xFFF44336),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
