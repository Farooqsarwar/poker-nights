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
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/code_display.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/tournament_display_block.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/structure_editor.dart';

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
  bool _showRestartModal = false;
  bool _showCancelModal = false;
  bool _showUndoModal = false;
  bool _showedFinalTablePrompt = false;
  // Pending speed change shown in the preview modal (audit fix B4: the admin
  // must see old vs. proposed structure + both finish estimates BEFORE
  // anything is applied).
  SpeedRecommendation? _pendingSpeed;

  /// Estimated finish time: remaining clock + the durations of the levels
  /// still to play (+5% buffer). [futureDurationOverride] previews a
  /// speed-up/slow-down of all future levels.
  String? _estimateFinish(LiveGame game, Duration clockOffset, {int? futureDurationOverride}) {
    final levels = game.structure.levels;
    if (levels.isEmpty) return null;
    var mins = game.currentSecondsRemaining(clockOffset) ~/ 60;
    for (final l in levels) {
      if (l.level >= game.currentLevel) {
        mins += l.level > game.currentLevel && futureDurationOverride != null
            ? futureDurationOverride
            : l.durationMins;
      }
    }
    final finish = DateTime.now().add(Duration(minutes: (mins * 1.05).round()));
    return '${finish.hour.toString().padLeft(2, '0')}:${finish.minute.toString().padLeft(2, '0')}';
  }

  /// What a speed up/slow down would do to the level duration (the provider
  /// clamps the result to the allowed 10/15/20 set).
  int _previewedDuration(LiveGame game, SpeedRecommendation rec) {
    final raw = rec == SpeedRecommendation.speedUp
        ? game.structure.levelDuration - 5
        : game.structure.levelDuration + 5;
    return raw < 10 ? 10 : (raw > 20 ? 20 : raw);
  }

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
    final isAdmin = app.isAdmin;
    // MVP spec §3.1: exactly one administrator per event.
    // Auth guarding is handled securely by GoRouter's redirect logic.

    // Final Table Auto-Trigger (Audit fix)
    final isNinePlayers = game != null && game.activePlayers.length == 9;
    if (isNinePlayers && game.status == LiveGameStatus.running && !_showStructureModal && !_showRestartModal && !_showCancelModal && !_showUndoModal && !_showedFinalTablePrompt) {
      _showedFinalTablePrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AppModal(
              open: true,
              onClose: () => Navigator.pop(ctx),
              title: 'Final Table Reached!',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Exactly 9 players remain. It is time for the final table redraw.'),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          variant: AppButtonVariant.secondary,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Not Yet'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push(RoutePaths.finalTable);
                          },
                          child: const Text('Start Redraw'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).then((_) {
            if (mounted) {
               // Let them re-trigger it if they want by some other means, but don't auto-show again.
            }
          });
        }
      });
    }

    if (game == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'No active game.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
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
    final secondsRemaining = game.currentSecondsRemaining(app.serverTimeOffset);
    final level = game.currentLevelData;
    final activePlayers = game.activePlayers;
    final eliminatedPlayers = game.eliminatedPlayers;
    final timerDanger = secondsRemaining <= 60;
    final timerWarning = secondsRemaining <= 300;
    final levelDurationSecs = (level?.durationMins ?? 1) * 60;
    final levelPct = level == null
        ? 0.0
        : (((levelDurationSecs - secondsRemaining) / levelDurationSecs) * 100)
              .clamp(0, 100)
              .toDouble();

    final device = AppBreakpoints.deviceOf(context);
    final timerSize = device.isMobile ? 54.0 : 64.0;

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
          if (device.isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.name,
                  style: AppTypography.display(
                    size: AppFontSizes.xxxl,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.go(RoutePaths.tvMode),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AppIconLabel(
                          label: 'TV',
                          icon: Icons.tv_outlined,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => ChatSheet.show(context, game.id),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIconLabel(
                              label: 'Chat',
                              icon: Icons.chat_bubble_outline,
                            ),
                            if (app.unreadGameChatCount(game.id) > 0) ...[
                              const SizedBox(width: 4),
                              ChatUnreadBadge(
                                count: app.unreadGameChatCount(game.id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: app.toggleVoice,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AppIconLabel(
                          label: 'Voice',
                          icon: app.voiceEnabled
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: app.canUndo
                          ? () => setState(() => _showUndoModal = true)
                          : null,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AppIconLabel(label: 'Undo', icon: Icons.undo),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.name,
                    style: AppTypography.display(
                      size: AppFontSizes.xxxl,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.go(RoutePaths.tvMode),
                      child: const AppIconLabel(
                        label: 'TV',
                        icon: Icons.tv_outlined,
                      ),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => ChatSheet.show(context, game.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIconLabel(
                            label: 'Chat',
                            icon: Icons.chat_bubble_outline,
                          ),
                          if (app.unreadGameChatCount(game.id) > 0) ...[
                            const SizedBox(width: 4),
                            ChatUnreadBadge(
                              count: app.unreadGameChatCount(game.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: app.toggleVoice,
                      child: AppIconLabel(
                        label: 'Voice',
                        icon: app.voiceEnabled
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                      ),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onPressed: app.canUndo
                          ? () => setState(() => _showUndoModal = true)
                          : null,
                      child: const AppIconLabel(
                        label: 'Undo',
                        icon: Icons.undo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          // Blocking cancelled state — blocking states take priority (spec §12).
          if (status == LiveGameStatus.cancelled)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: const AppAlertBanner(
                type: AppAlertType.error,
                message:
                    'This tournament has been cancelled. Live controls are disabled.',
              ),
            ),
          // Speed recommendation — always previewed before applying
          // (audit fix B4: old vs. proposed structure + finish estimates).
          if (game.speedRecommendation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: AppAlertBanner(
                type: AppAlertType.warning,
                message: game.speedRecommendation == SpeedRecommendation.speedUp
                    ? 'Tournament is running late — shorter future levels suggested'
                    : 'Tournament finishing early — longer future levels suggested',
                actionLabel: 'Preview change',
                onAction: () =>
                    setState(() => _pendingSpeed = game.speedRecommendation),
              ),
            ),
          // Estimated finish — required on the admin control screen
          // (Tech spec §11.1, audit fix B3).
          if (status.isActiveLive || status == LiveGameStatus.rebuypause) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Estimated finish ≈ ${_estimateFinish(game, app.serverTimeOffset) ?? '—'}',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!device.isMobile) ...[
            // ── DESKTOP BEAUTIFUL LAYOUT ──
            // Row 1: Timer full width, top center
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: TournamentDisplayBlock(game: game, showStatusChip: true),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(height: AppSpacing.lg),

            // ── CONTROLS — Row 1 & 2 are Host/Admin only (advancing the
            // tournament and touching blinds/seating is out of Co-Admin's
            // scope) ─────────────────────────────────────────────────────
            if (isAdmin) ...[
            // ── CONTROLS — Row 1: Timer ──────────────────────────────────
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Play / Pause / Resume — always takes up ~1/3
                  Expanded(
                    flex: 3,
                    child: Builder(
                      builder: (_) {
                        if (status == LiveGameStatus.checkin ||
                            status == LiveGameStatus.published ||
                            status == LiveGameStatus.ready) {
                          return AppButton(
                            size: AppButtonSize.lg,
                            onPressed: app.startTimer,
                            child: const AppIconLabel(
                              label: 'Start Timer',
                              icon: Icons.play_arrow,
                            ),
                          );
                        } else if (status == LiveGameStatus.running) {
                          return AppButton(
                            size: AppButtonSize.lg,
                            variant: AppButtonVariant.primary,
                            onPressed: app.pauseTimer,
                            child: const AppIconLabel(
                              label: 'Pause Timer',
                              icon: Icons.pause,
                            ),
                          );
                        } else {
                          final canResume = status != LiveGameStatus.rebuypause &&
                              status != LiveGameStatus.finaltable;
                          return AppButton(
                            size: AppButtonSize.lg,
                            variant: AppButtonVariant.primary,
                            onPressed: canResume ? app.resumeTimer : null,
                            child: AppIconLabel(
                              label: 'Resume Timer',
                              icon: Icons.play_arrow,
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  if (status == LiveGameStatus.running ||
                      status == LiveGameStatus.paused) ...[
                    const SizedBox(width: AppSpacing.sm),
                    // Next Level
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        size: AppButtonSize.lg,
                        variant: AppButtonVariant.secondary,
                        onPressed: currentLevel >= structure.levels.length
                            ? null
                            : app.nextLevel,
                        child: const AppIconLabel(
                          label: 'Next Level',
                          trailing: Icons.skip_next,
                        ),
                      ),
                    ),
                  ],

                  if (status == LiveGameStatus.rebuypause) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 4,
                      child: AppButton(
                        size: AppButtonSize.lg,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.go(RoutePaths.rebuySettlement),
                        child: const AppIconLabel(
                          label: 'Settlement',
                          trailing: Icons.arrow_forward,
                        ),
                      ),
                    ),
                  ],
                  if (status == LiveGameStatus.finaltable) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 4,
                      child: AppButton(
                        size: AppButtonSize.lg,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.go(RoutePaths.finalTable),
                        child: const AppIconLabel(
                          label: 'Redraw Table',
                          trailing: Icons.arrow_forward,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── CONTROLS — Row 2: Structure / Nav (secondary actions) ───
            // Restart Level lives here (secondary + confirmation), not next
            // to Pause/Next Level (audit fixes E6/E1).
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(
                            () => _pendingSpeed = SpeedRecommendation.speedUp,
                          ),
                          child: const AppIconLabel(
                            label: 'Speed Up',
                            icon: Icons.bolt,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(
                            () => _pendingSpeed = SpeedRecommendation.slowDown,
                          ),
                          child: const AppIconLabel(
                            label: 'Slow Down',
                            icon: Icons.trending_down,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed: app.forceEvaluateSpeedRecommendation,
                          child: const AppIconLabel(
                            label: 'Recalculate',
                            icon: Icons.timer_outlined,
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
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              setState(() => _showStructureModal = true),
                          child: const AppIconLabel(
                            label: 'Edit Levels',
                            icon: Icons.edit_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed:
                              status == LiveGameStatus.running ||
                                  status == LiveGameStatus.paused
                              ? () => setState(() => _showRestartModal = true)
                              : null,
                          child: const AppIconLabel(
                            label: 'Restart',
                            icon: Icons.replay,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.lg,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.go(RoutePaths.checkIn),
                          child: const AppIconLabel(
                            label: 'Seats',
                            icon: Icons.people_outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
            const SizedBox(height: AppSpacing.xl),

            // Row 3: "Other things"
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                          ),
                          child: AppTabs(
                            tabs: [
                              AppTabItem(
                                id: 'players',
                                label: 'Players',
                                count: activePlayers.length,
                              ),
                              AppTabItem(
                                id: 'eliminated',
                                label: 'Eliminated',
                                count: eliminatedPlayers.length,
                              ),
                              const AppTabItem(id: 'seating', label: 'Seating'),
                              const AppTabItem(
                                id: 'prize',
                                label: 'Prizes (private)',
                              ),
                              const AppTabItem(id: 'audit', label: 'Audit Log'),
                            ],
                            active: _tab,
                            onChanged: (t) => setState(() => _tab = t),
                          ),
                        ),
                        const Divider(height: 1),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_tab == 'players') ..._playersTab(app, game),
                              if (_tab == 'eliminated')
                                _EliminatedTab(
                                  players: eliminatedPlayers,
                                  settings: settings,
                                  currentLevel: currentLevel,
                                  onGrantRebuy: app.grantRebuy,
                                  onGrantReEntry: app.grantReEntry,
                                  isAdmin: isAdmin,
                                ),
                              if (_tab == 'seating')
                                _SeatingTab(players: activePlayers),
                              if (_tab == 'prize')
                                _PrizeTab(
                                  structure: structure,
                                  settings: settings,
                                  remainingPlayers: activePlayers.length,
                                  settled: game.settlementConfirmed,
                                ),
                              if (_tab == 'audit')
                                _AuditTab(auditHistory: game.auditHistory),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TV mode code',
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            CodeDisplay(code: game.tvCode),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Open on any TV browser',
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _AnnouncementCard(
                        controller: _announcementController,
                        announcements: game.announcements,
                        onSend: () => _sendAnnouncement(app),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // ── MOBILE LINEAR LAYOUT ──
            // Timer block
            AppCard(
              glow: timerDanger,
              borderColor: timerDanger
                  ? AppColors.destructive.withValues(alpha: 0.4)
                  : timerWarning
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : null,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _TimerColumn(
                game: game,
                timerSize: timerSize,
                timerColor: timerColor,
                levelPct: levelPct,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Timer controls + speed/structure quick actions — Host/Admin
            // only, same reasoning as the desktop layout above.
            if (isAdmin) ...[
            // Timer controls
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (status == LiveGameStatus.checkin ||
                    status == LiveGameStatus.published ||
                    status == LiveGameStatus.ready)
                  AppButton(
                    size: AppButtonSize.lg,
                    onPressed: app.startTimer,
                    child: const AppIconLabel(
                      label: 'Start',
                      icon: Icons.play_arrow,
                    ),
                  )
                else if (status == LiveGameStatus.running)
                  AppButton(
                    size: AppButtonSize.lg,
                    variant: AppButtonVariant.secondary,
                    onPressed: app.pauseTimer,
                    child: const AppIconLabel(
                      label: 'Pause',
                      icon: Icons.pause,
                    ),
                  )
                else if (status == LiveGameStatus.paused ||
                    status == LiveGameStatus.rebuypause)
                  AppButton(
                    size: AppButtonSize.lg,
                    onPressed: app.resumeTimer,
                    child: const AppIconLabel(
                      label: 'Resume',
                      icon: Icons.play_arrow,
                    ),
                  ),
                if (status == LiveGameStatus.running ||
                    status == LiveGameStatus.paused)
                  AppButton(
                    size: AppButtonSize.md,
                    variant: AppButtonVariant.secondary,
                    onPressed: currentLevel >= (structure.levels.length)
                        ? null
                        : app.nextLevel,
                    child: const AppIconLabel(
                      label: 'Next level',
                      trailing: Icons.arrow_forward,
                    ),
                  ),
                if (status == LiveGameStatus.rebuypause)
                  AppButton(
                    size: AppButtonSize.md,
                    onPressed: () => context.go(RoutePaths.rebuySettlement),
                    child: const AppIconLabel(
                      label: 'Settlement',
                      trailing: Icons.arrow_forward,
                    ),
                  ),
                if (status == LiveGameStatus.finaltable)
                  AppButton(
                    size: AppButtonSize.md,
                    onPressed: () => context.go(RoutePaths.finalTable),
                    child: const AppIconLabel(
                      label: 'Redraw table',
                      trailing: Icons.arrow_forward,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Speed / structure quick actions
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(
                            () => _pendingSpeed = SpeedRecommendation.speedUp,
                          ),
                          child: const AppIconLabel(
                            label: 'Speed Up',
                            icon: Icons.bolt,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(
                            () => _pendingSpeed = SpeedRecommendation.slowDown,
                          ),
                          child: const AppIconLabel(
                            label: 'Slow Down',
                            icon: Icons.trending_down,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed:
                              status == LiveGameStatus.running ||
                                  status == LiveGameStatus.paused
                              ? () => setState(() => _showRestartModal = true)
                              : null,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppIconLabel(
                              label: 'Restart',
                              icon: Icons.replay,
                            ),
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
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed: app.forceEvaluateSpeedRecommendation,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppIconLabel(
                              label: 'Recalculate',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              setState(() => _showStructureModal = true),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppIconLabel(
                              label: 'Edit Levels',
                              icon: Icons.edit_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.go(RoutePaths.checkIn),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppIconLabel(
                              label: 'Seats',
                              icon: Icons.people_outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // TV code + announcement
            Column(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TV mode code',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CodeDisplay(code: game.tvCode),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Open on any TV browser',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
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
            ),
            const SizedBox(height: AppSpacing.lg),
            // Tabs
            AppTabs(
              tabs: [
                AppTabItem(
                  id: 'players',
                  label: 'Players',
                  count: activePlayers.length,
                ),
                AppTabItem(
                  id: 'eliminated',
                  label: 'Eliminated',
                  count: eliminatedPlayers.length,
                ),
                const AppTabItem(id: 'seating', label: 'Seating'),
                const AppTabItem(id: 'prize', label: 'Prizes (private)'),
                const AppTabItem(id: 'audit', label: 'Audit Log'),
              ],
              active: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: AppSpacing.md),
            // Players tab
            if (_tab == 'players') ..._playersTab(app, game),
            // Eliminated tab
            if (_tab == 'eliminated')
              _EliminatedTab(
                players: eliminatedPlayers,
                settings: settings,
                currentLevel: currentLevel,
                onGrantRebuy: app.grantRebuy,
                onGrantReEntry: app.grantReEntry,
                isAdmin: isAdmin,
              ),
            // Seating tab
            if (_tab == 'seating') _SeatingTab(players: activePlayers),
            // Prize tab
            if (_tab == 'prize')
              _PrizeTab(
                structure: structure,
                settings: settings,
                remainingPlayers: activePlayers.length,
                settled: game.settlementConfirmed,
              ),
            if (_tab == 'audit') _AuditTab(auditHistory: game.auditHistory),
          ],
          const SizedBox(height: AppSpacing.xxl),
          // Final table trigger for small tournaments (≤9 start, never auto-transition)
          // Host/Admin only — Co-Admin's scope stops at membership + rebuys.
          if (isAdmin &&
              (status == LiveGameStatus.running ||
                  status == LiveGameStatus.paused))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppButton(
                size: AppButtonSize.md,
                variant: AppButtonVariant.secondary,
                onPressed: () => app.triggerFinalTable(),
                child: const AppIconLabel(
                  label: 'Final Table',
                  icon: Icons.table_chart_outlined,
                ),
              ),
            ),
          // Danger zone: cancel tournament (spec §12 — confirmation + reason).
          // Host/Admin only.
          if (isAdmin &&
              status != LiveGameStatus.completed &&
              status != LiveGameStatus.cancelled) ...[
            AppCard(
              borderColor: AppColors.destructive.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancel tournament',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.destructive,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requires confirmation and a reason, which is recorded in the audit log and shared with members.',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.danger,
                    onPressed: () => setState(() => _showCancelModal = true),
                    child: const Text('Cancel tournament'),
                  ),
                ],
              ),
            ),
          ],
          // Structure edit modal — the full editor (edit any future blind /
          // duration, insert or remove levels; active level locked).
          // Audit fix B5: manual "Edit Future Levels" is available live.
          AppModal(
            open: _showStructureModal,
            onClose: () => setState(() => _showStructureModal = false),
            title: 'Edit future structure',
            child: StructureEditor(
              structure: structure,
              currentLevel: currentLevel,
              anteStyle: settings.anteStyle,
              onSpeedUp: () => setState(() {
                _showStructureModal = false;
                _pendingSpeed = SpeedRecommendation.speedUp;
              }),
              onSlowDown: () => setState(() {
                _showStructureModal = false;
                _pendingSpeed = SpeedRecommendation.slowDown;
              }),
              onApply: (levels) {
                app.applyFutureLevels(levels);
                setState(() => _showStructureModal = false);
              },
            ),
          ),
          // Speed change PREVIEW — old vs. proposed structure and both
          // estimated finish times, applied only on explicit confirm
          // (audit fix B4).
          if (_pendingSpeed != null) ...[
            Builder(
              builder: (context) {
                final game2 = app.currentGame;
                if (game2 == null) return const SizedBox.shrink();
                final oldDur = game2.structure.levelDuration;
                final newDur = _previewedDuration(game2, _pendingSpeed!);
                final isUp = _pendingSpeed == SpeedRecommendation.speedUp;
                return AppModal(
                  open: true,
                  onClose: () => setState(() => _pendingSpeed = null),
                  title: isUp ? 'Preview: speed up' : 'Preview: slow down',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppAlertBanner(
                        type: AppAlertType.info,
                        message:
                            'Future levels change only — the active level and all '
                            'completed levels stay exactly as they are.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _PreviewCol(
                              label: 'Current',
                              duration: '$oldDur min levels',
                              finish: _estimateFinish(game2, app.serverTimeOffset) ?? '—',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: _PreviewCol(
                              label: 'Proposed',
                              duration: '$newDur min levels (future)',
                              finish:
                                  _estimateFinish(
                                    game2,
                                    app.serverTimeOffset,
                                    futureDurationOverride: newDur,
                                  ) ??
                                  '—',
                              highlighted: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              variant: AppButtonVariant.secondary,
                              onPressed: () =>
                                  setState(() => _pendingSpeed = null),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              onPressed: () {
                                app.acceptSpeedRecommendation(
                                  rec: _pendingSpeed,
                                );
                                setState(() => _pendingSpeed = null);
                              },
                              child: const Text('Apply change'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Undo PREVIEW — "Undo shows the action that will be reversed"
          // (User Flow spec §12.6, audit fix E5).
          AppModal(
            open: _showUndoModal,
            onClose: () => setState(() => _showUndoModal = false),
            title: 'Undo last action?',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  app.lastActionSummary ??
                      'The most recent action will be reversed.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: () => setState(() => _showUndoModal = false),
                        child: const Text('Keep'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.danger,
                        onPressed: () {
                          app.undoLast();
                          setState(() => _showUndoModal = false);
                        },
                        child: const Text('Undo action'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Restart level confirmation (spec §12: shows exact effect)
          AppModal(
            open: _showRestartModal,
            onClose: () => setState(() => _showRestartModal = false),
            title: 'Restart level ${game.currentLevel}?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppAlertBanner(
                  type: AppAlertType.warning,
                  message: level == null
                      ? 'The timer resets to the full level duration and restarts running.'
                      : 'Level ${game.currentLevel} (${Formatters.chips(level.sb)}/${Formatters.chips(level.bb)}) — the timer resets to ${game.structure.levelDuration} minutes and restarts running.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            setState(() => _showRestartModal = false),
                        child: const Text('Keep going'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: () {
                          app.restartLevel();
                          setState(() => _showRestartModal = false);
                        },
                        child: const Text('Restart level'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Cancel tournament confirmation (spec §12: reason required)
          AppModal(
            open: _showCancelModal,
            onClose: () => setState(() => _showCancelModal = false),
            title: 'Cancel tournament',
            child: _CancelTournamentForm(
              gameName: settings.name,
              onCancel: (reason) {
                app.cancelGame(reason);
                setState(() => _showCancelModal = false);
              },
            ),
          ),
          // Offline Conflict Modal
          AppModal(
            open: app.hasOfflineConflict,
            onClose: () => app.resolveOfflineConflict(keepLocal: true),
            title: 'Offline Conflict Detected',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppAlertBanner(
                  type: AppAlertType.warning,
                  message:
                      'You have local offline progress that differs from the cloud state. Please choose which state to keep.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  variant: AppButtonVariant.primary,
                  onPressed: () => app.resolveOfflineConflict(keepLocal: true),
                  child: const Text('Keep Local Offline Progress'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => app.resolveOfflineConflict(keepLocal: false),
                  child: const Text('Discard Local & Sync Cloud'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _playersTab(AppProvider app, LiveGame game) {
    final settings = game.settings;
    final currentLevel = game.currentLevel;
    final canRebuy =
        settings.rebuys && currentLevel <= settings.rebuysCloseLevel;

    return [
      if (app.isAdmin && app.lateRegistrationOpen)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppButton(
            fullWidth: true,
            size: AppButtonSize.md,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showAddLatePlayerModal(context, app),
            child: const Text('+ Add Late Player (Late Reg)'),
          ),
        ),
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
                          Text(
                            p.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (p.isGuest)
                            const AppBadge(
                              label: 'Guest',
                              variant: AppBadgeVariant.muted,
                            ),
                          if (p.rebuys > 0)
                            AppBadge(
                              label: 'Rebuy ×${p.rebuys}',
                              variant: AppBadgeVariant.accent,
                            ),
                          if (p.reEntries > 0)
                            AppBadge(
                              label: 'Re-entry ×${p.reEntries}',
                              variant: AppBadgeVariant.gold,
                            ),
                          if (p.hasAddOn)
                            const AppBadge(
                              label: 'Add-on',
                              variant: AppBadgeVariant.green,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Table ${p.table} · Seat ${p.seat}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (app.isAdmin)
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
                        onPressed: () => _confirmRebuy(context, app, p),
                        child: const Text('Rebuy'),
                      ),
                    if (settings.addOn &&
                        game.status == LiveGameStatus.rebuypause &&
                        !p.hasAddOn)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _confirmAddOn(context, app, p),
                        child: const Text('Add-on'),
                      ),
                    if (app.isAdmin)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _confirmRemovePlayer(context, app, p),
                        child: Icon(
                          Icons.delete_outline,
                          color: AppColors.destructive,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  void _confirmRemovePlayer(BuildContext context, AppProvider app, Player p) {
    showAppModal(
      context: context,
      title: 'Remove Player',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Are you sure you want to completely remove ${p.name} from this tournament?\n\n'
            'This will delete their seat assignment and deduct their starting stack (${app.currentGame!.structure.startingStack} chips) and any rebuys/add-ons from the total chips in play.',
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                variant: AppButtonVariant.danger,
                onPressed: () {
                  app.removePlayer(p.id);
                  Navigator.pop(context);
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddLatePlayerModal(BuildContext context, AppProvider app) {
    final nameCtrl = TextEditingController();
    showAppModal(
      context: context,
      title: 'Add Late Player',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: nameCtrl,
            label: 'Player Name',
            hint: 'Enter name (e.g. David)',
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                app.addLatePlayer(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Add Player'),
          ),
        ],
      ),
    );
  }

  void _confirmRebuy(BuildContext context, AppProvider app, Player p) {
    showAppModal(
      context: context,
      title: 'Grant rebuy',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${p.name} receives a fresh ${Formatters.chips(app.currentGame!.structure.rebuyStack)}-chip '
            'rebuy stack and rejoins the game. The prize pool is recalculated.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    app.grantRebuy(p.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Grant rebuy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmAddOn(BuildContext context, AppProvider app, Player p) {
    showAppModal(
      context: context,
      title: 'Grant add-on',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${p.name} purchases the add-on stack (${Formatters.chips(app.currentGame!.structure.addOnStack)} chips). '
            'The prize pool is recalculated.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    app.grantAddOn(p.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Grant add-on'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEliminateModal(
    BuildContext context,
    AppProvider app,
    Player player,
  ) {
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

// ── Timer layout ──────────────────────────────────────────────────────────────
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
        _TimerInfo(
          game: game,
          timerSize: timerSize,
          timerColor: timerColor,
          levelPct: levelPct,
        ),
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
  });

  final LiveGame game;
  final double timerSize;
  final Color timerColor;
  final double levelPct;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: TournamentDisplayBlock(game: game, showStatusChip: true),
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
          Text(
            'Announcement',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: AppFontSizes.xs,
                        color: AppColors.iconMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          a.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
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
    required this.isAdmin,
  });

  final List<Player> players;
  final GameSettings settings;
  final int currentLevel;
  final void Function(String playerId) onGrantRebuy;
  final void Function(String playerId) onGrantReEntry;

  /// Host/Admin only — result corrections and full removal are tournament-
  /// advancing actions, out of Co-Admin's rebuy-only scope.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Text(
            'No eliminations yet.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }
    final canRebuy =
        settings.rebuys && currentLevel <= settings.rebuysCloseLevel;
    final canReEnter =
        settings.reEntry && currentLevel <= settings.rebuysCloseLevel;
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
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canRebuy)
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
                    if (isAdmin) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => context
                            .read<AppProvider>()
                            .correctElimination(p.id),
                        child: Text(
                          'Correct Result',
                          style: TextStyle(color: AppColors.destructive),
                        ),
                      ),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () {
                        showAppModal(
                          context: context,
                          title: 'Remove Player',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Are you sure you want to completely remove ${p.name} from this tournament?\n\n'
                                'This will delete their seat assignment, result record, and deduct their starting stack and any rebuys/add-ons from the total chips in play.',
                                style: AppTypography.bodySm,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AppButton(
                                    variant: AppButtonVariant.ghost,
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  AppButton(
                                    variant: AppButtonVariant.danger,
                                    onPressed: () {
                                      context.read<AppProvider>().removePlayer(
                                        p.id,
                                      );
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(
                        Icons.delete_outline,
                        color: AppColors.destructive,
                        size: 16,
                      ),
                    ),
                    ],
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

    final app = context.watch<AppProvider>();
    final rec = app.seatingRecommendation;
    // Seating/balance management is Host/Admin only (Co-Admin's scope stops
    // at membership + rebuys) — everyone else sees the read-only table view
    // below.
    final isAdmin = app.isAdmin;

    return Column(
      children: [
        if (isAdmin && rec == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: app.requestSeatingBalance,
                  child: const Text('Evaluate Table Balance'),
                ),
              ],
            ),
          ),
        if (isAdmin && rec != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppAlertBanner(
              type: AppAlertType.info,
              message:
                  'Table balance recommendation:\nMove ${rec.fromPlayerName} from Table ${rec.fromTable} to Table ${rec.toTable}, Seat ${rec.toSeat}.',
              actionLabel: 'Confirm',
              onAction: app.confirmSeatMove,
              // We simulate a dismiss button by using a row inside message if we wanted,
              // but AppAlertBanner only supports one action. So let's wrap it.
            ),
          ),
        if (isAdmin && rec != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: app.dismissSeatMove,
                  child: const Text('Dismiss Recommendation'),
                ),
              ],
            ),
          ),
        for (final table in allTables)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TableCard(
              table: table,
              players: seated.where((p) => p.table == table).toList(),
            ),
          ),
        if (unseated.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Unseated',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AppBadge(
                      label: '${unseated.length} players',
                      variant: AppBadgeVariant.muted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final p in unseated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      p.name,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
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
              Text(
                'Table $table',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              AppBadge(
                label: '${players.length} players',
                variant: AppBadgeVariant.accent,
              ),
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
                    color: isDealer
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isDealer ? 'Dealer · Seat ${p.seat}' : 'Seat ${p.seat}',
                      style: AppTypography.bodyXs.copyWith(
                        color: isDealer
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                        fontWeight: isDealer ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (p.isGuest)
                      Text(
                        'Guest',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
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
    required this.settled,
  });

  final TournamentStructure structure;
  final GameSettings settings;
  final int remainingPlayers;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    const placeLabel = ['1st', '2nd', '3rd', '4th'];

    // Client rule: the price distribution is only calculated at the end of
    // the rebuy level, when the exact field and add-ons are known. Until the
    // settlement is confirmed the admin sees the estimate only.
    if (!settled) {
      return Column(
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppAlertBanner(
                  type: AppAlertType.info,
                  message:
                      'Prize amounts are private — only visible to you as admin.',
                ),
                const SizedBox(height: AppSpacing.md),
                Icon(
                  Icons.lock_outline,
                  size: 28,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Distribution calculated at rebuy close',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Prices are calculated at the end of Level ${settings.rebuysCloseLevel}, '
                  'when the exact number of players, actual rebuys and selected add-ons are known.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Est. prize pool',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${structure.prizePool}',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Organizational costs · ${settings.organizerPct}%',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${structure.organizerAmount}',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppAlertBanner(
                type: AppAlertType.warning,
                message:
                    'Prize amounts are private — only visible to you as admin.',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid places',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: AppSelect<int?>(
                      value: settings.forcePaidPlaces,
                      hint: 'Auto-calculate',
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Auto'),
                        ),
                        for (var i = 1; i <= 10; i++)
                          DropdownMenuItem<int?>(
                            value: i,
                            child: Text('$i paid places'),
                          ),
                      ],
                      onChanged: (v) =>
                          context.read<AppProvider>().overridePaidPlaces(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final p in structure.prizes)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: p.place <= 4
                            ? MedalIcon(p.place, size: AppFontSizes.lg)
                            : Text(
                                '${p.place}.',
                                style: AppTypography.monoSm.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          p.place <= 4
                              ? '${placeLabel[p.place - 1]} place'
                              : '${p.place}th place',
                          style: AppTypography.bodySm,
                        ),
                      ),
                      Text(
                        '${p.amount}',
                        style: AppTypography.monoSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    'Prize pool',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${structure.prizePool}',
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Audit fix E2: label is the percentage; value is the amount.
                  Text(
                    'Organizational costs · ${settings.organizerPct}%',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${structure.organizerAmount}',
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
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
                Text(
                  'Color-up instructions',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final ins in structure.colorUpInstructions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: AppFontSizes.xs,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            ins,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
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
            child: const AppIconLabel(
              label: 'Record finish order',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.auditHistory});

  final List<AuditRecord> auditHistory;

  @override
  Widget build(BuildContext context) {
    if (auditHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Text(
            'No audit events yet.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    // Reverse to show newest first
    final reversed = auditHistory.reversed.toList();

    return Column(
      children: [
        for (final record in reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.edit_note,
                      size: AppFontSizes.lg,
                      color: AppColors.icon,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              record.type.toUpperCase(),
                              style: AppTypography.monoXs.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Formatters.relativeTime(record.timestamp),
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(record.details, style: AppTypography.bodySm),
                        const SizedBox(height: 2),
                        Text(
                          'by ${record.actor}',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        if (widget.koEnabled) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSelect(
            label: 'KO bounty recipient (optional)',
            value: _koRecipient,
            hint: '— None —',
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('— None —'),
              ),
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

/// One column of the speed-change preview (current vs. proposed).
class _PreviewCol extends StatelessWidget {
  const _PreviewCol({
    required this.label,
    required this.duration,
    required this.finish,
    this.highlighted = false,
  });

  final String label;
  final String duration;
  final String finish;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySoft : AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.bodyXs.copyWith(
              color: highlighted
                  ? AppColors.primary
                  : AppColors.mutedForeground,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            duration,
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Est. finish ≈ $finish',
            style: AppTypography.monoSm.copyWith(color: AppColors.foreground),
          ),
        ],
      ),
    );
  }
}

/// Cancel-tournament confirmation form. A reason is required and is recorded
/// in the audit log and shared with members (spec §12).
class _CancelTournamentForm extends StatefulWidget {
  const _CancelTournamentForm({required this.gameName, required this.onCancel});

  final String gameName;
  final ValueChanged<String> onCancel;

  @override
  State<_CancelTournamentForm> createState() => _CancelTournamentFormState();
}

class _CancelTournamentFormState extends State<_CancelTournamentForm> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cancelling ${widget.gameName} stops the timer and removes it from live view. '
          'Members are notified. This cannot be undone from the dashboard.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _reason,
          label: 'Reason (required)',
          hint: 'e.g. venue closed, not enough players',
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep tournament'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.danger,
                onPressed: reason.isEmpty
                    ? null
                    : () => widget.onCancel(reason),
                child: const Text('Cancel tournament'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
