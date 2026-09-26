import '../core/network/api_client.dart';
import 'coupon_model.dart';

/// One coupon that belongs to **this user**.
///
/// Source: `GET /api/v1/discounts/apply/my_coupons/`.
///
/// ## The shape is not a DRF page
///
/// The live endpoint answers the app's own envelope with a **bare list**:
/// `{"success": true, "data": []}`. There is no `count` / `results`, so it must
/// never be read with `PagedResult.from` — an empty body would then be treated as
/// a single blank coupon and the «هدیه‌ها» screen would show one empty card
/// instead of its empty state.
///
/// ## Why it is a "gift"
///
/// A coupon reaches this list because an admin attached it to the account (or it
/// was granted for a purchase), which is exactly what the user calls a gift. The
/// distinction matters for presentation: the screen shows the *benefit*, not the
/// raw record, so a 100 % coupon has to be readable as "free".
class Gift {
  const Gift({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.discountType = DiscountType.fixed,
    this.discountValue = 0,
    this.maxDiscountAmount,
    this.minOrderAmount = 0,
    this.usageLimit = 0,
    this.usagePerUser = 0,
    this.usedCount = 0,
    this.usedPercentage = 0,
    this.isFirstPurchaseOnly = false,
    this.specificCourses = const <int>[],
    this.specificCategories = const <int>[],
    this.excludeCourses = const <int>[],
    this.status = '',
    this.isActive = true,
    this.specificUser,
    this.validFrom,
    this.validUntil,
    this.createdAt,
  });

  final int id;

  /// The string the user types at checkout. Always shown, and copyable.
  final String code;

  final String title;
  final String? description;

  /// `percent` | `fixed` — see [DiscountType].
  final String discountType;
  final int discountValue;

  /// Upper bound on a percentage discount. `null` / `0` means no cap.
  final int? maxDiscountAmount;

  /// The smallest order the coupon applies to. `0` means no minimum.
  final int minOrderAmount;

  /// `0` means unlimited.
  final int usageLimit;

  /// `0` means unlimited.
  final int usagePerUser;

  final int usedCount;
  final int usedPercentage;

  /// Applies only to a user's first ever purchase.
  final bool isFirstPurchaseOnly;

  /// Restricts the coupon to these course ids. Empty means "every course".
  final List<int> specificCourses;

  /// Restricts the coupon to these category ids. Empty means "every category".
  final List<int> specificCategories;

  /// Courses the coupon explicitly does **not** apply to.
  final List<int> excludeCourses;

  /// The backend's own status string, when it sends one.
  final String status;

  /// The admin's on/off switch. A coupon can be inside its validity window and
  /// still be inactive.
  final bool isActive;

  /// The account this coupon was granted to. `null` means the coupon is public
  /// (anyone can use the code), which also means it is **not** a gift and must
  /// not raise a notification.
  final int? specificUser;

  /// Start of the coupon's window. See [validUntil] for the field-name warning.
  final DateTime? validFrom;

  /// End of the coupon's window.
  ///
  /// ⚠️ The live `Coupon` schema names this **`valid_until`**. It does *not* send
  /// `end_date`, so reading that key leaves this null and both «اعتبار تا …» on
  /// the card and the "one hour left" reminder become dead code.
  final DateTime? validUntil;

  final DateTime? createdAt;

  /// A coupon is a gift only when an admin attached it to a single account.
  bool get isPersonal => specificUser != null;

  /// A `percent` coupon of 100 % makes the course free.
  bool get isHundredPercent =>
      discountType == DiscountType.percent && discountValue >= 100;

  /// The coupon is spent: every allowed use has been used up.
  bool get isExhausted {
    if (usageLimit > 0 && usedCount >= usageLimit) return true;
    if (usagePerUser > 0 && usedCount >= usagePerUser) return true;
    return false;
  }

  /// The coupon's own clock has run out.
  bool get isExpired {
    final DateTime? end = validUntil;
    if (end == null) return false;
    return !DateTime.now().isBefore(end);
  }

  /// How long is left before [validUntil]. `null` when the coupon never expires.
  ///
  /// Negative once the coupon has lapsed, so callers can tell "about to expire"
  /// from "already gone" without a second clock read.
  Duration? get timeLeft {
    final DateTime? end = validUntil;
    if (end == null) return null;
    return end.difference(DateTime.now());
  }

  /// True while the coupon is inside its final hour — the reminder window.
  ///
  /// Used by the notification centre: exactly one "expiring soon" alert should be
  /// raised per coupon, and only while it is still usable.
  bool get isExpiringWithinAnHour {
    final Duration? left = timeLeft;
    if (left == null) return false;
    if (left.isNegative) return false;
    return left <= const Duration(hours: 1);
  }

