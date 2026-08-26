import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../models/tournament_preset.dart';
import '../../providers/app_provider.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/chip_token.dart';

enum _ChipMode { preset, quick, exact }

/// Minimum normalized score for a preset to qualify as a suggestion
/// (tech spec §6.2).
const double _presetMatchMinScore = 0.7;

/// Formats [hours] the way the wizard's duration picker does (`4h`, `3.5h`).
String _hoursLabel(double hours) =>
    '${hours == hours.roundToDouble() ? hours.round() : hours}h';

/// Tech spec §6.2 — closeness score for suggesting one of the administrator's
/// saved presets instead of building the tournament from zero. Each compared
/// facet contributes its weight to a normalized 0..1 score (maxima sum to 1):
///
/// | Facet               | Full | Partial                        |
/// |---------------------|------|--------------------------------|
/// | Buy-in              | 0.25 | within ±20% → 0.15             |
/// | Bounty + amount     | 0.15 | same on/off, amount off → 0.075|
/// | Target duration     | 0.15 | within ±0.5h → 0.08            |
/// | Expected attendance | 0.10 | posture miss → 0               |
/// | Rebuys + close lvl  | 0.10 | same on/off, level off → 0.05  |
/// | Add-on              | 0.10 | —                              |
/// | Chip set            | 0.15 | same colour count → 0.075      |
///
/// Inputs that are not known yet (empty buy-in / bounty field, no attendance
/// signal) earn half their weight, so an untouched form neither earns nor
/// loses a suggestion. Presets store no headcount, so attendance fit uses the
/// rebuy-posture heuristic of `AppProvider.suggestPresets`: fields of ten or
/// fewer players favour rebuy presets, larger fields favour no-rebuy presets.
/// Anything that is not a full or partial hit is reported in [diffs] so the
/// UI can explain the differences.
({double score, List<String> diffs}) _matchPreset(
  TournamentPreset p, {
  required int buyIn,
  required bool koEnabled,
  required int koAmount,
  required double durationHours,
  required int expectedPlayers,
  required bool rebuys,
  required int rebuysCloseLevel,
  required bool addOn,
  required String chipSetName,
  required int chipColorCount,
}) {
  final diffs = <String>[];
  var score = 0.0;

  if (buyIn <= 0) {
    score += 0.125;
  } else if (p.buyIn == buyIn) {
    score += 0.25;
  } else {
    if ((p.buyIn - buyIn).abs() / buyIn <= 0.2) score += 0.15;
    diffs.add('Buy-in ${p.buyIn} (yours: $buyIn)');
  }

  if (p.koEnabled == koEnabled) {
    if (!koEnabled) {
      score += 0.15;
    } else if (koAmount <= 0 || p.koAmount == koAmount) {
      score += koAmount <= 0 ? 0.075 : 0.15;
      if (koAmount > 0) diffs.add('Bounty ${p.koAmount} (yours: $koAmount)');
    } else {
      score += 0.075;
      diffs.add('Bounty ${p.koAmount} (yours: $koAmount)');
    }
  } else {
    diffs.add(
      'Bounty ${p.koEnabled ? 'on' : 'off'} '
      '(yours: ${koEnabled ? 'on' : 'off'})',
    );
  }

  if (p.durationHours == durationHours) {
    score += 0.15;
  } else {
    if ((p.durationHours - durationHours).abs() <= 0.5) score += 0.08;
    diffs.add(
      'Duration ${_hoursLabel(p.durationHours)} '
      '(yours: ${_hoursLabel(durationHours)})',
    );
  }

  if (expectedPlayers <= 0) {
    score += 0.05;
  } else if ((expectedPlayers <= 10 && p.rebuys) ||
      (expectedPlayers > 10 && !p.rebuys)) {
    score += 0.10;
  }

  if (p.rebuys == rebuys) {
    if (!rebuys) {
      score += 0.10;
    } else if (p.rebuysCloseLevel == rebuysCloseLevel) {
      score += 0.10;
    } else {
      score += 0.05;
      diffs.add(
        'Rebuys close L${p.rebuysCloseLevel} (yours: L$rebuysCloseLevel)',
      );
    }
  } else {
    diffs.add(
      'Rebuys ${p.rebuys ? 'on' : 'off'} (yours: ${rebuys ? 'on' : 'off'})',
    );
  }

  if (p.addOn == addOn) {
    score += 0.10;
  } else {
    diffs.add(
      'Add-on ${p.addOn ? 'on' : 'off'} (yours: ${addOn ? 'on' : 'off'})',
    );
  }

  if (p.chipSetName == chipSetName) {
    score += 0.15;
  } else {
    if (chipSetName.isNotEmpty && p.chipSet.length == chipColorCount) {
      score += 0.075;
    }
    diffs.add(
      'Chip set ${p.chipSetName} '
      '(yours: ${chipSetName.isEmpty ? 'custom' : chipSetName})',
    );
  }

  return (score: score, diffs: diffs);
}

