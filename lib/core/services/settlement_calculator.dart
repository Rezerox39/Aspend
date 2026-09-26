import '../models/trip_expense.dart';

/// One member's standing in a trip.
class MemberBalance {
  final String name;
  final double paid;
  final double owed;

  const MemberBalance({
    required this.name,
    required this.paid,
    required this.owed,
  });

  /// Positive -> the group owes this member. Negative -> this member owes.
  double get net => paid - owed;

  bool get isSettledUp => net.abs() < SettlementCalculator.epsilon;

  MemberBalance copyWith({double? paid, double? owed}) => MemberBalance(
        name: name,
        paid: paid ?? this.paid,
        owed: owed ?? this.owed,
      );
}

/// A single "X pays Y" instruction that closes a trip's balance in as few
/// payments as possible.
class SettlementTransfer {
  final String from;
  final String to;
  final double amount;

  const SettlementTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });
}

/// Pure maths behind group-trip splitting.
///
/// Everything here works in **integer cents** internally. Splitting money with
/// doubles and then summing it back up is how you end up with a trip that is
/// "off by 0.0000001" and a settle-up screen that never quite reaches zero.
class SettlementCalculator {
  /// Anything smaller than half a cent is treated as settled.
  static const double epsilon = 0.005;

  /// Splits [amount] between [participants] according to [mode].
  ///
  /// [inputs] carries the per-member values the chosen mode needs: exact
  /// amounts for [SplitMode.exact], weights for [SplitMode.shares],
  /// percentages for [SplitMode.percentage]. Ignored for [SplitMode.equal].
  ///
  /// The returned shares always sum to exactly [amount] — any rounding
  /// remainder is handed out one cent at a time rather than being dropped, so
  /// the group's books stay balanced to the cent.
  static Map<String, double> buildShares({
    required double amount,
    required SplitMode mode,
    required List<String> participants,
    Map<String, double> inputs = const {},
  }) {
    final members = participants.where((p) => p.trim().isNotEmpty).toList();
    if (members.isEmpty) return {};

    final totalCents = _toCents(amount);
    final shares = <String, double>{};
    if (totalCents == 0) {
      for (final member in members) {
        shares[member] = 0.0;
      }
      return shares;
    }

    switch (mode) {
      case SplitMode.equal:
        _distributeEvenly(members, totalCents, shares);
      case SplitMode.exact:
        _distributeExact(members, inputs, shares);
      case SplitMode.shares:
        _distributeByWeight(members, totalCents, inputs, shares);
      case SplitMode.percentage:
        _distributeByWeight(
          members,
          totalCents,
          _normalisePercentages(members, inputs),
          shares,
        );
    }
    return shares;
  }

  /// Even split: each member gets `total / n`, with the leftover cents spread
  /// one cent each over the first members so the sum lands exactly.
  static void _distributeEvenly(
    List<String> members,
    int totalCents,
    Map<String, double> shares,
  ) {
    final count = members.length;
    final base = totalCents ~/ count;
    var remainder = totalCents % count;
    for (var i = 0; i < count; i++) {
      final cents = remainder > 0 ? base + 1 : base;
      if (remainder > 0) remainder--;
      shares[members[i]] = _fromCents(cents);
    }
  }

  /// Exact amounts are taken at face value; the sum is whatever the user
  /// entered, since they are deliberately overriding the total.
  static void _distributeExact(
    List<String> members,
    Map<String, double> inputs,
    Map<String, double> shares,
  ) {
    for (final member in members) {
      shares[member] = inputs[member] ?? 0.0;
    }
  }

  /// Weighted split (shares, or percentages once normalised to weights).
  ///
  /// Uses the **largest remainder** method: every member gets the floor of
  /// their portion, then the leftover cents go to whoever was rounded down
  /// hardest. That is fairer than giving the remainder to the first member,
  /// and it always lands on the exact total.
  static void _distributeByWeight(
    List<String> members,
    int totalCents,
    Map<String, double> weights,
    Map<String, double> shares,
  ) {
    final positive = <String, double>{};
    var weightTotal = 0.0;
    for (final member in members) {
      final weight = weights[member] ?? 0.0;
      if (weight > 0) {
        positive[member] = weight;
        weightTotal += weight;
      }
    }

    // Everyone entered zero (or nothing at all) — fall back to an even split
    // rather than silently handing the whole amount to nobody.
    if (weightTotal <= 0) {
      _distributeEvenly(members, totalCents, shares);
      return;
    }

    final allocations = <String, int>{};
    final remainders = <String, double>{};
    var handedOut = 0;
    for (final member in members) {
      final weight = positive[member];
      if (weight == null) {
        allocations[member] = 0;
        continue;
      }
      final exact = totalCents * weight / weightTotal;
      final floor = exact.floor();
      allocations[member] = floor;
      handedOut += floor;
      remainders[member] = exact - floor;
    }

    var leftover = totalCents - handedOut;
    if (leftover > 0) {
      final ranked = positive.keys.toList()
        ..sort((a, b) {
          final byRemainder = remainders[b]!.compareTo(remainders[a]!);
          return byRemainder != 0 ? byRemainder : a.compareTo(b);
        });
      for (var i = 0; i < leftover && ranked.isNotEmpty; i++) {
        allocations[ranked[i % ranked.length]] =
            (allocations[ranked[i % ranked.length]] ?? 0) + 1;
      }
    }

    for (final member in members) {
      shares[member] = _fromCents(allocations[member] ?? 0);
    }
  }

