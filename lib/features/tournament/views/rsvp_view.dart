import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/guests/controllers/guest_controller.dart';
import 'package:poker_night/features/tournament/controllers/rsvp_controller.dart';
import 'package:poker_night/features/tournament/models/rsvp_model.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';

class RsvpView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const RsvpView({super.key, required this.groupId, required this.gameId});

  @override
  State<RsvpView> createState() => _RsvpViewState();
}

class _RsvpViewState extends State<RsvpView> {
  RsvpStatus _selectedStatus = const RsvpStatus.going();
  int _guestCount = 0;
  bool _rsvpLocked = false;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    _checkRsvpCutoff();
  }

  void _checkRsvpCutoff() {
    LiveGameController? liveGameController;
    if (Get.isRegistered<LiveGameController>(tag: widget.gameId)) {
      liveGameController = Get.find<LiveGameController>(tag: widget.gameId);
    }
    
    if (liveGameController != null) {
      final gameState = liveGameController.state;
      if (gameState.startedAt != null) {
        final scheduledAt = gameState.startedAt;
        if (scheduledAt != null) {
          final cutoff = scheduledAt.subtract(const Duration(hours: 1));
          if (DateTime.now().isAfter(cutoff)) {
            setState(() => _rsvpLocked = true);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('RSVP', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.darkSurface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_rsvpLocked) ...[
                const PNCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text('RSVP changes are closed (1 hour before scheduled start)')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Icon(Icons.event, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Will you be playing?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _statusOption('Going', Icons.check_circle, Colors.green, const RsvpStatus.going()),
              _statusOption('Not Going', Icons.cancel, Colors.red, const RsvpStatus.notGoing()),
              _statusOption('Maybe', Icons.help, Colors.orange, const RsvpStatus.maybe()),
              const SizedBox(height: 16),
              if (_selectedStatus is RsvpGoing) ...[
                const Text('Bringing guests?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final count = i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(count == 0 ? '0' : '+$count'),
                        selected: _guestCount == count,
                        onSelected: _rsvpLocked ? null : (selected) {
                          if (selected) setState(() => _guestCount = count);
                        },
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 32),
              PNButton(
                label: 'Submit RSVP',
                onPressed: _rsvpLocked ? null : () async {
                  final currentUser = _authController.currentUser.value;
                  if (currentUser == null) return;
                  
                  RsvpController rsvpController;
                  if (Get.isRegistered<RsvpController>(tag: widget.gameId)) {
                    rsvpController = Get.find<RsvpController>(tag: widget.gameId);
                  } else {
                    rsvpController = Get.put(RsvpController(widget.gameId), tag: widget.gameId);
                  }
                  
                  await rsvpController.submitRsvp(
                    participantId: currentUser.id,
                    participantName: currentUser.name,
                    status: _selectedStatus,
                    guestCount: _guestCount,
                  );

                  if (_selectedStatus is RsvpGoing && _guestCount > 0) {
                    GuestController guestController;
                    if (Get.isRegistered<GuestController>(tag: widget.gameId)) {
                      guestController = Get.find<GuestController>(tag: widget.gameId);
                    } else {
                      guestController = Get.put(GuestController(widget.gameId), tag: widget.gameId);
                    }
                    
                    for (int i = 1; i <= _guestCount; i++) {
                      await guestController.addGuest(
                        name: '${currentUser.name}\'s Guest #$i',
                        inviterParticipantId: currentUser.id,
                        slotNo: i,
                      );
                    }
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RSVP submitted')),
                    );
                    context.pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusOption(String label, IconData icon, Color color, RsvpStatus status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: PNCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: isSelected ? color : AppColors.textSecondary),
          title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.textPrimary)),
          trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
          onTap: () => setState(() => _selectedStatus = status),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
