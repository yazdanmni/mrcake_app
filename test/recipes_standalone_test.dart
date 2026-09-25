import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/pages/recipes/recipes_screen.dart';

import 'support/app_fonts.dart';

/// «رسپی‌ها» must list **only** recipes that belong to no course.
///
/// A recipe with `course` set is part of what that course teaches, so showing
/// it on the public recipe screen would hand out a paid course's material for
/// free. The screen used to filter on `featured == true && courseId == null`,
/// which excluded every standalone recipe that was not marked featured — the
/// opposite of "show the ones that are not for a course".
///
/// The API cannot express the filter (`course`, `category`, `featured`,
/// `difficulty`, `is_active` — no `course__isnull`), so it happens in the app,
/// and pagination has to advance on the *unfiltered* page or a page made
/// entirely of course recipes looks like the end of the list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRecipesAdapter api;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    RemoteCache.clear();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeRecipesAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  Future<void> pumpRecipes(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    // The real fonts, so a `RenderFlex overflowed` here is a genuine one — see
    // `support/app_fonts.dart`.
    await loadAppFonts();

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (BuildContext context, Widget? child) =>
            const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls to the end of the list, which is what asks for the next page.
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -2500),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
  }

  group('RecipesScreen only lists standalone recipes', () {
    testWidgets('a recipe that belongs to a course is never listed', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.pages = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[
          recipeJson(id: 1, title: 'کیک شکلاتی', course: null),
          recipeJson(id: 2, title: 'درس دوره حرفه‌ای', course: 7),
          recipeJson(id: 3, title: 'تارت لیمو', course: null),
        ],
      };

      await pumpRecipes(tester);

      expect(find.text('کیک شکلاتی'), findsOneWidget);
      expect(find.text('تارت لیمو'), findsOneWidget);
      expect(
        find.text('درس دوره حرفه‌ای'),
        findsNothing,
        reason: 'a recipe with `course` set belongs to that course',
      );
    });

    testWidgets('a standalone recipe shows even when it is not featured', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.pages = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[
          recipeJson(id: 1, title: 'رسپی عادی', featured: false),
        ],
      };

      await pumpRecipes(tester);

      expect(
        find.text('رسپی عادی'),
        findsOneWidget,
        reason: '`featured` is not a reason to hide a standalone recipe',
      );
    });

    testWidgets('a page of course recipes does not end the list', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      // Page 2 is *entirely* course recipes. Advancing on the filtered page
      // would stop the list right there and page 3 — the standalone ones —
      // would never load.
      api.pages = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[
          for (var i = 1; i <= 8; i++)
            recipeJson(id: i, title: 'رسپی مستقل $i'),
        ],
        2: <Map<String, dynamic>>[
          for (var i = 20; i <= 24; i++)
            recipeJson(id: i, title: 'رسپی دوره $i', course: 3),
        ],
        3: <Map<String, dynamic>>[
          recipeJson(id: 30, title: 'رسپی پایانی الف'),
          recipeJson(id: 31, title: 'رسپی پایانی ب'),
        ],
      };

      await pumpRecipes(tester);

      // Page 1 renders, so the list is scrollable and the next page is asked
      // for the moment the end is reached.
      expect(find.text('رسپی مستقل 1'), findsOneWidget);

      await scrollToEnd(tester);

      expect(
        api.requestedPages,
        containsAll(<int>[1, 2, 3]),
        reason: 'a fully filtered page must not stop the pagination',
      );
      expect(find.text('رسپی پایانی الف'), findsOneWidget);
      expect(find.text('رسپی دوره 20'), findsNothing);
    });

    testWidgets('an empty library shows the app-wide empty state, not a bare '
        'sentence', (tester) async {
      ignoreNetworkImageErrors();

      // Every row on the page belongs to a course, so the standalone list ends
      // up empty — the screen has to explain itself the way the courses
      // screens do, instead of leaving a lone line inside a grid cell.
      api.pages = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[
          recipeJson(id: 1, title: 'رسپی دوره', course: 5),
        ],
      };

      await pumpRecipes(tester);

      expect(
        find.textContaining('هنوز رسپی مستقلی اضافه نشده'),
        findsOneWidget,
        reason: 'the empty state must be the app-wide one',
      );
      expect(find.byIcon(Icons.restaurant_menu_outlined), findsOneWidget);
    });

    testWidgets('a backend with nothing at all is stated, not left blank', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.pages = <int, List<Map<String, dynamic>>>{};

      await pumpRecipes(tester);

      expect(find.textContaining('هنوز رسپی مستقلی اضافه نشده'), findsOneWidget);
    });

    testWidgets('a search that matches nothing says so — and does not claim '
        'the library is empty', (tester) async {
      ignoreNetworkImageErrors();

      api.pages = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[recipeJson(id: 1, title: 'کیک شکلاتی')],
      };

      await pumpRecipes(tester);
      expect(find.text('کیک شکلاتی'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'پیتزا');
      // `_onSearchChanged` debounces by 350ms before it reaches the API.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('رسپی‌ای پیدا نشد'), findsOneWidget);
      expect(
        find.textContaining('هنوز رسپی مستقلی اضافه نشده'),
        findsNothing,
        reason: 'the library is not empty — the search simply matched nothing',
      );
    });
  });

  group('RecipesScreen responsiveness', () {
    const Map<String, Size> devices = <String, Size>{
      'iPhone SE 320×568': Size(320, 568),
      'Galaxy 360×640': Size(360, 640),
      'iPhone 13 390×844 (design)': Size(390, 844),
      'Pixel 7 412×915': Size(412, 915),
      'iPad mini 768×1024': Size(768, 1024),
      'phone landscape 844×390': Size(844, 390),
      'tablet landscape 1024×768': Size(1024, 768),
    };

    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('lays out without overflow on ${device.key}', (tester) async {
        ignoreNetworkImageErrors();

        api.pages = <int, List<Map<String, dynamic>>>{
          1: <Map<String, dynamic>>[
            for (var i = 1; i <= 4; i++)
              recipeJson(id: i, title: 'رسپی شماره $i'),
          ],
        };

        await pumpRecipes(tester, size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the grid must scale with ${device.key}',
        );
      });

      testWidgets('lays the empty state out without overflow on ${device.key}', (
        tester,
      ) async {
        ignoreNetworkImageErrors();

        api.pages = <int, List<Map<String, dynamic>>>{};

        await pumpRecipes(tester, size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the empty state must scale with ${device.key}',
        );
        expect(
          find.textContaining('هنوز رسپی مستقلی اضافه نشده'),
          findsOneWidget,
        );
      });
    }
  });
}

