import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/tournament/controllers/tournament_controller.dart';
import 'package:poker_night/features/tournament/controllers/tournament_engine.dart';
import 'package:poker_night/features/tournament/models/blind_structure_model.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class CreateTournamentView extends StatefulWidget {
  final String groupId;

  const CreateTournamentView({super.key, required this.groupId});

  @override
  State<CreateTournamentView> createState() => _CreateTournamentViewState();
}

class _CreateTournamentViewState extends State<CreateTournamentView> {
  final _authController = Get.find<AuthController>();
  final _tournamentController = Get.find<TournamentController>();

  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  final _locationController = TextEditingController(text: 'Home');
  final _expectedPlayersController = TextEditingController(text: '8');
  double _targetDuration = 4.0;
  final _buyInController = TextEditingController(text: '20');

  String _chipSetupType = 'existing';
  String _selectedChipSet = 'Standard';
  final List<Map<String, dynamic>> _chipColors = [
    {'color': Colors.white, 'label': 'White', 'availability': 50, 'value': '1'},
    {'color': Colors.red, 'label': 'Red', 'availability': 30, 'value': '5'},
    {'color': Colors.blue, 'label': 'Blue', 'availability': 20, 'value': '10'},
    {'color': Colors.green, 'label': 'Green', 'availability': 15, 'value': '25'},
    {'color': Colors.black, 'label': 'Black', 'availability': 10, 'value': '100'},
  ];
  bool _numberedChips = true;

  bool _rebuysEnabled = true;
  int _closeLevel = 6;
  bool _addOnEnabled = true;
  bool _koBountyEnabled = false;
  String _anteMode = 'big blind ante';
  double _organizerPercent = 0.0;

  BlindStructure? _generatedStructure;
  PrizeDistribution? _prizeDistribution;

