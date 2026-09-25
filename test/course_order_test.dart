import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/utils/currency_format.dart';
import 'package:mr_cake_project/core/utils/persian_date.dart';
import 'package:mr_cake_project/models/course_order.dart';

/// The orders feature has two pieces of pure logic worth locking down:
///
///  * [CourseOrder] — the payload behind «سفارش های من», and specifically the
///    `total_amount` that decides whether a registration is free;
///  * [PersianDate] — the Gregorian → Jalali conversion, since the API sends
///    ISO-8601 UTC and the screen must show `1405/07/02`.
void main() {
  group('CourseOrder', () {
    test('reads a real `GET v1/payments/orders/` row', () {
      final order = CourseOrder.fromJson(const {
        'id': 11,
        'order_number': 'MC-11',
        'status': 'pending',
        'subtotal': 2500000,
        'discount_amount': 500000,
        'total_amount': 2000000,
        'paid_amount': 0,
        'payment_gateway': 'mock',
        'payment_time': null,
        'items_count': 1,
        'created_at': '2026-09-24T11:03:07.123456Z',
        'updated_at': '2026-09-24T11:03:07.123456Z',
      });

      expect(order.id, 11);
      expect(order.orderNumber, 'MC-11');
      expect(order.status, OrderStatus.pending);
      expect(order.subtotal, 2500000);
      expect(order.discountAmount, 500000);
      expect(order.totalAmount, 2000000);
      expect(order.paidAmount, 0);
      expect(order.paymentGateway, 'mock');
      expect(order.paymentTime, isNull);
      expect(order.itemsCount, 1);
      expect(order.createdAt, isNotNull);
      // The list payload carries no items — only the detail does.
      expect(order.items, isEmpty);
    });

    test('reads `OrderDetail.items[]`', () {
      final order = CourseOrder.fromJson(const {
        'id': 11,
        'order_number': 'MC-11',
        'status': 'paid',
        'total_amount': 2000000,
        'coupon_code': 'OFF20',
        'description': 'ثبت نام دوره: کیک خامه‌ای',
        'tax_amount': 0,
        'items': [
          {
            'id': 5,
            'course_title': 'کیک خامه‌ای حرفه‌ای',
            'unit_price': 2500000,
            'quantity': 1,
            'discount_per_item': 500000,
            'line_total': 2000000,
          },
        ],
      });

      expect(order.items, hasLength(1));
      final line = order.items.single;
      expect(line.courseTitle, 'کیک خامه‌ای حرفه‌ای');
      expect(line.unitPrice, 2500000);
      expect(line.discountPerItem, 500000);
      expect(line.lineTotal, 2000000);
      expect(order.couponCode, 'OFF20');
      expect(order.description, 'ثبت نام دوره: کیک خامه‌ای');
    });

    test('a zero total means the coupon covered everything', () {
      final order = CourseOrder.fromJson(const {
        'id': 12,
        'status': 'paid',
        'subtotal': 2500000,
        'discount_amount': 2500000,
        'total_amount': 0,
      });

      expect(order.isFullyDiscounted, isTrue);
      expect(order.effectiveAmount, 0);
    });

    test('a pending order is what the user owes', () {
      final order = CourseOrder.fromJson(const {
        'id': 13,
        'status': 'pending',
        'subtotal': 2500000,
        'discount_amount': 500000,
        'total_amount': 2000000,
        'paid_amount': 0,
      });

      expect(order.isPending, isTrue);
      expect(order.isPaid, isFalse);
      // `paid_amount` is 0 before settlement, so it must not be shown.
      expect(order.effectiveAmount, 2000000);
    });

    test('a settled order shows what was actually collected', () {
      final order = CourseOrder.fromJson(const {
        'id': 14,
        'status': 'paid',
        'subtotal': 2500000,
        'total_amount': 2000000,
        'paid_amount': 1900000,
      });

      expect(order.isPaid, isTrue);
      expect(order.effectiveAmount, 1900000);
    });

    test('a payload without total_amount falls back to subtotal - discount', () {
      final order = CourseOrder.fromJson(const {
        'id': 15,
        'status': 'pending',
        'subtotal': 2500000,
        'discount_amount': 500000,
      });

      expect(order.effectiveAmount, 2000000);
    });

    test('never reports a negative amount', () {
      final order = CourseOrder.fromJson(const {
        'id': 16,
        'status': 'pending',
        'subtotal': 100,
        'discount_amount': 500,
      });

      expect(order.effectiveAmount, 0);
      expect(order.isFullyDiscounted, isTrue);
    });

    test('an empty payload degrades instead of throwing', () {
      final order = CourseOrder.fromJson(const {});

      expect(order.id, 0);
      expect(order.status, '');
      expect(order.items, isEmpty);
      expect(order.effectiveAmount, 0);
    });
  });

  group('OrderStatus', () {
    test('renders the Persian label the API ships', () {
      expect(OrderStatus.label('pending'), 'در انتظار پرداخت');
      expect(OrderStatus.label('paid'), 'پرداخت شده');
      expect(OrderStatus.label('failed'), 'پرداخت ناموفق');
      expect(OrderStatus.label('canceled'), 'لغو شده');
      expect(OrderStatus.label('refunded'), 'بازپرداخت شده');
    });

    test('never shows a raw enum or an empty string', () {
      expect(OrderStatus.label(''), 'نامشخص');
      expect(OrderStatus.label('something_new'), 'something_new');
    });
  });

  group('OrderGateway', () {
    test('renders the Persian label', () {
      expect(OrderGateway.label('mock'), 'درگاه تست');
      expect(OrderGateway.label('zarinpal'), 'زرین‌پال');
      expect(OrderGateway.label('idpay'), 'آیدی پی');
      expect(OrderGateway.label('other'), 'سایر');
    });

    test('an unknown gateway is shown as-is, an empty one as a dash', () {
      expect(OrderGateway.label('bitpay'), 'bitpay');
      expect(OrderGateway.label(''), '—');
    });
  });

  group('PersianDate', () {
    test('converts Nowruz to 1/1', () {
      expect(PersianDate.toJalali(2026, 3, 21), (1405, 1, 1));
      expect(PersianDate.toJalali(2025, 3, 21), (1404, 1, 1));
      expect(PersianDate.toJalali(2024, 3, 20), (1403, 1, 1));
    });

    test('converts a mid-year date', () {
      // 2026-09-24 is 187 days after Nowruz 1405 -> Mehr 2.
      expect(PersianDate.toJalali(2026, 9, 24), (1405, 7, 2));
    });

    test('converts a date in the previous Jalali year', () {
      expect(PersianDate.toJalali(2026, 1, 1), (1404, 10, 11));
      expect(PersianDate.toJalali(2024, 1, 1), (1402, 10, 11));
    });

    test('formats with zero-padded month and day', () {
      expect(PersianDate.format(DateTime(2026, 9, 24, 12)), '1405/07/02');
      expect(PersianDate.format(DateTime(2026, 3, 21, 12)), '1405/01/01');
    });

    test('can include the time', () {
      expect(
        PersianDate.format(DateTime(2026, 9, 24, 14, 35), withTime: true),
        '1405/07/02 - 14:35',
      );
      expect(
        PersianDate.format(DateTime(2026, 9, 24, 9, 5), withTime: true),
        '1405/07/02 - 09:05',
      );
    });

    test('a null date renders as a dash, not a wrong date', () {
      // `payment_time` is null until the order is paid.
      expect(PersianDate.formatOrDash(null), '—');
      expect(
        PersianDate.formatOrDash(DateTime(2026, 9, 24, 12)),
        '1405/07/02',
      );
    });
  });

  group('currency formatting', () {
    test('groups thousands', () {
      expect(formatNumber(2500000), '2,500,000');
      expect(formatNumber(500), '500');
      expect(formatNumber(1000), '1,000');
      expect(formatNumber(0), '0');
    });

    test('a negative amount keeps its sign', () {
      expect(formatNumber(-500000), '-500,000');
    });

    test('zero renders as free, never as "0 تومان"', () {
      expect(formatToman(0), 'رایگان');
      expect(formatToman(-1), 'رایگان');
      expect(formatToman(2500000), '2,500,000 تومان');
    });
  });
}