  /// True once an admin switched the coupon on and it has not lapsed or been
  /// spent. This is the state that raises the "your code is now active" alert.
  bool get isActiveNow {
    if (!isActive || isExpired || isExhausted) return false;
    final DateTime? start = validFrom;
    if (start != null && DateTime.now().isBefore(start)) return false;
    final String normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return normalized == 'active' || normalized == 'فعال';
  }

  /// Still usable: not spent, not expired, and not switched off by an admin.
  bool get isUsable {
    if (isExhausted || isExpired) return false;
    final String normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return normalized == 'active' || normalized == 'فعال';
  }

  /// `20%` / `۵۰٬۰۰۰ تومان` — the headline figure, without the wrapper words.
  String get benefitLabel {
    if (discountType == DiscountType.percent) {
      return '$discountValue٪';
    }
    return _grouped(discountValue);
  }

  /// The full sentence under [benefitLabel]: what it does and under what limits.
  String get benefitDescription {
    if (isHundredPercent) return 'این کد دوره را رایگان می‌کند.';

    if (discountType == DiscountType.percent) {
      final int? cap = maxDiscountAmount;
      if (cap != null && cap > 0) {
        return 'تا سقف ${_grouped(cap)} تومان تخفیف';
      }
      return 'تخفیف روی مبلغ سفارش';
    }

    return 'تخفیف نقدی روی مبلغ سفارش';
  }

  /// The constraints, as short Persian chips. Empty means unrestricted.
  List<String> get conditions {
    final List<String> out = <String>[];

    if (minOrderAmount > 0) {
      out.add('حداقل خرید ${_grouped(minOrderAmount)} تومان');
    }

    if (isFirstPurchaseOnly) {
      out.add('فقط اولین خرید');
    }

    if (specificCourses.isNotEmpty) {
      out.add('فقط روی ${specificCourses.length} دوره مشخص');
    } else if (specificCategories.isNotEmpty) {
      out.add('فقط روی دسته‌بندی‌های مشخص');
    } else if (excludeCourses.isNotEmpty) {
      out.add('روی ${excludeCourses.length} دوره اعمال نمی‌شود');
    } else {
      out.add('روی همه دوره‌ها');
    }

    if (usagePerUser > 0) {
      out.add('$usagePerUser بار برای هر کاربر');
    }

    final DateTime? end = validUntil;
    if (end != null) {
      out.add('تا ${_persianDate(end)}');
    }

    return out;
  }

  /// `HolidayCoupon` -> `GET /api/v1/discounts/apply/my_coupons/`
  factory Gift.fromJson(Map<String, dynamic> json) {
    final List<int> courses = Json.asIntList(json['specific_courses']);
    final List<int> categories = Json.asIntList(json['specific_categories']);
    final List<int> excluded = Json.asIntList(json['exclude_courses']);

    return Gift(
      id: Json.asInt(json['id']) ?? 0,
      code: Json.asString(json['code']) ?? '',
      title: Json.asString(json['title']) ?? 'کد تخفیف',
      description: Json.asString(json['description']),
      discountType: DiscountType.fromValue(
        Json.asString(json['discount_type']),
      ),
      discountValue: Json.asInt(json['discount_value']) ?? 0,
      maxDiscountAmount: Json.asInt(json['max_discount_amount']),
      minOrderAmount: Json.asInt(json['min_order_amount']) ?? 0,
      usageLimit: Json.asInt(json['usage_limit']) ?? 0,
      usagePerUser: Json.asInt(json['usage_per_user']) ?? 0,
      usedCount: Json.asInt(json['used_count']) ?? 0,
      usedPercentage: Json.asInt(json['used_percentage']) ?? 0,
      isFirstPurchaseOnly: Json.asBool(json['is_first_purchase_only']),
      specificCourses: courses,
      specificCategories: categories,
      excludeCourses: excluded,
      status: Json.asString(json['status']) ?? '',
      // A coupon row without an explicit flag is treated as on — the list only
      // ever contains coupons the backend already considers relevant.
      isActive: Json.asBool(json['is_active'], fallback: true),
      specificUser: Json.asInt(json['specific_user']),
      validFrom: Json.asDate(json['valid_from']),
      validUntil: Json.asDate(json['valid_until']),
      createdAt: Json.asDate(json['created_at']),
    );
  }

  /// `1234567` -> `۱٬۲۳۴٬۵۶۷`, so an amount reads the way a Persian receipt
  /// does. Kept local to the model so both the gift card and any caller agree.
  static String _grouped(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('٬');
      buffer.write(_toPersianDigit(digits[i]));
    }

    return '${value < 0 ? '-' : ''}$buffer';
  }

  static String _toPersianDigit(String digit) {
    const List<String> persian = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
    ];
    final int index = int.tryParse(digit) ?? -1;
    return index >= 0 ? persian[index] : digit;
  }

  static String _persianDate(DateTime date) {
    // The backend sends a Gregorian date, so it is printed as one — with Persian
    // digits, because every other number in the app is.
    return '${_grouped(date.year)}/${_grouped(date.month)}/${_grouped(date.day)}';
  }
}
