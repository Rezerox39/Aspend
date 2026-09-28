// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripAdapter extends TypeAdapter<Trip> {
  @override
  final int typeId = 6;

  @override
  Trip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trip(
      name: fields[0] as String,
      destination: fields[1] as String?,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime?,
      memberNames: (fields[4] as List).cast<String>(),
      coverPhotoPath: fields[6] as String?,
      notes: fields[7] as String?,
      isArchived: fields[8] as bool? ?? false,
      createdAt: fields[9] as DateTime? ?? DateTime.now(),
      baseCurrency: fields[10] as String? ?? 'INR',
      members: (fields[11] as List?)?.cast<TripMember>() ?? const <TripMember>[],
    );
  }

  @override
  void write(BinaryWriter writer, Trip obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.destination)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.memberNames)
      ..writeByte(6)
      ..write(obj.coverPhotoPath)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.isArchived)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.baseCurrency)
      ..writeByte(11)
      ..write(obj.members);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
