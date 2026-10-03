import '../models/cash_game.dart';

/// One payment from one player to another.
class CashTransfer {
  const CashTransfer({
    required this.fromName,
    required this.toName,
    required this.amount,
  });

  final String fromName;
  final String toName;

  /// Always positive.
  final double amount;
}

/// Whether the money on the table adds up.
class CashReconciliation {
  const CashReconciliation({
    required this.totalBuyIns,
    required this.totalOnTable,
    required this.totalCashedOut,
  });

  final double totalBuyIns;

  /// Chips still in front of players who have not cashed out.
  final double totalOnTable;

  final double totalCashedOut;

  /// What is unaccounted for. Positive means money went in that nobody holds.
  double get difference => totalBuyIns - (totalOnTable + totalCashedOut);

  /// Floating-point noise is not a discrepancy. A real one at a home game is
  /// at least a chip, never a thousandth of one.
  bool get balances => difference.abs() < 0.01;
}

/// Settling a cash game (§3's "Advanced cash-game functionality"; build spec
/// §F2.10, `settleUp(balances)`).
///
/// A cash game ends with everybody's net win or loss, and then the genuinely
/// annoying part: working out who hands money to whom. The naive answer is
/// that every loser pays a central pot and every winner draws from it, which
/// means twice as many transfers as necessary and somebody holding a pile of
/// cash they do not own.
///
/// **Why greedy pairing is not good enough.** Pairing the biggest debtor
/// against the biggest creditor, repeatedly, across the WHOLE table looks
/// optimal and is not: balances **+4 +3 +3 −6 −4** (A, B, C, D, E) take 4
/// greedy transfers, but the true minimum is 3 — split the table into two
/// independent zero-sum groups first ({A, E} and {B, C, D}), then pair
/// greedily *within* each group (D→B 3, D→C 3, E→A 4).
///
/// **Why that minimum is exact.** Each transfer is an edge in a graph on the
/// people with a non-zero balance; every connected component of that graph
/// must itself sum to zero, and a component of k people needs at least k − 1
/// edges to settle. So the fewest possible transfers is
/// `(people with a balance) − (the most disjoint zero-sum groups the table
/// can be cut into)`. Finding that maximum is a bitmask DP over the people
/// with a non-zero balance: `best[mask] = max` over every non-empty zero-sum
/// subset `g` of `mask` that contains its lowest member, of
/// `1 + best[mask \ g]` (fixing the lowest member avoids counting the same
/// partition more than once). Backtracking the choices that achieved
/// `best[full]` recovers the actual groups; inside each group the biggest
/// debtor pays the biggest creditor, repeatedly (ties broken by name), which
/// is exactly `k − 1` transfers for a k-person group.
///
/// All arithmetic runs in whole cents. Doing it in doubles produces a
/// settlement that is out by a penny about a third of the time, and a penny
/// wrong is an argument at the table even though nobody cares about the penny.
abstract final class CashSettlement {
  /// Above this many people with a non-zero balance the exact bitmask DP
  /// (2^n subsets) stops being worth it; the spec's own worked example caps
  /// at 16, which this stays comfortably under before falling back to the
  /// still-correct-count-wise (if not always minimal) greedy pairing.
  static const int maxExactPeople = 16;

  /// Converts to cents to keep the arithmetic exact.
  static int _cents(double v) => (v * 100).round();

  static double _money(int cents) => cents / 100.0;

  /// Who pays whom, the fewest transfers that bring every balance to zero.
  ///
  /// [players] may be mid-session: a player who has not cashed out is treated
  /// as holding their current stack, which is what they would walk away with.
  static List<CashTransfer> settle(List<CashPlayer> players) {
    final balances = <({String name, int cents})>[];
    for (final p in players) {
      final net = _cents(_netOf(p));
      if (net != 0) balances.add((name: p.name, cents: net));
    }
    return settleBalances(balances);
  }

