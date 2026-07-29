import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_empty_state.dart';
import 'package:poker_night/features/tournament/controllers/check_in_controller.dart';
import 'package:poker_night/features/tournament/models/check_in_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';


class CheckInView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const CheckInView({super.key, required this.groupId, required this.gameId});

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  String _searchQuery = '';
  late final CheckInController _checkInController;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CheckInController>(tag: widget.gameId)) {
      _checkInController = Get.find<CheckInController>(tag: widget.gameId);
    } else {
      _checkInController = Get.put(CheckInController(widget.gameId), tag: widget.gameId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Check In', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: Obx(() {
        final allRecords = _checkInController.checkIns;
        
        final records = allRecords.where((r) => 
          r.participantName.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        final checkedIn = records.where((r) => r.status == const CheckInStatus.checkedIn()).toList();
        final pending = records.where((r) => r.status == const CheckInStatus.pending()).toList();
        final noShows = records.where((r) => r.status == const CheckInStatus.noShow()).toList();
        
        final totalPlayers = allRecords.length;
        final totalCheckedIn = allRecords.where((r) => r.status == const CheckInStatus.checkedIn()).length;
        final double progress = totalPlayers > 0 ? totalCheckedIn / totalPlayers : 0.0;
        
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Stats at top
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$totalCheckedIn / $totalPlayers Checked In', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontFamily: 'Inter', color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.cardDark,
                          color: AppColors.primary,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      TextField(
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search players...',
                          hintStyle: const TextStyle(color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.cardDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: records.isEmpty
                    ? const PNEmptyState(
                        icon: Icons.person_pin,
                        title: 'No players found',
                        subtitle: 'Try adjusting your search',
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (checkedIn.isNotEmpty) ...[
                            const PNSectionHeaderWidget(title: 'Checked In'),
                            ...checkedIn.map((r) => _checkInTile(r, true)),
                          ],
                          if (pending.isNotEmpty) ...[
                            const PNSectionHeaderWidget(title: 'Pending'),
                            ...pending.map((r) => _checkInTile(r, false)),
                          ],
                          if (noShows.isNotEmpty) ...[
                            const PNSectionHeaderWidget(title: 'No Show'),
                            ...noShows.map((r) => _checkInTile(r, false)),
                          ],
                          const SizedBox(height: 80), // space for fab
                        ],
                      ),
                ),
              ],
            ),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Lock check-in logic
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.lock, color: Colors.white),
        label: const Text('Lock Check-in', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _checkInTile(CheckInRecord record, bool isCheckedIn) {
    return PNCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCheckedIn ? Colors.green.withValues(alpha: 0.3) : Colors.transparent, width: 2),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCheckedIn ? Colors.green.withValues(alpha: 0.2) : AppColors.cardDark,
            child: Icon(
              isCheckedIn ? Icons.check : Icons.schedule,
              color: isCheckedIn ? Colors.green : AppColors.textSecondary,
            ),
          ),
          title: Text(record.participantName, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: record.checkedInAt != null
              ? Text('Checked in at ${_formatTime(record.checkedInAt!)}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 12))
              : const Text('Not yet checked in', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 12)),
          trailing: isCheckedIn
              ? null
              : Switch(
                  value: false,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    if (val) {
                      _checkInController.checkInPlayer(record.participantId, record.participantName);
                    }
                  },
                ),
        ),
      ),
    ).animate().fade().slideX();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class PNSectionHeaderWidget extends StatelessWidget {
  final String title;
  const PNSectionHeaderWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}
