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
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/course_learning/course_learning_screen.dart';

/// End-to-end coverage of the registration flow, driven through the real
/// `CourseDetailsScreen` dialogs.
///
/// There is no live account to test against, so the network is replaced by
/// [FakeApiAdapter] — a `HttpClientAdapter` that answers from a routing table.
/// Everything above the socket (ApiClient, repositories, the widget, the
/// dialogs) is production code.
///
/// The rule being pinned down:
///   * **the created order has the last word.** A registration always creates an
///     order, and it is the order's `total_amount` — never the client-side coupon
///     maths — that decides whether anything is owed;
///   * a **zero total** (free course, or a 100 % coupon) enrolls the user and
///     sends **nothing else**: no ticket, no cart row. This is the bug that was
///     reported: a coupon that zeroed the amount still filed a request;
///   * anything that still costs money is **not charged**. It files a support
///     ticket on the user's behalf (name, family name and phone number filled in
///     automatically) and parks the course in the cart until an admin approves
///     the order.
///
/// Nothing is mirrored on the device any more — `CartStore` and
/// `EnrollmentStore` are gone — so the assertions are about what was actually
/// sent to the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int courseId = 7;
  const int price = 2500000;

  const course = Course(
    id: courseId,
    image: '',
    title: 'کیک خامه‌ای حرفه‌ای',
    instructorFirstName: 'زهرا',
    instructorLastName: 'محمدی',
    instructorImage: '',
    price: '$price',
    currency: 'تومان',
    lessons: '12',
    duration: '3',
    studentsCount: 0,
    categoryIds: <int>[],
    type: CourseType.professional,
    access: CourseAccess.paid, instructorId: 1,
  );

  late FakeApiAdapter api;
  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'mr_cake.auth.access_token': 'test-token',
      // The paid path writes these three into the ticket, so the session has to
      // carry them exactly like a real sign-in would.
      'mr_cake.auth.user': jsonEncode({
        'id': 42,
        'phone_number': '09123456789',
        'first_name': 'علی',
        'last_name': 'رضایی',
      }),
    });
    // Wires ApiClient.accessTokenProvider.
    await SessionManager.instance.init();
  });

  setUp(() async {
    RemoteCache.clear();

    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeApiAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// `flutter test` ships no Persian font, so every glyph is drawn as a square
  /// of `fontSize`. Copy that fits comfortably on a device therefore measures
  /// far wider here, and this full production screen reports
  /// `RenderFlex overflowed` in places that never overflow for a real user.
  /// Filter exactly those messages out; every other error still fails the test.
  ///
  /// This has to run **inside** the test body rather than in `setUp`:
  /// `testWidgets` installs the binding's own `FlutterError.onError` when the
  /// body starts, so anything set up earlier is overwritten before the first
  /// pump and the overflow is reported as a test failure.
  void ignoreTestFontOverflow() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if ('${details.exception}'.contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  /// Pumps until the tree settles (kept as a named helper so the intent — "the
  /// dialogs are opened by taps and need a full settle" — reads clearly).
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  /// Pumps the real screen at the Figma design size.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => const MaterialApp(
          home: CourseDetailsScreen(course: course),
        ),
      ),
    );
    await settle(tester);
  }

  /// Scrolls the register button into view and taps it.
  Future<void> openRegisterDialog(WidgetTester tester) async {
    final button = find.text('ثبت نام دوره');
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
  }

  /// The coupon field lives inside the dialog, not on the page behind it.
  Finder couponField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  /// Types [code] into the coupon field and presses the apply icon.
  ///
  /// The suffix icon and `onSubmitted` run the same validation; the icon is what
  /// a user taps, so that is what is driven here.
  Future<void> applyCoupon(WidgetTester tester, String code) async {
    await tester.enterText(couponField(), code);
    await tester.tap(find.byIcon(Icons.local_activity_outlined));
    await settle(tester);
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  testWidgets('a paid course asks for a coupon code first', (tester) async {
    ignoreTestFontOverflow();
    await pumpScreen(tester);
    await openRegisterDialog(tester);

    expect(find.text('خرید دوره'), findsOneWidget);
    expect(couponField(), findsOneWidget);
    expect(find.text('مبلغ قابل پرداخت'), findsOneWidget);
    // Nothing applied yet -> the request wording, never a payment wording.
    expect(find.text('ارسال درخواست ثبت نام'), findsOneWidget);
    expect(find.text('ادامه و پرداخت'), findsNothing);
    expect(find.text('ثبت نام رایگان فوری'), findsNothing);
    // Nothing is sent just by opening the dialog.
    expect(api.orderPosts, isEmpty);
  });

  testWidgets('a 100% coupon enrolls for free and sends no request', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.coupon = const {
      'code': 'FREE100',
      'discount_type': 'percent',
      'discount_value': 100,
      'title': 'کد رایگان',
    };
    // The server agrees the order costs nothing.
    api.order = fakeOrder(
      id: 11,
      subtotal: price,
      discountAmount: price,
      totalAmount: 0,
      couponCode: 'FREE100',
    );

    await pumpScreen(tester);
    await openRegisterDialog(tester);
    await applyCoupon(tester, 'FREE100');

    // The coupon is recognised as covering the whole price.
    expect(find.text('ثبت نام رایگان فوری'), findsOneWidget);
    expect(find.text('ارسال درخواست ثبت نام'), findsNothing);
    expect(find.text('کد تخفیف شما کل هزینه دوره را پوشش می‌دهد.'), findsOneWidget);

    // ... so it enters the SAME confirmation dialog a free course uses.
    await tester.tap(find.text('ثبت نام رایگان فوری'));
    await settle(tester);

    expect(find.text('ثبت نام در دوره'), findsOneWidget);
    expect(find.text('بله، می‌خواهم دانشجوی این دوره شوم'), findsOneWidget);
    // The dialog says *why* nothing is owed — the coupon covered the price,
    // the course itself is not a free one.
    expect(
      find.text(
        'کد تخفیف شما کل هزینه این دوره را پوشش داد. آیا می‌خواهید دانشجوی این دوره شوید؟',
      ),
      findsOneWidget,
    );
    // Nothing has been posted yet — the user has not confirmed.
    expect(api.orderPosts, isEmpty);
    expect(api.ticketPosts, isEmpty);

    // Tick the checkbox and confirm.
    await tester.tap(find.text('بله، می‌خواهم دانشجوی این دوره شوم'));
    await settle(tester);
    await tester.tap(find.text('تأیید و ثبت نام'));
    await settle(tester);

    // The order was created, with the coupon attached.
    expect(api.orderPosts.length, 1);
    final body = api.orderPosts.single;
    expect(body['course_ids'], <dynamic>[courseId]);
    expect(body['coupon_code'], 'FREE100');
    expect(body['gateway'], 'mock');

    // A zero total is a free enrollment: **no ticket and no cart row**. This is
    // the reported bug — the request used to be filed anyway.
    expect(api.ticketPosts, isEmpty);
    expect(api.cartPosts, isEmpty);

    // Free wording, not "payment succeeded".
    expect(find.text('ثبت نام با موفقیت انجام شد'), findsOneWidget);
    expect(find.text('پرداخت با موفقیت انجام شد'), findsNothing);
    expect(find.text('درخواست ثبت نام ارسال شد'), findsNothing);
  });

  testWidgets('the free confirmation leads into the course content', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.coupon = const {
      'code': 'FREE100',
      'discount_type': 'percent',
      'discount_value': 100,
      'title': 'کد رایگان',
    };
    api.order = fakeOrder(
      id: 11,
      subtotal: price,
      discountAmount: price,
      totalAmount: 0,
      couponCode: 'FREE100',
    );

    await pumpScreen(tester);
    await openRegisterDialog(tester);
    await applyCoupon(tester, 'FREE100');
    await tester.tap(find.text('ثبت نام رایگان فوری'));
    await settle(tester);
    await tester.tap(find.text('بله، می‌خواهم دانشجوی این دوره شوم'));
    await settle(tester);
    await tester.tap(find.text('تأیید و ثبت نام'));
    await settle(tester);

    expect(find.text('شروع یادگیری'), findsOneWidget);

    await tester.tap(find.text('شروع یادگیری'));
    await settle(tester);

    // «بعد از صفحه جزئیات دوره» — a student lands on the course content.
    expect(find.byType(CourseLearningScreen), findsOneWidget);
  });

  testWidgets('an order that costs nothing sends no ticket even when the '
      'coupon cannot be sized on the client', (tester) async {
    ignoreTestFontOverflow();

    // `POST v1/discounts/apply/validate/` is documented with no response body,
    // so a 100 % coupon can decode to an empty map and look exactly like "no
    // discount at all". The client therefore has no idea whether the course is
    // free — and must not guess.
    api.coupon = const <String, dynamic>{};
    // The order is the authority, and it says the price is zero.
    api.order = fakeOrder(
      id: 12,
      subtotal: price,
      discountAmount: price,
      totalAmount: 0,
      couponCode: 'FREE100',
    );

    await pumpScreen(tester);
    await openRegisterDialog(tester);
    await applyCoupon(tester, 'FREE100');

    // The client cannot tell, so it offers the generic request wording...
    expect(find.text('ارسال درخواست ثبت نام'), findsOneWidget);

    await tester.tap(find.text('ارسال درخواست ثبت نام'));
    await settle(tester);

    // ...but the order says zero, so it is a free enrollment.
    expect(api.orderPosts.length, 1);
    expect(api.orderPosts.single['coupon_code'], 'FREE100');
    expect(api.ticketPosts, isEmpty, reason: 'a zero total must not file a ticket');
    expect(api.cartPosts, isEmpty, reason: 'a zero total must not enter the cart');
    expect(find.text('ثبت نام با موفقیت انجام شد'), findsOneWidget);
  });

  testWidgets('a partial coupon only discounts and files a request', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.coupon = const {
      'code': 'OFF20',
      'discount_type': 'percent',
      'discount_value': 20,
      'title': 'تخفیف ۲۰٪',
    };
    api.order = fakeOrder(
      id: 13,
      subtotal: price,
      discountAmount: 500000,
      totalAmount: 2000000,
      couponCode: 'OFF20',
    );

    await pumpScreen(tester);
    await openRegisterDialog(tester);
    await applyCoupon(tester, 'OFF20');

    // The amount is settled before anything is sent.
    expect(find.text('ارسال درخواست ثبت نام'), findsOneWidget);
    expect(find.text('تخفیف اعمال شده'), findsOneWidget);
    expect(find.text('- 500,000 تومان'), findsOneWidget);
    expect(find.text('2,000,000 تومان'), findsOneWidget);

    await tester.tap(find.text('ارسال درخواست ثبت نام'));
    await settle(tester);

    // The order records the request with the coupon attached…
    expect(api.orderPosts.length, 1);
    expect(api.orderPosts.single['coupon_code'], 'OFF20');

    // …and nothing was charged. Instead a ticket was filed on the user's behalf,
    // with the identity the user asked to have filled in automatically.
    expect(api.ticketPosts.length, 1);
    final ticket = api.ticketPosts.single;
    final message = ticket['message'] as String;
    expect(message, contains('علی رضایی'));
    expect(message, contains('09123456789'));
    expect(message, contains('کد تخفیف: OFF20'));
    expect(message, contains('مبلغ تخفیف: 500,000 تومان'));
    // The amount comes from the ORDER, not from the client-side coupon maths.
    expect(message, contains('مبلغ قابل پرداخت: 2,000,000 تومان'));
    expect(ticket['title'], contains('کیک خامه‌ای حرفه‌ای'));
    expect(ticket['title'], contains('علی رضایی'));
    // Matched by name against the live subject list, not hard-coded.
    expect(ticket['subject_id'], 1);
    expect(ticket['priority'], 'high');

    // The course is parked in the cart until the request is approved.
    expect(api.cartPosts.single['course'], courseId);

    expect(find.text('درخواست ثبت نام ارسال شد'), findsOneWidget);
    expect(find.text('پرداخت با موفقیت انجام شد'), findsNothing);
    // A paid request is not an enrollment yet.
    expect(find.text('ثبت نام با موفقیت انجام شد'), findsNothing);
  });

  testWidgets('an invalid coupon still files the request, without the code', (
    tester,
  ) async {
    ignoreTestFontOverflow();
    api.coupon = null; // -> the endpoint answers 404

    await pumpScreen(tester);
    await openRegisterDialog(tester);
    await applyCoupon(tester, 'NOPE');

    expect(
      find.text('کد تخفیف وارد شده معتبر نیست یا منقضی شده است.'),
      findsOneWidget,
    );

    // Continuing must still send the request, WITHOUT the bad code.
    await tester.tap(find.text('ارسال درخواست ثبت نام'));
    await settle(tester);

    expect(api.orderPosts.length, 1);
    expect(api.orderPosts.single.containsKey('coupon_code'), isFalse);

    expect(api.ticketPosts.length, 1);
    final message = api.ticketPosts.single['message'] as String;
    expect(message, isNot(contains('NOPE')));
    expect(message, contains('علی رضایی'));
    expect(api.cartPosts.length, 1);
    expect(find.text('درخواست ارسال شد'), findsNothing);
    expect(find.text('درخواست ثبت نام ارسال شد'), findsOneWidget);
  });
}

