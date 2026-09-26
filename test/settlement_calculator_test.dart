import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildShares — equal', () {
    test('splits evenly when it divides cleanly', () {
      final shares = SettlementCalculator.buildShares(
        amount: 90,
        mode: SplitMode.equal,
        participants: ['Ana', 'Ben', 'Cleo'],
      );

      expect(shares, {'Ana': 30.0, 'Ben': 30.0, 'Cleo': 30.0});
    });

    test('hands the odd cents out so the total is never lost', () {
      final shares = SettlementCalculator.buildShares(
        amount: 100,
        mode: SplitMode.equal,
        participants: ['Ana', 'Ben', 'Cleo'],
      );

      expect(shares.values.reduce((a, b) => a + b), closeTo(100.0, 1e-9));
      expect(shares['Ana'], 33.34);
      expect(shares['Cleo'], 33.33);
    });

    test('survives an amount that cannot be split to the cent', () {
      final shares = SettlementCalculator.buildShares(
        amount: 10.01,
        mode: SplitMode.equal,
        participants: ['A', 'B', 'C'],
      );

      expect(shares.values.reduce((a, b) => a + b), closeTo(10.01, 1e-9));
    });

    test('returns nothing for an empty group', () {
      expect(
        SettlementCalculator.buildShares(
          amount: 50,
          mode: SplitMode.equal,
          participants: [],
        ),
        isEmpty,
      );
    });

    test('zero amount gives everyone zero', () {
      final shares = SettlementCalculator.buildShares(
        amount: 0,
        mode: SplitMode.equal,
        participants: ['Ana', 'Ben'],
      );

      expect(shares, {'Ana': 0.0, 'Ben': 0.0});
    });
  });

  group('buildShares — weighted', () {
    test('splits by weight', () {
      final shares = SettlementCalculator.buildShares(
        amount: 100,
        mode: SplitMode.shares,
        participants: ['Ana', 'Ben', 'Cleo'],
        inputs: {'Ana': 1.0, 'Ben': 1.0, 'Cleo': 2.0},
      );

      expect(shares, {'Ana': 25.0, 'Ben': 25.0, 'Cleo': 50.0});
    });

    test('gives leftover cents to the most rounded-down member', () {
      final shares = SettlementCalculator.buildShares(
        amount: 100,
        mode: SplitMode.shares,
        participants: ['Ana', 'Ben', 'Cleo'],
        inputs: {'Ana': 1.0, 'Ben': 1.0, 'Cleo': 1.0},
      );

      expect(shares.values.reduce((a, b) => a + b), closeTo(100.0, 1e-9));
    });

    test('falls back to an even split when every weight is zero', () {
      final shares = SettlementCalculator.buildShares(
        amount: 90,
        mode: SplitMode.shares,
        participants: ['Ana', 'Ben', 'Cleo'],
        inputs: {'Ana': 0.0, 'Ben': 0.0, 'Cleo': 0.0},
      );

      expect(shares, {'Ana': 30.0, 'Ben': 30.0, 'Cleo': 30.0});
    });

    test('splits by percentage', () {
      final shares = SettlementCalculator.buildShares(
        amount: 200,
        mode: SplitMode.percentage,
        participants: ['Ana', 'Ben'],
        inputs: {'Ana': 75.0, 'Ben': 25.0},
      );

      expect(shares, {'Ana': 150.0, 'Ben': 50.0});
    });

    test('keeps the total when percentages do not add to 100', () {
      final shares = SettlementCalculator.buildShares(
        amount: 100,
        mode: SplitMode.percentage,
        participants: ['Ana', 'Ben'],
        inputs: {'Ana': 30.0, 'Ben': 30.0},
      );

      expect(shares.values.reduce((a, b) => a + b), closeTo(100.0, 1e-9));
    });
  });

  group('buildShares — exact', () {
    test('uses the entered amounts at face value', () {
      final shares = SettlementCalculator.buildShares(
        amount: 100,
        mode: SplitMode.exact,
        participants: ['Ana', 'Ben', 'Cleo'],
        inputs: {'Ana': 60.0, 'Ben': 25.0, 'Cleo': 15.0},
      );

      expect(shares, {'Ana': 60.0, 'Ben': 25.0, 'Cleo': 15.0});
    });
  });

  group('computeBalances', () {
    TripExpense expense({
      required String paidBy,
      required double amount,
      required Map<String, double> shares,
    }) =>
        TripExpense(
          tripId: 't1',
          title: 'item',
          amount: amount,
          paidBy: paidBy,
          date: DateTime(2026, 1, 1),
          shares: shares,
        );

    test('net is zero when everyone splits evenly', () {
      final balances = SettlementCalculator.computeBalances(
        members: ['Ana', 'Ben'],
        expenses: [
          expense(paidBy: 'Ana', amount: 100, shares: {'Ana': 50.0, 'Ben': 50.0}),
        ],
      );

      expect(balances['Ana']!.net, closeTo(0.0, 1e-9));
      expect(balances['Ben']!.net, closeTo(0.0, 1e-9));
    });

    test('payer is owed the other members’ shares', () {
      final balances = SettlementCalculator.computeBalances(
        members: ['Ana', 'Ben', 'Cleo'],
        expenses: [
          expense(
            paidBy: 'Ana',
            amount: 90,
            shares: {'Ana': 30.0, 'Ben': 30.0, 'Cleo': 30.0},
          ),
        ],
      );

      expect(balances['Ana']!.net, closeTo(60.0, 1e-9));
      expect(balances['Ben']!.net, closeTo(-30.0, 1e-9));
      expect(balances['Cleo']!.net, closeTo(-30.0, 1e-9));
    });

    test('balances sum to zero across the group', () {
      final balances = SettlementCalculator.computeBalances(
        members: ['Ana', 'Ben', 'Cleo'],
        expenses: [
          expense(
            paidBy: 'Ana',
            amount: 90,
            shares: {'Ana': 30.0, 'Ben': 30.0, 'Cleo': 30.0},
          ),
          expense(paidBy: 'Ben', amount: 30, shares: {'Ana': 10.0, 'Ben': 10.0, 'Cleo': 10.0}),
        ],
      );

      final sum = balances.values.fold<double>(0.0, (sum, b) => sum + b.net);
      expect(sum, closeTo(0.0, 1e-9));
    });

    test('a settlement moves the balance without touching expenses', () {
      final balances = SettlementCalculator.computeBalances(
        members: ['Ana', 'Ben'],
        expenses: [
          expense(paidBy: 'Ana', amount: 100, shares: {'Ana': 50.0, 'Ben': 50.0}),
        ],
        settlements: [
          (from: 'Ben', to: 'Ana', amount: 50.0),
        ],
      );

      expect(balances['Ana']!.net, closeTo(0.0, 1e-9));
      expect(balances['Ben']!.net, closeTo(0.0, 1e-9));
    });

    test('a member with no expenses is simply zero', () {
      final balances = SettlementCalculator.computeBalances(
        members: ['Ana', 'Ben'],
        expenses: const [],
      );

      expect(balances['Ben']!.net, closeTo(0.0, 1e-9));
    });
  });

  group('minimizeTransfers', () {
    test('a single expense becomes one payment', () {
      final transfers = SettlementCalculator.minimizeTransfers({
        'Ana': const MemberBalance(name: 'Ana', paid: 90, owed: 30),
        'Ben': const MemberBalance(name: 'Ben', paid: 0, owed: 30),
        'Cleo': const MemberBalance(name: 'Cleo', paid: 0, owed: 30),
      });

      expect(transfers, hasLength(1));
      expect(transfers.first.from, 'Ben');
      expect(transfers.first.to, 'Ana');
      expect(transfers.first.amount, closeTo(60.0, 1e-9));
    });

    test('collapses a triangle into two payments, not three', () {
      final transfers = SettlementCalculator.minimizeTransfers({
        'A': const MemberBalance(name: 'A', paid: 60, owed: 0),
        'B': const MemberBalance(name: 'B', paid: 60, owed: 0),
        'C': const MemberBalance(name: 'C', paid: 0, owed: 120),
      });

      expect(transfers, hasLength(2));
      expect(
        transfers.fold<double>(0.0, (sum, t) => sum + t.amount),
        closeTo(120.0, 1e-9),
      );
    });

    test('an already-settled group needs no payments', () {
      final transfers = SettlementCalculator.minimizeTransfers({
        'Ana': const MemberBalance(name: 'Ana', paid: 50, owed: 50),
        'Ben': const MemberBalance(name: 'Ben', paid: 50, owed: 50),
      });

      expect(transfers, isEmpty);
    });

    test('sub-cent residue does not produce phantom payments', () {
      final transfers = SettlementCalculator.minimizeTransfers({
        'Ana': const MemberBalance(name: 'Ana', paid: 10.001, owed: 10.0),
        'Ben': const MemberBalance(name: 'Ben', paid: 0, owed: 0),
      });

      expect(transfers, isEmpty);
    });

    test('paying the plan off settles the group', () {
      final balances = {
        'Ana': const MemberBalance(name: 'Ana', paid: 300, owed: 100),
        'Ben': const MemberBalance(name: 'Ben', paid: 0, owed: 100),
        'Cleo': const MemberBalance(name: 'Cleo', paid: 0, owed: 100),
      };

      final transfers = SettlementCalculator.minimizeTransfers(balances);

      final after = <String, double>{'Ana': 0.0, 'Ben': 0.0, 'Cleo': 0.0};
      for (final t in transfers) {
        after[t.from] = after[t.from]! - t.amount;
        after[t.to] = after[t.to]! + t.amount;
      }

      expect(after['Ana']!.abs(), lessThan(SettlementCalculator.epsilon));
      expect(after['Ben']!.abs(), lessThan(SettlementCalculator.epsilon));
      expect(after['Cleo']!.abs(), lessThan(SettlementCalculator.epsilon));
    });
  });

  group('totalOutstanding', () {
    test('counts only what the group still owes', () {
      final total = SettlementCalculator.totalOutstanding({
        'Ana': const MemberBalance(name: 'Ana', paid: 90, owed: 30),
        'Ben': const MemberBalance(name: 'Ben', paid: 0, owed: 30),
        'Cleo': const MemberBalance(name: 'Cleo', paid: 0, owed: 30),
      });

      expect(total, closeTo(60.0, 1e-9));
    });
  });
}
