import 'payment_service.dart';

/// What the free tier allows (specification v3.1, decisions D4 and D5).
///
/// D4 moved the free limit off group membership — "Do not cap Group
/// membership as the main free-tier limitation. Groups are persistent
/// communities and should support growth" — and onto *hosting*. D5 puts the
/// line at the *second table*, not at a head count: free covers one table,
/// however many seats the host has given it. Nine is only the default table
/// size (the seating model is 1–9 on one table and 10 becomes 5+5).
///
/// **This is a user-experience gate, not enforcement.** The entitlement it
/// reads is device-local ([MockPaymentService]) and a determined user could
/// bypass it entirely. Server-side enforcement needs a backend that is not
/// scoped or paid for yet, so the security rules no longer pretend to cap
/// seats either.
abstract final class Entitlements {
  /// The default table size, and so the default free field.
  static const int freeMaxActivePlayers = 9;

  /// Whether this tier may host [players] on the host's own table size
  /// ([maxPerTable]) -- that is, whether the field still fits one table.
  static bool canHost(
    PremiumTier tier,
    int players, {
    int maxPerTable = freeMaxActivePlayers,
  }) => tier == PremiumTier.premium || players <= maxPerTable;

  /// Why not, in the words a host should see. Null when hosting is allowed.
  ///
  /// D4's monetization principle is explicit that the core clock, check-in
  /// and basic payouts are never paywalled — the upgrade reason is "more
  /// tables, more intelligence and more control". So this says what the limit
  /// is and what lifts it, rather than implying the app is crippled.
  static String? hostingBlockedReason(
    PremiumTier tier,
    int players, {
    int maxPerTable = freeMaxActivePlayers,
  }) {
    if (canHost(tier, players, maxPerTable: maxPerTable)) return null;
    return 'Free hosting covers one table — up to $maxPerTable '
        'players. This tournament has $players, which needs a second table. '
        'Premium unlocks more than one table.';
  }

  /// Features D4 places behind Premium.
  ///
  /// Named rather than boolean so call sites read as a requirement rather than
  /// a magic flag, and so the list can be audited against D4 directly.
  static bool allows(PremiumTier tier, PremiumFeature feature) =>
      tier == PremiumTier.premium;
}

/// Where "basic" ends and "advanced" begins.
///
/// D4 is explicit that the following are free, without limit: the ICM
/// calculator and deals, one TV display, unlimited tournaments, sync and full
/// level editing, rebuys/add-ons/busts, seating (including TDA balancing),
/// unlimited chip sets, basic standings and cash games. Premium is named as:
/// 2+ tables, seasons and points, custom TV layouts and more displays,
/// progressive/mystery bounties, unlimited saved templates (3 free), and
/// graphs/exportable history.
///
/// Everything else — anything D4 doesn't name either way — is a judgement,
/// not a requirement, gathered here and named so the product owner can move
/// any of them without hunting through screens.
///
/// | Feature | Free gets | Premium adds |
/// |---|---|---|
/// | Tables | One table (any size the host sets) | 2+ tables |
/// | Seating | All modes, TDA balancing | — (free per D4) |
/// | Structure | Full level editing | — (free per D4) |
/// | Payouts / ICM | Full ICM calculator, any payout shape | — (free per D4) |
/// | Chips | Unlimited sets, colour-up during play | Colour-up optimisation/planning |
/// | Templates | 3 saved | Unlimited |
/// | Cash games | Standings and settlement | — (free per D4) |
/// | TV | One read-only display | Customisation, multiple displays |
/// | Seasons | — | Seasons and points |
/// | Bounties | — | Progressive and Mystery bounties |
/// | Stats | Basic standings | Graphs and exportable history |
/// | AI | ICM calculator itself is free | Structure pacing / advanced insight |
abstract final class PremiumBoundary {
  /// Saved templates: 3 free, unlimited on Premium (D4).
  static const int freeMaxSavedPresets = 3;
}

/// The Premium column of D4, as a type.
///
/// `advancedCashGame` and `advancedStats` were removed: D4 names cash games
/// and basic standings as free with no "advanced" cash-game split, and the
/// stats/export upsell (see `stats_screen.dart`) is a static blurb, not a
/// gate — there was no live call site for either member.
enum PremiumFeature {
  multiTable,
  chipOptimisation,
  savedPresets,
  tvCustomisation,
  advancedAiRecommendations,
  seasons;

  /// Short label for an upgrade prompt.
  String get label => switch (this) {
        PremiumFeature.multiTable => 'Multi-table tournaments',
        PremiumFeature.chipOptimisation => 'Chip optimisation and colour-ups',
        PremiumFeature.savedPresets => 'Unlimited saved templates',
        PremiumFeature.tvCustomisation => 'TV customisation',
        PremiumFeature.advancedAiRecommendations => 'Advanced AI recommendations',
        PremiumFeature.seasons => 'Seasons and points',
      };
}
