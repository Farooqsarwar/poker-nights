import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/cash_game.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_text_field.dart';

enum _CashStep { setup, players }

/// New cash game setup mirroring the web `CashGamePage`.
class CashGameScreen extends StatefulWidget {
  const CashGameScreen({super.key});

  @override
  State<CashGameScreen> createState() => _CashGameScreenState();
}

class _CashGameScreenState extends State<CashGameScreen> {
  _CashStep _step = _CashStep.setup;

  final _name = TextEditingController();
  final _date = TextEditingController(text: _today());
  final _location = TextEditingController();
  final _smallBlind = TextEditingController(text: '1');
  final _bigBlind = TextEditingController(text: '2');
  final _minBuyIn = TextEditingController(text: '20');
  final _maxBuyIn = TextEditingController(text: '200');
  final _maxPlayers = TextEditingController(text: '10');
  final _rakePct = TextEditingController(text: '0');
  String _currency = '\$';
  final List<TextEditingController> _playerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  static String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _location.dispose();
    _smallBlind.dispose();
    _bigBlind.dispose();
    _minBuyIn.dispose();
    _maxBuyIn.dispose();
    _maxPlayers.dispose();
    _rakePct.dispose();
    for (final c in _playerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start(AppProvider app) {
    final validNames = _playerControllers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (validNames.length < 2) return;
    app.startCashGame(
      CashSessionSettings(
        name: _name.text.trim().isEmpty ? 'Friday Cash Game' : _name.text.trim(),
        date: _date.text,
        location: _location.text.trim().isEmpty ? 'Location' : _location.text.trim(),
        smallBlind: num.tryParse(_smallBlind.text)?.toDouble() ?? 1,
        bigBlind: num.tryParse(_bigBlind.text)?.toDouble() ?? 2,
        minBuyIn: num.tryParse(_minBuyIn.text)?.toDouble() ?? 20,
        maxBuyIn: num.tryParse(_maxBuyIn.text)?.toDouble() ?? 200,
        currency: _currency,
        maxPlayers: num.tryParse(_maxPlayers.text)?.toInt() ?? 10,
        rakePct: num.tryParse(_rakePct.text)?.toDouble() ?? 0,
      ),
      validNames,
    );
    context.go(RoutePaths.cashGameLive);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final validCount = _playerControllers.where((c) => c.text.trim().isNotEmpty).length;

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.home),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(Icons.arrow_back, size: AppFontSizes.xl, color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Cash Game', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                  Text(
                    'Set up blinds, buy-in limits, and players',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Step tabs
          Row(
            children: [
              Expanded(
                child: _StepTab(
                  label: '1. Game Setup',
                  active: _step == _CashStep.setup,
                  onTap: () => setState(() => _step = _CashStep.setup),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StepTab(
                  label: '2. Players',
                  active: _step == _CashStep.players,
                  onTap: () => setState(() => _step = _CashStep.players),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step == _CashStep.setup)
            _SetupForm(
              name: _name,
              date: _date,
              location: _location,
              smallBlind: _smallBlind,
              bigBlind: _bigBlind,
              minBuyIn: _minBuyIn,
              maxBuyIn: _maxBuyIn,
              maxPlayers: _maxPlayers,
              rakePct: _rakePct,
              currency: _currency,
              onCurrencyChanged: (v) => setState(() => _currency = v ?? '\$'),
              onContinue: () => setState(() => _step = _CashStep.players),
            )
          else
            _PlayersForm(
              controllers: _playerControllers,
              onAdd: () => setState(() => _playerControllers.add(TextEditingController())),
              onRemove: (i) => setState(() {
                _playerControllers.removeAt(i).dispose();
              }),
              validCount: validCount,
              currency: _currency,
              smallBlind: _smallBlind.text,
              bigBlind: _bigBlind.text,
              minBuyIn: _minBuyIn.text,
              maxBuyIn: _maxBuyIn.text,
              onStart: () => _start(app),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            fontWeight: FontWeight.w500,
            color: active ? AppColors.primaryForeground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _SetupForm extends StatelessWidget {
  const _SetupForm({
    required this.name,
    required this.date,
    required this.location,
    required this.smallBlind,
    required this.bigBlind,
    required this.minBuyIn,
    required this.maxBuyIn,
    required this.maxPlayers,
    required this.rakePct,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onContinue,
  });

  final TextEditingController name;
  final TextEditingController date;
  final TextEditingController location;
  final TextEditingController smallBlind;
  final TextEditingController bigBlind;
  final TextEditingController minBuyIn;
  final TextEditingController maxBuyIn;
  final TextEditingController maxPlayers;
  final TextEditingController rakePct;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: name,
            label: 'Game name',
            placeholder: 'Friday Cash Game',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(controller: date, label: 'Date', placeholder: 'YYYY-MM-DD'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(controller: location, label: 'Location', placeholder: 'Location'),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: AppSpacing.xxl),
          Text('Blinds', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppSelect(
                  label: 'Currency',
                  value: currency,
                  items: const [
                    DropdownMenuItem(value: '\$', child: Text('USD')),
                    DropdownMenuItem(value: '€', child: Text('EUR')),
                    DropdownMenuItem(value: '£', child: Text('GBP')),
                    DropdownMenuItem(value: '¥', child: Text('JPY')),
                  ],
                  onChanged: onCurrencyChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: smallBlind,
                  label: 'Small blind',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '1',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: bigBlind,
                  label: 'Big blind',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '2',
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: AppSpacing.xxl),
          Text('Buy-in limits', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: minBuyIn,
                  label: 'Min buy-in',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: maxBuyIn,
                  label: 'Max buy-in',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: maxPlayers,
                  label: 'Max players',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: rakePct,
                  label: 'Rake %',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: onContinue,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue to Players'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersForm extends StatelessWidget {
  const _PlayersForm({
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
    required this.validCount,
    required this.currency,
    required this.smallBlind,
    required this.bigBlind,
    required this.minBuyIn,
    required this.maxBuyIn,
    required this.onStart,
  });

  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final int validCount;
  final String currency;
  final String smallBlind;
  final String bigBlind;
  final String minBuyIn;
  final String maxBuyIn;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Starting players', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Add players now — you can add more once the game starts.',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: controllers[i],
                      placeholder: 'Player ${i + 1}',
                    ),
                  ),
                  if (controllers.length > 1)
                    InkWell(
                      onTap: () => onRemove(i),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.destructive,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          AppButton(
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: onAdd,
            child: const Text('+ Add player'),
          ),
          const Divider(color: AppColors.border, height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'Blinds', value: '$smallBlind/$bigBlind'),
                const SizedBox(height: 4),
                _SummaryRow(label: 'Buy-in range', value: '$minBuyIn–$maxBuyIn'),
                const SizedBox(height: 4),
                _SummaryRow(label: 'Starting players', value: '$validCount'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: validCount >= 2 ? onStart : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 16, color: AppColors.icon),
                SizedBox(width: 6),
                Text('Start cash game'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
        const Spacer(),
        Text(value, style: AppTypography.monoSm),
      ],
    );
  }
}
