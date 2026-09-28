import 'package:aspends_tracker/core/models/trip.dart';
import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/models/trip_member.dart';
import 'package:aspends_tracker/core/models/trip_settlement.dart';
import 'package:aspends_tracker/core/repositories/trip_repository.dart';

/// One-time upgrade of trips created before members were first-class.
///
/// A trip used to store its people as bare names, and its expenses keyed
/// `paidBy` and every share by those names. Members are now records with stable
/// ids, because two people can share a name and expenses have to be able to tell
/// them apart. This rewrites the stored keys from name to id, exactly once.
///
/// Two rules make it safe to run against real data:
///
/// * **It never drops a name.** If an expense or settlement names somebody who
///   is not on the trip — which is reachable today, because removing a person
///   from [Trip.memberNames] never touched the expenses that referenced them —
///   a member is invented for them rather than leaving a dangling key that
///   would silently vanish from the balances.
/// * **It never changes an amount.** Only keys move; every share value is
///   carried across untouched, so a migrated trip balances to the same total it
///   did before.
///
/// Running it twice is a no-op: a trip that already has members is skipped.
class TripMigration {
  const TripMigration(this._repository);

  final TripRepository _repository;

  /// Upgrades every trip that still needs it and reports how many were touched.
  Future<int> run() async {
    var migrated = 0;
    for (final trip in _repository.getAllTrips()) {
      if (trip.members.isNotEmpty) continue;
      if (await _migrateTrip(trip)) migrated++;
    }
    return migrated;
  }

  Future<bool> _migrateTrip(Trip trip) async {
    final tripId = trip.key.toString();
    final expenses = _repository.getExpensesForTrip(tripId);
    final settlements = _repository.getSettlementsForTrip(tripId);

    final byId = <String, TripMember>{};

    // Start from the names the trip already claims, then fold in anyone the
    // expenses or settlements still reference.
    void ensureMember(String rawKey) {
      final existing = byId.values.where((m) =>
          m.id == rawKey || TripMember.namesMatch(m.name, rawKey));
      if (existing.isNotEmpty) return;
      final id = Trip.memberIdFor(rawKey);
      byId[id] = TripMember(id: id, name: rawKey.trim().isEmpty ? rawKey : rawKey.trim());
    }

    for (final name in trip.memberNames) {
      ensureMember(name);
    }
    for (final expense in expenses) {
      ensureMember(expense.paidBy);
      for (final key in expense.shares.keys) {
        ensureMember(key);
      }
    }
    for (final settlement in settlements) {
      ensureMember(settlement.fromMember);
      ensureMember(settlement.toMember);
    }

    /// Maps either an old name or an already-migrated id to the member's id.
    String idFor(String key) {
      for (final member in byId.values) {
        if (member.id == key) return member.id;
      }
      return Trip.memberIdFor(key);
    }

    for (final expense in expenses) {
      expense.paidBy = idFor(expense.paidBy);
      expense.shares = {
        for (final entry in expense.shares.entries) idFor(entry.key): entry.value,
      };
      await _repository.updateExpense(expense.key, expense);
    }

    for (final settlement in settlements) {
      settlement.fromMember = idFor(settlement.fromMember);
      settlement.toMember = idFor(settlement.toMember);
      await _repository.updateSettlement(settlement.key, settlement);
    }

    trip.members = byId.values.toList();
    trip.syncMemberNames();
    await _repository.updateTrip(trip.key, trip);
    return true;
  }
}
