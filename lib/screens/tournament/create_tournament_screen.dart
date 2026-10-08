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
import '../../models/tournament_format.dart';
import '../../providers/app_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/event_settings_validation.dart';
import '../../utils/sanitization.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/event_settings_form.dart';
import '../../widgets/pace_cards.dart';
import '../../widgets/structure_feasibility_card.dart';
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
  const CreateTournamentScreen({
    super.key,
    this.presetId,
    this.repostGameId,
  });

  /// Optional `?preset=` query param: pre-fills the form from a saved
  /// tournament preset (checklist 09-006).
  final String? presetId;

  /// Optional `?repost=` query param: pre-fills the form from a previous
  /// completed game, shifted one week later.
  final String? repostGameId;

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

  /// Loading state while publishing the tournament
  bool _isPublishing = false;

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

      // §E17 row 9: rebuy-rate learning pre-fills the expected take-up from the
      // last eight completed nights, while the add-on take-up path already
      // reuses the same calibration flow. Keep it local and transparent so the
      // host can still override the suggestion before publishing.
      final rebuyForecast = app.forecastRebuyRate.clamp(0.0, 1.0);
      final addOnForecast = app.forecastAddOnTakeUp.clamp(0.0, 1.0);
      final forecastPlayers = _derivedExpectedPlayers.clamp(2, 2000);
      setState(() {
        _draft = _draft.copyWith(
          expectedRebuys: _draft.expectedRebuys ??
              (forecastPlayers * rebuyForecast).round(),
          expectedAddOns: _draft.expectedAddOns ??
              (forecastPlayers * addOnForecast).round(),
        );
        _seedTick++;
      });

      final repostGame = widget.repostGameId == null
          ? null
          : app.currentGroup.games
              .where((g) => g.id == widget.repostGameId)
              .firstOrNull;
      if (repostGame != null) {
        final nextDate = (repostGame.settings.scheduledStart ?? DateTime.now())
            .add(const Duration(days: 7));
        final next = _draft.copyWith(
          name: repostGame.settings.name,
          date: '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}',
          time: repostGame.settings.time,
          location: repostGame.settings.location,
          buyIn: repostGame.settings.buyIn,
          durationHours: repostGame.settings.durationHours,
          koEnabled: repostGame.settings.koEnabled,
          koAmount: repostGame.settings.koAmount,
          rebuys: repostGame.settings.rebuys,
          rebuysCloseLevel: repostGame.settings.rebuysCloseLevel,
          rebuyLimit: repostGame.settings.rebuyLimit,
          reEntry: repostGame.settings.reEntry,
          addOn: repostGame.settings.addOn,
          addOnCloseLevel: repostGame.settings.addOnCloseLevel,
          anteEnabled: repostGame.settings.anteEnabled,
          anteAfterLevel: repostGame.settings.anteAfterLevel,
          organizerPct: repostGame.settings.organizerPct,
          chipSet: List.of(repostGame.settings.chipSet),
          chipSetName: repostGame.settings.chipSetName,
          breaks: List.of(repostGame.settings.breaks),
          rsvpDeadlineHours: repostGame.settings.rsvpDeadlineHours,
          pace: repostGame.settings.pace,
          expectedPlayersOverride: null,
          clearExpectedPlayersOverride: true,
        );
        setState(() {
          _draft = _withBountyInDomain(next);
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
    final now = DateTime.now();
    var time = '20:00';
    final todayStart = DateTime(now.year, now.month, now.day, 20, 0);
    if (!now.isBefore(todayStart)) {
      final next = now.add(const Duration(hours: 1));
      time =
          '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    }
    return GameSettings(
      name: '',
      date: _todayIso,
      time: time,
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
      anteEnabled: true,
      anteAfterLevel: 6,
      anteStyle: AnteStyle.bigBlind,
      antePreference: AntePreference.recommend,
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
    setState(() => _draft = _withBountyInDomain(next));
    _syncControllers();
    _refreshPresetMatches(context.read<AppProvider>());
  }

  /// Forces the KO bounty amount back into the spec's 5–50 step-5 domain.
  ///
  /// The step-1 stepper is the only control that edits it now — the free-text
  /// "Bounty amount" that used to sit on step 3 is gone, because the spec puts
  /// the bounty on step 1 only. So an out-of-domain value can only arrive with
  /// a preset or a repost, and it has to be corrected where it enters the
  /// draft rather than left for a validation gate: the wizard's `_errors` map
  /// gates advancing but is never rendered on step 1, so a gate on `koAmount`
  /// would block the host on a message they cannot see. Clamping here means
  /// the value on screen is always one the stepper can show and the spec allows.
  GameSettings _withBountyInDomain(GameSettings s) {
    final clamped =
        s.koAmount.clamp(GameSettings.minBounty, GameSettings.maxBounty);
    final stepped = ((clamped / GameSettings.bountyStep).round() *
            GameSettings.bountyStep)
        .clamp(GameSettings.minBounty, GameSettings.maxBounty);
    if (stepped == s.koAmount) return s;
    return s.copyWith(koAmount: stepped);
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
    setState(() {
      _draft = _withBountyInDomain(
        _draft.copyWith(
          name: p.name,
          buyIn: p.buyIn,
          durationHours: p.durationHours,
          rebuys: p.rebuys,
          rebuysCloseLevel: p.rebuysCloseLevel,
          rebuyCloseChosenByOrganizer: p.rebuyCloseChosenByOrganizer,
          rebuyLimit: p.rebuyLimit,
          rebuyCost: p.rebuyCost,
          reEntry: p.reEntry,
          addOn: p.addOn,
          addOnOvertime: p.addOnOvertime,
          addOnCloseLevel: p.addOnCloseLevel,
          breaks: List.of(p.breaks),
          addOnCost: p.addOnCost,
          koEnabled: p.koEnabled,
          koAmount: p.koAmount,
          koKind: p.koKind,
          antePreference: p.antePreference,
          anteEnabled: p.anteEnabled,
          anteAfterLevel: p.anteAfterLevel,
          anteStyle: p.anteStyle,
          organizerPct: p.organizerPct.clamp(0, GameSettings.maxOrganizerPct),
          chipSet: List.of(p.chipSet),
          chipSetName: p.chipSetName,
          format: p.format,
          maxReEntries: p.maxReEntries,
          earlyArrivalBonusEnabled: p.earlyArrivalBonusEnabled,
          earlyArrivalCutoffMins: p.earlyArrivalCutoffMins,
          earlyArrivalBonusPctOverride: p.earlyArrivalBonusPctOverride,
          rsvpDeadlineHours: p.rsvpDeadlineHours,
          hardFinishEnabled: p.hardFinishEnabled,
          hardFinishMinsAfterFinish: p.hardFinishMinsAfterFinish,
          hardFinishSplit: p.hardFinishSplit,
          levelDurationMins: p.levelDurationMins,
          pace: p.pace,
          shootoutTables: p.shootoutTables,
          shootoutTableTargetMins: p.shootoutTableTargetMins,
          announceEliminations: p.announceEliminations,
          locationPrivate: p.locationPrivate,
          forcePaidPlaces: p.forcePaidPlaces,
          rebuyChips: p.rebuyChips,
          reEntryChips: p.reEntryChips,
          addOnChips: p.addOnChips,
          tableSettingsOverride: p.tableSettingsOverride,
          lockedExpectedPlayers: p.lockedExpectedPlayers,
          expectedRebuys: p.expectedRebuys,
          expectedReEntries: p.expectedReEntries,
          expectedAddOns: p.expectedAddOns,
          forecastRebuyRate: p.forecastRebuyRate,
          forecastAddOnTakeUp: p.forecastAddOnTakeUp,
        ),
      );
      _syncControllers();
      _seedTick++;
    });
    _appliedPresetId = p.id;
  }

  void _next() {
    // Only the steps whose fields carry validation keys gate on the shared
    // validator. Chips (step 2) and Format (step 4) have no keys of their own.
    const stepKeys = <int, Set<String>>{
      1: {'name', 'date', 'time', 'location', 'buyIn'},
      3: {'rebuyLimit', 'maxReEntries', 'koAmount', 'orgPct'},
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
          _ConfirmItem(
            'Bounty',
            s.koEnabled
                ? 'Yes, ${s.koKind.label} (${s.koAmount})'
                : 'No',
          ),
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
    final errs = validateEventSettings(s);
    if (errs.isNotEmpty) {
      final stepFor = {
        'name': 1,
        'date': 1,
        'time': 1,
        'location': 1,
        'buyIn': 1,
        'rebuyLimit': 3,
        'maxReEntries': 3,
        'koAmount': 1,
        'orgPct': 4,
      };
      final first = errs.keys.first;
      setState(() {
        _errors
          ..clear()
          ..addAll(errs);
        _step = stepFor[first] ?? _step;
      });
      await showAppModal(
        context: context,
        title: 'Check the details',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              errs.values.first,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fix details'),
            ),
          ],
        ),
      );
      return;
    }
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

    setState(() => _isPublishing = true);

    try {
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
    // Carry the full draft (not a field subset) so format/forecasts/chips/
    // bonus/hard-finish choices survive publish.
    final game = app.createGame(
      s.copyWith(
        name: Sanitization.sanitizeTournamentName(s.name.trim()),
        location: Sanitization.sanitizeLocation(s.location.trim()),
        // Roster size — the working head-count still comes from RSVPs and
        // check-in; `expectedPlayersOverride` below is what lets the host say
        // "plan for more than replied" (Tech 6.1).
        players: _expectedPlayers,
        rebuyLimit: s.rebuys ? s.rebuyLimit : null,
        organizerPct: s.organizerPct.clamp(0, GameSettings.maxOrganizerPct),
      ),
    );
    app.setCurrentGame(game);
    app.publishGame();

    if (!mounted) return;
    context.go(RoutePaths.invitation);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
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
                onPressed: () {
                  if (_step == 1) {
                    // Detect if we're editing an existing tournament (via /t/:id/configure)
                    // vs creating new (via /create-tournament or /t/new).
                    // The matched route path tells us which flow we're in.
                    final matchedPath =
                        GoRouterState.of(context).matchedLocation;
                    final isEditing = matchedPath.contains('/configure');
                    context.go(
                        isEditing ? RoutePaths.hostDashboard : RoutePaths.group);
                  } else {
                    setState(() => _step--);
                  }
                },
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

  Widget _fieldError(String key) {
    final msg = _errors[key];
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        msg,
        style: TextStyle(
          color: AppColors.destructiveText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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
              onTap: () {
                final target = i + 1;
                if (target <= _step) {
                  setState(() => _step = target);
                } else {
                  _next();
                }
              },
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

  /// Single publish gate shared by the bottom bar and the review card:
  /// blocked while publishing, on validation errors, or when the chip case
  /// cannot build the stack. Null structure (engine exception) also blocks.
  bool get _canPublish {
    if (_isPublishing) return false;
    if (validateEventSettings(_draft).isNotEmpty) return false;
    final structure = _draftStructure(_draft);
    if (structure == null || structure.feasible == false) return false;
    return true;
  }

  Widget _buildBottomBar(AppProvider app) {
    final isLastStep = _step == 5;
    final isLoading = isLastStep && _isPublishing;

    // §F1.5 point 7: "**Create** stays disabled until the stack is playable."
    // Only the chip-case failure blocks — a structure that merely runs past
    // its finish time is a warning the host is allowed to accept, and the
    // feasibility card says so on the same screen.
    final blocked = isLastStep && !_canPublish;

    return AppButton(
      size: AppButtonSize.lg,
      fullWidth: true,
      onPressed: isLoading || blocked
          ? null
          : (isLastStep ? () => _generate(app) : _next),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.foreground,
                ),
              ),
            )
          : Text(
              isLastStep ? 'Publish event' : 'Continue',
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
        _fieldError('name'),
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
                        firstDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _fieldError('date')),
            const SizedBox(width: 12),
            Expanded(child: _fieldError('time')),
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
        _fieldError('location'),
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
                  _fieldError('buyIn'),
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
                  const SizedBox(height: 6),
                  Text(
                    _expectedPlayers <= 9
                        ? '1 table (1–9 players · standard hosting)'
                        : '${(_expectedPlayers / 9).ceil()} tables needed (multi-table)',
                    style: TextStyle(
                      color: _expectedPlayers > 9 &&
                              app.premiumTier != PremiumTier.premium
                          ? AppColors.primaryText
                          : AppColors.mutedForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Group members: unlimited on all plans. Tournament capacity: 1 table (up to 9 players) is Free; 2+ tables is Premium.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 18),

        if (_expectedPlayers > 9) ...[
          if (app.premiumTier != PremiumTier.premium)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primarySoftBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppTag('PREMIUM', tone: AppTagTone.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Two or more tables',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$_expectedPlayers going and your tables seat 9, so this night needs a second table — that is Premium. Free hosting covers one table up to 9 players.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppButton(
                        size: AppButtonSize.sm,
                        onPressed: () => context.push(RoutePaths.upgrade),
                        child: const Text('See Premium'),
                      ),
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          final currentGroup = app.currentGroup;
                          app.updateGroupTableSettings(
                            currentGroup.tableSettings.copyWith(
                              maxPerTable: 10,
                            ),
                          );
                          app.updateTournamentTableSettings(
                            app.effectiveTableSettings.copyWith(
                              maxPerTable: 10,
                            ),
                          );
                        },
                        child: const Text('Seat 10 at one table instead (free)'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primarySoftBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: AppColors.successText,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Table Tournament Active',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$_expectedPlayers players across ${(_expectedPlayers / 9).ceil()} tables with automated TDA balancing & redraws.',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const AppTag('UNLOCKED', tone: AppTagTone.success),
                ],
              ),
            ),
        ],

        // KO bounty — the spec's Step-1 field (§C1 step 1, T37/T38/T64).
        _buildKoBountySection(app),
        const SizedBox(height: 24),

        // Step chips row
        _buildStepChipsRow(),
      ],
    );
  }

  /// §C1 step 1 — KO bounty: a toggle, and only then the amount and the type.
  ///
  /// Rendered unconditionally, including for a night with no prize pool. The
  /// bounty pot is collected on top of the buy-in and funds nothing but
  /// knockouts (§F2.4), so "Payouts: None" is precisely the night a KO bounty
  /// is still worth turning on — hiding it there would remove the only payout
  /// the table has.
  Widget _buildKoBountySection(AppProvider app) {
    final s = _draft;
    // The stepper is the screen's authority on the 5–50 domain, so the figure
    // it shows and the figure the caption quotes are the same number. A draft
    // can still hold something outside the domain (a preset or a repost of an
    // older game carries one), and quoting that raw here would put a bounty the
    // spec does not allow on the screen. `_withBountyInDomain` has already
    // clamped it where it entered the draft; the clamp below is the belt to
    // that braces, and the first nudge writes the value back either way.
    final bounty = s.effectiveKoAmount.clamp(
      GameSettings.minBounty,
      GameSettings.maxBounty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('KO bounty'),
                  const SizedBox(height: 2),
                  Text(
                    'On top of the buy-in, a separate pot',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppToggle(
              value: s.koEnabled,
              onChanged: (v) => _onDraftChanged(_draft.copyWith(koEnabled: v)),
            ),
          ],
        ),
        if (!s.koEnabled) const SizedBox.shrink() else ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormFieldLabel('Bounty amount'),
                    const SizedBox(height: 2),
                    Text(
                      'Shown as "${s.buyIn} + $bounty"',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CountStepper(
                value: bounty,
                min: GameSettings.minBounty,
                max: GameSettings.maxBounty,
                step: GameSettings.bountyStep,
                semanticLabel: 'Bounty amount',
                onChanged: (v) => _onDraftChanged(_draft.copyWith(koAmount: v)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFormFieldLabel('Bounty type'),
          const SizedBox(height: AppSpacing.xs),
          for (final kind in BountyKind.values) ...[
            _BountyKindOption(
              kind: kind,
              selected: s.koKind == kind,
              onTap: () => _chooseBountyKind(app, kind),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ],
    );
  }

  /// §C1 step 1 / G1: a Premium kind is not selected by tapping it on the free
  /// tier — the tap opens the upgrade screen, exactly as every other
  /// Premium-only control in the app does.
  void _chooseBountyKind(AppProvider app, BountyKind kind) {
    if (kind.isPremium && app.premiumTier != PremiumTier.premium) {
      context.push(RoutePaths.upgrade);
      return;
    }
    _onDraftChanged(_draft.copyWith(koKind: kind));
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
        // section carries their prices. The KO bounty is a step-1 control and
        // ante/breaks are format decisions, so nothing here is shown twice.
        sections: const {EventFormSection.rebuys, EventFormSection.money},
        onChanged: _onDraftChanged,
      ),
    );
  }

  /// §F1.3 `paceOptions`, memoised.
  ///
  /// It runs the whole structure engine three times, so it must not be
  /// recomputed on every rebuild — a step with a text field in it rebuilds on
  /// each keystroke. The key covers exactly the inputs that change the answer;
  /// anything else on the draft (the name, the location) cannot.
  PaceOptions? _paceOptionsCache;
  String? _paceOptionsKey;

  PaceOptions _paceOptionsFor(GameSettings s) {
    final key = [
      s.expectedPlayersOverride ?? s.players,
      s.durationHours,
      s.chipSet.map((c) => '${c.value}x${c.quantity}').join(','),
      s.rebuys,
      s.reEntry,
      s.addOn,
      s.anteEnabled,
      s.rebuysCloseLevel,
      s.breaks.fold<int>(0, (a, b) => a + b.durationMins),
    ].join('|');
    if (_paceOptionsKey == key && _paceOptionsCache != null) {
      return _paceOptionsCache!;
    }
    final players = s.expectedPlayersOverride ?? s.players;
    final opts = TournamentEngine.paceOptions(
      TournamentParams(
        players: players < 2 ? 2 : players,
        durationHours: s.durationHours,
        buyIn: s.buyIn,
        chipSet: s.chipSet,
        rebuys: s.rebuys,
        rebuysCloseLevel: s.rebuysCloseLevel,
        rebuyLimit: s.rebuyLimit,
        reEntry: s.reEntry,
        addOn: s.addOn,
        anteEnabled: s.anteEnabled,
        anteAfterLevel: s.anteAfterLevel,
        anteStyle: s.anteStyle,
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        organizerPct: s.organizerPct.clamp(0, GameSettings.maxOrganizerPct),
        rebuyCost: s.rebuyCost,
        addOnCost: s.addOnCost,
        breaks: List.of(s.breaks),
        format: s.format,
      ),
    );
    _paceOptionsKey = key;
    _paceOptionsCache = opts;
    return opts;
  }

  Widget _buildStep4(AppProvider app) {
    final paceOptions = _paceOptionsFor(_draft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // §F1.3 / C1 step 4. The pace decides the level length AND the growth
        // the ladder is solved against, so it sits above the format details
        // rather than among them: it is the choice that shapes the night.
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pace',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'One level length all night. The blinds climb at whatever '
                'rate reaches the finish on time.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PaceCards(
                options: paceOptions,
                selected: _draft.pace,
                onSelected: (p) => _onDraftChanged(_draft.copyWith(pace: p)),
                // §F1.3's `later`: the finish time lives on step 1, so this
                // takes the host back to it rather than guessing a new one.
                onChooseLater: () => setState(() => _step = 1),
                onDropAddOn: _draft.addOn
                    ? () => _onDraftChanged(_draft.copyWith(addOn: false))
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              // ── §D6 EARLY-ARRIVAL BONUS ──
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Early arrival bonus',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Extra starting chips for players checked in and approved before the scheduled start (opens 10 min before)',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                value: _draft.earlyArrivalBonusEnabled,
                onChanged: (v) => _onDraftChanged(
                  _draft.copyWith(earlyArrivalBonusEnabled: v),
                ),
              ),
              if (_draft.earlyArrivalBonusEnabled) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'Bonus chips:',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    DropdownButton<double>(
                      value: _draft.earlyArrivalBonusPctOverride ?? 0.125,
                      dropdownColor: AppColors.card,
                      items: const [
                        DropdownMenuItem(value: 0.025, child: Text('+2.5%')),
                        DropdownMenuItem(value: 0.05, child: Text('+5%')),
                        DropdownMenuItem(value: 0.075, child: Text('+7.5%')),
                        DropdownMenuItem(value: 0.10, child: Text('+10%')),
                        DropdownMenuItem(value: 0.125, child: Text('+12.5% (default)')),
                        DropdownMenuItem(value: 0.15, child: Text('+15%')),
                        DropdownMenuItem(value: 0.175, child: Text('+17.5%')),
                        DropdownMenuItem(value: 0.20, child: Text('+20%')),
                        DropdownMenuItem(value: 0.225, child: Text('+22.5%')),
                        DropdownMenuItem(value: 0.25, child: Text('+25%')),
                      ],
                      onChanged: (pct) {
                        if (pct != null) {
                          _onDraftChanged(
                            _draft.copyWith(earlyArrivalBonusPctOverride: pct),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              // ── §F4 / C-cfg §7 HARD FINISH ──
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Hard finish',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Fixed time ceiling agreed before posting. Splits prizes if reached.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                value: _draft.hardFinishEnabled,
                onChanged: (v) => _onDraftChanged(
                  _draft.copyWith(hardFinishEnabled: v),
                ),
              ),
              if (_draft.hardFinishEnabled) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'Latest finish:',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    DropdownButton<int>(
                      value: _draft.hardFinishMinsAfterFinish,
                      dropdownColor: AppColors.card,
                      items: const [
                        DropdownMenuItem(value: 45, child: Text('+45 min')),
                        DropdownMenuItem(value: 60, child: Text('+1 hour (default)')),
                        DropdownMenuItem(value: 90, child: Text('+1.5 hours')),
                        DropdownMenuItem(value: 120, child: Text('+2 hours')),
                        DropdownMenuItem(value: 180, child: Text('+3 hours')),
                      ],
                      onChanged: (mins) {
                        if (mins != null) {
                          _onDraftChanged(
                            _draft.copyWith(hardFinishMinsAfterFinish: mins),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'If still playing:',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    DropdownButton<String>(
                      value: _draft.hardFinishSplit,
                      dropdownColor: AppColors.card,
                      items: const [
                        DropdownMenuItem(value: 'icm', child: Text('Split by ICM')),
                        DropdownMenuItem(value: 'chips', child: Text('Split by chips')),
                      ],
                      onChanged: (split) {
                        if (split != null) {
                          _onDraftChanged(
                            _draft.copyWith(hardFinishSplit: split),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: EventSettingsForm(
            key: _formKey,
            initial: _draft,
            // Format only (D1): ante, breaks and the seating override.
            // Rebuys/add-ons fields have their own step
            // (EventFormSection.rebuys), and the KO bounty is step 1's, so
            // this step renders none of them.
            sections: const {EventFormSection.format},
            onChanged: _onDraftChanged,
          ),
        ),
      ],
    );
  }

  /// The structure the draft would actually produce, memoised on the same key
  /// as [_paceOptionsFor] plus the chosen pace.
  ///
  /// Used to answer one question before the host commits: can this chip case
  /// deal this field a playable stack? §F1.5 point 7 says a structure that
  /// cannot is a blocking condition, not a warning.
  TournamentStructure? _draftStructureCache;
  String? _draftStructureKey;

  TournamentStructure? _draftStructure(GameSettings s) {
    // Memoised for the same reason as the pace options: this runs the whole
    // engine, and the bottom bar rebuilds on every keystroke in the wizard.
    final key = [
      s.expectedPlayersOverride ?? s.players,
      s.durationHours,
      s.chipSet.map((c) => '${c.value}x${c.quantity}').join(','),
      s.rebuys,
      s.reEntry,
      s.addOn,
      s.anteEnabled,
      s.rebuysCloseLevel,
      s.pace?.name,
      s.breaks.fold<int>(0, (a, b) => a + b.durationMins),
    ].join('|');
    if (_draftStructureKey == key) return _draftStructureCache;

    final result = _generateDraftStructure(s);
    _draftStructureKey = key;
    _draftStructureCache = result;
    return result;
  }

  TournamentStructure? _generateDraftStructure(GameSettings s) {
    final players = s.expectedPlayersOverride ?? s.players;
    try {
      return TournamentEngine.generate(
        TournamentParams(
          players: players < 2 ? 2 : players,
          durationHours: s.durationHours,
          buyIn: s.buyIn,
          chipSet: s.chipSet,
          rebuys: s.rebuys,
          rebuysCloseLevel: s.rebuysCloseLevel,
          rebuyLimit: s.rebuyLimit,
          reEntry: s.reEntry,
          addOn: s.addOn,
          anteEnabled: s.anteEnabled,
          anteAfterLevel: s.anteAfterLevel,
          anteStyle: s.anteStyle,
          koEnabled: s.koEnabled,
          koAmount: s.koAmount,
          organizerPct: s.organizerPct.clamp(0, GameSettings.maxOrganizerPct),
          rebuyCost: s.rebuyCost,
          addOnCost: s.addOnCost,
          breaks: List.of(s.breaks),
          format: s.format,
          pace: s.pace,
        ),
      );
    } on Exception {
      // A draft that cannot be generated at all (duplicate chip values, say)
      // is the existing validation's problem, not this card's.
      return null;
    }
  }

  Widget _buildStep5(AppProvider app) {
    final s = _draft;
    final structure = _draftStructure(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // §F1.5 point 7 / §E17 row 88: the blocking card sits ABOVE "Ready to
        // create", because if the chip case cannot deal a playable stack the
        // host is not ready to create.
        if (structure != null) ...[
          StructureFeasibilityCard(
            structure: structure,
            players: s.expectedPlayersOverride ?? s.players,
            onEditChips: () => setState(() => _step = 2),
            onFewerRebuys: () => setState(() => _step = 3),
            onPlayFreezeOut: structure.feasible || !(s.rebuys || s.addOn)
                ? null
                : () => _onDraftChanged(
                      _draft.copyWith(
                        rebuys: false,
                        reEntry: false,
                        addOn: false,
                        format: TournamentFormat.freezeOut,
                      ),
                    ),
          ),
          if (!structure.feasible || !structure.fits)
            const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
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
                    ? AppBadgeVariant.highlight
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.reEntry ? 'Re-entry' : 'No re-entry',
                variant: s.reEntry
                    ? AppBadgeVariant.highlight
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.addOn
                    ? 'Add-on to L${s.addOnCloseLevel}'
                    : 'No add-on',
                variant: s.addOn ? AppBadgeVariant.highlight : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: s.antePreference == AntePreference.none
                    ? 'No ante'
                    : 'Ante L${s.anteAfterLevel} (${s.antePreference == AntePreference.individual ? 'Ind' : 'BB'})',
                variant: s.antePreference != AntePreference.none
                    ? AppBadgeVariant.highlight
                    : AppBadgeVariant.muted,
              ),
              AppBadge(
                label: 'Chips: ${s.chipSetName}',
                variant: AppBadgeVariant.default_,
              ),
              AppBadge(
                label: _expectedPlayers > 9
                    ? '${(_expectedPlayers / 9).ceil()} Tables · ${app.premiumTier == PremiumTier.premium ? "PREMIUM ACTIVE" : "REQUIRES PREMIUM"}'
                    : '1 Table · FREE',
                variant: _expectedPlayers > 9
                    ? (app.premiumTier == PremiumTier.premium
                        ? AppBadgeVariant.highlight
                        : AppBadgeVariant.red)
                    : AppBadgeVariant.default_,
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
            onPressed: _canPublish ? () => _generate(app) : null,
            child: const AppIconLabel(
              label: 'Create event',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
        ),
      ],
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

/// One of the three KO bounty types (§C1 step 1).
///
/// The Premium pair carries the pill at all times rather than only on the free
/// tier: the host has to be able to SEE that a richer bounty exists before
/// deciding whether the night is worth it, which is what makes it a pitch
/// rather than a wall.
class _BountyKindOption extends StatelessWidget {
  const _BountyKindOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final BountyKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  kind.label,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (kind.isPremium)
                const AppTag('PREMIUM', tone: AppTagTone.primary)
              else
                Text(
                  'Free',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
