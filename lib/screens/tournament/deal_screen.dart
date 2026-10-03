import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/payouts_engine.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';

/// Section heading, sized like the rest of the app's in-page headings.
Widget _sectionTitle(String text) => Text(
  text,
  style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600),
);

/// "1st", "2nd", "3rd" — the prize badges and the confirm sheet both need it,
/// and "1st." is what the spec writes.
String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// C-deal — the deal screen. Spec route `/t/:id/deal`, host only.
///
/// Shows the stacks still in, the prizes still to pay, and the three
/// automatic splits side by side, then the host's own numbers. The spec
/// requires ICM and chip chop to be shown TOGETHER (C-deal rules) so the
/// reason ICM matters is visible rather than asserted, which is why the
/// alternatives are not behind a toggle.
class DealScreen extends StatefulWidget {
  const DealScreen({super.key});

  @override
  State<DealScreen> createState() => _DealScreenState();
}

class _DealScreenState extends State<DealScreen> {
  /// Which automatic split seeds the editable fields, and the player's
  /// amounts. Null until the first build seeds them, so a host who never
  /// touches a field still confirms a real, visible number.
  Map<String, double>? _agreed;
  String? _seededFrom;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    if (game == null) return _NoGame(message: 'There is no game to deal.');
    if (!app.isAdmin) {
      return _NoGame(
        message: 'Only the host of this game can agree a deal.',
        icon: Icons.lock_outline,
      );
    }
    if (game.activePlayers.isEmpty) {
      return _NoGame(
        message: 'Everyone has already been paid out, so there is nothing '
            'left to split.',
        icon: Icons.done_all,
      );
    }

    final stacks = _stacksOnTable(game);
    final prizes = _prizesStillToPay(game);
    final leftToPay = app.dealTotalLeftToPay();
    final cmp = PayoutsEngine.compareDeals(stacks, prizes);

