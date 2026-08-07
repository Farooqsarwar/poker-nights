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
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/chip_loading_animation.dart';
import '../../widgets/chip_token.dart';

enum _ChipMode { preset, quick, exact }

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
  static const _steps = ['Game info', 'Chip set', 'Rules', 'Generate'];

  int _step = 1;

  // Step 1
  final _name = TextEditingController();
  final _date = TextEditingController(text: _todayIso);
  final _time = TextEditingController(text: '20:00');
  final _location = TextEditingController();
  final _players = TextEditingController();
  final _buyIn = TextEditingController();
  bool _locationPrivate = false;
  double _duration = 3.5;
  final Map<String, String> _errors = {};

  // Step 2
  _ChipMode _chipMode = _ChipMode.preset;
  String _presetName = '';
  late List<ChipColor> _chipSet;

  // Step 3
  bool _rebuys = true;
  int _rebuysClose = 6;
  final _rebuyCost = TextEditingController();
  bool _reEntry = true;
  bool _addOn = true;
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
  double _orgPct = 10;

  // Preset support (checklist §9.1)
  List<TournamentPreset> _suggestions = const [];
  bool _suggestionsDismissed = false;
  String? _appliedPresetId;

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
        if (poll.question.toLowerCase().contains('going') || poll.question.toLowerCase().contains('play')) {
          int yesVotes = poll.votes.values.where((v) => 
            v.toLowerCase() == 'yes' || v.toLowerCase() == 'going' || v.toLowerCase() == 'in'
          ).length;
          if (yesVotes > 0) {
            expected = yesVotes;
            break;
          }
        }
      }
      setState(() {
        _players.text = expected.toString();
      });

      if (widget.presetId != null) {
        final preset = app.presetById(widget.presetId);
        if (preset != null) {
          setState(() => _applyPreset(preset));
          return;
        }
      }

      setState(() {
        _suggestions = _matchSuggestions(app, expected);
      });
    });
  }

  /// Scores presets against signals parsed from closed polls (buy-in, duration,
  /// etc.) so the wizard can suggest a match (09-007 / 09-008).
  List<TournamentPreset> _matchSuggestions(AppProvider app, int expected) {
    final signals = <num>[];
    for (final poll in app.currentGroup.polls) {
      if (!poll.closed) continue;
      for (final opt in poll.options) {
        final cleaned = opt.trim().replaceAll(RegExp(r'[hH]$'), '').trim();
        final n = num.tryParse(cleaned);
        if (n != null && n > 0) signals.add(n);
      }
    }
    return app.suggestPresets(expectedPlayers: expected, pollSignals: signals);
  }

  /// Fills every field of the wizard from a saved preset (09-006).
  void _applyPreset(TournamentPreset p) {
    _name.text = p.name;
    _buyIn.text = p.buyIn.toString();
    _duration = p.durationHours;
    _rebuys = p.rebuys;
    _rebuysClose = p.rebuysCloseLevel;
    _rebuyCost.text = p.rebuyCost?.toString() ?? '';
    _reEntry = p.reEntry;
    _addOn = p.addOn;
    _addOnCost.text = p.addOnCost?.toString() ?? '';
    _koEnabled = p.koEnabled;
    _koAmount.text = p.koAmount.toString();
    _antePreference = p.anteEnabled ? AntePreference.bigBlind : AntePreference.none;
    _anteAfterLevel = p.anteAfterLevel;
    _orgPct = p.organizerPct.toDouble();
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
      _players,
      _buyIn,
      _koAmount,
      _rebuyCost,
      _addOnCost,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validateStep1() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors['name'] = 'Required';
    if (_date.text.trim().isEmpty) _errors['date'] = 'Required';
    final p = int.tryParse(_players.text) ?? 0;
    if (p < 2) _errors['players'] = 'Min 2 players';
    final b = num.tryParse(_buyIn.text) ?? 0;
    if (b <= 0) _errors['buyIn'] = 'Must be positive';
    setState(() {});
    return _errors.isEmpty;
  }

  void _next() {
    if (_step == 1 && !_validateStep1()) return;
    setState(() => _step++);
  }

  void _generate(AppProvider app) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ChipLoadingAnimation(),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).pop();

    final game = app.createGame(GameSettings(
      name: _name.text.trim(),
      date: _date.text.trim(),
      time: _time.text.trim(),
      location: _location.text.trim(),
      players: int.tryParse(_players.text) ?? 8,
      durationHours: _duration,
      buyIn: num.tryParse(_buyIn.text)?.toInt() ?? 15,
      koEnabled: _koEnabled,
      koAmount: num.tryParse(_koAmount.text)?.toInt() ?? 5,
      rebuys: _rebuys,
      rebuysCloseLevel: _rebuysClose,
      rebuyCost: num.tryParse(_rebuyCost.text)?.toInt(),
      reEntry: _reEntry,
      addOn: _addOn,
      addOnCost: num.tryParse(_addOnCost.text)?.toInt(),
      anteEnabled: _anteEnabled,
      anteAfterLevel: _anteAfterLevel,
      anteStyle: _anteStyle,
      antePreference: _antePreference,
      organizerPct: _orgPct.round(),
      chipSet: _chipSet,
      chipSetName: _chipMode == _ChipMode.preset ? _presetName : 'Custom',
      locationPrivate: _locationPrivate,
    ));
    app.setCurrentGame(game);
    context.go(RoutePaths.structureReview);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              InkWell(
                onTap: () => _step == 1 ? context.go(RoutePaths.group) : setState(() => _step--),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(Icons.arrow_back, size: AppFontSizes.xl, color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Tournament', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    Text(
                      'Step $_step of ${_steps.length}: ${_steps[_step - 1]}',
                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
          if (_step == 1 && _suggestions.isNotEmpty &&
              !_suggestionsDismissed && _appliedPresetId == null) ...[
            _buildSuggestionBanner(app),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Steps
          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
          if (_step == 3) _buildStep3(),
          if (_step == 4) _buildStep4(app),
          const SizedBox(height: AppSpacing.lg),
          // Nav buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: () => _step == 1 ? context.go(RoutePaths.group) : setState(() => _step--),
                child: _step == 1
                    ? const Text('Cancel')
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, size: 14, color: AppColors.icon),
                          SizedBox(width: 6),
                          Text('Back'),
                        ],
                      ),
              ),
              if (_step < 4)
                AppButton(
                  onPressed: _next,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next'),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
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
                child: AppTextField(
                  controller: _time,
                  label: 'Start time',
                ),
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
              subtitle: 'Guests see the address only after check-in (11-014/11-015)',
              value: _locationPrivate,
              onChanged: (v) => setState(() => _locationPrivate = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberField(
                  controller: _players,
                  label: 'Expected players',
                  error: _errors['players'],
                  onChanged: (_) {
                    final app = context.read<AppProvider>();
                    setState(() {
                      _suggestions = _matchSuggestions(
                        app,
                        int.tryParse(_players.text) ?? 0,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _buyIn,
                      label: 'Buy-in amount',
                      error: _errors['buyIn'],
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No currency symbol in game UI',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSelect(
            label: 'Target duration',
            value: _duration.toString(),
            onChanged: (v) => setState(() => _duration = double.tryParse(v ?? '') ?? 3.5),
            items: [
              for (final d in [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0])
                DropdownMenuItem(
                  value: d.toString(),
                  child: Text(
                    d == 3.5 ? '3.5 hours (recommended)' : '${d == d.roundToDouble() ? d.round() : d} hours',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Suggestion banner shown before starting from scratch (09-007). When two
  /// presets match, both are offered so the admin can choose (09-008), or
  /// ignore them and start from zero (09-009).
  Widget _buildSuggestionBanner(AppProvider app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Matching preset${_suggestions.length > 1 ? 's' : ''} from your poll results',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _suggestionsDismissed = true),
              child: Text(
                'Ignore',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Buy-in ${p.buyIn} · ${p.durationHours}h · '
                          '${p.rebuys ? 'Rebuys to L${p.rebuysCloseLevel}' : 'No rebuys'} · '
                          '${p.anteEnabled ? 'Ante L${p.anteAfterLevel}+' : 'No ante'}',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    size: AppButtonSize.sm,
                    onPressed: () {
                      setState(() => _applyPreset(p));
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

  Widget _buildStep2() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final m in _ChipMode.values) ...[
                Expanded(
                  child: _ModeButton(
                    label: switch (m) {
                      _ChipMode.preset => 'Saved preset',
                      _ChipMode.quick => 'Quick setup',
                      _ChipMode.exact => 'Exact count',
                    },
                    active: _chipMode == m,
                    onTap: () => setState(() => _chipMode = m),
                  ),
                ),
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
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _chipSet.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ChipToken(colorName: _chipSet[i].color, hex: _chipSet[i].colorValue, value: _chipSet[i].value),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Rank ${i + 1}', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
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
                      icon: const Icon(Icons.arrow_upward, size: 14, color: AppColors.mutedForeground),
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
                      icon: const Icon(Icons.arrow_downward, size: 14, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              'Enter exact chip counts and values.',
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _chipSet.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ChipToken(colorName: _chipSet[i].color, hex: _chipSet[i].colorValue, value: _chipSet[i].value),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(_chipSet[i].color, style: AppTypography.bodyXs),
                    ),
                    _ExactInput(
                      label: 'Value',
                      value: '${_chipSet[i].value}',
                      onChanged: (v) => setState(() {
                        _chipSet[i] = _chipSet[i].copyWith(value: int.tryParse(v) ?? 1);
                      }),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ExactInput(
                      label: '×',
                      value: '${_chipSet[i].quantity}',
                      onChanged: (v) => setState(() {
                        _chipSet[i] = _chipSet[i].copyWith(quantity: int.tryParse(v) ?? 0);
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToggleRow(
            title: 'Rebuys',
            subtitle: 'Players can re-enter after elimination',
            value: _rebuys,
            onChanged: (v) => setState(() => _rebuys = v),
          ),
          if (_rebuys) ...[
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
              child: AppSelect(
                label: 'Close rebuys',
                value: '$_rebuysClose',
                onChanged: (v) => setState(() => _rebuysClose = int.tryParse(v ?? '') ?? 6),
                items: [
                  for (var n = 4; n <= 8; n++)
                    DropdownMenuItem(value: '$n', child: Text('End of Level $n')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rebuy price', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
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
                    'Unlimited rebuys per player until they close (09-050).',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
          const Divider(color: AppColors.border),
          _ToggleRow(
            title: 'Re-entry',
            subtitle: 'Separate option — buy a new entry stack after elimination',
            value: _reEntry,
            onChanged: (v) => setState(() => _reEntry = v),
          ),
          if (_reEntry)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.sm, bottom: AppSpacing.sm),
              child: Text(
                'Closes with late registration and rebuys.',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          const Divider(color: AppColors.border),
          _ToggleRow(
            title: 'Add-on',
            subtitle: 'One per active player at rebuy close',
            value: _addOn,
            onChanged: (v) => setState(() => _addOn = v),
          ),
          if (_addOn)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add-on price', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
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
                    'Add-on matches the starting stack (12-060).',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.border),
          _ToggleRow(
            title: 'KO bounty',
            subtitle: 'Side payment for eliminating a player',
            value: _koEnabled,
            onChanged: (v) => setState(() => _koEnabled = v),
          ),
          if (_koEnabled)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bounty amount', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
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
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ante', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Choose how the ante is posted (09-010)', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final pref in AntePreference.values) ...[
                      Expanded(
                        child: _ModeButton(
                          label: switch (pref) {
                            AntePreference.recommend => 'Recommended',
                            AntePreference.none => 'No ante',
                            AntePreference.bigBlind => 'Big blind',
                            AntePreference.individual => 'Individual',
                          },
                          active: _antePreference == pref,
                          onTap: () => setState(() => _antePreference = pref),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  switch (_antePreference) {
                    AntePreference.recommend =>
                      'One ante per table equal to the big blind, starting at a fixed level. Recommended.',
                    AntePreference.none => 'No antes during the tournament.',
                    AntePreference.bigBlind => 'One ante per table, equal to the big blind.',
                    AntePreference.individual => 'Every player posts an ante (half the big blind) each hand.',
                  },
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
                if (_antePreference != AntePreference.none) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppSelect(
                    label: 'Activate ante',
                    value: '$_anteAfterLevel',
                    onChanged: (v) => setState(() => _anteAfterLevel = int.tryParse(v ?? '') ?? 6),
                    items: [
                      for (var n = 4; n <= 8; n++)
                        DropdownMenuItem(value: '$n', child: Text('After Level $n')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Organiser percentage', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _orgPct,
                      min: 0,
                      max: 20,
                      divisions: 20,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.border,
                      onChanged: (v) => setState(() => _orgPct = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${_orgPct.round()}%',
                      textAlign: TextAlign.right,
                      style: AppTypography.mono(size: AppFontSizes.sm, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              Text(
                'Private — only you see this amount. The prize pool is ${100 - _orgPct.round()}% of gross.',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
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
          const Icon(Icons.casino_outlined, size: AppFontSizes.display, color: AppColors.icon),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ready to generate',
            textAlign: TextAlign.center,
            style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${_name.text.trim()} · ${_date.text} at ${_time.text}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          Text(
            '${_players.text} players · ${_duration == _duration.roundToDouble() ? _duration.round() : _duration}h · Buy-in ${_buyIn.text}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          Text(
            '${_rebuys ? 'Rebuys until Level $_rebuysClose${_rebuyCost.text.trim().isNotEmpty ? ' @ ${_rebuyCost.text}' : ''}' : 'No rebuys'} ·'
            '${_reEntry ? ' Re-entry enabled' : ' No re-entry'} ·'
            '${_addOn ? ' Add-on enabled' : ' No add-on'} ·'
            '${_antePreference == AntePreference.none ? ' No ante' : ' Ante after Level $_anteAfterLevel (${_anteStyle == AnteStyle.individual ? 'individual' : 'big blind'})'}'
            '${_locationPrivate ? ' · Private address' : ''}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          Text(
            'Chip set: ${_chipMode == _ChipMode.preset ? _presetName : 'Custom'}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Poker Night will calculate starting stack, blind levels, chip composition and prize distribution. You can review and edit before confirming.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => _generate(app),
            child: const Text('Generate structure'),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label, this.error, this.onChanged});

  final TextEditingController controller;
  final String label;
  final String? error;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          error: error,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.active, required this.onTap});

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
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: active ? AppColors.primary : AppColors.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

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
                Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
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
  const _ExactInput({required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.ring),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
