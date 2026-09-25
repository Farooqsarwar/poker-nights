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
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/chip_token.dart';

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
  final avgStack = activeCount > 0
      ? totalChips ~/ activeCount
      : structure.startingStack;
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
  bool _playersConfirmed = false;
  bool _addOnsConfirmed = false;
  bool _colorUpConfirmed = false;
  final Set<String> _addOnSelections = {};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final isAdmin = app.isAdmin;

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.invitation);
      });
      return const SizedBox.shrink();
    }

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
    final totalAddOns = activePlayers
        .where((p) => _addOnSelections.contains(p.id))
        .length;
    final addOnChips = totalAddOns * structure.addOnStack;
    final estPrizePool =
        structure.prizePool +
        (settings.addOn ? totalAddOns * settings.effectiveAddOnCost : 0);
    // §25.4a is a strict sequence and each step is gated on the previous one's
    // submission: attendance fixes the field, the add-on step fixes
    // `totalAddOns`, and only then can §18's grossEligible — and so the prize
    // pool — be computed at all.
    final stepIndex = !_playersConfirmed
        ? 0
        : !_addOnsConfirmed
        ? 1
        : !_colorUpConfirmed
        ? 2
        : 3;
    // What the pool will be once the selected add-ons are granted. The counts
    // already recorded on the players come from the provider; the selections
    // on this screen have not been granted yet, so they are passed in as the
    // pending count. Granting them below and then calling `confirmSettlement`
    // (which previews with 0 pending) reaches exactly these numbers.
    final preview = app.previewSettlementPrizes(
      settings.addOn ? _addOnSelections.length : 0,
    );

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
                    // Audit fix E3: the closing level is configurable (L4–L8),
                    // so the title follows it instead of hard-coding Level 6.
                    Text(
                      'End of Level ${settings.rebuysCloseLevel} — Settlement',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Confirm players → add-ons → color-up → prize pool',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppAlertBanner(
            type: AppAlertType.warning,
            message:
                'Rebuys are now closed. No new players may join after this point.',
          ),
          const SizedBox(height: AppSpacing.lg),
          // Progress
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= stepIndex
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Step 1: Confirm final eliminations & rebuys
          _ConfirmPlayersStep(
            game: game,
            isConfirmed: _playersConfirmed,
            onEdit: () => setState(() {
              // Re-opening an earlier step invalidates every later one: the
              // add-on price and the prize pool are both functions of the
              // confirmed field (§25.4a).
              _playersConfirmed = false;
              _addOnsConfirmed = false;
              _colorUpConfirmed = false;
            }),
            onGrantRebuy: settings.rebuys
                ? (id) => app.grantRebuy(
                    id,
                    idempotencyKey:
                        'final-rebuy-$id-${DateTime.now().microsecondsSinceEpoch}',
                  )
                : null,
            onConfirm: () {
              app.applyRecommendedAddOnStack();
              setState(() => _playersConfirmed = true);
            },
          ),
          // Step 2: Add-ons
          if (_playersConfirmed) ...[
            const SizedBox(height: AppSpacing.md),
            _AddOnsStep(
              isConfirmed: _addOnsConfirmed,
              onEdit: () => setState(() {
                _addOnsConfirmed = false;
                _colorUpConfirmed = false;
              }),
              activePlayers: activePlayers,
              addOnStack: app.recommendedAddOnStack,
              addOnChipPlan: app.liveAddOnChipPlan,
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
                            game.players.fold<int>(
                                  0,
                                  (s, p) => s + p.rebuys + p.reEntries,
                                ) *
                                structure.rebuyStack +
                            game.players.where((p) => p.hasAddOn).length *
                                structure.addOnStack) ~/
                        activePlayers.length)
                  : structure.startingStack,
              onApplySuggestion: () {
                app.updateEventSettings(
                  settings.copyWith(addOnCost: suggestedPrice),
                );
              },
              onConfirm: () => setState(() => _addOnsConfirmed = true),
            ),
          ],
          // Step 3: Color-up
          if (_addOnsConfirmed) ...[
            const SizedBox(height: AppSpacing.md),
            _ColorUpStep(
              isConfirmed: _colorUpConfirmed,
              onEdit: () => setState(() => _colorUpConfirmed = false),
              instructions: structure.colorUpInstructions,
              anteEnabled: settings.anteEnabled,
              anteStyle: settings.anteStyle,
              onAnteChanged: (v) => app.updateEventSettings(
                settings.copyWith(anteEnabled: v),
              ),
              // This used to call `confirmSettlement()` outright, which locked
              // the pool without the host ever seeing it. Color-up is a
              // physical instruction, not a financial decision — it only
              // unlocks the confirmation below.
              onNext: () => setState(() => _colorUpConfirmed = true),
            ),
          ],
          // Step 4: Confirm the prize pool. §25.4a's last gate — nothing about
          // the money is written until the host has read these numbers and
          // said yes.
          if (_colorUpConfirmed) ...[
            const SizedBox(height: AppSpacing.md),
            _ConfirmPrizePoolStep(
              organizerAmount: preview.organizerAmount,
              prizePool: preview.prizePool,
              roundingRemainder: preview.roundingRemainder,
              prizes: preview.prizes,
              addOnsTaken: settings.addOn
                  ? game.players.where((p) => p.hasAddOn).length +
                        _addOnSelections.length
                  : 0,
              organizerPct: settings.effectiveOrganizerPct,
              onConfirm: () {
                for (final id in _addOnSelections) {
                  app.grantAddOn(
                    id,
                    idempotencyKey:
                        'addon-$id-${DateTime.now().microsecondsSinceEpoch}',
                  );
                }
                app.confirmSettlement();
                context.go(RoutePaths.adminDashboard);
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _AddOnsStep extends StatelessWidget {
  const _AddOnsStep({
    required this.isConfirmed,
    required this.onEdit,
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

  final bool isConfirmed;
  final VoidCallback onEdit;
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
    if (isConfirmed) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add-ons selected: $totalAddOns',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      );
    }
    
    final isSuggestionNew =
        suggestedPrice > 0 && suggestedPrice != currentAddOnCost;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add-ons',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Each active player may purchase one add-on worth ${Formatters.chips(addOnStack)} chips.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // AI price suggestion (client feedback 07-018).
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'AI add-on price suggestion',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on $playerCount players, blinds ${Formatters.chips(currentBB)} and an average stack of ${Formatters.chips(avgStack)} — suggested price '
                  '${suggestedPrice > 0 ? Formatters.chips(suggestedPrice) : '—'}.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current add-on price: ${Formatters.chips(currentAddOnCost)}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (isSuggestionNew)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: onApplySuggestion,
                        child: const Text('Apply suggested price'),
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
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
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
                          Flexible(
                            child: Text(
                              p.name,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (p.hasAddOn) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(
                              label: 'Already purchased',
                              variant: AppBadgeVariant.green,
                            ),
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
                                color: selections.contains(p.id)
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: selections.contains(p.id)
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: selections.contains(p.id)
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: AppColors.primaryForeground,
                                    )
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
                    Text(
                      'Add-ons selected',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text('$totalAddOns', style: AppTypography.monoSm),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'Extra chips entering play',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.chips(addOnChips),
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'Updated prize pool (est.)',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.chips(estPrizePool),
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: onConfirm,
            child: const AppIconLabel(
              label: 'Confirm add-ons',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorUpStep extends StatelessWidget {
  const _ColorUpStep({
    required this.isConfirmed,
    required this.onEdit,
    required this.instructions,
    required this.anteEnabled,
    required this.anteStyle,
    required this.onAnteChanged,
    required this.onNext,
  });

  final bool isConfirmed;
  final VoidCallback onEdit;
  final List<String> instructions;
  final bool anteEnabled;
  final AnteStyle anteStyle;

  /// Spec §4.13 / Technical §11.2 step 4: the settlement break must end with
  /// the admin CONFIRMING ante activation or keeping antes off. This step
  /// previously only announced the decision, leaving no way to change it here.
  final ValueChanged<bool> onAnteChanged;
  final VoidCallback onNext;

  String get _anteName =>
      anteStyle == AnteStyle.individual ? 'individual ante' : 'big blind ante';

  @override
  Widget build(BuildContext context) {
    if (isConfirmed) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Color-up complete',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Color-up recommendations (Global)',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The system does not track individual stacks. Execute these global recommendations physically at the table. The $_anteName will begin next level.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (instructions.isEmpty)
            Text(
              'No color-up required at this point.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            )
          else
            for (var i = 0; i < instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
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
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          instructions[i],
                          style: AppTypography.bodySm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: anteEnabled ? AppColors.primarySoft : AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: anteEnabled
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        anteEnabled
                            ? 'Ante starts next level'
                            : 'Antes stay off',
                        style: AppTypography.bodySm.copyWith(
                          color: anteEnabled
                              ? AppColors.primary
                              : AppColors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AppToggle(
                      value: anteEnabled,
                      onChanged: onAnteChanged,
                      label: 'Activate ante next level',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  anteEnabled
                      ? (anteStyle == AnteStyle.individual
                            ? 'Every player posts an individual ante (half the big blind). Confirm with all players before starting.'
                            : 'Big blind ante equal to the big blind value. Confirm with all players before starting.')
                      : 'No ante will be posted. Switch this on to activate the ante from the next level.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            fullWidth: true,
            onPressed: onNext,
            child: const AppIconLabel(
              label: 'Color-up complete',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}


/// Step 4 — the host reads the prize pool and confirms it.
///
/// §25.4a's third gate. It is locked until the add-on step submits because
/// §18's `grossEligible` needs `totalAddOns` fixed, and that is exactly what
/// the add-on step fixes. This step previously did not exist: color-up called
/// `confirmSettlement()` directly, so the pool — the one number the whole
/// settlement break exists to produce — was written without the host ever
/// seeing it, and nothing can reopen it afterwards (§25.4a is one-way).
///
/// The figures are the provider's own settlement preview, so what is shown
/// here is what gets stored.
class _ConfirmPrizePoolStep extends StatelessWidget {
  const _ConfirmPrizePoolStep({
    required this.organizerAmount,
    required this.prizePool,
    required this.roundingRemainder,
    required this.prizes,
    required this.addOnsTaken,
    required this.organizerPct,
    required this.onConfirm,
  });

  final int organizerAmount;
  final int prizePool;
  final int roundingRemainder;
  final List<Prize> prizes;
  final int addOnsTaken;
  final num organizerPct;
  final VoidCallback onConfirm;

  /// Gross eligible is not returned by the preview, but it is recoverable
  /// exactly: the engine splits gross into the organizer cut, the sub-10
  /// residue carried out of the pool, and the pool itself (§18, 14-022).
  /// Deriving it here rather than re-running `grossEligibleFor` keeps the
  /// three lines guaranteed to add up on screen.
  int get _grossEligible => prizePool + organizerAmount + roundingRemainder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step 4 — Confirm the prize pool',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Built from the confirmed field, the recorded rebuys and re-entries '
            'and the $addOnsTaken add-on${addOnsTaken == 1 ? '' : 's'} above. '
            'Confirming locks it: no further rebuys, re-entries or add-ons, and '
            'players stop seeing "Estimated".',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _MoneyRow(label: 'Gross eligible', amount: _grossEligible),
                if (organizerAmount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _MoneyRow(
                    label: 'Organizational costs ($organizerPct%)',
                    amount: -organizerAmount,
                  ),
                ],
                // 14-010 / 14-011: the residue is NOT an organizer cut and is
                // never labelled as one. It is the change that cannot be split
                // into payouts that are all multiples of 10.
                if (roundingRemainder > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _MoneyRow(
                    label: 'Rounding remainder (kept aside)',
                    amount: -roundingRemainder,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.sm),
                _MoneyRow(
                  label: 'Final prize pool',
                  amount: prizePool,
                  emphasis: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Payouts',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (prizes.isEmpty)
            Text(
              'No paid places — check the field size and the buy-in.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            )
          else
            for (final prize in prizes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${prize.place}${_ordinalSuffix(prize.place)} place',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.prize(prize.amount),
                        style: AppTypography.monoSm.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: onConfirm,
            child: const AppIconLabel(
              label: 'Confirm prize pool & resume play',
              trailing: Icons.check,
            ),
          ),
        ],
      ),
    );
  }

  static String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    return switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }
}

/// One line of the pool breakdown. Negative amounts render with a leading
/// minus so a host can read the subtraction down the column.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.emphasis = false,
  });

  final String label;
  final int amount;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: emphasis
                  ? AppColors.foreground
                  : AppColors.mutedForeground,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          '${amount < 0 ? '-' : ''}${Formatters.prize(amount.abs())}',
          style: AppTypography.monoSm.copyWith(
            color: emphasis ? AppColors.primary : AppColors.primaryText,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Step 0 — Admin confirms exact player count before add-on selection.
/// Records any final eliminations and rebuys that happened during the
/// last hand before the deadline (spec §4.13).
class _ConfirmPlayersStep extends StatelessWidget {
  const _ConfirmPlayersStep({
    required this.game,
    required this.onConfirm,
    this.onGrantRebuy,
    required this.isConfirmed,
    required this.onEdit,
  });

  final LiveGame game;
  final VoidCallback onConfirm;
  final void Function(String playerId)? onGrantRebuy;
  final bool isConfirmed;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (isConfirmed) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Players confirmed',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      );
    }
    final active = game.activePlayers;
    final eliminated = [
      ...game.eliminatedPlayers,
    ]..sort((a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0));
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step 1 — Confirm who is in',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Check the eliminations and rebuys from the last hand before the '
            'deadline. A hand that began before the deadline can still be '
            'settled here — tap "Final rebuy" to record one. This confirms the '
            'exact field before the add-on price is calculated.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Recent eliminations with their rebuy state
          if (eliminated.isNotEmpty) ...[
            Text(
              'Eliminations so far',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final p in eliminated)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    AppAvatar(name: p.name, size: AppAvatarSize.sm),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        p.name,
                        style: AppTypography.bodySm.copyWith(
                          color: p.rebuys > 0
                              ? AppColors.mutedForeground
                              : AppColors.foreground,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    Text(
                      'Pos ${p.eliminationPos ?? '—'}',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Glyphs as well as colour, matching the sheet's
                    // Busted pill — this list is scanned quickly and the two
                    // states sit in the same column.
                    p.rebuys > 0
                        ? const AppBadge(
                            label: 'Rebought',
                            variant: AppBadgeVariant.green,
                            icon: Icons.refresh,
                          )
                        : const AppBadge(
                            label: 'Out',
                            variant: AppBadgeVariant.red,
                            icon: Icons.close,
                          ),
                    // User Flow section 4.13 / 12-056: "the administrator
                    // records any final valid rebuy from a hand that began
                    // before the deadline". That happens HERE, during the
                    // break — there was previously no way to do it, because
                    // `rebuysClosed` flipped the moment settlement began.
                    if (onGrantRebuy != null && p.rebuys == 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => onGrantRebuy!(p.id),
                        child: const Text('Final rebuy'),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'No eliminations recorded yet.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          // Summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Active players going to add-on phase: ',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${active.length}',
                  style: AppTypography.mono(
                    size: AppFontSizes.md,
                    weight: FontWeight.w700,
                    color: AppColors.primaryText,
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
