import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../utils/event_settings_validation.dart';
import 'app_text_field.dart';
import 'app_toggle.dart';
import 'chip_set_editor.dart';
import 'count_stepper.dart';

/// A section of the event settings form. Sections render in the order given
/// in [EventSettingsForm.sections].
enum EventFormSection {
  details,
  chips,
  rules,
  rebuys,
  format,
  money,
}

/// Shared event-settings editor, the union of the creation wizard's step form
/// bodies and the edit form's field set, so one widget (and one validation
/// function) can back every screen that edits a [GameSettings].
///
/// Renders only the requested [EventFormSection]s and reports every change
/// through [EventFormSection.onChanged] as a full [GameSettings] draft built
/// via [GameSettings.copyWith].
class EventSettingsForm extends StatefulWidget {
  const EventSettingsForm({
    super.key,
    required this.initial,
    required this.sections,
    required this.onChanged,
    this.showOrganizerPct = false,
    this.orgPctCeiling = GameSettings.maxOrganizerPct,
  });

  /// The settings this form starts from. Seeded once; later edits are never
  /// re-synced from a new [GameSettings], so callers must not rebuild this
  /// widget with a draft as its own [initial] (the parent owns the draft).
  final GameSettings initial;

  /// Which sections to render, in order of iteration.
  final Set<EventFormSection> sections;

  /// Called with the latest draft on every edit. The draft reflects whatever
  /// the fields currently hold, valid or not — validation (via
  /// [validateEventSettings]) is the parent's call.
  final ValueChanged<GameSettings> onChanged;

  /// Whether to render the organizational-costs (org %) control. The creation
  /// wizard hides it; the edit form shows it.
  final bool showOrganizerPct;

  /// The documented cap on the org percentage. Games created under the old
  /// 0-100 rule may carry a higher stored figure, so the effective ceiling
  /// is raised to whatever [initial] was saved with when that is higher — an
  /// existing figure is never silently rewritten, it can only be reduced.
  final int orgPctCeiling;

  @override
  State<EventSettingsForm> createState() => _EventSettingsFormState();
}

class _EventSettingsFormState extends State<EventSettingsForm> {
  late final TextEditingController _name;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _buyIn;
  late bool _locationPrivate;
  late double _duration;
  late int _expectedPlayers;
  late bool _expectedOverridden;
  late List<ChipColor> _chipSet;
  late String _chipSetName;
  late bool _rebuys;
  late bool _rebuyUnlimited;
  late int _rebuysClose;
  late bool _rebuyCloseChosen;
  late bool _reEntry;
  late bool _addOn;
  late int _addOnClose;
  late bool _koEnabled;
  late final TextEditingController _koAmount;
  late AntePreference _antePreference;
  late int _anteAfterLevel;
  late List<ScheduledBreak> _breaks;
  late bool _overrideTableSettings;
  late int _maxPerTable;
  late bool _randomizeSeating;
  late int _orgPct;
  late final TextEditingController _rebuyLimit;
  late final TextEditingController _rebuyCost;
  late final TextEditingController _addOnCost;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _name = TextEditingController(text: s.name);
    _date = TextEditingController(text: s.date);
    _time = TextEditingController(text: s.time);
    _location = TextEditingController(text: s.location);
    _buyIn = TextEditingController(text: '${s.buyIn}');
    _locationPrivate = s.locationPrivate;
    _duration = s.durationHours;
    _expectedOverridden = s.expectedPlayersOverride != null;
    // Chips plan from the RSVPs unless the host has overridden the figure.
    _expectedPlayers = s.expectedPlayersOverride ?? s.players;
    _chipSet = List.of(s.chipSet);
    _chipSetName = s.chipSetName;
    _rebuys = s.rebuys;
    // `rebuyLimit == null` is how "unlimited" is stored, so it doubles as the
    // unlimited flag — same rule the wizard's Off/Limited/Unlimited uses.
    _rebuyUnlimited = s.rebuyLimit == null;
    _rebuysClose = s.rebuysCloseLevel;
    _rebuyCloseChosen = s.rebuyCloseChosenByOrganizer;
    _reEntry = s.reEntry;
    _addOn = s.addOn;
    _addOnClose = s.addOnCloseLevel;
    _koEnabled = s.koEnabled;
    _koAmount = TextEditingController(text: '${s.koAmount}');
    _antePreference = s.antePreference;
    _anteAfterLevel = s.anteAfterLevel;
    _breaks = List.of(s.breaks);
    _overrideTableSettings = s.tableSettingsOverride != null;
    _maxPerTable = s.tableSettingsOverride?.maxPerTable ?? 9;
    _randomizeSeating = s.tableSettingsOverride?.randomizeByDefault ?? false;
    _orgPct = s.organizerPct;
    // Only shown when rebuys are Limited; defaults to 1 per player.
    _rebuyLimit = TextEditingController(text: s.rebuyLimit?.toString() ?? '1');
    _rebuyCost = TextEditingController(text: s.rebuyCost?.toString() ?? '');
    _addOnCost = TextEditingController(text: s.addOnCost?.toString() ?? '');
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Legit ceiling for the org % stepper: the documented cap, raised to the
  /// stored legacy figure when the game was created under the old 0-100 rule.
  int get _orgPctCeiling => math.max(widget.orgPctCeiling, widget.initial.organizerPct);

