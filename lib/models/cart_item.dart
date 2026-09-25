import '../core/network/api_client.dart';
import 'course.dart';

/// One row of the user's shopping cart — `GET /api/v1/payments/cart/`.
///
/// The backend returns the cart as a **single object**, not a DRF page:
///
/// ```json
/// {"success": true, "data": {
///   "items": [], "total_items": 0, "unique_courses": 0,
///   "subtotal": 0, "total": 0
/// }}
/// ```
///
/// The item fields themselves are **not documented** — `v1/payments/cart/` is
/// declared in the OpenAPI schema with no request body and no response body at
/// all (the same gap as `v1/discounts/apply/validate/`). So [fromJson] reads the
/// few names the backend could plausibly use instead of insisting on one, and
/// every field degrades to a safe default.
///
/// A cart row means "an enrollment request that is still waiting" — nothing is
/// stored on the device, so this is exactly what the backend holds.
class CartItem {
  const CartItem({
    this.id = 0,
    required this.courseId,
    this.course,
    this.quantity = 1,
    this.price = 0,
    this.requestedAt,
  });

  /// Server-side row id. Needed to delete the row.
  final int id;

  final int courseId;

  /// The course itself. `null` when the backend sends only `course_id`.
  final Course? course;

  final int quantity;

  /// Unit price. `0` means free / unknown.
  final int price;

  final String? requestedAt;

  /// Total for this row.
  int get lineTotal => price * (quantity < 1 ? 1 : quantity);

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final nested = Json.asMap(json['course']);

    final courseId =
        Json.asInt(json['course_id']) ?? Json.asInt(nested?['id']) ?? 0;

    final course = nested == null ? null : Course.fromJson(nested);

    // The unit price can sit on the row or only inside the nested course.
    final price =
        Json.asInt(json['price']) ??
        Json.asInt(json['unit_price']) ??
        Json.asInt(json['amount']) ??
        course?.priceAsInt ??
        0;

    return CartItem(
      id: Json.asInt(json['id']) ?? 0,
      courseId: courseId,
      course: course,
      quantity: Json.asInt(json['quantity']) ?? 1,
      price: price < 0 ? 0 : price,
      requestedAt:
          Json.asString(json['requested_at']) ??
          Json.asString(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course_id': courseId,
    if (course != null) 'course': course!.toJson(),
    'quantity': quantity,
    'price': price,
    if (requestedAt != null) 'requested_at': requestedAt,
  };
}

/// The `data` object of `GET /api/v1/payments/cart/`.
class CartSummary {
  const CartSummary({
    this.items = const <CartItem>[],
    this.totalItems = 0,
    this.uniqueCourses = 0,
    this.subtotal = 0,
    this.total = 0,
  });

  final List<CartItem> items;
  final int totalItems;
  final int uniqueCourses;
  final int subtotal;
  final int total;

  bool get isEmpty => items.isEmpty;

  static const CartSummary empty = CartSummary();

  /// Reads the whole envelope payload. Tolerates both the real single-object
  /// shape and a plain list (in case the backend ever paginates it).
  factory CartSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    final items = rawItems is List
        ? rawItems
              .map(Json.asMap)
              .whereType<Map<String, dynamic>>()
              .map(CartItem.fromJson)
              .where((item) => item.courseId > 0)
              .toList(growable: false)
        : const <CartItem>[];

    return CartSummary(
      items: items,
      totalItems: Json.asInt(json['total_items']) ?? items.length,
      uniqueCourses: Json.asInt(json['unique_courses']) ?? items.length,
      subtotal:
          Json.asInt(json['subtotal']) ??
          items.fold<int>(0, (sum, item) => sum + item.lineTotal),
      total:
          Json.asInt(json['total']) ??
          items.fold<int>(0, (sum, item) => sum + item.lineTotal),
    );
  }
}
