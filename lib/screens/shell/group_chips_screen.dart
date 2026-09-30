import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../models/group.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';
import '../../widgets/why_disclosure.dart';

/// Spec B10 — the chip set this group starts from. Host only.
///
/// The group stores a POINTER, never a copy (§E3: `defaultChipSetId → one of
/// the host's chipSets`). The physical chips are the host's (§F4), so editing a
/// set in F5 has to reach every group pointing at it — storing the chips here
/// would freeze the group on whatever the set looked like today.
///
/// The pointer is written through `AppProvider.setGroupDefaultChipSet()`, which
/// updates the group document — there is no local-only copy, so a choice made
/// here reaches the tournament wizard and every other member's device.
/// Everything downstream of the pointer — the option list, the totals, the
/// starting-stack preview — is read from `AppProvider.savedChipSets` on every
/// build, which is what makes the "editing the set updates every group that
/// points at it" behaviour real rather than asserted.
class GroupChipsScreen extends StatefulWidget {
  const GroupChipsScreen({super.key});

  @override
  GroupChipsScreenState createState() => GroupChipsScreenState();
}

/// Public so a test can read back the pointer the screen chose without
/// reaching into private state.
class GroupChipsScreenState extends State<GroupChipsScreen> {
  /// Id of the always-available box, distinct from any user-saved set so a
  /// saved set can never collide with it.
  static const String _standardBoxId = 'preset-standard-500';

  /// §F1 step 2's own worked example is "200 (100 big blinds)", so the opening
  /// depth this screen previews at is 100 BB.
  static const double _targetDepthBB = 100;

  /// What the bank check demands per seat: the starting stack, a rebuy for
  /// half the field, and an add-on for everyone at the 125% §F1 step 3
  /// default.
  static const double _bankedStacksPerSeat = 1 + 0.5 + 1.25;

  late Group _group;

  @override
  void initState() {
    super.initState();
    _group = context.read<AppProvider>().currentGroup;
  }

  /// The group as this screen currently has it. Only [Group.defaultChipSetId]
  /// can differ from the session's group — no field of it is ever a chip.
  Group get group => _group;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    // A different group selected underneath (the sidebar is reachable from
    // here) discards the pointer chosen for the old one.
    if (_group.id != app.currentGroup.id) _group = app.currentGroup;
    // The pointer is the group's, not the screen's, so it is re-read from the
    // provider on every build rather than mirrored here. Holding a working copy
    // meant the choice died with the screen: it reached no other screen, no
    // other member's device, and nothing that creates the next tournament.
    if (_group.defaultChipSetId != app.currentGroup.defaultChipSetId) {
      _group = app.currentGroup;
    }

    if (!app.isAdmin) {
      return _NotHost(
        message: 'Only the host of this group can choose the chips it plays '
            'with by default.',
      );
    }

