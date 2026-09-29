import 'dart:math' as math;

import 'cash_settlement.dart' show CashSettlement, CashTransfer;
import 'icm.dart' show Icm, IcmResult;

/// The build spec's Part F2 payouts engine: paid places and the split
/// (`payoutPlan`), the organiser's cut (`organiserFee`), rounding a deal
/// (`roundDeal`), the bubble save, when the app offers a deal
/// (`dealTrigger`), season points, and the other chop mechanics
/// (`chipChop`/`equalChop`/`leaveForWinner`/`compareDeals`).
///
/// [Icm.compute] (§F2.5, Malmuth–Harville) and [CashSettlement.settleBalances]
/// (§F2.10, the fewest cash transfers) already live in their own files —
/// [icm] and [settleUp] below are thin spec-named wrappers around them so
/// every §F2 function can be called from one place.
///
/// Money is handled in integer cents internally (the spec's own rule, so
/// rounding is exact); every public function here takes and returns whole
/// currency units (`num`/`double`), decimals only when the amount actually
/// has cents — matching every worked example in §F2.11/§F2.12.
abstract final class PayoutsEngine {
  // ---------------------------------------------------------------------
  // F2.1 / F2.2 — paid places, the split, cash units and rounding.
  // ---------------------------------------------------------------------

  /// Percentage-by-place shapes, largest place first. Only "owner" (the
  /// app's default) and "standard" are specified; a host who supplies
  /// [PayoutPlanOptions.customShares] bypasses both.
  static const Map<int, List<double>> ownerShapes = {
    1: [100],
    2: [65, 35],
    3: [52.5, 32.5, 15],
    4: [42.5, 30, 17.5, 10],
    5: [38, 24, 17, 12, 9],
    6: [35, 22, 16, 12, 9, 6],
  };

  static const Map<int, List<double>> standardShapes = {
    1: [100],
    2: [65, 35],
    3: [50, 30, 20],
    4: [45, 27, 18, 10],
    5: [38, 24, 17, 12, 9],
    6: [35, 22, 16, 12, 9, 6],
  };

  /// `< 5 → 1 · < 100 → 5 · < 500 → 10 · else → 50` (§F2.2), in whole
  /// currency units.
  static int cashUnit(num buyIn) {
    if (buyIn < 5) return 1;
    if (buyIn < 100) return 5;
    if (buyIn < 500) return 10;
    return 50;
  }

  /// PokerStars Home Games-style curves: `entries → paid places`. `ps15`
  /// (default, ≈ top 15 %) is the spec's own table, given tier for tier:
  /// 2–5 → 1 · 6–7 → 2 · 8–21 → 3 · 22–28 → 4 · 29–35 → 5 · 36–42 → 6, then
  /// +1 place per 7 further entries.
  ///
  /// `ps10` and `ps20` exist only for a host override (§F2.1) and the spec
  /// does not pin their exact tiers the way it does `ps15`'s — they are
  /// approximated here as the same shape scaled to target ≈10 % / ≈20 % of
  /// the field, which is the one property the spec does state about them.
  static int curvePlaces(int entries, {String curve = 'ps15'}) {
    if (entries <= 0) return 0;
    switch (curve) {
      case 'ps10':
        return _percentPlaces(entries, 10);
      case 'ps20':
        return _percentPlaces(entries, 20);
      case 'ps15':
      default:
        return _ps15Places(entries);
    }
  }

  static int _ps15Places(int entries) {
    if (entries <= 5) return 1;
    if (entries <= 7) return 2;
    if (entries <= 21) return 3;
    if (entries <= 28) return 4;
    if (entries <= 35) return 5;
    if (entries <= 42) return 6;
    return 6 + ((entries - 42 + 6) ~/ 7);
  }

  static int _percentPlaces(int entries, num pct) {
    if (entries < 2) return 1;
    final raw = (entries * pct / 100).ceil();
    return raw < 1 ? 1 : raw;
  }

