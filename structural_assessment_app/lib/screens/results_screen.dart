import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/analysis_result.dart';
import '../models/building_assessment.dart';
import '../services/video_service.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatefulWidget {
  final BuildingAssessment assessment;
  final AnalysisResult result;

  const ResultsScreen({
    super.key,
    required this.assessment,
    required this.result,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  double? _downloadProgress;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (widget.result.localVideoPath != null &&
        await File(widget.result.localVideoPath!).exists()) {
      // Play from local file
      _videoController = VideoPlayerController.file(
        File(widget.result.localVideoPath!),
      );
    } else if (widget.result.videoUrl != null) {
      // Play from network (or show download button)
      return;
    }

    if (_videoController != null) {
      await _videoController!.initialize();
      setState(() => _isVideoInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildRiskBanner(),
                _buildAnalysisSection(),
                if (widget.result.failureMode != null) _buildFailureModeSection(),
                _buildRecommendationsSection(),
                if (widget.result.videoUrl != null) _buildVideoSection(),
                _buildAssessmentDetailsSection(),
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButtons(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.getRiskGradient(widget.result.riskLevel),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Analysis Complete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    widget.assessment.buildingType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.assessment.numberOfFloors} floors • ${widget.assessment.primaryMaterial}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.getRiskGradient(widget.result.riskLevel),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.getRiskColor(widget.result.riskLevel).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRiskIcon(),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RISK LEVEL',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.result.riskLevel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${widget.result.confidence ?? 'Medium'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms)
        .slideY(begin: 0.2, end: 0)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildAnalysisSection() {
    return _buildSection(
      title: 'Structural Analysis',
      icon: Icons.analytics,
      child: Text(
        widget.result.analysis,
        style: const TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Color(0xFF424242),
        ),
      ),
    );
  }

  Widget _buildFailureModeSection() {
    return _buildSection(
      title: 'Failure Mode',
      icon: Icons.warning_amber,
      iconColor: const Color(0xFFFF9800),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Color(0xFFFF9800), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.result.failureMode!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return _buildSection(
      title: 'Safety Recommendations',
      icon: Icons.checklist,
      iconColor: const Color(0xFF4CAF50),
      child: Column(
        children: widget.result.recommendations.asMap().entries.map((entry) {
          return _buildRecommendationItem(
            entry.value,
            entry.key,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendationItem(String recommendation, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index))
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildVideoSection() {
    return _buildSection(
      title: 'Collapse Simulation',
      icon: Icons.video_library,
      iconColor: const Color(0xFFF44336),
      child: Column(
        children: [
          if (widget.result.isVideoDownloaded && _isVideoInitialized)
            _buildVideoPlayer()
          else if (_isDownloading)
            _buildDownloadProgress()
          else
            _buildDownloadButton(),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFF44336), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This simulation shows potential failure progression. For reference only.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            if (!_videoController!.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, size: 64),
                  color: Colors.white,
                  onPressed: () {
                    setState(() {
                      _videoController!.play();
                    });
                  },
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: const Color(0xFF2196F3),
                  backgroundColor: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildDownloadProgress() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Downloading video...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 8),
          if (_downloadProgress != null)
            Text(
              '${(_downloadProgress! * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.download, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Download Simulation Video',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save for offline viewing',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _downloadVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Download Now'),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildAssessmentDetailsSection() {
    return _buildSection(
      title: 'Assessment Details',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildDetailRow('Building Type', widget.assessment.buildingType),
          _buildDetailRow('Floors', '${widget.assessment.numberOfFloors}'),
          _buildDetailRow('Material', widget.assessment.primaryMaterial),
          _buildDetailRow('Year Built', '${widget.assessment.yearBuilt}'),
          _buildDetailRow(
            'Assessed',
            '${widget.assessment.timestamp.toString().substring(0, 16)}',
          ),
          _buildDetailRow(
            'Generated',
            '${widget.result.generatedAt.toString().substring(0, 16)}',
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? const Color(0xFF2196F3), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF757575),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF212121),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'share',
          onPressed: _shareReport,
          backgroundColor: const Color(0xFF4CAF50),
          child: const Icon(Icons.share),
        ),
        if (widget.result.isVideoDownloaded && widget.result.localVideoPath != null)
          const SizedBox(height: 12),
        if (widget.result.isVideoDownloaded && widget.result.localVideoPath != null)
          FloatingActionButton(
            heroTag: 'open_video',
            onPressed: _openVideo,
            backgroundColor: const Color(0xFF2196F3),
            child: const Icon(Icons.open_in_new),
          ),
      ],
    ).animate().fadeIn().scale();
  }

  IconData _getRiskIcon() {
    switch (widget.result.riskLevel.toLowerCase()) {
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

  Future<void> _downloadVideo() async {
    if (widget.result.videoUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final videoService = context.read<VideoService>();
      final localPath = await videoService.downloadVideo(
        videoUrl: widget.result.videoUrl!,
        analysisId: widget.result.id,
        onProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (localPath != null) {
        // Update result with local path
        setState(() {
          _isDownloading = false;
        });

        await _initializeVideo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video downloaded successfully!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isDownloading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    final text = '''
Structural Assessment Report

Building: ${widget.assessment.buildingType.toUpperCase()}
Risk Level: ${widget.result.riskLevel.toUpperCase()}
Date: ${DateTime.now().toString().substring(0, 16)}

Analysis:
${widget.result.analysis}

Generated by Integrity Inspect
''';

    await Share.share(text, subject: 'Structural Assessment Report');
  }

  Future<void> _openVideo() async {
    if (widget.result.localVideoPath != null) {
      final videoService = context.read<VideoService>();
      await videoService.openVideo(widget.result.localVideoPath!);
    }
  }
}
