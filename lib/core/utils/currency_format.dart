/// Money formatting shared by the cart, the orders screens and the checkout
/// dialogs.
///
/// The app has no `intl` dependency and the backend sends plain integers, so the
/// grouping is done by hand. Digits stay ASCII (`2,500,000 تومان`) — that is
/// what every existing screen shows and what the tests assert on.
library;

/// `2500000` -> `2,500,000 تومان`, and `0` -> `رایگان`.
///
/// A zero amount is never rendered as `0 تومان`: in this app it always means
/// "nothing to pay" (a free course, or a coupon that covered the whole price).
String formatToman(int amount) {
  if (amount <= 0) return 'رایگان';
  return '${formatNumber(amount)} تومان';
}

/// `2500000` -> `2,500,000` — thousands separators, no currency suffix.
///
/// Used for line items and breakdown rows where the unit is already implied.
String formatNumber(int value) {
  final bool negative = value < 0;
  final String digits = value.abs().toString();

  final List<String> buffer = <String>[];
  int count = 0;

  for (int i = digits.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.insert(0, ',');
    buffer.insert(0, digits[i]);
    count++;
  }

  return '${negative ? '-' : ''}${buffer.join()}';
}
