import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../services/assessment_completion_service.dart';
import '../database/video_database.dart';

class AssessmentResultsScreen extends StatefulWidget {
  final AssessmentResult result;

  const AssessmentResultsScreen({
    super.key,
    required this.result,
  });

  @override
  State<AssessmentResultsScreen> createState() => _AssessmentResultsScreenState();
}

class _AssessmentResultsScreenState extends State<AssessmentResultsScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;
  String? _downloadedVideoPath;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
        actions: [
          IconButton(
            onPressed: () => _shareResults(context),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRiskLevelCard(),
            const SizedBox(height: 16),
            _buildAnalysisCard(),
            const SizedBox(height: 16),
            if (widget.result.failureMode != null) ...[
              _buildFailureModeCard(),
              const SizedBox(height: 16),
            ],
            _buildRecommendationsCard(),
            const SizedBox(height: 16),
            if (widget.result.videoUrl != null) ...[
              _buildVideoCard(),
              const SizedBox(height: 16),
            ],
            _buildMetricsCard(),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskLevelCard() {
    final Color riskColor = _getRiskColor(widget.result.riskLevel);
    
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [riskColor.withOpacity(0.1), riskColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getRiskIcon(widget.result.riskLevel),
              size: 48,
              color: riskColor,
            ).animate().scale(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              'Risk Level: ${widget.result.riskLevel.toUpperCase()}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: riskColor,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${widget.result.confidence.toUpperCase()}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    ).animate().slideY(begin: -0.2, end: 0);
  }

  Widget _buildAnalysisCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Structural Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.result.analysis,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildFailureModeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Most Likely Failure Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.result.failureMode!,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildRecommendationsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.result.recommendations.asMap().entries.map((entry) {
              final int index = entry.key;
              final String recommendation = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _buildVideoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: Colors.purple[600]),
                const SizedBox(width: 8),
                Text(
                  'Physics Simulation Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Video Player
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildVideoPlayer(),
              ),
            ),

            const SizedBox(height: 12),

            // Video Controls
            if (_downloadedVideoPath != null && _videoController != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Colors.purple[600]!,
                        bufferedColor: Colors.purple[200]!,
                        backgroundColor: Colors.grey[300]!,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay, size: 32),
                    onPressed: () {
                      _videoController!.seekTo(Duration.zero);
                      _videoController!.play();
                    },
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Download Button
            if (_downloadedVideoPath == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isVideoLoading ? null : () => _downloadAndPlayVideo(context),
                  icon: _isVideoLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isVideoLoading ? 'Downloading...' : 'Download & Play Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Downloading simulation video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_downloadedVideoPath != null && _videoController != null) {
      if (_videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(color: Colors.purple),
        );
      }
    }

    // Show placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 64,
            color: Colors.purple[300],
          ),
          const SizedBox(height: 8),
          const Text(
            'Physics-Based Simulation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '3 Phases: Damage → FEA → Collapse',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    if (widget.result.detailedMetrics == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo[600]),
                const SizedBox(width: 8),
                Text(
                  'Detailed Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.result.detailedMetrics!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 900.ms);
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _downloadReport(context),
            icon: const Icon(Icons.download),
            label: const Text('Download Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _contactExpert(context),
            icon: const Icon(Icons.phone),
            label: const Text('Contact Expert'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning;
      case 'high':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  void _shareResults(BuildContext context) {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing results...')),
    );
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    try {
      _videoController = VideoPlayerController.file(File(videoPath));
      await _videoController!.initialize();

      // Auto-play the video
      _videoController!.play();

      // Loop the video
      _videoController!.setLooping(true);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  Future<void> _downloadAndPlayVideo(BuildContext context) async {
    print('═══════════════════════════════════════════════════════');
    print('VIDEO DOWNLOAD STARTED');
    print('═══════════════════════════════════════════════════════');

    if (widget.result.videoUrl == null || widget.result.videoUrl!.isEmpty) {
      print('❌ ERROR: No video URL provided');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No simulation video available')),
        );
      }
      return;
    }

    print('✅ Video URL: ${widget.result.videoUrl}');
    print('📋 Assessment ID: ${widget.result.assessmentId}');
    print('⚠️  Risk Level: ${widget.result.riskLevel}');

    // Set loading state
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
      });
    }

    // Save scaffoldMessenger for later use
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      print('───────────────────────────────────────────────────────');
      print('STEP 1: Making HTTP request...');
      print('URL: ${widget.result.videoUrl}');

      final startTime = DateTime.now();
      final response = await http.get(
        Uri.parse(widget.result.videoUrl!),
        headers: {
          'Accept': 'video/mp4, video/*, */*',
          'User-Agent': 'IntegrityInspect/1.0',
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ ERROR: Request timed out after 60 seconds');
          throw Exception('Request timed out');
        },
      );

      final requestDuration = DateTime.now().difference(startTime);
      print('✅ Request completed in ${requestDuration.inSeconds}s');
      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body length: ${response.bodyBytes.length} bytes (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      print('📋 Response headers:');
      response.headers.forEach((key, value) {
        print('   $key: $value');
      });
      
      if (response.statusCode == 200) {
        print('───────────────────────────────────────────────────────');
        print('STEP 2: Getting storage directory...');

        // Get application documents directory (phone's internal app storage)
        final directory = await getApplicationDocumentsDirectory();
        print('✅ App documents directory: ${directory.path}');

        // Create simulation videos folder in app's private storage
        final videoDir = Directory('${directory.path}/simulation_videos');
        print('📁 Creating video directory: ${videoDir.path}');

        await videoDir.create(recursive: true);
        print('✅ Video directory created/verified');

        // Generate unique ID for the video
        final videoId = const Uuid().v4();
        final videoPath = '${videoDir.path}/$videoId.mp4';
        print('🆔 Generated video ID: $videoId');
        print('📍 Target file path: $videoPath');

        print('───────────────────────────────────────────────────────');
        print('STEP 3: Writing video file to phone storage...');

        // Save video file to phone's internal storage
        final file = File(videoPath);
        final writeStartTime = DateTime.now();
        await file.writeAsBytes(response.bodyBytes);
        final writeDuration = DateTime.now().difference(writeStartTime);
        print('✅ File write completed in ${writeDuration.inMilliseconds}ms');

        // Verify file was saved
        if (await file.exists()) {
          final fileSize = await file.length();
          print('✅✅✅ VIDEO SUCCESSFULLY SAVED TO PHONE! ✅✅✅');
          print('📍 Location: $videoPath');
          print('📦 Size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

          print('───────────────────────────────────────────────────────');
          print('STEP 4: Saving metadata to SQLite database...');

          // Save video metadata to SQLite database
          final videoMetadata = SimulationVideo(
            id: videoId,
            assessmentId: widget.result.assessmentId,
            videoPath: videoPath,
            riskLevel: widget.result.riskLevel,
            buildingType: widget.result.detailedMetrics?['building_type']?.toString() ?? 'Unknown',
            numberOfFloors: widget.result.detailedMetrics?['floors'] as int? ?? 0,
            collapseType: widget.result.failureMode ?? 'Unknown',
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
          );

          print('💾 Video metadata:');
          print('   ID: ${videoMetadata.id}');
          print('   Assessment ID: ${videoMetadata.assessmentId}');
          print('   Risk Level: ${videoMetadata.riskLevel}');
          print('   Building Type: ${videoMetadata.buildingType}');
          print('   Floors: ${videoMetadata.numberOfFloors}');
          print('   Collapse Type: ${videoMetadata.collapseType}');
          print('   File Size: ${videoMetadata.fileSize}');

          await VideoDatabase.instance.insertVideo(videoMetadata);
          print('✅ Video metadata saved to SQLite database');

          // Get total videos count
          final totalVideos = await VideoDatabase.instance.getTotalVideoCount();
          final totalStorage = await VideoDatabase.instance.getTotalStorageUsed();
          print('───────────────────────────────────────────────────────');
          print('📊 DATABASE STATS:');
          print('   Total videos stored: $totalVideos');
          print('   Total storage used: ${(totalStorage / 1024 / 1024).toStringAsFixed(2)} MB');
          print('═══════════════════════════════════════════════════════');

          print('───────────────────────────────────────────────────────');
          print('STEP 5: Initializing video player...');

          // Set downloaded video path and initialize player
          if (mounted) {
            setState(() {
              _downloadedVideoPath = videoPath;
            });
          }

          // Initialize video player
          await _initializeVideoPlayer(videoPath);
          print('✅ Video player initialized successfully');

          print('═══════════════════════════════════════════════════════');
          print('🎉 VIDEO DOWNLOAD COMPLETE!');
          print('═══════════════════════════════════════════════════════');

          // Reset loading state
          if (mounted) {
            setState(() {
              _isVideoLoading = false;
            });
          }

          // Show success message
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('✅ Video downloaded and ready to play!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          print('❌ ERROR: File was not created successfully');
          throw Exception('File was not created successfully');
        }

      } else {
        print('───────────────────────────────────────────────────────');
        print('❌ ERROR: HTTP request failed');
        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('═══════════════════════════════════════════════════════');

        // Reset loading state
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to download video: HTTP ${response.statusCode}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════');
      print('❌❌❌ FATAL ERROR DURING VIDEO DOWNLOAD ❌❌❌');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════════');

      // Reset loading state
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });

        print('Showing error message to user');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error downloading video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                print('User requested retry');
                _downloadAndPlayVideo(context);
              },
            ),
          ),
        );
      }
    }
  }

  void _showVideoSuccessDialog(BuildContext context, String videoPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Downloaded Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Blender 3D simulation video has been downloaded to your device.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'File: ${videoPath.split('/').last}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openVideoWithExternalApp(videoPath);
            },
            child: const Text('Open Video'),
          ),
        ],
      ),
    );
  }

  void _openVideoWithExternalApp(String videoPath) {
    // Show info about opening the video
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video saved to: ${videoPath.split('/').last}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View Folder',
          onPressed: () {
            // In a real implementation, you'd use a file manager plugin
            print('Opening folder containing: $videoPath');
          },
        ),
      ),
    );
  }

  void _downloadReport(BuildContext context) {
    // Implement report download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading report...')),
    );
  }

  void _contactExpert(BuildContext context) {
    // Implement expert contact
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contacting structural expert...')),
    );
  }
}
