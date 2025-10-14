import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/building_assessment.dart';
import '../models/hazard.dart';
import '../services/local_storage_service.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';
import 'photo_capture_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
          initialValue: _numberOfFloors.toString(),
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
          initialValue: _yearBuilt.toString(),
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
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Damage Description',
            hintText: 'Describe the damage in detail...',
            alignLabelWithHint: true,
          ),
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
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (Optional)',
            hintText: 'Any additional observations...',
            alignLabelWithHint: true,
          ),
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
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              child: Text(_currentStep == 3 ? 'Submit' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Building type selected, continue
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Validate building details
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 2) {
      // Validate damage
      if (_selectedDamageTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one damage type')),
        );
        return;
      }
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 3) {
      // Final submission
      if (_photoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one photo')),
        );
        return;
      }
      _submitAssessment();
    }
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
      final assessment = BuildingAssessment(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        buildingType: _buildingType,
        numberOfFloors: _numberOfFloors,
        primaryMaterial: _primaryMaterial,
        yearBuilt: _yearBuilt,
        damageTypes: _selectedDamageTypes,
        damageDescription: _damageDescription,
        photoUrls: _photoUrls,
        latitude: _latitude,
        longitude: _longitude,
        hazards: [],
        notes: _notes,
      );

      await context.read<LocalStorageService>().saveAssessment(assessment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment saved successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(assessment);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving assessment: $e')),
      );
    }
  }
}