/// A `OrderDetail` payload with sane defaults, so each test only states what it
/// cares about.
Map<String, dynamic> fakeOrder({
  required int id,
  required int subtotal,
  int discountAmount = 0,
  int totalAmount = 0,
  int paidAmount = 0,
  String status = 'pending',
  String couponCode = '',
}) => <String, dynamic>{
  'id': id,
  'order_number': 'MC-$id',
  'status': status,
  'subtotal': subtotal,
  'discount_amount': discountAmount,
  'total_amount': totalAmount,
  'paid_amount': paidAmount,
  'payment_gateway': 'mock',
  'payment_time': null,
  'items_count': 1,
  'items': <dynamic>[],
  'tax_amount': 0,
  'coupon_code': couponCode,
  'payments': '',
  'created_at': '2026-09-24T00:00:00Z',
  'updated_at': '2026-09-24T00:00:00Z',
  'user': <String, dynamic>{},
};

/// Routes the app's requests to canned responses and records what was posted.
class FakeApiAdapter implements HttpClientAdapter {
  /// `null` makes the coupon endpoint answer `404 کد تخفیف یافت نشد`.
  Map<String, dynamic>? coupon = const {
    'code': 'FREE100',
    'discount_type': 'percent',
    'discount_value': 100,
    'title': 'کد رایگان',
  };

