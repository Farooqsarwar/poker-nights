import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../responsive/responsive.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/code_display.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/status_dot.dart';

/// Admin live dashboard mirroring the web `AdminDashboardPage`.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _tab = 'players';
  final _announcementController = TextEditingController();
  bool _showStructureModal = false;

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  void _sendAnnouncement(AppProvider app) {
    final text = _announcementController.text.trim();
    if (text.isEmpty) return;
    app.addAnnouncement(text);
    _announcementController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text('No active game.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Go home'),
            ),
          ],
        ),
      );
    }

    final structure = game.structure;
    final settings = game.settings;
    final status = game.status;
    final currentLevel = game.currentLevel;
    final secondsRemaining = game.secondsRemaining;
    final level = game.currentLevelData;
    final activePlayers = game.activePlayers;
    final eliminatedPlayers = game.eliminatedPlayers;
    final avgStack = Formatters.averageStack(game.totalChipsInPlay, activePlayers.length);
    final timerDanger = secondsRemaining <= 60;
    final timerWarning = secondsRemaining <= 300;
    final levelDurationSecs = (level?.durationMins ?? 1) * 60;
    final levelPct = level == null
        ? 0.0
        : (((levelDurationSecs - secondsRemaining) / levelDurationSecs) * 100).clamp(0, 100).toDouble();

    final device = AppBreakpoints.deviceOf(context);
    final timerSize = device.isMobile ? 54.0 : 64.0;

    final statusSpec = _statusSpec(status);
    final timerColor = timerDanger
        ? AppColors.destructive
        : timerWarning
            ? AppColors.warning
            : AppColors.primary;

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settings.name, style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const StatusDot(status: AppStatus.online),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          statusSpec.label,
                          style: AppTypography.monoXs.copyWith(
                            color: statusSpec.color,
                            fontWeight: FontWeight.w600,
                          ),
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
                    onPressed: () => context.go(RoutePaths.tvMode),
                    child: const Text('📺 TV'),
                  ),
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    onPressed: app.toggleVoice,
                    child: Text(app.voiceEnabled ? '🔊 Voice' : '🔇 Voice'),
                  ),
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: app.canUndo ? app.undoLast : null,
                    child: const Text('↩ Undo'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Speed recommendation
          if (game.speedRecommendation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: AppAlertBanner(
                type: AppAlertType.warning,
                message: game.speedRecommendation == SpeedRecommendation.speedUp
                    ? 'Tournament is running late — suggest shorter future levels'
                    : 'Tournament finishing early — suggest longer future levels',
                actionLabel: 'Accept change',
                onAction: app.acceptSpeedRecommendation,
              ),
            ),
          // Timer block
          AppCard(
            glow: timerDanger,
            borderColor: timerDanger
                ? AppColors.destructive.withValues(alpha: 0.4)
                : timerWarning
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : null,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: device.isMobile
                ? _TimerColumn(
                    game: game,
                    timerSize: timerSize,
                    timerColor: timerColor,
                    levelPct: levelPct,
                  )
                : _TimerRow(
                    game: game,
                    timerSize: timerSize,
                    timerColor: timerColor,
                    levelPct: levelPct,
                    avgStack: avgStack,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Timer controls
          Row(
            children: [
              if (status == LiveGameStatus.checkin || status == LiveGameStatus.published) ...[
                AppButton(
                  size: AppButtonSize.lg,
                  onPressed: app.startTimer,
                  child: const Text('▶ Start'),
                ),
              ] else if (status == LiveGameStatus.running) ...[
                AppButton(
                  size: AppButtonSize.lg,
                  variant: AppButtonVariant.secondary,
                  onPressed: app.pauseTimer,
                  child: const Text('⏸ Pause'),
                ),
              ] else if (status == LiveGameStatus.paused || status == LiveGameStatus.rebuypause) ...[
                AppButton(
                  size: AppButtonSize.lg,
                  onPressed: app.resumeTimer,
                  child: const Text('▶ Resume'),
                ),
              ],
              if (status == LiveGameStatus.running || status == LiveGameStatus.paused) ...[
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: currentLevel >= (structure.levels.length)
                      ? null
                      : app.nextLevel,
                  child: const Text('Next level →'),
                ),
              ],
              if (status == LiveGameStatus.rebuypause) ...[
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  size: AppButtonSize.sm,
                  onPressed: () => context.go(RoutePaths.rebuySettlement),
                  child: const Text('Settlement →'),
                ),
              ],
              if (status == LiveGameStatus.finaltable) ...[
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  size: AppButtonSize.sm,
                  onPressed: () => context.go(RoutePaths.finalTable),
                  child: const Text('Redraw table →'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Speed / structure quick actions
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => setState(() => _showStructureModal = true),
                child: const Text('⚡ Speed Up'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => setState(() => _showStructureModal = true),
                child: const Text('🐢 Slow Down'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => setState(() => _showStructureModal = true),
                child: const Text('✏️ Edit Future Levels'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => context.go(RoutePaths.checkIn),
                child: const Text('👥 Seats'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // TV code + announcement
          if (device.isMobile)
            Column(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TV mode code', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                      const SizedBox(height: AppSpacing.sm),
                      CodeDisplay(code: game.tvCode),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Open on any TV browser',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _AnnouncementCard(
                  controller: _announcementController,
                  announcements: game.announcements,
                  onSend: () => _sendAnnouncement(app),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TV mode code', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                        const SizedBox(height: AppSpacing.sm),
                        CodeDisplay(code: game.tvCode),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Open on any TV browser',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AnnouncementCard(
                    controller: _announcementController,
                    announcements: game.announcements,
                    onSend: () => _sendAnnouncement(app),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          // Tabs
          AppTabs(
            tabs: [
              AppTabItem(id: 'players', label: 'Players', count: activePlayers.length),
              AppTabItem(id: 'eliminated', label: 'Eliminated', count: eliminatedPlayers.length),
              const AppTabItem(id: 'seating', label: 'Seating'),
              const AppTabItem(id: 'prize', label: 'Prizes (private)'),
            ],
            active: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: AppSpacing.md),
          // Players tab
          if (_tab == 'players')
            ..._playersTab(app, game),
          // Eliminated tab
          if (_tab == 'eliminated')
            _EliminatedTab(
              players: eliminatedPlayers,
              settings: settings,
              currentLevel: currentLevel,
              onGrantRebuy: app.grantRebuy,
              onGrantReEntry: app.grantReEntry,
            ),
          // Seating tab
          if (_tab == 'seating')
            _SeatingTab(players: activePlayers),
          // Prize tab
          if (_tab == 'prize')
            _PrizeTab(
              structure: structure,
              settings: settings,
              remainingPlayers: activePlayers.length,
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Structure edit modal
          AppModal(
            open: _showStructureModal,
            onClose: () => setState(() => _showStructureModal = false),
            title: 'Edit future structure',
            child: _StructureEditor(
              structure: structure,
              currentLevel: currentLevel,
              onSpeedUp: () {
                app.acceptSpeedRecommendation(rec: SpeedRecommendation.speedUp);
                setState(() => _showStructureModal = false);
              },
              onSlowDown: () {
                app.acceptSpeedRecommendation(rec: SpeedRecommendation.slowDown);
                setState(() => _showStructureModal = false);
              },
              onApply: () => setState(() => _showStructureModal = false),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _playersTab(AppProvider app, LiveGame game) {
    final settings = game.settings;
    final currentLevel = game.currentLevel;
    final canRebuy = settings.rebuys && currentLevel <= settings.rebuysCloseLevel;

    return [
      for (final p in game.activePlayers)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(p.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                          if (p.isGuest) const AppBadge(label: 'Guest', variant: AppBadgeVariant.muted),
                          if (p.rebuys > 0) AppBadge(label: 'Rebuy ×${p.rebuys}', variant: AppBadgeVariant.accent),
                          if (p.reEntries > 0) AppBadge(label: 'Re-entry ×${p.reEntries}', variant: AppBadgeVariant.gold),
                          if (p.hasAddOn) const AppBadge(label: 'Add-on', variant: AppBadgeVariant.green),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Table ${p.table} · Seat ${p.seat}',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.danger,
                      onPressed: () => _showEliminateModal(context, app, p),
                      child: const Text('Out'),
                    ),
                    if (canRebuy)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => app.grantRebuy(p.id),
                        child: const Text('Rebuy'),
                      ),
                    if (settings.addOn && game.status == LiveGameStatus.rebuypause && !p.hasAddOn)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => app.grantAddOn(p.id),
                        child: const Text('Add-on'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  void _showEliminateModal(BuildContext context, AppProvider app, Player player) {
    final game = app.currentGame;
    if (game == null) return;
    final koEnabled = game.settings.koEnabled;
    final options = game.activePlayers.where((p) => p.id != player.id).toList();

    showAppModal(
      context: context,
      title: 'Confirm elimination',
      child: _EliminateContent(
        playerName: player.name,
        koEnabled: koEnabled,
        options: options,
        onConfirm: (koRecipientId) {
          app.eliminatePlayer(player.id, koRecipientId: koRecipientId);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ── Status spec ───────────────────────────────────────────────────────────────
class _StatusSpec {
  const _StatusSpec(this.label, this.color);
  final String label;
  final Color color;
}

_StatusSpec _statusSpec(LiveGameStatus status) {
  switch (status) {
    case LiveGameStatus.running:
      return const _StatusSpec('● RUNNING', AppColors.success);
    case LiveGameStatus.paused:
      return const _StatusSpec('⏸ PAUSED', AppColors.warning);
    case LiveGameStatus.rebuypause:
      return const _StatusSpec('⏸ BREAK — REBUY CLOSE', AppColors.warning);
    case LiveGameStatus.finaltable:
      return const _StatusSpec('♠ FINAL TABLE', AppColors.primary);
    case LiveGameStatus.checkin:
      return const _StatusSpec('CHECK-IN', AppColors.mutedForeground);
    case LiveGameStatus.published:
      return const _StatusSpec('PUBLISHED', AppColors.mutedForeground);
    case LiveGameStatus.draft:
      return const _StatusSpec('DRAFT', AppColors.mutedForeground);
    case LiveGameStatus.completed:
      return const _StatusSpec('COMPLETED', AppColors.mutedForeground);
    case LiveGameStatus.cancelled:
      return const _StatusSpec('CANCELLED', AppColors.mutedForeground);
  }
}

// ── Timer layout ──────────────────────────────────────────────────────────────
class _TimerRow extends StatelessWidget {
  const _TimerRow({
    required this.game,
    required this.timerSize,
    required this.timerColor,
    required this.levelPct,
    required this.avgStack,
  });

  final LiveGame game;
  final double timerSize;
  final Color timerColor;
  final double levelPct;
  final int avgStack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _TimerInfo(game: game, timerSize: timerSize, timerColor: timerColor, levelPct: levelPct, avgStack: avgStack)),
        const SizedBox(width: AppSpacing.xl),
        _TimerActions(game: game),
      ],
    );
  }
}

class _TimerColumn extends StatelessWidget {
  const _TimerColumn({
    required this.game,
    required this.timerSize,
    required this.timerColor,
    required this.levelPct,
  });

  final LiveGame game;
  final double timerSize;
  final Color timerColor;
  final double levelPct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimerInfo(game: game, timerSize: timerSize, timerColor: timerColor, levelPct: levelPct),
        const SizedBox(height: AppSpacing.lg),
        _TimerActions(game: game),
      ],
    );
  }
}

class _TimerInfo extends StatelessWidget {
  const _TimerInfo({
    required this.game,
    required this.timerSize,
    required this.timerColor,
    required this.levelPct,
    this.avgStack,
  });

  final LiveGame game;
  final double timerSize;
  final Color timerColor;
  final double levelPct;
  final int? avgStack;

  @override
  Widget build(BuildContext context) {
    final level = game.currentLevelData;
    final next = game.nextLevelData;
    final active = game.activePlayers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AppTimer(
              secondsRemaining: game.secondsRemaining,
              size: timerSize,
              danger: timerColor == AppColors.destructive,
              warning: timerColor == AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${game.currentLevel}', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                if (next != null)
                  Text(
                    'Next: ${Formatters.chips(next.sb)}/${Formatters.chips(next.bb)}',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(
          value: levelPct,
          max: 100,
          color: timerColor == AppColors.primary
              ? AppProgressColor.primary
              : timerColor == AppColors.warning
                  ? AppProgressColor.primary
                  : AppProgressColor.destructive,
          height: 6,
        ),
        if (level != null) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _BlindStat(
                label: 'Blinds',
                value: '${Formatters.chips(level.sb)} / ${Formatters.chips(level.bb)}',
                extra: level.ante != null ? '+ ${Formatters.chips(level.ante!)} ante' : null,
              ),
              _BlindStat(label: 'Players', value: '$active'),
              _BlindStat(
                label: 'Avg stack',
                value: Formatters.chips(avgStack ?? 0),
              ),
              _BlindStat(
                label: game.prizePoolLabel,
                value: Formatters.chips(game.structure.prizePool),
                valueColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BlindStat extends StatelessWidget {
  const _BlindStat({required this.label, required this.value, this.extra, this.valueColor});

  final String label;
  final String value;
  final String? extra;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.monoLg.copyWith(fontWeight: FontWeight.w700, color: valueColor ?? AppColors.foreground),
            ),
            if (extra != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                extra!,
                style: AppTypography.bodySm.copyWith(color: AppColors.accent),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final status = game.status;
    final structure = game.structure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == LiveGameStatus.checkin || status == LiveGameStatus.published) ...[
          AppButton(
            size: AppButtonSize.xl,
            onPressed: context.read<AppProvider>().startTimer,
            child: const Text('▶ Start'),
          ),
        ] else if (status == LiveGameStatus.running) ...[
          AppButton(
            size: AppButtonSize.xl,
            variant: AppButtonVariant.secondary,
            onPressed: context.read<AppProvider>().pauseTimer,
            child: const Text('⏸ Pause'),
          ),
        ] else if (status == LiveGameStatus.paused || status == LiveGameStatus.rebuypause) ...[
          AppButton(
            size: AppButtonSize.xl,
            onPressed: context.read<AppProvider>().resumeTimer,
            child: const Text('▶ Resume'),
          ),
        ],
        if (status == LiveGameStatus.running || status == LiveGameStatus.paused)
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            onPressed: game.currentLevel >= (structure.levels.length)
                ? null
                : context.read<AppProvider>().nextLevel,
            child: const Text('Next level →'),
          ),
        if (status == LiveGameStatus.rebuypause)
          AppButton(
            size: AppButtonSize.sm,
            onPressed: () => context.go(RoutePaths.rebuySettlement),
            child: const Text('Settlement →'),
          ),
        if (status == LiveGameStatus.finaltable)
          AppButton(
            size: AppButtonSize.sm,
            onPressed: () => context.go(RoutePaths.finalTable),
            child: const Text('Redraw table →'),
          ),
      ],
    );
  }
}

// ── Announcement card ─────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.controller,
    required this.announcements,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<Announcement> announcements;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final recent = announcements.length <= 2
        ? announcements.reversed
        : announcements.sublist(announcements.length - 2).reversed;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Announcement', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  placeholder: 'Type announcement…',
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: onSend,
                child: const Text('Send'),
              ),
            ],
          ),
          for (final a in recent)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '→ ${a.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
            )
                .animate(key: ValueKey(a.id))
                .fadeIn(duration: 260.ms)
                .slideY(begin: -0.25, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

// ── Tabs content ──────────────────────────────────────────────────────────────
class _EliminatedTab extends StatelessWidget {
  const _EliminatedTab({
    required this.players,
    required this.settings,
    required this.currentLevel,
    required this.onGrantRebuy,
    required this.onGrantReEntry,
  });

  final List<Player> players;
  final GameSettings settings;
  final int currentLevel;
  final void Function(String playerId) onGrantRebuy;
  final void Function(String playerId) onGrantReEntry;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Text('No eliminations yet.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
        ),
      );
    }
    final canRebuy = settings.rebuys && currentLevel <= settings.rebuysCloseLevel;
    final canReEnter = settings.reEntry && currentLevel <= settings.rebuysCloseLevel;
    return Column(
      children: [
        for (final p in players)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Opacity(
              opacity: 0.7,
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            'Position ${p.eliminationPos ?? '?'}',
                            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    if (canRebuy && p.rebuys == 0)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => onGrantRebuy(p.id),
                        child: const Text('Grant rebuy'),
                      ),
                    if (canReEnter)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: AppButton(
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => onGrantReEntry(p.id),
                          child: const Text('Re-entry'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeatingTab extends StatelessWidget {
  const _SeatingTab({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final seated = players.where((p) => p.table > 0).toList();
    final unseated = players.where((p) => p.table <= 0).toList();
    final tables = seated.map((p) => p.table).toSet().toList()..sort();
    final allTables = tables.isEmpty
        ? const [1]
        : [for (var t = tables.first; t <= tables.last; t++) t];

    return Column(
      children: [
        for (final table in allTables)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TableCard(table: table, players: seated.where((p) => p.table == table).toList()),
          ),
        if (unseated.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Unseated', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    AppBadge(label: '${unseated.length} players', variant: AppBadgeVariant.muted),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final p in unseated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      p.name,
                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.players});

  final int table;
  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<AppProvider>().currentGame;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Table $table', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              AppBadge(label: '${players.length} players', variant: AppBadgeVariant.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.4,
            ),
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              final isDealer = game?.dealerPlayerId == p.id;
              return Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDealer ? AppColors.primarySoft : AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDealer ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isDealer ? 'Dealer · Seat ${p.seat}' : 'Seat ${p.seat}',
                      style: AppTypography.bodyXs.copyWith(
                        color: isDealer ? AppColors.primary : AppColors.mutedForeground,
                        fontWeight: isDealer ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (p.isGuest)
                      Text('Guest', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrizeTab extends StatelessWidget {
  const _PrizeTab({
    required this.structure,
    required this.settings,
    required this.remainingPlayers,
  });

  final TournamentStructure structure;
  final GameSettings settings;
  final int remainingPlayers;

  @override
  Widget build(BuildContext context) {
    const medalEmoji = ['🥇', '🥈', '🥉', '4️⃣'];
    const placeLabel = ['1st', '2nd', '3rd', '4th'];

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppAlertBanner(
                type: AppAlertType.warning,
                message: 'Prize amounts are private — only visible to you as admin.',
              ),
              const SizedBox(height: AppSpacing.md),
              for (final p in structure.prizes)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        p.place <= 4 ? medalEmoji[p.place - 1] : '${p.place}.',
                        style: const TextStyle(fontSize: AppFontSizes.md),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          p.place <= 4 ? '${placeLabel[p.place - 1]} place' : '${p.place}th place',
                          style: AppTypography.bodySm,
                        ),
                      ),
                      Text(
                        '${p.amount}',
                        style: AppTypography.monoSm.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('Prize pool', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const Spacer(),
                  Text('${structure.prizePool}', style: AppTypography.monoXs.copyWith(color: AppColors.foreground)),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Organiser (${settings.organizerPct}%)',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                  const Spacer(),
                  Text('${structure.organizerAmount}', style: AppTypography.monoXs.copyWith(color: AppColors.foreground)),
                ],
              ),
            ],
          ),
        ),
        if (structure.colorUpInstructions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Color-up instructions', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                for (final ins in structure.colorUpInstructions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('→', style: AppTypography.bodySm.copyWith(color: AppColors.primary)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(ins, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (remainingPlayers <= 3) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            fullWidth: true,
            onPressed: () => context.go(RoutePaths.completeTournament),
            child: const Text('Record finish order →'),
          ),
        ],
      ],
    );
  }
}

// ── Eliminate modal ───────────────────────────────────────────────────────────
class _EliminateContent extends StatefulWidget {
  const _EliminateContent({
    required this.playerName,
    required this.koEnabled,
    required this.options,
    required this.onConfirm,
  });

  final String playerName;
  final bool koEnabled;
  final List<Player> options;
  final void Function(String? koRecipientId) onConfirm;

  @override
  State<_EliminateContent> createState() => _EliminateContentState();
}

class _EliminateContentState extends State<_EliminateContent> {
  String? _koRecipient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mark ${widget.playerName} as eliminated?',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        if (widget.koEnabled) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSelect(
            label: 'KO bounty recipient (optional)',
            value: _koRecipient,
            hint: '— None —',
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('— None —')),
              for (final p in widget.options)
                DropdownMenuItem<String>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _koRecipient = v),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.danger,
                onPressed: () => widget.onConfirm(_koRecipient),
                child: const Text('Eliminate'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Structure editor modal ────────────────────────────────────────────────────
class _StructureEditor extends StatelessWidget {
  const _StructureEditor({
    required this.structure,
    required this.currentLevel,
    required this.onSpeedUp,
    required this.onSlowDown,
    required this.onApply,
  });

  final TournamentStructure structure;
  final int currentLevel;
  final VoidCallback onSpeedUp;
  final VoidCallback onSlowDown;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final futureLevels = structure.levels.length > currentLevel
        ? structure.levels.sublist(currentLevel)
        : <BlindLevel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Adjust future levels. Active level is locked.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final l in futureLevels)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text('Lv ${l.level}', style: AppTypography.monoXs.copyWith(color: AppColors.mutedForeground)),
                ),
                Text('${Formatters.chips(l.sb)}/${Formatters.chips(l.bb)}', style: AppTypography.monoSm),
                if (l.ante != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '(ante ${Formatters.chips(l.ante!)})',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.accent),
                  ),
                ],
                const Spacer(),
                Text('${l.durationMins}m', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.danger,
                onPressed: onSpeedUp,
                child: const Text('Speed up (-5m)'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: onSlowDown,
                child: const Text('Slow down (+5m)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          fullWidth: true,
          onPressed: onApply,
          child: const Text('Apply & close'),
        ),
      ],
    );
  }
}
