part of 'analysis_result.dart';



class AnalysisResultAdapter extends TypeAdapter<AnalysisResult> {
  @override
  final int typeId = 2;

  @override
  AnalysisResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnalysisResult(
      id: fields[0] as String,
      assessmentId: fields[1] as String,
      riskLevel: fields[2] as String,
      analysis: fields[3] as String,
      failureMode: fields[4] as String?,
      recommendations: (fields[5] as List).cast<String>(),
      videoUrl: fields[6] as String?,
      generatedAt: fields[7] as DateTime,
      detailedMetrics: (fields[8] as Map?)?.cast<String, dynamic>(),
      confidence: fields[9] as String?,
      isVideoDownloaded: fields[10] as bool,
      localVideoPath: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisResult obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assessmentId)
      ..writeByte(2)
      ..write(obj.riskLevel)
      ..writeByte(3)
      ..write(obj.analysis)
      ..writeByte(4)
      ..write(obj.failureMode)
      ..writeByte(5)
      ..write(obj.recommendations)
      ..writeByte(6)
      ..write(obj.videoUrl)
      ..writeByte(7)
      ..write(obj.generatedAt)
      ..writeByte(8)
      ..write(obj.detailedMetrics)
      ..writeByte(9)
      ..write(obj.confidence)
      ..writeByte(10)
      ..write(obj.isVideoDownloaded)
      ..writeByte(11)
      ..write(obj.localVideoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
