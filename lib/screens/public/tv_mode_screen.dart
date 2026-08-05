import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/backgrounds.dart';

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

  void _connect() {
    final result = context.read<AppProvider>().enterGameCode(_codeController.text.trim());
    if (result == CodeLookupResult.notFound) {
      setState(() => _codeError = 'Code not found — try again');
    } else {
      setState(() => _codeError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) return _CodeEntry(controller: _codeController, error: _codeError, onConnect: _connect);

    return TVBackground(
      child: _TVLayout(game: game, app: app),
    );
  }
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({required this.controller, required this.error, required this.onConnect});

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
                      Text(AppAssets.spade, style: AppTypography.body(size: 48)),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'POKER NIGHT',
                        style: AppTypography.crimsonShimmer(size: 36, weight: FontWeight.w700),
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
                        Text('TV Display', style: AppTypography.display(size: AppFontSizes.xxl)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter the TV code shown by the host',
                          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: controller,
                          maxLength: 8,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: AppTypography.monoXl.copyWith(letterSpacing: 3),
                          onChanged: (_) {},
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'TV CODE',
                            hintStyle: AppTypography.monoXl.copyWith(color: AppColors.onSurfaceHint, letterSpacing: 3),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: const BorderSide(color: AppColors.ring),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(error!, style: AppTypography.bodySm.copyWith(color: AppColors.destructive)),
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
                                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: InkWell(
                                  onTap: () => controller.text = 'TV-FP',
                                  child: Text(
                                    'TV-FP',
                                    style: AppTypography.monoSm.copyWith(color: AppColors.primary),
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
  const _TVLayout({required this.game, required this.app});

  final LiveGame game;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final level = game.currentLevelData;
    final next = game.nextLevelData;
    final activePlayers = game.activePlayers;
    final avgStack = Formatters.averageStack(game.totalChipsInPlay, activePlayers.length);
    final avgBB = level != null ? (avgStack / level.bb).round() : 0;

    final timerDanger = game.secondsRemaining <= 60;
    final timerWarning = game.secondsRemaining <= 300;

    final isFinalTable = game.status == LiveGameStatus.finaltable;
    final isCompleted = game.status == LiveGameStatus.completed;
    final isBreak = game.status == LiveGameStatus.rebuypause;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
          child: Column(
            children: [
              // Header
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  Text(AppAssets.spade, style: AppTypography.body(size: 28)),
                  const SizedBox(width: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.settings.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl),
                        ),
                        Text(
                          '${game.settings.date} · ${game.settings.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  if (game.status == LiveGameStatus.running)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiveDot(),
                        SizedBox(width: AppSpacing.xs),
                        Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: AppFontSizes.sm, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  if (isBreak)
                    const Text(
                      '⏸ BREAK',
                      style: TextStyle(color: AppColors.warning, fontSize: AppFontSizes.sm, fontWeight: FontWeight.w600),
                    ),
                  InkWell(
                    onTap: app.toggleVoice,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Text(
                        app.voiceEnabled ? '🔊 Voice on' : '🔇 Voice off',
                        style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                  ),
                  // Join QR — players scan to open the game join page (15-021).
                  _JoinQR(game: game),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Body
              Expanded(
                child: isCompleted && game.finishOrder.length >= 3
                    ? _Podium(game: game)
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _TimerBlock(
                              game: game,
                              level: level,
                              timerDanger: timerDanger,
                              timerWarning: timerWarning,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _StatsGrid(
                              game: game,
                              level: level,
                              next: next,
                              avgStack: avgStack,
                              avgBB: avgBB,
                            ),
                            if (isFinalTable) ...[
                              const SizedBox(height: AppSpacing.xl),
                              _FinalTableBoard(players: activePlayers),
                            ],
                            if (isBreak) ...[
                              const SizedBox(height: AppSpacing.xl),
                              const _BreakBanner(),
                            ],
                          ],
                        ),
                      ),
              ),

              // Footer
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text('CODE: ${game.publicCode}', style: AppTypography.monoXs.copyWith(color: AppColors.mutedForeground)),
                  const Spacer(),
                  Text('pokernight.app', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(width: AppSpacing.lg),
                  InkWell(
                    onTap: () => context.go(RoutePaths.landing),
                    child: Text('✕ Exit', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle));
  }
}

/// Scannable join QR for the TV display. Encodes the public game link so
/// players can open the join page directly instead of typing the code.
class _JoinQR extends StatelessWidget {
  const _JoinQR({required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Scan QR to join the game ${game.publicCode}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: QrImageView(
          data: 'https://pokernight.app/game/${game.publicCode}',
          version: QrVersions.auto,
          size: 64,
          gapless: false,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
    );
  }
}

class _TimerBlock extends StatelessWidget {
  const _TimerBlock({
    required this.game,
    required this.level,
    required this.timerDanger,
    required this.timerWarning,
  });

  final LiveGame game;
  final BlindLevel? level;
  final bool timerDanger;
  final bool timerWarning;

  @override
  Widget build(BuildContext context) {
    final color = timerDanger ? AppColors.destructive : (timerWarning ? AppColors.warning : AppColors.primary);
    final lvl = level;
    final pct = lvl == null
        ? 0.0
        : ((lvl.durationMins * 60 - game.secondsRemaining) / (lvl.durationMins * 60)).clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          'LEVEL ${game.currentLevel}',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground, letterSpacing: 2),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AppTimer(
            secondsRemaining: game.secondsRemaining,
            size: 96,
            danger: timerDanger,
            warning: timerWarning,
          ),
        ),
        if (level != null) ...[
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 576),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(width: double.infinity, color: AppColors.muted),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: pct,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.game,
    required this.level,
    required this.next,
    required this.avgStack,
    required this.avgBB,
  });

  final LiveGame game;
  final BlindLevel? level;
  final BlindLevel? next;
  final int avgStack;
  final int avgBB;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 768 ? 4 : 2;
        final lvl = level;
        final nxt = next;
        final ante = lvl?.ante;
        final tiles = [
          _Tile(
            label: 'Blinds',
            span: columns >= 4 ? 2 : 1,
            child: Column(
              children: [
                Text(
                  lvl == null ? '—' : '${Formatters.chips(lvl.sb)} / ${Formatters.chips(lvl.bb)}',
                  style: AppTypography.mono(size: 48, weight: FontWeight.w700),
                ),
                if (ante != null)
                  Text(
                    '+ ${Formatters.chips(ante)} ante',
                    style: AppTypography.bodySm.copyWith(color: AppColors.accent),
                  ),
                if (nxt != null)
                  Text(
                    'Next: ${Formatters.chips(nxt.sb)} / ${Formatters.chips(nxt.bb)}'
                    '${nxt.ante != null ? ' + ${Formatters.chips(nxt.ante!)} ante' : ''}',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),
          _Tile(
            label: 'Players',
            child: Text('${game.activePlayers.length}', style: AppTypography.mono(size: 56, weight: FontWeight.w700)),
          ),
          _Tile(
            label: 'Avg Stack',
            child: Column(
              children: [
                Text(Formatters.chips(avgStack), style: AppTypography.mono(size: 40, weight: FontWeight.w700)),
                if (avgBB > 0)
                  Text('$avgBB BB', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
              ],
            ),
          ),
        ];

        // Prize pool is a separate highlighted tile
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final tileWidth = (c.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
                final rows = <Widget>[];
                for (var i = 0; i < tiles.length; i += columns) {
                  final slice = tiles.sublist(i, (i + columns).clamp(0, tiles.length));
                  rows.add(Row(
                    children: [
                      for (var j = 0; j < slice.length; j++) ...[
                        if (j > 0) const SizedBox(width: AppSpacing.lg),
                        SizedBox(width: tileWidth, child: slice[j]),
                      ],
                    ],
                  ));
                  if (i + columns < tiles.length) rows.add(const SizedBox(height: AppSpacing.lg));
                }
                return Column(children: rows);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 768;
                return Row(
                  children: [
                    _PrizePoolTile(width: isWide ? c.maxWidth / 2 - 8 : c.maxWidth),
                    if (isWide) ...[
                      const SizedBox(width: AppSpacing.lg),
                      if (game.announcements.isNotEmpty)
                        _AnnouncementTile(width: c.maxWidth / 2 - 8, game: game),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child, this.span = 1});

  final String label;
  final Widget child;
  final int span;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _PrizePoolTile extends StatelessWidget {
  const _PrizePoolTile({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<AppProvider>().currentGame;
    final pool = game?.structure.prizePool ?? 0;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Column(
        children: [
          Text(
            (game?.prizePoolLabel ?? 'Prize Pool').toUpperCase(),
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Formatters.chips(pool),
            style: AppTypography.mono(size: 48, weight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.width, required this.game});

  final double width;
  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final latest = game.announcements.last;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('📢', style: TextStyle(fontSize: AppFontSizes.xxl)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Announcement', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: AppSpacing.xs),
                Text(latest.text, style: AppTypography.body(size: AppFontSizes.lg, weight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalTableBoard extends StatelessWidget {
  const _FinalTableBoard({required this.players});

  final List players;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppAssets.spade, style: AppTypography.body(size: AppFontSizes.xxl)),
              const SizedBox(width: AppSpacing.sm),
              Text('FINAL TABLE', style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < players.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primarySoftBorder),
                  ),
                  child: Column(
                    children: [
                      Text('Seat ${i + 1}', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                      Text(
                        '${(players[i] as dynamic).name}',
                        style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakBanner extends StatelessWidget {
  const _BreakBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warningSoftBorder),
      ),
      child: Column(
        children: [
          Text('⏸ BREAK', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700, color: AppColors.warning)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Rebuy period has ended. Add-ons available. Resume when ready.',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
    const medals = ['🥈', '🥇', '🥉'];
    const labels = ['2nd', '1st', '3rd'];
    const places = [2, 1, 3];
    final heights = [170.0, 240.0, 140.0];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tournament Complete!',
            style: AppTypography.display(size: 36, weight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: _PodiumStep(
                    medal: medals[i],
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
  const _PodiumStep({required this.medal, required this.label, required this.name, required this.height});

  final String medal;
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: AppFontSizes.display)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name ?? '—',
            textAlign: TextAlign.center,
            style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}
