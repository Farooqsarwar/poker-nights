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
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/code_display.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pace_cards.dart';
import '../../widgets/app_text_field.dart';

/// C0 -- "Start a game now". Friends are already at the table: four answers
/// and one tap, and the clock runs.
///
/// It is the same engine and the same game document as the planned wizard
/// (C1); this screen only fills the inputs in for the host and then walks the
/// steps the check-in desk would (walk-ins, structure, seating, start).
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  /// The wizard's own opening chip set (`presetNames[2]`).
  static const _standardPresetIndex = 2;
  static const _hoursOptions = [2, 3, 4, 5];
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

  int _players = 8;
  int _hours = 4;
  int _buyIn = 15;
  bool _rebuy = false;
  PaceMode? _pace;
  bool _seeded = false;
  bool _starting = false;
  String? _error;
  bool _showNameInputs = false;
  final List<TextEditingController> _nameControllers = [];

  void _syncNameControllers() {
    while (_nameControllers.length < _players) {
      _nameControllers.add(TextEditingController());
    }
    while (_nameControllers.length > _players) {
      _nameControllers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  PaceOptions? _optionsCache;
  String? _optionsKey;

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

  TournamentParams _params(AppProvider app, {PaceMode? pace}) {
    return TournamentParams(
      players: _players < 2 ? 2 : _players,
      durationHours: _hours.toDouble(),
      buyIn: _buyIn,
      chipSet: _chips(app),
      rebuys: _rebuy,
      rebuysCloseLevel: 0,
      rebuyCloseChosenByOrganizer: false,
      reEntry: false,
      addOn: _rebuy,
      anteEnabled: true,
      anteAfterLevel: 6,
      koEnabled: false,
      koAmount: 5,
      organizerPct: 0,
      expectedRebuyRate: _rebuy ? 0.35 : 0,
      pace: pace,
    );
  }

  PaceOptions _options(AppProvider app) {
    final key = [
      _players,
      _hours,
      _rebuy,
      _chips(app).map((c) => '${c.value}x${c.quantity}').join(','),
    ].join('|');
    if (_optionsKey == key && _optionsCache != null) return _optionsCache!;
    final opts = TournamentEngine.paceOptions(_params(app));
    _optionsKey = key;
    _optionsCache = opts;
    return opts;
  }

  PaceMode _effectivePace(PaceOptions opts) =>
      _pace ?? opts.recommended ?? PaceMode.regular;

  String _sentence(AppProvider app, PaceOptions opts) {
    final pace = _effectivePace(opts);
    final o = opts.options.where((o) => o.pace == pace).firstOrNull;
    if (o == null) return '';
    final depth = o.startingDepthBB.round();
    return 'Structure for $_players players over ${_hours}h: '
        '$depth big blinds deep, opening ${o.openingSB}/${o.openingBB}, '
        '${o.levelMinutes}-minute levels (${pace.label}), '
        '${o.levels} levels. ${_rebuy ? 'Rebuys and one add-on. ' : ''}'
        '$_buyIn buy-in. You can still edit any level.';
  }

  GameSettings _settings(AppProvider app, PaceMode pace) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = '${_weekdays[now.weekday - 1]} Poker';
    final structure = TournamentEngine.generate(_params(app, pace: pace));
    final rebuyClose = _rebuy ? structure.rebuysCloseLevel : 0;
    return GameSettings(
      name: name,
      date: '${now.year}-${two(now.month)}-${two(now.day)}',
      time: '${two(now.hour)}:${two(now.minute)}',
      location: '',
      players: _players,
      durationHours: _hours.toDouble(),
      pace: pace,
      buyIn: _buyIn,
      koEnabled: false,
      koAmount: 5,
      rebuys: _rebuy,
      rebuysCloseLevel: rebuyClose,
      reEntry: false,
      addOn: _rebuy,
      addOnCloseLevel: rebuyClose,
      anteEnabled: true,
      anteAfterLevel: rebuyClose > 0 ? rebuyClose + 1 : 6,
      anteStyle: AnteStyle.bigBlind,
      antePreference: AntePreference.recommend,
      organizerPct: 0,
      chipSet: _chips(app),
      chipSetName: _chipsName(app),
      locationPrivate: false,
      breaks: const [],
    );
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

  Future<void> _start(AppProvider app) async {
    if (_starting) return;
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

    final pace = _effectivePace(_options(app));
    final created = app.createGame(_settings(app, pace));
    // A quick game is the people at the table, not the group roster.
    app.setCurrentGame(created.copyWith(players: const []));
    app.publishGame(announce: false);
    final customNames = _nameControllers.map((c) => c.text.trim()).toList();
    final hasAnyCustomName = customNames.any((n) => n.isNotEmpty);
    app.addQuickPlayers(_players, names: hasAnyCustomName ? customNames : null);
    app.generateFinalStructure(_players);
    app.confirmStructure();
    app.generateSeating(TableSeatingMode.random);
    app.confirmSeating();
    await app.startTournament();
    if (!mounted) return;
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

    final cap = _cap(app);
    if (!_seeded) {
      _seeded = true;
      final last = _lastHeadcount(app);
      _players = (last ?? 8).clamp(2, cap);
    }
    if (_players > cap) _players = cap;

    final opts = _options(app);
    final selected = _effectivePace(opts);
    final atFreeCap = !app.canHostPlayers(_premiumMaxPlayers) && _players >= cap;
    final last = _lastHeadcount(app);
    final chips = _chips(app);
    final pieces = chips.fold<int>(0, (sum, c) => sum + c.quantity);

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
            subtitle:
                'Friends already at the table? Four answers and one tap.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _QuickCard(
            eyebrow: 'Players',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountStepper(
                  value: _players,
                  min: 2,
                  max: cap,
                  suffix: 'players',
                  semanticLabel: 'Players',
                  onChanged: (v) => setState(() {
                    _players = v;
                    _pace = null;
                    _syncNameControllers();
                  }),
                ),
                if (last != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Hint(
                    'Last time at ${app.currentGroup.name}: $last',
                  ),
                ],
                if (atFreeCap) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Hint(
                    'One table seats up to $cap on the free plan. For two '
                    'tables, plan the night from New tournament.',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () {
                    _syncNameControllers();
                    setState(() => _showNameInputs = !_showNameInputs);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _showNameInputs
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showNameInputs
                              ? 'Hide player names'
                              : 'Add player names (optional)',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showNameInputs) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter your friends’ names for the scoreboard and seating (or leave blank for Player 1, Player 2...)',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _players; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: AppTextField(
                              controller: _nameControllers[i],
                              placeholder: 'Player ${i + 1} name (e.g. Alex)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickCard(
            eyebrow: 'How long',
            child: AppTabs(
              tabs: [
                for (final h in _hoursOptions)
                  AppTabItem(id: '$h', label: '${h}h'),
              ],
              active: '$_hours',
              onChanged: (id) => setState(() {
                _hours = int.parse(id);
                _pace = null;
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickCard(
            eyebrow: 'Pace',
            child: PaceCards(
              options: opts,
              selected: selected,
              onSelected: (p) => setState(() => _pace = p),
              onChooseLater: () => setState(() {
                _hours = _hoursOptions.firstWhere(
                  (h) => h > _hours,
                  orElse: () => _hoursOptions.last,
                );
                _pace = null;
              }),
              onDropAddOn: _rebuy
                  ? () => setState(() {
                      _rebuy = false;
                      _pace = null;
                    })
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickCard(
            eyebrow: 'Buy-in',
            child: CountStepper(
              value: _buyIn,
              min: 5,
              max: 100,
              step: 5,
              semanticLabel: 'Buy-in',
              onChanged: (v) => setState(() => _buyIn = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickCard(
            eyebrow: 'Format',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTabs(
                  tabs: const [
                    AppTabItem(id: 'freeze', label: 'Freeze Out'),
                    AppTabItem(id: 'rebuy', label: 'Rebuy'),
                  ],
                  active: _rebuy ? 'rebuy' : 'freeze',
                  onChanged: (id) => setState(() {
                    _rebuy = id == 'rebuy';
                    _pace = null;
                  }),
                ),
                if (_rebuy) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _Hint(
                    'Rebuys plan for 35% of the field, with one add-on at '
                    '125% of a starting stack.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_chipsName(app)} · $pieces pcs',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (chips.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'No chip set found — add one in Chip sets first.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.destructiveText,
                ),
              ),
            ),
          _QuickCard(
            eyebrow: "What you'll get",
            child: Text(
              _sentence(app, opts),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.foreground,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null) ...[
            Text(
              _error!,
              style: AppTypography.bodySm.copyWith(color: AppColors.destructiveText),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _starting,
            onPressed: chips.isEmpty ? null : () => _start(app),
            child: const Text('Generate & start the clock'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEyebrow(eyebrow, muted: true),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
    );
  }
}
