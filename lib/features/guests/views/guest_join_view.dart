import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/guests/controllers/guest_controller.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';

class GuestJoinView extends StatefulWidget {
  final String tournamentId;

  const GuestJoinView({super.key, required this.tournamentId});

  @override
  State<GuestJoinView> createState() => _GuestJoinViewState();
}

class _GuestJoinViewState extends State<GuestJoinView> {
  final _nameController = TextEditingController();
  String? _selectedInviter;
  int? _selectedSlot;
  bool _submitted = false;

  static const List<int> _guestSlots = [1, 2, 3, 4];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    if (_selectedInviter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who invited you')),
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a guest slot')),
      );
      return;
    }

    final guestController = Get.put(GuestController(widget.tournamentId), tag: widget.tournamentId);
    await guestController.loadGuests();
    final existingGuests = guestController.guests;
    final slotTaken = existingGuests.any((g) =>
      g.slotNo == _selectedSlot &&
      g.gameId == widget.tournamentId &&
      g.confirmationState != 'rejected');

    if (slotTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guest slot $_selectedSlot is already taken. Please choose another.')),
      );
      return;
    }

    await guestController.addGuest(
      name: name,
      inviterParticipantId: _selectedInviter!,
      slotNo: _selectedSlot!,
    );

    setState(() => _submitted = true);
  }

  String _slotLabel(int slot) {
    switch (slot) {
      case 1: return 'Guest Slot 1';
      case 2: return 'Guest Slot 2';
      case 3: return 'Guest Slot 3';
      case 4: return 'Guest Slot 4';
      default: return 'Slot $slot';
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveGameController = Get.find<LiveGameController>(tag: widget.tournamentId);
    final gameState = liveGameController.state;
    final registeredPlayers = gameState.players.where((p) => !p.isGuest).toList();
    final theme = Theme.of(context);

    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          title: const Text('Request Submitted', style: TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.darkSurface,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text('Request Sent!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Your request to join as a guest has been sent to the tournament admin for approval.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                PNButton(
                  onPressed: () => context.go('/login'),
                  label: 'Back to Home',
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('Join as Guest', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.darkSurface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PNCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Tournament', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Poker Night', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your Name', hintText: 'Enter your name', prefixIcon: Icon(Icons.person)),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedInviter,
                  decoration: const InputDecoration(labelText: 'Invited By', hintText: 'Select a player', prefixIcon: Icon(Icons.person_add)),
                  items: registeredPlayers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setState(() => _selectedInviter = v),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _selectedSlot,
                  decoration: const InputDecoration(labelText: 'Guest Slot', hintText: 'Select slot', prefixIcon: Icon(Icons.meeting_room)),
                  items: _guestSlots.map((s) => DropdownMenuItem(value: s, child: Text(_slotLabel(s)))).toList(),
                  onChanged: (v) => setState(() => _selectedSlot = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: PNButton(
                    onPressed: _submit,
                    label: 'Submit Request',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
