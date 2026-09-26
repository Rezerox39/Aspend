import 'package:aspends_tracker/core/const/app_constants.dart';
import 'package:aspends_tracker/core/models/trip.dart';
import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/models/trip_settlement.dart';
import 'package:hive/hive.dart';

/// Hive-backed storage for group trips and their shared expenses.
class TripRepository {
  static const String _tripsBoxName = AppConstants.tripsBox;
  static const String _expensesBoxName = AppConstants.tripExpensesBox;
  static const String _settlementsBoxName = AppConstants.tripSettlementsBox;

  Box<Trip> get _tripsBox => Hive.box<Trip>(_tripsBoxName);
  Box<TripExpense> get _expensesBox => Hive.box<TripExpense>(_expensesBoxName);
  Box<TripSettlement> get _settlementsBox =>
      Hive.box<TripSettlement>(_settlementsBoxName);

  // ---------------------------------------------------------------- trips

  List<Trip> getAllTrips() => _tripsBox.values.toList();

  Future<void> addTrip(Trip trip) => _tripsBox.add(trip);

  Future<void> updateTrip(dynamic key, Trip trip) => _tripsBox.put(key, trip);

  /// Removes a trip together with every expense and settlement under it, so a
  /// deleted trip can never leave orphaned rows behind.
  Future<void> deleteTrip(dynamic key) async {
    final tripId = key.toString();
    final expenseKeys = <dynamic>[];
    final settlementKeys = <dynamic>[];

    for (final expense in _expensesBox.values) {
      if (expense.tripId == tripId) expenseKeys.add(expense.key);
    }
    for (final settlement in _settlementsBox.values) {
      if (settlement.tripId == tripId) settlementKeys.add(settlement.key);
    }

    await _expensesBox.deleteAll(expenseKeys);
    await _settlementsBox.deleteAll(settlementKeys);
    await _tripsBox.delete(key);
  }

  Stream<BoxEvent> watchTrips() => _tripsBox.watch();

  // ------------------------------------------------------------- expenses

  List<TripExpense> getAllExpenses() => _expensesBox.values.toList();

  List<TripExpense> getExpensesForTrip(String tripId) => _expensesBox.values
      .where((expense) => expense.tripId == tripId)
      .toList();

  Future<void> addExpense(TripExpense expense) => _expensesBox.add(expense);

  Future<void> updateExpense(dynamic key, TripExpense expense) =>
      _expensesBox.put(key, expense);

  Future<void> deleteExpense(dynamic key) => _expensesBox.delete(key);

  Stream<BoxEvent> watchExpenses() => _expensesBox.watch();

  // ---------------------------------------------------------- settlements

  List<TripSettlement> getAllSettlements() => _settlementsBox.values.toList();

  List<TripSettlement> getSettlementsForTrip(String tripId) =>
      _settlementsBox.values
          .where((settlement) => settlement.tripId == tripId)
          .toList();

  Future<void> addSettlement(TripSettlement settlement) =>
      _settlementsBox.add(settlement);

  Future<void> deleteSettlement(dynamic key) => _settlementsBox.delete(key);

  Stream<BoxEvent> watchSettlements() => _settlementsBox.watch();

  // ------------------------------------------------------------- bulk ops

  Future<void> clearAllTripsData() async {
    await Future.wait([
      _tripsBox.clear(),
      _expensesBox.clear(),
      _settlementsBox.clear(),
    ]);
  }
}
