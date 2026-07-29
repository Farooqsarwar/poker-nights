import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_section_header.dart';
import 'package:poker_night/features/guests/controllers/guest_controller.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/guests/models/guest_model.dart';
class GuestManagementView extends StatefulWidget {
  final String gameId;

  const GuestManagementView({super.key, required this.gameId});

  @override
  State<GuestManagementView> createState() => _GuestManagementViewState();
}

class _GuestManagementViewState extends State<GuestManagementView> {
  late final GuestController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(GuestController(widget.gameId), tag: widget.gameId);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final guests = controller.guests;
      final pending = guests.where((g) => g.confirmationState == 'pending').toList();
      final approved = guests.where((g) => g.confirmationState == 'approved').toList();
      final rejected = guests.where((g) => g.confirmationState == 'rejected').toList();

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          title: Text('Guest Management (${pending.length} pending)', style: const TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.darkSurface,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: guests.isEmpty
                ? const Center(child: Text('No guest requests'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pending.isNotEmpty) ...[
                        PNSectionHeader(title: 'Pending Approval'),
                        ...pending.map((g) => _guestTile(g, false)),
                      ],
                      if (approved.isNotEmpty) ...[
                        PNSectionHeader(title: 'Approved'),
                        ...approved.map((g) => _guestTile(g, true)),
                      ],
                      if (rejected.isNotEmpty) ...[
                        PNSectionHeader(title: 'Rejected'),
                        ...rejected.map((g) => _guestTile(g, true)),
                      ],
                    ],
                  ),
          ),
        ),
      );
    });
  }

  Widget _guestTile(GuestModel guest, bool resolved) {
    return PNCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: guest.confirmationState == 'approved'
              ? Colors.green
              : guest.confirmationState == 'rejected'
                  ? Colors.red
                  : Colors.orange,
          child: Icon(
            guest.confirmationState == 'approved'
                ? Icons.check
                : guest.confirmationState == 'rejected'
                    ? Icons.close
                    : Icons.hourglass_empty,
            color: Colors.white,
          ),
        ),
        title: Text(guest.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text('Slot #${guest.slotNo}', style: const TextStyle(color: AppColors.textSecondary)),
        trailing: resolved
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () {
                      controller.approveGuest(guest.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () {
                      controller.rejectGuest(guest.id);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
