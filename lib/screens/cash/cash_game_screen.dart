import 'package:flutter/material.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/cash_game.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/back_nav_button.dart';

/// Cash game setup screen strictly matching D1_CashSetup mobile-first design.
class CashGameScreen extends StatefulWidget {
  const CashGameScreen({super.key});

  @override
  State<CashGameScreen> createState() => _CashGameScreenState();
}

class _CashGameScreenState extends State<CashGameScreen> {
  final _name = TextEditingController(text: 'Friday Cash Game');
  final _smallBlind = TextEditingController(text: '1');
  final _bigBlind = TextEditingController(text: '2');
  final _minBuyIn = TextEditingController(text: '100');
  final _maxBuyIn = TextEditingController(text: '500');
  bool _trackSettlement = true;
  String? _selectedChipSetId;

  // Selected preset stake index: 0 = 0.5/1, 1 = 1/2, 2 = 2/5, -1 = custom
  int _selectedStakeIndex = 1;

  final List<TextEditingController> _playerControllers = [];

  @override
  void initState() {
    super.initState();
    _initDefaultPlayers();
  }

  void _initDefaultPlayers() {
    // Start with 6 empty or default player slots matching D2 preview
    _playerControllers.addAll([
      TextEditingController(text: 'Alex M.'),
      TextEditingController(text: 'Marcus L.'),
      TextEditingController(text: 'Ava R.'),
      TextEditingController(text: 'Daniel K.'),
      TextEditingController(text: 'Sophia T.'),
      TextEditingController(text: 'Leo B.'),
    ]);
  }

  @override
  void dispose() {
    _name.dispose();
    _smallBlind.dispose();
    _bigBlind.dispose();
    _minBuyIn.dispose();
    _maxBuyIn.dispose();
    for (final c in _playerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _setStake(int index, String sb, String bb) {
    setState(() {
      _selectedStakeIndex = index;
      _smallBlind.text = sb;
      _bigBlind.text = bb;
    });
  }

  void _start(AppProvider app) {
    final validNames = _playerControllers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (validNames.length < 2) {
      _showAddPlayersSheet(app);
      return;
    }

    final sb = num.tryParse(_smallBlind.text)?.toDouble() ?? 1;
    final bb = num.tryParse(_bigBlind.text)?.toDouble() ?? 2;
    final minBuy = num.tryParse(_minBuyIn.text)?.toDouble() ?? 100;
    final maxBuy = num.tryParse(_maxBuyIn.text)?.toDouble() ?? 500;

    if (bb <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Big blind must be greater than 0.')),
      );
      return;
    }
    if (sb >= bb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Small blind must be less than big blind.'),
        ),
      );
      return;
    }
    if (minBuy > maxBuy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Min buy-in must be <= max buy-in.')),
      );
      return;
    }

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    app.startCashGame(
      CashSessionSettings(
        name: _name.text.trim().isEmpty
            ? 'Friday Cash Game'
            : _name.text.trim(),
        date: today,
        location: app.hasCurrentGroup ? app.currentGroup.name : 'Home',
        smallBlind: sb,
        bigBlind: bb,
        minBuyIn: minBuy,
        maxBuyIn: maxBuy,
        maxPlayers: 10,
        currency: '\$',
      ),
      validNames,
    );
    context.go(RoutePaths.cashGameLive);
  }

  void _showAddPlayersSheet(AppProvider app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Table Players',
                            style: AppTypography.display(
                              size: 20,
                              weight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setSheetState(() {
                                _playerControllers.add(TextEditingController());
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                '+ Add seat',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _playerControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.borderSubtle,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _playerControllers[i],
                                    style: TextStyle(
                                      color: AppColors.foreground,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      // The container draws the field; without these the theme's
                                      // outline and fill paint a second box inside it.
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      hintText: 'Player name',
                                      hintStyle: TextStyle(
                                        color: AppColors.onSurfaceHint,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_playerControllers.length > 2) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.onSurfaceHint,
                                  ),
                                  onPressed: () {
                                    setSheetState(() {
                                      _playerControllers.removeAt(i).dispose();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          _start(app);
                        },
                        child: Text(
                          'Confirm & Start',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                    'Home set · 5 colors',
                    style: TextStyle(color: AppColors.foreground),
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
                      '${set.name} · ${set.chips.length} colors',
                      style: TextStyle(color: AppColors.foreground),
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

    if (!app.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    final chipSetName = _selectedChipSetId == null
        ? 'Home set · 5 colors'
        : (app.savedChipSets
                  .where((c) => c.id == _selectedChipSetId)
                  .firstOrNull
                  ?.name ??
              'Home set · 5 colors');

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
              BackNavButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.home);
                  }
                },
                label: 'Back to home',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.destructiveSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
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

          // Stakes section
          Text(
            'Stakes',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStakeSegment(
                    label: '0.5 / 1',
                    selected: _selectedStakeIndex == 0,
                    onTap: () => _setStake(0, '0.5', '1'),
                  ),
                ),
                Expanded(
                  child: _buildStakeSegment(
                    label: '1 / 2',
                    selected: _selectedStakeIndex == 1,
                    onTap: () => _setStake(1, '1', '2'),
                  ),
                ),
                Expanded(
                  child: _buildStakeSegment(
                    label: '2 / 5',
                    selected: _selectedStakeIndex == 2,
                    onTap: () => _setStake(2, '2', '5'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Min buy-in & Max buy-in row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min buy-in',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildBuyInField(controller: _minBuyIn, prefix: '\$'),
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
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildBuyInField(controller: _maxBuyIn, prefix: '\$'),
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
                  Text(
                    chipSetName,
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
                    Text(
                      'Track settlement',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
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

  static Widget _buildStakeSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primarySoftBorder,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.foreground : AppColors.mutedForeground,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
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
          Text(
            prefix,
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
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
