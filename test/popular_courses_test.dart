import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/home/home_courses.dart';
import 'package:mr_cake_project/pages/home/widgets/course_card.dart';
import 'package:mr_cake_project/utils/course_utils.dart';

/// The home «دوره های محبوب» carousel must show the courses with the **most
/// students**, ranked so the best-seller leads the list.
///
/// Two things used to break that:
///
///  1. the selection was `perType: 2` — two courses out of every `CourseType`
///     bucket, emitted free → professional → single. That is a *balanced* mix,
///     not a ranking, so the free bucket was always pushed to the front even
///     when its courses had fewer students;
///  2. the data came from `v1/courses/best_selling/`, which is **auth-only**
///     (a guest gets 401) and returns the backend's own notion of "best
///     selling" rather than an explicit student-count order.
///
/// The fix keeps the widget untouched and changes the data: the carousel now
/// asks for `v1/courses/?ordering=-students_count` (verified against the live
/// backend: `۳، ۲، ۰` هنرجو, where the default order is `۲، ۰، ۳`) and ranks
/// locally as a fallback, so the order is right even on an older deployment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Course course({
    required int id,
    required String title,
    required int students,
    CourseType type = CourseType.professional,
    String? rating,
  }) => Course(
    id: id,
    image: '',
    title: title,
    instructorFirstName: 'مریم',
    instructorLastName: 'احمدی',
    instructorImage: '',
    price: '2500000',
    currency: 'تومان',
    lessons: '8',
    duration: '2',
    studentsCount: students,
    categoryIds: const <int>[1],
    type: type,
    access: CourseAccess.paid,
    rating: rating, instructorId: 1,
  );

  group('CourseUtils.getPopularCourses', () {
    test('puts the course with the most students first', () {
      final ranked = CourseUtils.getPopularCourses(
        courses: [
          course(id: 1, title: 'کم', students: 10),
          course(id: 2, title: 'زیاد', students: 50),
          course(id: 3, title: 'متوسط', students: 30),
        ],
      );

      expect(
        ranked.map((c) => c.studentsCount).toList(),
        <int>[50, 30, 10],
      );
      expect(ranked.first.title, 'زیاد');
    });

    test('a balanced per-type mix no longer overrides the ranking', () {
      // The old implementation emitted the free bucket first, so this free
      // course led the carousel even though it has the fewest students.
      final ranked = CourseUtils.getPopularCourses(
        courses: [
          course(
            id: 1,
            title: 'رایگان',
            students: 5,
            type: CourseType.free,
          ),
          course(id: 2, title: 'حرفه‌ای', students: 100),
          course(
            id: 3,
            title: 'تک‌آموزشی',
            students: 50,
            type: CourseType.single,
          ),
        ],
      );

      expect(
        ranked.map((c) => c.title).toList(),
        <String>['حرفه‌ای', 'تک‌آموزشی', 'رایگان'],
      );
    });

    test('courses nobody has joined yet sink to the bottom', () {
      final ranked = CourseUtils.getPopularCourses(
        courses: [
          course(id: 1, title: 'بدون هنرجو', students: 0),
          course(id: 2, title: 'پرطرفدار', students: 3),
        ],
      );

      expect(ranked.last.title, 'بدون هنرجو');
    });

    test('ties are broken by rating, then by id, so the order is stable', () {
      final tied = [
        course(id: 3, title: 'ج', students: 20),
        course(id: 1, title: 'الف', students: 20),
        course(id: 2, title: 'ب', students: 20),
      ];

      expect(
        CourseUtils.getPopularCourses(courses: tied).map((c) => c.id).toList(),
        <int>[1, 2, 3],
      );

      expect(
        CourseUtils.getPopularCourses(
          courses: [
            course(id: 1, title: 'کم‌امتیاز', students: 20, rating: '3.00'),
            course(id: 2, title: 'پرامتیاز', students: 20, rating: '4.90'),
          ],
        ).first.title,
        'پرامتیاز',
      );
    });

    test('limit caps the carousel without reordering it', () {
      final ranked = CourseUtils.getPopularCourses(
        limit: 2,
        courses: [
          course(id: 1, title: 'الف', students: 10),
          course(id: 2, title: 'ب', students: 40),
          course(id: 3, title: 'ج', students: 20),
        ],
      );

      expect(ranked.map((c) => c.studentsCount).toList(), <int>[40, 20]);
    });

    test('no courses means an empty carousel', () {
      expect(CourseUtils.getPopularCourses(courses: const []), isEmpty);
      expect(CourseUtils.getPopularCourses(), isEmpty);
    });
  });

  group('HomeCourses', () {
    late FakeCoursesAdapter api;
    late HttpClientAdapter originalAdapter;

    setUp(() {
      RemoteCache.clear();
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      api = FakeCoursesAdapter();
      ApiClient.instance.dio.httpClientAdapter = api;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    /// The test font draws every Persian glyph as a square, so the real widget
    /// overflows here and nowhere else — see `coupon_flow_test.dart`.
    void ignoreTestFontOverflow() {
      final void Function(FlutterErrorDetails)? original = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if ('${details.exception}'.contains('overflowed by')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }

    Future<void> pumpCarousel(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 390, child: HomeCourses()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the carousel asks the backend for the student ranking', (
      tester,
    ) async {
      ignoreTestFontOverflow();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 2, title: 'دوره پرطرفدار', students: 3),
        courseJson(id: 4, title: 'دوره دوم', students: 2),
      ];

      await pumpCarousel(tester);

      expect(
        api.coursesQuery?['ordering'],
        '-students_count',
        reason: 'the backend ranks by student count, most popular first',
      );
    });

    testWidgets('only the courses with the most students reach the carousel', (
      tester,
    ) async {
      ignoreTestFontOverflow();

      // Deliberately *not* in popularity order: the ranking has to come from
      // the app, not from the order the fake server happens to answer in.
      // Seven courses, so the three cards the carousel renders must be the
      // three best-sellers — not simply the first three rows.
      api.courses = <Map<String, dynamic>>[
        courseJson(id: 1, title: 'الف', students: 10),
        courseJson(id: 2, title: 'ب', students: 20),
        courseJson(id: 3, title: 'ج', students: 30),
        courseJson(id: 4, title: 'د', students: 40),
        courseJson(id: 5, title: 'ه', students: 50),
        courseJson(id: 6, title: 'و', students: 60),
        courseJson(id: 7, title: 'ز', students: 70),
      ];

      await pumpCarousel(tester);

      final rendered = tester
          .widgetList<CourseCard>(find.byType(CourseCard))
          .map((card) => card.course)
          .toList();

      expect(
        rendered.map((c) => c.studentsCount).toSet(),
        <int>{70, 60, 50},
        reason: 'the carousel is filled from the top of the ranking',
      );
    });

    testWidgets('the most popular course leads the row', (tester) async {
      ignoreTestFontOverflow();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 3, title: 'بدون هنرجو', students: 0),
        courseJson(id: 2, title: 'دوره پرطرفدار', students: 90),
        courseJson(id: 4, title: 'دوره دوم', students: 20),
      ];

      await pumpCarousel(tester);

      double dxOf(int courseId) => tester
          .getCenter(
            find.byWidgetPredicate(
              (widget) => widget is CourseCard && widget.course.id == courseId,
            ),
          )
          .dx;

      expect(
        dxOf(2),
        lessThan(dxOf(4)),
        reason: 'the course with the most students comes first, not second',
      );
    });
  });
}

/// A `CourseList` row as the backend sends it.
Map<String, dynamic> courseJson({
  required int id,
  required String title,
  required int students,
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'image': 'https://media.dl.mceiran.website/courses/images/cover.jpg',
  'price': 2500000,
  'is_free': false,
  'lessons_count': 8,
  'students_count': students,
  'teacher': {'first_name': 'مریم', 'last_name': 'احمدی'},
};

/// Answers `GET v1/courses/` and records the query it was asked with.
class FakeCoursesAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> courses = const <Map<String, dynamic>>[];

  /// The `?ordering=…` query the carousel sent, when it sent one.
  Map<String, dynamic>? coursesQuery;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('courses/') ||
        options.path.contains('courses/?')) {
      coursesQuery = Map<String, dynamic>.of(options.queryParameters);
      return _json(200, {
        'links': {'next': null, 'previous': null},
        'count': courses.length,
        'total_pages': 1,
        'current_page': 1,
        'results': courses,
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
