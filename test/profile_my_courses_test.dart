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
import 'package:mr_cake_project/pages/profile/widgets/profile_my_courses_section.dart';

/// «دوره‌های من» is the only place a user can see what they own, and it is fed
/// by **`GET v1/courses/my_courses/`** — which returns the full `CourseList`
/// objects, so a course never has to be looked up again by id.
///
/// ⚠️ It is *not* fed by `GET v1/courses/enrollments/`. That endpoint is
/// declared in the OpenAPI schema (`PaginatedEnrollmentList`) but the live
/// server answers `404 {"message":"یافت نشد."}` for it, and pointing this list
/// at it is what made the profile report «دوره یافت نشد» and show an empty
/// «دوره‌های من» while Postman happily returned the user's courses.
///
/// `enrollments/` is still consulted **best-effort** for `progress_percent`, so
/// the fake server answers 404 for it by default — exactly like production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int enrolledCourseId = 99;
  const String enrolledTitle = 'کیک سه‌طبقه عروسی';

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
  /// square, so the real widget overflows here and nowhere else.
  void ignoreTestFontOverflow() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if ('${details.exception}'.contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    ValueChanged<Course>? onCourseTap,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileMyCoursesSection(
                userId: 42,
                onCourseTap: onCourseTap,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the courses returned by my_courses are listed', (tester) async {
    ignoreTestFontOverflow();

    api.myCourses = <Map<String, dynamic>>[
      courseJson(id: 11, title: 'کیک شکلاتی'),
      courseJson(id: 12, title: 'ماکارون فرانسوی'),
    ];

    await pumpSection(tester);

    expect(find.text('دوره‌های من'), findsOneWidget);
    expect(find.text('کیک شکلاتی'), findsOneWidget);
    expect(find.text('ماکارون فرانسوی'), findsOneWidget);
    expect(find.text('هنوز دوره‌ای ندارید'), findsNothing);

    expect(
      api.getPaths.any((path) => path.contains('my_courses')),
      isTrue,
      reason: 'my_courses/ is the source of truth for the owned courses',
    );
  });

  testWidgets('progress from enrollments enriches the rows', (tester) async {
    ignoreTestFontOverflow();

    api.myCourses = <Map<String, dynamic>>[
      courseJson(id: enrolledCourseId, title: enrolledTitle),
    ];
    api.enrollmentsStatus = 200;
    api.enrollments = <Map<String, dynamic>>[
      {
        'id': 1,
        'course_id': enrolledCourseId,
        'progress_percent': 40,
      },
    ];

    await pumpSection(tester);

    expect(find.text(enrolledTitle), findsOneWidget);
    expect(find.text('40٪'), findsOneWidget);
  });

  testWidgets('a 404 on enrollments does not hide the courses', (tester) async {
    ignoreTestFontOverflow();

    // The live server answers 404 for `enrollments/`; the courses must still be
    // listed, just without a meaningful progress bar.
    api.myCourses = <Map<String, dynamic>>[
      courseJson(id: enrolledCourseId, title: enrolledTitle),
    ];

    await pumpSection(tester);

    expect(find.text(enrolledTitle), findsOneWidget);
    expect(find.text('0٪'), findsOneWidget);
    expect(find.text('هنوز دوره‌ای ندارید'), findsNothing);
  });

  testWidgets('an empty my_courses shows the empty state', (tester) async {
    ignoreTestFontOverflow();
    await pumpSection(tester);

    expect(find.text('هنوز دوره‌ای ندارید'), findsOneWidget);
    expect(find.text('شما هنوز در هیچ دوره‌ای ثبت‌نام نکرده‌اید'), findsOneWidget);
  });

  testWidgets('a failed my_courses says so, and retry recovers', (tester) async {
    ignoreTestFontOverflow();

    api.myCoursesStatus = 500;
    await pumpSection(tester);

    // Telling a user who owns courses that they own none is worse than
    // admitting the request failed.
    expect(find.text('دریافت دوره‌های شما ناموفق بود'), findsOneWidget);
    expect(find.text('هنوز دوره‌ای ندارید'), findsNothing);

    api.myCoursesStatus = 200;
    api.myCourses = <Map<String, dynamic>>[
      courseJson(id: enrolledCourseId, title: enrolledTitle),
    ];

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(find.text(enrolledTitle), findsOneWidget);
    expect(find.text('دریافت دوره‌های شما ناموفق بود'), findsNothing);
  });

  testWidgets('tapping a course reports it back to the profile', (tester) async {
    ignoreTestFontOverflow();

    api.myCourses = <Map<String, dynamic>>[
      courseJson(id: enrolledCourseId, title: enrolledTitle),
    ];

    Course? tapped;
    await pumpSection(tester, onCourseTap: (course) => tapped = course);

    await tester.tap(find.text(enrolledTitle));
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped!.id, enrolledCourseId);
    expect(tapped!.title, enrolledTitle);
  });
}

/// A `CourseList` row.
Map<String, dynamic> courseJson({required int id, required String title}) =>
    <String, dynamic>{
      'id': id,
      'title': title,
      'image': '',
      'price': '2500000',
      'instructor_last_name': 'محمدی',
    };

/// Answers `my_courses/` (+ the best-effort `enrollments/` call) and records
/// which paths were asked for.
class FakeApiAdapter implements HttpClientAdapter {
  /// `GET v1/courses/my_courses/` — the owned courses.
  List<Map<String, dynamic>> myCourses = const <Map<String, dynamic>>[];

  /// Status of the `my_courses/` call, so a failure can be simulated.
  int myCoursesStatus = 200;

  /// `GET v1/courses/enrollments/` — 404 on the live server, hence the default.
  List<Map<String, dynamic>> enrollments = const <Map<String, dynamic>>[];
  int enrollmentsStatus = 404;

  /// Every path the app asked for, in order.
  final List<String> getPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (options.method.toUpperCase() == 'GET') getPaths.add(path);

    if (path.contains('my_courses')) {
      if (myCoursesStatus != 200) {
        return _json(myCoursesStatus, {
          'success': false,
          'message': 'خطای سرور',
          'status_code': myCoursesStatus,
        });
      }
      return _page(myCourses);
    }

    if (path.contains('enrollments')) {
      if (enrollmentsStatus != 200) {
        return _json(enrollmentsStatus, {
          'success': false,
          'message': 'یافت نشد.',
          'status_code': enrollmentsStatus,
        });
      }
      return _page(enrollments);
    }

    return _json(200, {'success': true, 'data': <String, dynamic>{}});
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _page(List<Map<String, dynamic>> results) => _json(200, {
    'count': results.length,
    'next': null,
    'previous': null,
    'results': results,
  });

  ResponseBody _json(int status, Map<String, dynamic> payload) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
}
