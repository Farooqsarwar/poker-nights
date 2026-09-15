import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../models/tournament.dart';
import '../../utils/clock_sequence.dart';
import '../../utils/icm.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/glass_styles.dart';

/// The public tools (§2).
///
/// Four calculators that need no account, each on its own URL. §2 also asks
/// for a "soft prompt into the full app" — soft being the operative word:
/// somebody who came to settle a chop argument should get their answer first
/// and an invitation second, or they will never come back.
///
/// They deliberately reuse the tournament engine rather than reimplementing
/// it. A blind structure produced here should be the one the app would
/// produce, or the tool is advertising a different product.

/// A common home box, used by the tools that need chips to reason about.
///
/// The full app asks what you actually own. A public tool that demanded a
/// chip inventory before showing anything would lose most people at the first
/// screen, so it assumes the box most people have and says so.
const kToolChipSet = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
  ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
  ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
];

/// Shared chrome: a title, the tool, and one quiet line about the app.
class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({
    required this.title,
    required this.blurb,
    required this.child,
  });

  final String title;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A real Scaffold, like every other public screen. AppPage is a
    // ColoredBox and provides no Material, so InkWell and friends assert
    // "No Material widget found" without one.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => context.go(RoutePaths.tools),
                child: const Text('← All tools'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            blurb,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          child,
          const SizedBox(height: AppSpacing.xxl),
          // The soft prompt. One line, after the answer.
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Glass.solidTint(AppColors.secondary),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Running a whole poker night?',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Poker Night handles invites, check-in, the clock, rebuys '
                  'and payouts. Free for one table.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  size: AppButtonSize.sm,
                  onPressed: () => context.go(RoutePaths.landing),
                  child: const Text('Take a look'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
      ),
    );
  }
}

/// Index of the four tools (§2).
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const tools = <({String title, String blurb, String path})>[
      (
        title: 'Blind Structure Generator',
        blurb: 'A full blind schedule built around your chips and how long '
            'you want to play.',
        path: RoutePaths.toolBlinds,
      ),
      (
        title: 'Tournament Clock',
        blurb: 'A simple, readable clock for a structure you already have.',
        path: RoutePaths.toolClock,
      ),
      (
        title: 'ICM Calculator',
        blurb: 'What each stack is actually worth in money. Settle the chop.',
        path: RoutePaths.toolIcm,
      ),
      (
        title: 'Payout Calculator',
        blurb: 'Clean, countable prize splits from a buy-in and a field size.',
        path: RoutePaths.toolPayouts,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Poker tools',
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Free, no account needed.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final t in tools)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => context.go(t.path),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.title,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.blurb,
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
      ),
    );
  }
}

/// Blind Structure Generator — the app's own engine, without an account.
class ToolBlindsScreen extends StatefulWidget {
  const ToolBlindsScreen({super.key});

  @override
  State<ToolBlindsScreen> createState() => _ToolBlindsScreenState();
}

class _ToolBlindsScreenState extends State<ToolBlindsScreen> {
  int _players = 9;
  double _hours = 4;
  TournamentStructure? _result;

