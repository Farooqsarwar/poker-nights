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
import '../../widgets/app_button.dart';
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
      setState(
        () => _codeError = 'Too many attempts — wait a minute',
      );
    } else {
      setState(() => _codeError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.tvGame;

    if (game == null) {
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style,
                        size: 60,
                        color: AppColors.primary,
                      ),
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
                          'Enter the TV code shown by the host',
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
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: const BorderSide(
                                color: AppColors.ring,
                              ),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            error!,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.destructive,
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
                                      color: AppColors.primary,
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

class _TVLayout extends StatelessWidget {
  const _TVLayout({required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final isCompleted = game.status == LiveGameStatus.completed;

    if (isCompleted && game.finishOrder.length >= 3) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _Podium(game: game),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: TournamentDisplayBlock(
                        game: game,
                        showPayoutAmounts: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(width: 340, child: _RotatingPanel(game: game)),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            child: TournamentDisplayBlock(game: game, showPayoutAmounts: false),
          );
        },
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
  const _RotatingPanel({required this.game});

  final LiveGame game;

  @override
  State<_RotatingPanel> createState() => _RotatingPanelState();
}

class _RotatingPanelState extends State<_RotatingPanel> {
  static const _titles = ['LEADERBOARD', 'PRIZE POOL', 'UPCOMING'];

  int _panel = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      setState(() => _panel = (_panel + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _titles[_panel],
            style: AppTypography.mono(
              size: 15,
              weight: FontWeight.w700,
              letterSpacing: 2.5,
              color: Color(0xFFFF0015),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: switch (_panel) {
                0 => _LeaderboardPanel(
                  key: const ValueKey(0),
                  game: widget.game,
                ),
                1 => _PayoutsPanel(key: const ValueKey(1), game: widget.game),
                _ => _UpcomingPanel(key: const ValueKey(2), game: widget.game),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({super.key, required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final players = [...game.players]
      ..sort((a, b) {
        final t = a.table.compareTo(b.table);
        return t != 0 ? t : a.seat.compareTo(b.seat);
      });

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
                      size: 12,
                      color: p.active
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'T${p.table} · S${p.seat}',
                  style: AppTypography.mono(
                    size: 11,
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
  const _PayoutsPanel({super.key, required this.game});

  final LiveGame game;

  static const _ords = ['1ST', '2ND', '3RD', '4TH', '5TH', '6TH'];

  @override
  Widget build(BuildContext context) {
    final paidPlaces = game.structure.prizes.take(6).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            Formatters.chips(game.structure.prizePool),
            textAlign: TextAlign.center,
            style: AppTypography.mono(
              size: 42,
              weight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          Text(
            game.prizePoolLabel.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.mono(
              size: 12,
              letterSpacing: 2,
              color: AppColors.mutedForeground,
            ),
          ),
          if (game.status == LiveGameStatus.completed) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF222222)),
            const SizedBox(height: 8),
            for (var i = 0; i < paidPlaces; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _ords[i],
                      style: AppTypography.mono(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Color(0xFFFF0015),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _podiumName(i + 1),
                      style: AppTypography.mono(size: 13, color: Colors.white),
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
  const _UpcomingPanel({super.key, required this.game});

  final LiveGame game;

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
          style: AppTypography.mono(size: 14, color: Color(0xFFFF0015)),
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
                      size: 13,
                      weight: FontWeight.w700,
                      color: Color(0xFFFF0015),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SB ${Formatters.chips(l.sb)} · BB ${Formatters.chips(l.bb)}',
                      style: AppTypography.mono(size: 13, color: Colors.white),
                    ),
                  ),
                  if (l.ante != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'ANTE ${Formatters.chips(l.ante!)}',
                      style: AppTypography.mono(
                        size: 11,
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
