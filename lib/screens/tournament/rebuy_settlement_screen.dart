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
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_page.dart';
import '../../widgets/chip_token.dart';

enum _SettlementStep { confirmPlayers, addOns, colorUp, confirm }

/// Client feedback (07-018): the AI suggests an add-on price from the current
/// player count, blinds and average stack. Stack depth (avg stack / big blind)
/// drives the value of the add-on stack: the shorter stacks are, the more the
/// add-on is worth, so the suggested price moves up and vice-versa. The result
/// is clamped to ±25% of the buy-in and rounded to a clean multiple of 5.
int aiSuggestedAddOnPrice(LiveGame game) {
  final settings = game.settings;
  final structure = game.structure;
  final buyIn = settings.buyIn;
  if (buyIn <= 0) return 0;

  final totalRebuys = game.players.fold<int>(
    0,
    (s, p) => s + p.rebuys + p.reEntries,
  );
  final addOnsGranted = game.players.where((p) => p.hasAddOn).length;
  final totalChips =
      settings.players * structure.startingStack +
      totalRebuys * structure.rebuyStack +
      addOnsGranted * structure.addOnStack;
  final activeCount = game.activePlayers.length;
  final avgStack = activeCount > 0 ? totalChips ~/ activeCount : structure.startingStack;
  final bb = game.currentLevelData?.bb ?? structure.levels.first.bb;

  final depth = bb > 0 ? avgStack / bb : 20.0;
  final factor = (1.0 + (20.0 - depth) / 100.0).clamp(0.75, 1.25);
  final raw = buyIn * factor;
  return (raw / 5).round() * 5;
}

/// Rebuy settlement / color-up flow mirroring the web `RebuySettlementPage`.
class RebuySettlementScreen extends StatefulWidget {
  const RebuySettlementScreen({super.key});

  @override
  State<RebuySettlementScreen> createState() => _RebuySettlementScreenState();
}

class _RebuySettlementScreenState extends State<RebuySettlementScreen> {
  _SettlementStep _step = _SettlementStep.confirmPlayers;
  final Set<String> _addOnSelections = {};

