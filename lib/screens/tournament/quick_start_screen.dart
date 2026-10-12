import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/structure_builder_controller.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/code_display.dart';
import '../../widgets/page_header.dart';
import '../../widgets/structure_builder.dart';

/// C0 -- "Start a game now". Friends are already at the table.
///
/// The shared stack-first [StructureBuilder] (WP2): the host answers the setup,
/// approves the starting stack, looks at the levels, and only then does the
/// clock run. It is the same engine and the same game document as the planned
/// wizard (C1); the final tap walks the steps the check-in desk would
/// (walk-ins, structure, seating, start).
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  /// The wizard's own opening chip set (`presetNames[2]`).
  static const _standardPresetIndex = 2;
  static const _premiumMaxPlayers = 30;
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  StructureBuilderController? _controller;
  bool _starting = false;
  String? _error;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// The last completed game's headcount in this group, or null.
  int? _lastHeadcount(AppProvider app) {
    for (final g in app.currentGroup.games.reversed) {
      if (g.status != LiveGameStatus.completed) continue;
      final n = g.players.where((p) => p.checkedIn && p.confirmed).length;
      if (n >= 2) return n;
    }
    return null;
  }

  /// Free hosting stops at one table (D5). Quick start never offers the
  /// second-table prompt, so the stepper simply stops there.
  int _cap(AppProvider app) => app.canHostPlayers(_premiumMaxPlayers)
      ? _premiumMaxPlayers
      : app.currentGroup.tableSettings.maxPerTable.clamp(2, _premiumMaxPlayers);

  List<ChipColor> _chips(AppProvider app) {
    final id = app.currentGroup.defaultChipSetId ?? app.defaultChipSetId;
    if (id != null) {
      for (final cs in app.savedChipSets) {
        if (cs.id == id) return cs.chips;
      }
    }
    final names = TournamentEngine.presetNames;
    if (names.isEmpty) return const [];
    return TournamentEngine.getPreset(
      names[_standardPresetIndex.clamp(0, names.length - 1)],
    );
  }

  String _chipsName(AppProvider app) {
    final id = app.currentGroup.defaultChipSetId ?? app.defaultChipSetId;
    if (id != null) {
      for (final cs in app.savedChipSets) {
        if (cs.id == id) return cs.name;
      }
    }
    final names = TournamentEngine.presetNames;
    return names.isEmpty
        ? ''
        : names[_standardPresetIndex.clamp(0, names.length - 1)];
  }

  StructureBuilderController _controllerFor(AppProvider app) {
    return _controller ??= StructureBuilderController(
      mode: BuilderMode.quick,
      chipSet: _chips(app),
      chipSetName: _chipsName(app),
      players: (_lastHeadcount(app) ?? 8).clamp(2, _cap(app)),
      durationHours: 4,
      startMinutes: DateTime.now().hour * 60 + DateTime.now().minute,
    );
  }

  /// The settings the game is created with: a plain "tonight" night, carrying
  /// every builder choice.
  GameSettings _settings(AppProvider app, StructureBuilderController c) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final base = GameSettings(
      name: '${_weekdays[now.weekday - 1]} Poker',
      date: '${now.year}-${two(now.month)}-${two(now.day)}',
      time: '${two(now.hour)}:${two(now.minute)}',
      location: '',
      players: c.players,
      durationHours: c.durationHours,
      buyIn: c.buyIn,
      koEnabled: false,
      koAmount: 5,
      rebuys: false,
      rebuysCloseLevel: 0,
      addOn: false,
      anteEnabled: true,
      anteAfterLevel: 6,
      organizerPct: 0,
      chipSet: c.chipSet,
      chipSetName: c.chipSetName,
      locationPrivate: false,
      breaks: const [],
    );
    return c.applyTo(base);
  }

  /// C0: "Starting a new game ends it." Returns whether to carry on.
  Future<bool> _confirmReplace(AppProvider app, LiveGame running) async {
    var proceed = false;
    await showAppModal(
      context: context,
      title: '${running.settings.name} is still running',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Starting a new game ends it. The levels played so far are kept '
            'in History, marked unfinished, and it does not count for '
            'standings.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.destructive,
            onPressed: () {
              proceed = true;
              Navigator.of(context).pop();
            },
            child: const Text('End it and start'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Keep ${running.settings.name} running'),
          ),
        ],
      ),
    );
    return proceed;
  }

  Future<void> _start(AppProvider app, TournamentStructure approved) async {
    if (_starting) return;
    final c = _controller!;
    // Defensive: the confirm button is disabled when blocked, but nothing
    // (game, group, guest sign-in) may be created for a night the chips cannot
    // deal.
    if (approved.isBlocked) return;
    final running = app.currentGame;
    if (running != null && running.status.isActiveLive) {
      final proceed = await _confirmReplace(app, running);
      if (!mounted) return;
      if (!proceed) {
        context.go(RoutePaths.hostDashboard);
        return;
      }
      app.cancelGame('Replaced by a quick game');
    }

    setState(() {
      _starting = true;
      _error = null;
    });

    // A2b: no account needed. An anonymous session hosts on a group of its
    // own, which the host can later upgrade to a real account.
    if (!app.isAuthenticated) {
      final err = await app.signInAsGuest();
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _starting = false;
          _error = err;
        });
        return;
      }
    }
    if (!app.hasCurrentGroup) {
      final group = await app.createGroup('My games');
      if (!mounted) return;
      if (group == null) {
        setState(() {
          _starting = false;
          _error = 'Could not set up the game. Check your connection and try again.';
        });
        return;
      }
      await app.groupReady.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      if (!mounted) return;
    }

    final created = app.createGame(_settings(app, c));
    // A quick game is the people at the table, not the group roster.
    app.setCurrentGame(created.copyWith(players: const []));
    app.publishGame(announce: false);
    app.addQuickPlayers(c.players);
    // Rebuilds from the saved settings, which carry the approved stack, the
    // pinned levels and a chosen rebuy close: the structure the host approved.
    app.generateFinalStructure(c.players);
    app.confirmStructure();
    app.generateSeating(TableSeatingMode.random);
    app.confirmSeating();
    final started = await app.startTournament();
    if (!mounted) return;
    if (!started) {
      // The structure rebuilt for the final headcount can't be dealt: do not
      // open the dashboard or show a join code for a clock that isn't running.
      setState(() {
        _starting = false;
        _error = 'The chip case can’t fund this night. Change the chips, '
            'players or format, then try again.';
      });
      return;
    }
    setState(() => _starting = false);
    await _showJoinCode(app.currentGame?.publicCode);
    if (!mounted) return;
    if (app.isAdmin) {
      context.go(RoutePaths.hostDashboard);
    } else {
      context.go(RoutePaths.playerLive);
    }
  }

  /// C0: the clock is running; show the join code before the dashboard so the
  /// table can join by code (no account, no app).
  Future<void> _showJoinCode(String? code) async {
    if (code == null || code.isEmpty) return;
    await showAppModal(
      context: context,
      title: 'Your game is live',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join code · Players and the TV. No account, no app.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: CodeDisplay(code: code, label: 'Join code')),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Open the clock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Signed out, or signed in with no group yet: the form is still open (the
    // game gets a group of its own when it starts). Only a plain member of the
    // current group is turned away.
    final canHost = !app.isAuthenticated || !app.hasCurrentGroup || app.isAdmin;
    if (!canHost) {
      return AppPage(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              onBack: () => context.go(RoutePaths.home),
              title: 'Start a game now',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Text(
                'Only a group host can start a game. Ask your host, or use the '
                'free clock in Tools.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              fullWidth: true,
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    }

    final controller = _controllerFor(app);
    final last = _lastHeadcount(app);
    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(
              app.isAuthenticated ? RoutePaths.home : RoutePaths.landing,
            ),
            title: 'Start a game now',
            subtitle: 'Friends already at the table? Set it up, check the '
                'stack, and the clock runs.',
          ),
          const SizedBox(height: AppSpacing.lg),
          StructureBuilder(
            controller: controller,
            confirmLabel: 'Start the clock',
            maxPlayers: _cap(app),
            playersHint: last == null ? null : 'Last time: $last players',
            busy: _starting,
            error: _error,
            onEditChips: () => context.push(RoutePaths.chipSets).then((_) {
              if (mounted) controller.setChipSet(_chips(app));
            }),
            onConfirm: (s) => _start(app, s),
          ),
        ],
      ),
    );
  }
}
