import 'package:hive/hive.dart';

part 'trip_expense.g.dart';

/// How an expense's amount was divided between the members.
enum SplitMode {
  /// Everyone pays an identical share.
  equal,

  /// Each member owes a hand-entered amount.
  exact,

  /// Each member enters a weight (2 shares = twice a 1-share member).
  shares,

  /// Each member enters a percentage of the total.
  percentage;

  static SplitMode fromIndex(int index) =>
      index >= 0 && index < SplitMode.values.length
          ? SplitMode.values[index]
          : SplitMode.equal;
}

/// A single shared expense inside a [Trip].
///
/// The per-member split is **stored resolved** (see [shares]) rather than
/// storing the raw inputs and recomputing it. That keeps balance maths a plain
/// sum over saved data, so editing a trip's members later can never silently
/// rewrite what past expenses meant.
@HiveType(typeId: 7)
class TripExpense extends HiveObject {
  /// [Trip.key] as a string, so an expense does not need the trip object itself.
  @HiveField(0)
  String tripId;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  /// Name of the member who fronted the money.
  @HiveField(3)
  String paidBy;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String category;

  @HiveField(6)
  int splitModeIndex;

  /// Member name -> the amount that member owes for this expense. Always sums
  /// to exactly [amount].
  @HiveField(7)
  Map<String, double> shares;

  @HiveField(8)
  String? note;

  @HiveField(9)
  List<String>? receiptPaths;

  TripExpense({
    required this.tripId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.shares,
    this.category = 'other',
    this.splitModeIndex = 0,
    this.note,
    this.receiptPaths,
  }) : shares = Map<String, double>.from(shares);

  SplitMode get splitMode => SplitMode.fromIndex(splitModeIndex);

  /// What [paidBy] is owed back in total for this expense.
  double get owedToPayer {
    var total = 0.0;
    for (final entry in shares.entries) {
      if (entry.key != paidBy) total += entry.value;
    }
    return total;
  }

  /// The member's own share of what they paid (what they are owed back).
  double get payerOwnShare => shares[paidBy] ?? 0.0;

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'date': date.toIso8601String(),
        'category': category,
        'splitModeIndex': splitModeIndex,
        'shares': shares,
        'note': note,
        'receiptPaths': receiptPaths,
      };
}
