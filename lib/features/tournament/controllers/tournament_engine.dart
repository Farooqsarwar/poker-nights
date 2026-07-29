import 'dart:math';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/features/tournament/models/blind_structure_model.dart';
import 'package:poker_night/features/tournament/models/chip_set_model.dart';

class TournamentEngine {
  TournamentEngine._();

  static BlindStructure generate(TournamentSettings settings, ChipSet? chipSet) {
    final players = settings.expectedPlayers;
    final hours = settings.targetDurationHours;
    final levelDuration = _chooseLevelDuration(hours, players);
    final totalLevels = ((hours * 60) / levelDuration).floor();

    final chips = _getAvailableDenominations(chipSet);
    final openingBB = _pickOpeningBlind(chips, settings);
    final startingStack = _calculateStartingStack(openingBB, hours, players);
    final targetFinalBB = _calculateTargetFinalBB(startingStack, players, hours);
    final growthFactor = pow(targetFinalBB / openingBB, 1.0 / max(1, totalLevels - 1)).toDouble();

    final anteActivationLevel = settings.rebuysEnabled ? settings.rebuyCloseLevel + 1 : (totalLevels ~/ 3);

    final levels = <BlindLevel>[];
    for (int i = 0; i < totalLevels; i++) {
      final raw = openingBB * pow(growthFactor, i).toDouble();
      final bb = _snapBlind(raw.round(), chips);
      final sb = _chooseSmallBlind(bb, chips);
      final ante = _computeAnte(bb, settings.anteMode, settings.expectedPlayers, chips, levelNumber: i + 1, anteActivationLevel: anteActivationLevel);
      levels.add(BlindLevel(
        level: i + 1,
        smallBlind: sb,
        bigBlind: bb,
        ante: ante,
        durationMinutes: levelDuration,
        label: 'Level ${i + 1}',
      ));
    }
    final rebuyStack = startingStack;
    final addOnStack = (startingStack * 0.5).round();
    final chipPlan = _generateChipPlan(startingStack, chips);

    return BlindStructure(
      levels: levels,
      startingStack: startingStack,
      startingStackChips: chipPlan['totalChips'] as int,
      rebuyStack: rebuyStack,
      addOnStack: addOnStack,
      anteActivationLevel: anteActivationLevel,
      predictedFinishLevel: totalLevels,
      chipPlanSummary: chipPlan['summary'] as String,
      chipExchanges: _generateChipExchanges(levels, chips),
    );
  }

  static List<int> _getAvailableDenominations(ChipSet? chipSet) {
    if (chipSet != null && chipSet.chips.isNotEmpty) {
      return chipSet.chips.map((c) => c.value).toList()..sort();
    }
    return [1, 5, 10, 25, 100, 500];
  }

  static int _chooseLevelDuration(double hours, int players) {
    if (hours >= 5 && players <= 8) return 20;
    if (hours >= 4) return 15;
    if (hours <= 3.5 && players >= 6) return 10;
    return 15;
  }

  static int _pickOpeningBlind(List<int> chips, TournamentSettings settings) {
    final minChip = chips.isNotEmpty ? chips.first : 1;
    final buyIn = settings.buyIn.round();
    if (buyIn <= 10) return minChip * 10;
    if (buyIn <= 20) return minChip * 25;
    if (buyIn <= 50) return minChip * 50;
    return minChip * 100;
  }

  static int _calculateStartingStack(int openingBB, double hours, int players) {
    final targetBB = (125 + 28 * (hours - 3.5) - 2.5 * max(0, players - 8)).round();
    final clamped = min(max(targetBB, 80), 240);
    return _practicalRound(openingBB * clamped);
  }

  static int _calculateTargetFinalBB(int startingStack, int players, double hours) {
    final expectedTotal = startingStack * players + startingStack * players ~/ 2;
    return (expectedTotal / (2 * 15)).round();
  }

  static int _snapBlind(int bb, List<int> chips) {
    final smallest = chips.isNotEmpty ? chips.first : 1;
    if (bb <= 50 * smallest) return _roundToNearest(bb, 5 * smallest);
    if (bb <= 100 * smallest) return _roundToNearest(bb, 10 * smallest);
    if (bb <= 500 * smallest) return _roundToNearest(bb, 25 * smallest);
    if (bb <= 1000 * smallest) return _roundToNearest(bb, 50 * smallest);
    if (bb <= 5000 * smallest) return _roundToNearest(bb, 100 * smallest);
    return _roundToNearest(bb, 250 * smallest);
  }

  static int _chooseSmallBlind(int bb, List<int> chips) {
    final smallest = chips.isNotEmpty ? chips.first : 1;
    final candidate = (bb ~/ 2).round();
    return _snapBlind(max(candidate, smallest), chips);
  }

  static int _roundToNearest(int value, int multiple) {
    return ((value + multiple ~/ 2) ~/ multiple) * multiple;
  }

  static int _practicalRound(int value) {
    if (value <= 500) return ((value + 49) ~/ 50) * 50;
    if (value <= 5000) return ((value + 99) ~/ 100) * 100;
    return ((value + 499) ~/ 500) * 500;
  }

