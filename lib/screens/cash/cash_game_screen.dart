import 'package:flutter/material.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../widgets/glass_styles.dart';
import '../../models/cash_game.dart';
import '../../models/chip_color.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/mock_data.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/app_back_button.dart';

/// Cash game setup screen strictly matching D1_CashSetup mobile-first design.
///
/// Anyone signed in can run one (D-D: "No host or co-host roles, no group
/// needed"), and a session starts with an empty table: players are added on
/// the live screen with their own buy-in.
class CashGameScreen extends StatefulWidget {
  const CashGameScreen({super.key});

  @override
  State<CashGameScreen> createState() => _CashGameScreenState();
}

class _CashGameScreenState extends State<CashGameScreen> {
  // DECISION: C2/M6 - Stepper ladder from 0.05/0.10 up to 50/100; min buy-in defaults to 100 BB and max to 250 BB.
  static const _blinds = <(String, double, double)>[
    ('0.05 / 0.10', 0.05, 0.10),
    ('0.10 / 0.20', 0.10, 0.20),
    ('0.20 / 0.40', 0.20, 0.40),
    ('0.25 / 0.50', 0.25, 0.50),
    ('0.5 / 1', 0.5, 1),
    ('1 / 2', 1, 2),
    ('2 / 5', 2, 5),
    ('5 / 10', 5, 10),
    ('10 / 20', 10, 20),
    ('15 / 30', 15, 30),
    ('20 / 40', 20, 40),
    ('25 / 50', 25, 50),
    ('50 / 100', 50, 100),
  ];

  final _name = TextEditingController(text: 'Cash game');
  final _buyIn = TextEditingController(text: '200');
  final _minBuyIn = TextEditingController(text: '200');
  final _maxBuyIn = TextEditingController(text: '500');
  final _chipValue = TextEditingController(text: '1');
  final _customSb = TextEditingController(text: '1');
  final _customBb = TextEditingController(text: '2');
  final _whoIsPlaying = TextEditingController();
  bool _setMinMax = false;
  bool _trackSettlement = true;
  String? _selectedChipSetId;

  // Selected preset blind index: 5 is '1 / 2', -1 = custom.
  int _selectedBlindIndex = 5;
  double _sb = 1;
  double _bb = 2;

  // Buy-in bounds follow the stakes (D1: 50 BB and 250 BB) until the host
  // types their own; after that they are left alone.
  bool _buyInsEdited = false;

  @override
  void initState() {
    super.initState();
    _buyIn.addListener(_markEdited);
    _minBuyIn.addListener(_markEdited);
    _maxBuyIn.addListener(_markEdited);
    // Breakdown card reads these controllers — rebuild as the host types.
    _buyIn.addListener(_refreshBreakdown);
    _minBuyIn.addListener(_refreshBreakdown);
    _chipValue.addListener(_refreshBreakdown);
  }

  void _refreshBreakdown() {
    if (mounted) setState(() {});
  }

  bool _settingBuyIns = false;

  void _markEdited() {
    if (!_settingBuyIns) _buyInsEdited = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _buyIn.dispose();
    _minBuyIn.dispose();
    _maxBuyIn.dispose();
    _chipValue.dispose();
    _customSb.dispose();
    _customBb.dispose();
    _whoIsPlaying.dispose();
    super.dispose();
  }
  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _applyBlinds(int index, double sb, double bb, {bool syncControllers = true}) {
    setState(() {
      _selectedBlindIndex = index;
      _sb = sb;
      _bb = bb;
      if (syncControllers) {
        _customSb.text = _num(sb);
        _customBb.text = _num(bb);
      }
      if (!_buyInsEdited) {
        _settingBuyIns = true;
        _buyIn.text = _num(bb * 100);
        _minBuyIn.text = _num(bb * 100);
        _maxBuyIn.text = _num(bb * 250);
        _settingBuyIns = false;
      }
    });
  }

