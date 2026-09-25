import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../models/live_game.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/tournament_display_block.dart';
import '../../widgets/glass_styles.dart';

/// The public tools (§2).
///
/// Five calculators that need no account, each on its own URL. §2 also asks
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

/// The boxes worth offering a stranger. The chip denominations decide the
/// starting stack and the whole blind ladder, so a tool that assumes one box
/// gives a confidently wrong answer to anybody who owns a different one — and
/// "which chips do you have" is a question people can answer without thinking.
const kToolChipSets = <String, List<ChipColor>>{
  'Standard 300 (1/5/25/100/500)': kToolChipSet,
  'No ones (5/25/100/500/1000)': [
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 50),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 30),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 1000, quantity: 20),
  ],
  'Four colours (25/100/500/1000)': [
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 50),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 1000, quantity: 30),
  ],
};

/// Shared chrome: a title, the tool, and one quiet line about the app.
class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({
    required this.title,
    required this.blurb,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String blurb;
  final Widget child;

  /// One or two compact buttons placed on the title row (e.g. "Share").
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // A real Scaffold, like every other public screen. AppPage is a
    // ColoredBox and provides no Material, so InkWell and friends assert
    // "No Material widget found" without one.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppPage(
      // Public route: no ScreenShell, so no top bar owns the status-bar
      // inset. Without this the first row renders under the notch.
      topInset: true,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
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
                const SizedBox(height: AppSpacing.xxs),
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

/// Index of the five tools (§2).
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
      (
        title: 'Quick Blind Calculator',
        blurb: 'One level, right now. What should the blinds be for this stack?',
        path: RoutePaths.toolQuickBlind,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppPage(
      // Public route — see _ToolScaffold.
      topInset: true,
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const AppBadge(
            label: 'FREE · NO LOGIN',
            variant: AppBadgeVariant.green,
            border: true,
          ),
          const SizedBox(height: AppSpacing.sm),
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
                            const SizedBox(height: AppSpacing.xxs),
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

  /// 0 means "let the engine pick from the duration", which is what it does
  /// for every tournament in the app. Offering only fixed lengths would make
  /// the tool answer a narrower question than the product does.
  int _levelMins = 0;
  bool _antes = false;
  String _chipSetName = kToolChipSets.keys.first;

  /// Wall-clock start, so the schedule reads as a plan for an evening rather
  /// than a list of offsets. Presentation only — the engine has no idea what
  /// time it is and should not.
  TimeOfDay _startAt = const TimeOfDay(hour: 19, minute: 0);

  TournamentStructure? _result;

  void _generate() {
    setState(() {
      _result = TournamentEngine.generate(
        TournamentParams(
          players: _players,
          durationHours: _hours,
          buyIn: 20,
          chipSet: kToolChipSets[_chipSetName] ?? kToolChipSet,
          rebuys: true,
          rebuysCloseLevel: 6,
          reEntry: false,
          addOn: true,
          anteEnabled: _antes,
          anteAfterLevel: 7,
          anteStyle: AnteStyle.bigBlind,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
          levelDurationMins: _levelMins == 0 ? null : _levelMins,
        ),
      );
    });
  }

  /// [_startAt] advanced by [mins], wrapped over midnight.
  String _clockAt(int mins) {
    final total = (_startAt.hour * 60 + _startAt.minute + mins) % (24 * 60);
    final h = total ~/ 60;
    final m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _startAt);
    if (picked != null && mounted) setState(() => _startAt = picked);
  }

  /// The generated schedule as plain text, ready to paste into a group chat.
  String _scheduleText(TournamentStructure r) {
    final buf = StringBuffer()
      ..writeln('Blind Structure Generator')
      ..writeln(
        '${r.plannedLevels} levels · ${r.levelDuration}-min levels · '
        '${r.startingStack} starting stack',
      );
    var at = 0;
    for (final seg in ClockSequence.build(r)) {
      buf
        ..write(_clockAt(at))
        ..write('  ');
      at += seg.seconds ~/ 60;
      if (seg.isBreak) {
        buf.write('Break');
      } else {
        buf.write('L${seg.level!.level} ${seg.level!.sb} / ${seg.level!.bb}');
        if (seg.level!.ante != null) {
          buf.write('  ante ${seg.level!.ante}');
        }
      }
      buf.writeln('  ${seg.seconds ~/ 60}m');
    }
    buf.writeln('— generated with Poker Night');
    return buf.toString();
  }

  Future<void> _share(TournamentStructure r) async {
    await Clipboard.setData(ClipboardData(text: _scheduleText(r)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return _ToolScaffold(
      title: 'Blind Structure Generator',
      blurb: 'Pick the box of chips you actually own — the denominations decide '
          'the starting stack and the whole ladder.',
      actions: [
        if (r != null)
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            onPressed: () => _share(r),
            child: const Text('Share'),
          ),
      ],
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
          const SizedBox(height: AppSpacing.md),
          Text(
            'Quick settings',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Same _levelMins / _antes state as before, behind pill toggles
          // instead of a dropdown and a switch — the mockup's quick-settings
          // row.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final opt in const [
                (mins: 0, label: 'AUTO LEVELS'),
                (mins: 10, label: '10 MIN LEVELS'),
                (mins: 15, label: '15 MIN LEVELS'),
                (mins: 20, label: '20 MIN LEVELS'),
                (mins: 30, label: '30 MIN LEVELS'),
              ])
                _TogglePill(
                  label: opt.label,
                  selected: _levelMins == opt.mins,
                  onTap: () => setState(() => _levelMins = opt.mins),
                ),
              _TogglePill(
                label: 'ANTES FROM L7',
                selected: _antes,
                onTap: () => setState(() => _antes = !_antes),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppSelect<String>(
            label: 'Chips',
            value: _chipSetName,
            items: [
              for (final name in kToolChipSets.keys)
                DropdownMenuItem<String>(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _chipSetName = v ?? _chipSetName),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Start time',
            child: AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: _pickStart,
              child: Text(_clockAt(0)),
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

            // The headline figures first, as their own cards. A schedule is
            // the answer, but "how deep do we start and how long will it run"
            // is the question people actually arrived with.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatCard(
                  label: 'Starting stack',
                  value: '${r.startingStack}',
                ),
                _StatCard(label: 'Levels', value: '${r.plannedLevels}'),
                _StatCard(
                  label: 'Level length',
                  value: '${r.levelDuration}m',
                ),
                _StatCard(
                  label: 'Est. finish',
                  value: r.expectedFinishMins >= 60
                      ? '${r.expectedFinishMins ~/ 60}h '
                            '${(r.expectedFinishMins % 60).toString().padLeft(2, '0')}m'
                      : '${r.expectedFinishMins}m',
                ),
                _StatCard(
                  label: 'Finishes around',
                  value: _clockAt(r.expectedFinishMins),
                ),
              ],
            ),
            if (r.styleNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                r.styleNote,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Blind schedule',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          'Time',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          'Lvl',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Blinds / ante',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      Text(
                        'Min',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.md),
                  // Breaks are segments of the clock, not footnotes on the
                  // level before them, so the schedule prints them in place
                  // and the wall-clock column carries their length through.
                  Builder(
                    builder: (context) {
                      var at = 0;
                      final rows = <Widget>[];
                      for (final seg in ClockSequence.build(r)) {
                        final startedAt = at;
                        at += seg.seconds ~/ 60;
                        rows.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    _clockAt(startedAt),
                                    style: AppTypography.monoXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                    seg.isBreak ? '—' : 'L${seg.level!.level}',
                                    style: AppTypography.monoXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    seg.isBreak
                                        ? 'Break'
                                        : '${seg.level!.sb} / ${seg.level!.bb}'
                                            '${seg.level!.ante != null ? '  ante ${seg.level!.ante}' : ''}',
                                    style: AppTypography.monoXs.copyWith(
                                      fontWeight: seg.isBreak
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: seg.isBreak
                                          ? AppColors.mutedForeground
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${seg.seconds ~/ 60}m',
                                  style: AppTypography.monoXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: rows,
                      );
                    },
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
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: options.isEmpty
                ? null
                : () => _useStructure(options.first),
            child: const Text('Use this structure'),
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

  /// Hands the recommended split over as plain text a host can paste into the
  /// group chat. The tool is standalone (no account), so copy is the honest
  /// "use" — the app's own scoreboard reads the same numbers.
  Future<void> _useStructure(PayoutOption o) async {
    final buf = StringBuffer()
      ..writeln('Payout structure — ${o.paidPlaces} places paid')
      ..writeln(
        '$_players entries · $_buyIn buy-in · ${o.prizePool} prize pool',
      );
    for (var i = 0; i < o.prizes.length; i++) {
      buf.writeln(
        '${_ordinal(o.prizes[i].place)}  ${o.prizes[i].amount}  '
        '(${o.percentages[i]}%)',
      );
    }
    buf.writeln('— calculated with Poker Night');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payout structure copied to clipboard')),
    );
  }
}

/// ICM Calculator — what each stack is worth in money.
class ToolIcmScreen extends StatefulWidget {
  const ToolIcmScreen({super.key});

  @override
  State<ToolIcmScreen> createState() => _ToolIcmScreenState();
}

class _ToolIcmScreenState extends State<ToolIcmScreen> {
  List<int> _stacks = [5000, 3000, 2000];
  List<int> _payouts = [50, 30, 20];

  /// Inputs for the prize generator below the prize list. Typing three
  /// amounts by hand is fine for a final table you already have a sheet for;
  /// it is not fine when the argument at the table is "what *should* we be
  /// paying?", which is the other half of every chop discussion.
  int _pool = 100;
  int _places = 3;
  PayoutShape _shape = PayoutShape.standard;

  /// Replaces the prize list with the engine's own split of [_pool]. The
  /// amounts stay editable afterwards — a house that pays odd numbers should
  /// not have to choose between the generator and the truth.
  void _fillFromPool() {
    final prizes = TournamentEngine.recalculatePrizes(
      _pool,
      // Only used to cap the paid places against the field, and the field
      // here is whoever is left at the table.
      _stacks.length < _places ? _places : _stacks.length,
      0,
      forcePaidPlaces: _places,
      shape: _shape,
    ).prizes;
    if (prizes.isEmpty) return;
    setState(() => _payouts = [for (final p in prizes) p.amount]);
  }

  @override
  Widget build(BuildContext context) {
    final equity = Icm.equity(stacks: _stacks, payouts: _payouts);
    final pool = _payouts.fold<int>(0, (a, p) => a + p);
    final chips = _stacks.fold<int>(0, (a, s) => a + s);
    // What each player actually gets handed if the table chops on ICM: whole
    // units that still add up to the pool, rather than three numbers with
    // decimals that nobody can pay out in chips or notes.
    final settlement = Icm.roundPreservingTotal(equity, pool);

    return _ToolScaffold(
      title: 'ICM Calculator',
      blurb: 'Chips are not money. A big stack is worth less than its chip '
          'share, a short stack more — this is the difference.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chip stacks',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _stacks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StepperRow(
                label: Text('Player ${i + 1}', style: AppTypography.bodyXs),
                stepper: CountStepper(
                  value: _stacks[i],
                  min: 0,
                  max: 1000000,
                  step: 500,
                  semanticLabel: 'Player ${i + 1} stack',
                  onChanged: (v) => setState(() => _stacks[i] = v),
                ),
                trailing: Text(
                  equity[i].toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: AppTypography.monoXs.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
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
              child: _StepperRow(
                label: Text(
                  '${i + 1}${i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th'}',
                  style: AppTypography.bodyXs,
                ),
                stepper: CountStepper(
                  value: _payouts[i],
                  min: 0,
                  max: 100000,
                  step: 10,
                  semanticLabel: 'Prize ${i + 1}',
                  onChanged: (v) => setState(() => _payouts[i] = v),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _StepperRow(
            label: Text('Pool', style: AppTypography.bodyXs),
            stepper: CountStepper(
              value: _pool,
              min: 0,
              max: 1000000,
              step: 50,
              semanticLabel: 'Prize pool',
              onChanged: (v) => setState(() => _pool = v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppSelect<int>(
                  value: _places,
                  items: [
                    for (var i = 1; i <= 5; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text('$i paid'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _places = v ?? _places),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSelect<PayoutShape>(
                  value: _shape,
                  items: [
                    for (final shape in PayoutShape.values)
                      DropdownMenuItem<PayoutShape>(
                        value: shape,
                        child: Text(shape.label),
                      ),
                  ],
                  onChanged: (v) => setState(() => _shape = v ?? _shape),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            onPressed: _fillFromPool,
            child: const Text('Fill prizes from pool'),
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
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        '',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    for (final h in const ['Chips', 'ICM', 'Diff'])
                      Expanded(
                        child: Text(
                          h,
                          textAlign: TextAlign.right,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
                for (var i = 0; i < _stacks.length; i++)
                  Builder(
                    builder: (context) {
                      final share = chips == 0 ? null : pool * _stacks[i] / chips;
                      // The whole point of the tool, in one number: what the
                      // chip count over- or under-states your stack by. A big
                      // stack reads negative, a short stack positive.
                      final diff = share == null ? null : equity[i] - share;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                'P${i + 1}',
                                style: AppTypography.bodyXs,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                share == null ? '—' : share.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                equity[i].toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                diff == null
                                    ? '—'
                                    : '${diff >= 0 ? '+' : '−'}'
                                        '${diff.abs().toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: diff == null || diff.abs() < 0.005
                                      ? AppColors.mutedForeground
                                      : diff > 0
                                          ? AppColors.successText
                                          : AppColors.destructiveText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const Divider(height: AppSpacing.lg),
                Text(
                  'Chop payout',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ICM equity in whole units, adjusted so the payouts add up '
                  'to the $pool pool exactly.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
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
                          '${settlement[i]}',
                          style: AppTypography.monoSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
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
                      color: AppColors.warningText,
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

/// One figure from the clock, labelled. Small enough to sit in a row of them
/// under the countdown without competing with it.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Glass.solidTint(AppColors.secondary),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.monoSm.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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

/// A small selectable pill for a quick binary/enum setting — the "15 MIN
/// LEVELS" / "ANTES FROM L7" style controls on the mockup. Purely a visual
/// alternative to a dropdown or a switch; the caller still owns the state and
/// decides what selected means.
class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : Glass.solidTint(AppColors.secondary),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: selected
                  ? AppColors.primaryText
                  : AppColors.mutedForeground,
            ),
          ),
        ),
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

/// A label, a [CountStepper] and an optional trailing value, laid out in one
/// row when there is room and stacked when there is not.
///
/// [CountStepper] has a hard minimum width — its two 44x44 buttons are a
/// deliberate touch-target floor, not something to shrink — so a fixed-width
/// label and trailing column either side of it (the ICM calculator's
/// stack/prize rows) is exactly the layout that overflows on a 320px phone.
/// Below [_narrowThreshold] this drops the label/trailing pair onto their own
/// line above a full-width stepper instead of trying to squeeze all three
/// into one row that cannot get any narrower.
class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.label, required this.stepper, this.trailing});

  final Widget label;
  final Widget stepper;
  final Widget? trailing;

  static const double _narrowThreshold = 360;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _narrowThreshold) {
          return Row(
            children: [
              SizedBox(width: 70, child: label),
              Expanded(child: stepper),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 80, child: trailing!),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [label, ?trailing],
            ),
            const SizedBox(height: AppSpacing.xs),
            stepper,
          ],
        );
      },
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

  /// Kept so the clock can show what the engine actually decided — starting
  /// stack and the rebuy window are part of reading a structure, not extras.
  TournamentStructure? _structure;

  int _players = 9;
  int _hours = 4;

  int _index = 0;
  bool _running = false;

  /// Seconds left in the current segment.
  int _left = 0;

  bool get _finished =>
      _segments.isNotEmpty && _index == _segments.length - 1 && _left == 0;

  /// Seconds still to play across every remaining segment, including this one.
  int get _remainingTotal {
    if (_segments.isEmpty) return 0;
    var total = _left;
    for (var i = _index + 1; i < _segments.length; i++) {
      total += _segments[i].seconds;
    }
    return total;
  }

  /// Seconds until the next scheduled break, or null when none remain.
  int? get _untilBreak {
    if (_segments.isEmpty) return null;
    if (_segments[_index].isBreak) return 0;
    var total = _left;
    for (var i = _index + 1; i < _segments.length; i++) {
      if (_segments[i].isBreak) return total;
      total += _segments[i].seconds;
    }
    return null;
  }

  /// Levels remaining — this one included — before the next scheduled break,
  /// or null when none remain. Companion to [_untilBreak]: that one answers
  /// "how long", this answers "how many levels first".
  int? get _levelsUntilBreak {
    if (_segments.isEmpty) return null;
    if (_segments[_index].isBreak) return 0;
    var count = 1;
    for (var i = _index + 1; i < _segments.length; i++) {
      if (_segments[i].isBreak) return count;
      count++;
    }
    return null;
  }

  /// A one-line preview of the segment right after this one, or null at the
  /// end of the structure.
  String? get _nextLabel {
    if (_segments.isEmpty) return null;
    final next = _index + 1;
    if (next >= _segments.length) return null;
    final seg = _segments[next];
    if (seg.isBreak) return 'Next: Break';
    return 'Next: L${seg.level!.level}  ${seg.level!.sb} / ${seg.level!.bb}';
  }

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
      _structure = structure;
      _segments = segments;
      _index = 0;
      _running = false;
      _left = segments.isEmpty ? 0 : segments.first.seconds;
    });
  }

  void _toggle() {
    // Pressing Start on a finished structure used to arm a ticker that could
    // never count down — the button looked live and nothing moved. Rewind to
    // the top instead, which is what "start" means on a clock that has run
    // its course.
    if (!_running && _finished) {
      setState(() {
        _index = 0;
        _left = _segments.first.seconds;
      });
    }
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
      _structure = null;
      _running = false;
      _index = 0;
      _left = 0;
    });
  }

  /// Longer spans read better as "1h 45m" than as 105 minutes.
  String _coarse(int seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  /// Wraps the tool's clock state in a [LiveGame] so the page can render
  /// [TournamentDisplayBlock] — the SAME widget the TV display and the host
  /// dashboard use.
  ///
  /// The point of the public clock is to be the app's clock, not a lookalike
  /// of it. Rebuilding the display here would mean two clocks to keep in step
  /// and a tool that quietly drifts from the product it advertises. This way
  /// any change to the real display shows up here for free.
  ///
  /// `timerRunning` is deliberately false: [LiveGame.currentSecondsRemaining]
  /// returns the stored `secondsRemaining` verbatim in that case, which lets
  /// this screen's own ticker drive the count instead of a wall-clock
  /// `levelEndTime` that a preview has no reason to invent.
  ///
  /// [index]/[left] let the fullscreen copy of the clock render a snapshot at
  /// a caller-supplied position; when omitted the live tool state is used.
  LiveGame _previewGame({int? index, int? left}) {
    final structure = _structure!;
    final i = index ?? _index;
    final l = left ?? _left;
    final level = ClockSequence.levelAt(_segments, i);
    final onBreak = _segments[i].isBreak;

    return LiveGame(
      id: 'tool-clock',
      groupId: '',
      settings: GameSettings(
        name: 'Tournament Clock',
        date: '',
        time: '',
        location: '',
        players: _players,
        durationHours: _hours.toDouble(),
        buyIn: 20,
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 7,
        organizerPct: 0,
        chipSet: kToolChipSet,
        chipSetName: 'Standard 300',
      ),
      structure: structure,
      status: onBreak ? LiveGameStatus.onBreak : LiveGameStatus.running,
      publicCode: '',
      tvCode: '',
      currentLevel: level?.level ?? 1,
      timerRunning: false,
      secondsRemaining: l,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: structure.startingStack * _players,
      pendingGuests: const [],
      finishOrder: const [],
    );
  }

  void _enterFullScreen() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => _FullscreenClock(
          segments: _segments,
          initialIndex: _index,
          initialLeft: _left,
          gameFor: (index, left) => _previewGame(index: index, left: left),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final started = _segments.isNotEmpty;

    return _ToolScaffold(
      title: 'Tournament Clock',
      blurb: 'A blind schedule and a countdown. Nothing else on the screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!started) ...[
_Field(
            label: 'Entries',
            child: CountStepper(
              value: _players,
              min: 2,
              max: 100,
              semanticLabel: 'Entries',
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
            // The real display block — the same widget driving the TV screen
            // and the host dashboard, not a reproduction of it.
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: _enterFullScreen,
                child: const Text('Full screen'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: TournamentDisplayBlock(
                game: _previewGame(),
                showStatusChip: false,
                showPayoutAmounts: false,
              ),
            ),
            if (_finished) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  'Structure complete',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              if (_nextLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    _nextLabel!,
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
              if (_levelsUntilBreak != null && _levelsUntilBreak! > 0) ...[
                const SizedBox(height: AppSpacing.xxs),
                Center(
                  child: Text(
                    _levelsUntilBreak == 1
                        ? 'Break after this level'
                        : 'Break in ${_levelsUntilBreak! - 1} more '
                            'level${_levelsUntilBreak! - 1 == 1 ? '' : 's'}',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.md),

            // The figures a host actually watches for alongside the count:
            // how much night is left, and when the room next gets a break.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatCard(
                  label: 'Time left',
                  value: _coarse(_remainingTotal),
                ),
                if (_untilBreak != null)
                  _StatCard(
                    label: 'Next break',
                    value: _untilBreak == 0 ? 'Now' : _coarse(_untilBreak!),
                  ),
                if (_structure != null)
                  _StatCard(
                    label: 'Starting stack',
                    value: '${_structure!.startingStack}',
                  ),
                _StatCard(
                  label: 'Level',
                  value: '${_index + 1} of ${_segments.length}',
                ),
              ],
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

/// Fullscreen copy of the clock tool. Runs its own one-second ticker: the
/// preview [LiveGame] is built from a snapshot, and [LiveTimerBuilder] only
/// counts down while `timerRunning` is true, so the display would otherwise
/// freeze here without a parent rebuild each tick.
class _FullscreenClock extends StatefulWidget {
  const _FullscreenClock({
    required this.segments,
    required this.initialIndex,
    required this.initialLeft,
    required this.gameFor,
  });

  final List<ClockSegment> segments;
  final int initialIndex;
  final int initialLeft;

  /// Builds a [LiveGame] snapshot at an arbitrary (index, seconds-left)
  /// position, so the fullscreen clock and the button that opened it stay in
  /// step when the tool was running.
  final LiveGame Function(int index, int left) gameFor;

  @override
  State<_FullscreenClock> createState() => _FullscreenClockState();
}

class _FullscreenClockState extends State<_FullscreenClock> {
  Timer? _ticker;
  late int _index;
  late int _left;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _left = widget.initialLeft;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_tick);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_left > 0) {
      _left--;
      if (_left == 0 && _index + 1 < widget.segments.length) {
        _index++;
        _left = widget.segments[_index].seconds;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: TournamentDisplayBlock(
                  game: widget.gameFor(_index, _left),
                  showStatusChip: false,
                  showPayoutAmounts: false,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Exit full screen'),
              ),
            ),
          ],
        ),
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

/// Quick Blind Calculator — one level, right now.
class ToolQuickBlindScreen extends StatefulWidget {
  const ToolQuickBlindScreen({super.key});

  @override
  State<ToolQuickBlindScreen> createState() => _ToolQuickBlindScreenState();
}

class _ToolQuickBlindScreenState extends State<ToolQuickBlindScreen> {
  int _stack = 10000;
  String _chipSetName = kToolChipSets.keys.first;

  @override
  Widget build(BuildContext context) {
    final chips = kToolChipSets[_chipSetName] ?? kToolChipSet;
    final targetBB = _stack / TournamentEngine.targetHeadsUpAverageBB;
    final bb = TournamentEngine.snapToPracticalBlind(targetBB, chips);
    
    int minChip = 1;
    final values = chips.map((c) => c.value).where((v) => v > 0).toList()..sort();
    if (values.isNotEmpty) minChip = values.first;

    int sb = bb ~/ 2;
    if (sb < minChip) {
      sb = minChip;
    } else {
      sb = (sb ~/ minChip) * minChip;
    }
    if (sb == 0) sb = minChip;

    return _ToolScaffold(
      title: 'Quick Blind Calculator',
      blurb: 'One level, right now. What should the blinds be for this stack?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppBadge(
            label: '30-SECOND SETUP',
            variant: AppBadgeVariant.green,
            border: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Starting stack',
            child: CountStepper(
              value: _stack,
              min: 500,
              max: 1000000,
              step: 500,
              semanticLabel: 'Starting stack',
              onChanged: (v) => setState(() => _stack = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSelect<String>(
            label: 'Chips',
            value: _chipSetName,
            items: [
              for (final name in kToolChipSets.keys)
                DropdownMenuItem<String>(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _chipSetName = v ?? _chipSetName),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Blinds',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$sb / $bb',
                  style: AppTypography.display(
                    size: AppFontSizes.xxxl,
                    weight: FontWeight.w700,
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

