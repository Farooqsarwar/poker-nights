import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/chip_token.dart';

enum _SettlementStep { addOns, colorUp, confirm }

/// Rebuy settlement / color-up flow mirroring the web `RebuySettlementPage`.
class RebuySettlementScreen extends StatefulWidget {
  const RebuySettlementScreen({super.key});

  @override
  State<RebuySettlementScreen> createState() => _RebuySettlementScreenState();
}

class _RebuySettlementScreenState extends State<RebuySettlementScreen> {
  _SettlementStep _step = _SettlementStep.addOns;
  final Set<String> _addOnSelections = {};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      return Center(
        child: Text('No active game.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
      );
    }

    final structure = game.structure;
    final settings = game.settings;
    final activePlayers = game.activePlayers;
    final totalAddOns = activePlayers.where((p) => _addOnSelections.contains(p.id)).length;
    final addOnChips = totalAddOns * structure.addOnStack;
    final estPrizePool = structure.prizePool + (settings.addOn ? totalAddOns * settings.buyIn : 0);
    final stepIndex = _SettlementStep.values.indexOf(_step);

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppBackButton(onTap: () => context.go(RoutePaths.adminDashboard)),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rebuy Settlement', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                  Text(
                    'Level ${settings.rebuysCloseLevel} is complete — confirm before continuing',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppAlertBanner(
            type: AppAlertType.warning,
            message: 'Rebuys are now closed. No new players may join after this point.',
          ),
          const SizedBox(height: AppSpacing.lg),
          // Progress
          Row(
            children: [
              for (var i = 0; i < _SettlementStep.values.length; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= stepIndex ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Step 1: Add-ons
          if (_step == _SettlementStep.addOns)
            _AddOnsStep(
              activePlayers: activePlayers,
              addOnStack: structure.addOnStack,
              addOnChipPlan: structure.chipPlan,
              selections: _addOnSelections,
              onToggle: (id) => setState(() {
                if (!_addOnSelections.remove(id)) _addOnSelections.add(id);
              }),
              totalAddOns: totalAddOns,
              addOnChips: addOnChips,
              estPrizePool: estPrizePool,
              onConfirm: () => setState(() => _step = _SettlementStep.colorUp),
            ),
          // Step 2: Color-up
          if (_step == _SettlementStep.colorUp)
            _ColorUpStep(
              instructions: structure.colorUpInstructions,
              anteEnabled: settings.anteEnabled,
              onNext: () => setState(() => _step = _SettlementStep.confirm),
            ),
          // Step 3: Confirm
          if (_step == _SettlementStep.confirm)
            _ConfirmStep(
              activeCount: activePlayers.length,
              // Already-granted add-ons plus the ones selected in this step.
              addOnsTaken: activePlayers.where((p) => p.hasAddOn).length + _addOnSelections.length,
              anteEnabled: settings.anteEnabled,
              prizePool: structure.prizePool,
              onStart: () {
                for (final id in _addOnSelections) {
                  app.grantAddOn(id);
                }
                app.confirmSettlement();
                app.updateGameStatus(LiveGameStatus.running);
                app.resumeTimer();
                context.go(RoutePaths.adminDashboard);
              },
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _AddOnsStep extends StatelessWidget {
  const _AddOnsStep({
    required this.activePlayers,
    required this.addOnStack,
    required this.addOnChipPlan,
    required this.selections,
    required this.onToggle,
    required this.totalAddOns,
    required this.addOnChips,
    required this.estPrizePool,
    required this.onConfirm,
  });

  final List<Player> activePlayers;
  final int addOnStack;
  final List<ChipPlanEntry> addOnChipPlan;
  final Set<String> selections;
  final ValueChanged<String> onToggle;
  final int totalAddOns;
  final int addOnChips;
  final int estPrizePool;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add-ons', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Each active player may purchase one add-on worth ${Formatters.chips(addOnStack)} chips.',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          if (addOnChipPlan.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add-on composition',
              style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (final entry in addOnChipPlan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ChipToken(
                        colorName: entry.color,
                        hex: Color(entry.hex),
                        value: entry.value,
                        count: entry.count,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final p in activePlayers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(child: Text(p.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500))),
                          if (p.hasAddOn) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(label: 'Already purchased', variant: AppBadgeVariant.green),
                          ],
                        ],
                      ),
                    ),
                    if (!p.hasAddOn)
                      InkWell(
                        onTap: () => onToggle(p.id),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: selections.contains(p.id) ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: selections.contains(p.id) ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: selections.contains(p.id)
                                  ? const Icon(Icons.check, size: 14, color: AppColors.primaryForeground)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Add-on', style: AppTypography.bodySm),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Add-ons selected', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                    const Spacer(),
                    Text('$totalAddOns', style: AppTypography.monoSm),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Extra chips entering play', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                    const Spacer(),
                    Text(Formatters.chips(addOnChips), style: AppTypography.monoSm.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Updated prize pool (est.)', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                    const Spacer(),
                    Text(Formatters.chips(estPrizePool), style: AppTypography.monoSm.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: onConfirm,
            child: const Text('Confirm add-ons →'),
          ),
        ],
      ),
    );
  }
}

class _ColorUpStep extends StatelessWidget {
  const _ColorUpStep({
    required this.instructions,
    required this.anteEnabled,
    required this.onNext,
  });

  final List<String> instructions;
  final bool anteEnabled;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Color-up instructions', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Exchange small chips before continuing. The ${anteEnabled ? 'big blind ante' : 'ante'} will begin next level.',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          if (instructions.isEmpty)
            Text('No color-up required at this point.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground))
          else
            for (var i = 0; i < instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: AppTypography.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(instructions[i], style: AppTypography.bodySm)),
                    ],
                  ),
                ),
              ),
          if (anteEnabled) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ante starts next level', style: AppTypography.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Big blind ante equal to the big blind value. Confirm with all players before starting.',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            fullWidth: true,
            onPressed: onNext,
            child: const Text('Color-up complete →'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.activeCount,
    required this.addOnsTaken,
    required this.anteEnabled,
    required this.prizePool,
    required this.onStart,
  });

  final int activeCount;
  final int addOnsTaken;
  final bool anteEnabled;
  final int prizePool;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ready to continue?', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _ConfirmRow(label: 'Active players', value: '$activeCount'),
                const SizedBox(height: 4),
                _ConfirmRow(label: 'Add-ons taken', value: '$addOnsTaken'),
                const SizedBox(height: 4),
                _ConfirmRow(label: 'Ante', value: anteEnabled ? 'Active from next level' : 'Not enabled'),
                const Divider(color: AppColors.border, height: AppSpacing.lg),
                Row(
                  children: [
                    Text('Prize pool', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(Formatters.chips(prizePool), style: AppTypography.monoSm.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Once you start the next level, no more rebuys or add-ons are possible.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: onStart,
            child: const Text('▶ Start next level'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

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
