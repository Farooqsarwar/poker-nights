import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../utils/import_results_parser.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';

/// Spec B12 — import last season's nights so the standings and the season
/// table start full. Host only.
///
/// Two steps, and the split is the spec's: **Check** parses and previews,
/// **Import n nights** commits. Committing straight from the text area would
/// make a bulk paste un-reviewable — the host would find out about the one
/// malformed line only after the good ones were already stored.
class ImportResultsScreen extends StatefulWidget {
  const ImportResultsScreen({super.key});

  @override
  State<ImportResultsScreen> createState() => _ImportResultsScreenState();
}

class _ImportResultsScreenState extends State<ImportResultsScreen> {
  final _controller = TextEditingController();

  /// Null until **Check** has been pressed. Deliberately not parsed on every
  /// keystroke: the error text names line numbers, and a list that reshuffles
  /// while the host is still typing the line it describes is unreadable.
  ImportParseResult? _checked;
  bool _saving = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isAdmin) {
      return _NotHost(
        onBack: () => context.go(RoutePaths.group),
        message: 'Only the host of this group can import past results.',
      );
    }

    final checked = _checked;
    final valid = checked?.valid ?? const <ImportLine>[];
    final failed = checked?.failed ?? const <ImportLine>[];

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.group),
            title: 'Import past results',
            subtitle: "Bring last season's nights in",
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('One night per line', style: _cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The date, a semicolon, then everyone in finishing order:',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    '2026-06-27; Costa, Alexey, Nina, Hugo, Elena',
                    style: AppTypography.monoSm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _controller,
                  label: 'Results to import',
                  placeholder: 'One night per line',
                  maxLines: 10,
                  // Any edit invalidates the preview: the figures below
                  // describe a specific text, and leaving them up would invite
                  // committing nights that are no longer what is on screen.
                  onChanged: (_) => setState(() {
                    _checked = null;
                    _result = null;
                    _error = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  variant: AppButtonVariant.secondary,
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : () => setState(() {
                            _checked = ImportResultsParser.parse(
                              _controller.text,
                              takenDates: app.seasonDates,
                            );
                            _result = null;
                            _error = null;
                          }),
                  child: const Text('Check'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_result != null) ...[
            AppAlertBanner(type: AppAlertType.success, message: _result!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_error != null) ...[
            AppAlertBanner(type: AppAlertType.error, message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],

          if (checked != null) ...[
            _Preview(
              valid: valid,
              failed: failed,
              memberIndex: app.importMemberIndex,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (valid.isNotEmpty)
              AppButton(
                fullWidth: true,
                size: AppButtonSize.lg,
                loading: _saving,
                disabled: _saving,
                onPressed: () => _commit(app, valid),
                child: Text('Import ${valid.length} '
                    '${valid.length == 1 ? 'night' : 'nights'}'),
              )
            else
              AppAlertBanner(
                type: AppAlertType.warning,
                message: 'Nothing to import — every line was refused. The '
                    'reason is on each one below.',
              ),
          ] else
            const _Hint(),
        ],
      ),
    );
  }

  /// Commit the checked lines. Only the lines **Check** accepted are sent:
  /// re-parsing here would commit something the host never previewed.
  Future<void> _commit(AppProvider app, List<ImportLine> valid) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final index = app.importMemberIndex;
      final saved = await app.importNights([
        for (final line in valid)
          ImportResultsParser.toNight(line, index),
      ]);
      if (!mounted) return;
      // `importNights` re-checks the dates against what is already stored, so
      // a night that landed between Check and Import is skipped rather than
      // double-counted. Saying "0 imported" is the honest outcome there.
      setState(() {
        _saving = false;
        _result = saved == 0
            ? 'Nothing was imported — every one of those nights is already in '
                'the season.'
            : 'Imported $saved ${saved == 1 ? 'night' : 'nights'} — standings '
                'and season points updated.';
        if (saved > 0) {
          _controller.clear();
          _checked = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save those nights: $e';
      });
    }
  }
}

TextStyle get _cardTitle =>
    AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600);

/// The preview: every line the host typed, with what happens to it.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.valid,
    required this.failed,
    required this.memberIndex,
  });

  final List<ImportLine> valid;
  final List<ImportLine> failed;
  final Map<String, String> memberIndex;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Preview', style: _cardTitle)),
              if (valid.isNotEmpty)
                AppBadge(
                  label: '${valid.length} ready',
                  variant: AppBadgeVariant.green,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            failed.isEmpty
                ? 'Every line is good. Press Import to save them.'
                // §B12: valid lines import even when others fail, so this is
                // a note about what will be skipped, not a block.
                : 'The ${valid.length} good ${valid.length == 1 ? 'line' : 'lines'} '
                    'will import. The ${failed.length} below will be skipped.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final line in [...valid, ...failed])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LineTile(line: line, memberIndex: memberIndex),
            ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.memberIndex});

  final ImportLine line;
  final Map<String, String> memberIndex;

  @override
  Widget build(BuildContext context) {
    final ok = line.ok;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: ok
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.destructive.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? AppColors.success : AppColors.destructive,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.date ?? line.raw.trim(),
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // The parser's error already reads "Line 3: ...", so it is
                  // shown as-is rather than re-wrapped in a second line label.
                  ok
                      ? '${line.names.length} players — ${line.names.join(', ')}'
                      : line.error!,
                  style: AppTypography.bodyXs.copyWith(
                    color: ok
                        ? AppColors.mutedForeground
                        : AppColors.destructive,
                  ),
                ),
                if (ok) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ...line.names.map((name) {
                    final normalized = name.trim().toLowerCase();
                    final matched = memberIndex.containsKey(normalized);
                    if (matched) return const SizedBox.shrink();
                    final suggestion = ImportResultsParser.findSimilarMember(name, memberIndex);
                    if (suggestion != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '"$name" → suggest: [member match]',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          IconTile(
            icon: Icons.content_paste_go_outlined,
            size: 56,
            tone: IconTileTone.neutral,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Paste your nights above and press Check. Nothing is saved until '
            'you press Import.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotHost extends StatelessWidget {
  const _NotHost({required this.onBack, required this.message});

  final VoidCallback onBack;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(onBack: onBack, title: 'Import past results'),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                IconTile(
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
