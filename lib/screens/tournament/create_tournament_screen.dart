import 'package:flutter/material.dart';
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
import '../../utils/event_settings_validation.dart';
import '../../utils/sanitization.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/event_settings_form.dart';
import '../../widgets/squircle_icon_button.dart';

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

/// 5-step tournament creation wizard mirroring the web `CreateTournamentPage`.
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
    'Rebuys & add-ons',
    'Format',
    'Review & create',
  ];

  int _step = 1;

  /// Working draft of the whole event. The shared [EventSettingsForm] owns the
  /// field widgets; it seeds itself once from [_draft] and reports every edit
  /// back through its `onChanged`, so [_draft] (never the widget tree) is the
  /// single source of truth for validation, presets, the review step and
  /// `_generate`.
  late GameSettings _draft;

  /// Bumped whenever the mounted form must be re-seeded from [_draft] — the
  /// group-derived player count landing after load, or a preset applied.
  int _seedTick = 0;

  /// Key for the shared form on every step. A change remounts it fresh from
  /// [_draft]; while unchanged, edits stay live and are never clobbered.
  Key get _formKey =>
      ValueKey('wizard-form-$_seedTick-${_appliedPresetId ?? 'none'}');

  /// Latest validation misses, keyed by field (name/date/time/location/buyIn/
  /// rebuyLimit/koAmount). The shared form renders the same errors inline
  /// against the matching field; this map only gates advancing.
  final Map<String, String> _errors = {};

  /// The head-count derived from the group + RSVP signals, kept for the
  /// step-1 estimate caption ("from your group") and the reset-to-RSVP path.
  int _derivedExpectedPlayers = 2;

  // Expected players — the estimate the host can override. RSVPs stay the real
  // source: an untouched stepper keeps tracking them (override stays null),
  // and `_generate` only writes the edited number once the host moves it.
  bool get _expectedOverridden => _draft.expectedPlayersOverride != null;
  int get _expectedPlayers => _draft.expectedPlayersOverride ?? _draft.players;
  bool get _breaksOn => _draft.breaks.isNotEmpty;

  // Preset support (checklist §9.1). Tech spec §6.2: before starting from
  // zero, saved presets close to the current base inputs are suggested.
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

  String get _durationLabel {
    final h = _draft.durationHours;
    return '${h == h.roundToDouble() ? h.round() : h}h';
  }

  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _buyInController;
  late TextEditingController _playersController;

  String _formatDisplayDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? 'Fri, Mar 14' : iso;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _formatDisplayTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 20;
      final m = int.tryParse(parts[1]) ?? 0;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:${m.toString().padLeft(2, '0')} $ampm';
    }
    return timeStr.isEmpty ? '8:00 PM' : timeStr;
  }

  void _syncControllers() {
    if (_nameController.text != _draft.name) _nameController.text = _draft.name;
    if (_locationController.text != _draft.location) {
      _locationController.text = _draft.location;
    }
    final buyInStr = _draft.buyIn > 0 ? '${_draft.buyIn}' : '';
    if (_buyInController.text != buyInStr) _buyInController.text = buyInStr;
    final playersStr = '$_expectedPlayers';
    if (_playersController.text != playersStr) {
      _playersController.text = playersStr;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _buyInController.dispose();
    _playersController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final group = app.currentGroup;

    final presetName = TournamentEngine.presetNames.isNotEmpty
        ? TournamentEngine.presetNames[2]
        : TournamentEngine.presetNames.firstOrNull ?? '';
    _draft = _initialDraft(presetName, expectedPlayers: 2);
    _nameController = TextEditingController(text: _draft.name);
    _locationController = TextEditingController(text: _draft.location);
    _buyInController = TextEditingController(
      text: _draft.buyIn > 0 ? '${_draft.buyIn}' : '',
    );
    _playersController = TextEditingController(text: '$_expectedPlayers');

    final defaultChipSetId = group.defaultChipSetId ?? app.defaultChipSetId;
    if (defaultChipSetId != null) {
      final saved = app.savedChipSets
          .cast<({String id, String name, List<ChipColor> chips})?>()
          .firstWhere((cs) => cs?.id == defaultChipSetId, orElse: () => null);
      if (saved != null) {
        _draft = _draft.copyWith(chipSetName: saved.name, chipSet: saved.chips);
      }
    }

    // Auto-fill players from group + apply preset / suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

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

      _derivedExpectedPlayers = expected < 2 ? 2 : expected;
      if (!_expectedOverridden) {
        setState(() {
          _draft = _draft.copyWith(players: _derivedExpectedPlayers);
          _seedTick++;
        });
      }

      if (widget.presetId != null) {
        final preset = app.presetById(widget.presetId);
        if (preset != null) {
          setState(() => _applyPreset(preset));
          return;
        }
      }

      _refreshPresetMatches(app);
    });
  }

  /// The wizard's opening draft. Numeric fields the host is expected to fill
  /// (buy-in) start invalid so the shared validator flags them until entered.
  GameSettings _initialDraft(
    String chipSetName, {
    required int expectedPlayers,
  }) {
    return GameSettings(
      name: '',
      date: _todayIso,
      time: '20:00',
      location: '',
      players: expectedPlayers,
      durationHours: 3.5, // Spec §4.3: default target duration is 3.5 hours.
      buyIn: 0,
      koEnabled: false,
      koAmount: 5,
      rebuys: true,
      rebuysCloseLevel: 6,
      rebuyLimit: null, // null = unlimited (see GameSettings.rebuyLimit).
      reEntry: true,
      addOn: true,
      addOnCloseLevel: 6,
      anteEnabled: false,
      anteAfterLevel: 6,
      anteStyle: AnteStyle.individual,
      antePreference: AntePreference.none,
      organizerPct: 10,
      chipSet: List.of(TournamentEngine.getPreset(chipSetName)),
      chipSetName: chipSetName,
      locationPrivate: false,
      breaks: const [],
    );
  }

  /// Any shared-form edit lands here: the draft is updated (the form keeps its
  /// own field state, so nothing needs re-seeding) and the §6.2 preset
  /// suggestions are recomputed from the new base inputs.
  void _onDraftChanged(GameSettings next) {
    setState(() => _draft = next);
    _syncControllers();
    _refreshPresetMatches(context.read<AppProvider>());
  }

  /// Tech spec §6.2 — recomputes which of the administrator's saved presets
  /// sit close enough (score >= [_presetMatchMinScore]) to the current base
  /// inputs to be suggested, keeping the two best scores. Runs on wizard load
  /// and on every base-input edit; the guard stops it for good once a preset
  /// was explicitly picked ([_appliedPresetId]), the section was dismissed,
  /// or the review step was reached.
  void _refreshPresetMatches(AppProvider app) {
    if (_appliedPresetId != null || _suggestionsDismissed || _reachedReview) {
      _presetMatches.clear();
      setState(() {});
      return;
    }
    final s = _draft;
    final chipSetName = TournamentEngine.presetNames.contains(s.chipSetName)
        ? s.chipSetName
        : '';
    final scored =
        <({TournamentPreset preset, double score, List<String> diffs})>[];
    for (final p in app.presets) {
      final match = _matchPreset(
        p,
        buyIn: s.buyIn,
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        durationHours: s.durationHours,
        expectedPlayers: s.expectedPlayersOverride ?? s.players,
        rebuys: s.rebuys,
        rebuysCloseLevel: s.rebuysCloseLevel,
        addOn: s.addOn,
        chipSetName: chipSetName,
        chipColorCount: s.chipSet.length,
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

  /// Fills the wizard draft from a saved preset (09-006). Date/time/location,
  /// the RSVP-derived player figure and any expected-player override are kept
  /// — presets store none of those. Changing [_appliedPresetId] remounts the
  /// mounted step's shared form so it re-seeds from the updated draft.
  void _applyPreset(TournamentPreset p) {
    _draft = _draft.copyWith(
      name: p.name,
      buyIn: p.buyIn,
      durationHours: p.durationHours,
      rebuys: p.rebuys,
      rebuysCloseLevel: p.rebuysCloseLevel,
      rebuyLimit: p.rebuyLimit,
      rebuyCost: p.rebuyCost,
      reEntry: p.reEntry,
      addOn: p.addOn,
      addOnCloseLevel: p.addOnCloseLevel,
      breaks: List.of(p.breaks),
      addOnCost: p.addOnCost,
      koEnabled: p.koEnabled,
      koAmount: p.koAmount,
      antePreference: p.anteEnabled
          ? AntePreference.bigBlind
          : AntePreference.none,
      anteEnabled: p.anteEnabled,
      anteAfterLevel: p.anteAfterLevel,
      anteStyle: p.anteEnabled ? AnteStyle.bigBlind : AnteStyle.individual,
      organizerPct: p.organizerPct.clamp(0, GameSettings.maxOrganizerPct),
      chipSet: List.of(p.chipSet),
      chipSetName: p.chipSetName,
    );
    _appliedPresetId = p.id;
  }

  void _next() {
    // Only the steps whose fields carry validation keys gate on the shared
    // validator. Chips (step 2) and Format (step 4) have no keys of their own.
    const stepKeys = <int, Set<String>>{
      1: {'name', 'date', 'time', 'location', 'buyIn'},
      3: {'rebuyLimit', 'koAmount'},
    };
    final keys = stepKeys[_step] ?? const <String>{};
    final hit = keys.isEmpty
        ? const <String, String>{}
        : {
            for (final e in validateEventSettings(_draft).entries)
              if (keys.contains(e.key)) e.key: e.value,
          };
    setState(() {
      _errors
        ..clear()
        ..addAll(hit);
      if (hit.isEmpty) {
        _step++;
        if (_step >= _steps.length) {
          // Tech spec §6.2 guard: reaching the review step stops suggesting,
          // even when the admin goes back to edit afterwards.
          _reachedReview = true;
          _presetMatches.clear();
        }
      }
    });
  }

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
    final s = _draft;
    final Rect? anchor = _contentRect;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => _ConfirmDetailsDialog(
        anchorRect: anchor,
        gameRows: <_ConfirmItem>[
          _ConfirmItem('Name', s.name.trim()),
          _ConfirmItem('When', '${s.date} at ${s.time}'),
          if (s.location.trim().isNotEmpty)
            _ConfirmItem(
              'Where',
              s.location.trim() + (s.locationPrivate ? '  (private)' : ''),
            ),
          // The count the host is planning for is an estimate on top of the
          // Going / Going +N RSVPs (Tech 6.1); RSVPs remain the real source.
          _ConfirmItem(
            'Players',
            _expectedOverridden
                ? '$_expectedPlayers (your override)'
                : 'From RSVPs',
          ),
          _ConfirmItem('Buy-in', '${s.buyIn}'),
          _ConfirmItem('Duration', _durationLabel),
        ],
        ruleRows: <_ConfirmItem>[
          _ConfirmItem(
            'Rebuys & re-entry',
            s.rebuys
                ? (s.rebuyLimit == null
                      ? 'Unlimited to L${s.rebuysCloseLevel}'
                      : 'Limited to L${s.rebuysCloseLevel}')
                : 'Off',
          ),
          _ConfirmItem(
            'Add-on',
            s.addOn ? 'Yes, to L${s.addOnCloseLevel}' : 'No',
          ),
          _ConfirmItem(
            'Breaks',
            _breaksOn
                ? '${s.breaks.length} x ${s.breaks.first.durationMins} min'
                : 'None',
          ),
          _ConfirmItem('Bounty', s.koEnabled ? 'Yes (${s.koAmount})' : 'No'),
          _ConfirmItem(
            'Ante',
            s.antePreference == AntePreference.none
                ? 'No'
                : 'From L${s.anteAfterLevel}',
          ),
          _ConfirmItem('Organizational costs', '${s.organizerPct}%'),
        ],
        chipSet: s.chipSet,
        chipSetName: s.chipSetName,
      ),
    );
  }

  void _generate(AppProvider app) async {
    final s = _draft;
    if (s.chipSet.isEmpty) {
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

    final values = s.chipSet.map((c) => c.value).toList();
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

    // Persist a custom chip set once so it can be reused next time. A set that
    // still matches a named preset is not custom.
    if (!TournamentEngine.presetNames.contains(s.chipSetName)) {
      final customName = '${s.name.trim()} set';
      app.saveChipSet(
        'cs-${s.name.trim().replaceAll(' ', '-').toLowerCase()}',
        customName,
        s.chipSet,
      );
    }

    // Client flow: the event is created and published straight away so the
    // group can RSVP. The structure is NOT generated here — it is generated
    // by the Admin during check-in from confirmed actual attendance.
    final game = app.createGame(
      GameSettings(
        name: Sanitization.sanitizeTournamentName(s.name.trim()),
        date: s.date.trim(),
        time: s.time.trim(),
        location: Sanitization.sanitizeLocation(s.location.trim()),
        // Roster size — the working head-count still comes from RSVPs and
        // check-in; `expectedPlayersOverride` below is what lets the host say
        // "plan for more than replied" (Tech 6.1).
        players: app.currentGroup.members.length,
        expectedPlayersOverride: s.expectedPlayersOverride,
        durationHours: s.durationHours,
        buyIn: s.buyIn,
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        rebuys: s.rebuys,
        rebuysCloseLevel: s.rebuysCloseLevel,
        rebuyCloseChosenByOrganizer: s.rebuyCloseChosenByOrganizer,
        rebuyLimit: s.rebuys ? s.rebuyLimit : null,
        rebuyCost: s.rebuyCost,
        reEntry: s.reEntry,
        addOn: s.addOn,
        addOnCloseLevel: s.addOnCloseLevel,
        breaks: List.of(s.breaks),
        addOnCost: s.addOnCost,
        anteEnabled: s.anteEnabled,
        anteAfterLevel: s.anteAfterLevel,
        anteStyle: s.anteStyle,
        antePreference: s.antePreference,
        organizerPct: s.organizerPct.clamp(0, 100),
        chipSet: s.chipSet,
        chipSetName: s.chipSetName,
        locationPrivate: s.locationPrivate,
        tableSettingsOverride: s.tableSettingsOverride,
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
          // Top App Bar: Squircle back `<` button & `Step X of 5`
          Row(
            children: [
              SquircleIconButton(
                icon: Icons.chevron_left,
                size: 40,
                borderRadius: 12,
                backgroundColor: AppColors.card,
                borderColor: AppColors.borderSubtle,
                onPressed: () => _step == 1
                    ? context.go(RoutePaths.group)
                    : setState(() => _step--),
              ),
              const Spacer(),
              Text(
                'Step $_step of ${_steps.length}',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Red progress indicator bar underneath app bar
          Container(
            height: 2.5,
            width: double.infinity,
            color: AppColors.borderSubtle,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_step / _steps.length.toDouble()).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryHover],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_step == 1 &&
              _presetMatches.isNotEmpty &&
              !_suggestionsDismissed &&
              _appliedPresetId == null) ...[
            _buildSuggestionBanner(),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Steps
          if (_step == 1) _buildStep1(app),
          if (_step == 2) ...[
            _buildStepHeader(2),
            const SizedBox(height: 16),
            _buildStep2(app),
            const SizedBox(height: 24),
            _buildStepChipsRow(),
          ],
          if (_step == 3) ...[
            _buildStepHeader(3),
            const SizedBox(height: 16),
            _buildStep3(app),
            const SizedBox(height: 24),
            _buildStepChipsRow(),
          ],
          if (_step == 4) ...[
            _buildStepHeader(4),
            const SizedBox(height: 16),
            _buildStep4(app),
            const SizedBox(height: 24),
            _buildStepChipsRow(),
          ],
          if (_step == 5) ...[
            _buildStepHeader(5),
            const SizedBox(height: 16),
            _buildStep5(app),
            const SizedBox(height: 24),
            _buildStepChipsRow(),
          ],

          const SizedBox(height: 24),

          // Bottom sticky Continue button
          _buildBottomBar(app),
        ],
      ),
    );
  }

  Widget _buildStepHeader(int stepNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[stepNumber - 1].toUpperCase(),
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _steps[stepNumber - 1],
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.mutedForeground,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.foreground,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          // The container draws the field; without these the theme's
          // outline and fill paint a second box inside it.
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: placeholder,
          hintStyle: TextStyle(color: AppColors.onSurfaceHint),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStepChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            InkWell(
              onTap: () => setState(() => _step = i + 1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: i == _step - 1
                      ? AppColors.primarySoft
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: i == _step - 1
                        ? AppColors.primary
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Text(
                  _steps[i].toUpperCase(),
                  style: TextStyle(
                    color: i == _step - 1
                        ? AppColors.primaryText
                        : AppColors.mutedForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            if (i < _steps.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppProvider app) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: _step < 5 ? _next : () => _generate(app),
          child: Text(
            _step == 5 ? 'Publish event' : 'Continue',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(AppProvider app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Eyebrow
        Text(
          'EVENT DETAILS',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        // Title
        Text(
          'New tournament',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),

        // Event name
        _buildFormFieldLabel('Event name'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _nameController,
          placeholder: 'Friday Night Freezeout',
          onChanged: (val) {
            _onDraftChanged(_draft.copyWith(name: val));
          },
        ),
        const SizedBox(height: 16),

        // Date & Time side-by-side row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Date'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final current =
                          DateTime.tryParse(_draft.date) ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: current,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        final m = picked.month.toString().padLeft(2, '0');
                        final d = picked.day.toString().padLeft(2, '0');
                        _onDraftChanged(
                          _draft.copyWith(date: '${picked.year}-$m-$d'),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        _formatDisplayDate(_draft.date),
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Time'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final parts = _draft.time.split(':');
                      final h = parts.isNotEmpty
                          ? int.tryParse(parts[0]) ?? 20
                          : 20;
                      final m = parts.length > 1
                          ? int.tryParse(parts[1]) ?? 0
                          : 0;
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: h, minute: m),
                      );
                      if (picked != null) {
                        final timeStr =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        _onDraftChanged(_draft.copyWith(time: timeStr));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        _formatDisplayTime(_draft.time),
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Location
        _buildFormFieldLabel('Location'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _locationController,
          placeholder: "Marcus's place",
          onChanged: (val) {
            _onDraftChanged(_draft.copyWith(location: val));
          },
        ),
        const SizedBox(height: 16),

        // Buy-in & Expected players side-by-side row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Buy-in'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Text(
                          r'$',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _buyInController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              // The container draws the field; without these the theme's
                              // outline and fill paint a second box inside it.
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              hintText: '100',
                              hintStyle: TextStyle(color: AppColors.onSurfaceHint),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val) ?? 0;
                              _onDraftChanged(_draft.copyWith(buyIn: parsed));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Expected players'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _playersController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              // The container draws the field; without these the theme's
                              // outline and fill paint a second box inside it.
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final parsed =
                                  int.tryParse(val) ?? _derivedExpectedPlayers;
                              _onDraftChanged(
                                _draft.copyWith(
                                  players: parsed,
                                  expectedPlayersOverride: parsed,
                                ),
                              );
                            },
                          ),
                        ),
                        Text(
                          'from group',
                          style: TextStyle(
                            color: AppColors.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Step chips row
        _buildStepChipsRow(),
      ],
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
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.primarySoft,
              borderColor: AppColors.primary.withValues(alpha: 0.4),
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
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _matchLabel(m.score),
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
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
      child: EventSettingsForm(
        key: _formKey,
        initial: _draft,
        sections: const {EventFormSection.chips},
        onChanged: _onDraftChanged,
      ),
    );
  }

  Widget _buildStep3(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: EventSettingsForm(
        key: _formKey,
        initial: _draft,
        // Rebuys & add-ons only (D1): the fine-grained rebuys section owns
        // the rebuys/re-entry/limit/close and add-on decisions; the money
        // section carries their prices. Format decisions (KO, ante, breaks)
        // live on the Format step, so nothing here is shown twice.
        sections: const {EventFormSection.rebuys, EventFormSection.money},
        onChanged: _onDraftChanged,
      ),
    );
  }

  Widget _buildStep4(AppProvider app) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: EventSettingsForm(
        key: _formKey,
        initial: _draft,
        // Format only (D1): KO bounty, ante, breaks and the seating override.
        // Rebuys/add-ons fields have their own step (EventFormSection.rebuys),
        // so this step renders none of them.
        sections: const {EventFormSection.format},
        onChanged: _onDraftChanged,
      ),
    );
  }

  Widget _buildStep5(AppProvider app) {
    final s = _draft;
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
            '${s.name.trim()} · ${s.date} at ${s.time}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The head-count card reflects the host's step-1 estimate when one
          // is set; otherwise the real source (RSVPs) is quoted.
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
                  value: '${s.buyIn}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.groups_outlined,
                  label: 'Players',
                  value: _expectedOverridden
                      ? '$_expectedPlayers'
                      : 'from RSVPs',
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
                label: s.rebuys
                    ? (s.rebuyLimit == null
                          ? 'Unlimited rebuys to L${s.rebuysCloseLevel}'
                          : '${s.rebuyLimit} rebuys to L${s.rebuysCloseLevel}${s.rebuyCost != null ? ' @ ${s.rebuyCost}' : ''}')
                    : 'No rebuys',
                variant: s.rebuys
                    ? AppBadgeVariant.gold
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.reEntry ? 'Re-entry' : 'No re-entry',
                variant: s.reEntry
                    ? AppBadgeVariant.gold
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.addOn
                    ? 'Add-on to L${s.addOnCloseLevel}'
                    : 'No add-on',
                variant: s.addOn ? AppBadgeVariant.gold : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.antePreference == AntePreference.none
                    ? 'No ante'
                    : 'Ante L${s.anteAfterLevel} (${s.antePreference == AntePreference.individual ? 'Ind' : 'BB'})',
                variant: s.antePreference != AntePreference.none
                    ? AppBadgeVariant.gold
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: 'Chips: ${s.chipSetName}',
                variant: AppBadgeVariant.default_,
              ),
              if (s.locationPrivate)
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
                      children: [
                        for (final c in chipSet)
                          ChipPill(
                            colorName: c.color,
                            hex: c.colorValue,
                            value: c.value,
                            count: c.quantity,
                          ),
                      ],
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
                const SizedBox(height: AppSpacing.xxs),
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
            icon: Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: AppColors.background,
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
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      color: AppColors.background,
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
          const SizedBox(height: AppSpacing.xxs),
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
