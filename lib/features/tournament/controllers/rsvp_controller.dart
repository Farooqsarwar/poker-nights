import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/tournament/models/rsvp_model.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/services/storage_service.dart';

class RsvpController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String gameId;

  final rsvps = <RsvpEntry>[].obs;
  final isLoading = true.obs;

  RsvpController(this.gameId);

  @override
  void onInit() {
    super.onInit();
    loadRsvps();
  }

  Future<void> loadRsvps() async {
    isLoading.value = true;
    final data = await _storage.getJson('rsvps_$gameId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => RsvpEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    rsvps.value = list;
    isLoading.value = false;
  }

  bool canEditRsvp(TournamentModel tournament) {
    final cutoff = tournament.scheduledAt.subtract(const Duration(hours: 1));
    return DateTime.now().isBefore(cutoff) && tournament.status == TournamentStatus.published.value;
  }

  Future<void> submitRsvp({
    required String participantId,
    required String participantName,
    required RsvpStatus status,
    int guestCount = 0,
  }) async {
    final idx = rsvps.indexWhere((r) => r.participantId == participantId);
    RsvpEntry entry;
    if (idx >= 0) {
      entry = rsvps[idx].copyWith(
        status: status,
        guestCount: guestCount,
        respondedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      rsvps[idx] = entry;
    } else {
      entry = RsvpEntry(
        id: const Uuid().v4(),
        gameId: gameId,
        participantId: participantId,
        participantName: participantName,
        status: status,
        guestCount: guestCount,
        respondedAt: DateTime.now(),
      );
      rsvps.add(entry);
    }
    await _persist();
  }

  String rsvpSummary() {
    final going = rsvps.where((r) => r.status is RsvpGoing).length;
    final maybe = rsvps.where((r) => r.status is RsvpMaybe).length;
    final notGoing = rsvps.where((r) => r.status is RsvpNotGoing).length;
    return '$going going, $maybe maybe, $notGoing not going';
  }

  int confirmedCount() {
    return rsvps.where((r) =>
      r.status is RsvpGoing || r.status is RsvpMaybe
    ).length;
  }

  Future<void> _persist() async {
    await _storage.set('rsvps_$gameId', {'items': rsvps.map((e) => e.toJson()).toList()});
  }
}
