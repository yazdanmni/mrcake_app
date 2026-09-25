import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/pages/orders/order_details_screen.dart';
import 'package:mr_cake_project/pages/orders/orders_screen.dart';

/// «سفارش های من» is where a paid registration lives until an admin approves it,
/// so these tests pin down two things:
///
///  * the list is exactly `GET v1/payments/orders/` — nothing is mirrored on the
///    device, and a `pending` order must be visibly pending;
///  * opening an order fetches `GET v1/payments/orders/{id}/`, because that is
///    the only payload carrying `items[]` — the course the order was placed for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter api;
  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'mr_cake.auth.access_token': 'test-token',
      'mr_cake.auth.user': jsonEncode({
        'id': 42,
        'phone_number': '09123456789',
        'first_name': 'علی',
        'last_name': 'رضایی',
      }),
    });
    await SessionManager.instance.init();
  });

  setUp(() {
    RemoteCache.clear();

    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeApiAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  /// See `coupon_flow_test.dart` — the test font draws every Persian glyph as a
  /// square, so the real screens overflow here and nowhere else.
  void ignoreTestFontOverflow() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if ('${details.exception}'.contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpOrders(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list is read from the orders endpoint', (tester) async {
    ignoreTestFontOverflow();

    api.orders = <Map<String, dynamic>>[
      orderRow(id: 11, number: 'MC-11', status: 'pending', total: 2000000),
    ];

    await pumpOrders(tester);

    expect(
      api.getPaths.where((path) => path.contains('payments/orders')).length,
      1,
    );
    expect(find.text('سفارش های من'), findsOneWidget);
    expect(find.text('سفارش MC-11'), findsOneWidget);
  });

  testWidgets('a pending order is visibly waiting and says what happens next', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.orders = <Map<String, dynamic>>[
      orderRow(id: 11, number: 'MC-11', status: 'pending', total: 2000000),
    ];

    await pumpOrders(tester);

    expect(find.text('در انتظار پرداخت'), findsOneWidget);
    expect(find.text('پرداخت شده'), findsNothing);
    expect(find.text('2,000,000 تومان'), findsOneWidget);
    // The user is told the course is not theirs yet.
    expect(
      find.textContaining('پس از تأیید مدیر'),
      findsOneWidget,
    );
  });

  testWidgets('a settled order shows as paid', (tester) async {
    ignoreTestFontOverflow();

    api.orders = <Map<String, dynamic>>[
      orderRow(
        id: 12,
        number: 'MC-12',
        status: 'paid',
        total: 2000000,
        paid: 2000000,
        paymentTime: '2026-09-24T11:03:07Z',
      ),
    ];

    await pumpOrders(tester);

    expect(find.text('پرداخت شده'), findsOneWidget);
    expect(find.text('در انتظار پرداخت'), findsNothing);
    expect(find.text('مبلغ پرداخت شده'), findsOneWidget);
    // Nothing is pending, so the notice is not shown.
    expect(find.textContaining('پس از تأیید مدیر'), findsNothing);
  });

  testWidgets('every order the server returns is listed', (tester) async {
    ignoreTestFontOverflow();

    api.orders = <Map<String, dynamic>>[
      orderRow(id: 11, number: 'MC-11', status: 'pending', total: 2000000),
      orderRow(id: 12, number: 'MC-12', status: 'paid', total: 500000),
      orderRow(id: 13, number: 'MC-13', status: 'canceled', total: 900000),
    ];

    await pumpOrders(tester);

    expect(find.text('سفارش MC-11'), findsOneWidget);
    expect(find.text('سفارش MC-12'), findsOneWidget);
    expect(find.text('سفارش MC-13'), findsOneWidget);
    expect(find.text('لغو شده'), findsOneWidget);
  });

  testWidgets('an empty list explains what the screen is for', (tester) async {
    ignoreTestFontOverflow();
    await pumpOrders(tester);

    expect(find.text('هنوز سفارشی ندارید'), findsOneWidget);
    expect(find.text('رفتن به دوره‌ها'), findsOneWidget);
  });

  testWidgets('opening an order fetches its detail and names the course', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.orders = <Map<String, dynamic>>[
      orderRow(id: 11, number: 'MC-11', status: 'pending', total: 2000000),
    ];
    api.orderDetail = {
      ...orderRow(id: 11, number: 'MC-11', status: 'pending', total: 2000000),
      'coupon_code': 'OFF20',
      'description': 'ثبت نام دوره: کیک خامه‌ای حرفه‌ای',
      'items': <Map<String, dynamic>>[
        {
          'id': 5,
          'course_title': 'کیک خامه‌ای حرفه‌ای',
          'unit_price': 2500000,
          'quantity': 1,
          'discount_per_item': 500000,
          'line_total': 2000000,
        },
      ],
    };

    await pumpOrders(tester);

    await tester.tap(find.text('سفارش MC-11'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(
      api.getPaths.where((path) => path.contains('payments/orders/11')).length,
      1,
    );

    // The course name only exists in the detail payload.
    expect(find.text('کیک خامه‌ای حرفه‌ای'), findsOneWidget);
    expect(find.text('کد تخفیف'), findsOneWidget);
    expect(find.text('OFF20'), findsOneWidget);
    expect(find.text('جمع کل اقلام'), findsOneWidget);
  });
}

/// A `OrderList` payload with sane defaults.
Map<String, dynamic> orderRow({
  required int id,
  required String number,
  required String status,
  int total = 0,
  int discount = 0,
  int paid = 0,
  String? paymentTime,
}) => <String, dynamic>{
  'id': id,
  'order_number': number,
  'status': status,
  'subtotal': total + discount,
  'discount_amount': discount,
  'total_amount': total,
  'paid_amount': paid,
  'payment_gateway': 'mock',
  'payment_time': paymentTime,
  'items_count': 1,
  'created_at': '2026-09-24T11:03:07Z',
  'updated_at': '2026-09-24T11:03:07Z',
};

/// Answers the orders endpoints and records which paths were requested.
class FakeApiAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> orders = const <Map<String, dynamic>>[];

  Map<String, dynamic> orderDetail = const <String, dynamic>{};

  /// Every `GET` path the app asked for, in order.
  final List<String> getPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    if (method == 'GET') getPaths.add(path);

    // Detail first: `payments/orders/11/` also contains `payments/orders`.
    if (method == 'GET' &&
        RegExp(r'payments/orders/\d+/?$').hasMatch(path)) {
      return _json(200, {'success': true, 'data': orderDetail});
    }

    if (path.contains('payments/orders')) {
      return _json(200, {
        'count': orders.length,
        'next': null,
        'previous': null,
        'results': orders,
      });
    }

    return _json(200, {'success': true, 'data': <String, dynamic>{}});
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _json(int status, Map<String, dynamic> payload) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
}
