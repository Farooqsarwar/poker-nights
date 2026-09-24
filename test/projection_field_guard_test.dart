import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tripwire on `LiveGame`'s shape (§23).
///
/// `projectionFor` scrubs by omission: it calls `copyWith` and overrides the
/// fields that must not travel. Everything it does not name rides through
/// untouched. That is a reasonable way to write it and a dangerous way to
/// maintain it — a field added to `LiveGame` months from now reaches every
/// player, guest and TV screen with nobody having decided that it should.
///
/// It has already happened once: `payments` was added, rode through
/// `copyWith`, and handed members the rebuy and add-on totals §23 explicitly
/// withholds, plus the gross, to anyone willing to sum a list.
///
/// So this test fails when the shape changes. It is not checking that the new
/// field is wrong — it cannot know — only that a human looked at it.
void main() {
  /// Every field `LiveGame`'s constructor accepts, as declared.
  ///
  /// When this test fails, decide which of the two the new field is and then
  /// update this list:
  ///
  ///  * **Public** — every viewer may see it (the level, the clock, who is
  ///    still in). Nothing more to do.
  ///  * **Private** — it belongs to the host (money, identities, anything
  ///    derived from what people paid). Add an override to `projectionFor` in
  ///    `lib/services/projections.dart` AND a case to
  ///    `projection_boundary_test.dart` proving it does not travel.
  const known = <String>{
    // Identity and wiring — public.
    'id', 'groupId', 'publicCode', 'tvCode', 'revision',
    // Play state — public, this is what the screens are for.
    'settings', 'structure', 'status', 'currentLevel', 'timerRunning',
    'secondsRemaining', 'players', 'totalChipsInPlay', 'finishOrder',
    'levelEndTime', 'startedAt', 'actualDurationMins', 'speedRecommendation', 'dealerPlayerId',
    'originalLevels', 'shotClock',
    // Social — chat is gated by role inside the projection.
    'chat', 'announcements',
    // Host-side flow. Scrubbed or harmless; each already has a decision.
    'auditHistory', 'pendingGuests', 'guestSlots', 'rebuyRequests',
    'addOnRequests', 'settlementConfirmed', 'seatingConfirmed',
    'checkInClosed', 'structureConfirmed', 'finalTableRedrawCompleted',
    'changeLog', 'organizerIds',
    // Money. PRIVATE — stripped in projectionFor, asserted next door.
    'payments',
    // Concurrency bookkeeping — never rendered.
    'lastIdempotencyKey', 'editorDeviceId', 'editorClaimedAt',
    'audioMasterDeviceId',
  };

  test('no field joins LiveGame without a projection decision', () {
    final source = File('lib/models/live_game.dart').readAsStringSync();

    final start = source.indexOf('  const LiveGame({');
    expect(
      start,
      greaterThan(-1),
      reason: 'the constructor moved or was renamed — this guard needs '
          'updating before it can protect anything',
    );
    final end = source.indexOf('});', start);
    expect(end, greaterThan(start));

    final body = source.substring(start, end);
    final declared = RegExp(r'this\.(\w+)')
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      declared,
      isNotEmpty,
      reason: 'parsed nothing — the guard is broken, not the model',
    );

    final added = declared.difference(known);
    final removed = known.difference(declared);

    expect(
      added,
      isEmpty,
      reason: 'New LiveGame field(s): ${added.join(', ')}.\n'
          'Decide whether each is public or private. If private, override it '
          'in projectionFor (lib/services/projections.dart) and assert it in '
          'projection_boundary_test.dart. Then add it to `known` here.\n'
          'This is the check that `payments` did not have.',
    );

    expect(
      removed,
      isEmpty,
      reason: 'LiveGame no longer has: ${removed.join(', ')}. Remove them '
          'from `known`, and from projectionFor if they were scrubbed there.',
    );
  });
}
