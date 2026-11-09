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
  ///
  /// The members that are free are here too, and say so: §D-G is explicit that
  /// "the owner's rule (D4) is the whole list. Anything not named as Premium is
  /// free." A feature only reaches this switch as Premium if D4 names it.
  static bool allows(PremiumTier tier, PremiumFeature feature) =>
      feature.requiresPremium ? tier == PremiumTier.premium : true;
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
/// Everything else — anything D4 doesn't name either way — is free too, not a
/// judgement call: §D-G states that D4 is the whole list. The rows below are
/// transcribed from §D-G's free/premium table so a change to either can be
/// checked against it line by line.
///
/// | Feature | Free gets | Premium adds |
/// |---|---|---|
/// | Tables | One table (any size the host sets) | 2+ tables |
/// | Seating | All modes, TDA balancing | — (free per D4) |
/// | Structure | Full level editing | — (free per D4) |
/// | Payouts / ICM | Full ICM calculator, any payout shape | — (free per D4) |
/// | Chips | Unlimited sets, colour-up during play, colour-up planning | — (free per D4) |
/// | Templates | 3 saved | Unlimited |
/// | Cash games | Standings and settlement | — (free per D4) |
/// | TV | One read-only display | Customisation, multiple displays |
/// | Seasons | — | Seasons and points |
/// | Bounties | Fixed KO bounty | Progressive and Mystery bounties |
/// | Stats | Basic standings | Graphs and exportable history |
/// | AI | ICM calculator, pacing and recommendations | — (free per D4) |
abstract final class PremiumBoundary {
  /// Saved templates: 3 free, unlimited on Premium (D4).
  static const int freeMaxSavedPresets = 3;
}

/// The Premium column of D4, as a type — plus the members D4 leaves free, which
/// only need to be here because a call site asks [Entitlements.allows] and the
/// answer has to be somewhere.
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
  seasons,
  bountyFormats,
  exportableHistory;

  /// Short label for an upgrade prompt.
  String get label => switch (this) {
        PremiumFeature.multiTable => 'Multi-table tournaments',
        PremiumFeature.chipOptimisation => 'Chip optimisation and colour-ups',
        PremiumFeature.savedPresets => 'Unlimited saved templates',
        PremiumFeature.tvCustomisation => 'TV customisation',
        PremiumFeature.advancedAiRecommendations => 'Advanced AI recommendations',
        PremiumFeature.seasons => 'Seasons and points',
        PremiumFeature.bountyFormats => 'Progressive and Mystery bounties',
        PremiumFeature.exportableHistory => 'Graphs and exportable history',
      };

  /// Whether this feature is behind the paywall.
  ///
  /// Not every value here is Premium. Chip planning and the AI's
  /// recommendations are ordinary tools and D4's free column opens with "every
  /// tool" / "every public tool - the full tournament engine", so they ride in
  /// this enum for their labels and are open to everyone.
  ///
  /// Stating it here rather than in [Entitlements.allows] keeps the decision
  /// next to the feature, and lets the test assert a tier for every value
  /// instead of assuming the enum and the paywall are the same set.
  bool get requiresPremium => switch (this) {
        PremiumFeature.chipOptimisation => false,
        PremiumFeature.advancedAiRecommendations => false,
        _ => true,
      };
}
