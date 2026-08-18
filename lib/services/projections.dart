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
LiveGame projectionFor(
  LiveGame game,
  GameProjectionRole role, {
  String? viewerId,
}) {
  if (role == GameProjectionRole.admin) return game;

  final viewerCanSeeChat = role == GameProjectionRole.player;

  // 12, 13: Zero organizerPct and clear forcePaidPlaces for non-admin
  final publicSettings = game.settings.copyWith(
    organizerPct: 0,
    forcePaidPlaces: null,
  );

  // 16: Zero other players' rebuys / reEntries / hasAddOn / knockouts except viewer's own record (registered member only)
  final publicPlayers = game.players.map((p) {
    final isViewer = role == GameProjectionRole.player && viewerId != null && p.id == viewerId;
    if (isViewer) return p;
    return p.copyWith(
      rebuys: 0,
      reEntries: 0,
      hasAddOn: false,
      knockouts: 0,
    );
  }).toList();

  // 17: Filter rebuyRequests / addOnRequests to viewer's own id for players; empty for guest/TV
  final publicRebuyRequests = role == GameProjectionRole.player && viewerId != null
      ? game.rebuyRequests.where((id) => id == viewerId).toList()
      : const <String>[];
  final publicAddOnRequests = role == GameProjectionRole.player && viewerId != null
      ? game.addOnRequests.where((id) => id == viewerId).toList()
      : const <String>[];

  return game.copyWith(
    settings: publicSettings,
    structure: game.structure.copyWith(
      organizerAmount: _noOrganizerAmount,
      prizes: [
        for (final p in game.structure.prizes)
          Prize(place: p.place, amount: _noPrizesAmounts),
      ],
    ),
    players: publicPlayers,
    chat: viewerCanSeeChat ? game.chat : const <ChatMessage>[],
    auditHistory: const <AuditRecord>[], // 14
    pendingGuests: const <Player>[], // 15
    rebuyRequests: publicRebuyRequests,
    addOnRequests: publicAddOnRequests,
  );
}

/// The player projection (registered group member, event + group access).
LiveGame playerProjection(LiveGame game, {String? viewerId}) =>
    projectionFor(game, GameProjectionRole.player, viewerId: viewerId);

/// The guest projection (event-only viewer; no chat, no private amounts).
LiveGame guestProjection(LiveGame game) =>
    projectionFor(game, GameProjectionRole.guest);

/// The TV projection (read-only presentation; no chat, no private amounts).
LiveGame tvProjection(LiveGame game) =>
    projectionFor(game, GameProjectionRole.tv);