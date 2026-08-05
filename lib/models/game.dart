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
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime timestamp;
  final bool deleted;
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
  });

  final String id;
  final String question;
  final List<String> options;
  final Map<String, String> votes; // userId -> option
  final bool closed;
  final DateTime createdAt;

  int get totalVotes => votes.length;
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
}

