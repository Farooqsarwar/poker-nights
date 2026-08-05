/// A participant in a cash game.
class CashPlayer {
  const CashPlayer({
    required this.id,
    required this.name,
    required this.stack,
    required this.totalBuyIns,
    required this.buyInCount,
    required this.cashedOut,
  });

  final String id;
  final String name;
  final double stack;
  final double totalBuyIns;
  final int buyInCount;
  final double cashedOut;

  bool get isCashedOut => cashedOut > 0;

  double get net => cashedOut - totalBuyIns;

  CashPlayer copyWith({
    double? stack,
    double? totalBuyIns,
    int? buyInCount,
    double? cashedOut,
  }) {
    return CashPlayer(
      id: id,
      name: name,
      stack: stack ?? this.stack,
      totalBuyIns: totalBuyIns ?? this.totalBuyIns,
      buyInCount: buyInCount ?? this.buyInCount,
      cashedOut: cashedOut ?? this.cashedOut,
    );
  }
}

/// Settings for a cash game session.
class CashSessionSettings {
  const CashSessionSettings({
    required this.name,
    required this.date,
    required this.location,
    required this.smallBlind,
    required this.bigBlind,
    required this.minBuyIn,
    required this.maxBuyIn,
    required this.currency,
    required this.maxPlayers,
    required this.rakePct,
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
}

/// A running / completed cash game.
class CashSession {
  const CashSession({
    required this.id,
    required this.settings,
    required this.isCompleted,
    required this.startTime,
    required this.players,
  });

  final String id;
  final CashSessionSettings settings;
  final bool isCompleted;
  final DateTime startTime;
  final List<CashPlayer> players;

  double get totalInPlay =>
      players.fold(0, (sum, p) => sum + p.stack);

  double get totalBuyIns =>
      players.fold(0, (sum, p) => sum + p.totalBuyIns);

  double get totalCashedOut =>
      players.fold(0, (sum, p) => sum + p.cashedOut);

  double get expectedInPlay => totalBuyIns - totalCashedOut;

  double get difference => (totalBuyIns - totalCashedOut) - totalInPlay;

  Duration get elapsed =>
      DateTime.now().difference(startTime);

  CashSession copyWith({
    bool? isCompleted,
    List<CashPlayer>? players,
  }) {
    return CashSession(
      id: id,
      settings: settings,
      isCompleted: isCompleted ?? this.isCompleted,
      startTime: startTime,
      players: players ?? this.players,
    );
  }
}

