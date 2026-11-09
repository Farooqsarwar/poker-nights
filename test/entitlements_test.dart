import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/services/entitlements.dart';
import 'package:poker_night/services/payment_service.dart';

/// v11 addendum §3, §4 and acceptance criteria 2 and 3.
void main() {
  group('acceptance #2 — free hosts a complete one-table tournament', () {
    for (final players in [2, 5, 8, 9]) {
      test('$players players is free', () {
        expect(Entitlements.canHost(PremiumTier.free, players), isTrue);
        expect(
          Entitlements.hostingBlockedReason(PremiumTier.free, players),
          isNull,
        );
      });
    }

    test('nine is the boundary, not eight', () {
      // The addendum is explicit: "Nine players is the clean boundary because
      // the current seating model is 1-9 = one table and 10 = 5+5."
      expect(Entitlements.freeMaxActivePlayers, 9);
      expect(Entitlements.canHost(PremiumTier.free, 9), isTrue);
      expect(Entitlements.canHost(PremiumTier.free, 10), isFalse);
    });

    test('ten or more needs Premium, and says why', () {
      final reason = Entitlements.hostingBlockedReason(PremiumTier.free, 12);
      expect(reason, isNotNull);
      expect(reason, contains('12'));
      expect(
        reason,
        contains('Premium'),
        reason: 'the host needs to know what lifts the limit',
      );
    });

    test('Premium hosts any field', () {
      for (final players in [10, 18, 40, 200]) {
        expect(Entitlements.canHost(PremiumTier.premium, players), isTrue);
        expect(
          Entitlements.hostingBlockedReason(PremiumTier.premium, players),
          isNull,
        );
      }
    });
  });

  group('acceptance #3 — group membership is NOT the free limit', () {
    test('nothing here caps group size', () {
      // The addendum moved the limit off membership deliberately: "Groups are
      // persistent communities and should support growth." A 50-member group
      // running a 9-player game is entirely free.
      expect(Entitlements.canHost(PremiumTier.free, 9), isTrue);
    });
  });

  group('§3 — the Premium feature list', () {
    test('allows() agrees with the declared tier for every feature', () {
      // Not every value in the enum is Premium — chip planning and the AI's
      // recommendations are ordinary tools, and D4's free column opens with
      // "every tool". So this asserts consistency per feature rather than
      // assuming the enum and the paywall are the same set. A new feature
      // added without a tier decision fails here.
      for (final f in PremiumFeature.values) {
        expect(
          Entitlements.allows(PremiumTier.premium, f),
          isTrue,
          reason: '$f must be open on Premium',
        );
        expect(
          Entitlements.allows(PremiumTier.free, f),
          f.requiresPremium ? isFalse : isTrue,
          reason: '$f is${f.requiresPremium ? '' : ' not'} behind the paywall',
        );
      }
    });

    test('the tools D4 calls free are not paywalled', () {
      // D4 free column: "every tool, one table, full level editing, ICM deal
      // suggestions, 3 saved templates/presets, basic standings." Neither of
      // these is a Premium-column item.
      expect(Entitlements.allows(
        PremiumTier.free,
        PremiumFeature.chipOptimisation,
      ), isTrue);
      expect(Entitlements.allows(
        PremiumTier.free,
        PremiumFeature.advancedAiRecommendations,
      ), isTrue);
    });

    test('a premium-only control stays closed on free', () {
      // The regression this guards: a free tier user tapping a Premium control
      // must be stopped, not let through.
      for (final f in [
        PremiumFeature.multiTable,
        PremiumFeature.seasons,
        PremiumFeature.bountyFormats,
        PremiumFeature.exportableHistory,
      ]) {
        expect(f.requiresPremium, isTrue, reason: '$f is Premium');
        expect(Entitlements.allows(PremiumTier.free, f), isFalse);
      }
    });

    test('every feature has a label for the upgrade prompt', () {
      for (final f in PremiumFeature.values) {
        expect(f.label, isNotEmpty);
      }
    });
  });
}
