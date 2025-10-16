

part of 'building_assessment.dart';

class BuildingAssessmentAdapter extends TypeAdapter<BuildingAssessment> {
  @override
  final int typeId = 0;

  @override
  BuildingAssessment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BuildingAssessment(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      buildingType: fields[2] as String,
      numberOfFloors: fields[3] as int,
      primaryMaterial: fields[4] as String,
      yearBuilt: fields[5] as int,
      damageTypes: (fields[6] as List).cast<String>(),
      damageDescription: fields[7] as String,
      photoUrls: (fields[8] as List).cast<String>(),
      latitude: fields[9] as double,
      longitude: fields[10] as double,
      hazards: (fields[11] as List).cast<Hazard>(),
      isSynced: fields[12] as bool,
      analysisResultId: fields[13] as String?,
      address: fields[14] as String?,
      notes: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BuildingAssessment obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.buildingType)
      ..writeByte(3)
      ..write(obj.numberOfFloors)
      ..writeByte(4)
      ..write(obj.primaryMaterial)
      ..writeByte(5)
      ..write(obj.yearBuilt)
      ..writeByte(6)
      ..write(obj.damageTypes)
      ..writeByte(7)
      ..write(obj.damageDescription)
      ..writeByte(8)
      ..write(obj.photoUrls)
      ..writeByte(9)
      ..write(obj.latitude)
      ..writeByte(10)
      ..write(obj.longitude)
      ..writeByte(11)
      ..write(obj.hazards)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.analysisResultId)
      ..writeByte(14)
      ..write(obj.address)
      ..writeByte(15)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingAssessmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
