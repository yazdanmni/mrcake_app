import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/pages/home/home_screen.dart';
import 'package:mr_cake_project/pages/recipes/recipes_screen.dart';
import 'package:mr_cake_project/pages/students/students_screen.dart';

/// The home shortcuts must actually navigate.
///
/// «هنرجوها» and «رسپی‌ها» were `// TODO` stubs — tapping them did nothing at
/// all. This pumps the **real** `HomeScreen` (not a stand-in) so the wiring
/// itself is covered: a stub creeping back in fails here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHomeAdapter api;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    RemoteCache.clear();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeHomeAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  /// The test font draws every glyph as a square, so real widgets overflow here
  /// and nowhere else — see `coupon_flow_test.dart`. Network images cannot load
  /// in a test either, so their load errors are ignored as well.
  void ignoreTestEnvironmentNoise() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final String text = '${details.exception}';
      if (text.contains('overflowed by')) return;
      if (details.exception is NetworkImageLoadException) return;
      if (text.contains('HTTP request failed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (BuildContext context, Widget? child) =>
            const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The shortcuts sit below the hero, the categories and the promo banner, so
  /// they have to be scrolled into view before they can be tapped.
  Future<void> tapShortcut(WidgetTester tester, String label) async {
    final finder = find.text(label);
    expect(
      finder,
      findsWidgets,
      reason: 'the «$label» shortcut should be on the home screen',
    );

    final target = finder.last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();

    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('home shortcuts', () {
    testWidgets('«هنرجوها» opens the students screen', (tester) async {
      ignoreTestEnvironmentNoise();
      api.students = <Map<String, dynamic>>[
        studentJson(id: 1, firstName: 'زهرا', lastName: 'کریمی'),
      ];

      await pumpHome(tester);
      await tapShortcut(tester, 'هنرجوها');

      expect(find.byType(StudentsScreen), findsOneWidget);
    });

    testWidgets('«رسپی‌ها» opens the recipes screen', (tester) async {
      ignoreTestEnvironmentNoise();

      await pumpHome(tester);
      await tapShortcut(tester, 'رسپی‌ها');

      expect(find.byType(RecipesScreen), findsOneWidget);
    });

    testWidgets('«استاد» still opens the teachers screen', (tester) async {
      ignoreTestEnvironmentNoise();

      await pumpHome(tester);
      await tapShortcut(tester, 'استاد');

      expect(
        find.text('استادان'),
        findsOneWidget,
        reason: 'the teachers screen has its own title',
      );
    });
  });
}

/// A `UserPublic` row as the backend sends it.
Map<String, dynamic> studentJson({
  required int id,
  required String firstName,
  required String lastName,
  String? bio,
}) => <String, dynamic>{
  'id': id,
  'first_name': firstName,
  'last_name': lastName,
  'full_name': '$firstName $lastName',
  'avatar': null,
  'bio': bio,
  'role': 'user',
};

/// Answers the home screen's four requests with empty pages (so the bundled
/// seed data is used) and the two roster endpoints with real payloads.
class FakeHomeAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> students = const <Map<String, dynamic>>[];

  /// The query `accounts/users/` was asked with.
  Map<String, dynamic>? studentsQuery;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;

    if (path.contains('accounts/users')) {
      studentsQuery = Map<String, dynamic>.of(options.queryParameters);
      return _page(students);
    }

    if (path.contains('courses/recipes')) {
      return _page(const <Map<String, dynamic>>[]);
    }

    if (path.contains('courses/')) {
      return _page(const <Map<String, dynamic>>[]);
    }

    // banners, hero, categories: empty, so the screen keeps its seed content.
    return _json(200, <String, dynamic>{'results': <dynamic>[]});
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
