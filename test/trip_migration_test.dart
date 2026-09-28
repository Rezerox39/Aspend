import 'dart:io';

import 'package:aspends_tracker/core/const/app_constants.dart';
import 'package:aspends_tracker/core/models/trip.dart';
import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/models/trip_member.dart';
import 'package:aspends_tracker/core/models/trip_settlement.dart';
import 'package:aspends_tracker/core/repositories/trip_repository.dart';
import 'package:aspends_tracker/core/services/trip_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Trips used to store their people as bare names, with every expense keyed by
/// those names. The migration moves those keys onto member ids exactly once.
///
/// It runs against real Hive boxes rather than a fake, because the thing worth
/// protecting is that the rewritten records actually round-trip through the
/// hand-written adapters.
void main() {
  late Directory tempDir;
  late TripRepository repository;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_migration_test');
    Hive.init(tempDir.path);
    Hive
      ..registerAdapter(TripAdapter())
      ..registerAdapter(TripExpenseAdapter())
      ..registerAdapter(TripSettlementAdapter())
      ..registerAdapter(TripMemberAdapter());
    await Hive.openBox<Trip>(AppConstants.tripsBox);
    await Hive.openBox<TripExpense>(AppConstants.tripExpensesBox);
    await Hive.openBox<TripSettlement>(AppConstants.tripSettlementsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    repository = TripRepository();
    await Hive.box<Trip>(AppConstants.tripsBox).clear();
    await Hive.box<TripExpense>(AppConstants.tripExpensesBox).clear();
    await Hive.box<TripSettlement>(AppConstants.tripSettlementsBox).clear();
  });

  /// A trip shaped the way it was before members existed: no members, and a
  /// populated `memberNames`.
  Future<Trip> legacyTrip(List<String> memberNames) async {
    final trip = Trip(
      name: 'Old trip',
      startDate: DateTime(2026, 1, 1),
      memberNames: memberNames,
    );
    await repository.addTrip(trip);
    return trip;
  }

  Future<void> legacyExpense({
    required Trip trip,
    required String paidBy,
    required Map<String, double> shares,
  }) async {
    await repository.addExpense(
      TripExpense(
        tripId: trip.key.toString(),
        title: 'Dinner',
        amount: shares.values.fold<double>(0, (a, b) => a + b),
        paidBy: paidBy,
        date: DateTime(2026, 1, 2),
        shares: shares,
      ),
    );
  }

  Trip reloadedTrip() => repository.getAllTrips().single;
  TripExpense reloadedExpense() => repository.getAllExpenses().single;

  group('upgrading a legacy trip', () {
    test('rewrites the payer and every share onto member ids', () async {
      final trip = await legacyTrip(['Ana', 'Ben']);
      await legacyExpense(trip: trip, paidBy: 'Ana', shares: {'Ana': 500, 'Ben': 500});

      final migrated = await TripMigration(repository).run();

      expect(migrated, 1);
      final up = reloadedTrip();
      expect(up.members.map((m) => m.name), ['Ana', 'Ben']);
      expect(up.memberNames, ['Ana', 'Ben'],
          reason: 'the legacy list must keep working for existing read sites');

      final expense = reloadedExpense();
      expect(up.memberById(expense.paidBy)!.name, 'Ana');
      for (final key in expense.shares.keys) {
        expect(up.memberIds, contains(key),
            reason: 'every share has to land on a real member id');
      }
    });

    test('never changes an amount', () async {
      final trip = await legacyTrip(['Ana', 'Ben']);
      await legacyExpense(
          trip: trip, paidBy: 'Ana', shares: {'Ana': 333.33, 'Ben': 333.33});

      await TripMigration(repository).run();

      final expense = reloadedExpense();
      expect(expense.amount, 666.66);
      expect(expense.shares.values.fold<double>(0, (a, b) => a + b), 666.66);
    });

    test('keeps an expense whose member is no longer on the trip', () async {
      // Reachable today: removing a person from the trip never touched the
      // expenses that referenced them. Dropping the row would quietly delete
      // money somebody is owed.
      final trip = await legacyTrip(['Ana']);
      await legacyExpense(trip: trip, paidBy: 'Ben', shares: {'Ana': 200, 'Ben': 200});

      await TripMigration(repository).run();

      final up = reloadedTrip();
      final expense = reloadedExpense();
      expect(repository.getAllExpenses(), hasLength(1));
      expect(up.members.map((m) => m.name), containsAll(['Ana', 'Ben']));
      expect(up.memberById(expense.paidBy)!.name, 'Ben');
    });

    test('rewrites settlement members onto ids', () async {
      final trip = await legacyTrip(['Ana', 'Ben']);
      await legacyExpense(trip: trip, paidBy: 'Ana', shares: {'Ana': 500, 'Ben': 500});
      await repository.addSettlement(
        TripSettlement(
          tripId: trip.key.toString(),
          fromMember: 'Ben',
          toMember: 'Ana',
          amount: 250,
          date: DateTime(2026, 1, 3),
        ),
      );

      await TripMigration(repository).run();

      final up = reloadedTrip();
      final settlement = repository.getAllSettlements().single;
      expect(up.memberById(settlement.fromMember)!.name, 'Ben');
      expect(up.memberById(settlement.toMember)!.name, 'Ana');
    });
  });

  group('running it again', () {
    test('does nothing, so a re-run can never re-key stored expenses', () async {
      final trip = await legacyTrip(['Ana', 'Ben']);
      await legacyExpense(trip: trip, paidBy: 'Ana', shares: {'Ana': 500, 'Ben': 500});

      await TripMigration(repository).run();
      final firstExpense = reloadedExpense();
      final firstIds = reloadedTrip().memberIds;

      final second = await TripMigration(repository).run();

      expect(second, 0, reason: 'a trip that already has members is skipped');
      expect(reloadedExpense().paidBy, firstExpense.paidBy);
      expect(reloadedTrip().memberIds, firstIds);
    });
  });
}
