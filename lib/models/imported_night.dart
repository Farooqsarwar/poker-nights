/// One result row of an imported night (B12): either a group member
/// ([playerId] set) or someone who is not a member, kept as typed
/// ([guestName] set).
class ImportedEntry {
  const ImportedEntry({this.playerId, this.guestName});

  final String? playerId;
  final String? guestName;

  Map<String, dynamic> toMap() => {
        if (playerId != null) 'playerId': playerId,
        if (playerId == null && guestName != null) 'guestName': guestName,
      };

  static ImportedEntry fromMap(Map<String, dynamic> m) => ImportedEntry(
        playerId: m['playerId'] as String?,
        guestName: m['guestName'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ImportedEntry &&
      other.playerId == playerId &&
      other.guestName == guestName;

  @override
  int get hashCode => Object.hash(playerId, guestName);
}

/// A past night the host typed in (Build Spec v3.1 §B12), stored at
/// `groups/{gid}/importedNights/{id}`.
///
/// [entries] are in finishing order, winner first. Imported nights count in
/// the all-time standings and the season table but carry no knockouts, and a
/// guest row is never re-linked if that person later joins the group.
class ImportedNight {
  const ImportedNight({
    required this.id,
    required this.date,
    required this.entries,
  });

  final String id;

  /// `YYYY-MM-DD`.
  final String date;
  final List<ImportedEntry> entries;

  /// One night per date, so re-running an import can never duplicate a night.
  static String idForDate(String date) => 'night-$date';

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'entries': [for (final e in entries) e.toMap()],
      };

  static ImportedNight fromMap(String id, Map<String, dynamic> m) {
    final raw = m['entries'];
    return ImportedNight(
      id: id,
      date: (m['date'] as String?) ?? '',
      entries: [
        if (raw is List)
          for (final e in raw)
            if (e is Map) ImportedEntry.fromMap(Map<String, dynamic>.from(e)),
      ],
    );
  }
}
