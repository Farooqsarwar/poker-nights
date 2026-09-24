import '../models/live_game.dart';
import 'sanitization.dart';

/// Shared validation for tournament event settings.
///
/// The union of the creation wizard's step-1 / step-3 checks
/// (`create_tournament_screen.dart`) and the edit form's save-time checks
/// (`invitation_screen.dart`), lifted into one pure function so the shared
/// [EventSettingsForm] renders the same inline errors on every screen.
///
/// Returns a `{ fieldName: message }` map keyed by the same names the wizard
/// writes into its `_errors` map (name, location, date, time, buyIn,
/// koAmount, rebuyLimit, orgPct), so an inline field can display its own
/// error directly. An empty map means valid.
///
/// [`now`] exists so tests can pin the clock; it defaults to `DateTime.now()`.
Map<String, String> validateEventSettings(GameSettings s, {DateTime? now}) {
  final errors = <String, String>{};
  final at = now ?? DateTime.now();

  final name = s.name.trim();
  if (name.isEmpty) {
    errors['name'] = 'Required';
  } else if (name.length > Sanitization.maxTournamentNameLength) {
    errors['name'] = 'Max ${Sanitization.maxTournamentNameLength} characters';
  }

  if (s.location.trim().length > Sanitization.maxLocationLength) {
    errors['location'] = 'Max ${Sanitization.maxLocationLength} characters';
  }

  final date = s.date.trim();
  if (date.isEmpty) {
    errors['date'] = 'Required';
  } else {
    final parsed = DateTime.tryParse(date);
    // `DateTime.parse` normalises overflow — '2026-13-45' silently becomes
    // 2027-02-14 — so an impossible date would otherwise sail through as a
    // valid future date. Re-formatting the parsed value and comparing is what
    // catches the rollover.
    if (parsed == null || _isoDate(parsed) != date) {
      errors['date'] = 'Invalid date format (YYYY-MM-DD)';
    } else {
      final today = DateTime(at.year, at.month, at.day);
      if (parsed.isBefore(today)) {
        errors['date'] = 'Date must be today or in the future';
      }
    }
  }

  final time = s.time.trim();
  if (time.isEmpty) {
    errors['time'] = 'Required';
  } else {
    final parts = time.split(':');
    if (parts.length != 2) {
      errors['time'] = 'Invalid time format (HH:MM)';
    } else {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        errors['time'] = 'Invalid time (HH:MM)';
      } else if (!errors.containsKey('date')) {
        // Spec §12.2: reject a past date AND a past time on today's date.
        // Skipped when the date already carries an error: a past date and a
        // "start time must be in the future" are one root cause, and flagging
        // both fields for it reads as two separate problems.
        final parsed = DateTime.tryParse(date);
        if (parsed != null) {
          final scheduled = DateTime(parsed.year, parsed.month, parsed.day, h, m);
          if (scheduled.isBefore(at)) {
            errors['time'] = 'Start time must be in the future';
          }
        }
      }
    }
  }

  if (s.buyIn <= 0) {
    errors['buyIn'] = 'Must be positive';
  }

  if (s.rebuys && s.rebuyLimit != null && s.rebuyLimit! < 0) {
    errors['rebuyLimit'] = 'Must be >= 0';
  }
  if (s.maxReEntries != null && s.maxReEntries! < 0) {
    errors['maxReEntries'] = 'Must be >= 0';
  }

  if (s.koEnabled && s.koAmount < 0) {
    errors['koAmount'] = 'Must be >= 0';
  }

  // Spec §7 / §18: "0-20%". The forms cap entry at 20; this is the backstop
  // the model's [GameSettings.effectiveOrganizerPct] backs with a clamp.
  if (s.organizerPct < 0 || s.organizerPct > GameSettings.maxOrganizerPct) {
    errors['orgPct'] = 'Must be 0-${GameSettings.maxOrganizerPct}';
  }

  return errors;
}

/// `YYYY-MM-DD` for [d], used to detect a date string that only parsed because
/// `DateTime` rolled its overflowing month or day forward.
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';