import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/mock_data.dart';

void main() {
  test('Guest flow works properly with auto-confirm', () {
    final app = AppProvider();
    
    // Create game with MockData.demoSettings (players: 8)
    final game = app.createGame(MockData.demoSettings);
    
    final initialActive = game.activePlayers.length;
    final initialChips = game.totalChipsInPlay;
    
    // We expect 8 placeholders (6 members, 2 generic)
    expect(initialActive, 8);
    expect(game.players.length, 8);
    
    // Member invites guest
    final inviter = game.players.first;
    
    // Guest requests check-in (auto-confirmed)
    app.requestGuestCheckIn('John Doe', inviter.id, 1);
    
    var updatedGame = app.currentGame!;
    expect(updatedGame.pendingGuests.length, 0);
    
    final confirmedGuest = updatedGame.players.firstWhere((p) => p.name == 'John Doe');
    expect(confirmedGuest.checkedIn, true);
    expect(confirmedGuest.confirmed, true);
    expect(confirmedGuest.active, true);
    
    // Verify a generic placeholder was removed (total players back to 8)
    expect(updatedGame.players.length, 8);
    expect(updatedGame.activePlayers.length, 8);
    
    // Now add another guest request
    app.requestGuestCheckIn('Jane Doe', inviter.id, 2);
    
    // Verify total players remains 8 because there were 2 generic placeholders
    updatedGame = app.currentGame!;
    expect(updatedGame.players.length, 8);
    
    // Now add a third guest request
    app.requestGuestCheckIn('Unexpected Guest', inviter.id, 3);
    
    // Verify total players is now 9, and active players is 9, and chips increased
    updatedGame = app.currentGame!;
    expect(updatedGame.players.length, 9);
    expect(updatedGame.activePlayers.length, 9);
    expect(updatedGame.totalChipsInPlay, initialChips + game.structure.startingStack);
  });
}
