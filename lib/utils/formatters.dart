import 'dart:math';

/// Formatting helpers shared across the UI.
class Formatters {
  Formatters._();

  /// The level-change sentence, in the words the voice uses (Addendum 2 #2):
  /// "Level 4. Blinds 5 and 10, ante 10." One place, so the screen-reader live
  /// region, the announcement feed and the spoken line cannot drift apart.
  static String levelSpoken(int level, int sb, int bb, [int? ante]) =>
      'Level $level. Blinds $sb and $bb${ante != null ? ', ante $ante' : ''}.';

  /// Chip counts and blinds as plain integers with thousands separators:
  /// 12500 -> '12,500' (Build Spec E16). Nothing is abbreviated: "k" is only for
  /// the values printed on a chip swatch, and never for money — rounding an
  /// amount misstates it (a 1,250 prize pool as "1.3K"), which breaks the exact
  /// reconciliation 14-024 expects a reader to be able to do.
  static String chips(num n) {
    final v = n.round();
    return '${v < 0 ? '-' : ''}${_grouped(v.abs())}';
  }

  /// The symbol this phone prints in front of money, chosen in Settings under
  /// ON THIS PHONE (F2). Empty by default: the spec keeps money plain ("15" or
  /// "15 + 5") unless the person asks for a symbol, and it is never shared
  /// with the group -- it changes how this device shows amounts, not the amounts.
  /// Chip counts never carry it.
  static String currencySymbol = '';

  static String _grouped(int nonNegative) {
    final digits = nonNegative.toString();
    final sb = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
      sb.write(digits[i]);
    }
    return sb.toString();
  }

  /// Money, exactly as it is, with thousands separators. No currency symbol
  /// unless this phone chose one (04-013, User Flow section 3.4: display "15"
  /// or "15 + 5"). Amounts are never abbreviated.
  ///
  /// Named [prize] rather than `money` because the cash module already owns a
  /// two-argument `money(currency, amount)` for its decimal values; this one
  /// is for whole-unit tournament figures (prize pool, payouts).
  static String prize(num n) {
    final v = n.round();
    return '${v < 0 ? '-' : ''}$currencySymbol${_grouped(v.abs())}';
  }

  /// 725 -> '12:05'; over an hour 4800 -> '1:20:00' (Build Spec E16).
  static String time(int seconds) {
    final h = seconds ~/ 3600;
    final s = (seconds % 60).toString().padLeft(2, '0');
    if (h > 0) {
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 200 -> '3h 20m'.
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// 900000 -> '15m ago'; 7200000 -> '2h ago'.
  static String relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    final m = diff.inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    return '${h ~/ 24}d ago';
  }

  /// 3.5 -> '3.5h'
  static String hours(double h) {
    if (h == h.roundToDouble()) return '${h.round()}h';
    return '${h}h';
  }

  /// Format money without currency symbol: whole units unless the amount has
  /// cents (Build Spec E16). [amount] is a double dollar value (cash game UI
  /// legacy — prefer [moneyCents]).
  static String money(String currency, double amount) {
    return moneyCents(currency, (amount * 100).round());
  }

  /// Format money from integer cents without currency symbol, with thousands
  /// separators. Whole units unless there are cents:
  /// moneyCents('', 15000) == '150', moneyCents('', 15025) == '150.25'.
  static String moneyCents(String currency, int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final whole = '$currencySymbol${_grouped(abs ~/ 100)}';
    final remainder = abs % 100;
    if (remainder == 0) return '$sign$whole';
    return '$sign$whole.${remainder.toString().padLeft(2, '0')}';
  }

  /// Signed money without currency symbol, e.g. '+20' / '-5.50'.
  /// [amount] is a double dollar value (cash game UI legacy — prefer [signedMoneyCents]).
  static String signedMoney(String currency, double amount) {
    return signedMoneyCents(currency, (amount * 100).round());
  }

  /// Signed money from integer cents, e.g. '+20' / '-5.50'.
  static String signedMoneyCents(String currency, int cents) {
    final sign = cents >= 0 ? '+' : '-';
    return '$sign${moneyCents(currency, cents.abs())}';
  }

  /// 'en-GB' style short date+time, e.g. '7 Aug 2026, 20:00'.
  static String shortDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hh:$mm';
  }

  /// 'Fri 3 Oct · 18:00', the form the RSVP deadline line uses (spec C3).
  static String weekdayDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} · $hh:$mm';
  }

  /// Average stack rounded to nearest 100.
  static int averageStack(int totalChips, int remaining) {
    if (remaining <= 0) return 0;
    return (totalChips / remaining / 100).round() * 100;
  }

  /// Technical section 22: "Tournament codes are random."
  ///
  /// This used to be an LCG seeded from `DateTime.now().millisecondsSinceEpoch`,
  /// which made every code reproducible offline from an approximate creation
  /// time. Worse, `publicCode` and `tvCode` were consecutive draws from one
  /// process-wide stream, so holding either one revealed the other, and
  /// `_seed % max` was modulo-biased across a 31-character alphabet.
  static final _random = Random.secure();

  /// 6-character invite code avoiding ambiguous characters (I, L, O, 0, 1).
  static String generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(chars[_random.nextInt(chars.length)]);
    }
    return sb.toString();
  }

  /// Unguessable document id (Technical section 22 / checklist 19-007:
  /// "Guessing sequential IDs does not expose another group or game").
  /// `<prefix>-<22 chars>` from a cryptographic source, replacing the old
  /// `<prefix>-<epoch_ms>` ids that spanned only a few million values for a
  /// given evening.
  static String secureId(String prefix) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final sb = StringBuffer(prefix)..write('-');
    for (var i = 0; i < 22; i++) {
      sb.write(chars[_random.nextInt(chars.length)]);
    }
    return sb.toString();
  }
}
