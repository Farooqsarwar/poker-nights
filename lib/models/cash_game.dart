/// A participant in a cash game.
class CashPlayer {
  const CashPlayer({
    required this.id,
    required this.name,
    required this.stack,
    required this.totalBuyIns,
    required this.buyInCount,
    required this.cashedOut,
    this.hasCashedOut = false,
  });

  final String id;
  final String name;
  final double stack;
  final double totalBuyIns;
  final int buyInCount;
  final double cashedOut;
  final bool hasCashedOut;

  bool get isCashedOut => hasCashedOut;

  /// Where this person stands: what they took out, plus what is still in front
  /// of them, minus what they put in -- across every stint of the session
  /// (a rejoin does not wipe an earlier cash-out).
  double get net => cashedOut + (hasCashedOut ? 0 : stack) - totalBuyIns;

  CashPlayer copyWith({
    String? id,
    String? name,
    double? stack,
    double? totalBuyIns,
    int? buyInCount,
    double? cashedOut,
    bool? hasCashedOut,
  }) {
    return CashPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      stack: stack ?? this.stack,
      totalBuyIns: totalBuyIns ?? this.totalBuyIns,
      buyInCount: buyInCount ?? this.buyInCount,
      cashedOut: cashedOut ?? this.cashedOut,
      hasCashedOut: hasCashedOut ?? this.hasCashedOut,
    );
  }
}

/// Settings for a cash game session.
///
/// `currency` and `rakePct` are kept for serialization compatibility but are
/// no longer surfaced in the UI: the primary interface hides currency symbols
/// (User Flow spec §3.4) and the minimal cash module has no rake (Tech §16.1).
class CashSessionSettings {
  const CashSessionSettings({
    required this.name,
    required this.date,
    required this.location,
    required this.smallBlind,
    required this.bigBlind,
    required this.minBuyIn,
    required this.maxBuyIn,
    this.currency = '',
    required this.maxPlayers,
    this.rakePct = 0,
    this.chipValue = 1,
    this.trackSettlement = true,
    this.chipSetId,
  });

  final String name;
  final String date;
  final String location;
  final double smallBlind;
  final double bigBlind;
  final double minBuyIn;
  final double maxBuyIn;
  final String currency;
  final int maxPlayers;
  final double rakePct;

  /// What one chip unit is worth in money, per session (D1): a chip marked 25
  /// is worth 25 x [chipValue]. Every stack x this = money.
  final double chipValue;

  /// D1 "Track settlement": auto-calculate who owes whom at the end.
  final bool trackSettlement;

  /// The chip set proposed for buy-in stacks; null = the default set.
  final String? chipSetId;
}

/// A running / completed cash game.
class CashSession {
  const CashSession({
    required this.id,
    required this.settings,
    this.isCompleted = false,
    required this.startTime,
    required this.players,
    this.unresolvedNote,
  });

  final String id;
  final CashSessionSettings settings;
  final bool isCompleted;
  final DateTime startTime;
  final List<CashPlayer> players;
  final String? unresolvedNote;

  double get totalInPlay => players.fold(0, (sum, p) => sum + p.stack);

  double get totalBuyIns => players.fold(0, (sum, p) => sum + p.totalBuyIns);

  double get totalCashedOut => players.fold(0, (sum, p) => sum + p.cashedOut);

  double get expectedInPlay => totalBuyIns - totalCashedOut;

  double get difference => (totalBuyIns - totalCashedOut) - totalInPlay;

  Duration get elapsed => DateTime.now().difference(startTime);

  CashSession copyWith({
    bool? isCompleted,
    List<CashPlayer>? players,
    String? unresolvedNote,
  }) {
    return CashSession(
      id: id,
      settings: settings,
      isCompleted: isCompleted ?? this.isCompleted,
      startTime: startTime,
      players: players ?? this.players,
      unresolvedNote: unresolvedNote ?? this.unresolvedNote,
    );
  }
}
