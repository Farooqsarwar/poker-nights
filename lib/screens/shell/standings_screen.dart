import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/imported_night.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../services/entitlements.dart';
import '../../services/payment_service.dart';
import '../../utils/payouts_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/page_header.dart';
import '../../widgets/premium_gate.dart';

/// B11 -- a group's standings.
///
/// The all-time table is free; the season table and its points formulas are
/// Premium (D4). Nothing here derives from money: no profit, no ROI, nothing
/// from buy-ins or prizes (§E14). Points are never stored -- every figure is
/// recomputed from the finish orders of the group's completed games.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  /// §B11's default custom table.
  static const _customPoints = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1];

  SeasonFormula _formula = SeasonFormula.fieldSize;

  static String _keyFor(AppProvider app, LiveGame g, String playerId) {
    final p = g.players.where((p) => p.id == playerId).firstOrNull;
    if (p == null) return playerId;
    final isMember = app.currentGroup.members.any((m) => m.id == p.id);
    return isMember ? p.id : 'guest:${p.name.trim().toLowerCase()}';
  }

  static String _nameFor(LiveGame g, String playerId) =>
      g.players.where((p) => p.id == playerId).firstOrNull?.name ?? 'Player';

  /// The member-or-guest key and display name for one imported result row.
  /// Members use their id (exactly like [_keyFor]) so an imported night and a
  /// played game count toward the same row; everyone else is a lower-cased
  /// guest name, which also merges with a played game's guest of that name.
  static (String key, String name) _importedIdentity(
    AppProvider app,
    ImportedEntry e,
  ) {
    final id = e.playerId;
    if (id != null) {
      final m = app.currentGroup.members.where((m) => m.id == id).firstOrNull;
      return (id, m?.name ?? 'Former member');
    }
    final name = (e.guestName ?? '').trim();
    return ('guest:${name.toLowerCase()}', name.isEmpty ? 'Player' : name);
  }

  /// Completed games that recorded a finish order, oldest first.
  List<LiveGame> _nights(AppProvider app) {
    final nights = [
      for (final g in app.currentGroup.games)
        if (g.status == LiveGameStatus.completed && g.finishOrder.length >= 2)
          g,
    ]..sort((a, b) => a.settings.date.compareTo(b.settings.date));
    return nights;
  }

  List<_AllTimeRow> _allTime(
    AppProvider app,
    List<LiveGame> nights,
    List<ImportedNight> imported,
  ) {
    final byKey = <String, _AllTimeRow>{};
    // Imported nights (B12): finishing order only, so no knockouts.
    for (final n in imported) {
      final field = n.entries.length;
      for (var pos = 0; pos < field; pos++) {
        final (key, name) = _importedIdentity(app, n.entries[pos]);
        final row = byKey.putIfAbsent(key, () => _AllTimeRow(name));
        final place = field - pos;
        row.games++;
        row.placeSum += place;
        if (place == 1) row.wins++;
        if (place <= 3) row.podiums++;
      }
    }
    for (final g in nights) {
      final field = g.finishOrder.length;
      for (var pos = 0; pos < field; pos++) {
        final id = g.finishOrder[pos];
        final key = _keyFor(app, g, id);
        final row = byKey.putIfAbsent(key, () => _AllTimeRow(_nameFor(g, id)));
        final place = field - pos;
        row.games++;
        row.placeSum += place;
        if (place == 1) row.wins++;
        if (place <= 3) row.podiums++;
        row.knockouts +=
            g.players.where((p) => p.id == id).firstOrNull?.knockouts ?? 0;
      }
    }
    return byKey.values.toList()
      ..sort((a, b) {
        final byPodium = b.podiums.compareTo(a.podiums);
        if (byPodium != 0) return byPodium;
        final byAvg = a.average.compareTo(b.average);
        return byAvg != 0 ? byAvg : a.name.compareTo(b.name);
      });
  }

  List<SeasonStanding> _season(
    AppProvider app,
    List<LiveGame> nights,
    List<ImportedNight> imported,
    int year,
  ) {
    final results = <List<SeasonNightResult>>[];
    for (final n in imported) {
      if (DateTime.tryParse(n.date)?.year != year) continue;
      final field = n.entries.length;
      results.add([
        for (var pos = 0; pos < field; pos++)
          SeasonNightResult(
            name: _importedIdentity(app, n.entries[pos]).$2,
            finish: field - pos,
          ),
      ]);
    }
    for (final g in nights) {
      if (DateTime.tryParse(g.settings.date)?.year != year) continue;
      final field = g.finishOrder.length;
      results.add([
        for (var pos = 0; pos < field; pos++)
          SeasonNightResult(
            name: _nameFor(g, g.finishOrder[pos]),
            finish: field - pos,
          ),
      ]);
    }
    return PayoutsEngine.seasonTable(
      results,
      formula: _formula,
      custom: _customPoints,
    );
  }

  String get _explanation => switch (_formula) {
    SeasonFormula.fieldSize =>
      'Points = 10 × √(players ÷ finish), one decimal. A win in a 12-player '
          'night is worth 34.6, in a 6-player night 24.5, and last place still '
          'earns 10 for playing. Rebuys don\'t change the field size.',
    SeasonFormula.ladder =>
      '10-7-5-3-1 for the top five, 0 for everyone else. Simple to explain, '
          'but a win counts the same in any field size.',
    SeasonFormula.custom =>
      'The host\'s own table: ${_customPoints.join('-')} for the top '
          '${_customPoints.length}, 0 for everyone else.',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final nights = _nights(app);
    final imported = app.importedNights;
    final table = _allTime(app, nights, imported);
    // The season is the year of the most recent night, played or imported.
    final dates = [
      for (final g in nights) g.settings.date,
      for (final n in imported) n.date,
    ]..sort();
    final year = dates.isNotEmpty
        ? (DateTime.tryParse(dates.last)?.year ?? DateTime.now().year)
        : DateTime.now().year;

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.home),
            title: 'Standings',
            subtitle: app.hasCurrentGroup ? app.currentGroup.name : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (table.isEmpty) ...[
            const AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No finished games yet',
              description:
                  'Standings fill in as the group finishes tournaments.',
            ),
            const SizedBox(height: AppSpacing.xl),
          ] else ...[
            const AppEyebrow('All time', muted: true),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < table.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.border),
                    _AllTimeTile(rank: i + 1, row: table[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Row(
            children: [
              AppEyebrow('Season $year · points', muted: true),
              const SizedBox(width: AppSpacing.sm),
              AppTag(
                app.premiumTier == PremiumTier.premium ? 'UNLOCKED' : 'PREMIUM',
                tone: app.premiumTier == PremiumTier.premium
                    ? AppTagTone.success
                    : AppTagTone.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumGate(
            tier: app.premiumTier,
            feature: PremiumFeature.seasons,
            blurb:
                'Season tables score every night by finish and field size.',
            child: _SeasonBlock(
              formula: _formula,
              onFormula: (f) => setState(() => _formula = f),
              standings: _season(app, nights, imported, year),
              explanation: _explanation,
            ),
          ),
          if (app.isAdmin) ...[
            const SizedBox(height: AppSpacing.xl),
            const AppEyebrow('Host tools', muted: true),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(RoutePaths.importResults),
              child: const Text('Import past results'),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _AllTimeRow {
  _AllTimeRow(this.name);

  final String name;
  int games = 0;
  int wins = 0;
  int podiums = 0;
  int knockouts = 0;
  int placeSum = 0;

  double get average => games == 0 ? 0 : placeSum / games;
}

class _AllTimeTile extends StatelessWidget {
  const _AllTimeTile({required this.rank, required this.row});

  final int rank;
  final _AllTimeRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.games} played · ${row.wins} wins · '
                  '${row.podiums} podiums · ${row.knockouts} KO',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'avg ${row.average.toStringAsFixed(1)}',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonBlock extends StatelessWidget {
  const _SeasonBlock({
    required this.formula,
    required this.onFormula,
    required this.standings,
    required this.explanation,
  });

  final SeasonFormula formula;
  final ValueChanged<SeasonFormula> onFormula;
  final List<SeasonStanding> standings;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTabs(
          tabs: const [
            AppTabItem(id: 'fieldSize', label: 'Field-size'),
            AppTabItem(id: 'ladder', label: '10-7-5-3-1'),
            AppTabItem(id: 'custom', label: 'Custom'),
          ],
          active: formula.name,
          onChanged: (id) => onFormula(
            SeasonFormula.values.firstWhere((f) => f.name == id),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (standings.isEmpty)
          Text(
            'No finished games this season yet.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < standings.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            standings[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm,
                          ),
                        ),
                        Text(
                          '${standings[i].wins} W',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          standings[i].points.toStringAsFixed(1),
                          style: AppTypography.bodySm,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          explanation,
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
