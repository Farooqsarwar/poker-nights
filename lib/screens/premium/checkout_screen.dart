import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_styles.dart';

/// Checkout.
///
/// The card form, validation, pending state and result screen are all real and
/// reusable. What sits behind the Pay button is [MockPaymentService], which
/// contacts no payment provider and moves no money — the commercial terms
/// (price, billing period, who pays, and whether Apple and Google taking
/// 15–30% on the native apps is acceptable) are not agreed yet.
///
/// The banner at the top says so on screen. Every real payment sandbox shows
/// the same thing, and it costs the demo nothing.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.planId});

  final String? planId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _payments = MockPaymentService();
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();

  final _errors = <String, String>{};
  bool _processing = false;
  PaymentResult? _result;

  PremiumPlan get _plan => PremiumPlan.placeholders.firstWhere(
        (p) => p.id == widget.planId,
        orElse: () => PremiumPlan.placeholders.last,
      );

  @override
  void dispose() {
    for (final c in [_name, _number, _expiry, _cvc]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  bool _validate() {
    _errors.clear();
    if (_name.text.trim().isEmpty) {
      _errors['name'] = 'Enter the name on the card';
    }
    if (_digits.length < 13 || _digits.length > 19) {
      _errors['number'] = 'Enter a valid card number';
    }
    final expiry = _expiry.text.trim();
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      _errors['expiry'] = 'MM/YY';
    } else {
      final month = int.tryParse(expiry.substring(0, 2)) ?? 0;
      if (month < 1 || month > 12) _errors['expiry'] = 'Invalid month';
    }
    if (_cvc.text.trim().length < 3) {
      _errors['cvc'] = '3 digits';
    }
    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _pay() async {
    if (!_validate()) return;
    setState(() => _processing = true);
    final result = await _payments.purchase(_plan);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result?.succeeded == true) return _success();

    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _testModeBanner(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Checkout',
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _orderSummary(),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _name,
            label: 'Name on card',
            placeholder: 'A. Player',
            error: _errors['name'],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _number,
            label: 'Card number',
            placeholder: '4242 4242 4242 4242',
            keyboardType: TextInputType.number,
            error: _errors['number'],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _expiry,
                  label: 'Expiry',
                  placeholder: 'MM/YY',
                  keyboardType: TextInputType.number,
                  error: _errors['expiry'],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _cvc,
                  label: 'CVC',
                  placeholder: '123',
                  keyboardType: TextInputType.number,
                  error: _errors['cvc'],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
              ),
            ],
          ),
          if (_result?.succeeded == false) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _result!.message ?? 'Payment could not be completed.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _processing,
            onPressed: _processing ? null : _pay,
            child: Text(
              _processing ? 'Processing…' : 'Pay ${_plan.price}',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.ghost,
            onPressed: _processing ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _testModeBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Test mode — no card is charged and no payment provider is '
              'contacted. Billing is not connected yet.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSummary() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Poker Night Premium',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_plan.name} · ${_plan.period}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _plan.price,
                style: AppTypography.display(
                  size: AppFontSizes.xl,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Due today',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _plan.price,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _success() {
    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Glass.solidTint(AppColors.success),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 32, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'You are Premium',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Multi-table tournaments, AI-optimised structures and the advanced '
            'tooling are unlocked on this device.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _testModeBanner(),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () => context.go(RoutePaths.home),
            child: const Text('Back to Poker Night'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Groups a card number into blocks of four as it is typed.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inserts the slash in MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
