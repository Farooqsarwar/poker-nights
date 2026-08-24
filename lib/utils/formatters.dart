/// Formatting helpers shared across the UI.
class Formatters {
  Formatters._();

  /// 12500 -> '12.5K', 1500000 -> '1.5M', 400 -> '400'.
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
    final dollars = cents ~/ 100;
    final remainder = (cents % 100).abs();
    return '$dollars.${remainder.toString().padLeft(2, '0')}';
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

  static final _random = _SimpleRng();

  /// 6-character invite code avoiding ambiguous characters.
  static String generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(chars[_random.nextInt(chars.length)]);
    }
    return sb.toString();
  }
}

class _SimpleRng {
  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

  int nextInt(int max) {
    _seed = (1103515245 * _seed + 12345) & 0x7fffffff;
    return _seed % max;
  }
}
