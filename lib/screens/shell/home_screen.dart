import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/app_notification.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/main_button.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/group_switcher.dart';

/// Dashboard mirroring the web `HomePage`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _groupNameController = TextEditingController();
  String _createError = '';
  bool _showCreate = false;

  /// True while `createGroup` is in flight. Creating a group writes a document
  /// and cannot be undone from this screen, so the button has to stop
  /// accepting taps for the duration rather than just look busy.
  bool _creatingGroup = false;
  bool _showRestoreModal = false;

  void _openJoin() => context.go(RoutePaths.join);

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'FP';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    // Always set the current game first so every destination screen
    // has the correct game in the provider (fixes navigation dead-ends).
    app.setCurrentGame(game);
    // The destination is the contextual main action (user-flow spec §9):
    // one event, one dominant next action, resolved from role + state.
    final user = app.user;
    final isAdmin = app.isAdmin;
    final me = user == null
        ? null
        : game.players.where((p) => p.id == user.id).firstOrNull;
    final action = mainActionFor(
      isAdmin ? MainButtonRole.admin : MainButtonRole.member,
      game,
      memberRow: me,
    );
    context.go(action.route ?? RoutePaths.invitation);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final group = app.currentGroup;
    final isAdmin = app.isAdmin;
    // Draft games are only visible to admins (spec §3, §25).
    final games = group.games
        .where(
          (g) =>
              g.status.isUpcoming &&
              (isAdmin || g.status != LiveGameStatus.draft),
        )
        .toList();
    final activeGame = games.where((g) => g.status.isActiveLive).firstOrNull;

    return Stack(
      children: [
        AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Top Header Row
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF381E20),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4A282A)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name.isNotEmpty == true
                              ? user!.name
                              : 'Alex Morgan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go(RoutePaths.notifications),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF242428)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          if (app.notifications.any((n) => !n.read))
                            Positioned(
                              top: 10,
                              right: 11,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD53032),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Screen Title: Large bold white 'Home'
              const Text(
                'Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Group Switcher Card: Squircle card with crimson FP initials badge
              InkWell(
                onTap: () => showGroupSwitcher(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF242428)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD53032),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(app.hasCurrentGroup ? group.name : 'FP'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app.hasCurrentGroup ? group.name : 'Select a group',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF8E8E93),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Offline Conflict Banner
              if (app.hasOfflineConflict) ...[
                AppAlertBanner(
                  type: AppAlertType.warning,
                  message:
                      'Local offline progress detected that is out of sync with the cloud. Would you like to keep the local offline data or revert to cloud?',
                  actionLabel: 'Review Conflict',
                  onAction: () => context.go(RoutePaths.adminDashboard),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
              ] else if (app.restoredFromRecovery && activeGame != null) ...[
                AppAlertBanner(
                  type: AppAlertType.info,
                  message:
                      'An active tournament was found on this device'
                      '${app.restoredAt != null ? ' — last saved ${_hhmm(app.restoredAt!)}' : ''}.',
                  actionLabel: 'Review',
                  onAction: () => setState(() => _showRestoreModal = true),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
              ],

              // 'NEXT UP' Live / Upcoming Card
              ...[
                _NextActionCard(
                  app: app,
                  group: group,
                  isAdmin: isAdmin,
                  onOpen: (g) => _openGame(context, app, g),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Quick action buttons side-by-side: + New game & Cash game
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(RoutePaths.createTournament),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF28282C)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Color(0xFFE5797A), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'New game',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(RoutePaths.cashGame),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF28282C)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cash game',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 'Group snapshot' section
              if (app.hasCurrentGroup) ...[
                const Text(
                  'Group snapshot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _GroupStats(group: group, app: app),
                const SizedBox(height: AppSpacing.xl),
              ],
              // Two-column layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: _UpcomingGames(
                            games: games,
                            isAdmin: app.isAdmin,
                            userId: user?.id,
                            onOpen: (g) => _openGame(context, app, g),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _GroupCard(
                                group: app.hasCurrentGroup ? group : null,
                                loading: app.groupBundleLoading,
                                showJoin: _openJoin,
                                showCreate: () =>
                                    setState(() => _showCreate = true),
                                isAdmin: app.isAdmin,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              if (app.notifications.any((n) => !n.read))
                                _AlertsPreview(
                                  notifications: app.notifications,
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UpcomingGames(
                        games: games,
                        isAdmin: app.isAdmin,
                        userId: user?.id,
                        onOpen: (g) => _openGame(context, app, g),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _GroupCard(
                        group: app.hasCurrentGroup ? group : null,
                        loading: app.groupBundleLoading,
                        showJoin: _openJoin,
                        showCreate: () => setState(() => _showCreate = true),
                        isAdmin: app.isAdmin,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (app.notifications.any((n) => !n.read))
                        _AlertsPreview(notifications: app.notifications),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Modals
        AppModal(
          open: _showCreate,
          onClose: () => setState(() => _showCreate = false),
          title: 'Create a group',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _groupNameController,
                label: 'Group name',
                placeholder: 'e.g. Friday Poker Club',
                error: _createError.isEmpty ? null : _createError,
                onChanged: (_) => setState(() => _createError = ''),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                fullWidth: true,
                size: AppButtonSize.lg,
                disabled: _groupNameController.text.trim().length < 2,
                loading: _creatingGroup,
                onPressed: () async {
                  if (_creatingGroup) return;
                  if (_groupNameController.text.trim().length < 2) return;
                  setState(() {
                    _creatingGroup = true;
                    _createError = '';
                  });
                  final created = await app.createGroup(
                    _groupNameController.text.trim(),
                  );
                  if (!context.mounted) return;
                  if (created == null) {
                    setState(() {
                      _creatingGroup = false;
                      _createError =
                          'Could not create the group. Please try again.';
                    });
                    return;
                  }
                  setState(() {
                    _creatingGroup = false;
                    _showCreate = false;
                  });
                  context.go(RoutePaths.group);
                },
                child: const Text('Create Group'),
              ),
            ],
          ),
        ),
        // Restore-active-tournament prompt (Tech §20.1, audit fix B8):
        // shows the last-saved local time and offers Restore or Discard.
        AppModal(
          open: _showRestoreModal && app.restoredFromRecovery,
          onClose: () => setState(() => _showRestoreModal = false),
          title: 'Restore active tournament?',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAlertBanner(
                type: AppAlertType.info,
                message: app.restoredAt != null
                    ? 'A saved game was found — last saved locally at ${_hhmm(app.restoredAt!)}.'
                    : 'A saved game was found on this device.',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                variant: AppButtonVariant.primary,
                fullWidth: true,
                onPressed: () {
                  // Keep the restored state.
                  app.resolveOfflineConflict(keepLocal: true);
                  setState(() => _showRestoreModal = false);
                },
                child: const Text('Restore and continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                onPressed: () {
                  app.discardRestoredGame();
                  setState(() => _showRestoreModal = false);
                },
                child: const Text('Discard saved game'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Group activity snapshot shown on Home — answers "how is the group doing?"
/// with counts that already exist in the provider (IA §7).
class _GroupStats extends StatelessWidget {
  const _GroupStats({required this.group, required this.app});

  final Group group;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final past = group.pastGames.length;
    final members = group.members.length;
    final cash = app.cashHistory.length;
    final prizeVolume = group.pastGames.fold<int>(
      0,
      (s, g) => s + g.structure.prizePool,
    );
    final cashVolume = app.cashHistory.fold<double>(
      0,
      (s, c) => s + c.totalBuyIns,
    );
    final totalVol = prizeVolume + cashVolume;
    final volumeStr = totalVol >= 1000
        ? '${(totalVol / 1000).round()}k'
        : '\$$totalVol';

    return Row(
      children: [
        _MetricCard(value: '$past', label: 'games'),
        const SizedBox(width: 8),
        _MetricCard(value: '$members', label: 'members'),
        const SizedBox(width: 8),
        _MetricCard(value: '$cash', label: 'cash\ngames'),
        const SizedBox(width: 8),
        _MetricCard(
          value: volumeStr,
          label: 'volume',
          valueColor: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF242428)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card that answers "what should I do next?" for the current user
/// (User Flow §4.1 — Home identifies the next required action, and shows
/// pending check-ins / confirmed attendance for the admin).
class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.app,
    required this.group,
    required this.isAdmin,
    required this.onOpen,
  });

  final AppProvider app;
  final Group group;
  final bool isAdmin;
  final ValueChanged<LiveGame> onOpen;

  LiveGame? _target() {
    final games = group.games.where((g) => g.status.isUpcoming).toList();
    if (games.isEmpty) return null;
    // Prefer a live game, then check-in/ready, then published.
    for (final s in [
      LiveGameStatus.running,
      LiveGameStatus.paused,
      LiveGameStatus.rebuypause,
      LiveGameStatus.finaltable,
      LiveGameStatus.checkin,
      LiveGameStatus.ready,
      LiveGameStatus.published,
      LiveGameStatus.draft,
    ]) {
      final g = games.where((g) => g.status == s).firstOrNull;
      if (g != null) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = _target();
    if (game == null) return const SizedBox.shrink();

    final going = game.goingCount;
    final (title, subtitle, actionLabel) = switch (game.status) {
      LiveGameStatus.running || LiveGameStatus.paused => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open dashboard',
      ),
      LiveGameStatus.rebuypause => (
        game.settings.name,
        'Settlement required · $going going',
        'Complete break',
      ),
      LiveGameStatus.finaltable => (
        game.settings.name,
        'Final table · 9 remain · $going going',
        'Redraw table',
      ),
      LiveGameStatus.checkin || LiveGameStatus.ready => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open check-in',
      ),
      _ => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open dashboard',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD53032).withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33D53032),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT UP',
            style: TextStyle(
              color: Color(0xFFE5797A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : 'Friday Night Freezeout',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (game.status.isActiveLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3826),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => onOpen(game),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFD53032),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40D53032),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingGames extends StatelessWidget {
  const _UpcomingGames({
    required this.games,
    required this.isAdmin,
    required this.userId,
    required this.onOpen,
  });

  final List<LiveGame> games;
  final bool isAdmin;
  final String? userId;
  final ValueChanged<LiveGame> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.group),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: Color(0xFFE5797A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (games.isEmpty)
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: AppEmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No upcoming games',
              description:
                  'The tables are empty. Create a tournament to get the action started.',
              action: isAdmin
                  ? AppButton(
                      onPressed: () => context.go(RoutePaths.createTournament),
                      child: const Text('Create First Game'),
                    )
                  : null,
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < games.length; i++) ...[
                _GameRow(
                  game: games[i],
                  isAdmin: isAdmin,
                  userId: userId,
                  onOpen: () => onOpen(games[i]),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.isAdmin,
    required this.userId,
    required this.onOpen,
  });

  final LiveGame game;
  final bool isAdmin;
  final String? userId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final going = game.goingCount;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF242428)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFD53032),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.settings.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${game.settings.date} ${game.settings.time} · Buy-in \$${game.settings.buyIn} · $going going',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242428),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'RSVP',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.showJoin,
    required this.showCreate,
    required this.isAdmin,
    this.loading = false,
  });

  final Group? group;
  final VoidCallback showJoin;
  final VoidCallback showCreate;
  final bool isAdmin;

  /// A group is selected but its live bundle is still loading (e.g. just
  /// joined) — show a spinner instead of the card or the empty state.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Group',
              style: AppTypography.display(
                size: AppFontSizes.xl,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading your group…',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (g != null) ...[
          AppCard(
            onTap: () => context.go(RoutePaths.group),
            glow: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.name,
                        style: AppTypography.display(
                          size: AppFontSizes.xl,
                          weight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.mutedForeground,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Member avatars overlapping row
                if (g.members.isNotEmpty) ...[
                  Row(
                    children: [
                      SizedBox(
                        height: 32,
                        width: (g.members.take(5).length * 22 + 10)
                            .toDouble()
                            .clamp(32, 130),
                        child: Stack(
                          children: [
                            for (var i = 0; i < g.members.take(5).length; i++)
                              Positioned(
                                left: i * 22.0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.card,
                                      width: 2,
                                    ),
                                    color:
                                        AppColors.avatarPalette[(g
                                                    .members[i]
                                                    .name
                                                    .isNotEmpty
                                                ? g.members[i].name.codeUnitAt(
                                                    0,
                                                  )
                                                : 0) %
                                            AppColors.avatarPalette.length],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    g.members[i].name.isNotEmpty
                                        ? g.members[i].name[0].toUpperCase()
                                        : '?',
                                    style: AppTypography.body(
                                      size: 12,
                                      weight: FontWeight.w700,
                                    ).copyWith(color: AppColors.foreground),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${g.members.length} member${g.members.length == 1 ? '' : 's'}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Text(
                      'Join Code',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        g.joinCode,
                        style: AppTypography.mono(
                          size: AppFontSizes.sm,
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onPressed: showJoin,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: AppSpacing.xs),
                Text('Join another group'),
              ],
            ),
          ),
        ] else
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xs),
                Icon(
                  Icons.handshake_outlined,
                  size: 48,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No group yet. Join with a code or create your own.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  fullWidth: true,
                  onPressed: showJoin,
                  child: const Text('Join Existing Group'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isAdmin)
                  AppButton(
                    fullWidth: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: showCreate,
                    child: const Text('Create New Group'),
                  ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
      ],
    );
  }
}

class _AlertsPreview extends StatelessWidget {
  const _AlertsPreview({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.read).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Alerts',
                    style: AppTypography.display(
                      size: AppFontSizes.xl,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.notifications),
              child: Text(
                'See all',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Column(
          children: [
            for (var i = 0; i < unread.length; i++)
              Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unread[i].title,
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      unread[i].type == NotificationType.game
                                          ? 'Game update'
                                          : 'Alert',
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '· ${Formatters.relativeTime(unread[i].timestamp)}',
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (i * 90).ms, duration: 400.ms)
                  .slideX(
                    begin: 0.08,
                    end: 0,
                    delay: (i * 90).ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
          ],
        ),
      ],
    );
  }
}
