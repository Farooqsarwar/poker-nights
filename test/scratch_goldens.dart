
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/models/tournament_format.dart';

void main() {
  final chips = TournamentEngine.getPreset('Standard 500');
  
  final freezeOutParams = TournamentParams(
    players: 10,
    durationHours: 3.5,
    buyIn: 15,
    chipSet: chips,
    rebuys: false,
    format: TournamentFormat.freezeOut,
    rebuysCloseLevel: 6,
    addOn: false,
    anteEnabled: false, anteAfterLevel: 1, koAmount: 0, koEnabled: false, organizerPct: 0,
  );
  
  final rebuyParamsWithCostEqualToBuyIn = TournamentParams(
    players: 10,
    durationHours: 3.5,
    buyIn: 15,
    rebuyCost: 15,
    chipSet: chips,
    rebuys: true,
    format: TournamentFormat.rebuy,
    rebuysCloseLevel: 6,
    addOn: true,
    anteEnabled: false, anteAfterLevel: 1, koAmount: 0, koEnabled: false, organizerPct: 0,
  );
  
  final s1 = TournamentEngine.generate(freezeOutParams);
  final s2 = TournamentEngine.generate(rebuyParamsWithCostEqualToBuyIn);
  
  print('golden210FreezeOut = ${s1.levels.map((l) => [l.sb, l.bb]).toList()};');
  print('golden210Rebuy = ${s2.levels.map((l) => [l.sb, l.bb]).toList()};');
}
