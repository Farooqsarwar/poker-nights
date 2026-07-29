import 'dart:async';
import 'package:poker_night/services/storage_service.dart';

class SyncService {
  final StorageService _storage;
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._storage);

  bool get isSyncing => _isSyncing;

  Future<void> startAutoSync({Duration interval = const Duration(seconds: 30)}) async {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncAll());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _syncGameStates();
      await _syncChatMessages();
      await _syncPolls();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncGameStates() async {}
  Future<void> _syncChatMessages() async {}
  Future<void> _syncPolls() async {}

  Future<void> markPending(String key, Map<String, dynamic> data) async {
    final pending = await _storage.getJson('sync_pending');
    final items = (pending?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    items.add({'key': key, 'data': data, 'timestamp': DateTime.now().toIso8601String()});
    await _storage.set('sync_pending', {'items': items});
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final pending = await _storage.getJson('sync_pending');
    return (pending?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> clearPending(String key) async {
    final pending = await _storage.getJson('sync_pending');
    final items = (pending?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    items.removeWhere((i) => i['key'] == key);
    await _storage.set('sync_pending', {'items': items});
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}

