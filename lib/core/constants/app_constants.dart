class AppConstants {
  AppConstants._();

  static const String appName = 'Poker Night';
  static const String version = '1.0.0';
  static const int maxGroupNameLength = 80;
  static const int maxTournamentNameLength = 80;
  static const int maxMessageLength = 500;
  static const int maxPlayersPerTable = 9;
  static const int minPlayers = 2;
  static const double defaultOrganizerPercentage = 0;
  static const int rsvpCutoffMinutes = 60;
  static const int rebuyDefaultCloseLevel = 6;
  static const int defaultLevelDuration = 15;
  static const List<int> levelDurationOptions = [10, 15, 20];
  static const List<double> targetDurationOptions = [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0];
  static const double defaultTargetDuration = 3.5;
  static const int payoutRoundTo = 10;
  static const int maxGuestSlots = 4;
  static const String joinCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int joinCodeLength = 6;
  static const String storageKeyGameState = 'poker_night_game_state';
  static const String storageKeyAuth = 'poker_night_auth';
  static const String storageKeySettings = 'poker_night_settings';
}
