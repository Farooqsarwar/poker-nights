import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

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
            decoration: const InputDecoration(labelText: 'Tournament Name', hintText: 'e.g. Friday Poker'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date & Time', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            subtitle: Text(
              '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year} '
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.bodyLarge,
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expectedPlayersController,
            decoration: const InputDecoration(labelText: 'Expected Players'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 2) return 'Minimum 2 players';
              if (n > 1000) return 'Maximum 1000 players';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Target Duration: ${_targetDuration.toStringAsFixed(1)}h', style: theme.textTheme.bodyLarge),
              Expanded(
                child: Slider(
                  value: _targetDuration,
                  min: 3.0,
                  max: 6.0,
                  divisions: 6,
                  label: '${_targetDuration.toStringAsFixed(1)}h',
                  onChanged: (v) => setState(() => _targetDuration = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _buyInController,
            decoration: const InputDecoration(labelText: 'Buy-In Amount', prefixText: '\$ '),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
        ],
      ),
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
              ButtonSegment(value: 'existing', label: Text('Existing Set')),
              ButtonSegment(value: 'quick', label: Text('Quick Setup')),
            ],
            selected: {_chipSetupType},
            onSelectionChanged: (v) => setState(() => _chipSetupType = v.first),
          ),
          const SizedBox(height: 16),
          if (_chipSetupType == 'existing') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedChipSet,
              decoration: const InputDecoration(labelText: 'Chip Set'),
              items: _chipSetOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedChipSet = v ?? _selectedChipSet),
            ),
          ] else ...[
            const Text('Chip Colors & Availability', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._chipColors.asMap().entries.map((entry) {
              final i = entry.key;
              final chip = entry.value;
              return PNCard(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: chip['color'] as Color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade400)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text(chip['label'] as String)),
                    Expanded(child: Text('x${chip['availability']}', style: theme.textTheme.bodyMedium)),
                    Expanded(child: Text('\$${chip['value']}', style: theme.textTheme.bodyMedium)),
                    IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent), onPressed: () => _removeChipColor(i)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            PNButton(
              onPressed: _addChipColor,
              icon: Icons.add,
              label: 'Add Color',
              outlined: true,
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Numbered Chips'),
            subtitle: const Text('Display denomination on chip'),
            value: _numberedChips,
            onChanged: (v) => setState(() => _numberedChips = v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(title: const Text('Rebuys'), value: _rebuysEnabled, onChanged: (v) => setState(() => _rebuysEnabled = v), contentPadding: EdgeInsets.zero),
        const Divider(),
        Row(
          children: [
            Text('Close Level After', style: theme.textTheme.bodyLarge),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: _closeLevel.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: 'levels', isDense: true),
                onChanged: (v) => setState(() => _closeLevel = int.tryParse(v) ?? 6),
              ),
            ),
          ],
        ),
        const Divider(),
        SwitchListTile(title: const Text('Add-On Available'), value: _addOnEnabled, onChanged: (v) => setState(() => _addOnEnabled = v), contentPadding: EdgeInsets.zero),
        const Divider(),
        SwitchListTile(title: const Text('KO Bounty'), value: _koBountyEnabled, onChanged: (v) => setState(() => _koBountyEnabled = v), contentPadding: EdgeInsets.zero),
        const Divider(),
        DropdownButtonFormField<String>(
          initialValue: _anteMode,
          decoration: const InputDecoration(labelText: 'Ante Mode'),
          items: _anteModeOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _anteMode = v ?? 'none'),
        ),
        const Divider(),
        Row(
          children: [
            Text('Organizer %: ${_organizerPercent.toStringAsFixed(0)}%', style: theme.textTheme.bodyLarge),
            Expanded(
              child: Slider(
                value: _organizerPercent, min: 0, max: 20, divisions: 20,
                label: '${_organizerPercent.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _organizerPercent = v),
              ),
            ),
          ],
        ),
      ],
    );
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
          Text('Summary', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _summaryRow('Tournament', _nameController.text.isNotEmpty ? _nameController.text : '(unnamed)', theme),
          _summaryRow('Date', '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}', theme),
          _summaryRow('Players', players.toString(), theme),
          _summaryRow('Buy-In', '\$${buyIn.toStringAsFixed(2)}', theme),
          _summaryRow('Duration', '${_targetDuration.toStringAsFixed(1)}h', theme),
          if (prizes != null) ...[
            _summaryRow('Prize Pool', '\$${prizes.prizePool}', theme),
            _summaryRow('Organizer', '\$${prizes.organizerAmount}', theme),
          ],
          _summaryRow('Rebuys', _rebuysEnabled ? 'Until Level $_closeLevel' : 'Disabled', theme),
          _summaryRow('Add-On', _addOnEnabled ? 'Enabled' : 'Disabled', theme),
          _summaryRow('KO Bounty', _koBountyEnabled ? 'Enabled' : 'Disabled', theme),
          _summaryRow('Ante Mode', _anteMode, theme),
          const Divider(height: 24),
          Text('Blind Structure', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (levels.isEmpty)
            const Text('Generating structure...')
          else
            ...levels.take(12).map((lvl) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('Level ${lvl.level}', style: theme.textTheme.bodySmall)),
                    SizedBox(width: 60, child: Text('SB \$${lvl.smallBlind}', style: theme.textTheme.bodySmall)),
                    SizedBox(width: 60, child: Text('BB \$${lvl.bigBlind}', style: theme.textTheme.bodySmall)),
                    Text('${lvl.durationMinutes}m', style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }),
          if (levels.length > 12)
            Text('... and ${levels.length - 12} more levels', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          if (prizes != null && prizes.payouts.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Payouts', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...prizes.payouts.map((p) => _summaryRow(_ordinal(p.position), '\$${p.amount}', theme)),
          ],
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

  Widget _summaryRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
