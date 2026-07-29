import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_qr_display.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/tournament/controllers/rsvp_controller.dart';
import 'package:poker_night/features/tournament/models/rsvp_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class TournamentLobbyView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const TournamentLobbyView({super.key, required this.groupId, required this.gameId});

  @override
  State<TournamentLobbyView> createState() => _TournamentLobbyViewState();
}

class _TournamentLobbyViewState extends State<TournamentLobbyView> {
  late final RsvpController _rsvpController;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    // Check if controller exists, else create it using Get.put
    if (Get.isRegistered<RsvpController>(tag: widget.gameId)) {
      _rsvpController = Get.find<RsvpController>(tag: widget.gameId);
    } else {
      _rsvpController = Get.put(RsvpController(widget.gameId), tag: widget.gameId);
    }
    Future.microtask(() {
      _rsvpController.loadRsvps();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentUser = _authController.currentUser.value;
      final rsvps = _rsvpController.rsvps;

      final myRsvp = currentUser != null
          ? rsvps.where((r) => r.participantId == currentUser.id).firstOrNull
          : null;

      final going = rsvps.where((r) => r.status == const RsvpStatus.going()).length;

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          title: const Text('Tournament Lobby', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header
                      PNCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Friday Night Poker', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                const Text('Oct 24, 8:00 PM', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      const Text('The Garage', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.secondaryAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.secondaryAccent)),
                                  child: const Text('\$50 Buy-in', style: TextStyle(fontFamily: 'Inter', color: AppColors.secondaryAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fade().slideY(begin: -0.2),
                      
                      const SizedBox(height: 16),
                      
                      // Stats Row
                      Row(
                        children: [
                          _statCard('Registered', rsvps.length.toString(), Icons.people, AppColors.primary),
                          const SizedBox(width: 12),
                          _statCard('Confirmed', going.toString(), Icons.check_circle, Colors.green),
                          const SizedBox(width: 12),
                          _statCard('Pot', '\$${going * 50}', Icons.monetization_on, AppColors.secondaryAccent),
                        ],
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.2),

                      const SizedBox(height: 24),
                      
                      const Text('Players', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      
                      ...rsvps.map((rsvp) {
                        Color statusColor = Colors.grey;
                        String statusText = 'Pending';
                        rsvp.status.when(
                          going: () { statusColor = Colors.green; statusText = 'Going'; },
                          maybe: () { statusColor = Colors.orange; statusText = 'Maybe'; },
                          notGoing: () { statusColor = Colors.red; statusText = 'Not Going'; },
                          noResponse: () {},
                        );
                        
                        return PNCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.cardDark,
                              child: Text(rsvp.participantId.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.textPrimary)),
                            ),
                            title: Text(rsvp.participantId, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(statusText, style: TextStyle(fontFamily: 'Inter', color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ).animate().fade().slideX();
                      }),

                      const SizedBox(height: 24),

                      // QR Code
                      PNCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('Scan to Join', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: PNQrDisplay(data: '/game/${widget.gameId}/player', size: 150),
                            ),
                          ],
                        ),
                      ).animate().fade().scale(),
                    ],
                  ),
                ),
                
                // Bottom Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: PNButton(
                                label: 'Check In',
                                onPressed: () => context.push('/groups/${widget.groupId}/tournament/${widget.gameId}/check-in'),
                                outlined: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PNButton(
                                label: 'Start Tournament',
                                onPressed: () => context.push('/groups/${widget.groupId}/tournament/${widget.gameId}/admin'),
                              ),
                            ),
                          ],
                        ),
                        if (myRsvp == null || myRsvp.status is RsvpNoResponse) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push('/groups/${widget.groupId}/tournament/${widget.gameId}/rsvp'),
                            child: const Text('RSVP Now', style: TextStyle(color: AppColors.secondaryAccent)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: PNCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
