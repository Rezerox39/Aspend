import 'package:hive/hive.dart';

part 'trip_settlement.g.dart';

/// A record that one member has paid another back, closing part of a trip's
/// outstanding balance.
///
/// Settlements are stored as a ledger rather than applied destructively to the
/// expenses, so the original expenses stay intact and the trip history reads
/// correctly after a settle-up.
@HiveType(typeId: 8)
class TripSettlement extends HiveObject {
  @HiveField(0)
  String tripId;

  /// Member who made the payment.
  @HiveField(1)
  String fromMember;

  /// Member who received it.
  @HiveField(2)
  String toMember;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String? note;

  TripSettlement({
    required this.tripId,
    required this.fromMember,
    required this.toMember,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'fromMember': fromMember,
        'toMember': toMember,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };
}