    final options = _options(app);
    final selectedId = _group.defaultChipSetId;
    final selected = _byId(options, selectedId);
    final seats = _typicalField(_group);

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.groupSettings),
            title: 'Default chip set',
            subtitle: '${_group.name} · every new game starts from this',
            actions: [
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(RoutePaths.editChipSet),
                child: const Text('+ New chip set'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your chip sets',
                  style: AppTypography.display(
                    size: AppFontSizes.lg,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The chips are yours, so the group only remembers which set '
                  'to use. Tap one to make it the default.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SetOptionCard(
                      key: ValueKey('chipSetOption-${option.id}'),
                      option: option,
                      selected: option.id == selectedId,
                      onTap: () => _select(option.id),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                WhyDisclosure(
                  explanation: StructureExplanation(
                    step: 'stack',
                    text: 'A pointer, never a copy - editing the set updates '
                        'every group that points at it. '
                        'Chip settings belong to the group, not to one game: '
                        'set once here and every tournament in this group '
                        'starts from it. A single game can still override the '
                        'chips in Configure without changing the group '
                        'default.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (selected != null) ...[
            _StartingStackCard(option: selected, seats: seats),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (selected == null && selectedId != null)
            AppAlertBanner(
              type: AppAlertType.warning,
              message: 'This group points at a chip set that is no longer in '
                  'your list - it was probably deleted. Pick another below, '
                  'or new games will have to choose their chips.',
            ),
        ],
      ),
    );
  }

  /// Stores the id and nothing else. A denormalised copy of the chips would
  /// strand the group on today's version of the set (see the class comment).
  void _select(String id) {
    if (_group.defaultChipSetId == id) return;
    // Written through the provider so it reaches the group document; the
    // screen's own copy is refreshed from there on the next build.
    context.read<AppProvider>().setGroupDefaultChipSet(id);
  }

  static ({String id, String name, List<ChipColor> chips})? _byId(
    List<({String id, String name, List<ChipColor> chips})> options,
    String? id,
  ) {
    if (id == null) return null;
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// The host's own sets, plus the Standard 500-piece box which is always on
  /// the list whether or not the host has ever saved a set.
  List<({String id, String name, List<ChipColor> chips})> _options(
    AppProvider app,
  ) {
    final options = <({String id, String name, List<ChipColor> chips})>[
      for (final s in app.savedChipSets)
        (id: s.id, name: s.name, chips: s.chips),
    ];
    if (!options.any((o) => o.id == _standardBoxId)) {
      options.add((
        id: _standardBoxId,
        name: 'Standard 500-piece box',
        chips: TournamentEngine.getPreset('Standard 500'),
      ));
    }
    return options;
  }

  /// How many players a typical night draws: the middle of this group's own
  /// past nights when it has played any, otherwise its membership clamped to
  /// a table-and-a-bit. §B10 asks for what the set produces "for a typical
  /// night", and the host's own nights are the only evidence available.
  int _typicalField(Group group) {
    final past = group.pastGames.map((g) => g.settings.players).where((p) => p > 1).toList()
      ..sort();
    if (past.isNotEmpty) return past[past.length ~/ 2];
    return group.members.length.clamp(2, 9).toInt();
  }
}

/// One chip set as a selectable option: colour dots, a total, and the DEFAULT
/// pill on the one the group points at.
class _SetOptionCard extends StatelessWidget {
  const _SetOptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ({String id, String name, List<ChipColor> chips}) option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chips = option.chips.where((c) => c.value > 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final pieces = chips.fold<int>(0, (sum, c) => sum + c.quantity);
    final total = chips.fold<int>(0, (sum, c) => sum + c.quantity * c.value);

    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : AppColors.borderSubtle,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color:
                  selected ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        option.name,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const AppBadge(
                        label: 'DEFAULT',
                        variant: AppBadgeVariant.green,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${chips.length} denominations · ${Formatters.chips(pieces)} '
                  'chips · ${Formatters.chips(total)} total',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final c in chips) _Swatch(chip: c),
                    ],
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

/// A colour dot with its value under it — the F4 chip swatch, small enough to
/// repeat across every option card.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.chip});

  final ChipColor chip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: chip.colorValue,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.foreground.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          Formatters.chips(chip.value),
          style: AppTypography.monoXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// "Shows the per-player starting stack the default set produces for a typical
/// night" — the per-player figure and the chips it is actually made of.
class _StartingStackCard extends StatelessWidget {
  const _StartingStackCard({required this.option, required this.seats});

  final ({String id, String name, List<ChipColor> chips}) option;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final usable = option.chips
        .where((c) => c.value > 0 && c.quantity > 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final total = usable.fold<int>(0, (sum, c) => sum + c.quantity * c.value);
    final unit = usable.map((c) => c.value).reduce(math.min);

    // The box has to stretch to about two takers per seat before it is handing
    // out chips that are already in someone's stack — the engine's own rule
    // for sizing a rebuy or add-on box.
    final reserve = TournamentEngine.lateEntryReserveMultiplier;
    final budget = seats <= 0 ? 0 : total ~/ (seats * reserve);
    final stack = (budget ~/ unit) * unit;
    final bigBlind = TournamentEngine.niceBB(
      stack / GroupChipsScreenState._targetDepthBB,
      unit,
    );
    final plan = stack <= 0
        ? const <ChipPlanEntry>[]
        : TournamentEngine.chipPlanAtLevel(
            stack: stack,
            chips: usable,
            currentBB: bigBlind,
            playersRemaining: math.max(1, seats),
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Starting stack',
            style: AppTypography.display(
              size: AppFontSizes.lg,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What a typical $seats-player night in this group would start each '
            'player on.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (stack <= 0)
            AppAlertBanner(
              type: AppAlertType.warning,
              message: 'This box cannot fund a $seats-player night. It is '
                  'worth ${Formatters.chips(total)} in total, so the field has '
                  'to be smaller or the set needs more chips.',
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formatters.chips(stack),
                  style: AppTypography.display(
                    size: AppFontSizes.xl,
                    weight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '(${(stack / math.max(1, bigBlind)).round()} big blinds)',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                plan
                    .map((e) => '${e.count} × ${e.color} '
                        '${Formatters.chips(e.value)}')
                    .join(' · '),
                style: AppTypography.monoSm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _BankCheck(
              total: total,
              perSeat: seats * stack,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Configure can use different chips for one game. The group default '
            'stays as it is.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankCheck extends StatelessWidget {
  const _BankCheck({required this.total, required this.perSeat});

  /// Everything the set is worth.
  final int total;

  /// What one seat's share of the field costs: starting stack plus reserves.
  final int perSeat;

  @override
  Widget build(BuildContext context) {
    final banked =
        (perSeat * GroupChipsScreenState._bankedStacksPerSeat).round();
    if (total >= banked) {
      return AppAlertBanner(
        type: AppAlertType.success,
        message: 'Your chip case covers every starting stack, a busy night of '
            'rebuys, every add-on and the early bonus.',
      );
    }
    if (total >= perSeat * 2) {
      return AppAlertBanner(
        type: AppAlertType.warning,
        message: 'Your chip case covers every starting stack and a rebuy for '
            'everyone, but not an add-on for everyone on top of that.',
      );
    }
    return AppAlertBanner(
      type: AppAlertType.warning,
      message: 'Your chip case does not cover a full field of starting stacks '
          'for this group — expect to run a smaller game or buy more chips.',
    );
  }
}

class _NotHost extends StatelessWidget {
  const _NotHost({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.groupSettings),
            title: 'Default chip set',
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const IconTile(
                  icon: Icons.lock_outline,
                  size: 56,
                  tone: IconTileTone.neutral,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
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
