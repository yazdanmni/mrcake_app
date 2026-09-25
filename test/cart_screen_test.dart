import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/pages/cart/cart_screen.dart';

/// «سبد خرید» is where a paid registration waits for an admin, so it is the only
/// feedback the user gets that their request was received.
///
/// Since the on-device mirrors (`CartStore` / `EnrollmentStore`) were deleted,
/// everything on this screen comes from `GET v1/payments/cart/`. These tests
/// therefore drive the real screen against a fake server and assert on what the
/// server said — including that a failed delete leaves the row alone instead of
/// pretending it worked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int courseId = 7;
  const String courseTitle = 'کیک خامه‌ای حرفه‌ای';

  /// One cart row, shaped like the nested payload the backend returns.
  Map<String, dynamic> cartRow({int id = 91, int price = 2500000}) => {
    'id': id,
    'course_id': courseId,
    'quantity': 1,
    'price': price,
    'course': {
      'id': courseId,
      'title': courseTitle,
      'image': '',
      'price': '$price',
      'instructor_last_name': 'محمدی',
    },
  };

  late FakeApiAdapter api;
  late HttpClientAdapter originalAdapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeApiAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  /// See `coupon_flow_test.dart` — the test font draws every Persian glyph as a
  /// square, so the real screens overflow here and nowhere else. The filter has
  /// to be installed inside the body, after `testWidgets` sets its own handler.
  void ignoreTestFontOverflow() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if ('${details.exception}'.contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpCart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a pending request comes from the server, with its price', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.cartItems = <Map<String, dynamic>>[cartRow()];

    await pumpCart(tester);

    expect(find.text('سبد خرید'), findsOneWidget);
    expect(find.text(courseTitle), findsOneWidget);
    expect(find.text('در انتظار تأیید'), findsOneWidget);
    expect(find.text('2,500,000 تومان'), findsWidgets);
    expect(find.text('سبد خرید شما خالی است'), findsNothing);
    // No "pay" affordance — the row is a request, not a basket item.
    expect(find.text('پرداخت'), findsNothing);
  });

  testWidgets('an empty cart explains what it is for', (tester) async {
    ignoreTestFontOverflow();
    await pumpCart(tester);

    expect(find.text('سبد خرید شما خالی است'), findsOneWidget);
    expect(find.text('رفتن به دوره‌ها'), findsOneWidget);
  });

  testWidgets('removing a row deletes it on the server and drops the row', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.cartItems = <Map<String, dynamic>>[cartRow(id: 91)];

    await pumpCart(tester);
    expect(find.text(courseTitle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // The row is gone from the screen *and* from the server, so a reload cannot
    // bring it back.
    expect(find.text(courseTitle), findsNothing);
    expect(find.text('سبد خرید شما خالی است'), findsOneWidget);
    expect(api.deletedCartItemIds, <int>[91]);
  });

  testWidgets('a failed delete keeps the row and says so', (tester) async {
    ignoreTestFontOverflow();

    api.cartItems = <Map<String, dynamic>>[cartRow(id: 91)];
    api.failDeletes = true;

    await pumpCart(tester);
    expect(find.text(courseTitle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // There is no local copy to fall back on, so pretending the delete worked
    // would make the row reappear on the next load.
    expect(find.text(courseTitle), findsOneWidget);
    expect(
      find.text('حذف از سبد خرید ناموفق بود. دوباره تلاش کنید.'),
      findsOneWidget,
    );
    expect(find.text('سبد خرید شما خالی است'), findsNothing);
  });

  testWidgets('an approved course leaves the cart for «دوره‌های من»', (
    tester,
  ) async {
    ignoreTestFontOverflow();

    api.cartItems = <Map<String, dynamic>>[cartRow()];

    // The admin approved it: the course is now an enrollment, so it must stop
    // being listed as pending.
    api.enrolledCourseIds = const <int>[courseId];

    await pumpCart(tester);

    expect(find.text(courseTitle), findsNothing);
    expect(find.text('سبد خرید شما خالی است'), findsOneWidget);
  });
}

/// Fakes only the socket. `GET v1/payments/cart/` answers the real public
/// payload; `GET v1/courses/my_courses/` answers a DRF page of `CourseList`
/// rows — the endpoint the cart checks to decide whether a pending request has
/// been approved.
class FakeApiAdapter implements HttpClientAdapter {
  /// Course ids the user is already enrolled in, as `my_courses/` reports them.
  List<int> enrolledCourseIds = const <int>[];

  /// Rows the server itself returns in the cart.
  List<Map<String, dynamic>> cartItems = const <Map<String, dynamic>>[];

  /// When true every `DELETE v1/payments/cart/{id}/` answers 500.
  bool failDeletes = false;

  /// Row ids the screen asked the server to delete, in order.
  final List<int> deletedCartItemIds = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    if (path.contains('payments/cart')) {
      if (method == 'DELETE') {
        if (failDeletes) {
          return _json(500, {'success': false, 'message': 'خطای سرور'});
        }

        final int id = int.tryParse(
              RegExp(r'(\d+)/?$').firstMatch(path)?.group(1) ?? '',
            ) ??
            0;

        deletedCartItemIds.add(id);
        cartItems = cartItems
            .where((row) => row['id'] != id)
            .toList(growable: false);

        return _json(200, {'success': true, 'data': <String, dynamic>{}});
      }

      return _json(200, {
        'success': true,
        'data': {
          'items': cartItems,
          'total_items': cartItems.length,
          'unique_courses': cartItems.length,
          'subtotal': 0,
          'total': 0,
        },
      });
    }

    // `my_courses/`, not `enrollments/`: the latter is declared in the OpenAPI
    // schema but the live server answers `404 یافت نشد.` for it.
    if (path.contains('courses/my_courses')) {
      return _json(200, {
        'count': enrolledCourseIds.length,
        'next': null,
        'previous': null,
        'results': enrolledCourseIds
            .map((id) => {'id': id, 'title': 'دوره $id'})
            .toList(),
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
