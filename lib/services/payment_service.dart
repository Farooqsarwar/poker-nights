import 'package:flutter/foundation.dart';
import 'package:localstore/localstore.dart';

/// What the app got for its money.
///
/// Specification v11 §3 splits the product into a genuinely usable free tier
/// and a Premium tier that unlocks scale, intelligence and advanced control.
enum PremiumTier {
  free,
  premium;

  String get label => switch (this) {
    PremiumTier.free => 'Free',
    PremiumTier.premium => 'Premium',
  };
}

/// One purchasable plan.
class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    this.saving,
  });

  final String id;
  final String name;

  /// Displayed as-is. Specification §24 forbids currency symbols in the
  /// primary UI, so this carries the number and the period carries the unit.
  final String price;
  final String period;

  /// e.g. "Save 20%" — shown as a badge when present.
  final String? saving;

  /// Placeholder pricing.
  ///
  /// The specification defines WHAT is Premium (§3) but never states a price,
  /// a billing period, or who pays. These numbers exist so the screen can be
  /// designed and reviewed; they are not agreed pricing and must be replaced
  /// before any real billing is connected.
  static const placeholders = [
    PremiumPlan(
      id: 'monthly',
      name: 'Monthly',
      price: '5',
      period: 'per month',
    ),
    PremiumPlan(
      id: 'yearly',
      name: 'Yearly',
      price: '36',
      period: 'per year · \$3/mo',
      saving: 'Save 40%',
    ),
  ];
}

/// The result of attempting a purchase.
class PaymentResult {
  const PaymentResult.success(this.plan)
      : succeeded = true,
        message = null;
  const PaymentResult.failure(this.message)
      : succeeded = false,
        plan = null;

  final bool succeeded;
  final PremiumPlan? plan;
  final String? message;
}

/// The boundary every payment provider sits behind.
///
/// Keeping this as an interface is what makes the current mock disposable
/// without touching a single screen. Swapping in Stripe, Apple In-App Purchase
/// or Google Play Billing later means writing one new implementation, not
/// rewriting the upgrade flow.
///
/// Note for whoever connects real billing: Apple and Google both REQUIRE
/// digital subscriptions sold inside their apps to go through their own
/// billing, and both take a percentage. A single card-processor integration
/// covers the web only.
abstract class PaymentService {
  Future<PremiumTier> currentTier();
  Future<PaymentResult> purchase(PremiumPlan plan);

  /// Re-checks for an existing entitlement and returns what was found.
  ///
  /// Returning the tier rather than void is what lets the caller say
  /// something true afterwards. A restore that always reports "nothing
  /// found" while the user is sitting on a valid entitlement is worse
  /// than no restore button at all.
  Future<PremiumTier> restore();
  Future<void> cancel();
}

/// The one place that decides which [PaymentService] the app uses.
///
/// Until this existed, three call sites each constructed [MockPaymentService]
/// directly, so the interface bought nothing: connecting real billing would
/// have meant finding and editing every one of them, and missing one would
/// have left a screen quietly transacting against the mock.
///
/// Connecting a real provider is now a single assignment. Write a
/// [PaymentService] implementation, set [instance] once at startup, and every
/// screen follows -- no screen imports a concrete implementation.
///
/// It stays settable rather than final so a test can substitute a stub and
/// so the swap needs no rebuild of the widget tree.
abstract final class Payments {
  static PaymentService instance = MockPaymentService();

  /// Whether the live implementation actually moves money.
  ///
  /// Screens use this to decide whether to show the test-mode banner, so the
  /// banner cannot be left on a real checkout or off a simulated one -- it
  /// follows the implementation instead of being remembered.
  static bool get isSimulated => instance is MockPaymentService;
}

/// A local, non-transacting implementation of [PaymentService].
///
/// **This takes no money and contacts no payment provider.** It exists so the
/// upgrade and checkout screens can be built, reviewed and demonstrated while
/// the commercial terms — price, billing period, who pays, and whether Apple
/// and Google taking 15–30% is acceptable — are still being agreed.
///
/// The entitlement it grants is stored on this device only. It is deliberately
/// NOT synced to Firestore and NOT readable by security rules, so it cannot be
/// mistaken for a real entitlement or used to unlock anything server-side.
/// Specification v11 §7 and acceptance criterion 12 require Premium
/// authorization to be enforced on the server; this class does not attempt
/// that and must not be treated as satisfying it.
class MockPaymentService implements PaymentService {
  MockPaymentService({this.latency = const Duration(milliseconds: 1400)});

  /// Simulated round-trip, so the checkout screen's pending state is real
  /// enough to design against.
  final Duration latency;

  static final _db = Localstore.instance;
  static const _collection = 'entitlements';
  static const _docId = 'local';

  @override
  Future<PremiumTier> currentTier() async {
    try {
      final doc = await _db.collection(_collection).doc(_docId).get();
      final tier = doc?['tier'] as String?;
      return tier == 'premium' ? PremiumTier.premium : PremiumTier.free;
    } catch (e) {
      debugPrint('MockPaymentService: could not read entitlement: $e');
      return PremiumTier.free;
    }
  }

  @override
  Future<PaymentResult> purchase(PremiumPlan plan) async {
    await Future<void>.delayed(latency);
    try {
      await _db.collection(_collection).doc(_docId).set({
        'tier': 'premium',
        'planId': plan.id,
        'purchasedAt': DateTime.now().toIso8601String(),
        // Marked so nothing downstream can mistake this for a real purchase.
        'simulated': true,
      });
      return PaymentResult.success(plan);
    } catch (e) {
      debugPrint('MockPaymentService: could not store entitlement: $e');
      return const PaymentResult.failure(
        'Could not save your plan on this device.',
      );
    }
  }

  @override
  Future<PremiumTier> restore() async {
    await Future<void>.delayed(latency);
    return currentTier();
  }

  @override
  Future<void> cancel() async {
    try {
      await _db.collection(_collection).doc(_docId).delete();
    } catch (e) {
      debugPrint('MockPaymentService: could not clear entitlement: $e');
    }
  }
}
