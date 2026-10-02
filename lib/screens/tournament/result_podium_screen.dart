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
import '../../services/entitlements.dart';
import '../../utils/formatters.dart';
import '../../utils/share_card.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/medal_icon.dart';

class _PodiumResult {
  const _PodiumResult({
    required this.player,
    required this.pos,
    required this.prize,
  });

  final Player player;
  final int pos;
  final Prize? prize;
}

/// Results podium mirroring the web `ResultPodiumPage`.
class ResultPodiumScreen extends StatelessWidget {
  const ResultPodiumScreen({super.key, this.gameId});

  /// Id of the game to show; falls back to the current live game when null.
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = gameId != null ? app.gameById(gameId!) : app.currentGame;

    // Guard: Allow viewing results only when game is completed, or cancelled (admin only).
    // A null game means it was deleted; a non-terminal game means the user navigated here
    // manually while the tournament is still running. Spec §9.1: admin can view results
    // for both completed and cancelled tournaments to understand what happened.
    if (game == null) {
      return const AppEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Result unavailable',
        description: 'This game may have been deleted or is not finished.',
      );
    }

    final isAdminViewingCancelled =
        app.isAdmin && game.status == LiveGameStatus.cancelled;
    final isCompletedGame = game.status == LiveGameStatus.completed;

    if (!isCompletedGame && !isAdminViewingCancelled) {
      return const AppEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Result unavailable',
        description: 'This game may have been deleted or is not finished.',
      );
    }

    final finishOrder = game.finishOrder;
    final players = game.players;
    final prizes = game.structure.prizes;
    final user = app.user;

    // Individual payout amounts are private: only organisers see them
    // (checklist 14-042, 19-020). Public completed results carry no money.
    final showAmounts = app.isAdmin;

    // A game that ended on an agreed deal (C-deal) was not paid out on the
    // ladder, so the ladder's figures would be a fiction. The agreed amounts
    // are indexed to `finishOrder`, and this loop is already walking that list,
    // so entry `i` is the same player's slot in both.
    final dealAmounts = game.dealAmounts;

    final ranked = [
      for (var i = 0; i < finishOrder.length; i++)
        if (players.where((p) => p.id == finishOrder[i]).firstOrNull
            case final player?)
          _PodiumResult(
            player: player,
            pos: finishOrder.length - i,
            prize: dealAmounts != null
                // A deal is only ever agreed among the players still at the
                // table; everyone who busted earlier was paid from the plan
                // when they went out, so the ladder still speaks for them.
                ? (dealAmounts[i] > 0
                    ? Prize(
                        place: finishOrder.length - i,
                        amount: (dealAmounts[i] * 100).round(),
                      )
                    : null)
                : prizes
                    .where((pr) => pr.place == finishOrder.length - i)
                    .firstOrNull,
          ),
    ];
    // finishOrder is "first-out first" so ranked is worst-first. The podium
    // shows the top three (1st/2nd/3rd), not the first three entries.
    final podium = ranked.where((r) => r.pos <= 3).toList()
      ..sort((a, b) => a.pos.compareTo(b.pos));
    final myResult = ranked.where((r) => r.player.id == user?.id || (app.hasGuestSession && app.guestSession!.gameId == game.id && r.player.name == app.guestSession!.name)).firstOrNull;
    final totalRebuys = players.fold<int>(0, (s, p) => s + p.rebuys);

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // §C9 opens with "← - Share (top right)", above the FINAL RESULTS
          // pill. The control lives in the title bar rather than at the foot of
          // the page because that is where the spec puts it, and because on
          // iPad the share sheet pops from the tapping control (T93) — the
          // origin rect is read off this button's own box.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: AppBackButton(
                    tooltip: 'Back',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(RoutePaths.group);
                      }
                    },
                  ),
                ),
                const Spacer(),
                _ShareButton(
                  onShare: (buttonContext) =>
                      _share(context, buttonContext, app, game, showAmounts),
                ),
              ],
            ),
          ),
          // Hero header
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: AppFontSizes.displayLg,
                  color: AppColors.icon,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  game.settings.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.crimsonShimmer(
                    size: AppFontSizes.display,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${game.settings.date} · ${game.settings.location}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${game.settings.name} prize pool',
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Podium visual
          if (podium.isNotEmpty)
            SizedBox(
              // Fits the winner column (medal + 150px block + amounts) with
              // real font metrics; 220 overflowed by 3px on every viewport.
              height: 228,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final vi in [1, 0, 2])
                    if (vi < podium.length)
                      Expanded(
                        child: _PodiumSlot(
                          result: podium[vi],
                          isWinner: vi == 0,
                          showAmounts: showAmounts,
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          // §34a post-game recap — best-effort, not exhaustive (boundary #8):
          // one comeback, one fast bust, one knockout leader, whichever of the
          // three actually happened. `recapFor` rather than `gameRecap` since
          // this screen can show a past game via `gameId`, not just the open
          // one.
          if (!app.recapFor(game).isEmpty) ...[
            _RecapCard(recap: app.recapFor(game)),
            const SizedBox(height: AppSpacing.lg),
          ],
          // My result banner
          if (myResult != null)
            AppCard(
              glow: myResult.pos <= 3,
              borderColor: myResult.pos <= 3
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : null,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your result',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _medalFor(myResult.pos, AppFontSizes.xxxl),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myResult.pos == 1
                                  ? 'Winner!'
                                  : '${myResult.pos}${_ordinal(myResult.pos)} place',
                              style: AppTypography.display(
                                size: AppFontSizes.xl,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${players.length} players entered',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (myResult.prize != null && showAmounts)
                        Text(
                          Formatters.chips(myResult.prize!.amount),
                          style: AppTypography.monoXl.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (myResult != null && app.isGuest) ...[
            AppAlertBanner(
              type: AppAlertType.info,
              message: 'Save this result to your permanent record.',
              actionLabel: 'Create Account',
              onAction: () => _showCreateAccountDialog(context, app),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Full results table
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  'FULL RESULTS',
                  style: AppTypography.bodyXs.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(
                  children: [
                    for (final entry in ranked.asMap().entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        color: entry.value.player.id == user?.id
                            ? AppColors.primarySoft
                            : (entry.key % 2 == 0
                                  ? AppColors.card
                                  : AppColors.background),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: entry.value.pos <= 3
                                  ? MedalIcon(
                                      entry.value.pos,
                                      size: AppFontSizes.lg,
                                    )
                                  : Text(
                                      '#${entry.value.pos}',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.monoSm.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.avatarColorFor(
                                  entry.value.player.name,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                entry.value.player.name.trim().isEmpty
                                    ? '?'
                                    : entry.value.player.name
                                          .trim()[0]
                                          .toUpperCase(),
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.value.player.name,
                                      style: AppTypography.bodySm.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (entry.value.player.id == user?.id) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    const AppBadge(
                                      label: 'You',
                                      variant: AppBadgeVariant.green,
                                    ),
                                  ],
                                  if (entry.value.player.isGuest) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    const AppBadge(
                                      label: 'Guest',
                                      variant: AppBadgeVariant.muted,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (showAmounts) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                [
                                  if (entry.value.player.rebuys > 0)
                                    '${entry.value.player.rebuys}R',
                                  if (entry.value.player.hasAddOn) 'AO',
                                  if (entry.value.player.knockouts > 0)
                                    '${entry.value.player.knockouts} KO',
                                ].join(' · '),
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              showAmounts && entry.value.prize != null
                                  ? Formatters.chips(entry.value.prize!.amount)
                                  : '—',
                              style: AppTypography.monoSm.copyWith(
                                color: showAmounts && entry.value.prize != null
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Stats
          if (showAmounts)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Players',
                    value: '${players.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Total pot',
                    value: Formatters.chips(game.structure.prizePool),
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(label: 'Rebuys', value: '$totalRebuys'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Players',
                    value: '${players.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Duration',
                    value:
                        '${game.settings.durationHours == game.settings.durationHours.roundToDouble() ? game.settings.durationHours.round() : game.settings.durationHours}h',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Final level',
                    value: 'L${game.currentLevel}',
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
                  onPressed: () => context.go(RoutePaths.group),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 14,
                        color: AppColors.icon,
                      ),
                      const SizedBox(width: 6),
                      const Text('Group'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Home'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _medalFor(int pos, double size) {
    if (pos <= 3) return MedalIcon(pos, size: size);
    return Text(
      '#$pos',
      style: AppTypography.monoSm.copyWith(color: AppColors.mutedForeground),
    );
  }

  /// §C9's **Share**: rasterise the fixed 1,080 x 1,350 card and hand it to
  /// the OS share sheet (T93).
  ///
  /// [buttonContext] is the Share control's own context, not the screen's — it
  /// is only there to read the anchor rect the sheet pops from on iPad/Mac.
  Future<void> _share(
    BuildContext screenContext,
    BuildContext buttonContext,
    AppProvider app,
    LiveGame game,
    bool showAmounts,
  ) async {
    final box = buttonContext.findRenderObject();
    final anchor = box is RenderBox
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await shareResults(
        screenContext,
        game: game,
        // `recapFor`, not `gameRecap`: this screen can show a past game by id,
        // not just the open one (same reason the night recap below uses it).
        recap: app.recapFor(game),
        showAmounts: showAmounts,
        // §C9 puts season points on the card "when seasons are on", and D4
        // puts seasons behind Premium — so this is the entitlement, not a
        // per-game setting, and there is nothing to read off the game.
        seasonsOn: Entitlements.allows(app.premiumTier, PremiumFeature.seasons),
        sharePositionOrigin: anchor,
      );
    } catch (e) {
      // A share can fail for reasons the player cannot act on — no share
      // target, the platform channel missing, the capture failing. Say so in
      // one line and leave the results on screen; they are not affected.
      debugPrint('Share card failed: $e');
      if (!screenContext.mounted) return;
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(content: Text("Could not share tonight's results.")),
      );
    }
  }

  String _ordinal(int pos) {
    if (pos == 1) return 'st';
    if (pos == 2) return 'nd';
    if (pos == 3) return 'rd';
    return 'th';
  }

  void _showCreateAccountDialog(BuildContext context, AppProvider app) {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    showAppModal(
      context: context,
      title: 'Create Account',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(controller: name, label: 'Name'),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: password,
            label: 'Password',
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            onPressed: () async {
              final err = await app.convertGuestAccount(
                name.text.trim(),
                email.text.trim(),
                password.text,
              );
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
                return;
              }
              Navigator.of(context).pop();
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.result,
    required this.isWinner,
    required this.showAmounts,
  });

  final _PodiumResult result;
  final bool isWinner;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    // Heights must stay well under the parent SizedBox(220) minus the medal
    // row (~32px) so the winner column never triggers a RenderFlex overflow.
    final heights = [150.0, 118.0, 86.0];
    final labels = ['1st', '2nd', '3rd'];
    final isFirst = result.pos == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MedalIcon(result.pos, size: AppFontSizes.xxxl),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              // Crimson outline for 1st, not gold (no-gold rule, B4.9): "no
              // metallic gold, silver or bronze".
              border: Border.all(
                color: isFirst
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            // Minimum heights, not fixed: name + place + prize must fit even
            // in the shortest (3rd-place) block at 320px.
            constraints: BoxConstraints(
              minHeight: heights[result.pos - 1],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  result.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: AppFontSizes.md,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  labels[result.pos - 1],
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (result.prize != null && showAmounts)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Formatters.chips(result.prize!.amount),
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
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

/// §34a. One row per award that actually happened this game — `biggestComeback`
/// is absent whenever nobody's stack was spot-checked before an elimination
/// (boundary #8: best-effort, not a full highlight reel).
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.recap});

  final GameRecap recap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(IconData icon, String label, RecapAward? award, String valueText) {
      if (award == null) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySm,
              ),
            ),
            Text(
              '${award.playerName} · $valueText',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    addRow(Icons.trending_up, 'Biggest comeback', recap.biggestComeback,
        '${recap.biggestComeback?.value} BB');
    addRow(Icons.timer_outlined, 'Fastest bust', recap.fastestBust,
        'Level ${recap.fastestBust?.value}');
    addRow(Icons.local_fire_department, 'Most knockouts', recap.mostKnockouts,
        '${recap.mostKnockouts?.value} KOs');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Night recap',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }
}

/// §C9's **Share** control. A button, but it owns one piece of state the
/// screen does not: whether a share is already in flight. Two taps would
/// rasterise the 1,080 x 1,350 card twice and open two sheets, and the second
/// capture would race the overlay entry the first one is still holding.
class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.onShare});

  /// Given the button's own context, because the share sheet's popover anchor
  /// is read from this control (iPad/Mac, T93).
  final Future<void> Function(BuildContext buttonContext) onShare;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _busy = false;

  Future<void> _run(BuildContext buttonContext) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onShare(buttonContext);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => AppButton(
        variant: AppButtonVariant.secondary,
        onPressed: () => _run(buttonContext),
        // `loading` is what disables the button and swaps in the spinner
        // (AppButton._isEnabled already folds it in), so this is the whole
        // in-flight guard — `_run` only has to survive a double tap.
        loading: _busy,
        // Not const: `AppColors.icon` reads the active palette, so the icon
        // re-tints with the rest of the app rather than freezing one palette's
        // grey into the tree.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share, size: 14, color: AppColors.icon),
            const SizedBox(width: 6),
            const Text('Share'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.valueColor});

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
            style: AppTypography.monoLg.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
