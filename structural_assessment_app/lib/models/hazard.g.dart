
part of 'hazard.dart';


class HazardAdapter extends TypeAdapter<Hazard> {
  @override
  final int typeId = 1;

  @override
  Hazard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Hazard(
      id: fields[0] as String,
      type: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      severity: fields[4] as String,
      description: fields[5] as String,
      photoUrl: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Hazard obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.severity)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.photoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HazardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
