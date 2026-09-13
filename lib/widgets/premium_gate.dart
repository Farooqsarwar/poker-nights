import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../services/entitlements.dart';
import '../services/payment_service.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Stands in front of a Premium feature (v11 addendum §3).
///
/// Shows [child] when the tier allows it, and an upgrade prompt naming the
/// feature when it does not. Naming matters: "Upgrade to Premium" tells a host
/// nothing, where "Saved presets are a Premium feature" tells them exactly
/// what they are choosing to buy.
///
/// §3's monetization principle is the boundary — the core clock, check-in and
/// basic payouts are never behind this. Only scale, intelligence and advanced
/// control.
///
/// **Not security.** The tier is resolved from the server-held entitlement
/// where one exists, but a determined user can still reach the underlying
/// provider methods. Real protection lives in `firestore.rules`, which refuses
/// the writes that matter regardless of what the UI allows.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.tier,
    required this.feature,
    required this.child,
    this.blurb,
  });

  final PremiumTier tier;
  final PremiumFeature feature;
  final Widget child;

  /// One line on why this is worth having. Falls back to the feature label.
  final String? blurb;

  @override
  Widget build(BuildContext context) {
    if (Entitlements.allows(tier, feature)) return child;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  feature.label,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            blurb ?? 'This is a Premium feature.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: () => context.push(RoutePaths.upgrade),
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}

/// Inline variant for a single control rather than a whole screen.
///
/// Dims and disables instead of replacing, so the host can still see the
/// setting exists — hiding it entirely makes the product look smaller than it
/// is, and makes the upgrade harder to want.
class PremiumLock extends StatelessWidget {
  const PremiumLock({
    super.key,
    required this.tier,
    required this.feature,
    required this.child,
  });

  final PremiumTier tier;
  final PremiumFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Entitlements.allows(tier, feature)) return child;

    return Tooltip(
      message: '${feature.label} — Premium',
      child: Stack(
        children: [
          Opacity(opacity: 0.45, child: IgnorePointer(child: child)),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => context.push(RoutePaths.upgrade),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: AppColors.background,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Premium',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
