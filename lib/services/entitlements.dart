import 'payment_service.dart';

/// What the free tier allows (v11 addendum §3 and §4).
///
/// The addendum moved the free limit off group membership — "Do not cap Group
/// membership as the main free-tier limitation. Groups are persistent
/// communities and should support growth" — and onto *hosting*: free covers
/// one table, up to nine active players. Nine is the boundary because the
/// seating model is 1–9 on one table and 10 becomes 5+5.
///
/// **This is a user-experience gate, not enforcement.** Addendum §7 and
/// acceptance criterion 12 require Premium authorization to be enforced
/// server-side, and nothing here does that: the entitlement it reads is
/// device-local ([MockPaymentService]) and a determined user could bypass it
/// entirely. It exists so the limit is visible and the upgrade path is
/// designed; the real gate belongs in Cloud Functions or a backend, neither of
/// which is scoped or paid for yet.
abstract final class Entitlements {
  /// Free hosting covers one table. The addendum names nine explicitly.
  static const int freeMaxActivePlayers = 9;

  /// Whether this tier may host a tournament of [players].
  static bool canHost(PremiumTier tier, int players) =>
      tier == PremiumTier.premium || players <= freeMaxActivePlayers;

  /// Why not, in the words a host should see. Null when hosting is allowed.
  ///
  /// The addendum's monetization principle is explicit that the core clock,
  /// check-in and basic payouts are never paywalled — the upgrade reason is
  /// "more tables, more intelligence and more control". So this says what the
  /// limit is and what lifts it, rather than implying the app is crippled.
  static String? hostingBlockedReason(PremiumTier tier, int players) {
    if (canHost(tier, players)) return null;
    return 'Free hosting covers one table — up to $freeMaxActivePlayers '
        'players. This tournament has $players, which needs two tables. '
        'Premium unlocks multi-table hosting.';
  }

  /// Features the addendum §3 places behind Premium.
  ///
  /// Named rather than boolean so call sites read as a requirement rather than
  /// a magic flag, and so the list can be audited against §3 directly.
  static bool allows(PremiumTier tier, PremiumFeature feature) =>
      tier == PremiumTier.premium;
}

/// The Premium column of addendum §3, as a type.
enum PremiumFeature {
  multiTable,
  aiOptimisedStructures,
  advancedSeating,
  chipOptimisation,
  savedPresets,
  advancedPayoutsAndIcm,
  advancedCashGame,
  advancedStats,
  tvCustomisation,
  advancedAiRecommendations;

  /// Short label for an upgrade prompt.
  String get label => switch (this) {
        PremiumFeature.multiTable => 'Multi-table tournaments',
        PremiumFeature.aiOptimisedStructures => 'AI-optimised structures',
        PremiumFeature.advancedSeating => 'Advanced seating and balancing',
        PremiumFeature.chipOptimisation => 'Chip optimisation and colour-ups',
        PremiumFeature.savedPresets => 'Saved presets',
        PremiumFeature.advancedPayoutsAndIcm => 'Advanced payouts and ICM',
        PremiumFeature.advancedCashGame => 'Advanced cash games',
        PremiumFeature.advancedStats => 'Advanced stats and exports',
        PremiumFeature.tvCustomisation => 'TV customisation',
        PremiumFeature.advancedAiRecommendations => 'Advanced AI recommendations',
      };
}
