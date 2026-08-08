import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/mock_data.dart';

void main() {
  test('Guest flow: request waits for admin confirmation, then seats them', () {
    final app = AppProvider();

    // Create game with MockData.demoSettings (players: 8)
    final game = app.createGame(MockData.demoSettings);

    expect(game.players.length, 8);
    expect(game.activePlayers.length, 8);
    final initialChips = game.totalChipsInPlay;

    // Member invites guest
    final inviter = game.players.first;

    // Guest requests check-in — stays pending for host approval (spec §6)
    app.requestGuestCheckIn('John Doe', inviter.id, 1);

    var updatedGame = app.currentGame!;
    expect(updatedGame.pendingGuests.length, 1);

    final pendingGuest = updatedGame.players.firstWhere((p) => p.name == 'John Doe');
    expect(pendingGuest.checkedIn, false);
    expect(pendingGuest.confirmed, false);
    expect(pendingGuest.active, false);

    // Admin confirms the request
    app.confirmGuest(pendingGuest.id);

    updatedGame = app.currentGame!;
    expect(updatedGame.pendingGuests.length, 0);

    // Placeholder replaced so player count stays at 8, no extra chips
    final confirmedGuest = updatedGame.players.firstWhere((p) => p.name == 'John Doe');
    expect(confirmedGuest.checkedIn, true);
    expect(confirmedGuest.confirmed, true);
    expect(confirmedGuest.active, true);
    expect(updatedGame.players.length, 8);
    expect(updatedGame.activePlayers.length, 8);
    // Placeholder replaced — total chips in play is unchanged.
    expect(updatedGame.totalChipsInPlay, initialChips);
  });

  test('Guest flow: rejected guest is removed and slot freed', () {
    final app = AppProvider();
    final game = app.createGame(MockData.demoSettings);
    final inviter = game.players.first;

    app.requestGuestCheckIn('Jane Doe', inviter.id, 1);

    var updated = app.currentGame!;
    final pending = updated.pendingGuests.first;
    final slotBefore = updated.guestSlots
        .firstWhere((s) => s.inviterId == inviter.id && s.slot == 1);
    expect(slotBefore.status, GuestSlotStatus.reserved);

    app.rejectGuest(pending.id);

    updated = app.currentGame!;
    expect(updated.pendingGuests.length, 0);
    expect(updated.players.where((p) => p.name == 'Jane Doe'), isEmpty);
    final slotAfter = updated.guestSlots
        .firstWhere((s) => s.inviterId == inviter.id && s.slot == 1);
    expect(slotAfter.status, GuestSlotStatus.unclaimed);
  });

  test('Guest flow: two confirmed guests still fit within expected players', () {
    final app = AppProvider();
    final game = app.createGame(MockData.demoSettings);
    final inviter = game.players.first;

    app.requestGuestCheckIn('John Doe', inviter.id, 1);
    app.requestGuestCheckIn('Jane Doe', inviter.id, 2);

    var updated = app.currentGame!;
    expect(updated.pendingGuests.length, 2);

    // Confirm both
    for (final p in updated.pendingGuests.toList()) {
      app.confirmGuest(p.id);
    }

    updated = app.currentGame!;
    expect(updated.pendingGuests.length, 0);
    // Two placeholders were replaced; two confirmed guests are active.
    expect(updated.players.where((p) => p.isGuest && p.confirmed).length, 2);
  });
}
