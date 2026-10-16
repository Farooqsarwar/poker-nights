import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../models/tournament_format.dart';
import '../../providers/app_provider.dart';
import '../../utils/event_settings_validation.dart';
import '../../utils/formatters.dart';
import '../../utils/sanitization.dart';
import '../../utils/structure_builder_controller.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/squircle_icon_button.dart';

/// The light group-event post. Structure decisions deliberately live in
/// the shared Create structure builder, after invitees have replied.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({
    super.key,
    this.presetId,
    this.repostGameId,
    this.initialSettings,
  });

  final String? presetId;
  final String? repostGameId;

  /// A seed used by tests and callers that already hold a draft. Normal app
  /// navigation restores [AppProvider.eventDraftForCurrentGroup] instead.
  final GameSettings? initialSettings;

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  late GameSettings _draft;
  late final TextEditingController _locationController;
  final Map<String, String> _errors = {};
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _draft = _seed(app);
    _locationController = TextEditingController(text: _draft.location);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  GameSettings _seed(AppProvider app) {
    var settings =
        widget.initialSettings ??
        app.eventDraftForCurrentGroup ??
        _defaultDraft(app);

    final repost = widget.repostGameId == null
        ? null
        : app.currentGroup.games
              .where((game) => game.id == widget.repostGameId)
              .firstOrNull;
    if (repost != null) {
      final old = repost.settings;
      final oldDate = old.scheduledStart ?? DateTime.now();
      final next = oldDate.add(const Duration(days: 7));
      settings = old.copyWith(
        date: _dateIso(next),
        time: _timeIso(next),
        players: _invitedCount(app),
        clearExpectedPlayersOverride: true,
        clearLockedExpectedPlayers: true,
        clearBuilderOverrides: true,
        clearRebuyLimit: true,
      );
    }

    final preset = widget.presetId == null
        ? null
        : app.presetById(widget.presetId);
    if (preset != null) {
      settings = preset.applyTo(settings);
    }
    return _normalise(settings);
  }

  GameSettings _defaultDraft(AppProvider app) {
    final start = DateTime.now().add(const Duration(hours: 2));
    final savedSet = app.savedChipSets.isEmpty ? null : app.savedChipSets.first;
    final chips =
        savedSet?.chips ?? TournamentEngine.getPreset('Home Set (4 colour)');
    final starter = GameSettings(
      name: 'Poker Night',
      date: _dateIso(start),
      time: _timeIso(start),
      location: '',
      players: _invitedCount(app),
      durationHours: 4,
      buyIn: 0,
      koEnabled: false,
      koAmount: GameSettings.minBounty,
      rebuys: false,
      rebuysCloseLevel: 0,
      reEntry: false,
      addOn: false,
      anteEnabled: true,
      anteAfterLevel: 6,
      organizerPct: 0,
      chipSet: List.of(chips),
      chipSetName: savedSet?.name ?? 'Home Set (4 colour)',
      format: TournamentFormat.freezeOut,
      pace: PaceMode.regular,
      targetDepthBB: TournamentType.normal.depthBB,
      breaks: const [],
    );
    final seeded = app.defaultGamePreset.applyTo(starter);
    return app.defaultGamePresetId == null
        ? seeded.copyWith(
            chipSet: starter.chipSet,
            chipSetName: starter.chipSetName,
          )
        : seeded;
  }

  GameSettings _normalise(GameSettings settings) {
    final bounty =
        ((settings.koAmount.clamp(
                  GameSettings.minBounty,
                  GameSettings.maxBounty,
                ) /
                GameSettings.bountyStep)
            .round() *
        GameSettings.bountyStep);
    final format = settings.effectiveFormat;
    return settings.copyWith(
      name: settings.name.trim().isEmpty ? 'Poker Night' : settings.name,
      buyIn: settings.buyIn.clamp(0, 10000),
      koAmount: bounty,
      rebuys: format == TournamentFormat.rebuy,
      reEntry: format == TournamentFormat.reEntry,
      format: format,
      pace: _typeForSettings(settings).pace,
      targetDepthBB:
          settings.targetDepthBB ?? _typeForSettings(settings).depthBB,
    );
  }

  static String _dateIso(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _timeIso(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  static TournamentType _typeForPace(PaceMode? pace) => switch (pace) {
    PaceMode.turbo => TournamentType.turbo,
    PaceMode.deep => TournamentType.deep,
    _ => TournamentType.normal,
  };

  static TournamentType _typeForSettings(GameSettings settings) =>
      TournamentTypeX.forDepth(settings.targetDepthBB ?? -1) ??
      _typeForPace(settings.pace);

  int _invitedCount(AppProvider app) {
    final count = app.currentGroup.members.length;
    return count < 2 ? 2 : count;
  }

  void _change(GameSettings settings) {
    final next = _normalise(settings);
    setState(() {
      _draft = next;
      _errors.clear();
    });
    context.read<AppProvider>().saveEventDraft(next);
  }

  void _setType(TournamentType type) {
    _change(_draft.copyWith(pace: type.pace, targetDepthBB: type.depthBB));
  }

  void _setFormat(TournamentFormat format) {
    final base = _draft.copyWith(
      clearBuilderOverrides: true,
      clearRebuyLimit: true,
    );
    _change(
      base.copyWith(
        format: format,
        rebuys: format == TournamentFormat.rebuy,
        reEntry: format == TournamentFormat.reEntry,
        addOn: format != TournamentFormat.freezeOut,
      ),
    );
  }

  Map<String, String> _validate() {
    const lightKeys = {'name', 'date', 'time', 'location', 'buyIn', 'koAmount'};
    return {
      for (final entry in validateEventSettings(_draft).entries)
        if (lightKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> _post(AppProvider app) async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() => _posting = true);
    try {
      // Prices, forecasts, chip amounts and the Unlimited/Limited choice are
      // structure decisions. Clearing them here is what lets Create structure
      // default the rebuy price to this buy-in and suggest the policy from the
      // eventual invited count.
      final posted = _draft.copyWith(
        name: Sanitization.sanitizeTournamentName(_draft.name.trim()),
        location: Sanitization.sanitizeLocation(_draft.location.trim()),
        players: _invitedCount(app),
        clearExpectedPlayersOverride: true,
        clearLockedExpectedPlayers: true,
      );
      final game = app.createGame(posted);
      app.setCurrentGame(game);
      app.publishGame();
      app.clearEventDraft();
      if (mounted) context.go(RoutePaths.invitation);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_draft.date) ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) _change(_draft.copyWith(date: _dateIso(picked)));
  }

  Future<void> _pickTime() async {
    final parts = _draft.time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.firstOrNull ?? '') ?? 20,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
    );
    if (picked != null) {
      _change(
        _draft.copyWith(
          time:
              '${picked.hour.toString().padLeft(2, '0')}:'
              '${picked.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  String _displayDate() {
    final date = DateTime.tryParse(_draft.date);
    if (date == null) return _draft.date;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int get _bonusPct =>
      ((_draft.earlyArrivalBonusPctOverride ?? 0.10) * 100).round();

  int get _indicativeStack => _draft.forceStack ?? 2000;

  Widget _label(String text) => Text(
    text,
    textAlign: TextAlign.left,
    style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _error(String key) {
    final error = _errors[key];
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        error,
        textAlign: TextAlign.left,
        style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
      ),
    );
  }

  Widget _picker({
    required Key key,
    required String value,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(value, textAlign: TextAlign.left),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.group);
      });
      return const SizedBox.shrink();
    }

    final type = _typeForSettings(_draft);
    final format = _draft.effectiveFormat;
    final bonusChips = (_indicativeStack * _bonusPct / 100).round();
    final currency = Formatters.currencySymbol;

    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SquircleIconButton(
                icon: Icons.chevron_left,
                size: 44,
                borderRadius: AppRadius.md,
                backgroundColor: AppColors.card,
                borderColor: AppColors.borderSubtle,
                onPressed: () => context.go(RoutePaths.group),
              ),
              const Spacer(),
              Text(
                'Draft saved',
                textAlign: TextAlign.left,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'New tournament',
            textAlign: TextAlign.left,
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Post the invitation now. Set chips, stacks, blinds and other '
            'gameplay details later in Create structure.',
            textAlign: TextAlign.left,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _label('Buy-in'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currency.isNotEmpty) ...[
                  Text(currency, style: AppTypography.bodyStyle),
                  const SizedBox(width: AppSpacing.xs),
                ],
                CountStepper(
                  key: const Key('event-buy-in'),
                  value: _draft.buyIn,
                  min: 0,
                  max: 10000,
                  step: 5,
                  semanticLabel: 'Buy-in',
                  onChanged: (value) => _change(_draft.copyWith(buyIn: value)),
                ),
              ],
            ),
          ),
          _error('buyIn'),
          const SizedBox(height: AppSpacing.lg),

          _label('Location'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('event-location'),
            controller: _locationController,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              hintText: 'Where are you playing?',
            ),
            onChanged: (value) => _change(_draft.copyWith(location: value)),
          ),
          _error('location'),
          const SizedBox(height: AppSpacing.lg),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Date'),
                    const SizedBox(height: AppSpacing.sm),
                    _picker(
                      key: const Key('event-date'),
                      value: _displayDate(),
                      onTap: _pickDate,
                    ),
                    _error('date'),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Start time'),
                    const SizedBox(height: AppSpacing.sm),
                    _picker(
                      key: const Key('event-time'),
                      value: _draft.time,
                      onTap: _pickTime,
                    ),
                    _error('time'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _label('KO bounty')),
                    AppToggle(
                      key: const Key('event-ko-toggle'),
                      value: _draft.koEnabled,
                      label: _draft.koEnabled ? 'On' : 'Off',
                      onChanged: (value) =>
                          _change(_draft.copyWith(koEnabled: value)),
                    ),
                  ],
                ),
                if (_draft.koEnabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _label('Bounty amount')),
                      if (currency.isNotEmpty) ...[
                        Text(currency),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      CountStepper(
                        key: const Key('event-ko-amount'),
                        value: _draft.koAmount,
                        min: GameSettings.minBounty,
                        max: GameSettings.maxBounty,
                        step: GameSettings.bountyStep,
                        semanticLabel: 'Bounty amount',
                        onChanged: (value) =>
                            _change(_draft.copyWith(koAmount: value)),
                      ),
                    ],
                  ),
                  _error('koAmount'),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _label('Tournament type'),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentedControl<TournamentType>(
            values: TournamentType.values,
            selected: type,
            labels: {
              for (final option in TournamentType.values) option: option.label,
            },
            onSelected: _setType,
          ),
          const SizedBox(height: AppSpacing.lg),

          _label('Rebuy type'),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentedControl<TournamentFormat>(
            values: const [
              TournamentFormat.freezeOut,
              TournamentFormat.rebuy,
              TournamentFormat.reEntry,
            ],
            selected: format,
            labels: const {
              TournamentFormat.freezeOut: 'Freeze-out',
              TournamentFormat.rebuy: 'Rebuy',
              TournamentFormat.reEntry: 'Re-entry',
            },
            onSelected: _setFormat,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _label('On-time bonus')),
                    AppToggle(
                      key: const Key('event-bonus-toggle'),
                      value: _draft.earlyArrivalBonusEnabled,
                      label: _draft.earlyArrivalBonusEnabled ? 'On' : 'Off',
                      onChanged: (value) => _change(
                        _draft.copyWith(
                          earlyArrivalBonusEnabled: value,
                          earlyArrivalBonusPctOverride:
                              _draft.earlyArrivalBonusPctOverride ?? 0.10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_draft.earlyArrivalBonusEnabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _label('Bonus percentage')),
                      CountStepper(
                        key: const Key('event-bonus-percent'),
                        value: _bonusPct,
                        min: 5,
                        max: 50,
                        step: 5,
                        suffix: '%',
                        semanticLabel: 'On-time bonus percent',
                        onChanged: (value) => _change(
                          _draft.copyWith(
                            earlyArrivalBonusPctOverride: value / 100,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '≈ ${Formatters.chips(bonusChips)} chips at a '
                    '${Formatters.chips(_indicativeStack)} stack — final '
                    'amount set in Create structure',
                    textAlign: TextAlign.left,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            key: const Key('post-event'),
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _posting ? null : () => _post(app),
            child: _posting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}
