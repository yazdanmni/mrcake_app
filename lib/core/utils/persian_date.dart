/// Gregorian → Jalali (Solar Hijri) conversion for the dates the API sends.
///
/// The backend answers `created_at` / `payment_time` as ISO-8601 **Gregorian**
/// timestamps (`2026-09-24T11:03:07.123456Z`). The app is Persian, so those raw
/// strings must never reach the screen — «سفارش های من» shows `1405/07/02`.
///
/// The conversion is the standard arithmetic algorithm (no lookup tables, no
/// dependency): it is exact for the whole range the backend can produce and
/// needs no `intl` package.
class PersianDate {
  PersianDate._();

  /// `1405/07/02`, or `1405/07/02 - 14:35` when [withTime] is true.
  ///
  /// [date] is converted to local time first, so an order placed at 23:50 in
  /// Tehran is not dated to the previous day because the server stored UTC.
  static String format(DateTime date, {bool withTime = false}) {
    final local = date.toLocal();
    final (int jy, int jm, int jd) = toJalali(
      local.year,
      local.month,
      local.day,
    );

    final String base =
        '$jy/${_two(jm)}/${_two(jd)}';

    if (!withTime) return base;

    return '$base - ${_two(local.hour)}:${_two(local.minute)}';
  }

  /// Same as [format], but `—` when [date] is null.
  ///
  /// `payment_time` is nullable on the API (`null` until the order is paid), and
  /// an empty cell is better than a wrong date.
  static String formatOrDash(DateTime? date, {bool withTime = false}) {
    if (date == null) return '—';
    return format(date, withTime: withTime);
  }

  /// Converts a Gregorian date to Jalali, returning `(year, month, day)`.
  static (int, int, int) toJalali(int gy, int gm, int gd) {
    const List<int> daysInMonths = <int>[
      0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,
    ];

    int jy = gy <= 1600 ? 0 : 979;
    int year = gy - (gy <= 1600 ? 621 : 1600);

    final int leapBase = gm > 2 ? year + 1 : year;

    int days =
        (365 * year) +
        ((leapBase + 3) ~/ 4) -
        ((leapBase + 99) ~/ 100) +
        ((leapBase + 399) ~/ 400) -
        80 +
        gd +
        daysInMonths[gm - 1];

    jy += 33 * (days ~/ 12053);
    days %= 12053;

    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final int jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    final int jd = 1 + (days < 186 ? (days % 31) : ((days - 186) % 30));

    return (jy, jm, jd);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
