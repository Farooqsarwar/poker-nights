import 'package:poker_night/services/storage_service.dart';

class NotificationService {
  final StorageService _storage;
  bool _enabled = true;

  NotificationService(this._storage);

  bool get enabled => _enabled;

  Future<void> initialize() async {
    final stored = await _storage.getString('notifications_enabled');
    _enabled = stored != 'false';
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _storage.set('notifications_enabled', value);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_enabled) return;
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {}

  Future<void> cancelAll() async {}
}

