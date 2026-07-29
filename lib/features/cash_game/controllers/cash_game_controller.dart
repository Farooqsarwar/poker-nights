import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/cash_game/models/cash_session_model.dart';
import 'package:poker_night/services/storage_service.dart';

class CashGameController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String _groupId;

  final RxList<CashSession> sessions = <CashSession>[].obs;
  final RxBool isLoading = true.obs;

  CashGameController(this._groupId);

  @override
  void onInit() {
    super.onInit();
    loadSessions();
  }
  Future<void> loadSessions() async {
    isLoading.value = true;
    final data = await _storage.getJson('cash_sessions_$_groupId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => CashSession.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    sessions.assignAll(list);
    isLoading.value = false;
  }

  Future<CashSession> createSession({
    required String name,
    required int smallBlind,
    required int bigBlind,
  }) async {
    final session = CashSession(
      id: const Uuid().v4(),
      groupId: _groupId,
      name: name,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      status: 'active',
      createdAt: DateTime.now(),
      players: [],
    );
    final updated = [...sessions, session];
    await _persist(updated);
    sessions.assignAll(updated);
    return session;
  }

  Future<void> addPlayer(String sessionId, String participantId, String name) async {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final session = sessions[idx];
    final player = CashPlayer(
      participantId: participantId,
      name: name,
      buyIn: 0,
      topUps: 0,
      cashOut: 0,
      status: 'active',
    );
    final updated = [...sessions]
      ..[idx] = session.copyWith(
        players: [...session.players, player],
        startedAt: session.startedAt ?? DateTime.now(),
      );
    await _persist(updated);
    sessions.assignAll(updated);
  }

  Future<void> recordBuyIn(String sessionId, String participantId, int amount) async {
    await _updatePlayer(sessionId, participantId, (p) => p.copyWith(
      buyIn: p.buyIn + amount,
    ));
  }

  Future<void> recordTopUp(String sessionId, String participantId, int amount) async {
    await _updatePlayer(sessionId, participantId, (p) => p.copyWith(
      topUps: p.topUps + amount,
    ));
  }

  Future<void> recordCashOut(String sessionId, String participantId, int amount) async {
    await _updatePlayer(sessionId, participantId, (p) => p.copyWith(
      cashOut: amount,
      status: 'cashed_out',
    ));
  }

  Future<void> closeSession(String sessionId) async {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final updated = [...sessions]
      ..[idx] = sessions[idx].copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );
    await _persist(updated);
    sessions.assignAll(updated);
  }

  Future<void> removePlayer(String sessionId, String participantId) async {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final session = sessions[idx];
    final updated = [...sessions]
      ..[idx] = session.copyWith(
        players: session.players.where((p) => p.participantId != participantId).toList(),
      );
    await _persist(updated);
    sessions.assignAll(updated);
  }

  Future<void> _updatePlayer(String sessionId, String participantId, CashPlayer Function(CashPlayer) update) async {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final session = sessions[idx];
    final pIdx = session.players.indexWhere((p) => p.participantId == participantId);
    if (pIdx < 0) return;
    final players = [...session.players];
    players[pIdx] = update(players[pIdx]);
    final updated = [...sessions]
      ..[idx] = session.copyWith(players: players);
    await _persist(updated);
    sessions.assignAll(updated);
  }

  Future<void> _persist(List<CashSession> sessionsList) async {
    await _storage.set('cash_sessions_$_groupId', {'items': sessionsList.map((e) => e.toJson()).toList()});
  }
}