  void _generate() {
    setState(() {
      _result = TournamentEngine.generate(
        TournamentParams(
          players: _players,
          durationHours: _hours,
          buyIn: 20,
          chipSet: kToolChipSet,
          rebuys: true,
          rebuysCloseLevel: 6,
          reEntry: false,
          addOn: true,
          anteEnabled: false,
          anteAfterLevel: 7,
          anteStyle: AnteStyle.bigBlind,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return _ToolScaffold(
      title: 'Blind Structure Generator',
      blurb: 'Built with a standard 300-chip set. The app uses the chips you '
          'actually own.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: 'Players',
            child: CountStepper(
              value: _players,
              min: 2,
              max: 100,
              semanticLabel: 'Players',
              onChanged: (v) => setState(() => _players = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Hours',
            child: CountStepper(
              value: _hours.round(),
              min: 3,
              max: 6,
              semanticLabel: 'Hours',
              onChanged: (v) => setState(() => _hours = v.toDouble()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: _generate,
            child: const Text('Generate structure'),
          ),
          if (r != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Starting stack ${r.startingStack}',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (r.styleNote.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      r.styleNote,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  for (final l in r.levels.take(r.plannedLevels))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              'L${l.level}',
                              style: AppTypography.monoXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${l.sb} / ${l.bb}'
                              '${l.ante != null ? '  ante ${l.ante}' : ''}',
                              style: AppTypography.monoXs,
                            ),
                          ),
                          Text(
                            '${l.durationMins}m',
                            style: AppTypography.monoXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
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
}

/// Payout Calculator — the engine's own options, without an account.
class ToolPayoutsScreen extends StatefulWidget {
  const ToolPayoutsScreen({super.key});

  @override
  State<ToolPayoutsScreen> createState() => _ToolPayoutsScreenState();
}

class _ToolPayoutsScreenState extends State<ToolPayoutsScreen> {
  int _players = 9;
  int _buyIn = 20;

  @override
  Widget build(BuildContext context) {
    final options = TournamentEngine.payoutOptions(_players * _buyIn, _players, 0);
    return _ToolScaffold(
      title: 'Payout Calculator',
      blurb: 'Clean amounts that divide properly at a real table.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: 'Players',
            child: CountStepper(
              value: _players,
              min: 2,
              max: 100,
              semanticLabel: 'Players',
              onChanged: (v) => setState(() => _players = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Buy-in',
            child: CountStepper(
              value: _buyIn,
              min: 1,
              max: 500,
              step: 5,
              semanticLabel: 'Buy-in',
              onChanged: (v) => setState(() => _buyIn = v),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Prize pool ${_players * _buyIn}',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${o.paidPlaces} places — ${o.rationale}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < o.prizes.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ordinal(o.prizes[i].place),
                              style: AppTypography.bodyXs,
                            ),
                          ),
                          Text(
                            '${o.percentages[i]}%',
                            style: AppTypography.monoXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            '${o.prizes[i].amount}',
                            style: AppTypography.monoXs.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _ordinal(int n) => switch (n) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '${n}th',
      };
}

/// ICM Calculator — what each stack is worth in money.
class ToolIcmScreen extends StatefulWidget {
  const ToolIcmScreen({super.key});

  @override
  State<ToolIcmScreen> createState() => _ToolIcmScreenState();
}

class _ToolIcmScreenState extends State<ToolIcmScreen> {
  List<int> _stacks = [5000, 3000, 2000];
  final List<int> _payouts = [50, 30, 20];

  @override
  Widget build(BuildContext context) {
    final equity = Icm.equity(stacks: _stacks, payouts: _payouts);
    final pool = _payouts.fold<int>(0, (a, p) => a + p);
    final chips = _stacks.fold<int>(0, (a, s) => a + s);

    return _ToolScaffold(
      title: 'ICM Calculator',
      blurb: 'Chips are not money. A big stack is worth less than its chip '
          'share, a short stack more — this is the difference.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Stacks',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _stacks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Player ${i + 1}',
                      style: AppTypography.bodyXs,
                    ),
                  ),
                  Expanded(
                    child: CountStepper(
                      value: _stacks[i],
                      min: 0,
                      max: 1000000,
                      step: 500,
                      semanticLabel: 'Player ${i + 1} stack',
                      onChanged: (v) => setState(() => _stacks[i] = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 80,
                    child: Text(
                      equity[i].toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: AppTypography.monoXs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: _stacks.length >= Icm.maxExactPlayers
                      ? null
                      : () => setState(() => _stacks = [..._stacks, 1000]),
                  child: const Text('Add player'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: _stacks.length <= 2
                      ? null
                      : () => setState(
                            () => _stacks = _stacks.sublist(
                              0,
                              _stacks.length - 1,
                            ),
                          ),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Prizes',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _payouts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${i + 1}${i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th'}',
                      style: AppTypography.bodyXs,
                    ),
                  ),
                  Expanded(
                    child: CountStepper(
                      value: _payouts[i],
                      min: 0,
                      max: 100000,
                      step: 10,
                      semanticLabel: 'Prize ${i + 1}',
                      onChanged: (v) => setState(() => _payouts[i] = v),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          // The comparison IS the tool. Showing equity without the chip share
          // beside it leaves the reader with a number and no insight.
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Equity vs chip share',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _stacks.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Player ${i + 1}',
                            style: AppTypography.bodyXs,
                          ),
                        ),
                        Text(
                          chips == 0
                              ? '—'
                              : (pool * _stacks[i] / chips).toStringAsFixed(2),
                          style: AppTypography.monoXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          equity[i].toStringAsFixed(2),
                          style: AppTypography.monoXs.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!Icm.isExact(_stacks)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Above ${Icm.maxExactPlayers} players this is a '
                    'proportional estimate, not the exact model.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.warning,
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodySm)),
        child,
      ],
    );
  }
}

/// Tournament Clock — a readable clock for a structure, without an account.
///
/// The public tool deliberately does less than the app's live clock: no
/// players, no rebuys, no sync between devices. It is the thing you put on a
/// laptop at the end of the table when you are running a game you organised
/// on paper. Everything that needs a game behind it lives in the app.
///
/// The ordering — which level, which break, when it ends — belongs to
/// [ClockSequence] and is tested there. This screen only counts down.
class ToolClockScreen extends StatefulWidget {
  const ToolClockScreen({super.key});

  @override
  State<ToolClockScreen> createState() => _ToolClockScreenState();
}

class _ToolClockScreenState extends State<ToolClockScreen> {
  Timer? _ticker;
  List<ClockSegment> _segments = const [];

  int _players = 9;
  int _hours = 4;

  int _index = 0;
  bool _running = false;

  /// Seconds left in the current segment.
  int _left = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _build() {
    final structure = TournamentEngine.generate(
      TournamentParams(
        players: _players,
        durationHours: _hours.toDouble(),
        buyIn: 20,
        chipSet: kToolChipSet,
        rebuys: true,
        rebuysCloseLevel: 6,
        reEntry: false,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 7,
        anteStyle: AnteStyle.bigBlind,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ),
    );
    final segments = ClockSequence.build(structure);
    setState(() {
      _segments = segments;
      _index = 0;
      _running = false;
      _left = segments.isEmpty ? 0 : segments.first.seconds;
    });
  }

  void _toggle() {
    setState(() => _running = !_running);
    _ticker?.cancel();
    if (!_running) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_left > 0) {
          _left--;
          // Roll over on the tick that reaches zero, so the clock never sits
          // on a finished level waiting to be noticed.
          if (_left == 0) _advance();
        }
      });
    });
  }

  void _advance() {
    if (_index + 1 < _segments.length) {
      _index++;
      _left = _segments[_index].seconds;
      return;
    }
    // The end of the structure. Stop rather than loop.
    _left = 0;
    _running = false;
    _ticker?.cancel();
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _segments = const [];
      _running = false;
      _index = 0;
      _left = 0;
    });
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final rest = seconds % 60;
    return '$m:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final started = _segments.isNotEmpty;
    final segment = started ? _segments[_index] : null;
    final onBreak = segment?.isBreak ?? false;
    final current = ClockSequence.levelAt(_segments, _index);
    final next = ClockSequence.nextLevelAfter(_segments, _index);
    final accent = onBreak ? AppColors.warning : AppColors.primary;

    return _ToolScaffold(
      title: 'Tournament Clock',
      blurb: 'A blind schedule and a countdown. Nothing else on the screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!started) ...[
            _Field(
              label: 'Players',
              child: CountStepper(
                value: _players,
                min: 2,
                max: 100,
                semanticLabel: 'Players',
                onChanged: (v) => setState(() => _players = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label: 'Hours',
              child: CountStepper(
                value: _hours,
                min: 3,
                max: 6,
                semanticLabel: 'Hours',
                onChanged: (v) => setState(() => _hours = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              fullWidth: true,
              onPressed: _build,
              child: const Text('Start a clock'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Glass.solidTint(accent),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: accent),
              ),
              child: Column(
                children: [
                  Text(
                    segment!.label,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Text(
                    _mmss(_left),
                    style: AppTypography.display(
                      size: 72,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (!onBreak && current != null)
                    Text(
                      '${current.sb} / ${current.bb}'
                      '${current.ante != null ? '   ante ${current.ante}' : ''}',
                      style: AppTypography.display(
                        size: AppFontSizes.xl,
                        weight: FontWeight.w600,
                      ),
                    ),
                  if (next != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Next  ${next.sb} / ${next.bb}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: _toggle,
                    child: Text(_running ? 'Pause' : 'Start'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(_advance),
                    child: const Text('Next'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _segments.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _SegmentRow(
                        segment: _segments[i],
                        isCurrent: i == _index,
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
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment, required this.isCurrent});

  final ClockSegment segment;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final level = segment.level;
    final style = AppTypography.monoXs.copyWith(
      color: isCurrent ? AppColors.primary : null,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
    );
    final muted = AppTypography.monoXs.copyWith(
      color: isCurrent ? AppColors.primary : AppColors.mutedForeground,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
    );

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(level == null ? '—' : 'L${level.level}', style: muted),
        ),
        Expanded(
          child: Text(
            level == null ? 'Break' : '${level.sb} / ${level.bb}',
            style: style,
          ),
        ),
        Text('${segment.seconds ~/ 60}m', style: muted),
      ],
    );
  }
}