  /// The same algorithm, taking raw (name, cents) balances directly — used by
  /// [settle] and available for callers (season/cash tools) that already have
  /// balances rather than [CashPlayer]s. Balances need not sum to exactly zero
  /// going in (rounding noise is tolerated); the last transfer absorbs it.
  static List<CashTransfer> settleBalances(
    List<({String name, int cents})> balances,
  ) {
    final nonzero = balances.where((b) => b.cents != 0).toList();
    if (nonzero.isEmpty) return const [];

    if (nonzero.length > maxExactPeople) {
      return _greedy(nonzero);
    }

    final n = nonzero.length;
    final cents = [for (final b in nonzero) b.cents];
    final sum = cents.fold<int>(0, (a, b) => a + b);
    if (sum != 0) {
      // Guard verifying sum of balances == 0 before DP partitioning;
      // if nonzero due to rounding, adjust last balance so DP finds zero-sum groups
      cents[n - 1] -= sum;
    }
    final full = (1 << n) - 1;

    // sumOf[mask] = sum of balances of the people in mask, built bottom-up
    // from the lowest set bit so each mask costs one addition.
    final sumOf = List<int>.filled(1 << n, 0);
    for (var mask = 1; mask <= full; mask++) {
      final lowBit = mask & (-mask);
      final idx = lowBit.bitLength - 1;
      sumOf[mask] = sumOf[mask ^ lowBit] + cents[idx];
    }

    final bestCache = <int, int>{};
    final groupOf = <int, int>{};

    // best[mask]: the most disjoint zero-sum groups the people in `mask` can
    // be cut into. Only ever called on masks that themselves sum to zero
    // (true of `full` by the settle-up precondition, and preserved by
    // construction on every recursive call), so a group achieving the max is
    // always found.
    int best(int mask) {
      if (mask == 0) return 0;
      final cached = bestCache[mask];
      if (cached != null) return cached;

      // Fix the lowest member so every partition is counted exactly once:
      // whichever group contains it is enumerated as `t | lowBit` over every
      // submask t of the rest.
      final lowBit = mask & (-mask);
      final rest = mask ^ lowBit;

      var bestVal = -1;
      var bestGroup = lowBit;
      var t = rest;
      while (true) {
        final group = t | lowBit;
        if (sumOf[group] == 0) {
          final val = 1 + best(mask ^ group);
          if (val > bestVal) {
            bestVal = val;
            bestGroup = group;
          }
        }
        if (t == 0) break;
        t = (t - 1) & rest;
      }

      bestCache[mask] = bestVal;
      groupOf[mask] = bestGroup;
      return bestVal;
    }

    best(full);

    final groups = <int>[];
    var remainingMask = full;
    while (remainingMask != 0) {
      final group = groupOf[remainingMask]!;
      groups.add(group);
      remainingMask ^= group;
    }

    final transfers = <CashTransfer>[];
    for (final group in groups) {
      transfers.addAll(_settleGroup(group, nonzero, cents));
    }
    if (sum != 0 && transfers.isNotEmpty) {
      final last = transfers.last;
      final adjustedCents = ((last.amount * 100).round() + sum);
      if (adjustedCents > 0) {
        transfers[transfers.length - 1] = CashTransfer(
          fromName: last.fromName,
          toName: last.toName,
          amount: _money(adjustedCents),
        );
      }
    }
    return transfers;
  }

