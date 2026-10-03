import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/glass_styles.dart';

/// Record finish order mirroring the web `CompleteTournamentPage`.
class CompleteTournamentScreen extends StatefulWidget {
  const CompleteTournamentScreen({super.key});

  @override
  State<CompleteTournamentScreen> createState() =>
      _CompleteTournamentScreenState();
}

class _CompleteTournamentScreenState extends State<CompleteTournamentScreen> {
  final List<String> _order = [];
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final game = context.read<AppProvider>().currentGame;
    if (game != null && game.activePlayers.length == 1) {
      _order.add(game.activePlayers.first.id);
    }
  }

  void _finishPlayer(String playerId) {
    setState(() {
      if (!_order.contains(playerId)) _order.add(playerId);
    });
  }

  void _undo() {
    if (_order.isEmpty) return;
    setState(() => _order.removeLast());
  }

  void _moveOrder(int from, int to) {
    if (from < 0 || from >= _order.length || to < 0 || to >= _order.length) return;
    setState(() {
      final id = _order.removeAt(from);
      _order.insert(to, id);
    });
  }

  void _confirm(AppProvider app) {
    // finishOrder is "first-out first": players already eliminated during play
    // (tracked by eliminationPos) come first, then the tapped survivors.
    final game = app.currentGame;
    final eliminated = game!.players.where((p) => p.eliminated).toList()
      ..sort(
        (a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0),
      );
    final ok = app.recordFinishOrder(
      [...eliminated.map((p) => p.id), ..._order],
    );
    if (!ok) {
      // Surface why finishing failed instead of falsely showing "complete".
      final msg = app.completionError ?? 'Could not finish the tournament.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() => _confirmed = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go(RoutePaths.resultPodium);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Spec §3.3: Only admin can complete a tournament.
    if (!app.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Host access required.')),
      );
    }

    final game = app.currentGame;

    if (game == null) {
      // No game in provider — redirect back to dashboard instead of
      // showing a blank screen dead-end.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.hostDashboard);
      });
      return const SizedBox.shrink();
    }

    final activePlayers = game.activePlayers;
    final prizes = game.structure.prizes;

    // Players eliminated during play, in first-out order (their elimination
    // position is the count of active players remaining at the time).
    final eliminated = game.players.where((p) => p.eliminated).toList()
      ..sort(
        (a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0),
      );

    final unranked = activePlayers
        .where((p) => !_order.contains(p.id))
        .toList();
    final ranked = <_RankedPlayer>[
      for (final p in eliminated)
        _RankedPlayer(
          player: p,
          pos: p.eliminationPos ?? activePlayers.length + 1,
          prize: _prizeFor(prizes, p.eliminationPos ?? 0),
        ),
      for (var i = 0; i < _order.length; i++)
        _RankedPlayer(
          player: game.players.where((p) => p.id == _order[i]).firstOrNull,
          pos: activePlayers.length - i,
          prize: _prizeFor(prizes, activePlayers.length - i),
        ),
    ];

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppBackButton(
                label: 'Back to dashboard',
                onPressed: () => context.go(RoutePaths.hostDashboard),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Finish Order',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tap players in order of elimination (first-out first)',
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
          if (_confirmed)
            AppCard(
              glow: true,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: AppFontSizes.displayLg,
                    color: AppColors.icon,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Tournament Complete!',
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Loading results\u2026',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Still playing
            if (unranked.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Still playing (${unranked.length})',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final p in unranked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: InkWell(
                          onTap: () => _finishPlayer(p.id),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.avatarPalette.first,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p.name.trim().isEmpty
                                        ? '?'
                                        : p.name.trim()[0].toUpperCase(),
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.foreground,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'tap to finish',
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: AppColors.icon,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (unranked.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Center(
                          child: Text(
                            'Last player \u2014 tap to set as winner!',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.successText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // Finish order
            if (ranked.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Finish order',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _undo,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.undo,
                                size: 14,
                                color: AppColors.destructive,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Undo last',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.destructiveText,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final r in ranked.reversed)
                      if (r.player != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: Glass.solidTint(AppColors.muted),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: r.pos <= 3
                                      ? Center(
                                          child: MedalIcon(
                                            r.pos,
                                            size: AppFontSizes.xl,
                                          ),
                                        )
                                      : Text(
                                          '#${r.pos}',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyXs.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    r.player?.name ?? 'Unknown',
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (r.player != null && _order.contains(r.player!.id)) ...[
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward, size: 14),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: 'Move up',
                                    onPressed: _order.indexOf(r.player!.id) < _order.length - 1
                                        ? () => _moveOrder(
                                              _order.indexOf(r.player!.id),
                                              _order.indexOf(r.player!.id) + 1,
                                            )
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward, size: 14),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: 'Move down',
                                    onPressed: _order.indexOf(r.player!.id) > 0
                                        ? () => _moveOrder(
                                              _order.indexOf(r.player!.id),
                                              _order.indexOf(r.player!.id) - 1,
                                            )
                                        : null,
                                  ),
                                ],
                                if (r.prize != null)
                                  Text(
                                    Formatters.chips(r.prize!.amount),
                                    style: AppTypography.monoSm.copyWith(
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // Prize breakdown
            if (prizes.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Prize distribution (host only)',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        if (unranked.isEmpty)
                          InkWell(
                            onTap: () {
                              showAppModal(
                                context: context,
                                title: 'Edit Deal / Chop',
                                child: _EditPrizesModal(
                                  initialPrizes: prizes,
                                  onSave: (newPrizes) => app.updatePrizes(newPrizes),
                                ),
                              );
                            },
                            child: Text(
                              'Edit Deal/Chop',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.primaryText,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < prizes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _placeName(prizes[i].place),
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.chips(prizes[i].amount),
                              style: AppTypography.monoSm.copyWith(
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: unranked.isEmpty ? () => _confirm(app) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: AppColors.icon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unranked.isEmpty
                        ? 'Record results'
                        : '${unranked.length} player${unranked.length > 1 ? 's' : ''} left to rank',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _placeName(int place) {
    if (place % 100 >= 11 && place % 100 <= 13) return '${place}th place';
    return switch (place % 10) {
      1 => '${place}st place',
      2 => '${place}nd place',
      3 => '${place}rd place',
      _ => '${place}th place',
    };
  }

  Prize? _prizeFor(List<Prize> prizes, int pos) {
    if (pos <= 0) return null;
    return prizes.where((p) => p.place == pos).firstOrNull;
  }
}

class _RankedPlayer {
  const _RankedPlayer({
    required this.player,
    required this.pos,
    required this.prize,
  });

  final Player? player;
  final int pos;
  final Prize? prize;
}


class _EditPrizesModal extends StatefulWidget {
  const _EditPrizesModal({required this.initialPrizes, required this.onSave});

  final List<Prize> initialPrizes;
  final void Function(List<Prize>) onSave;

  @override
  State<_EditPrizesModal> createState() => _EditPrizesModalState();
}

class _EditPrizesModalState extends State<_EditPrizesModal> {
  late final List<TextEditingController> _controllers;
  late int _pool;
  late int _placeCount;

  @override
  void initState() {
    super.initState();
    _placeCount = widget.initialPrizes.length.clamp(1, 6);
    _pool = widget.initialPrizes.fold<int>(0, (sum, p) => sum + p.amount);
    _controllers = widget.initialPrizes
        .map((p) => TextEditingController(text: p.amount.toString()))
        .toList();
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController(text: '$_pool'));
    }
  }

  void _applyPlaceCount(int places, {bool equalSplit = false}) {
    setState(() {
      _placeCount = places;
      final newAmounts = <int>[];
      if (equalSplit) {
        final share = _pool ~/ places;
        var rem = _pool - (share * places);
        for (var i = 0; i < places; i++) {
          newAmounts.add(share + (i == 0 ? rem : 0));
        }
      } else {
        // Standard ladder curves
        final fractions = switch (places) {
          1 => [1.0],
          2 => [0.65, 0.35],
          3 => [0.50, 0.30, 0.20],
          4 => [0.45, 0.25, 0.18, 0.12],
          5 => [0.40, 0.25, 0.18, 0.11, 0.06],
          _ => [0.38, 0.23, 0.16, 0.11, 0.07, 0.05],
        };
        var running = 0;
        for (var i = 0; i < places; i++) {
          if (i == places - 1) {
            newAmounts.add(_pool - running);
          } else {
            final amt = (_pool * fractions[i]).round();
            running += amt;
            newAmounts.add(amt);
          }
        }
      }

      for (final c in _controllers) {
        c.dispose();
      }
      _controllers.clear();
      for (final a in newAmounts) {
        _controllers.add(TextEditingController(text: a.toString()));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total prize pool: ${Formatters.prize(_pool)}',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Paid places (Spec A2):', style: AppTypography.bodyXs.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var p = 1; p <= 6; p++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AppButton(
                    size: AppButtonSize.sm,
                    variant: _placeCount == p ? AppButtonVariant.primary : AppButtonVariant.secondary,
                    onPressed: () => _applyPlaceCount(p),
                    child: Text('$p'),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => _applyPlaceCount(_placeCount, equalSplit: false),
                child: const Text('Ladder Split'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => _applyPlaceCount(_placeCount, equalSplit: true),
                child: const Text('Chop Equally'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Place ${i + 1}',
                    style: AppTypography.bodySm,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _controllers[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          onPressed: () {
            final newPrizes = <Prize>[];
            int totalNew = 0;
            for (var i = 0; i < _controllers.length; i++) {
              final amt = int.tryParse(_controllers[i].text.replaceAll(',', '')) ?? 0;
              totalNew += amt;
              newPrizes.add(Prize(place: i + 1, amount: amt));
            }

            if (totalNew != _pool && _pool > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Payouts sum to $totalNew, but the prize pool is $_pool.',
                  ),
                  backgroundColor: AppColors.destructive,
                ),
              );
              return;
            }

            widget.onSave(newPrizes);
            Navigator.of(context).pop();
          },
          child: const Text('Save Payouts'),
        ),
      ],
    );
  }
}
