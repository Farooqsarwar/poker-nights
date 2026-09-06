import re

file_path = 'lib/providers/app_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Change to Map<String, String>
content = re.sub(
    r'final Set<String> _pendingCheckIn = \{\};',
    r'final Map<String, String> _pendingCheckIn = {};',
    content
)

# 2. Delete _persistPendingCheckInToLocalStore
content = re.sub(
    r'  void _persistPendingCheckInToLocalStore\(\) \{.*?\n  \}\n\n',
    '',
    content,
    flags=re.DOTALL
)

# 3. Update requestCheckIn
content = re.sub(
    r'    _pendingCheckIn\.add\(playerId\);\n    _persistPendingCheckInToLocalStore\(\);',
    r"    final gameId = _currentGame?.id;\n    if (gameId != null) {\n      _pendingCheckIn[gameId] = playerId;\n      _persistPref('pendingCheckIn', _pendingCheckIn);\n    }",
    content
)

# 4. Update _loadUserPrefs
content = re.sub(
    r'      final savedPendingCheckIn = prefs\[\'pendingCheckIn\'\];\n      if \(savedPendingCheckIn is List\) \{\n        _pendingCheckIn\.addAll\(savedPendingCheckIn\.map\(\(e\) => e\.toString\(\)\)\);\n      \}',
    r"      final savedPendingCheckIn = prefs['pendingCheckIn'];\n      if (savedPendingCheckIn is Map) {\n        _pendingCheckIn.addAll(savedPendingCheckIn.cast<String, String>());\n      }",
    content
)

# 5. Update _withPendingCheckInOverlay
content = re.sub(
    r'  LiveGame _withPendingCheckInOverlay\(LiveGame game\) \{\n    if \(_pendingCheckIn\.isEmpty\) return game;\n    var updated = game;\n    final toRemove = <String>\{\};\n    final updatedPlayers = game\.players\.map\(\(p\) \{\n      if \(_pendingCheckIn\.contains\(p\.id\)\) \{',
    r'  LiveGame _withPendingCheckInOverlay(LiveGame game) {\n    if (_pendingCheckIn.isEmpty) return game;\n    var updated = game;\n    final toRemove = <String>{};\n    final updatedPlayers = game.players.map((p) {\n      if (_pendingCheckIn[game.id] == p.id) {',
    content
)
content = re.sub(
    r'    _pendingCheckIn\.removeAll\(toRemove\);',
    r'    for (var k in toRemove) _pendingCheckIn.remove(k);',
    content
)

# 6. Update _maybeReassertOwnCheckIn
content = re.sub(
    r'    if \(!_pendingCheckIn\.contains\(uid\)\) return;',
    r'    if (_pendingCheckIn[remote.id] != uid) return;',
    content
)
content = re.sub(
    r'      _pendingCheckIn\.remove\(uid\);\n      _persistPendingCheckInToLocalStore\(\);',
    r"      _pendingCheckIn.remove(remote.id);\n      _persistPref('pendingCheckIn', _pendingCheckIn);",
    content
)

# 7. Update _persistOwnCheckInPatch
content = re.sub(
    r'        if \(uid == null \|\| !_pendingCheckIn\.contains\(uid\)\) return;',
    r'        if (uid == null || _pendingCheckIn[gameId] != uid) return;',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
