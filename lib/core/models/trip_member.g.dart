// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_member.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripMemberAdapter extends TypeAdapter<TripMember> {
  @override
  final int typeId = 9;

  @override
  TripMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripMember(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String?,
      email: fields[3] as String?,
      label: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TripMember obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
