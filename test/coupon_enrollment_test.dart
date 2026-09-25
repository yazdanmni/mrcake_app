import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/models/coupon_model.dart';
import 'package:mr_cake_project/models/enrollment.dart';

/// Regression coverage for the two pure-logic pieces of the course-registration
/// feature — no network needed.
///
///  * `CouponValidation` — the arithmetic that *suggests* whether a coupon makes
///    the course free (100 %) or only discounts it. It is only a suggestion: the
///    authoritative answer is the created order's `total_amount`, because the
///    validator endpoint is documented with no response body.
///  * `Enrollment.fromJson` — the server payload that fills «دوره‌های من». Since
///    the on-device mirrors were deleted, this parse is the only thing standing
///    between the API and the profile list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Coupon maths
  // ---------------------------------------------------------------------------

  group('CouponValidation', () {
    test('a 100% percent coupon makes the course free', () {
      final coupon = CouponValidation.fromJson({
        'code': 'FREE100',
        'discount_type': 'percent',
        'discount_value': 100,
      }).applyToAmount(2500000);

      expect(coupon.valid, isTrue);
      expect(coupon.discountAmount, 2500000);
      expect(coupon.finalAmount, 0);
      expect(coupon.isFree, isTrue);
      expect(coupon.is100Percent, isTrue);
      expect(coupon.hasDiscountData, isTrue);
    });

    test('a partial percent coupon only reduces the payable amount', () {
      final coupon = CouponValidation.fromJson({
        'code': 'OFF20',
        'discount_type': 'percent',
        'discount_value': 20,
      }).applyToAmount(1000000);

      expect(coupon.discountAmount, 200000);
      expect(coupon.finalAmount, 800000);
      expect(coupon.isFree, isFalse);
      expect(coupon.is100Percent, isFalse);
    });

    test('max_discount_amount caps the percentage', () {
      final coupon = CouponValidation.fromJson({
        'code': 'OFF50',
        'discount_type': 'percent',
        'discount_value': 50,
        'max_discount_amount': 300000,
      }).applyToAmount(1000000);

      expect(coupon.discountAmount, 300000);
      expect(coupon.finalAmount, 700000);
    });

    test('a fixed coupon never discounts more than the price', () {
      final coupon = CouponValidation.fromJson({
        'code': 'BIG',
        'discount_type': 'fixed',
        'discount_value': 9000000,
      }).applyToAmount(2500000);

      expect(coupon.discountAmount, 2500000);
      expect(coupon.finalAmount, 0);
      expect(coupon.isFree, isTrue);
      // Fixed coupon >= price still counts as "covered everything".
      expect(coupon.is100Percent, isTrue);
    });

    test('an invalid coupon never discounts anything', () {
      final coupon =
          CouponValidation.invalid('NOPE').applyToAmount(1000000);

      expect(coupon.valid, isFalse);
      expect(coupon.discountAmount, 0);
      expect(coupon.finalAmount, 1000000);
      expect(coupon.isFree, isFalse);
    });

    test('an empty validator body keeps the typed code and no discount', () {
      // `POST v1/discounts/apply/validate/` is documented with no response
      // body, so a success can decode to an empty map. The coupon is accepted,
      // the code is preserved and the amount comes from the order instead.
      //
      // This is exactly why the free/paid branch must NOT be taken from here:
      // the client cannot tell a 100 % coupon from "no discount data at all".
      final coupon = CouponValidation.fromJson(
        const {},
        fallbackCode: 'FREE100',
      ).applyToAmount(1000000);

      expect(coupon.valid, isTrue);
      expect(coupon.code, 'FREE100');
      expect(coupon.hasDiscountData, isFalse);
      expect(coupon.finalAmount, 1000000);
      expect(coupon.isFree, isFalse);
    });

    test('a coupon is free when the course itself has no price', () {
      final coupon = CouponValidation.invalid('').applyToAmount(0);

      expect(coupon.finalAmount, 0);
      expect(coupon.isFree, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // The server payload behind «دوره‌های من»
  // ---------------------------------------------------------------------------

  group('Enrollment.fromJson', () {
    test('reads a real `GET v1/courses/enrollments/` row', () {
      final enrollment = Enrollment.fromJson(const {
        'id': 12,
        'course_id': 7,
        'progress_percent': 45,
        'price_paid': 2000000,
        'discount_applied': 500000,
        'is_paid': true,
        'completed': false,
        'lesson_progress_count': 5,
        'enrolled_at': '2026-09-24T10:00:00Z',
      });

      expect(enrollment.id, 12);
      expect(enrollment.courseId, 7);
      expect(enrollment.progress, closeTo(0.45, 0.0001));
      expect(enrollment.progressPercent, 45);
      expect(enrollment.pricePaid, 2000000);
      expect(enrollment.discountApplied, 500000);
      expect(enrollment.isPaid, isTrue);
      expect(enrollment.completed, isFalse);
      expect(enrollment.lessonProgressCount, 5);
      expect(enrollment.enrolledAt, '2026-09-24T10:00:00Z');
    });

    test('a 100 % coupon enrollment is unpaid but still an enrollment', () {
      // Free / fully-discounted registrations never go through a payment, so
      // `price_paid` is 0 and `is_paid` is false — the course must still show up
      // in the profile, because the enrollment itself is what matters.
      final enrollment = Enrollment.fromJson(const {
        'id': 13,
        'course_id': 7,
        'progress_percent': 0,
        'price_paid': 0,
        'discount_applied': 2500000,
        'is_paid': false,
      });

      expect(enrollment.courseId, 7);
      expect(enrollment.isPaid, isFalse);
      expect(enrollment.pricePaid, 0);
      expect(enrollment.discountApplied, 2500000);
    });

    test('takes the course id from the nested course when it is not flat', () {
      final enrollment = Enrollment.fromJson(const {
        'id': 14,
        'progress': 0.5,
        'course': {
          'id': 21,
          'title': 'کیک شکلاتی',
          'image': '',
          'price': '1500000',
        },
      });

      expect(enrollment.courseId, 21);
      expect(enrollment.course, isNotNull);
      expect(enrollment.course!.title, 'کیک شکلاتی');
      // `progress` (0..1) is the mock key, `progress_percent` the real one.
      expect(enrollment.progress, closeTo(0.5, 0.0001));
    });

    test('a payload with nothing recognisable degrades instead of throwing', () {
      final enrollment = Enrollment.fromJson(const {});

      expect(enrollment.id, 0);
      expect(enrollment.courseId, 0);
      expect(enrollment.progress, 0);
      expect(enrollment.course, isNull);
    });
  });
}