    // Seed on the first build, and again only if the host switches which
    // split the fields are prefilled from — never on a rebuild, which would
    // discard numbers they have already typed.
    final players = _onTableInFinishOrder(game);
    final agreed = _agreedFor(cmp, players);
    final agreedTotal =
        agreed.values.fold<double>(0, (sum, a) => sum + a);
    final mismatch = PayoutsEngine.dealAmountsError(agreedTotal, leftToPay);
    final leader = players.isEmpty ? null : players.first;

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.hostDashboard),
            title: 'Deal',
            subtitle: '${players.length} still in · deal at '
                '${players.length} players',
          ),
          const SizedBox(height: AppSpacing.lg),

          _StacksCard(
            players: players,
            leader: leader,
            game: game,
            app: app,
          ),
          const SizedBox(height: AppSpacing.md),

          if (prizes.isNotEmpty)
            _PrizesLeftCard(prizes: prizes, total: leftToPay),
          const SizedBox(height: AppSpacing.lg),

          _sectionTitle('How to split it'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Every split gives the same money in total. ICM and chip chop are '
            'both shown because they rarely agree — where they do, the short '
            'stack is not being paid fairly.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SplitsRow(
            players: players,
            comparison: cmp,
            selected: _seededFrom,
            onSelect: (source) => setState(() {
              _seededFrom = source;
              _agreed = _fromSource(cmp, players, source);
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),

          _sectionTitle('Agreed amounts'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pre-filled from the ICM split, rounded to whole amounts that add '
            'up exactly. Edit any of them.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (mismatch != null) ...[
            AppAlertBanner(type: AppAlertType.error, message: mismatch),
            const SizedBox(height: AppSpacing.md),
          ],
          _AgreedFields(
            players: players,
            amounts: agreed,
            onChanged: (id, value) => setState(() {
              final next = Map<String, double>.from(agreed);
              if (value == null) {
                next.remove(id);
              } else {
                next[id] = value;
              }
              _agreed = next;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_error != null) ...[
            AppAlertBanner(type: AppAlertType.error, message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            disabled: mismatch != null,
            onPressed: () => _confirm(context, app, players, agreed),
            child: const Text('Confirm deal & end'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'KO bounties are not part of a deal — they were already paid at '
            'each knockout.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// The players a deal covers, ordered the way the results screen reads them:
  /// the existing finish order first (whoever already busted, by elimination
  /// position), then the survivors by chips, so index 0 is "1st on chips".
  ///
  /// This deliberately reuses the same ordering the completion validator
  /// derives positions from, because the confirm writes a finish order — the
  /// two must not disagree about who is 1st.
  List<Player> _onTableInFinishOrder(LiveGame game) {
    final byId = {for (final p in game.players) p.id: p};
    final out = <Player>[];
    final seen = <String>{};
    for (final id in game.finishOrder) {
      final p = byId[id];
      if (p == null || p.eliminated) continue;
      if (!seen.add(id)) continue;
      out.add(p);
    }
    return out
      ..sort((a, b) => (b.stack ?? 0).compareTo(a.stack ?? 0));
  }

  /// Chip counts for the players still in, in [players] order.
  List<int> _stacksOnTable(LiveGame game) =>
      [for (final p in _onTableInFinishOrder(game)) p.stack ?? 0];

  /// The prizes the places on this table would pay, in whole currency units.
  ///
  /// Fewer players than the ladder has prizes means only the top places pay,
  /// so this must truncate rather than scale down the whole ladder — a third
  /// player cannot be paid 4th place money.
  List<int> _prizesStillToPay(LiveGame game) {
    final n = game.activePlayers.length;
    final prizes = game.structure.prizes;
    if (prizes.isEmpty) return const [];
    return [for (final p in prizes.take(n)) p.amount ~/ 100];
  }

  /// Buy-in, for §F2.2's cash unit. Read from the live game rather than held
  /// in state, so a structure edited after the screen opened still rounds to
  /// the right unit.
  int get _buyIn => context.read<AppProvider>().currentGame?.settings.buyIn ?? 0;

  Map<String, double> _agreedFor(DealComparison cmp, List<Player> players) {
    if (_agreed != null) return _agreed!;
    return _fromSource(cmp, players, _seededFrom ?? 'icm');
  }

  /// The editable figures for a chosen split.
  ///
  /// Amounts are ROUNDED to whole units here, because the spec has the host
  /// edit whole currency units that add up exactly. The engine's
  /// [PayoutsEngine.roundDeal] does that rounding properly — largest
  /// remainder, capped at the top prize — so it is used rather than a naive
  /// `round()` on each, which would leave the fields a cent or two short of
  /// the pot and block the confirm on a night the host did nothing wrong.
  Map<String, double> _fromSource(
    DealComparison cmp,
    List<Player> players,
    String source,
  ) {
    if (players.isEmpty) return const {};
    final raw = switch (source) {
      'chip' => cmp.chip,
      'equal' => cmp.equal,
      _ => cmp.icm,
    };
    final rawCents = [for (final v in raw) (v * 100).round()];
    if (rawCents.length != players.length) {
      return {
        for (var i = 0; i < players.length; i++)
          players[i].id: i < raw.length ? raw[i] : 0,
      };
    }
    final totalCents = rawCents.fold<int>(0, (s, v) => s + v);
    final cap = rawCents.reduce((a, b) => a > b ? a : b);
    List<int> rounded;
    try {
      rounded = PayoutsEngine.roundDeal(
        rawCents,
        // §F2.2's cash unit for this buy-in, in cents — the same unit the
        // payout ladder itself was rounded to, so a seeded deal lands on the
        // same figures the host would have seen on the payouts screen.
        PayoutsEngine.cashUnit(_buyIn) * 100,
        totalCents,
        cap,
      );
    } on ArgumentError {
      // Only reachable if the cap check fails, which a split of its own totals
      // cannot do. Fall back to the unrounded figures so the host still sees
      // real numbers rather than an empty form.
      rounded = rawCents;
    }
    return {
      for (var i = 0; i < players.length; i++)
        players[i].id: rounded[i] / 100,
    };
  }

  Future<void> _confirm(
    BuildContext context,
    AppProvider app,
    List<Player> players,
    Map<String, double> agreed,
  ) async {
    final error = PayoutsEngine.dealAmountsError(
      agreed.values.fold<double>(0, (s, a) => s + a),
      app.dealTotalLeftToPay(),
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final leader = players.isEmpty ? null : players.first;
    final ok = await _ConfirmDealSheet.show(
      context,
      leaderName: leader?.name ?? 'Nobody',
      leaderChips: leader?.stack ?? 0,
      count: players.length,
    );
    if (ok != true || !context.mounted) return;

    // The finish order is the provider's to derive — it is first-out-first
    // and a place is its index from the end, which a screen building it from
    // the table alone would get backwards and would drop any earlier busts.
    final refusal = app.confirmDealAndEnd(amountsByPlayerId: agreed);
    if (refusal != null) {
      setState(() => _error = refusal);
      return;
    }
    if (context.mounted) context.go(RoutePaths.resultPodium);
  }
}

class _NoGame extends StatelessWidget {  const _NoGame({required this.message, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.hostDashboard),
            title: 'Deal',
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                IconTile(icon: icon, size: 56, tone: IconTileTone.neutral),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// C-deal item 1 — the stacks still on the table, with steppers, Count by colour, and Add player.
class _StacksCard extends StatelessWidget {
  const _StacksCard({
    required this.players,
    required this.leader,
    required this.game,
    required this.app,
  });

  final List<Player> players;
  final Player? leader;
  final LiveGame game;
  final AppProvider app;

  void _showCountByColourDialog(BuildContext context, Player player) {
    final chipSet = game.settings.chipSet;
    final counts = <int, int>{};
    for (final c in chipSet) {
      counts[c.value] = 0;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int total = 0;
          for (final entry in counts.entries) {
            total += entry.key * entry.value;
          }

          return AlertDialog(
            backgroundColor: AppColors.card,
            title: Text('Count chips: ${player.name}', style: AppTypography.bodyBold),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final chip in chipSet)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Color(chip.hex),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${chip.color} (${Formatters.chips(chip.value)})',
                              style: AppTypography.bodySm,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: (counts[chip.value] ?? 0) > 0
                                ? () => setModalState(() {
                                      counts[chip.value] = (counts[chip.value] ?? 0) - 1;
                                    })
                                : null,
                          ),
                          Text('${counts[chip.value] ?? 0}', style: AppTypography.monoSm),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => setModalState(() {
                              counts[chip.value] = (counts[chip.value] ?? 0) + 1;
                            }),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total counted:', style: AppTypography.bodyBold),
                      Text(Formatters.chips(total), style: AppTypography.mono(weight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: TextStyle(color: AppColors.mutedForeground)),
              ),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () {
                  app.updatePlayerStack(player.id, total);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Apply total'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final stackCtrl = TextEditingController(text: '${game.structure.startingStack}');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Add player to deal', style: AppTypography.bodyBold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Player name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stackCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting chips'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          AppButton(
            size: AppButtonSize.sm,
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final stack = int.tryParse(stackCtrl.text.trim()) ?? game.structure.startingStack;
                app.checkInPlayer(name);
                final p = app.currentGame?.players.where((x) => x.name.toLowerCase() == name.toLowerCase()).firstOrNull;
                if (p != null) {
                  app.updatePlayerStack(p.id, stack);
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = game.settings.chipSet.isNotEmpty ? game.settings.chipSet.first.value : 100;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Stacks on the table', style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600)),
              ),
              if (leader != null) ...[
                AppBadge(
                  label: '1st on chips',
                  variant: AppBadgeVariant.green,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => _showAddPlayerDialog(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_outlined, size: 14),
                    SizedBox(width: 4),
                    Text('Add player'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < players.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == players.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      players[i].name,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: i == 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Count by colour',
                    child: IconButton(
                      icon: const Icon(Icons.colorize_outlined, size: 16),
                      color: AppColors.mutedForeground,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _showCountByColourDialog(context, players[i]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      final cur = players[i].stack ?? 0;
                      app.updatePlayerStack(players[i].id, max(0, cur - step));
                    },
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 64),
                    alignment: Alignment.center,
                    child: Text(
                      Formatters.chips(players[i].stack ?? 0),
                      style: AppTypography.monoSm.copyWith(
                        fontWeight: i == 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      final cur = players[i].stack ?? 0;
                      app.updatePlayerStack(players[i].id, cur + step);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// C-deal item 2 — the prizes still to pay, from the payout plan.
class _PrizesLeftCard extends StatelessWidget {
  const _PrizesLeftCard({required this.prizes, required this.total});

  final List<int> prizes;
  final double total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prizes still to pay', style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < prizes.length; i++)
                AppBadge(
                  label: '${_ordinal(i + 1)} ${Formatters.money('', prizes[i].toDouble())}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${Formatters.money('', total)} left to pay',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// C-deal item 3 — ICM, chip chop and equal chop together, side by side on a
/// tablet and stacked on a phone.
class _SplitsRow extends StatelessWidget {
  const _SplitsRow({
    required this.players,
    required this.comparison,
    required this.selected,
    required this.onSelect,
  });

  final List<Player> players;
  final DealComparison comparison;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SplitCard(
        title: 'ICM split',
        subtitle: 'Recommended',
        amounts: comparison.icm,
        players: players,
        selected: (selected ?? 'icm') == 'icm',
        recommended: true,
        onTap: () => onSelect('icm'),
      ),
      _SplitCard(
        title: 'Chip chop',
        subtitle: 'Min-cash first',
        amounts: comparison.chip,
        players: players,
        selected: selected == 'chip',
        onTap: () => onSelect('chip'),
      ),
      _SplitCard(
        title: 'Equal chop',
        subtitle: 'Everyone the same',
        amounts: comparison.equal,
        players: players,
        selected: selected == 'equal',
        onTap: () => onSelect('equal'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                cards[i],
              ],
            ],
          );
        }
        // IntrinsicHeight, for the same reason pace_cards.dart needs it: in a
        // scroll view the Row's height is unbounded, so a plain stretch asks
        // its children to be infinitely tall.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.title,
    required this.subtitle,
    required this.amounts,
    required this.players,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final String title;
  final String subtitle;
  final List<double> amounts;
  final List<Player> players;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600),
                ),
              ),
              if (recommended)
                AppBadge(
                  label: 'Rec',
                  variant: AppBadgeVariant.accent,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < players.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == players.length - 1 ? 0 : AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      players[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    i < amounts.length
                        ? Formatters.money('', amounts[i])
                        : '—',
                    style: AppTypography.bodySm,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// C-deal item 4 — one field per player, seeded with the chosen split.
class _AgreedFields extends StatelessWidget {
  const _AgreedFields({
    required this.players,
    required this.amounts,
    required this.onChanged,
  });

  final List<Player> players;
  final Map<String, double> amounts;
  final void Function(String id, double? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < players.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == players.length - 1 ? 0 : AppSpacing.md,
              ),
              child: _AmountField(
                key: ValueKey('deal-${players[i].id}'),
                player: players[i],
                value: amounts[players[i].id],
                onChanged: (v) => onChanged(players[i].id, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    super.key,
    required this.player,
    required this.value,
    required this.onChanged,
  });

  final Player player;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller =
      TextEditingController(text: _text(widget.value));

  /// C-deal item 4 rounds to whole units, so the field takes whole units and
  /// a two-digit keyboard. Free-text cents here would let the host type a
  /// value the confirm then rejects with no way to see why.
  static String _text(double? v) {
    if (v == null) return '';
    final cents = (v * 100).round();
    return cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(_AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt a new value when the parent replaced it (the host picked a
    // different split). Not while this field is being typed into, or every
    // keystroke would be undone by the rebuild that followed it.
    if (widget.value != oldWidget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextField(
            controller: _controller,
            label: widget.player.name,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (raw) {
              final cleaned = raw.trim();
              if (cleaned.isEmpty) {
                widget.onChanged(null);
                return;
              }
              widget.onChanged(double.tryParse(cleaned));
            },
          ),
        ),
      ],
    );
  }
}

/// C-deal item 5 — the confirm sheet listing the leader on chips.
class _ConfirmDealSheet extends StatelessWidget {
  const _ConfirmDealSheet({
    required this.leaderName,
    required this.leaderChips,
    required this.count,
  });

  final String leaderName;
  final int leaderChips;
  final int count;

  static Future<bool?> show(
    BuildContext context, {
    required String leaderName,
    required int leaderChips,
    required int count,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: _ConfirmDealSheet(
            leaderName: leaderName,
            leaderChips: leaderChips,
            count: count,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('End the tournament?', style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '1st on chips — $leaderName — ${Formatters.chips(leaderChips)}',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This records the agreed split and shows the final results. It '
              'can be undone from the host dashboard.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              fullWidth: true,
              size: AppButtonSize.lg,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm deal & end'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              fullWidth: true,
              size: AppButtonSize.lg,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
          ],
        ),
      ),
    );
  }
}
