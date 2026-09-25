import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../services/tv_display_settings.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/app_modal.dart';
import '../../services/entitlements.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/backgrounds.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/tournament_display_block.dart';
import '../../utils/formatters.dart';

/// Full-screen TV display mirroring the web `TVModePage`.
class TVModeScreen extends StatefulWidget {
  const TVModeScreen({super.key});

  @override
  State<TVModeScreen> createState() => _TVModeScreenState();
}

class _TVModeScreenState extends State<TVModeScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final result = await context.read<AppProvider>().enterGameCode(
      _codeController.text.trim(),
    );
    if (!mounted) return;
    if (result == CodeLookupResult.notFound) {
      setState(() => _codeError = 'Code not found — try again');
    } else if (result == CodeLookupResult.rateLimited) {
      setState(() => _codeError = 'Too many attempts — wait a minute');
    } else {
      setState(() => _codeError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.tvGame;

    if (game == null || game.status == LiveGameStatus.cancelled) {
      return _CodeEntry(
        controller: _codeController,
        error: _codeError,
        onConnect: _connect,
      );
    }
    return TVBackground(child: _TVLayout(game: game));
  }
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.controller,
    required this.error,
    required this.onConnect,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: TVBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The lockup is a fixed 60px glyph next to "POKER NIGHT" at
                  // 36pt — about 471px wide, inside a 384px box. That is a
                  // constant 87px overflow at every width from tablet up, and
                  // 231px on a 320px phone. FittedBox scales the whole lockup
                  // down as one unit so the icon and the wordmark keep their
                  // relative size; scaleDown means it never grows past its
                  // designed 36pt when there is room.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style, size: 60, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'POKER NIGHT',
                          style: AppTypography.crimsonShimmer(
                            size: 36,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.cardGlow,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TV Display',
                          style: AppTypography.display(size: AppFontSizes.xxl),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter the TV code shown by the admin',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: controller,
                          maxLength: 8,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: AppTypography.monoXl.copyWith(
                            letterSpacing: 3,
                          ),
                          onChanged: (_) {},
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'TV CODE',
                            hintStyle: AppTypography.monoXl.copyWith(
                              color: AppColors.onSurfaceHint,
                              letterSpacing: 3,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(color: AppColors.ring),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            error!,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.destructiveText,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: onConnect,
                          child: const Text('Connect to game'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Demo TV code: ',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: InkWell(
                                  onTap: () => controller.text = 'TV-FP',
                                  child: Text(
                                    'TV-FP',
                                    style: AppTypography.monoSm.copyWith(
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () => context.go(RoutePaths.landing),
                    child: const Text('Back to website'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TVLayout extends StatefulWidget {
  const _TVLayout({required this.game});

  final LiveGame game;

  @override
  State<_TVLayout> createState() => _TVLayoutState();
}

class _TVLayoutState extends State<_TVLayout> {
  /// Defaults until the stored settings arrive, so the first frame shows the
  /// tournament rather than a spinner. A TV that is slow to read its own
  /// preferences should still be readable from across the room meanwhile.
  TvDisplaySettings _display = const TvDisplaySettings();

  @override
  void initState() {
    super.initState();
    TvDisplayStore.load().then((d) {
      if (mounted) setState(() => _display = d);
    });
  }

  Future<void> _apply(TvDisplaySettings next) async {
    setState(() => _display = next);
    await TvDisplayStore.save(next);
  }

  void _openSettings() {
    showAppModal(
      context: context,
      title: 'Display settings',
      maxWidth: 420,
      child: _TvSettingsSheet(
        initial: _display,
        onChanged: _apply,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isCompleted = game.status == LiveGameStatus.completed;

    if (isCompleted && game.finishOrder.length >= 3) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: _Podium(game: game)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Opacity(
        // Deliberately faint. It must be findable by the host standing at the
        // screen and invisible to players glancing at it from the table.
        opacity: 0.35,
        child: FloatingActionButton.small(
          heroTag: 'tv-display-settings',
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.foreground,
          tooltip: 'Display settings',
          onPressed: _openSettings,
          child: const Icon(Icons.tune, size: 18),
        ),
      ),
      // TV mode usually runs on a real display with no insets, but it is
      // reachable on a tablet — where the banner and the clock would
      // otherwise sit under the status bar / camera cutout.
      body: SafeArea(
        child: Column(
        children: [
          // Event identity + TV code, so whoever is standing at the screen
          // can confirm it is showing the right game at a glance.
          _TVHeader(name: game.settings.name, tvCode: game.tvCode),
          // Reconnection banner for TV mode (tech spec §4.2).
          Consumer<AppProvider>(
            builder: (_, app, x) {
              if (app.hasReconnected) {
                return AppAlertBanner(
                  type: AppAlertType.success,
                  message: 'Back online — data is live.',
                  actionLabel: 'Dismiss',
                  onAction: () => app.clearReconnectedBanner(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Width sets the base scale; the host's multiplier accounts
                // for how far away the table actually is, which no viewport
                // measurement can know (section 8: readable at distance).
                final s = ((constraints.maxWidth / 1536) * _display.textScale)
                    .clamp(0.5, 3.0)
                    .toDouble();
                if (constraints.maxWidth >= 900) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          // The scoreboard is the point of the TV; it gets
                          // the larger share beside the rotating panel.
                          flex: 5,
                          child: Column(
                            children: [
                              Expanded(
                                // Always the wide scoreboard layout (the TV
                                // frame), laid out at its reference width and
                                // scaled to the column. Given the column's
                                // own width it fell back to the phone layout
                                // at phone-sized type.
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: 1536,
                                    child: TournamentDisplayBlock(
                                      game: game,
                                      showPayoutAmounts: false,
                                    ),
                                  ),
                                ),
                              ),
                              Consumer<AppProvider>(
                                builder: (_, app, x) {
                                  final lastSync = app.lastGameUpdate;
                                  if (lastSync == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final stale =
                                      DateTime.now()
                                          .difference(lastSync)
                                          .inSeconds >
                                      10;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: stale
                                          ? AppAlertBanner(
                                              type: AppAlertType.warning,
                                              message:
                                                  'Connection interrupted — feed may be stale.',
                                            )
                                          : Text(
                                              'Synced ${_formatLastSync(lastSync)}',
                                              style: AppTypography.mono(
                                                size: 10,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 3,
                          child: _RotatingPanel(
                            game: game,
                            scale: s,
                            display: _display,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      TournamentDisplayBlock(
                        game: game,
                        showPayoutAmounts: false,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Consumer<AppProvider>(
                        builder: (_, app, x) {
                          final lastSync = app.lastGameUpdate;
                          if (lastSync == null) return const SizedBox.shrink();
                          final stale =
                              DateTime.now().difference(lastSync).inSeconds >
                              10;
                          return stale
                              ? AppAlertBanner(
                                  type: AppAlertType.warning,
                                  message:
                                      'Connection interrupted — feed may be stale.',
                                )
                              : Text(
                                  'Synced ${_formatLastSync(lastSync)}',
                                  style: AppTypography.mono(
                                    size: 10,
                                    color: AppColors.mutedForeground,
                                  ),
                                );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Slim identity bar above the scoreboard clock — the event name and the
/// TV code that was used to connect this screen. Purely informational: the
/// host glances up to confirm this display is showing the right game.
class _TVHeader extends StatelessWidget {
  const _TVHeader({required this.name, required this.tvCode});

  final String name;
  final String tvCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              tvCode,
              style: AppTypography.monoXs.copyWith(
                color: AppColors.mutedForeground,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    // Columns display [2nd, 1st, 3rd] left → right (winner centred, tallest).
    const labels = ['2nd', '1st', '3rd'];
    const places = [2, 1, 3];
    final heights = [170.0, 240.0, 140.0];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tournament Complete!',
            style: AppTypography.display(
              size: 36,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: _PodiumStep(
                    place: places[i],
                    label: labels[i],
                    name: _podiumName(game, places[i]),
                    height: heights[i],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// finishOrder is "first-out first", so place P sits at index len - P.
  String? _podiumName(LiveGame game, int place) {
    final pos = game.finishOrder.length - place;
    if (pos < 0 || pos >= game.finishOrder.length) return null;
    final id = game.finishOrder[pos];
    for (final p in game.players) {
      if (p.id == id) return p.name;
    }
    return null;
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.place,
    required this.label,
    required this.name,
    required this.height,
  });

  final int place;
  final String label;
  final String? name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: height,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MedalIcon(place, size: AppFontSizes.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name ?? '—',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingPanel extends StatefulWidget {
  const _RotatingPanel({
    required this.game,
    this.scale = 1.0,
    this.display = const TvDisplaySettings(),
  });

  final LiveGame game;
  final double scale;

  /// Which panels this screen shows and how long each holds.
  final TvDisplaySettings display;

  @override
  State<_RotatingPanel> createState() => _RotatingPanelState();
}

class _RotatingPanelState extends State<_RotatingPanel> {
  static const _titles = [
    'LEADERBOARD',
    'PRIZE POOL',
    'ANNOUNCEMENTS',
    'UPCOMING',
  ];

  int _panel = 0;
  Timer? _timer;

  /// The panels this screen actually rotates through, in display order.
  ///
  /// Announcements are never switchable: they exist because the host needed
  /// to tell the room something, and a screen that can hide them is worse
  /// than one that cannot be configured at all.
  List<int> get _active {
    final d = widget.display;
    return [
      if (d.showLeaderboard || !d.hasAnyPanel) 0,
      if (d.showPayouts) 1,
      if (widget.game.announcements.isNotEmpty) 2,
      if (d.showUpcoming) 3,
    ];
  }

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(_RotatingPanel old) {
    super.didUpdateWidget(old);
    if (old.display.rotateSeconds != widget.display.rotateSeconds) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: widget.display.rotateSeconds),
      (_) {
        final n = _active.length;
        if (n <= 1) return;
        setState(() => _panel = (_panel + 1) % n);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    // Falls back to the leaderboard rather than rendering an empty box if a
    // screen somehow ends up with nothing selected.
    final effectivePanel = active.isEmpty ? 0 : active[_panel % active.length];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _titles[effectivePanel],
            style: AppTypography.mono(
              size: 15 * widget.scale,
              weight: FontWeight.w700,
              letterSpacing: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: switch (effectivePanel) {
                0 => _LeaderboardPanel(
                  key: const ValueKey(0),
                  game: widget.game,
                  scale: widget.scale,
                ),
                1 => _PayoutsPanel(
                  key: const ValueKey(1),
                  game: widget.game,
                  scale: widget.scale,
                ),
                2 => _AnnouncementsPanel(
                  key: const ValueKey(2),
                  game: widget.game,
                  scale: widget.scale,
                ),
                _ => _UpcomingPanel(
                  key: const ValueKey(3),
                  game: widget.game,
                  scale: widget.scale,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({super.key, required this.game, this.scale = 1.0});

  final LiveGame game;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final players = [...game.players]
      ..sort((a, b) {
        if (a.active && !b.active) return -1;
        if (!a.active && b.active) return 1;
        if (!a.active && !b.active) {
          return (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0);
        }
        final t = a.table.compareTo(b.table);
        return t != 0 ? t : a.seat.compareTo(b.seat);
      });

    String ordinalPlace(int n) {
      if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
      return switch (n % 10) {
        1 => '${n}st',
        2 => '${n}nd',
        3 => '${n}rd',
        _ => '${n}th',
      };
    }

    return ListView(
      children: [
        for (final p in players)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono(
                      size: 12 * scale,
                      color: p.active
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  p.active
                      ? 'T${p.table} · S${p.seat}'
                      : p.eliminationPos != null
                      ? '${ordinalPlace(p.eliminationPos!)} place'
                      : 'Out',
                  style: AppTypography.mono(
                    size: 11 * scale,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PayoutsPanel extends StatelessWidget {
  const _PayoutsPanel({super.key, required this.game, this.scale = 1.0});

  final LiveGame game;
  final double scale;

  static const _ords = ['1ST', '2ND', '3RD', '4TH', '5TH', '6TH'];

  @override
  Widget build(BuildContext context) {
    // Projections carry an empty `prizes` list plus a count, so read the
    // count rather than the list length (see TournamentStructure.paidPlaces).
    final paidPlaces = game.structure.paidPlacesForDisplay.clamp(0, 6);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xs),
          // 14-043 / 15-034: the pool total is a LIVE figure. Once the
          // tournament is finished, public and player results show the paid
          // positions only — no money. The podium and history screens already
          // gate on this; TV did not.
          if (game.status != LiveGameStatus.completed) ...[
            Text(
              Formatters.prize(game.structure.prizePool),
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                size: 42 * scale,
                weight: FontWeight.w300,
                color: AppColors.foreground,
              ),
            ),
            Text(
              game.prizePoolLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                size: 12 * scale,
                letterSpacing: 2,
                color: AppColors.mutedForeground,
              ),
            ),
          ] else
            Text(
              'FINAL POSITIONS',
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                size: 12 * scale,
                letterSpacing: 2,
                color: AppColors.mutedForeground,
              ),
            ),
          if (game.status == LiveGameStatus.completed) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < paidPlaces; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _ords[i],
                      style: AppTypography.mono(
                        size: 12 * scale,
                        weight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _podiumName(i + 1),
                      style: AppTypography.mono(
                        size: 13 * scale,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// finishOrder is "first-out first", so place P sits at index len - P.
  String _podiumName(int place) {
    final pos = game.finishOrder.length - place;
    if (pos < 0 || pos >= game.finishOrder.length) return '—';
    final id = game.finishOrder[pos];
    for (final p in game.players) {
      if (p.id == id) return p.name;
    }
    return '—';
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({super.key, required this.game, this.scale = 1.0});

  final LiveGame game;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final upcoming = game.structure.levels
        .where((l) => l.level > game.currentLevel)
        .take(4)
        .toList();

    if (upcoming.isEmpty) {
      return Center(
        child: Text(
          game.status == LiveGameStatus.completed
              ? 'TOURNAMENT COMPLETE'
              : 'END',
          style: AppTypography.mono(size: 14 * scale, color: AppColors.primary),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          for (final l in upcoming)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(
                    'L${l.level}',
                    style: AppTypography.mono(
                      size: 13 * scale,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SB ${Formatters.chips(l.sb)} · BB ${Formatters.chips(l.bb)}',
                      style: AppTypography.mono(
                        size: 13 * scale,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  if (l.ante != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'ANTE ${Formatters.chips(l.ante!)}',
                      style: AppTypography.mono(
                        size: 11 * scale,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementsPanel extends StatelessWidget {
  const _AnnouncementsPanel({super.key, required this.game, this.scale = 1.0});

  final LiveGame game;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final announcements = game.announcements.toList().reversed.take(8).toList();
    if (announcements.isEmpty) {
      return Center(
        child: Text(
          'No announcements',
          style: AppTypography.mono(
            size: 14 * scale,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }
    return ListView(
      children: [
        for (final a in announcements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              a.text,
              style: AppTypography.mono(
                size: 12 * scale,
                color: AppColors.foreground,
              ),
            ),
          ),
      ],
    );
  }
}

/// The TV's own display controls (§3 "Advanced TV/display customization",
/// §8's readability bar).
///
/// Gated, but the gate is inside the sheet rather than on the button: a host
/// who opens this and finds nothing has learned less than one who opens it and
/// sees what they would get.
class _TvSettingsSheet extends StatefulWidget {
  const _TvSettingsSheet({required this.initial, required this.onChanged});

  final TvDisplaySettings initial;
  final ValueChanged<TvDisplaySettings> onChanged;

  @override
  State<_TvSettingsSheet> createState() => _TvSettingsSheetState();
}

class _TvSettingsSheetState extends State<_TvSettingsSheet> {
  late TvDisplaySettings _d = widget.initial;

  void _set(TvDisplaySettings next) {
    setState(() => _d = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tier = context.watch<AppProvider>().premiumTier;

    return PremiumGate(
      tier: tier,
      feature: PremiumFeature.tvCustomisation,
      blurb: 'Set the text size for the room you are actually in, and choose '
          'what this screen cycles through.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Text size',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'For how far away the table is, not how big the screen is — that '
            'part is automatic.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _d.textScale,
                  min: TvDisplaySettings.minTextScale,
                  max: TvDisplaySettings.maxTextScale,
                  divisions: 13,
                  label: '${(_d.textScale * 100).round()}%',
                  onChanged: (v) => _set(_d.copyWith(textScale: v)),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${(_d.textScale * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: AppTypography.monoXs.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Cycle through',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PanelToggle(
            label: 'Leaderboard',
            value: _d.showLeaderboard,
            onChanged: (v) => _set(_d.copyWith(showLeaderboard: v)),
          ),
          _PanelToggle(
            label: 'Prize pool',
            value: _d.showPayouts,
            onChanged: (v) => _set(_d.copyWith(showPayouts: v)),
          ),
          _PanelToggle(
            label: 'Upcoming levels',
            value: _d.showUpcoming,
            onChanged: (v) => _set(_d.copyWith(showUpcoming: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Announcements always show — they are there because the host '
            'needed to tell the room something.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Hold each for',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final secs in TvDisplaySettings.rotatePresets)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: secs == _d.rotateSeconds
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  onPressed: () => _set(_d.copyWith(rotateSeconds: secs)),
                  child: Text('${secs}s'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Saved on this screen only. Another device keeps its own.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelToggle extends StatelessWidget {
  const _PanelToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodySm)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
