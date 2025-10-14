import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'local_storage_service.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  final Map<String, CancelToken> _cancelTokens = {};

  // Download video from URL
  Future<String?> downloadVideo({
    required String videoUrl,
    required String analysisId,
    Function(double)? onProgress,
  }) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission not granted');
        }
      }

      // Get save directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoDir = path.join(appDir.path, 'videos');
      final Directory videoDirObj = Directory(videoDir);

      if (!await videoDirObj.exists()) {
        await videoDirObj.create(recursive: true);
      }

      // Generate file name
      final String fileName = 'analysis_${analysisId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = path.join(videoDir, fileName);

      // Create cancel token
      final cancelToken = CancelToken();
      _cancelTokens[analysisId] = cancelToken;

      // Download the video
      await _dio.download(
        videoUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _downloadProgress[analysisId] = progress;
            onProgress?.call(progress);
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      // Update analysis result with local path
      await LocalStorageService().updateAnalysisVideoDownloadStatus(
        id: analysisId,
        isDownloaded: true,
        localPath: filePath,
      );

      // Clean up
      _downloadProgress.remove(analysisId);
      _cancelTokens.remove(analysisId);

      return filePath;
    } catch (e) {
      print('Error downloading video: $e');
      _downloadProgress.remove(analysisId);
      _cancelTokens.remove(analysisId);
      return null;
    }
  }

  // Cancel video download
  void cancelDownload(String analysisId) {
    final cancelToken = _cancelTokens[analysisId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download cancelled by user');
      _downloadProgress.remove(analysisId);
      _cancelTokens.remove(analysisId);
    }
  }

  // Get download progress
  double? getDownloadProgress(String analysisId) {
    return _downloadProgress[analysisId];
  }

  // Check if video is downloading
  bool isDownloading(String analysisId) {
    return _cancelTokens.containsKey(analysisId);
  }

  // Delete downloaded video
  Future<bool> deleteVideo(String filePath) async {
    try {
      final File videoFile = File(filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  // Get video file size
  Future<int> getVideoSize(String filePath) async {
    try {
      final File videoFile = File(filePath);
      if (await videoFile.exists()) {
        return await videoFile.length();
      }
      return 0;
    } catch (e) {
      print('Error getting video size: $e');
      return 0;
    }
  }

  // Format file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Get video duration (requires video_player package)
  Future<Duration?> getVideoDuration(String filePath) async {
    // This would require video_player package
    // Implementation depends on your specific needs
    return null;
  }

  // Share video
  Future<void> shareVideo(String filePath) async {
    try {
      final File videoFile = File(filePath);
      if (await videoFile.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Structural Analysis Video',
          text: 'Analysis video from Integrity Inspect',
        );
      }
    } catch (e) {
      print('Error sharing video: $e');
    }
  }

  // Open video with external player
  Future<void> openVideo(String filePath) async {
    try {
      final File videoFile = File(filePath);
      if (await videoFile.exists()) {
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      print('Error opening video: $e');
    }
  }

  // Get all downloaded videos
  Future<List<String>> getAllDownloadedVideos() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoDir = path.join(appDir.path, 'videos');
      final Directory videoDirObj = Directory(videoDir);

      if (!await videoDirObj.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = videoDirObj.listSync();
      return files
          .where((file) => file.path.endsWith('.mp4'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error getting downloaded videos: $e');
      return [];
    }
  }

  // Delete all downloaded videos
  Future<int> deleteAllVideos() async {
    try {
      final videos = await getAllDownloadedVideos();
      int deletedCount = 0;

      for (final videoPath in videos) {
        if (await deleteVideo(videoPath)) {
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      print('Error deleting all videos: $e');
      return 0;
    }
  }

  // Get total storage used by videos
  Future<int> getTotalVideoStorage() async {
    try {
      final videos = await getAllDownloadedVideos();
      int totalSize = 0;

      for (final videoPath in videos) {
        totalSize += await getVideoSize(videoPath);
      }

      return totalSize;
    } catch (e) {
      print('Error calculating total storage: $e');
      return 0;
    }
  }

  // Move video to external storage (Android only)
  Future<String?> moveToExternalStorage(String filePath) async {
    if (!Platform.isAndroid) return filePath;

    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return null;

      final String externalPath = path.join(
        externalDir.path,
        'IntegrityInspect',
        'Videos',
        path.basename(filePath),
      );

      // Create directory if it doesn't exist
      final Directory externalVideoDir = Directory(path.dirname(externalPath));
      if (!await externalVideoDir.exists()) {
        await externalVideoDir.create(recursive: true);
      }

      // Copy file
      final File sourceFile = File(filePath);
      await sourceFile.copy(externalPath);

      // Delete original
      await sourceFile.delete();

      return externalPath;
    } catch (e) {
      print('Error moving to external storage: $e');
      return null;
    }
  }

  // Check if video file exists
  Future<bool> videoExists(String filePath) async {
    try {
      final File videoFile = File(filePath);
      return await videoFile.exists();
    } catch (e) {
      return false;
    }
  }

  // Clean up old videos (older than X days)
  Future<int> cleanupOldVideos({int daysOld = 30}) async {
    try {
      final videos = await getAllDownloadedVideos();
      final DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      for (final videoPath in videos) {
        final File videoFile = File(videoPath);
        final DateTime modifiedDate = await videoFile.lastModified();

        if (modifiedDate.isBefore(cutoffDate)) {
          if (await deleteVideo(videoPath)) {
            deletedCount++;
          }
        }
      }

      return deletedCount;
    } catch (e) {
      print('Error cleaning up old videos: $e');
      return 0;
    }
  }
}
