import 'dart:math';
import 'package:get/get.dart';
import 'package:poker_night/services/storage_service.dart';

class SeatInfo {
  final int seatNumber;
  String? playerId;
  String? playerName;
  bool get isEmpty => playerId == null;

  SeatInfo({required this.seatNumber, this.playerId, this.playerName});
}

class TableInfo {
  final int tableNumber;
  final List<SeatInfo> seats;
  final int seatsPerTable;

  TableInfo({required this.tableNumber, required this.seatsPerTable})
      : seats = List.generate(seatsPerTable, (i) => SeatInfo(seatNumber: i + 1));

  int get occupiedCount => seats.where((s) => !s.isEmpty).length;
  int get emptyCount => seats.where((s) => s.isEmpty).length;
}

class SeatingState {
  final List<TableInfo> tables;
  final int seatsPerTable;
  final int? dealerPosition;

  SeatingState({required this.tables, required this.seatsPerTable, this.dealerPosition});
}

class SeatingController extends GetxController {
  final StorageService _storage;
  final String _gameId;
  static const int _defaultSeatsPerTable = 9;

  late final Rx<SeatingState> rxState;

  SeatingState get state => rxState.value;
  set state(SeatingState val) => rxState.value = val;

  SeatingController(this._storage, this._gameId) {
    rxState = SeatingState(tables: [], seatsPerTable: _defaultSeatsPerTable, dealerPosition: null).obs;
  }

  Future<void> loadSeating() async {
    final data = await _storage.getJson('seating_$_gameId');
    if (data == null) return;
    final tablesData = data['tables'] as List<dynamic>?;
    if (tablesData == null) return;
    final tables = tablesData.map((t) {
      final map = t as Map<String, dynamic>;
      final tableNo = map['tableNumber'] as int;
      final seatsData = map['seats'] as List<dynamic>;
      final table = TableInfo(tableNumber: tableNo, seatsPerTable: map['seatsPerTable'] as int? ?? _defaultSeatsPerTable);
      for (final s in seatsData) {
        final seatMap = s as Map<String, dynamic>;
        final seatNo = seatMap['seatNumber'] as int;
        final seat = table.seats.firstWhere((s) => s.seatNumber == seatNo);
        seat.playerId = seatMap['playerId'] as String?;
        seat.playerName = seatMap['playerName'] as String?;
      }
      return table;
    }).toList();
    state = SeatingState(tables: tables, seatsPerTable: data['seatsPerTable'] as int? ?? _defaultSeatsPerTable, dealerPosition: data['dealerPosition'] as int?);
  }

  void initializeTables(int playerCount, {int seatsPerTable = _defaultSeatsPerTable}) {
    final tableCount = ((playerCount - 1) ~/ seatsPerTable) + 1;
    final tables = List.generate(tableCount, (i) => TableInfo(tableNumber: i + 1, seatsPerTable: seatsPerTable));
    final dealer = tableCount == 1 ? Random().nextInt(seatsPerTable) + 1 : null;
    state = SeatingState(tables: tables, seatsPerTable: seatsPerTable, dealerPosition: dealer);
    _persist();
  }

  void autoSeat(List<Map<String, String>> players) {
    final shuffled = List<Map<String, String>>.from(players)..shuffle(Random());
    final tables = state.tables;
    int playerIdx = 0;
    for (final table in tables) {
      for (final seat in table.seats) {
        if (playerIdx >= shuffled.length) break;
        seat.playerId = shuffled[playerIdx]['id'];
        seat.playerName = shuffled[playerIdx]['name'];
        playerIdx++;
      }
    }
    rxState.refresh();
    _persist();
  }

  void assignSeat(int tableNo, int seatNo, String playerId, String playerName) {
    final table = state.tables.firstWhere((t) => t.tableNumber == tableNo);
    final seat = table.seats.firstWhere((s) => s.seatNumber == seatNo);
    seat.playerId = playerId;
    seat.playerName = playerName;
    state = SeatingState(tables: state.tables, seatsPerTable: state.seatsPerTable, dealerPosition: state.dealerPosition);
    _persist();
  }

  void removePlayer(int tableNo, int seatNo) {
    final table = state.tables.firstWhere((t) => t.tableNumber == tableNo);
    final seat = table.seats.firstWhere((s) => s.seatNumber == seatNo);
    seat.playerId = null;
    seat.playerName = null;
    state = SeatingState(tables: state.tables, seatsPerTable: state.seatsPerTable, dealerPosition: state.dealerPosition);
    _persist();
  }

  void assignDealer(int seatNo) {
    state = SeatingState(tables: state.tables, seatsPerTable: state.seatsPerTable, dealerPosition: seatNo);
    _persist();
  }

