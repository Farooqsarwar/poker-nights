import '../models/game.dart';
import '../models/live_game.dart';
import '../models/payment_record.dart';

/// Who a game projection is addressed to. Permissions must be enforced by the
/// backend (§22); this function is the single projection rule the future
/// server will run, and the mock applies it at the data-access boundary so the
/// interface never holds private fields for the wrong role (§2.3).
enum GameProjectionRole { admin, coHost, player, guest, tv }

const _noOrganizerAmount = 0;

/// Returns a copy of [game] safe for [role].
///
/// The admin projection is the full object. Player/guest/TV projections strip
/// private financial fields (the organiser's own contribution, individual
/// buy-in and rebuy figures) and, for guest/TV, the group chat. The public
/// prize-pool total and the payout ladder itself are preserved for all roles
/// (D2).
LiveGame projectionFor(
  LiveGame game,
  GameProjectionRole role, {
  String? viewerId,
}) {
  if (role == GameProjectionRole.admin) return game;

  final viewerCanSeeChat = role == GameProjectionRole.player;

  // 12, 13: Zero organizerPct and clear forcePaidPlaces for non-admin.
  //
  // This used to be a full manual `GameSettings(...)` reconstruction that
  // named every field individually — which means every field NOT named
  // silently dropped to its default (usually null) for every player, guest
  // and TV viewer, rather than riding through untouched. `format` was the
  // field that got caught doing this; the fix is structural, not another
  // field added to a list that will just go stale again next time: `copyWith`
  // makes "public by default, private fields listed explicitly" the actual
  // behaviour, matching this function's own doc comment above. Only the two
  // fields §6.2's table marks private are named here.
  // A2-1's overtime flag says the host is behind on settlement. It lives on
  // `GameSettings`, so it is zeroed here with the other money terms rather
  // than in the `LiveGame` copyWith below. Nothing a member reads needs it.
  final publicSettings = game.settings.copyWith(
    organizerPct: 0,
    clearForcePaidPlaces: true,
    addOnOvertime: false,
  );

  // Spec E6: Preserve rebuys and knockouts for player rankings and podium counts.
  // Players do not see other players' re-entries or add-ons.
  final publicPlayers = game.players
      .map(
        (p) => p.copyWith(
          reEntries: 0,
          hasAddOn: false,
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
            p.copyWith(reEntries: 0, hasAddOn: false),
        ]
      : const <Player>[];

  return game.copyWith(
    settings: publicSettings,
    structure: game.structure.copyWith(
      organizerAmount: _noOrganizerAmount,
      // D2: the payout ladder is PUBLIC. "Everyone - players, guests, the TV -
      // sees the prize pool and the payouts", and line 207 rejects the older
      // board rule that hid the amounts from everyone but the admin. This list
      // used to be emptied for every non-admin role, which left each player,
      // guest and the TV looking at a blank ladder. The organiser's own
      // contribution is the one figure that stays behind, above.
      prizes: game.structure.prizes,
      paidPlaces: game.structure.prizes.length,
    ),
    players: publicPlayers,
    // Spec E6: Preserve the viewer's own payment rows rather than emptying the ledger completely.
    payments: viewerId != null
        ? game.payments.where((p) => p.playerId == viewerId).toList()
        : const <PaymentRecord>[],
    // An agreed deal (C-deal) is what each NAMED person actually received,
    // which is the host-only decision the results screen already makes for
    // individual payouts ("showAmounts = app.isAdmin") — not the public
    // ladder, which the whole table is entitled to see. It sits alongside
    // `payments` rather than with `structure.prizes` for that reason: a deal
    // reveals the size of each person's win, and §23's pattern is that a
    // single amount plus a player id is the thing that must not travel.
    dealAmounts: null,
    clearDealAmounts: true,
    chat: viewerCanSeeChat ? game.chat : const <ChatMessage>[],
    auditHistory: const <AuditRecord>[], // 14
    // A2-1's declined half: who said no to spending their own money is
    // per-person financial intent, so it sits with the request queues rather
    // than in the member-readable document. The overtime half is zeroed on
    // `publicSettings` above. The visible badge is rendered from the admin's
    // own copy, not a member's.
    addOnDeclined: const <String>[],
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