  /// The `OrderDetail` the order endpoint answers with.
  Map<String, dynamic> order = fakeOrder(
    id: 1,
    subtotal: 2500000,
    totalAmount: 2500000,
    paidAmount: 2500000,
    status: 'paid',
  );

  /// The live `GET v1/support/subjects/` payload, trimmed to the fields the
  /// repository reads. Returned newest-first, exactly like the real endpoint —
  /// which is why the subject has to be matched by name and not by position.
  static const List<Map<String, dynamic>> subjects = <Map<String, dynamic>>[
    {'id': 4, 'name': 'درخواست دوره های قبلی خودتان'},
    {'id': 3, 'name': 'خرید های قبل'},
    {'id': 2, 'name': 'مشکل در خرید دوره ها'},
    {'id': 1, 'name': 'خرید دوره های جدید'},
  ];

  /// Every decoded body posted to `POST v1/payments/orders/`.
  final List<Map<String, dynamic>> orderPosts = <Map<String, dynamic>>[];

  /// Every decoded body posted to `POST v1/support/`.
  final List<Map<String, dynamic>> ticketPosts = <Map<String, dynamic>>[];

  /// Every decoded body posted to `POST v1/payments/cart/`.
  final List<Map<String, dynamic>> cartPosts = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    if (path.contains('discounts/apply/validate')) {
      final coupon = this.coupon;
      if (coupon == null) {
        return _json(404, {
          'success': false,
          'message': 'کد تخفیف یافت نشد',
        });
      }
      return _json(200, {'success': true, 'data': coupon});
    }

