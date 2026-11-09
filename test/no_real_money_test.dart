import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/services/payment_service.dart';

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
    test('the checkout screen discloses that nothing is charged', () {
      final source = read('lib/screens/premium/checkout_screen.dart');
      final lower = source.toLowerCase();
      // The screen's exact wording is "Demo - nothing is charged and no card
      // is needed" (and a matching line on the success state), so assert the
      // two things that matter — that nothing is charged, and that no card is
      // taken — rather than one brittle phrase that a copy edit would break.
      expect(
        lower,
        anyOf(contains('nothing is charged'), contains('no card is charged')),
        reason: 'the screen must say that no money moves',
      );
      expect(
        lower,
        anyOf(contains('no card is needed'), contains('no card is taken')),
        reason: 'the screen must say it does not take card details',
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

  group('the live implementation is the simulated one', () {
    test('Payments.instance is the mock, and says so', () {
      // The single seam real billing would arrive through. If somebody wires
      // a provider in, this fails -- which is the point: it should be a
      // deliberate, visible change, not something that lands unnoticed.
      expect(Payments.isSimulated, isTrue);
      expect(Payments.instance, isA<MockPaymentService>());
    });

    test('the test-mode banner is tied to the implementation', () {
      final source = read('lib/screens/premium/checkout_screen.dart');
      expect(
        source,
        contains('if (!Payments.isSimulated)'),
        reason: 'the banner must follow which service is live, not be a '
            'hardcoded string somebody can forget to remove',
      );
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
      // Whitespace-tolerant: `dart format` wraps this call across two lines
      // once the declaration grows, and a literal substring match then fails
      // on a purely cosmetic change. What matters is that the flag is read
      // from the environment at all, not how it is laid out.
      expect(
        RegExp(r"bool\.fromEnvironment\(\s*'DEMO_PREMIUM'").hasMatch(source),
        isTrue,
        reason: 'the demo grant must be switchable at build time',
      );
    });

    test('the deploy script makes a deliberate, documented choice', () {
      final deploy = File('deploy.ps1');
      if (!deploy.existsSync()) {
        // Gitignored: it carries a secret. Skip rather than fail on a machine
        // that does not have it.
        return;
      }
      final source = deploy.readAsStringSync();
      expect(
        RegExp('DEMO_PREMIUM=(true|false)').hasMatch(source),
        isTrue,
        reason: 'the flag must be set explicitly, never left to the default',
      );

      // It is currently TRUE, on purpose: the client asked for a working
      // dummy checkout, and a flag of false makes paying grant nothing on the
      // deployed site. That is a product decision, not an oversight, so the
      // reasoning has to be written where the next person will read it.
      if (source.contains('DEMO_PREMIUM=true')) {
        expect(
          source,
          contains('not a security boundary'),
          reason: 'if the deployed build accepts a device-local Premium flag, '
              'the script must say so and say why -- otherwise the free-tier '
              'limit looks enforced when it is not',
        );
        expect(
          source,
          contains('the day billing is connected'),
          reason: 'and must name the condition under which it flips back',
        );
      }
    });
  });
}
