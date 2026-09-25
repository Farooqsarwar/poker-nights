import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/cash_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/cash_settlement_panel.dart';
import '../../widgets/squircle_icon_button.dart';

enum _CashActionType { buyIn, cashOut }

class _CashAction {
  const _CashAction(this.type, this.playerId);

  final _CashActionType type;
  final String? playerId;
}

/// Live cash game dashboard strictly matching D2_CashLive mobile-first design.
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
  bool _forceEnd = false;
  final TextEditingController _unresolvedNote = TextEditingController();

  String? _editPlayerId;
  final _editStack = TextEditingController();
  final _editTotal = TextEditingController();
  final _editBuyInCount = TextEditingController();
  final _editCashedOut = TextEditingController();
  bool _editHasCashedOut = false;

  @override
  void dispose() {
    _amount.dispose();
    _newPlayerName.dispose();
    _editStack.dispose();
    _editTotal.dispose();
    _editBuyInCount.dispose();
    _editCashedOut.dispose();
    _unresolvedNote.dispose();
    super.dispose();
  }

  void _openEdit(CashPlayer p) {
    setState(() {
      _editPlayerId = p.id;
      _editStack.text = _num(p.stack);
      _editTotal.text = _num(p.totalBuyIns);
      _editBuyInCount.text = '${p.buyInCount}';
      _editCashedOut.text = _num(p.cashedOut);
      _editHasCashedOut = p.hasCashedOut;
      _forceEnd = false;
    });
  }

  void _saveEdit(AppProvider app) {
    final id = _editPlayerId;
    if (id == null) return;
    final stack = num.tryParse(_editStack.text.trim())?.toDouble();
    final total = num.tryParse(_editTotal.text.trim())?.toDouble();
    final count = num.tryParse(_editBuyInCount.text.trim())?.toInt();
    final cashedOut = num.tryParse(_editCashedOut.text.trim())?.toDouble();
    if (stack == null || total == null || count == null || cashedOut == null) {
      return;
    }
    app.cashEditPlayer(
      id,
      stack: stack,
      totalBuyIns: total,
      buyInCount: count,
      cashedOut: cashedOut,
      hasCashedOut: _editHasCashedOut,
    );
    setState(() => _editPlayerId = null);
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

    if (action.type == _CashActionType.buyIn && amt <= 0) return;

    String? error;
    if (action.type == _CashActionType.buyIn) {
      final pid = action.playerId;
      if (pid != null) {
        error = app.cashBuyIn(pid, amt);
      } else if (_newPlayerName.text.trim().isNotEmpty) {
        error = app.cashBuyIn(_newPlayerName.text.trim(), amt, isNew: true);
        if (error == null) _newPlayerName.clear();
      }
    } else if (action.type == _CashActionType.cashOut &&
        action.playerId != null) {
      app.cashCashOut(action.playerId!, amt);
    }

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
      return;
    }

    setState(() {
      _action = null;
      _amount.clear();
    });
  }

  void _endGame(AppProvider app) {
    final error = app.endCashGame(
      unresolvedNote: _forceEnd ? _unresolvedNote.text.trim() : null,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.destructive),
      );
      return;
    }
    setState(() => _showEndModal = false);
    context.go(RoutePaths.history);
  }

  void _showSessionMenu(BuildContext context, AppProvider app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session Options',
                  style: AppTypography.display(
                    size: 20,
                    weight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.scale_outlined,
                    color: AppColors.foreground,
                  ),
                  title: Text(
                    'Reconcile ledger',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() => _showReconcile = true);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.person_add_outlined,
                    color: AppColors.foreground,
                  ),
                  title: Text(
                    'Add new player',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _openAction(const _CashAction(_CashActionType.buyIn, null));
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.stop_circle_outlined,
                    color: AppColors.destructiveText,
                  ),
                  title: Text(
                    'End game',
                    style: TextStyle(color: AppColors.destructiveText),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() => _showEndModal = true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlayerActionSheet(
    BuildContext context,
    CashPlayer player,
    AppProvider app,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppAvatar(name: player.name, size: AppAvatarSize.lg),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: AppTypography.display(
                              size: 18,
                              weight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            'In ${player.totalBuyIns.toInt()} · Stack ${player.stack.toInt()}',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!player.isCashedOut) ...[
                  ListTile(
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.successText,
                    ),
                    title: Text(
                      'Buy-in / Rebuy',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openAction(
                        _CashAction(_CashActionType.buyIn, player.id),
                        preset: app.cashSession?.settings.minBuyIn,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.monetization_on_outlined,
                      color: AppColors.warningText,
                    ),
                    title: Text(
                      'Cash out',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openAction(
                        _CashAction(_CashActionType.cashOut, player.id),
                        preset: player.stack,
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: AppColors.foreground),
                  title: Text(
                    'Edit player stack & details',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openEdit(player);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (!app.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    final session = app.cashSession;

    if (session == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'No active cash game.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
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
    final elapsed = session.elapsed;
    final elapsedH = elapsed.inHours;
    final elapsedM = elapsed.inMinutes % 60;
    final currency = settings.currency;

    final isNewPlayer =
        _action?.type == _CashActionType.buyIn && _action?.playerId == null;
    final actionTitle = isNewPlayer
        ? 'Add new player'
        : _action?.type == _CashActionType.buyIn
        ? 'Buy in / rebuy'
        : _action?.type == _CashActionType.cashOut
        ? 'Cash out'
        : '';

    return AppPage(
      maxWidth: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: LIVE · 1 / 2 & Squircle ⋮ button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.successText,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE · ${_num(settings.smallBlind)} / ${_num(settings.bigBlind)}',
                    style: TextStyle(
                      color: AppColors.secondaryForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SquircleIconButton(
                icon: Icons.more_vert,
                iconSize: 22,
                iconColor: AppColors.mutedForeground,
                tooltip: 'Session options',
                onPressed: () => _showSessionMenu(context, app),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title: Cash session
          Text(
            'Cash session',
            style: AppTypography.display(
              size: 30,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),

          // 3 Metric Cards Row (players, in play, elapsed)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  value: '${players.length}',
                  label: 'players',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  value: Formatters.prize(totalInPlay.toInt()),
                  label: 'in play',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  value: '$elapsedH:${elapsedM.toString().padLeft(2, '0')}',
                  label: 'elapsed',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Expected in play & Difference Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expected in play',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      Formatters.prize(session.expectedInPlay.toInt()),
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Difference',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      session.difference == 0
                          ? '0'
                          : session.difference > 0
                          ? '+${session.difference.toInt()}'
                          : '${session.difference.toInt()}',
                      style: TextStyle(
                        color: session.difference >= 0
                            ? AppColors.successText
                            : AppColors.destructiveText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PLAYERS Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAYERS',
                style: AppTypography.bodyXs.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceHint,
                ),
              ),
              InkWell(
                onTap: () =>
                    _openAction(const _CashAction(_CashActionType.buyIn, null)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      color: AppColors.destructiveText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Player Cards List
          for (var i = 0; i < players.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPlayerCard(
                player: players[i],
                currency: currency,
                onTap: () => _showPlayerActionSheet(context, players[i], app),
              ),
            ),
          const SizedBox(height: 24),

          // Bottom Action Button: Cash out & settle
          InkWell(
            onTap: () => setState(() => _showReconcile = true),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Cash out & settle',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Modals & Panels
          if (_action != null)
            _buildActionModal(context, app, actionTitle, isNewPlayer, settings),
          if (_editPlayerId != null) _buildEditModal(context, app),
          if (_showReconcile) _buildReconcileModal(context, app, session),
          if (_showEndModal) _buildEndModal(context, app, session),
        ],
      ),
    );
  }

  static Widget _buildMetricCard({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.display(
                size: 26,
                weight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPlayerCard({
    required CashPlayer player,
    required String currency,
    required VoidCallback onTap,
  }) {
    final net = player.net;
    final netText = net > 0
        ? '+${net.toInt()}'
        : net < 0
        ? '${net.toInt()}'
        : '0';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            AppAvatar(name: player.name, size: AppAvatarSize.lg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'In ${player.totalBuyIns.toInt()} · ${player.buyInCount} buy-in${player.buyInCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (player.isCashedOut) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'OUT',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              netText,
              style: TextStyle(
                color: net >= 0
                    ? AppColors.successText
                    : AppColors.destructiveText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionModal(
    BuildContext context,
    AppProvider app,
    String actionTitle,
    bool isNewPlayer,
    CashSessionSettings settings,
  ) {
    return AppModal(
      open: true,
      title: actionTitle,
      onClose: () => setState(() {
        _action = null;
        _amount.clear();
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isNewPlayer) ...[
            AppTextField(
              controller: _newPlayerName,
              label: 'Player name',
              placeholder: 'Name',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            controller: _amount,
            label: 'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_action?.type == _CashActionType.buyIn) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () =>
                        _amount.text = '${settings.minBuyIn.toInt()}',
                    child: Text('Min (${settings.minBuyIn.toInt()})'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () =>
                        _amount.text = '${settings.maxBuyIn.toInt()}',
                    child: Text('Max (${settings.maxBuyIn.toInt()})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            fullWidth: true,
            onPressed: () => _confirmAction(app),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditModal(BuildContext context, AppProvider app) {
    final player = app.cashSession?.players
        .where((p) => p.id == _editPlayerId)
        .firstOrNull;
    return AppModal(
      open: true,
      title: 'Edit ${player?.name ?? 'Player'}',
      onClose: () => setState(() => _editPlayerId = null),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _editStack,
              label: 'Current Stack',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _editTotal,
              label: 'Total Buy-Ins',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _editBuyInCount,
              label: 'Buy-In Count',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _editCashedOut,
              label: 'Cashed Out',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Has cashed out',
                  style: TextStyle(color: AppColors.foreground),
                ),
                Switch(
                  value: _editHasCashedOut,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _editHasCashedOut = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              fullWidth: true,
              onPressed: () => _saveEdit(app),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconcileModal(
    BuildContext context,
    AppProvider app,
    CashSession session,
  ) {
    return AppModal(
      open: true,
      title: 'Settlement & Ledger',
      onClose: () => setState(() => _showReconcile = false),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CashSettlementPanel(
              players: session.players,
              tier: app.premiumTier,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              variant: AppButtonVariant.danger,
              fullWidth: true,
              onPressed: () {
                setState(() {
                  _showReconcile = false;
                  _showEndModal = true;
                });
              },
              child: const Text('End Game Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndModal(
    BuildContext context,
    AppProvider app,
    CashSession session,
  ) {
    final diff = session.difference;
    return AppModal(
      open: true,
      title: 'End cash game?',
      onClose: () => setState(() => _showEndModal = false),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (diff.abs() > 0.01) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.destructive),
                ),
                child: Text(
                  'Difference of ${Formatters.signedMoney(session.settings.currency, diff)}. Table does not reconcile.',
                  style: TextStyle(color: AppColors.destructiveText),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Checkbox(
                    value: _forceEnd,
                    onChanged: (v) => setState(() => _forceEnd = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Force end anyway with note',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                  ),
                ],
              ),
              if (_forceEnd) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _unresolvedNote,
                  label: 'Note',
                  placeholder: 'Explain discrepancy',
                ),
              ],
            ] else ...[
              Text(
                'All stacks reconcile perfectly. Would you like to finish this session?',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              variant: AppButtonVariant.danger,
              fullWidth: true,
              onPressed: diff.abs() <= 0.01 || _forceEnd
                  ? () => _endGame(app)
                  : null,
              child: const Text('Confirm End Game'),
            ),
          ],
        ),
      ),
    );
  }

  static String _num(num n) => n % 1 == 0 ? '${n.toInt()}' : '$n';
}
