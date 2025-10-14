import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/assessment_completion_service.dart';

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
                  'Simulation Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.purple[600],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Simulation Video Available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generated by Sora AI',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _playVideo(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Simulation'),
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

  void _playVideo(BuildContext context) {
    // Play the physics simulation video
    if (widget.result.videoUrl != null && widget.result.videoUrl!.isNotEmpty) {
      print('Opening physics simulation video: ${widget.result.videoUrl}');
      
      // Show video player dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Physics Simulation Video'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                const Text('3D Physics-Based Collapse Simulation'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'Physics Simulation Video',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '3D Wireframe Collapse Analysis',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Video URL: ${widget.result.videoUrl}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // In a real implementation, this would open the video
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening physics simulation video...')),
                );
                Navigator.pop(context);
              },
              child: const Text('Play Video'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulation video not available')),
      );
    }
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
