import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../models/cart_item.dart';
import '../models/coupon_model.dart';
import '../models/course_order.dart';
import '../models/gift.dart';
import 'catalog_repository.dart';

/// Screen -> Endpoint -> Model -> Repository
///
///  TicketsScreen  GET   v1/support/subjects/            -> page of `TicketSubject`
///  TicketsScreen  GET   v1/support/my_tickets/          -> page of `TicketList`
///  TicketsScreen  POST  v1/support/                     -> `TicketDetail`
///  TicketsScreen  GET   v1/support/{id}/                -> `TicketDetail`
///  TicketsScreen  POST  v1/support/{id}/send_message/   -> `TicketMessage`
///  TicketsScreen  POST  v1/support/{id}/close/          -> `TicketDetail`
/// `PriorityEnum` — `{low, medium, high, urgent}`.
///
/// The live endpoint rejects anything outside this set with a **400**, and the
/// schema's `default` is `medium`. Before this existed the app sent `'normal'`,
/// which is not a member — every ticket creation failed with
/// `priority: "normal" یک انتخاب معتبر نیست.`
class TicketPriority {
  TicketPriority._();

  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String urgent = 'urgent';

  static const List<String> all = <String>[low, medium, high, urgent];

  /// The Persian label for a priority value.
  static String label(String value) {
    switch (value) {
      case low:
        return 'کم';
      case high:
        return 'بالا';
      case urgent:
        return 'فوری';
      case medium:
      default:
        return 'متوسط';
    }
  }

  /// Maps any incoming string onto a value the API accepts.
  ///
  /// Silently falls back to [medium] (the schema default) rather than letting an
  /// unknown enum reach the network — a ticket that fails validation is a ticket
  /// the user never gets.
  static String resolve(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return all.contains(normalized) ? normalized : medium;
  }
}

/// `TicketStatusEnum` — the values `TicketList.status` / `TicketDetail.status`
/// can hold.
///
/// A wallet top-up request rides on a ticket, and its whole lifecycle is this
/// field: `open` → waiting for an admin, `closed`/`resolved` → the top-up was
/// carried out. Keep the closed set in one place so the wallet screen and the
/// tickets screen agree on what "done" means.
class TicketStatus {
  TicketStatus._();

  static const String open = 'open';
  static const String pending = 'pending';
  static const String answered = 'answered';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static const String rejected = 'rejected';

  /// Statuses that mean "this request is finished".
  static const Set<String> finished = <String>{resolved, closed};

  static bool isFinished(String? status) =>
      finished.contains((status ?? '').trim().toLowerCase());

  static String label(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case resolved:
        return 'رسیدگی شده';
      case closed:
        return 'بسته شده';
      case answered:
        return 'پاسخ داده شده';
      case pending:
        return 'در انتظار';
      case rejected:
        return 'رد شده';
      case open:
      default:
        return 'باز';
    }
  }
}

class SupportRepository {
  SupportRepository._();

  static final SupportRepository instance = SupportRepository._();

  ApiClient get _api => ApiClient.instance;

  /// `GET /api/v1/support/subjects/`
  Future<PagedResult> fetchSubjects({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.supportSubjects,
      query: {'page': page},
    );
    return PagedResult.from(data);
  }

  /// `GET /api/v1/support/my_tickets/` (auth)
  Future<PagedResult> fetchMyTickets({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.supportMyTickets,
      query: {'page': page},
    );
    return PagedResult.from(data);
  }