  // Step 0 — confirm final eliminations and rebuys
  int _finalEliminations = 0;
  int _finalRebuys = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      // No game in provider — redirect back to a safe screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.adminDashboard);
      });
      return const SizedBox.shrink();
    }

    final structure = game.structure;
    final settings = game.settings;
    final activePlayers = game.activePlayers;
    final suggestedPrice = aiSuggestedAddOnPrice(game);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End of Level 6 — Settlement', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    Text(
                      'Confirm players → add-ons → color-up → continue',
                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
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
          // Step 0: Confirm final eliminations & rebuys
          if (_step == _SettlementStep.confirmPlayers)
            _ConfirmPlayersStep(
              activeCount: activePlayers.length,
              eliminations: _finalEliminations,
              rebuys: _finalRebuys,
              onChanged: (e, r) => setState(() {
                _finalEliminations = e;
                _finalRebuys = r;
              }),
              onConfirm: () => setState(() => _step = _SettlementStep.addOns),
            ),
          // Step 1: Add-ons
          if (_step == _SettlementStep.addOns)
            _AddOnsStep(
              activePlayers: activePlayers,
              addOnStack: structure.addOnStack,
              addOnChipPlan: structure.addOnChipPlan,
              selections: _addOnSelections,
              onToggle: (id) => setState(() {
                if (!_addOnSelections.remove(id)) _addOnSelections.add(id);
              }),
              totalAddOns: totalAddOns,
              addOnChips: addOnChips,
              estPrizePool: estPrizePool,
              suggestedPrice: suggestedPrice,
              currentAddOnCost: settings.effectiveAddOnCost,
              currentBB: game.currentLevelData?.bb ?? structure.levels.first.bb,
              playerCount: activePlayers.length,
              avgStack: activePlayers.isNotEmpty
                  ? ((settings.players * structure.startingStack +
                          game.players.fold<int>(0, (s, p) => s + p.rebuys + p.reEntries) *
                              structure.rebuyStack +
                          game.players.where((p) => p.hasAddOn).length *
                              structure.addOnStack) ~/
                      activePlayers.length)
                  : structure.startingStack,
              onApplySuggestion: () {
                app.updateEventSettings(settings.copyWith(addOnCost: suggestedPrice));
              },
              onConfirm: () => setState(() => _step = _SettlementStep.colorUp),
            ),
          // Step 2: Color-up
          if (_step == _SettlementStep.colorUp)
            _ColorUpStep(
              instructions: structure.colorUpInstructions,
              anteEnabled: settings.anteEnabled,
              anteStyle: settings.anteStyle,
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
    required this.suggestedPrice,
    required this.currentAddOnCost,
    required this.currentBB,
    required this.playerCount,
    required this.avgStack,
    required this.onApplySuggestion,
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
  final int suggestedPrice;
  final int currentAddOnCost;
  final int currentBB;
  final int playerCount;
  final int avgStack;
  final VoidCallback onApplySuggestion;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isSuggestionNew = suggestedPrice > 0 && suggestedPrice != currentAddOnCost;
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
          const SizedBox(height: AppSpacing.md),
          // AI price suggestion (client feedback 07-018).
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text('AI add-on price suggestion', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on $playerCount players, blinds ${Formatters.chips(currentBB)} and an average stack of ${Formatters.chips(avgStack)} — suggested price '
                  '${suggestedPrice > 0 ? Formatters.chips(suggestedPrice) : '—'}.',
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current add-on price: ${Formatters.chips(currentAddOnCost)}',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                    if (isSuggestionNew)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: onApplySuggestion,
                        child: Text('Use ${Formatters.chips(suggestedPrice)}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (addOnChipPlan.isNotEmpty) ...[
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
            child: const AppIconLabel(label: 'Confirm add-ons', trailing: Icons.arrow_forward),
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
    required this.anteStyle,
    required this.onNext,
  });

  final List<String> instructions;
  final bool anteEnabled;
  final AnteStyle anteStyle;
  final VoidCallback onNext;

  String get _anteName => anteStyle == AnteStyle.individual ? 'individual ante' : 'big blind ante';

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
            'Exchange small chips before continuing. The $_anteName will begin next level.',
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
                    anteStyle == AnteStyle.individual
                        ? 'Every player posts an individual ante (half the big blind). Confirm with all players before starting.'
                        : 'Big blind ante equal to the big blind value. Confirm with all players before starting.',
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
            child: const AppIconLabel(label: 'Color-up complete', trailing: Icons.arrow_forward),
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
            child: const AppIconLabel(label: 'Start next level', icon: Icons.play_arrow),
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

/// Step 0 — Admin confirms exact player count before add-on selection.
/// Records any final eliminations and rebuys that happened during the
/// last hand before the deadline (spec §4.13).
class _ConfirmPlayersStep extends StatelessWidget {
  const _ConfirmPlayersStep({
    required this.activeCount,
    required this.eliminations,
    required this.rebuys,
    required this.onChanged,
    required this.onConfirm,
  });

  final int activeCount;
  final int eliminations;
  final int rebuys;
  final void Function(int eliminations, int rebuys) onChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final netActive = activeCount - eliminations + rebuys;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step 1 — Confirm final player count',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Record any eliminations or rebuys that occurred during the last hand '
            'before the deadline. This determines the exact number of active players '
            'and the add-on recommendation.',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Eliminations counter
          _CounterRow(
            label: 'Final eliminations this level',
            value: eliminations,
            onDecrement: eliminations > 0 ? () => onChanged(eliminations - 1, rebuys) : null,
            onIncrement: () => onChanged(eliminations + 1, rebuys),
          ),
          const SizedBox(height: AppSpacing.md),
          // Rebuys counter
          _CounterRow(
            label: 'Final valid rebuys (hands started before deadline)',
            value: rebuys,
            onDecrement: rebuys > 0 ? () => onChanged(eliminations, rebuys - 1) : null,
            onIncrement: () => onChanged(eliminations, rebuys + 1),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Active players going to add-on phase: ',
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                Text(
                  '$netActive',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: onConfirm,
            child: const AppIconLabel(
              label: 'Confirm player count — go to add-ons',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

/// +/- counter row used in the confirm-players step.
class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onIncrement,
    this.onDecrement,
  });

  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: onDecrement != null ? AppColors.destructive : AppColors.border,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.monoSm.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
