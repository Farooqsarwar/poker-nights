import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

/// Elects a single leader among the browser tabs of this origin that are
/// looking at the SAME live game, using `BroadcastChannel` — no server
/// involved.
///
/// Firestore's `editorDeviceId` (see `app_provider_cloud_sync.dart`) already
/// arbitrates the single-writer role ACROSS physical devices. What it cannot
/// see is that `deviceId` is persisted per-ORIGIN storage, so every tab of
/// the same browser shares one device id and each independently believes it
/// holds the role. This class arbitrates WITHIN one browser: only the tab
/// elected leader for a given game id is allowed to claim/hold the editor
/// role, so a second tab on the same game becomes a genuine read-only
/// follower instead of a second writer that merely "converges" via
/// session-stamped writes.
///
/// The election needs no shared storage, only messages: every tab announces
/// itself and then heartbeats; the tab with the oldest `start` timestamp
/// still being heard from is the leader. A tab that goes quiet (closed,
/// crashed, or navigated away) drops out once its heartbeat goes stale, so
/// leadership always fails over rather than being lost permanently.
class TabLeader {
  TabLeader(String scope)
    : _channel = html.BroadcastChannel('poker_night_editor_lock:$scope') {
    _sub = _channel.onMessage.listen(_onMessage);
    _announce('hello');
    _heartbeat = Timer.periodic(_beatInterval, (_) => _announce('beat'));
    _prune = Timer.periodic(const Duration(seconds: 2), (_) => _pruneStale());
  }

  static const _beatInterval = Duration(seconds: 3);

  /// More than double the heartbeat interval, so one dropped message never
  /// falsely evicts a live peer.
  static const _staleAfter = Duration(seconds: 9);

  final html.BroadcastChannel _channel;
  late final StreamSubscription<html.MessageEvent> _sub;
  late final Timer _heartbeat;
  late final Timer _prune;
  bool _disposed = false;

  /// Unique for this tab's lifetime; never persisted, unlike the
  /// repository's device id — the whole point is to tell tabs of the same
  /// device apart.
  final String _id =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  final int _start = DateTime.now().millisecondsSinceEpoch;
  final Map<String, _Peer> _peers = {};

  /// True when this tab is the oldest surviving tab watching this game.
  bool get isLeader {
    var leaderId = _id;
    var leaderStart = _start;
    for (final entry in _peers.entries) {
      final p = entry.value;
      final older = p.start < leaderStart;
      final tie = p.start == leaderStart && entry.key.compareTo(leaderId) < 0;
      if (older || tie) {
        leaderId = entry.key;
        leaderStart = p.start;
      }
    }
    return leaderId == _id;
  }

  void _announce(String type) {
    if (_disposed) return;
    _channel.postMessage(jsonEncode({'t': type, 'id': _id, 'start': _start}));
  }

  void _onMessage(html.MessageEvent event) {
    try {
      final msg = jsonDecode(event.data as String) as Map<String, dynamic>;
      final id = msg['id'] as String?;
      if (id == null || id == _id) return;
      if (msg['t'] == 'bye') {
        _peers.remove(id);
        return;
      }
      _peers[id] = _Peer(
        start: (msg['start'] as num).toInt(),
        lastSeen: DateTime.now(),
      );
      if (msg['t'] == 'hello') {
        // Reply immediately so a just-opened tab learns about us without
        // waiting out a full heartbeat interval.
        _announce('beat');
      }
    } catch (_) {
      // Not a message this election protocol sent — ignore it.
    }
  }

  void _pruneStale() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    _peers.removeWhere((_, p) => p.lastSeen.isBefore(cutoff));
  }

  void dispose() {
    if (_disposed) return;
    _announce('bye');
    _disposed = true;
    _heartbeat.cancel();
    _prune.cancel();
    _sub.cancel();
    _channel.close();
  }
}

class _Peer {
  _Peer({required this.start, required this.lastSeen});
  final int start;
  final DateTime lastSeen;
}
