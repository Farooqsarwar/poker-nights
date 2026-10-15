import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/tournament_format.dart';
import '../utils/structure_builder_controller.dart';
import '../utils/tournament_engine.dart';

/// Section frame shared with the builder's other input sections.
class BuilderSection extends StatelessWidget {
  const BuilderSection({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: AppTypography.bodyXs
                    .copyWith(color: AppColors.mutedForeground)),
          ],
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

// ─── Player names (quick game) ─────────────────────────────────────────────

/// Optional names for the quick game: add or remove a row, never more rows
/// than players. Names are positional; blank rows are skipped when seating.
class BuilderNamesSection extends StatelessWidget {
  const BuilderNamesSection({super.key, required this.controller});

  final StructureBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final names = c.playerNames;
    final full = names.length >= c.players;
    return BuilderSection(
      label: 'Player names (optional)',
      hint: 'For the scoreboard and seating. Leave it empty for Player 1, '
          'Player 2, …',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.', style: AppTypography.bodySm),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: Key('name-field-$i-${names.length}'),
                      initialValue: names[i],
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Player ${i + 1} name (e.g. Alex)',
                      ),
                      onChanged: (v) => c.setPlayerName(i, v),
                    ),
                  ),
                  IconButton(
                    key: Key('remove-name-$i'),
                    tooltip: 'Remove name',
                    onPressed: () => c.removePlayerName(i),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-name'),
              onPressed: full ? null : c.addPlayerName,
              icon: const Icon(Icons.add, size: 18),
              label: Text(full ? 'Every player has a name' : 'Add a name'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── More options ──────────────────────────────────────────────────────────

/// A whole-number field. Empty means "not set" (the default), so a host can
/// always hand a decision back.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String fieldKey;
  final String label;
  final int? value;
  final void Function(int? v) onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        key: Key(fieldKey),
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
        onChanged: (t) => onChanged(t.isEmpty ? null : int.tryParse(t)),
      ),
    );
  }
}

/// Everything the old review screen and the event form offered beyond the
/// setup questions: buy-in, level length, bounty, prize places, table size,
/// the organiser's contribution, rebuy / add-on prices and the expectations
/// the blinds are sized against. Collapsed by default.
class BuilderMoreOptions extends StatelessWidget {
  const BuilderMoreOptions({super.key, required this.controller});

  final StructureBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final o = c.options;
    final rebuy = c.format == TournamentFormat.rebuy;
    final reEntry = c.format == TournamentFormat.reEntry;
    final showAddOn = c.rebuyNight && c.addOn;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ExpansionTile(
        key: const Key('more-options'),
        tilePadding: EdgeInsets.zero,
        title: Text('More options',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Buy-in, bounty, prize places, table size, prices, expectations',
          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
        ),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _NumField(
                fieldKey: 'opt-buyin',
                label: 'Buy-in',
                value: c.buyIn,
                onChanged: (v) {
                  if (v != null) c.setBuyIn(v);
                },
              ),
              _NumField(
                fieldKey: 'opt-level-mins',
                label: 'Level length (minutes)',
                hint: '${TournamentEngine.kMinLevelDurationMins}–'
                    '${TournamentEngine.kMaxLevelDurationMins}',
                value: c.levelMins,
                onChanged: (v) {
                  if (v != null &&
                      v >= TournamentEngine.kMinLevelDurationMins &&
                      v <= TournamentEngine.kMaxLevelDurationMins) {
                    c.setLevelMins(v);
                  }
                },
              ),
              _NumField(
                fieldKey: 'opt-organiser',
                label: 'Organiser contribution (%)',
                value: o.organizerPct == 0 ? null : o.organizerPct,
                onChanged: (v) => c.updateOptions(
                    (o) => o.organizerPct = (v ?? 0).clamp(0, 100)),
              ),
              _NumField(
                fieldKey: 'opt-max-per-table',
                label: 'Max per table',
                hint: 'group default',
                value: o.maxPerTable,
                onChanged: (v) =>
                    c.updateOptions((o) => o.maxPerTable = v?.clamp(4, 10)),
              ),
              _NumField(
                fieldKey: 'opt-paid-places',
                label: 'Paid places',
                hint: 'auto',
                value: o.paidPlaces,
                onChanged: (v) => c.updateOptions(
                    (o) => o.paidPlaces = (v == null || v < 1) ? null : v),
              ),
              if (rebuy)
                _NumField(
                  fieldKey: 'opt-rebuy-price',
                  label: 'Rebuy price',
                  hint: 'same as buy-in',
                  value: o.rebuyCost,
                  onChanged: (v) => c.updateOptions((o) => o.rebuyCost = v),
                ),
              if (showAddOn)
                _NumField(
                  fieldKey: 'opt-addon-price',
                  label: 'Add-on price',
                  hint: 'same as buy-in',
                  value: o.addOnCost,
                  onChanged: (v) => c.updateOptions((o) => o.addOnCost = v),
                ),
              if (rebuy)
                _NumField(
                  fieldKey: 'opt-exp-rebuys',
                  label: 'Expected rebuys',
                  hint: 'engine forecast',
                  value: o.expectedRebuys,
                  onChanged: (v) => c.updateOptions(
                      (o) => o.expectedRebuys = v,
                      ladder: true),
                ),
              if (rebuy)
                _NumField(
                  fieldKey: 'opt-rebuy-chips',
                  label: 'Rebuy chips',
                  hint: 'one starting stack',
                  value: o.rebuyChips,
                  onChanged: (v) =>
                      c.updateOptions((o) => o.rebuyChips = v, ladder: true),
                ),
              if (reEntry)
                _NumField(
                  fieldKey: 'opt-exp-reentries',
                  label: 'Expected re-entries',
                  hint: 'engine forecast',
                  value: o.expectedReEntries,
                  onChanged: (v) => c.updateOptions(
                      (o) => o.expectedReEntries = v,
                      ladder: true),
                ),
              if (reEntry)
                _NumField(
                  fieldKey: 'opt-reentry-chips',
                  label: 'Re-entry chips',
                  hint: 'one starting stack',
                  value: o.reEntryChips,
                  onChanged: (v) =>
                      c.updateOptions((o) => o.reEntryChips = v, ladder: true),
                ),
              if (showAddOn)
                _NumField(
                  fieldKey: 'opt-exp-addons',
                  label: 'Expected add-ons',
                  hint: 'engine forecast',
                  value: o.expectedAddOns,
                  onChanged: (v) => c.updateOptions(
                      (o) => o.expectedAddOns = v,
                      ladder: true),
                ),
              if (showAddOn)
                _NumField(
                  fieldKey: 'opt-addon-chips',
                  label: 'Add-on chips',
                  hint: 'one starting stack',
                  value: o.addOnChips,
                  onChanged: (v) =>
                      c.updateOptions((o) => o.addOnChips = v, ladder: true),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text('Knockout bounty', style: AppTypography.bodySm),
              ),
              Switch(
                key: const Key('opt-ko-toggle'),
                value: o.koEnabled,
                onChanged: (v) => c.updateOptions((o) => o.koEnabled = v),
              ),
            ],
          ),
          if (o.koEnabled)
            Align(
              alignment: Alignment.centerLeft,
              child: _NumField(
                fieldKey: 'opt-ko-amount',
                label: 'Bounty per knockout',
                value: o.koAmount,
                onChanged: (v) => c.updateOptions(
                    (o) => o.koAmount = v == null || v < 1 ? 1 : v),
              ),
            ),
        ],
      ),
    );
  }
}