  /// `POST /api/v1/support/` (auth) -> `TicketCreate`
  ///
  /// The body matches `TicketCreate`: `title`, `subject_id`, `priority`,
  /// `message` and an optional `attachment` (a media url).
  ///
  /// ⚠️ **[priority] must be a [TicketPriority] value.** The live backend types
  /// it as `PriorityEnum = {low, medium, high, urgent}` and answers
  /// `400 priority: "normal" یک انتخاب معتبر نیست.` for anything else — which
  /// is exactly why "ارسال تیکت" failed for every ticket, whoever filed it.
  /// [TicketPriority.medium] is also the schema's own `default`.
  Future<Map<String, dynamic>> createTicket({
    required String title,
    required String message,
    int? subjectId,
    String? attachment,
    String priority = TicketPriority.medium,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'title': title,
      'message': message,
      // Never trust a caller-supplied string here: an invalid enum is a silent
      // hard failure at the API, and the ticket is the one thing that must go
      // through. Unknown values fall back to the schema default.
      'priority': TicketPriority.resolve(priority),
    };

    if (subjectId != null && subjectId > 0) {
      payload['subject_id'] = subjectId;
    }

    if (attachment != null && attachment.trim().isNotEmpty) {
      payload['attachment'] = attachment;
    }

    final data = await _api.post<dynamic>(
      ApiEndpoints.support,
      body: payload,
    );
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// `GET /api/v1/support/{id}/`
  Future<Map<String, dynamic>> fetchTicket(int id) async {
    final data = await _api.get<dynamic>(ApiEndpoints.supportTicket(id));
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// `POST /api/v1/support/{id}/send_message/`
  Future<Map<String, dynamic>> sendMessage({
    required int ticketId,
    required String message,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.supportTicketSendMessage(ticketId),
      body: {'message': message},
    );
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// `POST /api/v1/support/{id}/close/`
  Future<Map<String, dynamic>> closeTicket(int id) async {
    final data = await _api.post<dynamic>(ApiEndpoints.supportTicketClose(id));
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// `POST /api/v1/support/{id}/seen/`
  Future<void> markSeen(int id) async {
    await _api.post<dynamic>(ApiEndpoints.supportTicketSeen(id));
  }

  // ---------------------------------------------------------------------------
  // Auto-created enrollment requests
  // ---------------------------------------------------------------------------

  /// Subject names that mean "I want to buy a new course", best match first.
  ///
  /// The live backend ships exactly four subjects
  /// (`خرید دوره های جدید`, `مشکل در خرید دوره ها`, `خرید های قبل`,
  /// `درخواست دوره های قبلی خودتان`) and the first is the one a brand-new
  /// purchase belongs to.
  static const List<String> _newPurchaseHints = <String>[
    'خرید دوره های جدید',
    'خرید دوره جدید',
    'خرید دوره',
    'ثبت نام دوره',
    'ثبت نام',
  ];

  /// Picks the subject a paid-registration ticket should be filed under.
  ///
  /// Matching is by **name**, never by id: ids are database-assigned and would
  /// silently point at the wrong subject on another deployment. The hint list is
  /// walked in order, so a specific phrase always beats a generic one.
  ///
  /// Returns `null` when nothing matches. `TicketCreate.subject_id` is nullable,
  /// so the ticket is still created — just without a subject. Guessing
  /// `results.first` would be worse: the live endpoint returns subjects newest
  /// first, so the first row is «درخواست دوره های قبلی خودتان», the opposite of
  /// what a new purchase needs.
  Future<int?> resolveNewPurchaseSubjectId() async {
    try {
      final page = await fetchSubjects();

      final subjects = <({int id, String name})>[];
      for (final json in page.items) {
        final id = Json.asInt(json['id']) ?? 0;
        final name =
            Json.asString(json['name']) ?? Json.asString(json['title']) ?? '';
        if (id > 0 && name.isNotEmpty) {
          subjects.add((id: id, name: _normalize(name)));
        }
      }

      for (final hint in _newPurchaseHints) {
        final needle = _normalize(hint);
        for (final subject in subjects) {
          if (subject.name.contains(needle)) return subject.id;
        }
      }

      return null;
    } catch (_) {
      // The ticket is more valuable than its subject — never block on this.
      return null;
    }
  }

  /// Folds the Arabic/Persian letter variants and the zero-width non-joiner so
  /// «دوره‌های جدید» and «دوره های جدید» compare equal.
  static String _normalize(String value) => value
      .replaceAll('\u200c', ' ')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Screen -> Endpoint -> Model -> Repository
///
///  GiftsScreen  GET  v1/discounts/apply/my_coupons/  -> list of `Coupon`
///
/// ## The response shape
///
/// This endpoint does **not** answer a DRF page. It answers the app's own
/// envelope wrapping a **bare list**:
///
/// ```json
/// {"success": true, "data": []}
/// ```
///
/// `ApiClient.unwrapEnvelope` already returns the inner `data`, so the repository
/// sees a `List`. It must never go through `PagedResult.from`: an empty page
/// would then be read as "one object" and the gifts screen would render a single
/// blank card instead of its empty state. It is typed [Gift] at the call site.
class ShopGiftRepository {
  ShopGiftRepository._();

  static final ShopGiftRepository instance = ShopGiftRepository._();

  ApiClient get _api => ApiClient.instance;

  /// `GET /api/v1/discounts/apply/my_coupons/` (auth) -> `List<Gift>`.
  ///
  /// Not cached: a coupon can be granted by an admin at any moment, and a stale
  /// empty list would hide a gift the user was just given.
  Future<List<Gift>> fetchMyGifts({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.discountsMyCoupons,
      query: {'page': page},
    );

    // A bare list, or a DRF page if the backend ever starts paginating — both
    // are accepted so this cannot silently break on a deployment change.
    if (data is List) {
      return Json.asMapList(data)
          .map(Gift.fromJson)
          .where((Gift gift) => gift.code.isNotEmpty)
          .toList(growable: false);
    }

    final map = Json.asMap(data);
    if (map == null) return const <Gift>[];

    final raw = map['results'];
    if (raw is List) {
      return Json.asMapList(raw)
          .map(Gift.fromJson)
          .where((Gift gift) => gift.code.isNotEmpty)
          .toList(growable: false);
    }

    return const <Gift>[];
  }
}

/// Screen -> Endpoint -> Model -> Repository
///
///  CartScreen     GET    v1/payments/cart/              -> `CartSummary`
///  CartScreen     POST   v1/payments/cart/              -> void
///  CartScreen     DELETE v1/payments/cart/{id}/         -> void
///  CartScreen     DELETE v1/payments/cart/clear/        -> void
///  CartScreen     POST   v1/payments/cart/sync/         -> page of `CartItem`
///  CheckoutScreen POST   v1/payments/orders/            -> `OrderDetail`
///  OrdersScreen   GET    v1/payments/orders/            -> page of `OrderList`
///  CouponScreen   POST   v1/discounts/apply/validate/   -> `Coupon`
///  CouponScreen   GET    v1/discounts/apply/my_coupons/ -> page of `Coupon`
///
/// A cart row is an **enrollment request waiting for an admin**, not a basket
/// waiting for a checkout button: a paid registration creates an order, opens a
/// support ticket and parks the course here until the order is settled.
/// `OrderCreateGatewayEnum` / `Gateway4f2Enum` — the values the backend accepts
/// for `gateway`.
///
/// `mock` is the only one that can complete without a real bank redirect, so it
/// is the default in [ShopRepository.createOrder].
class PaymentGateway {
  PaymentGateway._();

  static const String mock = 'mock';
  static const String zarinpal = 'zarinpal';
  static const String idpay = 'idpay';
  static const String other = 'other';

  static const List<String> all = <String>[mock, zarinpal, idpay, other];
}

/// `PaymentStatusEnum` — `{pending, success, failed, canceled, refunded}`.
class PaymentStatus {
  PaymentStatus._();

  static const String pending = 'pending';
  static const String success = 'success';
  static const String failed = 'failed';
  static const String canceled = 'canceled';
  static const String refunded = 'refunded';
}

class ShopRepository {
  ShopRepository._();

  static final ShopRepository instance = ShopRepository._();

  ApiClient get _api => ApiClient.instance;

  // cart ---------------------------------------------------------------------

  /// `GET /api/v1/payments/cart/` (public) -> [CartSummary].
  ///
  /// The endpoint answers a **single object**, not a DRF page:
  /// `{items, total_items, unique_courses, subtotal, total}`. Reading it with
  /// `PagedResult.from` would wrap that whole object as one "item" and produce a
  /// cart with a single meaningless row, so it is parsed by [CartSummary].
  Future<CartSummary> fetchCart() async {
    final data = await _api.get<dynamic>(ApiEndpoints.cart);
    final map = Json.asMap(data);
    if (map == null) return CartSummary.empty;
    return CartSummary.fromJson(map);
  }

  /// `POST /api/v1/payments/cart/` (auth).
  ///
  /// The schema declares this endpoint with **no request body and no response
  /// body**, so `{course, quantity}` is the shape the app has always sent and
  /// the response is ignored. Nothing is mirrored on the device: the cart screen
  /// shows exactly what `GET v1/payments/cart/` returns, so a rejected POST is
  /// visible as an empty cart rather than hidden behind a local copy.
  Future<void> addToCart({required int courseId, int quantity = 1}) async {
    await _api.post<dynamic>(
      ApiEndpoints.cart,
      body: {'course': courseId, 'quantity': quantity},
    );
  }

  Future<void> updateCartItem({
    required int itemId,
    required int quantity,
  }) async {
    await _api.put<dynamic>(
      ApiEndpoints.cartItem(itemId),
      body: {'quantity': quantity},
    );
  }

  Future<void> removeCartItem(int itemId) async {
    await _api.delete<dynamic>(ApiEndpoints.cartItem(itemId));
  }

  Future<void> clearCart() async {
    await _api.delete<dynamic>(ApiEndpoints.cartClear);
  }

  Future<PagedResult> syncCart(List<Map<String, dynamic>> items) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.cartSync,
      body: {'items': items},
    );
    return PagedResult.from(data);
  }

  // orders -------------------------------------------------------------------

  Future<PagedResult> fetchOrders({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.orders,
      query: {'page': page},
    );
    return PagedResult.from(data);
  }

  /// `GET /api/v1/payments/orders/` (auth) typed as [CourseOrder].
  ///
  /// Not cached: an order's `status` changes the moment an admin approves it,
  /// and a stale «در انتظار پرداخت» would hide a course the user already owns.
  /// The list payload has no `items[]` — open an order with [fetchOrderDetails]
  /// to get them.
  Future<List<CourseOrder>> fetchOrderSummaries({int page = 1}) async {
    final result = await fetchOrders(page: page);
    return result.map(CourseOrder.fromJson);
  }

  Future<Map<String, dynamic>> fetchOrder(int id) async {
    final data = await _api.get<dynamic>(ApiEndpoints.order(id));
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// `GET /api/v1/payments/orders/{id}/` (auth) typed as [CourseOrder].
  ///
  /// This is the only payload that carries `items[]` (`course_title`,
  /// `line_total`, …), which is what makes the detail screen able to name the
  /// course an order was placed for.
  Future<CourseOrder?> fetchOrderDetails(int id) async {
    final raw = await fetchOrder(id);
    if (raw.isEmpty) return null;
    return CourseOrder.fromJson(raw);
  }

  /// `POST /api/v1/payments/orders/` -> `OrderCreate`
  ///
  /// The real `OrderCreate` body is:
  /// `{coupon_code, gateway, description, course_ids}` — there is **no**
  /// `address_id` and no `note` (those are not part of this backend's model).
  /// `course_ids` is what actually puts a course in the order, so omitting it
  /// produces an empty order.
  ///
  /// [gateway] defaults to `mock`, which is the only gateway that can complete
  /// without a real bank redirect.
  Future<Map<String, dynamic>> createOrder({
    List<int> courseIds = const [],
    String gateway = PaymentGateway.mock,
    String? couponCode,
    String? description,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.orders,
      body: {
        'gateway': gateway,
        'course_ids': courseIds,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  // Completing a payment — NOT implemented on purpose
  //
  // `POST v1/payments/payments/mock_gateway/` answers
  // `404 {"success":false,"message":"شناسه پرداخت یافت نشد"}` ("payment id not
  // found") for **every** body tried — `{}`, `{payment}`, `{payment_id}`,
  // `{id}`, `{authority}`, `{order_id}`, `{order, amount}` — because the
  // production database holds no payments to look up, so the response never
  // changes. The schema is no help either: it types the request body as
  // `Payment`, which is a *response* schema (a known DRF quirk).
  //
  // Writing a body here would be a guess, and a guessed body is exactly the bug
  // that was just fixed in [createOrder] (it used to send a non-existent
  // `address_id` / `note` and omit `course_ids`). To finish enrollment:
  //
  //   1. create a user and an order against a test account,
  //   2. POST `mock_gateway` with one candidate body and read the response,
  //   3. add the method here with the verified field name.
  //
  // Endpoint constants are already declared in [ApiEndpoints] so nothing else
  // needs touching. `PaymentStatus` below carries the resulting enum.

  // discounts ----------------------------------------------------------------

  /// `POST /api/v1/discounts/apply/validate/` -> `Coupon`
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    int? courseId,
    int? orderId,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'code': code,
    };

    if (courseId != null && courseId > 0) {
      payload['course'] = courseId;
    }

    if (orderId != null && orderId > 0) {
      payload['order'] = orderId;
    }

    final data = await _api.post<dynamic>(
      ApiEndpoints.discountsValidate,
      body: payload,
    );
    return Json.asMap(data) ?? <String, dynamic>{};
  }

  /// Typed wrapper around [validateCoupon] that returns a single
  /// [CouponValidation] merged with the computed amounts for [amount].
  ///
  /// If the API rejects the coupon (network error / 4xx) the returned value is
  /// `CouponValidation.invalid` so the UI can render an inline message instead
  /// of crashing.
  ///
  /// `POST v1/discounts/apply/validate/` is documented with **no response
  /// body**, so a successful call may decode to an empty map. That is why the
  /// typed code is passed as `fallbackCode`: the coupon is accepted, the user
  /// sees the code they typed, and the authoritative `discount_amount` /
  /// `total_amount` are read from the created order afterwards (see
  /// `createOrder`).
  Future<CouponValidation> validateCouponForAmount({
    required String code,
    required int amount,
    int? courseId,
  }) async {
    try {
      final raw = await validateCoupon(code: code, courseId: courseId);
      final coupon = CouponValidation.fromJson(raw, fallbackCode: code);
      return coupon.applyToAmount(amount);
    } catch (_) {
      return CouponValidation.invalid(code).applyToAmount(amount);
    }
  }

  /// `GET /api/v1/discounts/apply/my_coupons/` (auth)
  Future<PagedResult> fetchMyCoupons({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.discountsMyCoupons,
      query: {'page': page},
    );
    return PagedResult.from(data);
  }
}
