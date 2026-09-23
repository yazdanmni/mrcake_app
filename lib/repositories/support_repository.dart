import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import 'catalog_repository.dart';

/// Screen -> Endpoint -> Model -> Repository
///
///  TicketsScreen  GET   v1/support/subjects/            -> page of `TicketSubject`
///  TicketsScreen  GET   v1/support/my_tickets/          -> page of `TicketList`
///  TicketsScreen  POST  v1/support/                     -> `TicketDetail`
///  TicketsScreen  GET   v1/support/{id}/                -> `TicketDetail`
///  TicketsScreen  POST  v1/support/{id}/send_message/   -> `TicketMessage`
///  TicketsScreen  POST  v1/support/{id}/close/          -> `TicketDetail`
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
  Future<Map<String, dynamic>> createTicket({
    required String title,
    required String message,
    int? subjectId,
    String? attachment,
    String priority = 'normal',
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.support,
      body: {
        'title': title,
        'message': message,
        'subject_id': ?subjectId,
        'attachment': ?attachment,
        'priority': priority,
      },
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
}

/// Screen -> Endpoint -> Model -> Repository
///
///  Notifications  GET  v1/notifications/            -> page of `Notification`
///  Notifications  POST v1/notifications/{id}/read/  -> `Notification`
class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  ApiClient get _api => ApiClient.instance;

  Future<PagedResult> fetchNotifications({int page = 1}) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.notifications,
      query: {'page': page},
    );
    return PagedResult.from(data);
  }

  Future<Map<String, dynamic>> markAsRead(int id) async {
    final data = await _api.post<dynamic>(ApiEndpoints.notificationRead(id));
    return Json.asMap(data) ?? <String, dynamic>{};
  }
}

/// Screen -> Endpoint -> Model -> Repository
///
///  CartScreen     GET    v1/payments/cart/              -> page of `CartItem`
///  CartScreen     POST   v1/payments/cart/              -> `CartItem`
///  CartScreen     DELETE v1/payments/cart/{id}/         -> void
///  CartScreen     DELETE v1/payments/cart/clear/        -> void
///  CartScreen     POST   v1/payments/cart/sync/         -> page of `CartItem`
///  CheckoutScreen POST   v1/payments/orders/            -> `OrderDetail`
///  OrdersScreen   GET    v1/payments/orders/            -> page of `OrderList`
///  CouponScreen   POST   v1/discounts/apply/validate/   -> `Coupon`
///  CouponScreen   GET    v1/discounts/apply/my_coupons/ -> page of `Coupon`
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

  Future<PagedResult> fetchCart() async {
    final data = await _api.get<dynamic>(ApiEndpoints.cart);
    return PagedResult.from(data);
  }

  Future<Map<String, dynamic>> addToCart({
    required int courseId,
    int quantity = 1,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.cart,
      body: {'course': courseId, 'quantity': quantity},
    );
    return Json.asMap(data) ?? <String, dynamic>{};
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

  Future<Map<String, dynamic>> fetchOrder(int id) async {
    final data = await _api.get<dynamic>(ApiEndpoints.order(id));
    return Json.asMap(data) ?? <String, dynamic>{};
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
    final data = await _api.post<dynamic>(
      ApiEndpoints.discountsValidate,
      body: {'code': code, 'course': ?courseId, 'order': ?orderId},
    );
    return Json.asMap(data) ?? <String, dynamic>{};
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