  /// Turns a percentage map into a weight map. Members left blank count as 0.
  static Map<String, double> _normalisePercentages(
    List<String> members,
    Map<String, double> percentages,
  ) =>
      {
        for (final member in members)
          member: (percentages[member] ?? 0.0).clamp(0.0, 100.0).toDouble(),
      };

  /// Per-member totals for a trip.
  ///
  /// [settlements] are the payments already made back. A settlement moves the
  /// balance without touching the expenses, so the ledger stays auditable.
  static Map<String, MemberBalance> computeBalances({
    required List<String> members,
    required List<TripExpense> expenses,
    List<({String from, String to, double amount})> settlements = const [],
  }) {
    final paid = <String, double>{};
    final owed = <String, double>{};
    for (final member in members) {
      paid[member] = 0.0;
      owed[member] = 0.0;
    }

    for (final expense in expenses) {
      paid.update(
        expense.paidBy,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
      expense.shares.forEach((member, share) {
        if (share == 0) return;
        owed.update(
          member,
          (value) => value + share,
          ifAbsent: () => share,
        );
      });
    }

    for (final settlement in settlements) {
      // Paying someone back reduces what you owe, and reduces what they are
      // owed — so the payer's net rises and the receiver's net falls.
      paid.update(
        settlement.from,
        (value) => value + settlement.amount,
        ifAbsent: () => settlement.amount,
      );
      owed.update(
        settlement.to,
        (value) => value + settlement.amount,
        ifAbsent: () => settlement.amount,
      );
    }

    return {
      for (final member in members)
        member: MemberBalance(
          name: member,
          paid: paid[member] ?? 0.0,
          owed: owed[member] ?? 0.0,
        ),
    };
  }

  /// Collapses a trip's balances into the fewest payments that settle it.
  ///
  /// Greedy largest-first matching: the biggest debtor always pays the biggest
  /// creditor. This is the standard minimum-cash-flow heuristic — it does not
  /// find the provably optimal transaction count in every case, but it reliably
  /// lands on or near the minimum in practice, and it is O(n log n) instead of
  /// the exponential search an exact solution would need.
  ///
  /// A trip with 12 members and a messy history collapses to a handful of
  /// transfers here, instead of 66 pairwise payments.
  static List<SettlementTransfer> minimizeTransfers(
    Map<String, MemberBalance> balances,
  ) {
    final creditors = <_Claimant>[];
    final debtors = <_Claimant>[];

    for (final balance in balances.values) {
      final net = balance.net;
      if (net > epsilon) {
        creditors.add(_Claimant(balance.name, net));
      } else if (net < -epsilon) {
        debtors.add(_Claimant(balance.name, -net));
      }
    }

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final transfers = <SettlementTransfer>[];
    var creditorIndex = 0;
    var debtorIndex = 0;

    while (creditorIndex < creditors.length && debtorIndex < debtors.length) {
      final creditor = creditors[creditorIndex];
      final debtor = debtors[debtorIndex];
      final payment = _min(creditor.amount, debtor.amount);

      if (payment > epsilon) {
        transfers.add(SettlementTransfer(
          from: debtor.name,
          to: creditor.name,
          amount: payment,
        ));
      }

      creditor.amount -= payment;
      debtor.amount -= payment;

      if (creditor.amount <= epsilon) creditorIndex++;
      if (debtor.amount <= epsilon) debtorIndex++;
    }

    return transfers;
  }

  /// Total still owed across the whole group — the headline number on a trip.
  static double totalOutstanding(Map<String, MemberBalance> balances) {
    var total = 0.0;
    for (final balance in balances.values) {
      if (balance.net > epsilon) total += balance.net;
    }
    return total;
  }

  static int _toCents(double amount) => (amount * 100).round();

  static double _fromCents(int cents) => cents / 100.0;

  static double _min(double a, double b) => a < b ? a : b;
}

class _Claimant {
  final String name;
  double amount;

  _Claimant(this.name, this.amount);
}
