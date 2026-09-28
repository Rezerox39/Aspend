import 'package:aspends_tracker/core/models/trip_expense.dart';
import 'package:aspends_tracker/core/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every balance in a trip is kept in the trip's base currency, so a foreign
/// expense has to be converted once, at the point it is entered, and then
/// behave exactly like any other expense. The whole settle-up still lands on
/// zero afterwards — that is the property these tests protect.
const String _base = 'INR';

TripExpense _expense({
  required String title,
  required String amount,
  required String paidBy,
  required Map<String, double> shares,
  String currency = _base,
  double rate = 1.0,
  double? originalAmount,
}) =>
    TripExpense(
      tripId: 'trip-1',
      title: title,
      amount: double.parse(amount),
      paidBy: paidBy,
      date: DateTime(2026, 1, 1),
      shares: shares,
      currency: currency,
      exchangeRateToBase: rate,
      originalAmount: originalAmount,
    );

Map<String, double> _evenSplit(double amount, List<String> members) =>
    SettlementCalculator.buildShares(
      amount: amount,
      mode: SplitMode.equal,
      participants: members,
    );

void main() {
  group('conversion', () {
    test('100 USD at 83.5 lands on exactly 8350 in the base currency', () {
      expect(TripExpense.toBaseAmount(100, 83.5), 8350.0);
    });

    test('rounds a rate that does not divide evenly', () {
      // 33.33 * 83.5 = 2783.0555, which has to become a whole amount so the
      // expense can still be split into whole paise.
      expect(TripExpense.toBaseAmount(33.33, 83.5), 2783.0);
    });

    test('a same-currency expense is never marked foreign', () {
      final expense = _expense(
        title: 'Tea',
        amount: '120',
        paidBy: 'ana',
        shares: {'ana': 60, 'ben': 60},
      );

      expect(expense.isForeign, isFalse);
      expect(expense.exchangeRateToBase, 1.0);
      expect(expense.originalAmount, isNull);
    });

    test('a foreign expense keeps what was really paid', () {
      final expense = _expense(
        title: 'Museum tickets',
        amount: '8350',
        paidBy: 'ana',
        shares: {'ana': 4175, 'ben': 4175},
        currency: 'USD',
        rate: 83.5,
        originalAmount: 100,
      );

      expect(expense.isForeign, isTrue);
      expect(expense.currency, 'USD');
      expect(expense.originalAmount, 100);
      expect(expense.amount, 8350.0,
          reason: 'amount stays in the base currency so every existing balance '
              'calculation keeps working untouched');
    });
  });

  group('balances', () {
    test('a foreign expense contributes its base amount, not the original', () {
      final expense = _expense(
        title: 'Museum tickets',
        amount: '8350',
        paidBy: 'ana',
        shares: {'ana': 4175, 'ben': 4175},
        currency: 'USD',
        rate: 83.5,
        originalAmount: 100,
      );

      final balances = SettlementCalculator.computeBalances(
        members: ['ana', 'ben'],
        expenses: [expense],
      );

      expect(balances['ana']!.paid, 8350.0);
      expect(balances['ana']!.owed, 4175.0);
      expect(balances['ana']!.net, 4175.0);
      expect(balances['ben']!.net, -4175.0);
    });
  });

  group('settle-up', () {
    /// Settles the trip the way the UI does, and returns everyone's balance
    /// afterwards.
    Map<String, MemberBalance> settleTrip(
      List<TripExpense> expenses,
      List<String> members,
    ) {
      final balances =
          SettlementCalculator.computeBalances(members: members, expenses: expenses);
      final transfers = SettlementCalculator.minimizeTransfers(balances);
      return SettlementCalculator.computeBalances(
        members: members,
        expenses: expenses,
        settlements: [
          for (final transfer in transfers)
            (from: transfer.from, to: transfer.to, amount: transfer.amount),
        ],
      );
    }

    /// Every member is square. Compared against the calculator's own epsilon
    /// rather than zero, because that is the bar the settle-up screen uses.
    void expectSettled(Map<String, MemberBalance> balances) {
      for (final balance in balances.values) {
        expect(balance.net.abs(), lessThan(SettlementCalculator.epsilon),
            reason: '${balance.name} is still out by ${balance.net}');
      }
    }

    test('reaches zero for a foreign expense', () {
      final base = TripExpense.toBaseAmount(100, 83.5);
      final expense = _expense(
        title: 'Museum tickets',
        amount: '$base',
        paidBy: 'ana',
        shares: _evenSplit(base, ['ana', 'ben']),
        currency: 'USD',
        rate: 83.5,
        originalAmount: 100,
      );

      expectSettled(settleTrip([expense], ['ana', 'ben']));
    });

    test('reaches zero for a mixed-currency trip', () {
      final foreign = TripExpense.toBaseAmount(100, 83.5);
      final expenses = [
        _expense(
          title: 'Museum tickets',
          amount: '$foreign',
          paidBy: 'ana',
          shares: _evenSplit(foreign, ['ana', 'ben', 'cho']),
          currency: 'USD',
          rate: 83.5,
          originalAmount: 100,
        ),
        _expense(
          title: 'Train',
          amount: '4500',
          paidBy: 'ben',
          shares: _evenSplit(4500, ['ana', 'ben', 'cho']),
        ),
        _expense(
          title: 'Dinner',
          amount: '2783',
          paidBy: 'cho',
          shares: _evenSplit(2783, ['ana', 'ben', 'cho']),
        ),
      ];

      expectSettled(settleTrip(expenses, ['ana', 'ben', 'cho']));
    });

    test('reaches zero when a rate does not divide evenly', () {
      // 2783 over three people is 927.67 each; the rounding has to be absorbed
      // by the split, not left dangling in the balance.
      final base = TripExpense.toBaseAmount(33.33, 83.5);
      final expense = _expense(
        title: 'Odd rate',
        amount: '$base',
        paidBy: 'ana',
        shares: _evenSplit(base, ['ana', 'ben', 'cho']),
        currency: 'USD',
        rate: 83.5,
        originalAmount: 33.33,
      );

      final shares = expense.shares.values.fold<double>(0, (a, b) => a + b);
      expect(shares, closeTo(base, 0.001),
          reason: 'the split must still add back up to the whole expense');
      expectSettled(settleTrip([expense], ['ana', 'ben', 'cho']));
    });
  });
}
