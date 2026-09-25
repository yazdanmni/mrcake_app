import '../core/network/api_client.dart';

/// `OrderStatusEnum` -> `Status628Enum` in the API schema.
///
/// The backend ships the Persian wording itself
/// (`* pending - در انتظار پرداخت`, `* paid - پرداخت شده`, …), so the labels
/// live next to the constants instead of being re-invented per screen.
class OrderStatus {
  OrderStatus._();

  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String failed = 'failed';
  static const String canceled = 'canceled';
  static const String refunded = 'refunded';

  static const List<String> all = <String>[
    pending,
    paid,
    failed,
    canceled,
    refunded,
  ];

  /// The Persian label the API attaches to each value.
  static String label(String status) {
    switch (status) {
      case pending:
        return 'در انتظار پرداخت';
      case paid:
        return 'پرداخت شده';
      case failed:
        return 'پرداخت ناموفق';
      case canceled:
        return 'لغو شده';
      case refunded:
        return 'بازپرداخت شده';
      default:
        return status.isEmpty ? 'نامشخص' : status;
    }
  }
}

/// `PaymentGatewayEnum` — `mock | zarinpal | idpay | other`.
class OrderGateway {
  OrderGateway._();

  static String label(String gateway) {
    switch (gateway) {
      case 'mock':
        return 'درگاه تست';
      case 'zarinpal':
        return 'زرین‌پال';
      case 'idpay':
        return 'آیدی پی';
      case 'other':
        return 'سایر';
      default:
        return gateway.isEmpty ? '—' : gateway;
    }
  }
}

/// One row of `OrderDetail.items[]`.
///
/// `course_title` is a **snapshot** taken when the order was created ("عنوان
/// دوره در زمان سفارش"), not a live course reference — so an order stays
/// readable even if the course is later renamed or removed.
class CourseOrderLine {
  final int id;
  final String courseTitle;
  final int unitPrice;
  final int quantity;
  final int discountPerItem;
  final int lineTotal;

  const CourseOrderLine({
    required this.id,
    required this.courseTitle,
    this.unitPrice = 0,
    this.quantity = 1,
    this.discountPerItem = 0,
    this.lineTotal = 0,
  });

  factory CourseOrderLine.fromJson(Map<String, dynamic> json) {
    return CourseOrderLine(
      id: Json.asInt(json['id']) ?? 0,
      courseTitle: Json.asString(json['course_title']) ?? '',
      unitPrice: Json.asInt(json['unit_price']) ?? 0,
      quantity: Json.asInt(json['quantity']) ?? 1,
      discountPerItem: Json.asInt(json['discount_per_item']) ?? 0,
      lineTotal: Json.asInt(json['line_total']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'course_title': courseTitle,
    'unit_price': unitPrice,
    'quantity': quantity,
    'discount_per_item': discountPerItem,
    'line_total': lineTotal,
  };
}

/// `OrderList` / `OrderDetail` -> `GET /api/v1/payments/orders/`
///
/// One class covers both payloads: `OrderDetail` is a strict superset of
/// `OrderList` (it adds `items`, `coupon_code`, `description`, `tax_amount`, …).
/// The list response simply leaves [items] empty, and opening an order fetches
/// the detail to fill it in.
///
/// This is the record the user's paid registration lives in: a registration
/// creates an order with status [OrderStatus.pending], and the course only
/// reaches «دوره‌های من» once the backend marks that order [OrderStatus.paid].
class CourseOrder {
  final int id;
  final String orderNumber;

  /// `pending | paid | failed | canceled | refunded`
  final String status;

  /// جمع کل اقلام
  final int subtotal;

  /// مبلغ تخفیف
  final int discountAmount;

  /// مبلغ نهایی — what the user owes after the coupon.
  final int totalAmount;

  /// مبلغ پرداختی — what was actually collected.
  final int paidAmount;

  /// `mock | zarinpal | idpay | other`
  final String paymentGateway;

  final DateTime? paymentTime;
  final int itemsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ---------------------------------------------------------------------------
  // `OrderDetail` only — empty / null on a list response.
  // ---------------------------------------------------------------------------

  final List<CourseOrderLine> items;
  final int taxAmount;
  final String? description;
  final String couponCode;

  const CourseOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.paymentGateway = '',
    this.paymentTime,
    this.itemsCount = 0,
    this.createdAt,
    this.updatedAt,
    this.items = const <CourseOrderLine>[],
    this.taxAmount = 0,
    this.description,
    this.couponCode = '',
  });

  factory CourseOrder.fromJson(Map<String, dynamic> json) {
    return CourseOrder(
      id: Json.asInt(json['id']) ?? 0,
      orderNumber: Json.asString(json['order_number']) ?? '',
      status: Json.asString(json['status']) ?? '',
      subtotal: Json.asInt(json['subtotal']) ?? 0,
      discountAmount: Json.asInt(json['discount_amount']) ?? 0,
      totalAmount: Json.asInt(json['total_amount']) ?? 0,
      paidAmount: Json.asInt(json['paid_amount']) ?? 0,
      paymentGateway: Json.asString(json['payment_gateway']) ?? '',
      paymentTime: Json.asDate(json['payment_time']),
      itemsCount: Json.asInt(json['items_count']) ?? 0,
      createdAt: Json.asDate(json['created_at']),
      updatedAt: Json.asDate(json['updated_at']),
      items: Json.asMapList(json['items'])
          .map(CourseOrderLine.fromJson)
          .toList(growable: false),
      taxAmount: Json.asInt(json['tax_amount']) ?? 0,
      description: Json.asString(json['description']),
      couponCode: Json.asString(json['coupon_code']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'order_number': orderNumber,
    'status': status,
    'subtotal': subtotal,
    'discount_amount': discountAmount,
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'payment_gateway': paymentGateway,
    if (paymentTime != null) 'payment_time': paymentTime!.toIso8601String(),
    'items_count': itemsCount,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    'items': items.map((line) => line.toJson()).toList(),
    'tax_amount': taxAmount,
    if (description != null) 'description': description,
    'coupon_code': couponCode,
  };

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  bool get isPending => status == OrderStatus.pending;
  bool get isPaid => status == OrderStatus.paid;

  /// `در انتظار پرداخت` — never the raw enum.
  String get statusLabel => OrderStatus.label(status);

  /// The amount that matters to the user: what is owed on a pending order, what
  /// was collected on a settled one.
  ///
  /// `paid_amount` is authoritative once the order is paid; before that it is
  /// `0`, so [totalAmount] is used instead. [subtotal] minus [discountAmount] is
  /// the last resort for a payload that omitted `total_amount`.
  int get effectiveAmount {
    if (isPaid && paidAmount > 0) return paidAmount;
    if (totalAmount > 0) return totalAmount;
    final int derived = subtotal - discountAmount;
    return derived < 0 ? 0 : derived;
  }

  /// True when a coupon covered the whole price — the course was free, and the
  /// backend turns the order straight into an enrollment.
  bool get isFullyDiscounted => totalAmount <= 0;
}
