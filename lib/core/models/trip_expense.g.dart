// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripExpenseAdapter extends TypeAdapter<TripExpense> {
  @override
  final int typeId = 7;

  @override
  TripExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripExpense(
      tripId: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      paidBy: fields[3] as String,
      date: fields[4] as DateTime,
      category: fields[5] as String? ?? 'other',
      splitModeIndex: fields[6] as int? ?? 0,
      shares: (fields[7] as Map).cast<String, double>(),
      note: fields[8] as String?,
      receiptPaths: (fields[9] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TripExpense obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.paidBy)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.splitModeIndex)
      ..writeByte(7)
      ..write(obj.shares)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.receiptPaths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