  static int _computeAnte(int bb, String anteMode, int players, List<int> chips, {int levelNumber = 1, int anteActivationLevel = 999}) {
    if (anteMode == 'none' || levelNumber < anteActivationLevel) return 0;
    if (anteMode == 'big blind ante') return bb;
    final avgTableSize = players < 10 ? players : min(players, 9);
    final rawAnte = (bb / avgTableSize).round();
    return chips.isNotEmpty ? _snapBlind(max(rawAnte, chips.first), chips) : rawAnte;
  }

  static String? checkInventory(int stack, int playerCount, List<ChipDenomination> availableChips) {
    final byValue = <int, int>{};
    for (final c in availableChips) {
      byValue[c.value] = (byValue[c.value] ?? 0) + c.quantity;
    }
    final chipValues = byValue.keys.toList()..sort((a, b) => b.compareTo(a));
    int perPlayer = stack;
    final neededPerPlayer = <int, int>{};
    for (final val in chipValues) {
      final count = perPlayer ~/ val;
      if (count > 0) {
        neededPerPlayer[val] = count;
        perPlayer -= count * val;
      }
    }
    if (perPlayer > 0) {
      neededPerPlayer[chipValues.last] = (neededPerPlayer[chipValues.last] ?? 0) + 1;
    }
    final totalNeeded = <int, int>{};
    for (final entry in neededPerPlayer.entries) {
      totalNeeded[entry.key] = entry.value * playerCount;
    }
    for (final entry in totalNeeded.entries) {
      final available = byValue[entry.key] ?? 0;
      if (entry.value > available) {
        return 'Not enough \$${entry.key} chips: need ${entry.value}, have $available';
      }
    }
    return null;
  }

  static Map<String, dynamic> _generateChipPlan(int stack, List<int> chips) {
    int count = 0;
    int remaining = stack;
    final sorted = List<int>.from(chips)..sort((a, b) => b.compareTo(a));
    for (final denom in sorted) {
      if (denom > remaining) continue;
      final chipsForDenom = remaining ~/ denom;
      if (chipsForDenom > 0) {
        count += chipsForDenom;
        remaining -= chipsForDenom * denom;
      }
    }
    return {
      'totalChips': count,
      'summary': 'Starting stack: $stack chips in $count chips',
    };
  }

  static List<ChipExchange> _generateChipExchanges(List<BlindLevel> levels, List<int> chips) {
    final exchanges = <ChipExchange>[];
    for (int i = 1; i < levels.length; i++) {
      if (levels[i].bigBlind > levels[i - 1].bigBlind * 2) {
        final removeVals = chips.where((c) => c * 4 < levels[i].bigBlind).toList();
        if (removeVals.isNotEmpty) {
          exchanges.add(ChipExchange(
            atLevel: levels[i].level,
            instruction: 'Remove ${removeVals.map((v) => '\$$v').join(', ')} chips at break (Level ${levels[i].level})',
          ));
        }
      }
    }
    return exchanges;
  }

  static PrizeDistribution calculatePrizes(double buyIn, int playerCount, double organizerPercent, {double koBounty = 0}) {
    final regularBuyIn = buyIn - koBounty;
    final grossEligible = (regularBuyIn * playerCount).round();
    final targetOrganizer = (grossEligible * organizerPercent).round();
    var organizerAmount = _roundOrganizer(grossEligible, targetOrganizer);
    var prizePool = grossEligible - organizerAmount;
    if (prizePool % 10 != 0) {
      final adjustment = prizePool % 10;
      organizerAmount += adjustment;
      prizePool -= adjustment;
    }

    final paidPlaces = _calculatePaidPlaces(playerCount, prizePool);
    final weights = _generateWeights(paidPlaces);
    final payouts = _roundPayouts(prizePool, weights);

    return PrizeDistribution(
      prizePool: prizePool,
      organizerAmount: organizerAmount,
      paidPlaces: paidPlaces,
      payouts: payouts,
    );
  }

  static int _roundOrganizer(int gross, int target) {
    final low = (target ~/ 10) * 10;
    final high = low + 10;
    if (gross - high < 0) return low;
    return (target - low).abs() <= (high - target).abs() ? low : high;
  }

  static int _calculatePaidPlaces(int players, int prizePool) {
    if (players <= 4) return 2;
    if (players <= 8) {
      return prizePool >= 100 ? 3 : 2;
    }
    if (players <= 12) return prizePool >= 150 ? 4 : 3;
    return 4;
  }

  static List<double> _generateWeights(int places) {
    switch (places) {
      case 2: return [0.73, 0.27];
      case 3: return [0.57, 0.30, 0.13];
      case 4: return [0.56, 0.30, 0.10, 0.04];
      case 5: return [0.50, 0.25, 0.13, 0.07, 0.05];
      case 6: return [0.48, 0.24, 0.14, 0.07, 0.04, 0.03];
      case 7: return [0.44, 0.22, 0.14, 0.08, 0.06, 0.04, 0.02];
      case 8: return [0.42, 0.22, 0.14, 0.08, 0.06, 0.04, 0.02, 0.02];
      default: return [0.56, 0.30, 0.10, 0.04];
    }
  }

