import 'dart:math';

/// Formatting helpers shared across the UI.
class Formatters {
  Formatters._();

  /// Chip COUNTS only: 12500 -> '12.5K', 1500000 -> '1.5M', 400 -> '400'.
  ///
  /// Never use this for money. Rounding an amount misstates it — a 1,250 prize
  /// pool rendered as "1.3K" and a 1,150 payout as "1.2K" — which breaks the
  /// exact reconciliation 14-024 expects a reader to be able to do. Use
  /// [prize] for anything denominated in buy-ins.
  static String chips(num n) {
    final value = n.round();
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final decimals = value % 1000 == 0 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(decimals)}K';
    }
    return value.toString();
  }

  /// Money, exactly as it is, with thousands separators and no currency
  /// symbol (04-013, User Flow section 3.4: display "15" or "15 + 5", never
  /// a symbol). Amounts are never abbreviated.
  ///
  /// Named [prize] rather than `money` because the cash module already owns a
  /// two-argument `money(currency, amount)` for its decimal values; this one
  /// is for whole-unit tournament figures (prize pool, payouts).
  static String prize(num n) {
    final v = n.round();
    final digits = v.abs().toString();
    final sb = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
      sb.write(digits[i]);
    }
    return sb.toString();
  }

  /// 725 -> '12:05'.
  static String time(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
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

  /// Format money without currency symbol, always 2 decimals.
  /// [amount] is a double dollar value (cash game UI legacy — prefer [moneyCents]).
  static String money(String currency, double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Format money from integer cents without currency symbol.
  /// E.g. moneyCents('', 15000) == '150.00'
  static String moneyCents(String currency, int cents) {
    final sign = (cents < 0 && cents > -100) ? '-' : '';
    final dollars = cents ~/ 100;
    final remainder = (cents % 100).abs();
    return '$sign$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  /// Signed money without currency symbol, e.g. '+20.00' / '-5.00'.
  /// [amount] is a double dollar value (cash game UI legacy — prefer [signedMoneyCents]).
  static String signedMoney(String currency, double amount) {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign${amount.abs().toStringAsFixed(2)}';
  }

  /// Signed money from integer cents, e.g. '+20.00' / '-5.00'.
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