  /// Custom blinds: SB < BB always, in 1-unit steps for integer blinds or 0.05 for micro.
  void _nudgeCustom({double sb = 0, double bb = 0}) {
    var nextSb = _sb + sb;
    var nextBb = _bb + bb;
    if (nextSb < 0.05) nextSb = 0.05;
    if (nextBb <= nextSb) nextBb = nextSb + (nextSb >= 1 ? 1 : 0.05);
    _applyBlinds(-1, nextSb, nextBb);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _start(AppProvider app) {
    final double? minBuy;
    final double? maxBuy;
    if (!_setMinMax) {
      final buy = num.tryParse(_buyIn.text.trim())?.toDouble();
      if (buy == null || buy <= 0) {
        _toast('Enter a buy-in amount.');
        return;
      }
      minBuy = buy;
      maxBuy = buy;
    } else {
      minBuy = num.tryParse(_minBuyIn.text.trim())?.toDouble();
      maxBuy = num.tryParse(_maxBuyIn.text.trim())?.toDouble();
      if (minBuy == null || maxBuy == null || minBuy <= 0) {
        _toast('Enter a min and max buy-in.');
        return;
      }
      if (minBuy >= maxBuy) {
        _toast('Min buy-in must be less than max buy-in.');
        return;
      }
    }
    final chipValue = num.tryParse(_chipValue.text.trim())?.toDouble();

    if (_sb <= 0 || _bb <= 0 || _sb >= _bb) {
      _toast('Small blind must be less than big blind.');
      return;
    }
    if (chipValue == null || chipValue < 0.01) {
      _toast('Chip value must be at least 0.01.');
      return;
    }

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final rawNames = _whoIsPlaying.text.trim();
    final names = rawNames.isEmpty
        ? <String>[]
        : rawNames
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    app.startCashGame(
      CashSessionSettings(
        name: _name.text.trim().isEmpty ? 'Cash game' : _name.text.trim(),
        date: today,
        location: app.hasCurrentGroup ? app.currentGroup.name : 'Home',
        smallBlind: _sb,
        bigBlind: _bb,
        minBuyIn: minBuy,
        maxBuyIn: maxBuy,
        maxPlayers: 10,
        chipValue: chipValue,
        trackSettlement: _trackSettlement,
        chipSetId: _selectedChipSetId ?? app.defaultChipSetId,
      ),
      names,
    );
    if (context.mounted) {
      context.go(RoutePaths.cashGameLive);
    }
  }

  /// Chips of the selected set (standard fallback), sorted big first.
  List<ChipColor> _breakdownChips(AppProvider app) {
    final id = _selectedChipSetId ?? app.defaultChipSetId;
    final set = id == null
        ? null
        : app.savedChipSets.where((c) => c.id == id).firstOrNull;
    final chips = List<ChipColor>.of(
      set?.chips ?? MockData.defaultChipSet,
    )..sort((a, b) => b.value.compareTo(a.value));
    return chips.where((c) => c.value > 0).toList();
  }

  /// Fewest-chip breakdown of one min buy-in, so the host knows what to hand
  /// each player. Rebuilds live as buy-in, chip value or set changes.
  Widget _buildBreakdownCard(AppProvider app) {
    final buyIn =
        num.tryParse(_minBuyIn.text.trim())?.toDouble() ?? 0;
    final unit = num.tryParse(_chipValue.text.trim())?.toDouble() ?? 0;
    final chips = _breakdownChips(app);
    String body;
    if (buyIn <= 0 || unit < 0.01 || chips.isEmpty) {
      body = 'Enter a min buy-in and chip value to see the breakdown.';
    } else {
      var rest = (buyIn / unit).round();
      final parts = <String>[];
      for (final c in chips) {
        final n = rest ~/ c.value;
        if (n > 0) {
          parts.add('$n × ${c.value}');
          rest -= n * c.value;
        }
      }
      body = parts.isEmpty
          ? 'Buy-in is smaller than the smallest chip — lower the chip value.'
          : 'Per min buy-in: ${parts.join(' + ')}'
              '${rest > 0 ? ' (+$rest unit${rest == 1 ? '' : 's'} short — add a smaller chip)' : ''}';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chip breakdown',
            style: AppTypography.bodySm.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  String _chipSetLabel(AppProvider app) {
    final id = _selectedChipSetId ?? app.defaultChipSetId;
    final set = id == null
        ? null
        : app.savedChipSets.where((c) => c.id == id).firstOrNull;
    return set == null
        ? 'Standard set'
        : '${set.name} · ${set.chips.length} colours';
  }

  void _chooseChipSet(BuildContext context, AppProvider app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Chip Set',
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Standard set',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  // DECISION: C1 - Show every chip value and count in the dialog
                  subtitle: Text(
                    MockData.defaultChipSet.map((c) => '${c.value} (${c.quantity})').join(', '),
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  ),
                  trailing: _selectedChipSetId == null
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() => _selectedChipSetId = null);
                    Navigator.of(bottomSheetContext).pop();
                  },
                ),
                for (final set in app.savedChipSets)
                  ListTile(
                    title: Text(
                      set.name,
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    // DECISION: C1 - Show every chip value and count in the dialog
                    subtitle: Text(
                      set.chips.map((c) => '${c.value} (${c.quantity})').join(', '),
                      style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                    ),
                    trailing: _selectedChipSetId == set.id
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      setState(() => _selectedChipSetId = set.id);
                      Navigator.of(bottomSheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final symbol = Formatters.currencySymbol;
    final custom = _selectedBlindIndex == -1;

    return AppPage(
      maxWidth: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar with Squircle Back button < and CASH GAME badge pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppBackButton(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.home);
                  }
                },
                tooltip: 'Back to home',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.destructiveSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.destructive.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'CASH GAME',
                  style: TextStyle(
                    color: AppColors.destructiveText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title: New cash game
          Text(
            'New cash game',
            style: AppTypography.display(
              size: 32,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 24),

          // Blinds section
          Text(
            'Blinds',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _blinds.length; i++)
                _buildStakeChip(
                  label: _blinds[i].$1,
                  selected: _selectedBlindIndex == i,
                  onTap: () =>
                      _applyBlinds(i, _blinds[i].$2, _blinds[i].$3),
                ),
              _buildStakeChip(
                label: 'Custom',
                selected: custom,
                onTap: () => _applyBlinds(-1, _sb, _bb),
              ),
            ],
          ),
          if (custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StakeStepper(
                    label: 'Small blind',
                    controller: _customSb,
                    onMinus: () => _nudgeCustom(sb: -1),
                    onPlus: () => _nudgeCustom(sb: 1),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        _applyBlinds(-1, parsed, _bb, syncControllers: false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StakeStepper(
                    label: 'Big blind',
                    controller: _customBb,
                    onMinus: () => _nudgeCustom(bb: -1),
                    onPlus: () => _nudgeCustom(bb: 1),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        _applyBlinds(-1, _sb, parsed, syncControllers: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Buy-in section with Min/Max toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _setMinMax ? 'Buy-in range' : 'Buy-in',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _setMinMax = !_setMinMax;
                    if (_setMinMax) {
                      _minBuyIn.text = _buyIn.text;
                      _maxBuyIn.text = _num(_bb * 250);
                    } else {
                      _buyIn.text = _minBuyIn.text;
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Set minimum and maximum',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppToggle(
                      value: _setMinMax,
                      onChanged: (v) {
                        setState(() {
                          _setMinMax = v;
                          if (v) {
                            _minBuyIn.text = _buyIn.text;
                            _maxBuyIn.text = _num(_bb * 250);
                          } else {
                            _buyIn.text = _minBuyIn.text;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_setMinMax)
            _buildBuyInField(controller: _buyIn, prefix: symbol)
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Min buy-in',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBuyInField(controller: _minBuyIn, prefix: symbol),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max buy-in',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBuyInField(controller: _maxBuyIn, prefix: symbol),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          // Chip set dropdown
          Text(
            'Chip set',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _chooseChipSet(context, app),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _chipSetLabel(app),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.mutedForeground,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Chip value (D1): per session, never saved on the chip set.
          Text(
            'Chip value',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _buildBuyInField(controller: _chipValue, prefix: '1 chip ='),
          const SizedBox(height: 6),
          _buildChipValueExample(symbol),
          const SizedBox(height: 12),
          _buildBreakdownCard(app),
          const SizedBox(height: 20),

          // Track settlement Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Expanded, not a bare Text: a 16px label in the test
                    // font fallback is wider than the row has left after the
                    // toggle, and an unconstrained Text pushes the toggle off
                    // the card entirely at 320px.
                    Expanded(
                      child: Text(
                        'Track settlement',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppToggle(
                      value: _trackSettlement,
                      onChanged: (v) => setState(() => _trackSettlement = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto-calculate who owes who at the end.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Who is playing section (C4)
          Text(
            'Who is playing? (optional)',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: TextField(
              key: const Key('cash_who_is_playing_input'),
              controller: _whoIsPlaying,
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                hintText: 'Names separated by commas, e.g. Alice, Bob',
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Start session button
          InkWell(
            onTap: () => _start(app),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Glass.primaryGlow,
              ),
              child: Text(
                'Start session',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // DECISION: C3 - Show dynamic chip value example with live buy-in and chip count without currency symbol when currency is None.
  Widget _buildChipValueExample(String sym) {
    final unit = num.tryParse(_chipValue.text.trim())?.toDouble() ?? 1.0;
    final buy = _setMinMax
        ? (num.tryParse(_minBuyIn.text.trim())?.toDouble() ?? 100.0)
        : (num.tryParse(_buyIn.text.trim())?.toDouble() ?? 100.0);
    final chipsCount = unit > 0 ? (buy / unit).round() : 0;
    final chip25Val = 25 * unit;
    final chip25Str = chip25Val == chip25Val.roundToDouble()
        ? chip25Val.round().toString()
        : chip25Val.toStringAsFixed(2);
    final unitStr = unit == unit.roundToDouble() ? unit.round().toString() : unit.toString();
    final buyStr = buy == buy.roundToDouble() ? buy.round().toString() : buy.toString();

    final example = 'Example: At 1 chip = $sym$unitStr, a 25 chip is $sym$chip25Str; buy-in $sym$buyStr = $chipsCount chips.';
    return Text(
      example,
      style: AppTypography.bodyXs.copyWith(
        color: AppColors.mutedForeground,
      ),
    );
  }

  static Widget _buildStakeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderSubtle,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primarySoftBorder,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryForeground : AppColors.foreground,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ));
  }

  static Widget _buildBuyInField({
    required TextEditingController controller,
    required String prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          if (prefix.isNotEmpty) ...[
            Text(
              prefix,
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                // The container draws the field; without these the theme's
                // outline and fill paint a second box inside it.
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two custom-stakes steppers (D1: SB and BB, SB < BB).
class _StakeStepper extends StatelessWidget {
  const _StakeStepper({
    required this.label,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Lower $label',
            onPressed: onMinus,
            icon: Icon(Icons.remove, size: 18, color: AppColors.foreground),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  onChanged: onChanged,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Raise $label',
            onPressed: onPlus,
            icon: Icon(Icons.add, size: 18, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }
}
