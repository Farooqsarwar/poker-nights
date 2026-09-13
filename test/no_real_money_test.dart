import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The guarantee: **this application cannot take money.**
///
/// QA cases PN-DPAY-014 and PN-DPAY-015 ask for it, but a manual check only
/// proves it on the day somebody looks. A dependency added months from now
/// could quietly make the claim untrue, and nobody would notice until a real
/// card was charged.
///
/// So this asserts it structurally: no payment SDK is present, the payment
/// code makes no network calls, and nothing reaches a payment provider. If
/// someone adds real billing later these tests fail loudly, which is the
/// correct moment to revisit every "no money moves" statement in the product,
/// the documentation and the client's QA plan.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('PN-DPAY-014/015 — no payment provider is reachable', () {
    test('no payment SDK is a dependency', () {
      final pubspec = read('pubspec.yaml').toLowerCase();
      const paymentPackages = [
        'stripe',
        'in_app_purchase',
        'braintree',
        'paypal',
        'razorpay',
        'square',
        'adyen',
        'paytm',
        'flutterwave',
        'purchases_flutter', // RevenueCat
        'pay',
      ];
      final found = <String>[];
      for (final pkg in paymentPackages) {
        // Match a dependency line, not an incidental substring.
        if (RegExp('^\\s{2}$pkg\\s*:', multiLine: true).hasMatch(pubspec)) {
          found.add(pkg);
        }
      }
      expect(
        found,
        isEmpty,
        reason: 'a payment SDK is present: ${found.join(", ")}. The product '
            'claims in several places that no money can move — if that has '
            'changed, those claims need changing too',
      );
    });

    test('the payment service makes no network calls', () {
      final source = read('lib/services/payment_service.dart');
      for (final forbidden in [
        'http',
        'HttpClient',
        'Uri.parse',
        'Socket',
        'WebSocket',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: 'payment_service.dart references "$forbidden" — it must not '
              'talk to anything',
        );
      }
    });

    test('the payment sheet makes no network calls', () {
      final source = read('lib/widgets/dummy_payment_sheet.dart');
      for (final forbidden in ['http', 'HttpClient', 'Uri.parse']) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('the payment provider logic makes no network calls', () {
      final source = read('lib/providers/app_provider_payments.dart');
      for (final forbidden in ['http', 'HttpClient', 'Uri.parse']) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('the simulation announces itself', () {
    test('the checkout screen says no card is charged', () {
      final source = read('lib/screens/premium/checkout_screen.dart');
      expect(
        source.toLowerCase(),
        contains('no card is charged'),
        reason: 'a payment screen that looks real without saying it is a test '
            'is the thing app stores reject and users reasonably resent',
      );
    });

    test('the payment sheet says it is simulated', () {
      final source = read('lib/widgets/dummy_payment_sheet.dart');
      expect(source.toLowerCase(), contains('simulated'));
    });

    test('the stored entitlement is marked simulated', () {
      // So nothing downstream — support, an export, a future migration — can
      // mistake a demo grant for a purchase.
      final source = read('lib/services/payment_service.dart');
      expect(source, contains("'simulated': true"));
    });
  });

  group('the local entitlement cannot masquerade as a real one', () {
    test('it is stored on the device, never in Firestore', () {
      final source = read('lib/services/payment_service.dart');
      expect(
        source.contains('FirebaseFirestore'),
        isFalse,
        reason: 'a device-local demo flag written to Firestore would be '
            'indistinguishable from a real entitlement',
      );
    });

    test('production builds can switch the demo grant off', () {
      final source = read('lib/providers/app_provider.dart');
      expect(source, contains("bool.fromEnvironment('DEMO_PREMIUM'"));
    });

    test('the deploy script switches it off', () {
      final deploy = File('deploy.ps1');
      if (!deploy.existsSync()) {
        // Gitignored: it carries a secret. Skip rather than fail on a machine
        // that does not have it.
        return;
      }
      expect(
        deploy.readAsStringSync(),
        contains('DEMO_PREMIUM=false'),
        reason: 'the shipped build must not accept a device-local Premium flag',
      );
    });
  });
}