  final List<String> _chipSetOptions = ['Standard', 'Premium', 'Pro Series', 'Custom'];
  final List<String> _anteModeOptions = ['none', 'big blind ante', 'individual ante'];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _expectedPlayersController.dispose();
    _buyInController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
    }
    if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
    }
    if (_currentStep == 2) {
      _generateStructure();
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _generateStructure() {
    final players = int.tryParse(_expectedPlayersController.text) ?? 8;
    final buyIn = double.tryParse(_buyInController.text) ?? 0;
    final settings = TournamentSettings(
      expectedPlayers: players,
      targetDurationHours: _targetDuration,
      buyIn: buyIn,
      anteMode: _anteMode,
      rebuysEnabled: _rebuysEnabled,
      rebuyCloseLevel: _closeLevel,
      addOnEnabled: _addOnEnabled,
      koBounty: _koBountyEnabled ? 5.0 : 0,
      organizerPercentage: _organizerPercent / 100,
    );
    final structure = TournamentEngine.generate(settings, null);
    final prizes = TournamentEngine.calculatePrizes(
      buyIn, players, _organizerPercent / 100,
      koBounty: _koBountyEnabled ? 5.0 : 0,
    );
    setState(() {
      _generatedStructure = structure;
      _prizeDistribution = prizes;
    });
  }

  Future<void> _confirmAndCreate() async {
    _generateStructure();
    final userId = _authController.currentUser.value?.id ?? '';
    if (userId.isEmpty) return;

    final players = int.tryParse(_expectedPlayersController.text) ?? 8;
    final buyIn = double.tryParse(_buyInController.text) ?? 0;
    final settings = TournamentSettings(
      expectedPlayers: players,
      targetDurationHours: _targetDuration,
      buyIn: buyIn,
      anteMode: _anteMode,
      rebuysEnabled: _rebuysEnabled,
      rebuyCloseLevel: _closeLevel,
      addOnEnabled: _addOnEnabled,
      koBounty: _koBountyEnabled ? 5.0 : 0,
      organizerPercentage: _organizerPercent / 100,
    );

    final name = _nameController.text.trim().isEmpty
        ? 'Poker Night ${_selectedDate.month}/${_selectedDate.day}'
        : _nameController.text.trim();

    final scheduledAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    final tournament = await _tournamentController.createTournament(
      groupId: widget.groupId,
      name: name,
      scheduledAt: scheduledAt,
      location: _locationController.text.trim(),
      settings: settings,
    );

    if (_generatedStructure != null) {
      await _tournamentController.saveStructure(tournament.id, _generatedStructure!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" created!'), duration: const Duration(seconds: 2)),
      );
      context.go('/groups/${widget.groupId}/tournament/${tournament.id}/review');
    }
  }

  void _pickDateTime() async {
    if (!mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time == null) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  void _addChipColor() {
    if (_chipColors.length >= 8) return;
    setState(() {
      _chipColors.add({
        'color': Colors.grey,
        'label': 'New',
        'availability': 10,
        'value': '${(_chipColors.length + 1) * 10}',
      });
    });
  }

  void _removeChipColor(int index) {
    if (_chipColors.length <= 2) return;
    setState(() => _chipColors.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Create Tournament', style: TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.go('/groups/${widget.groupId}'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: AppColors.darkSurface,
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                surface: AppColors.darkSurface,
              ),
            ),
            child: Stepper(
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            onStepTapped: (step) {
              if (step < _currentStep) setState(() => _currentStep = step);
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    if (_currentStep < 3)
                      Expanded(
                        child: PNButton(
                          onPressed: details.onStepContinue,
                          label: 'Next',
                        ),
                      )
                    else
                      Expanded(
                        child: PNButton(
                          onPressed: _confirmAndCreate,
                          label: 'Create Tournament',
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      Expanded(
                        child: PNButton(
                          onPressed: details.onStepCancel,
                          label: 'Back',
                          outlined: true,
                        ),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Basic Info'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: _buildStep1(theme),
              ),
              Step(
                title: const Text('Chip Configuration'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: _buildStep2(theme),
              ),
              Step(
                title: const Text('Rules & Options'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: _buildStep3(theme),
              ),
              Step(
                title: const Text('Review & Confirm'),
                isActive: _currentStep >= 3,
                state: StepState.indexed,
                content: _buildStep4(theme),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Tournament Name',
              hintText: 'e.g. Friday Poker',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          PNCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text('Date & Time', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(
                '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year} '
                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expectedPlayersController,
            decoration: InputDecoration(
              labelText: 'Expected Players',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 2) return 'Minimum 2 players';
              if (n > 1000) return 'Maximum 1000 players';
              return null;
            },
          ),
          const SizedBox(height: 16),
          PNCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target Duration: ${_targetDuration.toStringAsFixed(1)}h', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Slider(
                  value: _targetDuration,
                  min: 3.0,
                  max: 6.0,
                  divisions: 6,
                  label: '${_targetDuration.toStringAsFixed(1)}h',
                  onChanged: (v) => setState(() => _targetDuration = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _buyInController,
            decoration: InputDecoration(
              labelText: 'Buy-In Amount',
              prefixText: '\$ ',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'existing', label: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Existing Set'))),
              ButtonSegment(value: 'quick', label: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Quick Setup'))),
            ],
            selected: {_chipSetupType},
            onSelectionChanged: (v) => setState(() => _chipSetupType = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return theme.colorScheme.onSurface;
              }),
            ),
          ),
          const SizedBox(height: 24),
          if (_chipSetupType == 'existing') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedChipSet,
              decoration: InputDecoration(
                labelText: 'Chip Set',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _chipSetOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedChipSet = v ?? _selectedChipSet),
            ),
          ] else ...[
            const Text('Chip Colors & Availability', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            ..._chipColors.asMap().entries.map((entry) {
              final i = entry.key;
              final chip = entry.value;
              return PNCard(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: chip['color'] as Color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade600, width: 2), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: Text(chip['label'] as String, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(child: Text('x${chip['availability']}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400))),
                    Expanded(child: Text('\$${chip['value']}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.remove_circle_outline, size: 24, color: Colors.redAccent), onPressed: () => _removeChipColor(i)),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
            }),
            const SizedBox(height: 16),
            PNButton(
              onPressed: _addChipColor,
              icon: Icons.add,
              label: 'Add Color',
              outlined: true,
            ),
          ],
          const SizedBox(height: 24),
          PNCard(
            child: SwitchListTile(
              title: const Text('Numbered Chips', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Display denomination on chip'),
              value: _numberedChips,
              onChanged: (v) => setState(() => _numberedChips = v),
              activeColor: AppColors.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildStep3(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PNCard(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Rebuys', style: TextStyle(fontWeight: FontWeight.w600)),
                value: _rebuysEnabled, 
                onChanged: (v) => setState(() => _rebuysEnabled = v), 
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
              ),
              if (_rebuysEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('Close Level After', style: theme.textTheme.bodyLarge),
                      const Spacer(),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          initialValue: _closeLevel.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            suffixText: 'levels', 
                            isDense: true,
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setState(() => _closeLevel = int.tryParse(v) ?? 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PNCard(
          child: SwitchListTile(title: const Text('Add-On Available', style: TextStyle(fontWeight: FontWeight.w600)), activeColor: AppColors.primary, value: _addOnEnabled, onChanged: (v) => setState(() => _addOnEnabled = v), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
        ),
        const SizedBox(height: 16),
        PNCard(
          child: SwitchListTile(title: const Text('KO Bounty', style: TextStyle(fontWeight: FontWeight.w600)), activeColor: AppColors.primary, value: _koBountyEnabled, onChanged: (v) => setState(() => _koBountyEnabled = v), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _anteMode,
          decoration: InputDecoration(
            labelText: 'Ante Mode',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: _anteModeOptions.map((a) => DropdownMenuItem(value: a, child: Text(a.capitalizeFirst ?? a))).toList(),
          onChanged: (v) => setState(() => _anteMode = v ?? 'none'),
        ),
        const SizedBox(height: 24),
        PNCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Organizer %: ${_organizerPercent.toStringAsFixed(0)}%', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Slider(
                value: _organizerPercent, min: 0, max: 20, divisions: 20,
                label: '${_organizerPercent.toStringAsFixed(0)}%',
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _organizerPercent = v),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStep4(ThemeData theme) {
    final players = int.tryParse(_expectedPlayersController.text) ?? 8;
    final buyIn = double.tryParse(_buyInController.text) ?? 0;

    if (_generatedStructure == null) {
      _generateStructure();
    }

    final levels = _generatedStructure?.levels ?? [];
    final prizes = _prizeDistribution;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PNCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.summarize, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _summaryRow('Tournament', _nameController.text.isNotEmpty ? _nameController.text : '(unnamed)', theme),
                _summaryRow('Date', '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}', theme),
                _summaryRow('Players', players.toString(), theme),
                _summaryRow('Buy-In', '\$${buyIn.toStringAsFixed(2)}', theme),
                _summaryRow('Duration', '${_targetDuration.toStringAsFixed(1)}h', theme),
                if (prizes != null) ...[
                  const Divider(height: 24),
                  _summaryRow('Prize Pool', '\$${prizes.prizePool}', theme, isHighlight: true),
                  _summaryRow('Organizer', '\$${prizes.organizerAmount}', theme),
                ],
                const Divider(height: 24),
                _summaryRow('Rebuys', _rebuysEnabled ? 'Until Level $_closeLevel' : 'Disabled', theme),
                _summaryRow('Add-On', _addOnEnabled ? 'Enabled' : 'Disabled', theme),
                _summaryRow('KO Bounty', _koBountyEnabled ? 'Enabled' : 'Disabled', theme),
                _summaryRow('Ante Mode', _anteMode.capitalizeFirst ?? _anteMode, theme),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 24),
          Text('Blind Structure', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          PNCard(
            padding: const EdgeInsets.all(0),
            child: levels.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                : Column(
                    children: [
                      ...levels.take(12).map((lvl) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
                            color: lvl.level % 2 == 0 ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.transparent,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(width: 80, child: Text('Level ${lvl.level}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('SB \$${lvl.smallBlind}', style: theme.textTheme.bodyMedium)),
                              Expanded(child: Text('BB \$${lvl.bigBlind}', style: theme.textTheme.bodyMedium)),
                              Text('${lvl.durationMinutes}m', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }),
                      if (levels.length > 12)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('... and ${levels.length - 12} more levels', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
          if (prizes != null && prizes.payouts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Payouts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            PNCard(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: prizes.payouts.map((p) => Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
                    color: p.position % 2 == 0 ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.transparent,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      SizedBox(width: 60, child: Text(_ordinal(p.position), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: p.position == 1 ? Colors.amber : null))),
                      const Spacer(),
                      Text('\$${p.amount}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ],
                  ),
                )).toList(),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  Widget _summaryRow(String label, String value, ThemeData theme, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 15))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500, fontSize: isHighlight ? 18 : 15, color: isHighlight ? AppColors.primary : theme.colorScheme.onSurface))),
        ],
      ),
    );
  }
}
