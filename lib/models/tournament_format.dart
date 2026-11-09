enum TournamentFormat {
  freezeOut,
  rebuy,
  reEntry,
  shootout;

  String get label => switch (this) {
        TournamentFormat.freezeOut => 'Freeze Out',
        TournamentFormat.rebuy => 'Rebuy',
        TournamentFormat.reEntry => 'Re-entry',
        TournamentFormat.shootout => 'Shootout',
      };

  bool get hasLateChips =>
      this == TournamentFormat.rebuy || this == TournamentFormat.reEntry;
}
