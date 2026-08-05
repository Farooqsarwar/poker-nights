import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';

enum _CashActionType { buyIn, cashOut }

class _CashAction {
  const _CashAction(this.type, this.playerId);

  final _CashActionType type;
  final String? playerId;
}

/// Live cash game dashboard mirroring the web `CashGameLivePage`.
class CashGameLiveScreen extends StatefulWidget {
  const CashGameLiveScreen({super.key});

  @override
  State<CashGameLiveScreen> createState() => _CashGameLiveScreenState();
}

class _CashGameLiveScreenState extends State<CashGameLiveScreen> {
  _CashAction? _action;
  final _amount = TextEditingController();
  final _newPlayerName = TextEditingController();
  bool _showEndModal = false;
  bool _showReconcile = false;

  @override
  void dispose() {
    _amount.dispose();
    _newPlayerName.dispose();
    super.dispose();
  }

  void _openAction(_CashAction action, {double? preset}) {
    setState(() {
      _action = action;
      _amount.text = preset != null ? preset.toString() : '';
    });
  }

  void _confirmAction(AppProvider app) {
    final amt = num.tryParse(_amount.text)?.toDouble();
    if (amt == null || amt <= 0) return;
    final action = _action;
    if (action == null) return;

    if (action.type == _CashActionType.buyIn) {
      final pid = action.playerId;
      if (pid != null) {
        app.cashBuyIn(pid, amt);
      } else if (_newPlayerName.text.trim().isNotEmpty) {
        app.cashBuyIn(_newPlayerName.text.trim(), amt, isNew: true);
        _newPlayerName.clear();
      }
    } else if (action.type == _CashActionType.cashOut && action.playerId != null) {
      app.cashCashOut(action.playerId!, amt);
    }

    setState(() {
      _action = null;
      _amount.clear();
    });
  }