/// A `RecipeList` row as the backend sends it. `course` is a plain nullable id.
Map<String, dynamic> recipeJson({
  required int id,
  required String title,
  int? course,
  bool featured = false,
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'slug': 'recipe-$id',
  'image': 'https://media.dl.mceiran.website/recipes/$id.jpg',
  'short_description': 'توضیح کوتاه $id',
  'course': course,
  'course_title': course == null ? null : 'دوره $course',
  'category': null,
  'created_by': null,
  'preparation_time': 10,
  'cooking_time': 20,
  'difficulty': 'easy',
  'servings': 4,
  'featured': featured,
  'views_count': 3,
  'is_active': true,
  'created_at': '2026-01-01T00:00:00Z',
};

/// Answers `GET v1/courses/recipes/?page=N` from a page map and records which
/// pages were asked for.
class FakeRecipesAdapter implements HttpClientAdapter {
  Map<int, List<Map<String, dynamic>>> pages =
      <int, List<Map<String, dynamic>>>{};

  final List<int> requestedPages = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;

    if (path.contains('courses/recipes')) {
      final int page = Json.asInt(options.queryParameters['page']) ?? 1;
      requestedPages.add(page);

      // The backend filters server-side, so the fake has to as well —
      // otherwise a search could never come back empty and the
      // «رسپی‌ای پیدا نشد» state would be untestable.
      final String query = '${options.queryParameters['search'] ?? ''}'.trim();

      final rows = (pages[page] ?? const <Map<String, dynamic>>[])
          .where((row) => query.isEmpty || '${row['title']}'.contains(query))
          .toList();

      return _json(200, {
        'links': {'next': null, 'previous': null},
        'count': rows.length,
        'total_pages': pages.length,
        'current_page': page,
        'results': rows,
      });
    }

    return _json(200, {
      'count': 0,
      'next': null,
      'previous': null,
      'results': <dynamic>[],
    });
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
