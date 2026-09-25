import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/pages/courses/courses_screen.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_header.dart';
import 'package:mr_cake_project/pages/students/students_screen.dart';

/// A screen that is **both** a bottom-navigation tab and a push target must
/// only offer a way back when it was actually pushed.
///
/// `CoursesScreen` is the one such screen: it is tab #2 of
/// `MainBottomNavigation` *and* the destination of «مشاهده همه», the «دوره‌ها»
/// shortcut and every category. As a tab there is nothing behind it, so a back
/// arrow would be a dead end; pushed on top of the home screen it must have
/// one.
///
/// `Navigator.canPop` is exactly that distinction — `MainBottomNavigation` is
/// installed with `pushAndRemoveUntil(_, (_) => false)`, so it is the only
/// route and `canPop` is false, while anything pushed above it makes `canPop`
/// true. These tests pin both halves down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void ignoreTestEnvironmentNoise() {
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final String text = '${details.exception}';
      if (text.contains('overflowed by')) return;
      if (details.exception is NetworkImageLoadException) return;
      if (text.contains('HTTP request failed')) return;
      if (text.contains('No host specified')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Widget wrap(Widget home) => ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (BuildContext context, Widget? child) => MaterialApp(home: home),
  );

  /// The back affordance of the courses header, if it is there.
  Finder backArrow() => find.descendant(
    of: find.byType(CoursesHeader),
    matching: find.byIcon(Icons.arrow_back_ios_rounded),
  );

  group('CoursesScreen back button', () {
    testWidgets('is absent when the screen is the navigation tab', (
      tester,
    ) async {
      ignoreTestEnvironmentNoise();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // The tab case: the courses screen *is* the root route, exactly as
      // `MainBottomNavigation` installs it.
      await tester.pumpWidget(wrap(const CoursesScreen()));
      await tester.pumpAndSettle();

      expect(
        backArrow(),
        findsNothing,
        reason: 'a tab has nothing behind it to go back to',
      );
    });

    testWidgets('appears when the screen was pushed', (tester) async {
      ignoreTestEnvironmentNoise();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CoursesScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        backArrow(),
        findsOneWidget,
        reason: 'opened from a button, the screen needs a way back',
      );

      // …and it really goes back.
      await tester.tap(backArrow());
      await tester.pumpAndSettle();

      expect(find.byType(CoursesHeader), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('the title stays pinned to the right in both cases', (
      tester,
    ) async {
      ignoreTestEnvironmentNoise();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const CoursesScreen()));
      await tester.pumpAndSettle();

      final Rect tabTitle = tester.getRect(find.text('دوره ها'));

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CoursesScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final Rect pushedTitle = tester.getRect(find.text('دوره ها'));

      expect(
        pushedTitle.right,
        closeTo(tabTitle.right, 0.5),
        reason: 'the back arrow is added beside the title, not over it',
      );
    });
  });

  group('screens that are only ever pushed', () {
    testWidgets('the students screen always has a back button', (tester) async {
      ignoreTestEnvironmentNoise();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const StudentsScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_rounded), findsOneWidget);
    });
  });
}

/// Answers `GET v1/courses/` and `GET v1/courses/categories/` with empty pages,
/// so the screens fall back to their bundled seed content.
class FakeCoursesAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'count': 0,
        'next': null,
        'previous': null,
        'results': <dynamic>[],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
