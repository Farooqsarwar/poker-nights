class ApiConstants {
  ApiConstants._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String groupCodesTable = 'groups';
  static const String usersTable = 'users';
  static const String membershipsTable = 'group_memberships';
  static const String gamesTable = 'games';
  static const String participantsTable = 'participants';
  static const String guestsTable = 'guests';
  static const String chipSetsTable = 'chip_sets';
  static const String gameActionsTable = 'game_actions';
  static const String chatMessagesTable = 'chat_messages';
  static const String pollsTable = 'polls';
  static const String pollOptionsTable = 'poll_options';
  static const String pollVotesTable = 'poll_votes';
  static const String notificationsTable = 'notifications';
  static const String cashTransactionsTable = 'cash_transactions';
  static const String gameResultsTable = 'game_results';
  static const String tournamentStructuresTable = 'tournament_structures';
  static const String presetsTable = 'presets';
}
