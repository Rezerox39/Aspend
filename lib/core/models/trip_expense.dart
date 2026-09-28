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
///
/// ### Currencies
///
/// [amount] and [shares] are always in the **trip's base currency**, so every
/// balance, split and settle-up stays in one unit and can reach exactly zero.
/// An expense paid in another currency keeps what was actually spent in
/// [originalAmount] and [currency], plus the [exchangeRateToBase] that turned it
/// into the base amount, purely so the person can see what they really paid.
@HiveType(typeId: 7)
class TripExpense extends HiveObject {
  /// [Trip.key] as a string, so an expense does not need the trip object itself.
  @HiveField(0)
  String tripId;

  @HiveField(1)
  String title;

  /// Always the trip's base-currency amount.
  @HiveField(2)
  double amount;

  /// Id of the member who fronted the money.
  @HiveField(3)
  String paidBy;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String category;

  @HiveField(6)
  int splitModeIndex;

  /// Member id -> the base-currency amount that member owes. Always sums to
  /// exactly [amount].
  @HiveField(7)
  Map<String, double> shares;

  @HiveField(8)
  String? note;

  @HiveField(9)
  List<String>? receiptPaths;

  /// The currency this expense was actually entered in. Equals the trip's base
  /// currency unless it was a foreign purchase.
  @HiveField(10)
  String currency;

  /// How many units of [currency] one unit of the base currency is worth. 1.0
  /// for a same-currency expense.
  @HiveField(11)
  double exchangeRateToBase;

  /// What was paid, in [currency]. Null when the expense is already in the
  /// trip's base currency, so there is nothing extra to show.
  @HiveField(12)
  double? originalAmount;

  TripExpense({
    required this.tripId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.date,
    required Map<String, double> shares,
    this.category = 'other',
    this.splitModeIndex = 0,
    this.note,
    this.receiptPaths,
    this.currency = 'INR',
    this.exchangeRateToBase = 1.0,
    this.originalAmount,
  }) : shares = Map<String, double>.from(shares);

  SplitMode get splitMode => SplitMode.fromIndex(splitModeIndex);

  /// True when this expense was paid in a currency other than the trip's.
  bool get isForeign => originalAmount != null;

  /// Converts a foreign amount into the base currency, rounded to whole minor
  /// units so a converted expense still splits to a whole number of cents.
  static double toBaseAmount(double amount, double rate) =>
      (amount * rate).roundToDouble();

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
        'currency': currency,
        'exchangeRateToBase': exchangeRateToBase,
        'originalAmount': originalAmount,
      };
}