  /// Rounds `net` across places 2…p to the nearest [unitCents], exact halves
  /// rounding down (computed in integer basis points so there is no float
  /// error to break the tie); place 1 (index 0) takes the exact remainder so
  /// the split always sums to `netCents`. A final repair pass nudges whole
  /// units from a lower place up to the one directly above it whenever
  /// rounding left it larger — "no place exceeds the one above it" (§F2.2).
  static List<int> roundShares(
    int netCents,
    List<num> sharesPercent,
    int unitCents,
  ) {
    final p = sharesPercent.length;
    if (p == 0) return const [];
    final amounts = List<int>.filled(p, 0);

    var allocatedToLower = 0;
    for (var i = 1; i < p; i++) {
      final bp = (sharesPercent[i] * 100).round(); // basis points
      final numerator = netCents * bp;
      final d = 10000 * unitCents;
      var k = d == 0 ? 0 : numerator ~/ d;
      if (d != 0) {
        final rem = numerator - k * d;
        if (2 * rem > d) k += 1; // round to nearest; an exact half rounds down
      }
      amounts[i] = k * unitCents;
      allocatedToLower += amounts[i];
    }
    amounts[0] = netCents - allocatedToLower;

    for (var i = p - 1; i >= 1; i--) {
      while (unitCents > 0 &&
          amounts[i] > amounts[i - 1] &&
          amounts[i] >= unitCents) {
        amounts[i] -= unitCents;
        amounts[i - 1] += unitCents;
      }
    }
    return amounts;
  }

  /// `payoutPlan(players, pool, opts)` (§F2.1, §F2.11, §F2.12a).
  ///
  /// Verified by hand against the spec's own fully-worked trace:
  /// `payoutPlan(11, 165, {buyIn: 15, organiser: {mode: 'percent', value:
  /// 10}})` → fee 16.00, net 149.00, drops from 3 to 2 places (3rd's 22.35 <
  /// 1.5 × 15 = 22.50), final places 99.00 / 50.00.
  static PayoutPlanResult payoutPlan(
    int players,
    num pool,
    PayoutPlanOptions opts,
  ) {
    final poolCents = _toCents(pool);
    final buyInCents = _toCents(opts.buyIn);
    final unitCents = cashUnit(opts.buyIn) * 100;
    final entries = players + (opts.countRebuys ? opts.rebuys : 0);

    final fee = organiserFee(
      pool,
      opts.organiser ?? const OrganiserFeeConfig(),
      entries: entries,
    );
    final netCents = fee.netCents;

    // Host-supplied explicit shares bypass the curve, the shape table and
    // the min-cash loop entirely — the host has already decided the split.
    if (opts.customShares != null) {
      final shares = opts.customShares!;
      _validateShares(shares);
      final amounts = roundShares(netCents, shares, unitCents);
      return PayoutPlanResult(
        places: shares.length,
        amounts: [for (final c in amounts) c / 100.0],
        grossPool: poolCents / 100.0,
        fee: fee.fee,
        netPool: netCents / 100.0,
        warnings: fee.warnings,
      );
    }

    List<double> shapeFor(int places) {
      final table = opts.shape == 'standard' ? standardShapes : ownerShapes;
      return table[places] ?? const [100];
    }

    var places = opts.forcePlaces ?? curvePlaces(entries, curve: opts.curve);
    places = math.min(places, math.min(opts.maxPlaces, 6));
    // Never pay half the field.
    places = math.min(places, math.max(1, (players ~/ 2) - 1));
    if (places < 1) places = players > 0 && netCents > 0 ? 1 : 0;

    while (places > 1) {
      final shares = shapeFor(places);
      final lastPct = shares.last;
      final lastCents = (netCents * lastPct / 100).round();
      final minCashFloorCents = (1.5 * buyInCents).round();
      if (lastCents < minCashFloorCents) {
        places -= 1;
        continue;
      }
      if (lastCents < unitCents) {
        places -= 1;
        continue;
      }
      break;
    }

    final amounts = places > 0
        ? roundShares(netCents, shapeFor(places), unitCents)
        : const <int>[];

    return PayoutPlanResult(
      places: places,
      amounts: [for (final c in amounts) c / 100.0],
      grossPool: poolCents / 100.0,
      fee: fee.fee,
      netPool: netCents / 100.0,
      warnings: fee.warnings,
    );
  }

  static void _validateShares(List<num> shares) {
    if (shares.isEmpty) {
      throw ArgumentError('payoutPlan: customShares must not be empty');
    }
    final sum = shares.fold<num>(0, (a, b) => a + b);
    if ((sum - 100).abs() > 0.01) {
      throw ArgumentError('payoutPlan: customShares must sum to 100 (got $sum)');
    }
    for (var i = 0; i < shares.length; i++) {
      if (shares[i] <= 0) {
        throw ArgumentError('payoutPlan: every share must be > 0');
      }
      if (i > 0 && shares[i] > shares[i - 1]) {
        throw ArgumentError('payoutPlan: customShares must be non-increasing');
      }
    }
  }