    if (path.contains('support/subjects')) {
      return _json(200, {
        'count': subjects.length,
        'next': null,
        'previous': null,
        'results': subjects,
      });
    }

    if (path.contains('support') && method == 'POST') {
      final body = _body(options);
      if (body != null) ticketPosts.add(body);
      return _json(201, {
        'success': true,
        'data': {
          'id': 77,
          'title': body?['title'] ?? '',
          'status': 'open',
          'priority': body?['priority'] ?? 'normal',
          'messages': <dynamic>[],
        },
      });
    }

    if (path.contains('payments/cart') && method == 'POST') {
      final body = _body(options);
      if (body != null) cartPosts.add(body);
      return _json(201, {'success': true, 'data': <String, dynamic>{}});
    }

    if (path.contains('payments/orders') && method == 'POST') {
      final body = _body(options);
      if (body != null) orderPosts.add(body);
      return _json(200, {'success': true, 'data': order});
    }

    // Course detail / anything else: an empty but valid envelope.
    return _json(200, {'success': true, 'data': <String, dynamic>{}});
  }

  @override
  void close({bool force = false}) {}

  static Map<String, dynamic>? _body(RequestOptions options) {
    final raw = options.data;
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  ResponseBody _json(int status, Map<String, dynamic> payload) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
}
