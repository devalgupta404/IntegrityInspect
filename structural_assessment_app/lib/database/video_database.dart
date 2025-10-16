import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class SimulationVideo {
  final String id;
  final String assessmentId;
  final String videoPath;
  final String riskLevel;
  final String buildingType;
  final int numberOfFloors;
  final String collapseType;
  final int fileSize;
  final DateTime downloadedAt;

  SimulationVideo({
    required this.id,
    required this.assessmentId,
    required this.videoPath,
    required this.riskLevel,
    required this.buildingType,
    required this.numberOfFloors,
    required this.collapseType,
    required this.fileSize,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assessmentId': assessmentId,
      'videoPath': videoPath,
      'riskLevel': riskLevel,
      'buildingType': buildingType,
      'numberOfFloors': numberOfFloors,
      'collapseType': collapseType,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory SimulationVideo.fromMap(Map<String, dynamic> map) {
    return SimulationVideo(
      id: map['id'],
      assessmentId: map['assessmentId'],
      videoPath: map['videoPath'],
      riskLevel: map['riskLevel'],
      buildingType: map['buildingType'],
      numberOfFloors: map['numberOfFloors'],
      collapseType: map['collapseType'],
      fileSize: map['fileSize'],
      downloadedAt: DateTime.parse(map['downloadedAt']),
    );
  }
}

class VideoDatabase {
  static final VideoDatabase instance = VideoDatabase._init();
  static Database? _database;

  VideoDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('simulation_videos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE simulation_videos (
        id TEXT PRIMARY KEY,
        assessmentId TEXT NOT NULL,
        videoPath TEXT NOT NULL,
        riskLevel TEXT NOT NULL,
        buildingType TEXT NOT NULL,
        numberOfFloors INTEGER NOT NULL,
        collapseType TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        downloadedAt TEXT NOT NULL
      )
    ''');
  }

  Future<String> insertVideo(SimulationVideo video) async {
    final db = await instance.database;
    await db.insert(
      'simulation_videos',
      video.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return video.id;
  }

  Future<SimulationVideo?> getVideoById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'simulation_videos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SimulationVideo.fromMap(maps.first);
    }
    return null;
  }

  Future<SimulationVideo?> getVideoByAssessmentId(String assessmentId) async {
    final db = await instance.database;
    final maps = await db.query(
      'simulation_videos',
      where: 'assessmentId = ?',
      whereArgs: [assessmentId],
    );

    if (maps.isNotEmpty) {
      return SimulationVideo.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SimulationVideo>> getAllVideos() async {
    final db = await instance.database;
    final result = await db.query(
      'simulation_videos',
      orderBy: 'downloadedAt DESC',
    );

    return result.map((json) => SimulationVideo.fromMap(json)).toList();
  }

  Future<int> deleteVideo(String id) async {
    final db = await instance.database;

    // Also delete the video file from disk
    final video = await getVideoById(id);
    if (video != null) {
      final file = File(video.videoPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    return await db.delete(
      'simulation_videos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getTotalVideoCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM simulation_videos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalStorageUsed() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(fileSize) as total FROM simulation_videos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<SimulationVideo>> getVideosByRiskLevel(String riskLevel) async {
    final db = await instance.database;
    final result = await db.query(
      'simulation_videos',
      where: 'riskLevel = ?',
      whereArgs: [riskLevel],
      orderBy: 'downloadedAt DESC',
    );

    return result.map((json) => SimulationVideo.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
