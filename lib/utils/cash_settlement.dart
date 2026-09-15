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

/// Settling a cash game (§3's "Advanced cash-game functionality").
///
/// A cash game ends with everybody's net win or loss, and then the genuinely
/// annoying part: working out who hands money to whom. The naive answer is
/// that every loser pays a central pot and every winner draws from it, which
/// means twice as many transfers as necessary and somebody holding a pile of
/// cash they do not own.
///
/// This produces a short list of direct payments instead. It is the standard
/// greedy pairing — largest debtor to largest creditor, repeatedly — which
/// yields at most one payment fewer than there are players. Finding the
/// provably shortest list is NP-hard and the difference at a nine-handed home
/// game is nil, so the greedy answer is the right engineering trade.
///
/// All arithmetic runs in whole cents. Doing it in doubles produces a
/// settlement that is out by a penny about a third of the time, and a penny
/// wrong is an argument at the table even though nobody cares about the penny.
abstract final class CashSettlement {
  /// Converts to cents to keep the arithmetic exact.
  static int _cents(double v) => (v * 100).round();

  static double _money(int cents) => cents / 100.0;

  /// Who pays whom, shortest sensible list first.
  ///
  /// [players] may be mid-session: a player who has not cashed out is treated
  /// as holding their current stack, which is what they would walk away with.
  static List<CashTransfer> settle(List<CashPlayer> players) {
    final debtors = <({String name, int cents})>[];
    final creditors = <({String name, int cents})>[];

    for (final p in players) {
      final net = _cents(_netOf(p));
      if (net < 0) debtors.add((name: p.name, cents: -net));
      if (net > 0) creditors.add((name: p.name, cents: net));
    }

    // Largest first, so the biggest obligations are cleared in the fewest
    // moves and the small ones fall out as remainders.
    debtors.sort((a, b) => b.cents - a.cents);
    creditors.sort((a, b) => b.cents - a.cents);

    final transfers = <CashTransfer>[];
    var i = 0;
    var j = 0;
    var owed = debtors.isEmpty ? 0 : debtors.first.cents;
    var due = creditors.isEmpty ? 0 : creditors.first.cents;

    while (i < debtors.length && j < creditors.length) {
      final pay = owed < due ? owed : due;
      if (pay > 0) {
        transfers.add(
          CashTransfer(
            fromName: debtors[i].name,
            toName: creditors[j].name,
            amount: _money(pay),
          ),
        );
      }
      owed -= pay;
      due -= pay;
      if (owed == 0) {
        i++;
        if (i < debtors.length) owed = debtors[i].cents;
      }
      if (due == 0) {
        j++;
        if (j < creditors.length) due = creditors[j].cents;
      }
    }

    return transfers;
  }

  /// A player's position, whether or not they have cashed out.
  ///
  /// [CashPlayer.net] only means anything after cashing out — before that,
  /// `cashedOut` is zero and the net reads as a total loss. Mid-session the
  /// chips in front of them are what they are worth.
  static double _netOf(CashPlayer p) =>
      p.hasCashedOut ? p.cashedOut - p.totalBuyIns : p.stack - p.totalBuyIns;

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
      if (p.hasCashedOut) {
        cashedOut += _cents(p.cashedOut);
      } else {
        onTable += _cents(p.stack);
      }
    }
    return CashReconciliation(
      totalBuyIns: _money(buyIns),
      totalOnTable: _money(onTable),
      totalCashedOut: _money(cashedOut),
    );
  }
}