  static List<PayoutEntry> _roundPayouts(int prizePool, List<double> weights) {
    final payouts = <PayoutEntry>[];
    var remaining = prizePool;
    for (int i = 0; i < weights.length; i++) {
      final isLast = i == weights.length - 1;
      int amount;
      if (isLast) {
        amount = remaining;
      } else {
        amount = ((prizePool * weights[i]) ~/ 10) * 10;
      }
      payouts.add(PayoutEntry(position: i + 1, amount: amount));
      remaining -= amount;
    }
    if (remaining > 0 && payouts.isNotEmpty) {
      payouts[0] = payouts[0].copyWith(amount: payouts[0].amount + remaining);
    }
    return payouts;
  }

  static PayoutReference? lookupPayoutReference(int buyIn, int players) {
    final gross = buyIn * players;
    final normalised = ((gross / 10).round() * 10).clamp(500, 7000);
    for (final entry in _payoutReferenceTable) {
      if (entry.buyInRange.contains(normalised) && entry.playerRange.contains(players)) {
        return entry;
      }
    }
    return null;
  }

  static const List<PayoutReference> _payoutReferenceTable = [
    PayoutReference(buyInRange: [500, 600], playerRange: [6, 10], paidPlaces: 3, percentages: [0.57, 0.30, 0.13]),
    PayoutReference(buyInRange: [500, 600], playerRange: [11, 20], paidPlaces: 4, percentages: [0.56, 0.30, 0.10, 0.04]),
    PayoutReference(buyInRange: [600, 800], playerRange: [6, 10], paidPlaces: 3, percentages: [0.57, 0.30, 0.13]),
    PayoutReference(buyInRange: [600, 800], playerRange: [11, 20], paidPlaces: 4, percentages: [0.56, 0.30, 0.10, 0.04]),
    PayoutReference(buyInRange: [800, 1000], playerRange: [6, 10], paidPlaces: 4, percentages: [0.56, 0.30, 0.10, 0.04]),
    PayoutReference(buyInRange: [800, 1000], playerRange: [11, 20], paidPlaces: 5, percentages: [0.50, 0.25, 0.13, 0.07, 0.05]),
    PayoutReference(buyInRange: [1000, 1500], playerRange: [6, 10], paidPlaces: 4, percentages: [0.54, 0.28, 0.12, 0.06]),
    PayoutReference(buyInRange: [1000, 1500], playerRange: [11, 20], paidPlaces: 6, percentages: [0.48, 0.24, 0.14, 0.07, 0.04, 0.03]),
    PayoutReference(buyInRange: [1500, 2100], playerRange: [6, 10], paidPlaces: 4, percentages: [0.52, 0.28, 0.13, 0.07]),
    PayoutReference(buyInRange: [1500, 2100], playerRange: [11, 20], paidPlaces: 6, percentages: [0.46, 0.24, 0.14, 0.08, 0.05, 0.03]),
    PayoutReference(buyInRange: [2100, 3000], playerRange: [6, 10], paidPlaces: 5, percentages: [0.48, 0.26, 0.14, 0.07, 0.05]),
    PayoutReference(buyInRange: [2100, 3000], playerRange: [11, 20], paidPlaces: 7, percentages: [0.44, 0.22, 0.14, 0.08, 0.06, 0.04, 0.02]),
    PayoutReference(buyInRange: [3000, 5000], playerRange: [6, 10], paidPlaces: 5, percentages: [0.48, 0.24, 0.14, 0.08, 0.06]),
    PayoutReference(buyInRange: [3000, 5000], playerRange: [11, 20], paidPlaces: 8, percentages: [0.42, 0.22, 0.14, 0.08, 0.06, 0.04, 0.02, 0.02]),
    PayoutReference(buyInRange: [5000, 7000], playerRange: [6, 10], paidPlaces: 6, percentages: [0.44, 0.22, 0.14, 0.08, 0.06, 0.06]),
    PayoutReference(buyInRange: [5000, 7000], playerRange: [11, 20], paidPlaces: 8, percentages: [0.40, 0.22, 0.14, 0.08, 0.06, 0.04, 0.04, 0.02]),
  ];
}

class PayoutReference {
  final List<int> buyInRange;
  final List<int> playerRange;
  final int paidPlaces;
  final List<double> percentages;

  const PayoutReference({
    required this.buyInRange,
    required this.playerRange,
    required this.paidPlaces,
    required this.percentages,
  });
}

class PrizeDistribution {
  final int prizePool;
  final int organizerAmount;
  final int paidPlaces;
  final List<PayoutEntry> payouts;

  PrizeDistribution({
    required this.prizePool,
    required this.organizerAmount,
    required this.paidPlaces,
    required this.payouts,
  });
}

class PayoutEntry {
  final int position;
  final int amount;

  PayoutEntry({required this.position, required this.amount});

  PayoutEntry copyWith({int? position, int? amount}) {
    return PayoutEntry(
      position: position ?? this.position,
      amount: amount ?? this.amount,
    );
  }
}
