import 'dart:async';
import 'package:poker_night/services/storage_service.dart';

class RealtimeService {
  final StorageService _storage;
  final Map<String, List<StreamSubscription<dynamic>>> _subscriptions = {};
  bool _isConnected = false;

  RealtimeService(this._storage);

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    _isConnected = true;
  }

  Future<void> disconnect() async {
    for (final subs in _subscriptions.values) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
    _subscriptions.clear();
    _isConnected = false;
  }

  void subscribe(String channel, void Function(Map<String, dynamic>) onData) {
    _subscriptions.putIfAbsent(channel, () => []);
  }

  void unsubscribe(String channel) {
    final subs = _subscriptions.remove(channel);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
  }

  Future<void> broadcast(String channel, Map<String, dynamic> payload) async {
    final key = 'realtime_$channel';
    final existing = await _storage.getJson(key);
    final messages = (existing?['messages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    messages.add({...payload, 'timestamp': DateTime.now().toIso8601String()});
    await _storage.set(key, {'messages': messages});
  }

  Future<List<Map<String, dynamic>>> getHistory(String channel) async {
    final data = await _storage.getJson('realtime_$channel');
    return (data?['messages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  }

  void dispose() {
    for (final subs in _subscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
  }
}