  void _endGame(AppProvider app) {
    app.endCashGame();
    setState(() => _showEndModal = false);
    context.go(RoutePaths.history);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final session = app.cashSession;

    if (session == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text('No active cash game.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              onPressed: () => context.go(RoutePaths.cashGame),
              child: const Text('Start a cash game'),
            ),
          ],
        ),
      );
    }

    final settings = session.settings;
    final players = session.players;
    final totalInPlay = session.totalInPlay;
    final totalBuyIns = session.totalBuyIns;
    final totalCashedOut = session.totalCashedOut;
    final activePlayers = players.where((p) => !p.isCashedOut).toList();
    final elapsed = session.elapsed;
    final elapsedH = elapsed.inHours;
    final elapsedM = elapsed.inMinutes % 60;
    final currency = settings.currency;

    final isNewPlayer = _action?.type == _CashActionType.buyIn && _action?.playerId == null;
    final actionTitle = isNewPlayer
        ? 'Add new player'
        : _action?.type == _CashActionType.buyIn
            ? 'Buy in / rebuy'
            : _action?.type == _CashActionType.cashOut
                ? 'Cash out'
                : '';

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settings.name, style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Live · ${elapsedH}h ${elapsedM}m · $currency${_num(settings.smallBlind)}/$currency${_num(settings.bigBlind)}',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => setState(() => _showReconcile = true),
                    child: const Text('⚖ Reconcile'),
                  ),
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.danger,
                    onPressed: () => setState(() => _showEndModal = true),
                    child: const Text('End game'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _CashStatCard(
                  label: 'Total in',
                  value: Formatters.money(currency, totalBuyIns),
                  valueColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CashStatCard(label: 'In play', value: Formatters.money(currency, totalInPlay)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CashStatCard(
                  label: 'Cashed out',
                  value: Formatters.money(currency, totalCashedOut),
                  valueColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Players
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Text('${players.length} Players', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _openAction(const _CashAction(_CashActionType.buyIn, null)),
                        child: const Text('+ Add player'),
                      ),
                    ],
                  ),
                ),
                for (final p in players)
                  Opacity(
                    opacity: p.isCashedOut ? 0.5 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: AppColors.avatarPalette.first, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase(),
                            style: AppTypography.bodyXs.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                              Text(
                                'In: ${Formatters.money(currency, p.totalBuyIns)}${p.buyInCount > 1 ? ' (${p.buyInCount}×)' : ''}',
                                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (p.isCashedOut)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const AppBadge(label: 'Cashed out', variant: AppBadgeVariant.muted),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.signedMoney(currency, p.net),
                                style: AppTypography.monoXs.copyWith(
                                  color: p.net >= 0 ? AppColors.success : AppColors.destructive,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            Formatters.money(currency, p.stack),
                            style: AppTypography.monoSm.copyWith(fontWeight: FontWeight.w600),
                          ),
                        if (!p.isCashedOut) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: [
                              AppButton(
                                size: AppButtonSize.sm,
                                variant: AppButtonVariant.secondary,
                                onPressed: () => _openAction(
                                  _CashAction(_CashActionType.buyIn, p.id),
                                  preset: settings.minBuyIn,
                                ),
                                child: const Text('+\$'),
                              ),
                              AppButton(
                                size: AppButtonSize.sm,
                                variant: AppButtonVariant.ghost,
                                onPressed: () => _openAction(
                                  _CashAction(_CashActionType.cashOut, p.id),
                                  preset: p.stack,
                                ),
                                child: const Text('Out'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Action modal
          if (_action != null)
            AppModal(
              open: true,
              onClose: () => setState(() => _action = null),
              title: actionTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNewPlayer)
                    AppTextField(
                      controller: _newPlayerName,
                      placeholder: 'Player name',
                      autofocus: true,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _amount,
                    label: 'Amount ($currency)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    textStyle: AppTypography.monoXl,
                    autofocus: !isNewPlayer,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _action!.type == _CashActionType.buyIn
                        ? 'Min $currency${_num(settings.minBuyIn)} · Max $currency${_num(settings.maxBuyIn)}'
                        : 'Current stack: $currency${_num(players.where((p) => p.id == _action!.playerId).firstOrNull?.stack ?? 0)}',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final a in [settings.minBuyIn, settings.minBuyIn * 2, settings.maxBuyIn])
                        InkWell(
                          onTap: () => setState(() => _amount.text = a.toString()),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '$currency${_num(a)}',
                              style: AppTypography.monoSm,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(() => _action = null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          onPressed: () => _confirmAction(app),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Reconcile modal
          if (_showReconcile)
            AppModal(
              open: true,
              onClose: () => setState(() => _showReconcile = false),
              title: 'Reconciliation',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chips in play must equal total buy-ins minus cashed out. Any discrepancy needs to be resolved before ending the game.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _ReconcileRow(label: 'Total buy-ins', value: Formatters.money(currency, totalBuyIns)),
                        const SizedBox(height: AppSpacing.xs),
                        _ReconcileRow(
                          label: 'Cashed out',
                          value: '- ${Formatters.money(currency, totalCashedOut)}',
                          valueColor: AppColors.success,
                        ),
                        const Divider(color: AppColors.border, height: AppSpacing.lg),
                        _ReconcileRow(label: 'Expected in play', value: Formatters.money(currency, session.expectedInPlay)),
                        const SizedBox(height: AppSpacing.xs),
                        _ReconcileRow(label: 'Actual in play', value: Formatters.money(currency, totalInPlay)),
                        const Divider(color: AppColors.border, height: AppSpacing.lg),
                        _ReconcileRow(
                          label: 'Difference',
                          value: Formatters.money(currency, session.difference.abs()),
                          valueColor: session.difference.abs() < 0.01 ? AppColors.success : AppColors.destructive,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  if (settings.rakePct > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Center(
                        child: Text(
                          'Rake (${settings.rakePct}%): ${Formatters.money(currency, totalBuyIns * settings.rakePct / 100)}',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => setState(() => _showReconcile = false),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          // End game modal
          if (_showEndModal)
            AppModal(
              open: true,
              onClose: () => setState(() => _showEndModal = false),
              title: 'End cash game?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Make sure all players have cashed out before ending. The results will be saved to history.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                  if (activePlayers.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${activePlayers.length} player${activePlayers.length > 1 ? 's' : ''} still active — they should cash out first.',
                        style: AppTypography.bodySm.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(() => _showEndModal = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.danger,
                          onPressed: () => _endGame(app),
                          child: const Text('End game'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _num(double value) => value == value.roundToDouble() ? value.round().toString() : value.toString();
}

class _CashStatCard extends StatelessWidget {
  const _CashStatCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.monoLg.copyWith(fontWeight: FontWeight.w700, color: valueColor ?? AppColors.foreground),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _ReconcileRow extends StatelessWidget {
  const _ReconcileRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
        const Spacer(),
        Text(
          value,
          style: AppTypography.monoSm.copyWith(
            color: valueColor ?? AppColors.foreground,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
