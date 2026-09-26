// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_settlement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripSettlementAdapter extends TypeAdapter<TripSettlement> {
  @override
  final int typeId = 8;

  @override
  TripSettlement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripSettlement(
      tripId: fields[0] as String,
      fromMember: fields[1] as String,
      toMember: fields[2] as String,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      note: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TripSettlement obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.fromMember)
      ..writeByte(2)
      ..write(obj.toMember)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripSettlementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
