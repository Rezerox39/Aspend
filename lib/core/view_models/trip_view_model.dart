import 'dart:async';

import 'package:aspends_tracker/core/models/trip.dart';
import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/models/trip_settlement.dart';
import 'package:aspends_tracker/core/repositories/trip_repository.dart';
import 'package:aspends_tracker/core/services/settlement_calculator.dart';
import 'package:aspends_tracker/core/services/trip_migration.dart';
import 'package:flutter/foundation.dart';

/// Owns all group-trip state: the trips themselves, their shared expenses, and
/// the settlement ledger.
///
/// Follows the same shape as [PersonViewModel] — a Hive-backed repository, a
/// change subscription that reloads on write, and memoised derived values so
/// the balance maths (which is O(expenses)) does not re-run on every frame.
class TripViewModel extends ChangeNotifier {
  final TripRepository _repository;

  List<Trip> _trips = [];
  List<TripExpense> _expenses = [];
  List<TripSettlement> _settlements = [];

  bool _showArchived = false;

  /// A single write fans out into several Hive box events (the explicit
  /// reload after the write, plus one event per box the repository touched),
  /// and every one of those used to trigger a full re-index and a rebuild of
  /// every listening widget. Reloads are now coalesced into the microtask
  /// queue, so one user action costs exactly one re-index and one rebuild.
  bool _reloadScheduled = false;

  // Memoisation. Balances and settle-up plans are derived per trip and are
  // comparatively expensive, so they are cached and only dropped when the
  // underlying data actually changes.
  final Map<String, List<TripExpense>> _expensesByTrip = {};
  final Map<String, List<TripSettlement>> _settlementsByTrip = {};
  final Map<String, Map<String, MemberBalance>> _balanceCache = {};
  final Map<String, List<SettlementTransfer>> _transferCache = {};
  final Map<String, double> _totalCache = {};
  final Map<String, int> _memberCountByTrip = {};

  TripViewModel(this._repository) {
    _loadData();
    _ensureMigrated();
    _subscribeToChanges();
  }

  // ----------------------------------------------------------------- reads

  List<Trip> get trips {
    final visible = _trips
        .where((trip) => _showArchived || !trip.isArchived)
        .toList();
    visible.sort((a, b) => b.startDate.compareTo(a.startDate));
    return visible;
  }

  bool get hasArchivedTrips => _trips.any((trip) => trip.isArchived);

  bool get showArchived => _showArchived;

  void setShowArchived(bool value) {
    if (_showArchived == value) return;
    _showArchived = value;
    notifyListeners();
  }

  Trip? tripByKey(dynamic key) {
    for (final trip in _trips) {
      if (trip.key == key) return trip;
    }
    return null;
  }

  List<TripExpense> expensesFor(String tripId) =>
      _expensesByTrip[tripId] ?? const [];

  List<TripSettlement> settlementsFor(String tripId) =>
      _settlementsByTrip[tripId] ?? const [];

  /// Total the group has spent on the trip.
  double totalSpent(String tripId) {
    var total = 0.0;
    for (final expense in expensesFor(tripId)) {
      total += expense.amount;
    }
    return total;
  }

  /// Per-person average spend — the number people actually want from a trip.
  double averagePerMember(String tripId) {
    final memberCount = _memberCountFor(tripId);
    if (memberCount == 0) return 0.0;
    return totalSpent(tripId) / memberCount;
  }

  /// Per-member standing, including settlements already paid.
  Map<String, MemberBalance> balancesFor(String tripId) =>
      _balanceCache[tripId] ?? const {};

  /// The fewest payments that would settle the trip right now.
  List<SettlementTransfer> settleUpPlan(String tripId) =>
      _transferCache[tripId] ?? const [];

  /// How much of the trip is still outstanding.
  double outstandingFor(String tripId) => _totalCache[tripId] ?? 0.0;

  bool isFullySettled(String tripId) =>
      outstandingFor(tripId) <= SettlementCalculator.epsilon;

  int _memberCountFor(String tripId) => _memberCountByTrip[tripId] ?? 0;

  // --------------------------------------------------------------- writes

  Future<void> addTrip(Trip trip) async {
    await _repository.addTrip(trip);
    _scheduleReload();
  }