  /// Inside one zero-sum group: biggest debtor pays biggest creditor,
  /// repeatedly, ties broken by name — exactly `k − 1` transfers for a
  /// k-person group.
  static List<CashTransfer> _settleGroup(
    int groupMask,
    List<({String name, int cents})> nonzero,
    List<int> cents,
  ) {
    final debtors = <_MutableBalance>[];
    final creditors = <_MutableBalance>[];
    for (var i = 0; i < nonzero.length; i++) {
      if ((groupMask & (1 << i)) == 0) continue;
      final c = cents[i];
      if (c < 0) debtors.add(_MutableBalance(nonzero[i].name, -c));
      if (c > 0) creditors.add(_MutableBalance(nonzero[i].name, c));
    }

    int byDebt(_MutableBalance a, _MutableBalance b) {
      final byAmount = b.cents.compareTo(a.cents);
      return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
    }

    final transfers = <CashTransfer>[];
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort(byDebt);
      creditors.sort(byDebt);
      final debtor = debtors.first;
      final creditor = creditors.first;
      final pay = debtor.cents < creditor.cents ? debtor.cents : creditor.cents;
      if (pay > 0) {
        transfers.add(
          CashTransfer(
            fromName: debtor.name,
            toName: creditor.name,
            amount: _money(pay),
          ),
        );
      }
      debtor.cents -= pay;
      creditor.cents -= pay;
      if (debtor.cents == 0) debtors.removeAt(0);
      if (creditor.cents == 0) creditors.removeAt(0);
    }
    return transfers;
  }

  /// Fallback beyond [maxExactPeople]: the standard greedy pairing (largest
  /// debtor to largest creditor, repeatedly). Not guaranteed minimal, but
  /// still at most one payment fewer than there are people, and a home game
  /// settle-up realistically never has more than 16 people owing money.
  static List<CashTransfer> _greedy(
    List<({String name, int cents})> balances,
  ) {
    final debtors = <_MutableBalance>[
      for (final b in balances)
        if (b.cents < 0) _MutableBalance(b.name, -b.cents),
    ];
    final creditors = <_MutableBalance>[
      for (final b in balances)
        if (b.cents > 0) _MutableBalance(b.name, b.cents),
    ];
    debtors.sort((a, b) => b.cents != a.cents ? b.cents.compareTo(a.cents) : a.name.compareTo(b.name));
    creditors.sort((a, b) => b.cents != a.cents ? b.cents.compareTo(a.cents) : a.name.compareTo(b.name));

    final transfers = <CashTransfer>[];
    var i = 0;
    var j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = debtors[i].cents < creditors[j].cents
          ? debtors[i].cents
          : creditors[j].cents;
      if (pay > 0) {
        transfers.add(
          CashTransfer(
            fromName: debtors[i].name,
            toName: creditors[j].name,
            amount: _money(pay),
          ),
        );
      }
      debtors[i].cents -= pay;
      creditors[j].cents -= pay;
      if (debtors[i].cents == 0) i++;
      if (creditors[j].cents == 0) j++;
    }
    return transfers;
  }

  /// A player's position, whether or not they have cashed out.
  ///
  /// [CashPlayer.net] only means anything after cashing out — before that,
  /// `cashedOut` is zero and the net reads as a total loss. Mid-session the
  /// chips in front of them are what they are worth.
  static double _netOf(CashPlayer p) => p.net;

  /// Each player's position, largest winner first.
  static List<({String name, double net})> standings(
    List<CashPlayer> players,
  ) {
    final rows = [
      for (final p in players) (name: p.name, net: _netOf(p)),
    ]..sort((a, b) => b.net.compareTo(a.net));
    return rows;
  }

  /// Does the money add up?
  ///
  /// At a cash game the answer should always be yes, and when it is not, the
  /// cause is nearly always a buy-in somebody took without recording. Saying
  /// so is more useful than silently balancing the books.
  static CashReconciliation reconcile(List<CashPlayer> players) {
    var buyIns = 0;
    var onTable = 0;
    var cashedOut = 0;
    for (final p in players) {
      buyIns += _cents(p.totalBuyIns);
      // A player who rejoined has an earlier cash-out AND chips on the table.
      cashedOut += _cents(p.cashedOut);
      if (!p.hasCashedOut) onTable += _cents(p.stack);
    }
    return CashReconciliation(
      totalBuyIns: _money(buyIns),
      totalOnTable: _money(onTable),
      totalCashedOut: _money(cashedOut),
    );
  }
}

/// Working copy of a balance used while a group (or the greedy fallback)
/// pays itself down to zero.
class _MutableBalance {
  _MutableBalance(this.name, this.cents);
  final String name;
  int cents;
}