  // ---------------------------------------------------------------------
  // F2.3 — the organiser's cut.
  // ---------------------------------------------------------------------

  /// `organiserFee(pool, cfg)` (§F2.3).
  ///
  /// The fee always rounds DOWN to [OrganiserFeeConfig.roundTo] and must be
  /// strictly less than the pool — calling it with a fee that would reach
  /// the pool throws, by design (the spec's own UI is responsible for
  /// lowering a fixed/per-entry fee to the pool minus one cash unit before
  /// that happens; that clamp is a screen concern, not this function's).
  ///
  /// Conceptually the fee is locked once rebuys close and a deal never
  /// recalculates it (§F2.3) — that lock is state the host's game holds, not
  /// something this pure function can or should enforce.
  static OrganiserFeeResult organiserFee(
    num pool,
    OrganiserFeeConfig cfg, {
    int entries = 0,
  }) {
    final poolCents = _toCents(pool);
    var feeCents = 0;
    switch (cfg.mode) {
      case OrganiserFeeMode.none:
        feeCents = 0;
      case OrganiserFeeMode.percent:
        feeCents = (poolCents * cfg.value / 100).floor();
      case OrganiserFeeMode.fixed:
        feeCents = _toCents(cfg.value);
      case OrganiserFeeMode.perEntry:
        feeCents = _toCents(cfg.value) * entries;
    }
    if (feeCents < 0) feeCents = 0;

    final roundToCents = _toCents(cfg.roundTo) <= 0 ? 100 : _toCents(cfg.roundTo);
    feeCents = (feeCents ~/ roundToCents) * roundToCents; // floors, never up

    if (feeCents >= poolCents) {
      throw ArgumentError(
        'organiserFee: fee (${feeCents / 100.0}) must be less than the pool '
        '(${poolCents / 100.0})',
      );
    }

    final warnings = <String>[
      if (feeCents > 0) 'POOL_DEDUCTION',
      if (cfg.visibility == 'host') 'HIDDEN_FROM_PLAYERS',
    ];

    return OrganiserFeeResult(
      feeCents: feeCents,
      netCents: poolCents - feeCents,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------------
  // F2.5 — ICM (delegates to the exact bitmask-DP / Monte-Carlo engine).
  // ---------------------------------------------------------------------

  /// `icm(stacks, prizes, opts)` (§F2.5) — a spec-named wrapper over
  /// [Icm.compute], which carries the actual Malmuth–Harville DP.
  static IcmResult icm(
    List<int> stacks,
    List<int> prizes, {
    int seed = Icm.defaultSeed,
  }) =>
      Icm.compute(stacks: stacks, payouts: prizes, seed: seed);

  // ---------------------------------------------------------------------
  // F2.6 — the other deals: chip chop, equal chop, leave-for-winner.
  // ---------------------------------------------------------------------

  /// `chipChop(stacks, prizes)` (§F2.6). Everyone first gets the lowest
  /// remaining prize; the rest of the pool splits by chip share; nobody gets
  /// more than 1st (excess re-splits among the still-uncapped players until
  /// stable).
  ///
  /// Verified by hand: `chipChop([8000,5000,2000],[250,150,100])` →
  /// 206.67 / 166.67 / 126.67 (2dp), matching §F2.11.
  static List<double> chipChop(List<int> stacks, List<int> prizes) {
    final n = stacks.length;
    if (n == 0 || prizes.isEmpty) return List<double>.filled(n, 0);

    final totalPool = prizes.fold<double>(0, (a, p) => a + p);
    final totalChips = stacks.fold<int>(0, (a, s) => a + s);
    final base = prizes.last.toDouble();
    final cap = prizes.first.toDouble();

    final amounts = List<double>.filled(n, base);
    final isCapped = List<bool>.filled(n, false);
    var poolLeft = totalPool - base * n;

    while (poolLeft > 1e-9) {
      var activeChips = 0;
      for (var i = 0; i < n; i++) {
        if (!isCapped[i]) activeChips += stacks[i];
      }
      if (activeChips <= 0 || totalChips <= 0) break;

      final tentative = List<double>.from(amounts);
      for (var i = 0; i < n; i++) {
        if (isCapped[i]) continue;
        tentative[i] = amounts[i] + poolLeft * stacks[i] / activeChips;
      }

      var overflow = 0.0;
      var anyNewlyCapped = false;
      for (var i = 0; i < n; i++) {
        if (isCapped[i]) continue;
        if (tentative[i] > cap + 1e-9) {
          overflow += tentative[i] - cap;
          tentative[i] = cap;
          isCapped[i] = true;
          anyNewlyCapped = true;
        }
      }
      for (var i = 0; i < n; i++) {
        amounts[i] = tentative[i];
      }
      poolLeft = overflow;
      if (!anyNewlyCapped) break;
    }
    return amounts;
  }

  /// `equalChop(n, prizes)` (§F2.6) — the top-`n` prizes split evenly.
  static List<double> equalChop(int n, List<int> prizes) {
    if (n <= 0) return const [];
    final total = prizes.take(n).fold<double>(0, (a, p) => a + p);
    final share = total / n;
    return List<double>.filled(n, share);
  }

  /// `leaveForWinner(stacks, prizes, x, method)` (§F2.6). Takes `x` off 1st
  /// (`0 ≤ x ≤ 1st − 2nd`), chops the rest by [method] (`'icm'`, `'chip'` or
  /// `'equal'`), and plays winner-take-all for `x`:
  /// `ev_i = locked_i + x × chipShare_i`.
  ///
  /// Verified by hand: leaving 50 for the winner (chip method) on
  /// [8000,5000,2000] / [250,150,100] locks 180 / 150 / 120, and its `ev`
  /// reproduces plain chip-chop (206.67 / 166.67 / 126.67) exactly —
  /// matching §F2.11's "with icm, ev equals plain ICM exactly".
  static LeaveForWinnerResult leaveForWinner(
    List<int> stacks,
    List<int> prizes,
    num x, {
    String method = 'icm',
  }) {
    if (prizes.isEmpty) {
      return LeaveForWinnerResult(
        locked: const [],
        ev: List<double>.filled(stacks.length, 0),
      );
    }
    final lockedPrizes = List<int>.from(prizes);
    lockedPrizes[0] = (lockedPrizes[0] - x).round();

    final List<double> locked;
    switch (method) {
      case 'chip':
        locked = chipChop(stacks, lockedPrizes);
      case 'equal':
        locked = equalChop(stacks.length, lockedPrizes);
      case 'icm':
      default:
        locked = Icm.equity(stacks: stacks, payouts: lockedPrizes);
    }

    final totalChips = stacks.fold<int>(0, (a, s) => a + s);
    final ev = List<double>.filled(stacks.length, 0);
    for (var i = 0; i < stacks.length; i++) {
      final chipShare = totalChips > 0 ? stacks[i] / totalChips : 0.0;
      ev[i] = locked[i] + x * chipShare;
    }
    return LeaveForWinnerResult(locked: locked, ev: ev);
  }

  /// `compareDeals(stacks, prizes)` (§F2.6) — ICM, chip and equal chop side
  /// by side, the deal screen's data.
  static DealComparison compareDeals(List<int> stacks, List<int> prizes) {
    return DealComparison(
      icm: Icm.equity(stacks: stacks, payouts: prizes),
      chip: chipChop(stacks, prizes),
      equal: equalChop(stacks.length, prizes),
    );
  }

  /// C-deal item 4's guard: the agreed amounts must add up to exactly what is
  /// left to pay, otherwise the deal shows
  /// "The agreed amounts add up to 185, but 189 is left to pay. Fix them
  /// first."
  ///
  /// The host edits whole currency units, so the sums arrive as doubles and
  /// must be compared at a half-cent tolerance — [roundDeal] hands out
  /// whole units, and forcing a coarser unit than the host is typing in would
  /// reject a split they can see is correct.
  static String? dealAmountsError(double agreed, double leftToPay) {
    if ((agreed - leftToPay).abs() < 0.005) return null;
    final a = _dealAmountText(agreed);
    final l = _dealAmountText(leftToPay);
    return 'The agreed amounts add up to $a, but $l is left to pay. '
        'Fix them first.';
  }

  /// Deal figures render as the host typed them: whole units stay whole
  /// ("185", not "185.00"), because the error text above is specified with
  /// bare integers and a trailing ".00" would read as a different number.
  static String _dealAmountText(double amount) {
    final rounded = (amount * 100).round();
    if (rounded % 100 == 0) return '${rounded ~/ 100}';
    return (rounded / 100).toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------
  // F2.7 — rounding a deal, and the bubble save.
  // ---------------------------------------------------------------------

  /// `roundDeal(amountsCents, unitCents, totalCents, capCents)` (§F2.7).
  ///
  /// Floors every amount to `unit`, hands the remaining whole units out by
  /// largest remainder (ties to the lower index), and gives any leftover
  /// sub-unit residue to the largest amount that stays at or under `cap`.
  /// Throws when `total > cap × n` (the deal cannot fit). The v3.1 fix noted
  /// in the spec — the residue must never push the largest amount above the
  /// cap — is why the residue pass checks `<= cap` before applying, same as
  /// the whole-unit distribution above it.
  static List<int> roundDeal(
    List<num> amountsCents,
    int unitCents,
    int totalCents,
    int capCents,
  ) {
    final n = amountsCents.length;
    if (n == 0) return const [];
    if (totalCents > capCents * n) {
      throw ArgumentError(
        'roundDeal: total ($totalCents) exceeds cap * n (${capCents * n})',
      );
    }
    if (unitCents <= 0) {
      throw ArgumentError('roundDeal: unit must be > 0');
    }

    final floors = [for (final a in amountsCents) (a ~/ unitCents) * unitCents];
    final allocated = floors.fold<int>(0, (s, f) => s + f);
    var remainder = totalCents - allocated;
    if (remainder < 0) remainder = 0;
    var unitsToGive = remainder ~/ unitCents;
    final subUnitResidue = remainder - unitsToGive * unitCents;

    final remainders = [
      for (var i = 0; i < n; i++) amountsCents[i] - floors[i],
    ];
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final cmp = remainders[b].compareTo(remainders[a]);
        return cmp != 0 ? cmp : a.compareTo(b); // ties to the lower index
      });

    final result = List<int>.from(floors);
    var idx = 0;
    var guard = 0;
    final maxGuard = n * 8 + 8;
    while (unitsToGive > 0 && guard < maxGuard) {
      final i = order[idx % order.length];
      if (result[i] + unitCents <= capCents) {
        result[i] += unitCents;
        unitsToGive--;
      }
      idx++;
      guard++;
    }

    if (subUnitResidue > 0) {
      final byAmountDesc = List<int>.generate(n, (i) => i)
        ..sort((a, b) => result[b].compareTo(result[a]));
      for (final i in byAmountDesc) {
        if (result[i] + subUnitResidue <= capCents) {
          result[i] += subUnitResidue;
          break;
        }
      }
    }

    return result;
  }

  /// `bubbleSave(prizesCents, amountCents, fundFrom, unitCents)` (§F2.7).
  /// Adds one paid place worth `amount` (must be ≤ the current lowest
  /// prize). `'first'` takes it all off 1st; `'proRata'` (D10, the app's
  /// default) has every paid place below 1st contribute
  /// `amount × its prize / total`, rounded to `unit`, with 1st paying the
  /// exact remainder — and re-floors (rounds down) instead if that would
  /// overdraw the bubble amount.
  ///
  /// Verified by hand against §F2.12d:
  /// `bubbleSave([99,60,30], 15, 'proRata', 1)` → `[91, 55, 28, 15]` exactly.
  static List<int> bubbleSave(
    List<int> prizesCents,
    int amountCents,
    String fundFrom,
    int unitCents,
  ) {
    if (prizesCents.isEmpty) {
      throw ArgumentError('bubbleSave: prizes must not be empty');
    }
    if (amountCents > prizesCents.last) {
      throw ArgumentError(
        'bubbleSave: amount ($amountCents) must be <= the lowest prize '
        '(${prizesCents.last})',
      );
    }

    final result = List<int>.from(prizesCents);

    if (fundFrom == 'first') {
      result[0] -= amountCents;
    } else {
      final totalCents = prizesCents.fold<int>(0, (a, b) => a + b);
      List<int> sharesFor(bool floorInsteadOfRound) {
        final shares = List<int>.filled(prizesCents.length, 0);
        for (var i = 1; i < prizesCents.length; i++) {
          final raw = amountCents * prizesCents[i] / totalCents / unitCents;
          final k = floorInsteadOfRound ? raw.floor() : raw.round();
          shares[i] = k * unitCents;
        }
        return shares;
      }

      var shares = sharesFor(false);
      var taken = shares.fold<int>(0, (a, b) => a + b);
      if (taken > amountCents) {
        // Rounding overdrew the bubble amount — round down instead.
        shares = sharesFor(true);
        taken = shares.fold<int>(0, (a, b) => a + b);
      }

      for (var i = 1; i < prizesCents.length; i++) {
        result[i] -= shares[i];
      }
      result[0] -= (amountCents - taken);
    }

    result.add(amountCents);

    for (var i = 1; i < result.length; i++) {
      if (result[i] > result[i - 1]) {
        throw StateError(
          'bubbleSave: resulting ladder is out of order ($result)',
        );
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // F2.8 — when the app suggests a deal.
  // ---------------------------------------------------------------------

  /// `dealTrigger(state)` (§F2.8). Highest priority first: `targetTime` >
  /// `bubble` > `inTheMoney` > `headsUp`; each fires once per game and never
  /// auto-applies. [DealTriggerState.suggestFrom] (the host's "Suggest an
  /// ICM deal from" setting, 2–5 players, default 5) gates whether the deal
  /// card can appear at all, regardless of which trigger would otherwise
  /// fire.
  ///
  /// Verified by hand: 4 players left, 3 paid places → `bubble` (§F2.11).
  static DealTriggerType? dealTrigger(DealTriggerState state) {
    if (state.remainingPlayers > state.suggestFrom) return null;
    if (state.remainingPlayers < 2) return null;

    if (state.targetTimeReached &&
        !state.alreadyFired.contains(DealTriggerType.targetTime)) {
      return DealTriggerType.targetTime;
    }
    if (state.remainingPlayers == state.paidPlaces + 1 &&
        !state.alreadyFired.contains(DealTriggerType.bubble)) {
      return DealTriggerType.bubble;
    }
    if (state.remainingPlayers <= state.paidPlaces &&
        !state.alreadyFired.contains(DealTriggerType.inTheMoney)) {
      return DealTriggerType.inTheMoney;
    }
    if (state.remainingPlayers == 2 &&
        !state.alreadyFired.contains(DealTriggerType.headsUp)) {
      return DealTriggerType.headsUp;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // F2.9 — season points.
  // ---------------------------------------------------------------------

  /// `seasonPoints` (§F2.9). Default `fieldSize` formula:
  /// `10 × √(players / finish)`, one decimal — 12 players: winner 34.6; 6
  /// players: winner 24.5; last place is always 10 (`√(n/n) = 1`). `ladder`
  /// (10·7·5·3·1 by default) and `custom` read `points[finish − 1]`, 0 beyond
  /// the table. `players` must be the head count who actually played —
  /// rebuys never add players.
  static double seasonPoints(
    int players,
    int finish, {
    SeasonFormula formula = SeasonFormula.fieldSize,
    List<num> ladder = const [10, 7, 5, 3, 1],
    List<num> custom = const [],
  }) {
    if (players <= 0 || finish <= 0) return 0;
    switch (formula) {
      case SeasonFormula.ladder:
        return finish - 1 < ladder.length ? ladder[finish - 1].toDouble() : 0;
      case SeasonFormula.custom:
        return finish - 1 < custom.length ? custom[finish - 1].toDouble() : 0;
      case SeasonFormula.fieldSize:
        final v = 10 * math.sqrt(players / finish);
        return (v * 10).round() / 10.0;
    }
  }

  /// `seasonTable` (§F2.9) — points summed across the season's nights (one
  /// decimal), ranked by points, then wins, then name.
  static List<SeasonStanding> seasonTable(
    List<List<SeasonNightResult>> nights, {
    SeasonFormula formula = SeasonFormula.fieldSize,
    List<num> ladder = const [10, 7, 5, 3, 1],
    List<num> custom = const [],
  }) {
    final totals = <String, double>{};
    final wins = <String, int>{};

    for (final night in nights) {
      final players = night.length; // who played, not entries with rebuys
      for (final r in night) {
        final pts = seasonPoints(
          players,
          r.finish,
          formula: formula,
          ladder: ladder,
          custom: custom,
        );
        totals[r.name] = (totals[r.name] ?? 0) + pts;
        if (r.finish == 1) wins[r.name] = (wins[r.name] ?? 0) + 1;
      }
    }

    final standings = [
      for (final name in totals.keys)
        SeasonStanding(
          name: name,
          points: ((totals[name] ?? 0) * 10).round() / 10.0,
          wins: wins[name] ?? 0,
        ),
    ]..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        final byWins = b.wins.compareTo(a.wins);
        if (byWins != 0) return byWins;
        return a.name.compareTo(b.name);
      });
    return standings;
  }

  // ---------------------------------------------------------------------
  // F2.10 — cash settle-up (delegates to the bitmask-DP min-transfer engine).
  // ---------------------------------------------------------------------

  /// `settleUp(balances)` (§F2.10) — a spec-named wrapper over
  /// [CashSettlement.settleBalances], which carries the actual bitmask DP.
  /// [balances] are in whole currency units; converted to cents internally.
  ///
  /// Verified by hand: balances +4 +3 +3 −6 −4 (A,B,C,D,E) settle in exactly
  /// 3 transfers (D→B 3, D→C 3, E→A 4), not the 4 that greedy pairing on the
  /// whole table would take.
  static SettleUpResult settleUp(List<({String name, num balance})> balances) {
    final cents = [
      for (final b in balances) (name: b.name, cents: _toCents(b.balance)),
    ];
    final transfers = CashSettlement.settleBalances(cents);
    final peopleWithBalance = cents.where((b) => b.cents != 0).length;
    return SettleUpResult(
      transfers: transfers,
      count: transfers.length,
      groups: peopleWithBalance - transfers.length,
    );
  }

  // ---------------------------------------------------------------------
  // F2.4 — the bounty pot.
  // ---------------------------------------------------------------------

  /// The bounty pot never enters [payoutPlan]'s `pool` (§F2.4): with KO
  /// bounty on, each entry and rebuy pays `buyIn + bounty`, and the bounty
  /// portion is tracked here, separately, credited to whoever eliminates
  /// that player. Fixed bounty only — progressive and mystery bounty are
  /// Premium and their mechanics are open (O8).
  static BountyPot bountyPot({required num bountyPerEntry}) =>
      BountyPot(bountyPerEntry: bountyPerEntry);
}

int _toCents(num v) => (v * 100).round();

/// [PayoutsEngine.organiserFee]'s modes. `perEntry` has no v1 screen but
/// stays in the engine for parity with the spec (§F2.3).
enum OrganiserFeeMode { none, percent, fixed, perEntry }

/// Configuration for [PayoutsEngine.organiserFee] / [PayoutsEngine.payoutPlan].
class OrganiserFeeConfig {
  const OrganiserFeeConfig({
    this.mode = OrganiserFeeMode.none,
    this.value = 0,
    this.roundTo = 1,
    this.visibility = 'host',
  });

  /// `none` (default) | `percent` | `fixed` | `perEntry`.
  final OrganiserFeeMode mode;

  /// Percent (0–100, `percent` mode) or a currency-unit amount (`fixed` /
  /// `perEntry` modes).
  final num value;

  /// Rounds the computed fee down to a multiple of this many currency
  /// units. Default 1.
  final num roundTo;

  /// `'host'` (default, hides the fee from players) or `'players'`.
  final String visibility;
}

/// [PayoutsEngine.organiserFee]'s result.
class OrganiserFeeResult {
  const OrganiserFeeResult({
    required this.feeCents,
    required this.netCents,
    required this.warnings,
  });

  final int feeCents;
  final int netCents;

  /// `'POOL_DEDUCTION'` whenever the fee is non-zero; `'HIDDEN_FROM_PLAYERS'`
  /// when [OrganiserFeeConfig.visibility] is `'host'`.
  final List<String> warnings;

  double get fee => feeCents / 100.0;
  double get net => netCents / 100.0;
}

/// Options for [PayoutsEngine.payoutPlan].
class PayoutPlanOptions {
  const PayoutPlanOptions({
    required this.buyIn,
    this.organiser,
    this.rebuys = 0,
    this.countRebuys = true,
    this.curve = 'ps15',
    this.shape = 'owner',
    this.forcePlaces,
    this.customShares,
    this.maxPlaces = 6,
  });

  final num buyIn;
  final OrganiserFeeConfig? organiser;
  final int rebuys;
  final bool countRebuys;

  /// `'ps10'` | `'ps15'` (default) | `'ps20'`.
  final String curve;

  /// `'owner'` (default) | `'standard'`.
  final String shape;

  /// Host override: a specific number of paid places (the shape still
  /// applies).
  final int? forcePlaces;

  /// Host override: explicit percentages by place, must sum to 100, each >
  /// 0, non-increasing. Bypasses the curve and shape entirely.
  final List<num>? customShares;

  final int maxPlaces;
}

/// [PayoutsEngine.payoutPlan]'s result.
class PayoutPlanResult {
  const PayoutPlanResult({
    required this.places,
    required this.amounts,
    required this.grossPool,
    required this.fee,
    required this.netPool,
    required this.warnings,
  });

  final int places;

  /// Amount for each paid place, largest first, whole currency units.
  final List<double> amounts;

  final double grossPool;
  final double fee;
  final double netPool;
  final List<String> warnings;
}

/// [PayoutsEngine.dealTrigger]'s four types, in priority order.
enum DealTriggerType { targetTime, bubble, inTheMoney, headsUp }

/// Input to [PayoutsEngine.dealTrigger].
class DealTriggerState {
  const DealTriggerState({
    required this.remainingPlayers,
    required this.paidPlaces,
    this.targetTimeReached = false,
    this.suggestFrom = 5,
    this.alreadyFired = const {},
  });

  final int remainingPlayers;
  final int paidPlaces;

  /// Whether the planned end has been reached, with ≥ 2 players left.
  final bool targetTimeReached;

  /// Host setting "Suggest an ICM deal from" — 2..5, default 5. No trigger
  /// fires while more players than this remain.
  final int suggestFrom;

  /// Triggers already shown this game (each type fires once per game).
  final Set<DealTriggerType> alreadyFired;
}

/// [PayoutsEngine.leaveForWinner]'s result.
class LeaveForWinnerResult {
  const LeaveForWinnerResult({required this.locked, required this.ev});

  /// The locked-in chop of the reduced prize pool (after taking `x` off 1st).
  final List<double> locked;

  /// `locked_i + x × chipShare_i` — each player's total expected value.
  final List<double> ev;
}

/// [PayoutsEngine.compareDeals]'s result: three chops, side by side.
class DealComparison {
  const DealComparison({
    required this.icm,
    required this.chip,
    required this.equal,
  });

  final List<double> icm;
  final List<double> chip;
  final List<double> equal;
}

/// [PayoutsEngine.seasonPoints]'s formula choices.
enum SeasonFormula { fieldSize, ladder, custom }

/// One player's finish on one season night, for [PayoutsEngine.seasonTable].
class SeasonNightResult {
  const SeasonNightResult({required this.name, required this.finish});
  final String name;
  final int finish;
}

/// One row of [PayoutsEngine.seasonTable]'s output.
class SeasonStanding {
  const SeasonStanding({
    required this.name,
    required this.points,
    required this.wins,
  });
  final String name;
  final double points;
  final int wins;
}

/// [PayoutsEngine.settleUp]'s result.
class SettleUpResult {
  const SettleUpResult({
    required this.transfers,
    required this.count,
    required this.groups,
  });

  final List<CashTransfer> transfers;

  /// The fewest transfers possible — `count == transfers.length`.
  final int count;

  /// The number of disjoint zero-sum groups the table was cut into.
  final int groups;
}

/// The bounty (KO) pot: always separate from [PayoutsEngine.payoutPlan]'s
/// `pool` (§F2.4). Fixed bounty only; progressive/mystery bounty are
/// Premium and their mechanics are open (O8).
class BountyPot {
  BountyPot({required this.bountyPerEntry});

  /// Currency units paid into the bounty pot per entry or rebuy.
  final num bountyPerEntry;

  int _totalCents = 0;
  final Map<String, int> _owedCents = {};

  /// Call once per entry or rebuy that pays the bounty add-on.
  void addEntry() => _totalCents += _toCents(bountyPerEntry);

  /// Credits the eliminator with this player's bounty.
  void recordElimination(String eliminatorName) {
    _owedCents[eliminatorName] =
        (_owedCents[eliminatorName] ?? 0) + _toCents(bountyPerEntry);
  }

  /// Total ever paid into the pot.
  double get total => _totalCents / 100.0;

  /// What a given eliminator has earned so far.
  double owedTo(String name) => (_owedCents[name] ?? 0) / 100.0;

  /// Everyone credited so far, in currency units.
  Map<String, double> get ledger => {
        for (final e in _owedCents.entries) e.key: e.value / 100.0,
      };
}