  Future<void> updateTrip(Trip oldTrip, Trip updated) async {
    await _repository.updateTrip(oldTrip.key, updated);
    _scheduleReload();
  }

  Future<void> deleteTrip(Trip trip) async {
    await _repository.deleteTrip(trip.key);
    _scheduleReload();
  }

  Future<void> setTripArchived(Trip trip, bool archived) async {
    trip.isArchived = archived;
    await _repository.updateTrip(trip.key, trip);
    _scheduleReload();
  }

  Future<void> addExpense(TripExpense expense) async {
    await _repository.addExpense(expense);
    _scheduleReload();
  }

  Future<void> updateExpense(TripExpense oldExpense, TripExpense updated) async {
    await _repository.updateExpense(oldExpense.key, updated);
    _scheduleReload();
  }

  Future<void> deleteExpense(TripExpense expense) async {
    await _repository.deleteExpense(expense.key);
    _scheduleReload();
  }

  Future<void> addSettlement(TripSettlement settlement) async {
    await _repository.addSettlement(settlement);
    _scheduleReload();
  }

  Future<void> deleteSettlement(TripSettlement settlement) async {
    await _repository.deleteSettlement(settlement.key);
    _scheduleReload();
  }

  Future<void> deleteAllData() async {
    await _repository.clearAllTripsData();
    _scheduleReload();
  }

  /// Queues a single re-index + notify for everything that happened in this
  /// microtask, instead of one per underlying write.
  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      _loadData();
    });
  }

  // ------------------------------------------------------------- internals

  /// Whether the name-keyed upgrade still has to run.
  bool _migrationChecked = false;

  Future<void> _ensureMigrated() async {
    if (_migrationChecked) return;
    _migrationChecked = true;
    try {
      final migrated = await TripMigration(_repository).run();
      if (migrated > 0) _loadData();
    } catch (_) {
      // A failed upgrade must never stop the app opening. The trips stay
      // readable exactly as they were, keyed by name.
      _migrationChecked = false;
    }
  }

  void _loadData() {
    _trips = _repository.getAllTrips();
    _expenses = _repository.getAllExpenses();
    _settlements = _repository.getAllSettlements();

    _rebuildIndex();
    notifyListeners();
  }

  void _rebuildIndex() {
    _expensesByTrip.clear();
    _settlementsByTrip.clear();
    _balanceCache.clear();
    _transferCache.clear();
    _totalCache.clear();
    _memberCountByTrip.clear();

    for (final trip in _trips) {
      _memberCountByTrip[trip.key.toString()] = trip.effectiveMembers.length;
    }

    for (final expense in _expenses) {
      _expensesByTrip.putIfAbsent(expense.tripId, () => []).add(expense);
    }
    for (final tripExpenses in _expensesByTrip.values) {
      tripExpenses.sort((a, b) => b.date.compareTo(a.date));
    }

    for (final settlement in _settlements) {
      _settlementsByTrip.putIfAbsent(settlement.tripId, () => []).add(settlement);
    }
    for (final tripSettlements in _settlementsByTrip.values) {
      tripSettlements.sort((a, b) => b.date.compareTo(a.date));
    }

    for (final trip in _trips) {
      _computeTrip(trip);
    }
  }

  void _computeTrip(Trip trip) {
    final tripId = trip.key.toString();
    final tripExpenses = _expensesByTrip[tripId] ?? const <TripExpense>[];
    final tripSettlements =
        _settlementsByTrip[tripId] ?? const <TripSettlement>[];

    final balances = SettlementCalculator.computeBalances(
      members: trip.effectiveMembers.map((m) => m.id).toList(),
      expenses: tripExpenses,
      settlements: [
        for (final settlement in tripSettlements)
          (
            from: settlement.fromMember,
            to: settlement.toMember,
            amount: settlement.amount,
          ),
      ],
    );

    _balanceCache[tripId] = balances;
    _transferCache[tripId] = SettlementCalculator.minimizeTransfers(balances);
    _totalCache[tripId] = SettlementCalculator.totalOutstanding(balances);
  }

  void _subscribeToChanges() {
    _repository.watchTrips().listen((_) => _scheduleReload());
    _repository.watchExpenses().listen((_) => _scheduleReload());
    _repository.watchSettlements().listen((_) => _scheduleReload());
  }
}
