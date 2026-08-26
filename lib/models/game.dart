/// RSVP response options.
enum Rsvp {
  going,
  maybe,
  cant,
  goingPlus1,
  goingPlus2,
  goingPlus3,
  goingPlus4;

  String get label {
    switch (this) {
      case Rsvp.going:
        return 'Going';
      case Rsvp.maybe:
        return 'Maybe';
      case Rsvp.cant:
        return "Can't Come";
      case Rsvp.goingPlus1:
        return 'Going +1';
      case Rsvp.goingPlus2:
        return 'Going +2';
      case Rsvp.goingPlus3:
        return 'Going +3';
      case Rsvp.goingPlus4:
        return 'Going +4';
    }
  }

  bool get isGoing => this == Rsvp.going || label.startsWith('Going +');

  int get guestCount {
    switch (this) {
      case Rsvp.goingPlus1:
        return 1;
      case Rsvp.goingPlus2:
        return 2;
      case Rsvp.goingPlus3:
        return 3;
      case Rsvp.goingPlus4:
        return 4;
      default:
        return 0;
    }
  }
}

/// A player (member or guest) registered against a game.
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.isGuest,
    this.inviterId,
    this.guestSlot,
    this.rsvp,
    required this.checkedIn,
    required this.confirmed,
    required this.eliminated,
    this.eliminationPos,
    required this.rebuys,
    this.reEntries = 0,
    required this.hasAddOn,
    required this.knockouts,
    required this.table,
    required this.seat,
    required this.active,
  });

  final String id;
  final String name;
  final bool isGuest;
  final String? inviterId;
  final int? guestSlot;
  final Rsvp? rsvp;
  final bool checkedIn;
  final bool confirmed;
  final bool eliminated;
  final int? eliminationPos;
  final int rebuys;

  /// Number of re-entries taken (checklist 12-046) — recorded separately from
  /// the normal rebuy count.
  final int reEntries;

  final bool hasAddOn;
  final int knockouts;
  final int table;
  final int seat;
  final bool active;

  Player copyWith({
    String? name,
    Rsvp? rsvp,
    bool? checkedIn,
    bool? confirmed,
    bool? eliminated,
    int? eliminationPos,
    int? rebuys,
    int? reEntries,
    bool? hasAddOn,
    int? knockouts,
    int? table,
    int? seat,
    bool? active,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      isGuest: isGuest,
      inviterId: inviterId,
      guestSlot: guestSlot,
      rsvp: rsvp ?? this.rsvp,
      checkedIn: checkedIn ?? this.checkedIn,
      confirmed: confirmed ?? this.confirmed,
      eliminated: eliminated ?? this.eliminated,
      eliminationPos: eliminationPos ?? this.eliminationPos,
      rebuys: rebuys ?? this.rebuys,
      reEntries: reEntries ?? this.reEntries,
      hasAddOn: hasAddOn ?? this.hasAddOn,
      knockouts: knockouts ?? this.knockouts,
      table: table ?? this.table,
      seat: seat ?? this.seat,
      active: active ?? this.active,
    );
  }

  Player copyWithClearRsvp() {
    return Player(
      id: id,
      name: name,
      isGuest: isGuest,
      inviterId: inviterId,
      guestSlot: guestSlot,
      rsvp: null,
      checkedIn: checkedIn,
      confirmed: confirmed,
      eliminated: eliminated,
      eliminationPos: eliminationPos,
      rebuys: rebuys,
      reEntries: reEntries,
      hasAddOn: hasAddOn,
      knockouts: knockouts,
      table: table,
      seat: seat,
      active: active,
    );
  }
}

/// A chat message inside a group or game.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.timestamp,
    required this.deleted,
    this.pinned = false,
    this.gameId,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime timestamp;
  final bool deleted;

  /// True when the message is a system-pinned event card (published game,
  /// edit notice). Pinned messages render as a card and are not deletable by
  /// members.
  final bool pinned;

  /// Set on pinned event cards so the card can act on the specific game it
  /// announces (open it, show live RSVP counts, let people RSVP inline)
  /// instead of assuming whatever game happens to be "current" in the app.
  final String? gameId;

  ChatMessage copyWith({bool? deleted}) {
    return ChatMessage(
      id: id,
      authorId: authorId,
      authorName: authorName,
      body: body,
      timestamp: timestamp,
      deleted: deleted ?? this.deleted,
      pinned: pinned,
      gameId: gameId,
    );
  }
}

/// Status of a reserved guest slot under an inviter (user-flow spec §7.1:
/// Unclaimed, Reserved, Check-in Requested, Checked In, Cancelled).
enum GuestSlotStatus { unclaimed, reserved, checkInRequested, checkedIn, cancelled }

/// A named guest seat reserved through a "Going +N" RSVP. Slots are created
/// when the member RSVPs and are persisted until the event starts, so the
/// admin can see exactly which guest seats are still open (checklist 07-014).
class GuestSlot {
  const GuestSlot({
    required this.id,
    required this.inviterId,
    required this.slot,
    required this.status,
    this.guestName,
  });

  final String id;
  final String inviterId;

  /// 1-based guest seat number under the inviter (1..guestCount).
  final int slot;
  final String? guestName;
  final GuestSlotStatus status;

  bool get available => status == GuestSlotStatus.unclaimed;

  GuestSlot copyWith({String? guestName, GuestSlotStatus? status}) {
    return GuestSlot(
      id: id,
      inviterId: inviterId,
      slot: slot,
      guestName: guestName ?? this.guestName,
      status: status ?? this.status,
    );
  }
}

/// A poll inside a group.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.closed,
    required this.createdAt,
    this.multi = false,
  });

  final String id;
  final String question;
  final List<String> options;

  /// userId -> selected option(s). A single-choice poll stores one option per
  /// user; a multi-choice poll may store several (Tech spec §14.2).
  final Map<String, List<String>> votes;
  final bool closed;
  final DateTime createdAt;

  /// Whether members may select more than one option.
  final bool multi;

  int get totalVotes => votes.length;

  /// Vote count per option (works for single and multi choice polls).
  Map<String, int> optionCounts() {
    final counts = <String, int>{for (final o in options) o: 0};
    for (final chosen in votes.values) {
      for (final c in chosen) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return counts;
  }
}

/// An announcement broadcast during a live game.
class Announcement {
  const Announcement({
    required this.id,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String text;
  final DateTime timestamp;

  Announcement copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
  }) {
    return Announcement(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// An audit record of a system or administrator event.
class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.actor,
    required this.details,
  });

  final String id;
  final DateTime timestamp;
  final String type;
  final String actor;
  final String details;

  AuditRecord copyWith({
    String? id,
    DateTime? timestamp,
    String? type,
    String? actor,
    String? details,
  }) {
    return AuditRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      details: details ?? this.details,
    );
  }
}