/// 4-step tournament creation wizard mirroring the web `CreateTournamentPage`.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key, this.presetId});

  /// Optional `?preset=` query param: pre-fills the form from a saved
  /// tournament preset (checklist 09-006).
  final String? presetId;

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  static const _steps = [
    'Event details',
    'Chip set',
    'Rules',
    'Review & create',
  ];

  int _step = 1;

  // Step 1
  final _name = TextEditingController();
  final _date = TextEditingController(text: _todayIso);
  final _time = TextEditingController(text: '20:00');
  final _location = TextEditingController();
  final _buyIn = TextEditingController();
  bool _locationPrivate = false;
  double _duration = 4.0;
  final Map<String, String> _errors = {};

  // Player count is derived from the group + RSVP signals, never asked as an
  // input (the guest/going +N counts determine who actually shows up).

  // Step 2
  _ChipMode _chipMode = _ChipMode.preset;
  String _presetName = '';
  late List<ChipColor> _chipSet;

  // Step 3 — defaults follow the client's "generally" list:
  // KO bounty off, add-on on (buy-in price, end of L6), rebuys unlimited
  // until end of L6, re-entry off.
  bool _rebuys = true;
  bool _rebuyUnlimited = true;
  int _rebuysClose = 6;
  final _rebuyLimit = TextEditingController(text: '1');
  final _rebuyCost = TextEditingController();
  bool _reEntry = false;
  bool _addOn = true;
  int _addOnClose = 6;
  final _addOnCost = TextEditingController();
  bool _koEnabled = false;
  final _koAmount = TextEditingController(text: '5');
  AntePreference _antePreference = AntePreference.recommend;
  int _anteAfterLevel = 6;
  AnteStyle get _anteStyle => switch (_antePreference) {
    AntePreference.recommend || AntePreference.bigBlind => AnteStyle.bigBlind,
    AntePreference.none || AntePreference.individual => AnteStyle.individual,
  };
  bool get _anteEnabled => _antePreference != AntePreference.none;
  final _orgPctController = TextEditingController(text: '0');
  int get _orgPct => int.tryParse(_orgPctController.text.trim()) ?? 0;

  // Preset support (checklist §9.1). Tech spec §6.2: before starting from
  // zero, saved presets close to the current base inputs are suggested.
  int _expectedPlayers = 0;

  /// Top §6.2 matches (at most two, best score first), recomputed while the
  /// admin edits the base inputs.
  final List<({TournamentPreset preset, double score, List<String> diffs})>
      _presetMatches = [];
  bool _suggestionsDismissed = false;
  String? _appliedPresetId;

  /// §6.2 guard flag: once the review step is reached the suggestions never
  /// come back, even if the admin navigates back to edit details.
  bool _reachedReview = false;

  static String get _todayIso {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _presetName = TournamentEngine.presetNames.isNotEmpty
        ? TournamentEngine.presetNames[2]
        : TournamentEngine.presetNames.firstOrNull ?? '';
    _chipSet = List.of(TournamentEngine.getPreset(_presetName));

    // Auto-fill players from group + apply preset / suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      final group = app.currentGroup;

      int expected = group.members.length;
      for (final poll in group.polls) {
        if (poll.question.toLowerCase().contains('going') ||
            poll.question.toLowerCase().contains('play')) {
          // votes is userId -> selected option(s) (single or multi choice).
          final yesVotes = poll.votes.values
              .expand((selected) => selected)
              .where(
                (v) =>
                    v.toLowerCase() == 'yes' ||
                    v.toLowerCase() == 'going' ||
                    v.toLowerCase() == 'in',
              )
              .length;
          if (yesVotes > 0) {
            expected = yesVotes;
            break;
          }
        }
      }

      if (widget.presetId != null) {
        final preset = app.presetById(widget.presetId);
        if (preset != null) {
          setState(() => _applyPreset(preset));
          return;
        }
      }

      _expectedPlayers = expected;
      _refreshPresetMatches(app);
    });
  }

  /// Tech spec §6.2 — recomputes which of the administrator's saved presets
  /// sit close enough (score >= [_presetMatchMinScore]) to the current base
  /// inputs to be suggested, keeping the two best scores. Runs on wizard load
  /// and on every base-input edit; the guard stops it for good once a preset
  /// was explicitly picked ([_appliedPresetId]), the section was dismissed,
  /// or the review step was reached.
  void _refreshPresetMatches(AppProvider app) {
    if (_appliedPresetId != null ||
        _suggestionsDismissed ||
        _reachedReview) {
      _presetMatches.clear();
      setState(() {});
      return;
    }
    final buyIn = num.tryParse(_buyIn.text)?.toInt() ?? 0;
    final koAmount = num.tryParse(_koAmount.text)?.toInt() ?? 0;
    final scored =
        <({TournamentPreset preset, double score, List<String> diffs})>[];
    for (final p in app.presets) {
      final match = _matchPreset(
        p,
        buyIn: buyIn,
        koEnabled: _koEnabled,
        koAmount: koAmount,
        durationHours: _duration,
        expectedPlayers: _expectedPlayers,
        rebuys: _rebuys,
        rebuysCloseLevel: _rebuysClose,
        addOn: _addOn,
        chipSetName: _chipMode == _ChipMode.preset ? _presetName : '',
        chipColorCount: _chipSet.length,
      );
      if (match.score >= _presetMatchMinScore) {
        scored.add((preset: p, score: match.score, diffs: match.diffs));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    _presetMatches
      ..clear()
      ..addAll(scored.take(2));
    setState(() {});
  }

  /// Score-based subtitle for a suggestion card (tech spec §6.2).
  String _matchLabel(double score) =>
      score >= 0.85 ? 'Very close match' : 'Close match';

  /// Fills every field of the wizard from a saved preset (09-006).
  void _applyPreset(TournamentPreset p) {
    _name.text = p.name;
    _buyIn.text = p.buyIn.toString();
    _duration = p.durationHours;
    _rebuys = p.rebuys;
    _rebuysClose = p.rebuysCloseLevel;
    _rebuyUnlimited = p.rebuyLimit == null;
    if (p.rebuyLimit != null) _rebuyLimit.text = p.rebuyLimit.toString();
    _rebuyCost.text = p.rebuyCost?.toString() ?? '';
    _reEntry = p.reEntry;
    _addOn = p.addOn;
    _addOnClose = p.addOnCloseLevel;
    _addOnCost.text = p.addOnCost?.toString() ?? '';
    _koEnabled = p.koEnabled;
    _koAmount.text = p.koAmount.toString();
    _antePreference = p.anteEnabled
        ? AntePreference.bigBlind
        : AntePreference.none;
    _anteAfterLevel = p.anteAfterLevel;
    _orgPctController.text = p.organizerPct.toString();
    _chipSet = List.of(p.chipSet);
    if (TournamentEngine.presetNames.contains(p.chipSetName)) {
      _chipMode = _ChipMode.preset;
      _presetName = p.chipSetName;
    } else {
      _chipMode = _ChipMode.exact;
    }
    _appliedPresetId = p.id;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _date,
      _time,
      _location,
      _buyIn,
      _koAmount,
      _rebuyLimit,
      _rebuyCost,
      _addOnCost,
      _orgPctController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validateStep1() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors['name'] = 'Required';
    if (_date.text.trim().isEmpty) _errors['date'] = 'Required';
    final b = num.tryParse(_buyIn.text) ?? 0;
    if (b <= 0) _errors['buyIn'] = 'Must be positive';
    setState(() {});
    return _errors.isEmpty;
  }

  void _next() {
    if (_step == 1 && !_validateStep1()) return;
    setState(() {
      _step++;
      if (_step >= _steps.length) {
        // Tech spec §6.2 guard: reaching the review step stops suggesting,
        // even when the admin goes back to edit afterwards.
        _reachedReview = true;
        _presetMatches.clear();
      }
    });
  }

  String get _durationLabel =>
      '${_duration == _duration.roundToDouble() ? _duration.round() : _duration}h';

  /// Global rect of this screen's content area.
  ///
  /// Dialogs live in the root overlay, which spans the whole window — including
  /// the persistent sidebar. Centring on the window therefore looks shifted to
  /// the left. Measuring the screen's own box lets the dialog centre over the
  /// *content* instead, with no hardcoded sidebar width.
  Rect? get _contentRect {
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  /// Centered, width-capped review dialog (07-018).
  Future<bool?> _showConfirmDialog() {
    final Rect? anchor = _contentRect;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => _ConfirmDetailsDialog(
        anchorRect: anchor,
        gameRows: <_ConfirmItem>[
          _ConfirmItem('Name', _name.text.trim()),
          _ConfirmItem('When', '${_date.text} at ${_time.text}'),
          if (_location.text.trim().isNotEmpty)
            _ConfirmItem(
              'Where',
              _location.text.trim() + (_locationPrivate ? '  (private)' : ''),
            ),
          // Player count is not an input — it comes from the Going /
          // Going +N RSVPs (client rule).
          _ConfirmItem('Players', 'From RSVPs'),
          _ConfirmItem('Buy-in', _buyIn.text.trim()),
          _ConfirmItem('Duration', _durationLabel),
        ],
        ruleRows: <_ConfirmItem>[
          _ConfirmItem(
            'Rebuys',
            _rebuys
                ? (_rebuyUnlimited
                      ? 'Unlimited to L$_rebuysClose'
                      : 'Limited to L$_rebuysClose')
                : 'Off',
          ),
          _ConfirmItem('Re-entry', _reEntry ? 'Yes' : 'No'),
          _ConfirmItem('Add-on', _addOn ? 'Yes, to L$_addOnClose' : 'No'),
          _ConfirmItem('Bounty', _koEnabled ? 'Yes (${_koAmount.text})' : 'No'),
          _ConfirmItem(
            'Ante',
            _antePreference == AntePreference.none
                ? 'No'
                : 'From L$_anteAfterLevel',
          ),
          _ConfirmItem('Organizational costs', '$_orgPct%'),
        ],
        chipSet: _chipSet,
        chipSetName: _chipMode == _ChipMode.preset ? _presetName : 'Custom',
      ),
    );
  }

  void _generate(AppProvider app) async {
    if (_chipSet.isEmpty) {
      await showAppModal(
        context: context,
        title: 'Set chip colours first',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Every game needs a chip set. Add chip colours and values before generating.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _step = 2);
              },
              child: const Text('Go to chip set'),
            ),
          ],
        ),
      );
      return;
    }

    final values = _chipSet.map((c) => c.value).toList();
    if (values.toSet().length != values.length) {
      await showAppModal(
        context: context,
        title: 'Duplicate chip values',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No two chip colours can have the same value. Please adjust your chip set.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _step = 2);
              },
              child: const Text('Fix chip set'),
            ),
          ],
        ),
      );
      return;
    }

    // Client feedback (07-018): confirm before creating, and persist a custom
    // chip set as a preset once.
    final confirmed = await _showConfirmDialog();
    if (confirmed != true || !mounted) return;

    // Persist a custom chip set once so it can be reused next time.
    if (_chipMode != _ChipMode.preset) {
      final customName = '${_name.text.trim()} set';
      app.saveChipSet(
        'cs-${_name.text.trim().replaceAll(' ', '-').toLowerCase()}',
        customName,
        _chipSet,
      );
    }

    // Client flow: the event is created and published straight away so the
    // group can RSVP. The structure is NOT generated here — the AI estimates
    // stacks/blinds/levels 30 minutes before start from the actual
    // attendance (Going + Going +N answers).
    final game = app.createGame(
      GameSettings(
        name: _name.text.trim(),
        date: _date.text.trim(),
        time: _time.text.trim(),
        location: _location.text.trim(),
        // Roster size — the real player count comes from RSVPs, never from an
        // input field (client rule).
        players: app.currentGroup.members.length,
        durationHours: _duration,
        buyIn: num.tryParse(_buyIn.text)?.toInt() ?? 15,
        koEnabled: _koEnabled,
        koAmount: num.tryParse(_koAmount.text)?.toInt() ?? 5,
        rebuys: _rebuys,
        rebuysCloseLevel: _rebuysClose,
        rebuyLimit: _rebuys && !_rebuyUnlimited
            ? (int.tryParse(_rebuyLimit.text) ?? 1)
            : null,
        rebuyCost: num.tryParse(_rebuyCost.text)?.toInt(),
        reEntry: _reEntry,
        addOn: _addOn,
        addOnCloseLevel: _addOnClose,
        addOnCost: num.tryParse(_addOnCost.text)?.toInt(),
        anteEnabled: _anteEnabled,
        anteAfterLevel: _anteAfterLevel,
        anteStyle: _anteStyle,
        antePreference: _antePreference,
        organizerPct: _orgPct.clamp(0, 100),
        chipSet: _chipSet,
        chipSetName: _chipMode == _ChipMode.preset ? _presetName : 'Custom',
        locationPrivate: _locationPrivate,
      ),
    );
    app.setCurrentGame(game);
    app.publishGame();
    context.go(RoutePaths.invitation);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isAdmin = app.isAdmin;

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.group);
      });
      return const SizedBox.shrink();
    }

    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              InkWell(
                onTap: () => _step == 1
                    ? context.go(RoutePaths.group)
                    : setState(() => _step--),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back,
                    size: AppFontSizes.xl,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Game',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Step $_step of ${_steps.length}: ${_steps[_step - 1]}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Progress
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i < _step ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step == 1 &&
              _presetMatches.isNotEmpty &&
              !_suggestionsDismissed &&
              _appliedPresetId == null) ...[
            _buildSuggestionBanner(),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Steps
          if (_step == 1) _buildStep1(app),
          if (_step == 2) _buildStep2(app),
          if (_step == 3) _buildStep3(app),
          if (_step == 4) _buildStep4(app),
          const SizedBox(height: AppSpacing.lg),
          // Nav buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: () => _step == 1
                    ? context.go(RoutePaths.group)
                    : setState(() => _step--),
                child: _step == 1
                    ? const Text('Cancel')
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: AppColors.icon,
                          ),
                          SizedBox(width: 6),
                          Text('Back'),
                        ],
                      ),
              ),
              if (_step < 4)
                AppButton(
                  onPressed: _next,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next'),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.icon,
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

  Widget _buildStep1(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: 'Tournament name',
            placeholder: 'e.g. Friday Poker',
            error: _errors['name'],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _date,
                  label: 'Date',
                  error: _errors['date'],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(controller: _time, label: 'Start time'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _location,
            label: 'Location (optional)',
            placeholder: "e.g. Daniel's place",
          ),
          if (_location.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ToggleRow(
              title: 'Keep address private',
              subtitle: 'Guests see the address only after check-in',
              value: _locationPrivate,
              onChanged: (v) => setState(() => _locationPrivate = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _buyIn,
                      label: 'Buy-in amount',
                      error: _errors['buyIn'],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _refreshPresetMatches(app),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Client rule: 4h is the "generally" duration, so it is the first
          // (and default) option; the host can pick any other duration.
          _SegmentedPicker(
            label: 'Target duration',
            options: const ['4h', '3h', '3.5h', '4.5h', '5h', '5.5h', '6h'],
            selected: _durationLabel,
            onChanged: (v) {
              final val = v.replaceAll('h', '');
              setState(() => _duration = double.tryParse(val) ?? 4.0);
              // §6.2: base-input edits refresh the suggested presets.
              _refreshPresetMatches(app);
            },
          ),
        ],
      ),
    );
  }

  /// Tech spec §6.2 — "Suggested" section shown above the form before the
  /// admin starts from zero. Up to two matches are offered (spec: show both
  /// and explain the differences), each with a closeness subtitle and the
  /// differences against the current inputs. Tapping applies through the
  /// existing [_applyPreset] path.
  Widget _buildSuggestionBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Suggested preset${_presetMatches.length > 1 ? 's' : ''}',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() {
                _suggestionsDismissed = true;
                _presetMatches.clear();
              }),
              child: Text(
                'Ignore',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final m in _presetMatches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.preset.name,
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _matchLabel(m.score),
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.diffs.isEmpty
                              ? 'Matches your current settings'
                              : m.diffs.join(' · '),
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    size: AppButtonSize.sm,
                    onPressed: () {
                      setState(() => _applyPreset(m.preset));
                      // §6.2 guard: stop suggesting once one is picked.
                      _presetMatches.clear();
                    },
                    child: const Text('Use preset'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStep2(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Client rule: chip colours + values should be presettable and
          // reusable. If the host has no saved chip set yet, point them at the
          // quick setup instead of silently defaulting.
          if (app.savedChipSets.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No saved chip set yet. Use "Quick setup" to pick your colours and '
                      'availability — it will be saved so you can reuse it next game.',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              for (int i = 0; i < _ChipMode.values.length; i++) ...[
                Expanded(
                  child: _ModeButton(
                    label: switch (_ChipMode.values[i]) {
                      _ChipMode.preset => 'Saved preset',
                      _ChipMode.quick => 'Quick setup',
                      _ChipMode.exact => 'Exact count',
                    },
                    active: _chipMode == _ChipMode.values[i],
                    onTap: () =>
                        setState(() => _chipMode = _ChipMode.values[i]),
                  ),
                ),
                if (i < _ChipMode.values.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_chipMode == _ChipMode.preset) ...[
            AppSelect(
              label: 'Select chip preset',
              value: _presetName,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _presetName = v;
                  _chipSet = List.of(TournamentEngine.getPreset(v));
                });
                // §6.2: the chip set facet feeds preset matching.
                _refreshPresetMatches(app);
              },
              items: [
                for (final name in TournamentEngine.presetNames)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final c in _chipSet)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ChipToken(
                    colorName: c.color,
                    hex: c.colorValue,
                    value: c.value,
                    count: c.quantity,
                  ),
                ),
              ),
          ] else if (_chipMode == _ChipMode.quick) ...[
            Text(
              'Select available colours and rank them from most to least available. Poker Night will suggest values.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _chipSet.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ChipToken(
                      colorName: _chipSet[i].color,
                      hex: _chipSet[i].colorValue,
                      value: _chipSet[i].value,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Rank ${i + 1}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: i == 0
                          ? null
                          : () => setState(() {
                              final tmp = _chipSet[i - 1];
                              _chipSet[i - 1] = _chipSet[i];
                              _chipSet[i] = tmp;
                            }),
                      icon: Icon(
                        Icons.arrow_upward,
                        size: 14,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: i == _chipSet.length - 1
                          ? null
                          : () => setState(() {
                              final tmp = _chipSet[i + 1];
                              _chipSet[i + 1] = _chipSet[i];
                              _chipSet[i] = tmp;
                            }),
                      icon: Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              'Enter exact chip counts and values.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _chipSet.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ChipToken(
                      colorName: _chipSet[i].color,
                      hex: _chipSet[i].colorValue,
                      value: _chipSet[i].value,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _chipSet[i].color,
                        style: AppTypography.bodyXs,
                      ),
                    ),
                    _ExactInput(
                      label: 'Value',
                      value: '${_chipSet[i].value}',
                      onChanged: (v) => setState(() {
                        _chipSet[i] = _chipSet[i].copyWith(
                          value: int.tryParse(v) ?? 1,
                        );
                      }),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ExactInput(
                      label: '×',
                      value: '${_chipSet[i].quantity}',
                      onChanged: (v) => setState(() {
                        _chipSet[i] = _chipSet[i].copyWith(
                          quantity: int.tryParse(v) ?? 0,
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: _showAddChipDialog,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14),
                  SizedBox(width: 4),
                  Text('Add Chip Color'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChipDialog() {
    Color pickerColor = AppColors.mutedForeground;
    final nameController = TextEditingController(text: 'Custom');
    final valueController = TextEditingController(text: '100');
    final qtyController = TextEditingController(text: '50');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => Dialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add custom colour',
                        style: AppTypography.display(
                          size: AppFontSizes.lg,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: (color) {
                          pickerColor = color;
                        },
                        enableAlpha: false,
                        labelTypes: const [],
                        portraitOnly: true,
                        pickerAreaBorderRadius: BorderRadius.circular(
                          AppRadius.md,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: nameController,
                        label: 'Colour name',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: valueController,
                              label: 'Value',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: qtyController,
                              label: 'Quantity',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      onPressed: () {
                        final hexName =
                            '#${pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                        final inputName = nameController.text.trim();
                        final val =
                            int.tryParse(valueController.text.trim()) ?? 100;
                        final qty =
                            int.tryParse(qtyController.text.trim()) ?? 50;
                        setState(() {
                          _chipSet.add(
                            ChipColor(
                              color: inputName.isEmpty ? hexName : inputName,
                              hex: pickerColor.toARGB32(),
                              value: val,
                              quantity: qty,
                            ),
                          );
                          _chipMode = _ChipMode.exact;
                        });
                        // §6.2: a custom set changes the chip facet.
                        _refreshPresetMatches(context.read<AppProvider>());
                        Navigator.pop(context);
                      },
                      child: const Text('Add colour'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rebuys',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Players can re-enter after elimination',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SegmentedPicker(
                  options: const ['Off', 'Limited', 'Unlimited'],
                  selected: _rebuys
                      ? (_rebuyUnlimited ? 'Unlimited' : 'Limited')
                      : 'Off',
                onChanged: (v) => setState(() {
                  if (v == 'Off') {
                    _rebuys = false;
                    _rebuyUnlimited = false;
                  } else if (v == 'Limited') {
                    _rebuys = true;
                    _rebuyUnlimited = false;
                  } else {
                    // Unlimited rebuys default to closing at the end of L6.
                    _rebuys = true;
                    _rebuyUnlimited = true;
                    _rebuysClose = 6;
                  }
                  // §6.2: rule edits refresh the suggested presets.
                  _refreshPresetMatches(app);
                }),
                ),
              ],
            ),
          ),
          if (_rebuys) ...[
            // Both limited and unlimited rebuys close at the end of a chosen
            // level (client rule: "if unlimited — until when, end of L6").
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: _SegmentedPicker(
                label: _rebuyUnlimited
                    ? 'Unlimited rebuys until'
                    : 'Close rebuys',
                options: const [
                  'End L4',
                  'End L5',
                  'End L6',
                  'End L7',
                  'End L8',
                ],
                selected: 'End L$_rebuysClose',
                onChanged: (v) => setState(
                  () => _rebuysClose =
                      int.tryParse(v.replaceAll('End L', '')) ?? 6,
                ),
              ),
            ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  top: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max rebuys per player',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: 130,
                      child: AppTextField(
                        controller: _rebuyLimit,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rebuy price',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 130,
                    child: AppTextField(
                      controller: _rebuyCost,
                      keyboardType: TextInputType.number,
                      placeholder: 'Default (${_buyIn.text})',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Unlimited rebuys per player until they close.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(color: AppColors.border),
          _ToggleRow(
            title: 'Re-entry',
            subtitle:
                'Separate option — buy a new entry stack after elimination',
            value: _reEntry,
            onChanged: (v) => setState(() => _reEntry = v),
          ),
          if (_reEntry)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                'Closes with late registration and rebuys.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add-on',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'One per active player at rebuy close',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _SegmentedPicker(
                  options: const ['Yes', 'No'],
                  selected: _addOn ? 'Yes' : 'No',
                  onChanged: (v) => setState(() => _addOn = v == 'Yes'),
                ),
              ],
            ),
          ),
          if (_addOn)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add-on price',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 130,
                    child: AppTextField(
                      controller: _addOnCost,
                      keyboardType: TextInputType.number,
                      placeholder: 'Default (${_buyIn.text})',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add-on matches the starting stack.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SegmentedPicker(
                    label: 'Add-on available until',
                    options: const [
                      'End L4',
                      'End L5',
                      'End L6',
                      'End L7',
                      'End L8',
                    ],
                    selected: 'End L$_addOnClose',
                    onChanged: (v) => setState(
                      () => _addOnClose =
                          int.tryParse(v.replaceAll('End L', '')) ?? 6,
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KO bounty',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Side payment for eliminating a player',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _SegmentedPicker(
                  options: const ['Yes', 'No'],
                  selected: _koEnabled ? 'Yes' : 'No',
                  onChanged: (v) => setState(() => _koEnabled = v == 'Yes'),
                ),
              ],
            ),
          ),
          if (_koEnabled)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bounty amount',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 130,
                    child: AppTextField(
                      controller: _koAmount,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Shown as "${_buyIn.text} + ${_koAmount.text}". Bounty does not enter prize pool.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ante',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose how the ante is posted',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Recommended',
                            active: _antePreference == AntePreference.recommend,
                            onTap: () => setState(
                              () => _antePreference = AntePreference.recommend,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ModeButton(
                            label: 'No ante',
                            active: _antePreference == AntePreference.none,
                            onTap: () => setState(
                              () => _antePreference = AntePreference.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Big blind',
                            active: _antePreference == AntePreference.bigBlind,
                            onTap: () => setState(
                              () => _antePreference = AntePreference.bigBlind,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ModeButton(
                            label: 'Individual',
                            active:
                                _antePreference == AntePreference.individual,
                            onTap: () => setState(
                              () => _antePreference = AntePreference.individual,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  switch (_antePreference) {
                    AntePreference.recommend =>
                      'One ante per table equal to the big blind, starting at a fixed level. Recommended.',
                    AntePreference.none => 'No antes during the tournament.',
                    AntePreference.bigBlind =>
                      'One ante per table, equal to the big blind.',
                    AntePreference.individual =>
                      'Every player posts an ante (half the big blind) each hand.',
                  },
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (_antePreference != AntePreference.none) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SegmentedPicker(
                    label: 'Activate ante',
                    options: const [
                      'After L4',
                      'After L5',
                      'After L6',
                      'After L7',
                      'After L8',
                    ],
                    selected: 'After L$_anteAfterLevel',
                    onChanged: (v) => setState(
                      () => _anteAfterLevel =
                          int.tryParse(v.replaceAll('After L', '')) ?? 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: AppColors.border),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organizational costs',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Percentage for equipment, drinks & snacks. Admin only — never shown to players.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 130,
                child: AppTextField(
                  controller: _orgPctController,
                  keyboardType: TextInputType.number,
                  label: 'Percentage (%)',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Private — the prize pool keeps the remaining percentage of gross.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.casino_outlined,
            size: AppFontSizes.display,
            color: AppColors.icon,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ready to create',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xl,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_name.text.trim()} · ${_date.text} at ${_time.text}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // No "expected players" card — the field size comes from RSVPs
          // (Going + Going +N), never from an input (client rule).
          Row(
            children: [
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: _durationLabel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.attach_money,
                  label: 'Buy-in',
                  value: _buyIn.text,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.groups_outlined,
                  label: 'Players',
                  value: 'from RSVPs',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              AppBadge(
                label: _rebuys
                    ? (_rebuyUnlimited
                          ? 'Unlimited rebuys to L$_rebuysClose'
                          : '${_rebuyLimit.text.trim().isNotEmpty ? _rebuyLimit.text : '1'} rebuys to L$_rebuysClose${_rebuyCost.text.trim().isNotEmpty ? ' @ ${_rebuyCost.text}' : ''}')
                    : 'No rebuys',
                variant: _rebuys ? AppBadgeVariant.gold : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: _reEntry ? 'Re-entry' : 'No re-entry',
                variant: _reEntry
                    ? AppBadgeVariant.gold
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: _addOn ? 'Add-on to L$_addOnClose' : 'No add-on',
                variant: _addOn ? AppBadgeVariant.gold : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: _antePreference == AntePreference.none
                    ? 'No ante'
                    : 'Ante L$_anteAfterLevel (${_antePreference == AntePreference.individual ? 'Ind' : 'BB'})',
                variant: _antePreference != AntePreference.none
                    ? AppBadgeVariant.gold
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label:
                    'Chips: ${_chipMode == _ChipMode.preset ? _presetName : 'Custom'}',
                variant: AppBadgeVariant.default_,
              ),
              if (_locationPrivate)
                const AppBadge(
                  label: 'Private Address',
                  variant: AppBadgeVariant.accent,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'The event is posted to the group for RSVPs. Poker Night will estimate stacks, '
            'blinds and levels 30 minutes before start, based on who answered Going / Going +N. '
            'You can still change every setting after publishing.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => _generate(app),
            child: const AppIconLabel(
              label: 'Create event',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Review / confirm dialog
// =============================================================================

class _ConfirmItem {
  const _ConfirmItem(this.label, this.value);
  final String label;
  final String value;
}

/// Centered, width-capped review dialog with a sticky header + footer and a
/// single scrollable body.
///
/// Uses [Dialog] rather than [AlertDialog] so the width is driven purely by our
/// own constraints — `AlertDialog` + `width: double.maxFinite` was what pushed
/// the old dialog off-centre on desktop.
class _ConfirmDetailsDialog extends StatelessWidget {
  const _ConfirmDetailsDialog({
    required this.gameRows,
    required this.ruleRows,
    required this.chipSet,
    required this.chipSetName,
    this.anchorRect,
  });

  final List<_ConfirmItem> gameRows;
  final List<_ConfirmItem> ruleRows;
  final List<ChipColor> chipSet;
  final String chipSetName;

  /// Global rect of the page content. When supplied the dialog centres over
  /// this rect rather than the whole window, so a persistent sidebar doesn't
  /// make it look off-centre.
  final Rect? anchorRect;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool isCompact = screen.width < 480;

    final double gap = isCompact ? AppSpacing.lg : AppSpacing.xxl;

    // Asymmetric insets shift the dialog to the centre of the content area.
    EdgeInsets inset = EdgeInsets.symmetric(
      horizontal: gap,
      vertical: AppSpacing.xxl,
    );

    final Rect? a = anchorRect;
    if (!isCompact && a != null && a.width > 360) {
      final double left = a.left + gap;
      final double right = (screen.width - a.right) + gap;
      // Only apply if it still leaves a usable width.
      if (screen.width - left - right >= 360) {
        inset = EdgeInsets.only(
          left: left,
          right: right,
          top: AppSpacing.xxl,
          bottom: AppSpacing.xxl,
        );
      }
    }

    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      insetPadding: inset,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          // Grows with the window instead of a hard 600.
          maxHeight: screen.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // lets the dialog hug its content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Divider(height: 1, color: AppColors.border),

            // Scrollable body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('Game'),
                    const SizedBox(height: AppSpacing.sm),
                    _Panel(
                      children: [
                        for (int i = 0; i < gameRows.length; i++)
                          _ConfirmRow(
                            item: gameRows[i],
                            last: i == gameRows.length - 1,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    const _SectionLabel('Rules'),
                    const SizedBox(height: AppSpacing.sm),
                    _Panel(
                      children: [
                        for (int i = 0; i < ruleRows.length; i++)
                          _ConfirmRow(
                            item: ruleRows[i],
                            last: i == ruleRows.length - 1,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      children: [
                        const _SectionLabel('Chip set'),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            '· $chipSetName',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [for (final c in chipSet) _ChipPill(chip: c)],
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: AppColors.border),
            _footer(context, isCompact),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review game details',
                  style: AppTypography.display(
                    size: AppFontSizes.lg,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check everything before the structure is generated.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(false),
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, bool isCompact) {
    final Widget back = AppButton(
      variant: AppButtonVariant.secondary,
      fullWidth: isCompact,
      onPressed: () => Navigator.of(context).pop(false),
      child: const Text('Back to edit'),
    );

    final Widget confirm = AppButton(
      fullWidth: isCompact,
      onPressed: () => Navigator.of(context).pop(true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 15, color: AppColors.icon),
          SizedBox(width: 6),
          Text('Confirm & generate'),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      // Stack on phones so nothing is ever clipped.
      child: isCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                confirm,
                const SizedBox(height: AppSpacing.sm),
                back,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                back,
                const SizedBox(width: AppSpacing.sm),
                confirm,
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.bodyXs.copyWith(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Label left, value hard-right — reads as a spec sheet instead of two ragged
/// columns.
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.item, this.last = false});

  final _ConfirmItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: AppColors.border, width: 0.6),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              item.value.isEmpty ? '—' : item.value,
              textAlign: TextAlign.right,
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.chip});

  final ChipColor chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: chip.colorValue,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.foreground.withValues(alpha: 0.22)),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${chip.value}',
            style: AppTypography.monoXs.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text(
            '×${chip.quantity}',
            style: AppTypography.monoXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: active ? AppColors.primary : AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ExactInput extends StatelessWidget {
  const _ExactInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 56,
          child: TextField(
            controller: TextEditingController(text: value),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: AppTypography.bodySm,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
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
        ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.display(
              size: AppFontSizes.md,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget picker = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < options.length; i++) ...[
          GestureDetector(
            onTap: () => onChanged(options[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: options[i] == selected
                    ? AppColors.primary
                    : AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                options[i],
                style: AppTypography.bodyXs.copyWith(
                  color: options[i] == selected
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          picker,
        ],
      );
    }

    return picker;
  }
}
