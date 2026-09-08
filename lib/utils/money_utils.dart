/// Money utilities — all tournament and cash-game monetary values are stored
/// and computed in INTEGER CENTS to eliminate floating-point rounding errors.
///
/// Rounding rule: ROUND HALF UP (ties go away from zero) — the standard
/// convention for financial calculations in tournament-prize contexts.
///
/// Architecture:
///   - Domain layer holds amounts as `int` cents (e.g. $150.00 = 15000 cents).
///   - Firestore boundary: READ converts num → int cents via [toCentsFromNum];
///     WRITE converts int cents → double dollars via [toDollars] only when the
///     existing Firestore schema requires a double (cash game fields).
///   - UI layer calls [formatCurrency] / [formatCurrencyDollars] for display.
class MoneyUtils {
  MoneyUtils._();

  // ── Conversion helpers ────────────────────────────────────────────────────

  /// Converts a dollar amount (double) to integer cents, rounding half-up.
  ///
  /// Example: toCents(149.995) == 15000  (rounds 149.995 → 150.00 → 15000)
  static int toCents(double dollars) => (dollars * 100).round();

  /// Converts a raw num (e.g. from Firestore) to integer cents.
  /// Accepts int (already-dollar int), double (dollar double), or any num.
  static int toCentsFromNum(num value) => (value * 100).round();

  /// Converts integer cents back to double dollars (use ONLY at the
  /// Firestore write boundary or for display).
  static double toDollars(int cents) => cents / 100.0;

  // ── Arithmetic ────────────────────────────────────────────────────────────

  /// Returns [pct] percent of [cents], rounding half-up.
  ///
  /// Example: percentOf(15000, 10) == 1500   ($150 × 10% = $15.00)
  ///          percentOf(16500, 10) == 1650   ($165 × 10% = $16.50)
  ///          percentOf(16666, 33) == 5500   ($166.66 × 33% ≈ $55.00)
  static int percentOf(int cents, int pct) => (cents * pct + 50) ~/ 100;

  /// Splits [totalCents] as evenly as possible into [n] parts, rounding
  /// remainders into the first part(s).
  ///
  /// Guarantees: sum of parts == totalCents.
  static List<int> splitEvenly(int totalCents, int n) {
    if (n <= 0) return [];
    final base = totalCents ~/ n;
    final remainder = totalCents % n;
    return [
      for (var i = 0; i < n; i++) base + (i < remainder ? 1 : 0),
    ];
  }

  // ── Display ───────────────────────────────────────────────────────────────

  /// Formats integer cents as a plain number with 2 decimal places.
  /// No currency symbol — spec §2.4 requires symbol-free display.
  ///
  /// Example: formatCurrency(15000) == '150.00'
  ///          formatCurrency(5)      == '0.05'
  static String formatCurrency(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final remainder = abs % 100;
    return '$sign$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  /// Formats a dollar double as a plain number (display only — never use
  /// double for intermediate calculations).
  ///
  /// Example: formatCurrencyDollars(150.0) == '150.00'
  static String formatCurrencyDollars(double dollars) =>
      formatCurrency(toCents(dollars));

  /// Signed display string, e.g. '+15.00' / '-5.00'.
  static String formatSigned(int cents) {
    final sign = cents >= 0 ? '+' : '-';
    return '$sign${formatCurrency(cents.abs())}';
  }
}
