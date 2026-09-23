import '../models/live_game.dart';
import '../models/tournament.dart';
import 'tournament_engine.dart';

/// What an independent recomputation of the structure concluded.
enum StructureVerdict {
  /// The stored structure is exactly what the engine produces from the
  /// tournament's own settings.
  verified,

  /// It is not, and nothing legitimate explains the difference.
  mismatch,

  /// Not checkable here — missing inputs, or an engine version that did not
  /// produce it. Deliberately distinct from [mismatch]: "I cannot tell" and
  /// "this is wrong" must never be shown as the same thing.
  cannotVerify,
}

/// The result of auditing one stored structure.
class StructureAudit {
  const StructureAudit.verified()
      : verdict = StructureVerdict.verified,
        differences = const [],
        reason = null;

  const StructureAudit.mismatch(this.differences)
      : verdict = StructureVerdict.mismatch,
        reason = null;

  const StructureAudit.cannotVerify(this.reason)
      : verdict = StructureVerdict.cannotVerify,
        differences = const [];

  final StructureVerdict verdict;

  /// Plain-language description of each difference found.
  final List<String> differences;

  /// Why the audit could not run. Null unless [verdict] is
  /// [StructureVerdict.cannotVerify].
  final String? reason;

  bool get isVerified => verdict == StructureVerdict.verified;
  bool get isMismatch => verdict == StructureVerdict.mismatch;
}

/// Independent verification that a tournament's structure is the one the
/// engine actually produces (addendum §7, acceptance criterion 15).
///
/// The criterion asks that AI generation is "not trusted solely to the
/// client". The specification's own answer is a server, and without Cloud
/// Functions there is nowhere for one to run. This is the answer that needs no
/// server: **every other device checks the host's work.**
///
/// It is possible because the engine is deterministic — no random source, no
/// clock, no shuffle — so the same settings always produce the same structure,
/// on any device. The generation inputs are already stored in [GameSettings],
/// so a player's phone, the TV and an organizer's tablet can each regenerate
/// and compare. The host's structure stops being the host's word.
///
/// What each layer contributes:
///
///  * Security rules — running on Google's servers — stop the settings being
///    rewritten after the fact to match a doctored structure.
///  * This check, on every device, stops a doctored structure matching honest
///    settings.
///
/// Tamper with either and every device in the room disagrees.
///
/// **Its limits, stated plainly.** This is detection, not prevention: a host
/// can still write a bad structure, but nobody's device will accept it
/// quietly. It is also not "server-side generation" and does not claim to be —
/// §7's wording still wants a server. What it satisfies is criterion 15's
/// actual words, that generation is not trusted *solely* to one client.
abstract final class StructureVerification {
  /// Recomputes [game]'s structure from its own settings and compares.
  static StructureAudit audit(LiveGame game) {
    final s = game.settings;
    final stored = game.structure;

    if (stored.levels.isEmpty) {
      return const StructureAudit.cannotVerify('no structure to check');
    }
    if (s.chipSet.isEmpty) {
      return const StructureAudit.cannotVerify(
        'the chip set is not on this device',
      );
    }
    if (s.players < 2) {
      return const StructureAudit.cannotVerify('no head count recorded');
    }

    final TournamentStructure fresh;
    try {
      fresh = TournamentEngine.generate(
        TournamentParams(
          players: s.players,
          durationHours: s.durationHours,
          buyIn: s.buyIn,
          chipSet: s.chipSet,
          rebuys: s.rebuys,
          rebuysCloseLevel: s.rebuysCloseLevel,
          rebuyCloseChosenByOrganizer: s.rebuyCloseChosenByOrganizer,
          reEntry: s.reEntry,
          addOn: s.addOn,
          anteEnabled: s.anteEnabled,
          anteAfterLevel: s.anteAfterLevel,
          anteStyle: s.anteStyle,
          koEnabled: s.koEnabled,
          koAmount: s.koAmount,
          // Zero deliberately. The organizer's cut is private (§23) and is
          // stripped from every non-host projection, so a player could not
          // supply it — and it affects only the prize split, never a single
          // blind, stack or chip. Verifying the structure must not require
          // seeing a figure players are not allowed to see.
          organizerPct: 0,
          rebuyCost: s.rebuyCost,
          addOnCost: s.addOnCost,
          breaks: s.breaks,
          // Generation inputs, so they belong in the recomputation. Unlike the
          // organizer cut above these are not private — they are printed on
          // the structure sheet every player can see — and leaving them out
          // would make an honest custom structure fail its own audit.
          expectedRebuys: s.expectedRebuys,
          expectedReEntries: s.expectedReEntries,
          expectedAddOns: s.expectedAddOns,
          rebuyChips: s.rebuyChips,
          reEntryChips: s.reEntryChips,
          addOnChips: s.addOnChips,
          levelDurationMins: s.levelDurationMins,
          // Costs nothing here — the audit below compares stacks, blinds and
          // breaks, never the prize split — but the engine consumes it, so
          // leaving it out would make this the one call that reruns the
          // generator on settings the host did not choose.
          payoutShape: s.payoutShape,
        ),
      );
    } catch (e) {
      return StructureAudit.cannotVerify('the engine could not rerun: $e');
    }

    final differences = <String>[];

    if (stored.startingStack != fresh.startingStack) {
      differences.add(
        'Starting stack is ${stored.startingStack}; these settings produce '
        '${fresh.startingStack}.',
      );
    }

    if (stored.levelDuration != fresh.levelDuration) {
      differences.add(
        'Levels run ${stored.levelDuration} minutes; these settings produce '
        '${fresh.levelDuration}.',
      );
    }

    // Manually edited levels are a documented, marked, legitimate change
    // (§11, §29) — the whole point of the marker is that a human chose them.
    // Comparing them would report every honest edit as tampering, which would
    // train people to ignore the warning.
    final freshByLevel = {for (final l in fresh.levels) l.level: l};
    for (final l in stored.levels) {
      if (l.manuallyEdited) continue;
      final f = freshByLevel[l.level];
      if (f == null) continue;
      if (l.sb != f.sb || l.bb != f.bb) {
        differences.add(
          'Level ${l.level} is ${l.sb}/${l.bb}; these settings produce '
          '${f.sb}/${f.bb}.',
        );
      } else if (l.ante != f.ante) {
        differences.add(
          'Level ${l.level} ante is ${l.ante ?? 'none'}; these settings '
          'produce ${f.ante ?? 'none'}.',
        );
      }
    }

    if (stored.breaks.length != fresh.breaks.length) {
      differences.add(
        '${stored.breaks.length} break(s) scheduled; these settings produce '
        '${fresh.breaks.length}.',
      );
    } else {
      for (var i = 0; i < stored.breaks.length; i++) {
        final a = stored.breaks[i];
        final b = fresh.breaks[i];
        if (a.afterLevel != b.afterLevel || a.durationMins != b.durationMins) {
          differences.add(
            'A break sits after level ${a.afterLevel} for ${a.durationMins} '
            'minutes; these settings produce level ${b.afterLevel} for '
            '${b.durationMins}.',
          );
        }
      }
    }

    // Cap what is reported. A structure that differs everywhere is one fact,
    // not forty, and a wall of text is read as noise.
    if (differences.length > 5) {
      final shown = differences.take(5).toList()
        ..add('…and ${differences.length - 5} more.');
      return StructureAudit.mismatch(shown);
    }

    return differences.isEmpty
        ? const StructureAudit.verified()
        : StructureAudit.mismatch(differences);
  }
}
