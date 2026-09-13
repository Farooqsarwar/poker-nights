import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/payment_record.dart';
import '../providers/app_provider.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'glass_styles.dart';

/// Collects a buy-in, rebuy, re-entry or add-on (QA section 12).
///
/// **Simulated.** No card is charged and no payment provider is contacted. The
/// sheet exists so the tournament's accounting can be exercised end to end —
/// including the unhappy paths, which is why Decline and Cancel are offered
/// as first-class buttons rather than hidden behind an error injector.
///
/// The amount comes from the tournament's own settings and is not editable
/// here. A payer who could name their own price is the whole of QA case
/// PN-NEG-013, and the cleanest prevention is to never accept the figure in
/// the first place.
/// `showAppModal` returns `Future<void>`, so the settled record is handed back
/// through [onSettled] rather than the future. The sheet pops itself either
/// way, so a caller that only needs the side effect can ignore it.
Future<void> showDummyPaymentSheet({
  required BuildContext context,
  required String playerId,
  required String playerName,
  required PaymentPurpose purpose,
  ValueChanged<PaymentRecord?>? onSettled,
}) {
  final app = context.read<AppProvider>();
  final amount = app.amountFor(purpose);

  // One key per sheet. Every button in this sheet reuses it, so a double-tap
  // -- or a retry after a dropped connection -- is the same payment rather
  // than a second one (PN-DPAY-007, PN-NEG-011).
  final idempotencyKey =
      'pay-$playerId-${purpose.name}-${DateTime.now().microsecondsSinceEpoch}';

  return showAppModal(
    context: context,
    title: purpose.label,
    maxWidth: 400,
    child: _DummyPaymentBody(
      playerId: playerId,
      playerName: playerName,
      purpose: purpose,
      amount: amount,
      idempotencyKey: idempotencyKey,
      onSettled: onSettled,
    ),
  );
}

class _DummyPaymentBody extends StatefulWidget {
  const _DummyPaymentBody({
    required this.playerId,
    required this.playerName,
    required this.purpose,
    required this.amount,
    required this.idempotencyKey,
    this.onSettled,
  });

  final String playerId;
  final String playerName;
  final PaymentPurpose purpose;
  final int amount;
  final String idempotencyKey;
  final ValueChanged<PaymentRecord?>? onSettled;

  @override
  State<_DummyPaymentBody> createState() => _DummyPaymentBodyState();
}

class _DummyPaymentBodyState extends State<_DummyPaymentBody> {
  bool _working = false;

  Future<void> _settle(PaymentStatus outcome) async {
    setState(() => _working = true);
    // A visible pause, so the pending state is real enough to design against
    // and a double-tap has something to race.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final record = context.read<AppProvider>().recordPayment(
          playerId: widget.playerId,
          purpose: widget.purpose,
          idempotencyKey: widget.idempotencyKey,
          outcome: outcome,
          failureReason:
              outcome == PaymentStatus.failed ? 'Declined (simulated)' : null,
        );
    if (!mounted) return;
    widget.onSettled?.call(record);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Simulated — no card is charged and no money moves.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Glass.solidTint(AppColors.secondary),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                widget.playerName,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.amount}',
                style: AppTypography.display(
                  size: AppFontSizes.xxxl,
                  weight: FontWeight.w700,
                ),
              ),
              Text(
                widget.purpose.label,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'The amount is set by the tournament and cannot be changed here.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          loading: _working,
          onPressed: _working ? null : () => _settle(PaymentStatus.paid),
          child: Text(_working ? 'Processing…' : 'Mark paid'),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Offered deliberately: the unhappy paths have to be reachable or
        // they cannot be tested (PN-DPAY-004, PN-DPAY-005).
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _working ? null : () => _settle(PaymentStatus.failed),
                child: const Text('Simulate decline'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: _working
                    ? null
                    : () => _settle(PaymentStatus.cancelled),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