  String get _durationLabel {
    final whole = _duration == _duration.roundToDouble();
    return '${whole ? _duration.round() : _duration}h';
  }

  GameSettings get _draft => _buildSettings(strict: false);

  /// Snapshot of the current field state. [strict] parses empty numeric
  /// fields as invalid (0 / -1) so the validator reports them, matching the
  /// wizard's `null -> "Must be ..."` rules, while a lenient draft keeps the
  /// last good value so the parent's draft never spoils over an in-flight key.
  GameSettings _buildSettings({required bool strict}) {
    final s = widget.initial;
    final buyIn = num.tryParse(_buyIn.text.trim());
    final koAmount = num.tryParse(_koAmount.text.trim());
    final rebuyLimit = num.tryParse(_rebuyLimit.text.trim());
    final rebuyCost = num.tryParse(_rebuyCost.text.trim());
    final addOnCost = num.tryParse(_addOnCost.text.trim());
    return s.copyWith(
      name: _name.text.trim(),
      date: _date.text.trim(),
      time: _time.text.trim(),
      location: _location.text.trim(),
      durationHours: _duration,
      buyIn: buyIn?.toInt() ?? (strict ? 0 : s.buyIn),
      locationPrivate: _locationPrivate,
      chipSet: _chipSet,
      chipSetName: _chipSetName,
      expectedPlayersOverride: _expectedOverridden ? _expectedPlayers : null,
      clearExpectedPlayersOverride: !_expectedOverridden,
      rebuys: _rebuys,
      rebuysCloseLevel: _rebuys ? _rebuysClose : 0,
      rebuyCloseChosenByOrganizer: _rebuys ? _rebuyCloseChosen : false,
      reEntry: _reEntry,
      rebuyLimit: _rebuys
          ? (_rebuyUnlimited
              ? null
              : (rebuyLimit?.toInt() ?? (strict ? -1 : 1)))
          : null,
      addOn: _addOn,
      addOnCloseLevel: _addOnClose,
      koEnabled: _koEnabled,
      koAmount: koAmount?.toInt() ?? (strict ? -1 : s.koAmount),
      antePreference: _antePreference,
      anteEnabled: _antePreference != AntePreference.none,
      anteStyle: _antePreference == AntePreference.individual
          ? AnteStyle.individual
          : AnteStyle.bigBlind,
      anteAfterLevel: _anteAfterLevel,
      organizerPct: _orgPct,
      breaks: List.of(_breaks),
      rebuyCost: _rebuys ? rebuyCost?.toInt() : null,
      addOnCost: _addOn ? addOnCost?.toInt() : null,
      tableSettingsOverride: _overrideTableSettings
          ? TableSettings(
              maxPerTable: _maxPerTable,
              randomizeByDefault: _randomizeSeating,
            )
          : null,
      clearTableSettingsOverride: !_overrideTableSettings,
    );
  }