  void autoSeatWithGuests(List<Map<String, String>> players, List<Map<String, String>> guests) {
    final allPlayers = List<Map<String, String>>.from(players)..shuffle(Random());
    final guestsByInviter = <String, List<Map<String, String>>>{};
    for (final g in guests) {
      final inviterId = g['inviterId'] ?? '';
      guestsByInviter.putIfAbsent(inviterId, () => []).add(g);
    }
    final seated = <String>{};
    final tables = state.tables;
    int tableIdx = 0;
    for (final p in allPlayers) {
      if (seated.contains(p['id'])) continue;
      _seatAtTable(tables, tableIdx, p, seated);
      final myGuests = guestsByInviter[p['id']] ?? [];
      for (final g in myGuests) {
        _seatAtTable(tables, tableIdx, g, seated);
      }
      tableIdx = (tableIdx + 1) % tables.length;
    }
    for (final g in guests) {
      if (!seated.contains(g['id'])) {
        _seatAtTable(tables, tableIdx, g, seated);
        tableIdx = (tableIdx + 1) % tables.length;
      }
    }
    state = SeatingState(tables: tables, seatsPerTable: state.seatsPerTable, dealerPosition: state.dealerPosition);
    _persist();
  }

  void _seatAtTable(List<TableInfo> tables, int tableIdx, Map<String, String> p, Set<String> seated) {
    final table = tables[tableIdx % tables.length];
    final empty = table.seats.where((s) => s.isEmpty).toList();
    if (empty.isEmpty) {
      for (int t = 0; t < tables.length; t++) {
        final altTable = tables[t];
        final altEmpty = altTable.seats.where((s) => s.isEmpty).toList();
        if (altEmpty.isNotEmpty) {
          altEmpty.first.playerId = p['id'];
          altEmpty.first.playerName = p['name'];
          seated.add(p['id'] ?? '');
          return;
        }
      }
      return;
    }
    empty.first.playerId = p['id'];
    empty.first.playerName = p['name'];
    seated.add(p['id'] ?? '');
  }

  List<Map<String, dynamic>> balanceTables() {
    final tables = state.tables;
    if (tables.length < 2) return [];

    final moves = <Map<String, dynamic>>[];
    final avgPerTable = tables.fold(0, (s, t) => s + t.occupiedCount) ~/ tables.length;

    for (int i = 0; i < tables.length; i++) {
      while (tables[i].occupiedCount > avgPerTable + 1) {
        final over = tables[i];
        final seatToMove = over.seats.firstWhere((s) => !s.isEmpty);
        for (int j = 0; j < tables.length; j++) {
          if (i == j) continue;
          if (tables[j].occupiedCount < avgPerTable) {
            final target = tables[j];
            final emptySeat = target.seats.firstWhere((s) => s.isEmpty);
            moves.add({
              'playerId': seatToMove.playerId,
              'playerName': seatToMove.playerName,
              'fromTable': over.tableNumber,
              'fromSeat': seatToMove.seatNumber,
              'toTable': target.tableNumber,
              'toSeat': emptySeat.seatNumber,
            });
            emptySeat.playerId = seatToMove.playerId;
            emptySeat.playerName = seatToMove.playerName;
            seatToMove.playerId = null;
            seatToMove.playerName = null;
            break;
          }
        }
      }
    }
    state = SeatingState(tables: tables, seatsPerTable: state.seatsPerTable, dealerPosition: state.dealerPosition);
    _persist();
    return moves;
  }

  Map<int, List<Map<String, String?>>> getSeatingMap() {
    final result = <int, List<Map<String, String?>>>{};
    for (final table in state.tables) {
      result[table.tableNumber] = table.seats.map((s) => {
        'seatNo': s.seatNumber.toString(),
        'playerId': s.playerId,
        'playerName': s.playerName,
      }).toList();
    }
    return result;
  }

  void redrawFinalTable(List<Map<String, String>> finalists) {
    initializeTables(finalists.length, seatsPerTable: finalists.length);
    autoSeat(finalists);
    assignDealer(Random().nextInt(finalists.length) + 1);
  }

  void _persist() {
    final data = {
      'seatsPerTable': state.seatsPerTable,
      'dealerPosition': state.dealerPosition,
      'tables': state.tables.map((t) => {
        'tableNumber': t.tableNumber,
        'seatsPerTable': t.seatsPerTable,
        'seats': t.seats.map((s) => {
          'seatNumber': s.seatNumber,
          'playerId': s.playerId,
          'playerName': s.playerName,
        }).toList(),
      }).toList(),
    };
    _storage.set('seating_$_gameId', data);
  }
}
