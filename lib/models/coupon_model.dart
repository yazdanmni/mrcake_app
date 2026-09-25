import '../core/network/api_client.dart';

class DiscountType {
  DiscountType._();

  static const String percent = 'percent';
  static const String fixed = 'fixed';

  static String fromValue(String? v) {
    switch (v?.toLowerCase()) {
      case 'percent':
      case 'percentage':
      case 'درصدی':
        return percent;
      case 'fixed':
      case 'amount':
      case 'mablaghi':
      case 'مبلغی':
        return fixed;
      default:
        return fixed;
    }
  }
}

/// Result of `POST /api/v1/discounts/apply/validate/` merged with any
/// additional amount that the caller already knows (the course price).
class CouponValidation {
  final bool valid;
  final String code;

  final String? discountType;
  final int discountValue;
  final int? maxDiscountAmount;
  final String? title;
  final String? description;

  /// The computed fields below are **not** returned by the validator
  /// endpoint.  They are computed client-side by
  /// `ShopRepository.validateCouponForAmount` so the UI can rely on a single
  /// typed result.
  final int originalAmount;
  final int discountAmount;
  final int finalAmount;

  const CouponValidation({
    required this.valid,
    required this.code,
    this.discountType,
    this.discountValue = 0,
    this.maxDiscountAmount,
    this.title,
    this.description,
    this.originalAmount = 0,
    this.discountAmount = 0,
    this.finalAmount = 0,
  });

  /// `true` when the coupon covers the full cart/course price.
  bool get isFree => finalAmount <= 0;

  /// Convenience: the coupon is a 100%-percent discount *OR* a fixed
  /// discount that equals/exceeds the original price.
  bool get is100Percent {
    if (discountType == DiscountType.percent && discountValue >= 100) {
      return true;
    }
    return discountAmount >= originalAmount && originalAmount > 0;
  }

  /// `true` when the validator actually returned usable numbers.
  ///
  /// `POST v1/discounts/apply/validate/` is documented with "no response body",
  /// so a successful call may decode to an empty map. In that case the coupon is
  /// accepted but its amount is unknown and the authoritative figures have to
  /// come from `POST v1/payments/orders/` (`total_amount`, `discount_amount`).
  bool get hasDiscountData => discountType != null && discountValue > 0;

  /// Builds a **failed** validation: the coupon was rejected by the API.
  factory CouponValidation.invalid(String code) => CouponValidation(
        valid: false,
        code: code,
      );

  /// [fallbackCode] is used when the API accepts the coupon but omits `code`
  /// from its payload, so the UI can still name the coupon the user typed.
  factory CouponValidation.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCode,
  }) {
    final code = Json.asString(json['code']) ?? '';
    return CouponValidation(
      valid: true,
      code: code.isEmpty ? (fallbackCode ?? '') : code,
      discountType: Json.asString(json['discount_type']),
      discountValue: Json.asInt(json['discount_value']) ?? 0,
      maxDiscountAmount: Json.asInt(json['max_discount_amount']),
      title: Json.asString(json['title']),
      description: Json.asString(json['description']),
    );
  }

  /// Returns a new instance with `originalAmount` / `discountAmount` /
  /// `finalAmount` populated using the typed coupon fields.
  CouponValidation applyToAmount(int amount) {
    final int original = amount < 0 ? 0 : amount;
    if (!valid || original == 0) {
      return CouponValidation(
        valid: valid,
        code: code,
        discountType: discountType,
        discountValue: discountValue,
        maxDiscountAmount: maxDiscountAmount,
        title: title,
        description: description,
        originalAmount: original,
        discountAmount: 0,
        finalAmount: original,
      );
    }

    int discount;
    final type = discountType ?? DiscountType.fixed;
    if (type == DiscountType.percent) {
      final raw = (original * discountValue / 100).round();
      final max = maxDiscountAmount;
      if (max != null && max > 0 && raw > max) {
        discount = max;
      } else {
        discount = raw;
      }
    } else {
      discount = discountValue;
      if (discount > original) discount = original;
    }

    final int finalAmt = original - discount;
    return CouponValidation(
      valid: valid,
      code: code,
      discountType: discountType,
      discountValue: discountValue,
      maxDiscountAmount: maxDiscountAmount,
      title: title,
      description: description,
      originalAmount: original,
      discountAmount: discount < 0 ? 0 : discount,
      finalAmount: finalAmt < 0 ? 0 : finalAmt,
    );
  }
}