  void _emit() {
    final draft = _draft;
    widget.onChanged(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sections.contains(EventFormSection.details))
          _group('Details', _detailsFields()),
        if (widget.sections.contains(EventFormSection.chips))
          _group('Chips', _chipsFields()),
        if (widget.sections.contains(EventFormSection.rules))
          _group('Rules', _rulesFields()),
        if (widget.sections.contains(EventFormSection.rebuys))
          _group('Rebuys & add-ons', _rebuysFields()),
        if (widget.sections.contains(EventFormSection.format))
          _group('Format', _formatFields()),
        if (widget.sections.contains(EventFormSection.money))
          _group('Money', _moneyFields()),
      ],
    );
  }

  Widget _group(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  // ---- Details ----

  List<Widget> _detailsFields() {
    final errors = validateEventSettings(_buildSettings(strict: true));
    return [
      AppTextField(
        controller: _name,
        label: 'Name',
        placeholder: 'e.g. Friday Poker',
        error: errors['name'],
        onChanged: (_) => _emit(),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: AppTextField(
                  controller: _date,
                  label: 'Date',
                  error: errors['date'],
                  readOnly: true,
                  suffixIcon: IconButton(
                    tooltip: 'Pick a date',
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: _pickDate,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: _pickTime,
              child: AbsorbPointer(
                child: AppTextField(
                  controller: _time,
                  label: 'Start time',
                  error: errors['time'],
                  readOnly: true,
                  suffixIcon: IconButton(
                    tooltip: 'Pick a start time',
                    icon: const Icon(Icons.access_time, size: 18),
                    onPressed: _pickTime,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        controller: _location,
        label: 'Location (optional)',
        placeholder: "e.g. Daniel's place",
        error: errors['location'],
        onChanged: (_) => _emit(),
      ),
      if (_location.text.trim().isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        _ToggleRow(
          title: 'Keep address private',
          subtitle: 'Guests see the address only after check-in',
          value: _locationPrivate,
          onChanged: (v) {
            setState(() => _locationPrivate = v);
            _emit();
          },
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        controller: _buyIn,
        label: 'Buy-in amount',
        error: errors['buyIn'],
        keyboardType: TextInputType.number,
        onChanged: (_) => _emit(),
      ),
      const SizedBox(height: AppSpacing.lg),
      _EditRow(
        title: 'Expected players',
        subtitle: _expectedOverridden
            ? 'Your override — chips and blinds are planned for this many'
            : 'From RSVPs. Adjust if you expect more.',
        trailing: CountStepper(
          value: _expectedPlayers,
          min: 2,
          max: 200,
          semanticLabel: 'Expected players',
          onChanged: (v) {
            setState(() {
              _expectedPlayers = v;
              _expectedOverridden = true;
            });
            _emit();
          },
        ),
      ),
      if (_expectedOverridden)
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => setState(() {
              _expectedOverridden = false;
              _expectedPlayers = widget.initial.players;
            }),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Text(
                'Follow RSVPs instead',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      _OptionPicker(
        label: 'Target duration',
        options: const ['3h', '3.5h', '4h', '4.5h', '5h', '5.5h', '6h'],
        selected: _durationLabel,
        onChanged: (v) {
          final val = v.replaceAll('h', '');
          setState(() => _duration = double.tryParse(val) ?? widget.initial.durationHours);
          _emit();
        },
      ),
    ];
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(_date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      final y = picked.year;
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() => _date.text = '$y-$m-$d');
      _emit();
    }
  }

  TimeOfDay get _startTime {
    final parts = _time.text.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return const TimeOfDay(hour: 20, minute: 0);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => _time.text = '$h:$m');
      _emit();
    }
  }

  // ---- Chips ----

  List<Widget> _chipsFields() {
    return [
      ChipSetEditor(
        initial: _chipSet,
        initialName: _chipSetName,
        onChanged: (chips, name) {
          setState(() {
            _chipSet = chips;
            _chipSetName = name;
          });
          _emit();
        },
      ),
    ];
  }

  // ---- Rules ----

  /// The monolithic rules section: every rebuys/add-ons and format decision on
  /// one scroll (D1's "thirteen decisions on one scroll"). Kept for callers
  /// that want all rules fields behind one section — the invitation edit
  /// modal's four-section mount. Step-based callers (the creation wizard)
  /// should compose [EventFormSection.rebuys] and [EventFormSection.format]
  /// instead so each step owns only its own decisions.
  List<Widget> _rulesFields() {
    return [
      ..._rebuysFields(),
      Divider(color: AppColors.border),
      ..._formatFields(),
    ];
  }

  /// Rebuys & add-ons decisions only — the wizard's "Rebuys & add-ons" step.
  /// Rebuy-pricing errors (`rebuyLimit`) surface here, where the field lives.
  List<Widget> _rebuysFields() {
    final errors = validateEventSettings(_buildSettings(strict: true));
    return [
      _EditRow(
        title: 'Rebuys & re-entry',
        subtitle: 'Players can buy back in after elimination',
        trailing: _OptionPicker(
          options: const ['Off', 'Limited', 'Unlimited'],
          selected: _rebuys
              ? (_rebuyUnlimited ? 'Unlimited' : 'Limited')
              : 'Off',
          onChanged: (v) {
            if (v == 'Off') {
              _rebuys = false;
              _rebuyUnlimited = false;
              // Spec §7/§32 keep rebuy and re-entry one toggle when turning
              // OFF; turning on never re-enables a re-entry a host had off.
              _reEntry = false;
            } else if (v == 'Limited') {
              _rebuys = true;
              _rebuyUnlimited = false;
            } else {
              _rebuys = true;
              _rebuyUnlimited = true;
              _rebuysClose = 6;
            }
            _emit();
          },
        ),
      ),
      if (_rebuys) ...[
        _EditRow(
          title: _rebuyUnlimited ? 'Unlimited rebuys until' : 'Close rebuys',
          subtitle: 'At the end of this level',
          trailing: _OptionPicker(
            options: const ['End L4', 'End L5', 'End L6', 'End L7', 'End L8'],
            selected: 'End L$_rebuysClose',
            onChanged: (v) {
              setState(() {
                _rebuysClose = int.tryParse(v.replaceAll('End L', '')) ?? 6;
                _rebuyCloseChosen = true;
              });
              _emit();
            },
          ),
        ),
        if (!_rebuyUnlimited)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                    error: errors['rebuyLimit'],
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          ),
      ],
      if (_reEntry)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            'Re-entry closes with late registration and rebuys.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      Divider(color: AppColors.border),
      _EditRow(
        title: 'Add-on',
        subtitle: 'One per active player at rebuy close',
        trailing: _OptionPicker(
          options: const ['Yes', 'No'],
          selected: _addOn ? 'Yes' : 'No',
          onChanged: (v) {
            setState(() => _addOn = v == 'Yes');
            _emit();
          },
        ),
      ),
      if (_addOn)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _OptionPicker(
            label: 'Add-on available until',
            options: const ['End L4', 'End L5', 'End L6', 'End L7', 'End L8'],
            selected: 'End L$_addOnClose',
            onChanged: (v) {
              setState(
                () => _addOnClose =
                    int.tryParse(v.replaceAll('End L', '')) ?? 6,
              );
              _emit();
            },
          ),
        ),
    ];
  }

  /// Format decisions only — KO bounty, ante, breaks (and the seating-mode
  /// override the format feeds). The wizard's "Format" step mounts this, so
  /// format fields never repeat on the rebuys step.
  List<Widget> _formatFields() {
    return [
      _EditRow(
        title: 'KO bounty',
        subtitle: 'Side payment for eliminating a player',
        trailing: _OptionPicker(
          options: const ['Yes', 'No'],
          selected: _koEnabled ? 'Yes' : 'No',
          onChanged: (v) {
            setState(() => _koEnabled = v == 'Yes');
            _emit();
          },
        ),
      ),
      Divider(color: AppColors.border),
      _EditRow(
        title: 'Ante',
        subtitle: 'How the ante is posted',
        trailing: _OptionPicker(
          options: const [
            'Recommended',
            'No ante',
            'Big blind',
            'Individual',
          ],
          selected: switch (_antePreference) {
            AntePreference.recommend => 'Recommended',
            AntePreference.none => 'No ante',
            AntePreference.bigBlind => 'Big blind',
            AntePreference.individual => 'Individual',
          },
          onChanged: (v) {
            setState(
              () => _antePreference = switch (v) {
                'No ante' => AntePreference.none,
                'Big blind' => AntePreference.bigBlind,
                'Individual' => AntePreference.individual,
                _ => AntePreference.recommend,
              },
            );
            _emit();
          },
        ),
      ),
      if (_antePreference != AntePreference.none)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: _OptionPicker(
            label: 'Activate ante',
            options: const [
              'After L4',
              'After L5',
              'After L6',
              'After L7',
              'After L8',
            ],
            selected: 'After L$_anteAfterLevel',
            onChanged: (v) {
              setState(
                () => _anteAfterLevel =
                    int.tryParse(v.replaceAll('After L', '')) ?? 6,
              );
              _emit();
            },
          ),
        ),
      Divider(color: AppColors.border),
      _ToggleRow(
        title: 'Override table settings',
        subtitle:
            'Group default: $_maxPerTable per table, randomize '
            '${_randomizeSeating ? 'on' : 'off'}',
        value: _overrideTableSettings,
        onChanged: (v) {
          setState(() => _overrideTableSettings = v);
          _emit();
        },
      ),
      if (_overrideTableSettings) ...[
        _EditRow(
          title: 'Players per table before splitting',
          subtitle: '6 to 12 seats per table',
          trailing: CountStepper(
            value: _maxPerTable,
            min: 6,
            max: 12,
            semanticLabel: 'Players per table',
            onChanged: (v) {
              setState(() => _maxPerTable = v);
              _emit();
            },
          ),
        ),
        _ToggleRow(
          title: 'Randomize seating',
          subtitle: 'Defaults seating generation to fully random',
          value: _randomizeSeating,
          onChanged: (v) {
            setState(() => _randomizeSeating = v);
            _emit();
          },
        ),
      ],
      Divider(color: AppColors.border),
      _group('Breaks', _breaksFields()),
    ];
  }

  List<Widget> _breaksFields() {
    return [
      _EditRow(
        title: 'Breaks',
        subtitle: _breaks.isNotEmpty
            ? 'Break time comes out of your $_durationLabel target, not on top '
                  'of it.'
            : 'Scheduled pauses built into the structure.',
        trailing: _OptionPicker(
          options: const ['Off', '1', '2', '3'],
          selected: _breaks.isNotEmpty ? '${_breaks.length}' : 'Off',
          onChanged: (v) {
            if (v == 'Off') {
              _breaks = const [];
              _emit();
              return;
            }
            final count = int.parse(v);
            final mins = _breaks.isNotEmpty ? _breaks.first.durationMins : 10;
            // afterLevel 0 asks the engine to place it: after the rebuy
            // window, or the midpoint when rebuys are off.
            setState(() {
              _breaks = List.generate(
                count,
                (i) => i < _breaks.length
                    ? _breaks[i]
                    : ScheduledBreak(afterLevel: 0, durationMins: mins),
              );
            });
            _emit();
          },
        ),
      ),
      if (_breaks.isNotEmpty) ...[
        for (var i = 0; i < _breaks.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Break ${i + 1}',
                    style: AppTypography.bodyXs.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        'After level',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      CountStepper(
                        value: _breaks[i].afterLevel,
                        min: 0,
                        max: 30,
                        semanticLabel: 'Break ${i + 1} after level',
                        onChanged: (v) {
                          setState(() {
                            _breaks = [
                              for (var j = 0; j < _breaks.length; j++)
                                j == i
                                    ? _breaks[j].copyWith(afterLevel: v)
                                    : _breaks[j],
                            ];
                          });
                          _emit();
                        },
                      ),
                      if (_breaks[i].afterLevel == 0)
                        Text(
                          'Auto',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        'Minutes',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      _OptionPicker(
                        options: const ['5', '10', '15', '20', 'Custom'],
                        selected: kBreakDurationPresets
                                .contains(_breaks[i].durationMins)
                            ? '${_breaks[i].durationMins}'
                            : 'Custom',
                        onChanged: (v) {
                          if (v == 'Custom') return;
                          final mins = int.parse(v);
                          setState(() {
                            _breaks = [
                              for (var j = 0; j < _breaks.length; j++)
                                j == i
                                    ? _breaks[j].copyWith(durationMins: mins)
                                    : _breaks[j],
                            ];
                          });
                          _emit();
                        },
                      ),
                      SizedBox(
                        width: 120,
                        child: CountStepper(
                          value: _breaks[i].durationMins,
                          min: 1,
                          max: 60,
                          step: 1,
                          semanticLabel: 'Break ${i + 1} minutes',
                          onChanged: (v) {
                            setState(() {
                              _breaks = [
                                for (var j = 0; j < _breaks.length; j++)
                                  j == i
                                      ? _breaks[j]
                                          .copyWith(durationMins: v)
                                      : _breaks[j],
                              ];
                            });
                            _emit();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_breaks.every((b) => b.afterLevel > 0))
          Text(
            'Placed exactly where you have chosen.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          )
        else
          Text(
            _rebuys
                ? 'Anything left on Auto goes after the rebuy window closes '
                      '(around L$_rebuysClose).'
                : 'Anything left on Auto goes around the middle of the '
                      'tournament.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
      ],
    ];
  }

  // ---- Money ----

  List<Widget> _moneyFields() {
    final errors = validateEventSettings(_buildSettings(strict: true));
    final fields = <Widget>[];
    if (_rebuys) {
      fields
        ..add(_EditRow(
          title: 'Rebuy price',
          subtitle: 'Defaults to the buy-in when blank',
          trailing: SizedBox(
            width: 130,
            child: AppTextField(
              controller: _rebuyCost,
              keyboardType: TextInputType.number,
              placeholder: 'Default (${_buyIn.text})',
              onChanged: (_) => _emit(),
            ),
          ),
        ))
        ..add(const SizedBox(height: AppSpacing.md));
    }
    if (_addOn) {
      fields
        ..add(_EditRow(
          title: 'Add-on price',
          subtitle: 'Defaults to the buy-in when blank',
          trailing: SizedBox(
            width: 130,
            child: AppTextField(
              controller: _addOnCost,
              keyboardType: TextInputType.number,
              placeholder: 'Default (${_buyIn.text})',
              onChanged: (_) => _emit(),
            ),
          ),
        ))
        ..add(const SizedBox(height: AppSpacing.md));
    }
    if (_koEnabled) {
      fields
        ..add(_EditRow(
          title: 'Bounty amount',
          subtitle: 'Shown as "${_buyIn.text} + bounty". Bounty does not enter '
              'the prize pool.',
          trailing: SizedBox(
            width: 130,
            child: AppTextField(
              controller: _koAmount,
              keyboardType: TextInputType.number,
              error: errors['koAmount'],
              onChanged: (_) => _emit(),
            ),
          ),
        ))
        ..add(const SizedBox(height: AppSpacing.md));
    }
    if (widget.showOrganizerPct) {
      fields
        ..add(_EditRow(
          title: 'Organizational costs',
          subtitle: 'Percentage retained for equipment, drinks & snacks — '
              'admin only, never shown to players',
          trailing: CountStepper(
            value: _orgPct,
            min: 0,
            max: _orgPctCeiling,
            suffix: '%',
            semanticLabel: 'Organizational costs percentage',
            onChanged: (v) {
              setState(() => _orgPct = v);
              _emit();
            },
          ),
        ))
        ..add(const SizedBox(height: AppSpacing.md));
    }
    return fields;
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
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
                const SizedBox(height: AppSpacing.xxs),
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

class _OptionPicker extends StatelessWidget {
  const _OptionPicker({
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
    Widget picker = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: o == selected
                    ? AppColors.primary
                    : AppColors.secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                o,
                style: AppTypography.bodyXs.copyWith(
                  color: o == selected
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
