import '../models/game.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../models/payment_record.dart';

/// Who a game projection is addressed to. Permissions must be enforced by the
/// backend (§22); this function is the single projection rule the future
/// server will run, and the mock applies it at the data-access boundary so the
/// interface never holds private fields for the wrong role (§2.3).
enum GameProjectionRole { admin, player, guest, tv }

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
  final publicSettings = GameSettings(
    name: game.settings.name,
    date: game.settings.date,
    time: game.settings.time,
    location: game.settings.location,
    players: game.settings.players,
    durationHours: game.settings.durationHours,
    buyIn: game.settings.buyIn,
    koEnabled: game.settings.koEnabled,
    koAmount: game.settings.koAmount,
    rebuys: game.settings.rebuys,
    rebuysCloseLevel: game.settings.rebuysCloseLevel,
    reEntry: game.settings.reEntry,
    addOn: game.settings.addOn,
    addOnCloseLevel: game.settings.addOnCloseLevel,
    anteEnabled: game.settings.anteEnabled,
    anteAfterLevel: game.settings.anteAfterLevel,
    anteStyle: game.settings.anteStyle,
    antePreference: game.settings.antePreference,
    organizerPct: 0,
    chipSet: game.settings.chipSet,
    chipSetName: game.settings.chipSetName,
    announceEliminations: game.settings.announceEliminations,
    forcePaidPlaces: null,
    rebuyCost: game.settings.rebuyCost,
    addOnCost: game.settings.addOnCost,
    locationPrivate: game.settings.locationPrivate,
  );

  // 14-045 / 05-033 / 19-021: players do not see their own investment either —
  // not their rebuys, re-entries or add-ons. The viewer used to be exempted
  // here, which left exactly the figures the checklist names as hidden sitting
  // in the member's own row.
  final publicPlayers = game.players
      .map(
        (p) => p.copyWith(
          rebuys: 0,
          reEntries: 0,
          hasAddOn: false,
          knockouts: 0,
        ),
      )
      .toList();

  // 17: Filter rebuyRequests / addOnRequests to viewer's own id for players; empty for guest/TV
  final publicRebuyRequests =
      role == GameProjectionRole.player && viewerId != null
      ? game.rebuyRequests.where((id) => id == viewerId).toList()
      : const <String>[];
  final publicAddOnRequests =
      role == GameProjectionRole.player && viewerId != null
      ? game.addOnRequests.where((id) => id == viewerId).toList()
      : const <String>[];

  // 15: Pending guest requests are kept for the guest role so a guest who
  // refreshes while waiting for admin approval can re-identify their own
  // (still pending) booking instead of being bounced to the entry screen.
  // Members see the pending row through players; TV needs it never. Private
  // counters are scrubbed exactly like the main players list.
  final publicPendingGuests = role == GameProjectionRole.guest
      ? [
          for (final p in game.pendingGuests)
            p.copyWith(rebuys: 0, reEntries: 0, hasAddOn: false, knockouts: 0),
        ]
      : const <Player>[];

  return game.copyWith(
    settings: publicSettings,
    structure: game.structure.copyWith(
      organizerAmount: _noOrganizerAmount,
      // The amounts do not travel at all. Zeroed `Prize` rows used to, and the
      // Firestore rules cannot iterate a list to confirm each one is 0 — so
      // the omission rested entirely on this function (19-019). An EMPTY list
      // plus a separate count is verifiable: `prizes.size() == 0`.
      prizes: const <Prize>[],
      paidPlaces: game.structure.prizes.length,
    ),
    players: publicPlayers,
    // Section 23: members and guests must not receive "rebuy/add-on totals"
    // or "gross collected". The player rows above are scrubbed of rebuys,
    // re-entries and add-ons for exactly that reason — and the payment ledger
    // hands all three straight back, plus the gross, to anyone who sums it.
    //
    // So it does not travel at all. Not even the viewer's own rows: the same
    // decision was already taken for their own investment a few lines up, and
    // a single record still reveals the buy-in amount alongside a player id.
    // The host sees the ledger; nobody else does.
    payments: const <PaymentRecord>[],
    chat: viewerCanSeeChat ? game.chat : const <ChatMessage>[],
    auditHistory: const <AuditRecord>[], // 14
    pendingGuests: publicPendingGuests,
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
