import '../models/game.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';

/// Who a game projection is addressed to. Permissions must be enforced by the
/// backend (§22); this function is the single projection rule the future
/// server will run, and the mock applies it at the data-access boundary so the
/// interface never holds private fields for the wrong role (§2.3).
enum GameProjectionRole { admin, player, guest, tv }

const _noPrizesAmounts = 0;
const _noOrganizerAmount = 0;

/// Returns a copy of [game] safe for [role].
///
/// The admin projection is the full object. Player/guest/TV projections strip
/// private financial fields (organizer amount, individual payout amounts) and,
/// for guest/TV, the group chat. The public prize-pool total is preserved for
/// all roles.
LiveGame projectionFor(LiveGame game, GameProjectionRole role) {
  if (role == GameProjectionRole.admin) return game;

  final viewerCanSeeChat = role == GameProjectionRole.player;

  return game.copyWith(
    structure: game.structure.copyWith(
      organizerAmount: _noOrganizerAmount,
      prizes: [
        for (final p in game.structure.prizes)
          Prize(place: p.place, amount: _noPrizesAmounts),
      ],
    ),
    chat: viewerCanSeeChat ? game.chat : const <ChatMessage>[],
  );
}

/// The player projection (registered group member, event + group access).
LiveGame playerProjection(LiveGame game) =>
    projectionFor(game, GameProjectionRole.player);

/// The guest projection (event-only viewer; no chat, no private amounts).
LiveGame guestProjection(LiveGame game) =>
    projectionFor(game, GameProjectionRole.guest);

/// The TV projection (read-only presentation; no chat, no private amounts).
LiveGame tvProjection(LiveGame game) =>
    projectionFor(game, GameProjectionRole.tv);