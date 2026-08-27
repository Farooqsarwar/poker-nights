/// Configurable table-sizing/seating rules for tournaments (checklist §13.1
/// extension). Lives on [Group] as the default for every future tournament
/// that group runs, and can be overridden per tournament on [GameSettings].
class TableSettings {
  const TableSettings({
    this.maxPerTable = 10,
    this.randomizeByDefault = false,
  });

  /// Player count that triggers a split into another table once check-in
  /// reaches it (spec: configurable 10–11, defaulting to 10).
  final int maxPerTable;

  /// Whether seating generation defaults to the fully-random mode rather
  /// than the admin's last-used mode. The admin can still pick a different
  /// mode at generation time either way.
  final bool randomizeByDefault;

  static const TableSettings fallback = TableSettings();

  TableSettings copyWith({int? maxPerTable, bool? randomizeByDefault}) {
    return TableSettings(
      maxPerTable: maxPerTable ?? this.maxPerTable,
      randomizeByDefault: randomizeByDefault ?? this.randomizeByDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TableSettings &&
      other.maxPerTable == maxPerTable &&
      other.randomizeByDefault == randomizeByDefault;

  @override
  int get hashCode => Object.hash(maxPerTable, randomizeByDefault);
}
