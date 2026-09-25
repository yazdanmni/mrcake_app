import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/pages/explore/widgets/reels_viewer.dart';
import 'package:mr_cake_project/pages/students/students_screen.dart';
import 'package:mr_cake_project/pages/teacher/widgets/teacher_portfolio_item.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

import 'support/app_fonts.dart';

/// «هنرجوها» shows **only نمونه کارها** — the works a teacher published for
/// their students, from `GET v1/accounts/teacher-portfolios/`.
///
/// The account roster is deliberately absent, so these tests pin that down as
/// well as the gallery's own behaviour: it asks the endpoint **without** a
/// `teacher` filter (the gallery spans every teacher, not one), renders one card
/// per work, paginates, opens the viewer on tap, and still works for a
/// signed-out visitor.
///
/// The fixtures below are the **real** payload — `image` **or** `video` as a
/// direct url, plus `student_name` and `title`. There is no `type` field on this
/// shape, which is exactly what used to make a video work render as a broken
/// picture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGalleryAdapter api;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    RemoteCache.clear();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeGalleryAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  Future<void> pumpStudents(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
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
            const MaterialApp(home: StudentsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('نمونه کارها gallery', () {
    testWidgets('asks the portfolio endpoint with no teacher filter, so the '
        'gallery is across every teacher', (tester) async {
      ignoreNetworkImageErrors();

      await pumpStudents(tester);

      expect(
        api.portfolioPath,
        contains('accounts/teacher-portfolios'),
        reason: 'the gallery is the same endpoint the teacher profile reads',
      );
      expect(
        api.portfolioQuery?.containsKey('teacher'),
        isFalse,
        reason: 'a `teacher` filter would hide every other teacher\'s works',
      );
    });

    testWidgets('renders one card per work the backend returns', (tester) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[
        workJson(id: 1),
        workJson(id: 2),
        workJson(id: 3),
      ];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsNWidgets(3));
      expect(find.text('نمونه کارهای هنرجوها'), findsOneWidget);
    });

    testWidgets('the account roster is not part of this screen', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[workJson(id: 1)];
      api.students = <Map<String, dynamic>>[studentJson(id: 1, name: 'زهرا')];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsOneWidget);
      expect(
        find.text('زهرا'),
        findsNothing,
        reason: 'the page is the gallery, not a people list',
      );
      expect(
        api.studentsRequests,
        0,
        reason: 'nothing on this screen should read the accounts endpoint',
      );
    });

    testWidgets('an empty gallery explains itself instead of showing a bare '
        'gap', (tester) async {
      ignoreNetworkImageErrors();

      api.portfolio = const <Map<String, dynamic>>[];

      await pumpStudents(tester);

      expect(find.text('هنوز نمونه‌کاری ثبت نشده.'), findsOneWidget);
      expect(find.byType(TeacherPortfolioItemCard), findsNothing);
    });

    testWidgets('a signed-out visitor still gets the gallery', (tester) async {
      ignoreNetworkImageErrors();

      // No token in a test process -> `SessionManager.isGuest` is true. The
      // gallery is public (`security: [{jwtAuth: []}, {}]`), so it must not
      // depend on any account-scoped read.
      api.portfolio = <Map<String, dynamic>>[workJson(id: 1), workJson(id: 2)];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsNWidgets(2));
    });

    testWidgets('scrolling to the end asks for the next page', (tester) async {
      ignoreNetworkImageErrors();

      // Eighteen works is six three-column rows — taller than the viewport, so
      // the list is genuinely scrollable. With `maxScrollExtent == 0` the
      // scroll listener never fires at all and the gallery would look
      // unpaginated for a reason that has nothing to do with pagination.
      api.portfolioByPage = <int, List<Map<String, dynamic>>>{
        1: <Map<String, dynamic>>[for (var i = 1; i <= 18; i++) workJson(id: i)],
        2: <Map<String, dynamic>>[workJson(id: 19), workJson(id: 20)],
      };

      await pumpStudents(tester);

      expect(api.portfolioPagesRequested, <int>[1]);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();

      expect(
        api.portfolioPagesRequested,
        <int>[1, 2],
        reason: 'hitting the bottom must advance the gallery',
      );
      expect(find.byType(TeacherPortfolioItemCard), findsNWidgets(20));
    });

    // A plain `test`, not `testWidgets`: this call is real I/O, and a
    // `testWidgets` body runs under `FakeAsync`, so awaiting it there never
    // completes (it hangs until the runner's 2-minute timeout).
    test('`fetchStudents` still binds the `user` role', () async {
      // The roster is gone from the UI, but the repository binding is kept: a
      // student is an account whose `role` is `user`, and this is the only
      // place that contract is written down.
      await CatalogRepository.instance.fetchStudents();

      expect(api.studentsQuery?['role'], 'user');
    });
  });

  // The regression that made a video work render as a broken picture: this
  // payload has no `type`, so `isVideo` has to come from the `video` url.
  group('TeacherPortfolioItem parses both payload shapes', () {
    test('a video row is a video even though it carries no `type`', () {
      final item = TeacherPortfolioItem.fromJson(videoWorkJson(id: 2));

      expect(
        item.isVideo,
        isTrue,
        reason: 'the accounts shape signals video by filling in `video`',
      );
      expect(item.videoUrl, 'https://example.test/work-2.mp4');
      expect(item.image, isEmpty);
      expect(item.studentName, 'مهدی رضایی');
      expect(item.studentId, 8);
      expect(item.title, 'نمونه کار ویدیویی 2');
    });

    test('an image row is not a video', () {
      final item = TeacherPortfolioItem.fromJson(workJson(id: 1));

      expect(item.isVideo, isFalse);
      expect(item.videoUrl, isNull);
      expect(item.image, 'https://example.test/work-1.jpg');
      expect(item.studentName, 'یزدان منوچهری');
    });

    test('a row with neither url is not a video', () {
      // Nothing to play and nothing to show: it must not be treated as a video
      // and sent to a player with an empty url.
      final item = TeacherPortfolioItem.fromJson(<String, dynamic>{
        'id': 3,
        'image': null,
        'video': null,
        'description': 'خالی',
      });

      expect(item.isVideo, isFalse);
      expect(item.image, isEmpty);
      expect(item.videoUrl, isNull);
    });

    test('the older content shape still parses, `type` included', () {
      final video = TeacherPortfolioItem.fromJson(
        legacyWorkJson(id: 5, type: 'video'),
      );
      final image = TeacherPortfolioItem.fromJson(
        legacyWorkJson(id: 6, type: 'image'),
      );

      expect(video.isVideo, isTrue);
      expect(image.isVideo, isFalse);
    });
  });

  group('both media types, like the teacher profile', () {
    testWidgets('an image work is a picture and gets no play badge', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[workJson(id: 1)];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsOneWidget);
      expect(
        find.byIcon(Icons.play_arrow_rounded),
        findsNothing,
        reason: '`type: image` must not be badged as a video',
      );
    });

    testWidgets('a video work is badged with the same play icon the teacher '
        'profile uses', (tester) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[videoWorkJson(id: 1)];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a mixed gallery keeps each item its own type', (tester) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[
        workJson(id: 1),
        videoWorkJson(id: 2),
        workJson(id: 3),
      ];

      await pumpStudents(tester);

      expect(find.byType(TeacherPortfolioItemCard), findsNWidgets(3));
      expect(
        find.byIcon(Icons.play_arrow_rounded),
        findsOneWidget,
        reason: 'only the one video item carries the badge',
      );
    });

    testWidgets('the player is handed a video url for a video and none for an '
        'image', (tester) async {
      ignoreNetworkImageErrors();

      // The image is first so the tapped page is the still — the video page
      // would otherwise build a real `VideoPlayerController`, and there is no
      // video platform in a test process.
      api.portfolio = <Map<String, dynamic>>[
        workJson(id: 1),
        videoWorkJson(id: 2),
      ];

      await pumpStudents(tester);

      final Finder card = find.byType(TeacherPortfolioItemCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      final ReelsViewer viewer = tester.widget<ReelsViewer>(
        find.byType(ReelsViewer),
      );

      expect(viewer.videos.length, 2);

      // The image: a thumbnail and no url → `_ReelItem` renders a still.
      expect(viewer.videos[0].videoUrl, isEmpty);
      expect(viewer.videos[0].thumbnail, isNotEmpty);

      // The video: a url → `_ReelItem` builds a player for it.
      expect(viewer.videos[1].videoUrl, isNotEmpty);
    });
  });

  group('opening a work', () {
    testWidgets('tapping a card opens the Explore-style vertical player', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[workJson(id: 1)];

      await pumpStudents(tester);

      final Finder card = find.byType(TeacherPortfolioItemCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(
        find.byType(ReelsViewer),
        findsOneWidget,
        reason: 'the gallery plays through the same viewer Explore uses',
      );
    });

    testWidgets('the whole gallery is handed to the player, at the tapped '
        'index', (tester) async {
      ignoreNetworkImageErrors();

      api.portfolio = <Map<String, dynamic>>[
        workJson(id: 1),
        workJson(id: 2),
        workJson(id: 3),
      ];

      await pumpStudents(tester);

      final Finder second = find.byType(TeacherPortfolioItemCard).at(1);
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();

      final ReelsViewer viewer = tester.widget<ReelsViewer>(
        find.byType(ReelsViewer),
      );

      expect(viewer.videos.length, 3);
      expect(
        viewer.initialIndex,
        1,
        reason: 'swiping should continue from the work that was tapped',
      );
      // An image work must reach the player with no video url, which is what
      // makes `_ReelItem` render a still instead of a playback error.
      expect(viewer.videos[1].videoUrl, isEmpty);
      expect(viewer.videos[1].thumbnail, isNotEmpty);
    });

    testWidgets('the player is captioned with the owner when the teacher is '
        'known', (tester) async {
      ignoreNetworkImageErrors();

      // The row cannot name its owner (the payload has no `teacher` field), so
      // the screen falls back to the single verified teacher.
      api.portfolio = <Map<String, dynamic>>[workJson(id: 1)];
      api.teachers = <Map<String, dynamic>>[teacherJson(id: 7, name: 'سارا')];

      await pumpStudents(tester);

      final Finder card = find.byType(TeacherPortfolioItemCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ReelsViewer),
          matching: find.text('استاد محمدی'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unresolvable owner drops the caption instead of printing an '
        'empty one', (tester) async {
      ignoreNetworkImageErrors();

      // No teacher can be resolved at all: the list is empty, so there is no
      // single verified fallback either.
      api.portfolio = <Map<String, dynamic>>[workJson(id: 1)];
      api.teachers = const <Map<String, dynamic>>[];

      await pumpStudents(tester);

      final Finder card = find.byType(TeacherPortfolioItemCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(ReelsViewer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReelsViewer),
          matching: find.textContaining('استاد'),
        ),
        findsNothing,
        reason: 'the chip prints «استاد {lastName}», which would read «استاد »',
      );
      // The description is the point of the item, so it survives.
      expect(find.text('نمونه کار شماره 1'), findsOneWidget);
    });
  });

  group('StudentsScreen gallery responsiveness', () {
    const Map<String, Size> devices = <String, Size>{
      'Galaxy 360×640': Size(360, 640),
      'iPhone SE 320×568': Size(320, 568),
      'iPhone 13 390×844 (design)': Size(390, 844),
      'Pixel 7 412×915': Size(412, 915),
      'iPad mini 768×1024': Size(768, 1024),
      'phone landscape 844×390': Size(844, 390),
      'tablet landscape 1024×768': Size(1024, 768),
    };

    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('lays the gallery out without overflow on ${device.key}', (
        tester,
      ) async {
        ignoreNetworkImageErrors();

        api.portfolio = <Map<String, dynamic>>[
          for (var i = 1; i <= 9; i++) workJson(id: i),
        ];
        api.teachers = <Map<String, dynamic>>[teacherJson(id: 7, name: 'سارا')];

        await pumpStudents(tester, size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the gallery must scale with ${device.key}',
        );

        // The three-column grid has to stay inside the screen: a cell that is
        // wider than a third of the viewport would run off the edge silently.
        final Finder cards = find.byType(TeacherPortfolioItemCard);

        for (var index = 0; index < cards.evaluate().length; index++) {
          final Rect rect = tester.getRect(cards.at(index));

          expect(
            rect.left,
            greaterThanOrEqualTo(-0.01),
            reason: 'a work card starts off-screen on ${device.key}',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(device.value.width + 0.01),
            reason: 'a work card runs off the right edge on ${device.key}',
          );
        }
      });
    }
  });
}

/// An **image** work, exactly as `accounts/teacher-portfolios/` sends it.
///
/// `video` is present but null — the backend fills in one url or the other, and
/// there is no `type` field to say which.
Map<String, dynamic> workJson({
  required int id,
  int studentId = 4,
  String studentName = 'یزدان منوچهری',
}) =>
    <String, dynamic>{
      'id': id,
      'student': studentId,
      'student_name': studentName,
      'title': 'نمونه کار شماره $id',
      'description': 'نمونه کار شماره $id',
      'image': 'https://example.test/work-$id.jpg',
      'video': null,
      'is_active': true,
      'created_at': '2026-09-24T17:52:50.402252+03:30',
      'updated_at': '2026-09-24T17:53:52.976955+03:30',
    };

/// A **video** work — `image` is null and `video` carries the url.
///
/// The card has no cover to paint, so it shows its placeholder behind the play
/// badge; the player is built from `video`.
Map<String, dynamic> videoWorkJson({
  required int id,
  int studentId = 8,
  String studentName = 'مهدی رضایی',
}) =>
    <String, dynamic>{
      'id': id,
      'student': studentId,
      'student_name': studentName,
      'title': 'نمونه کار ویدیویی $id',
      'description': 'نمونه کار ویدیویی $id',
      'image': null,
      'video': 'https://example.test/work-$id.mp4',
      'is_active': true,
      'created_at': '2026-09-24T18:21:40.394442+03:30',
      'updated_at': '2026-09-24T18:21:40.394464+03:30',
    };

/// The **older** `content/teacher-portfolio/` shape, kept so the model's dual
/// support cannot rot: a `type` enum and a `media` **id** instead of urls.
Map<String, dynamic> legacyWorkJson({
  required int id,
  String type = 'image',
}) =>
    <String, dynamic>{
      'id': id,
      'type': type,
      'description': 'نمونه کار قدیمی $id',
      'position': id,
      'is_published': true,
      'teacher': 7,
    };

/// A `TeacherProfilePublic` row as the backend sends it.
Map<String, dynamic> teacherJson({required int id, required String name}) =>
    <String, dynamic>{
      'id': id,
      'user': <String, dynamic>{
        'id': 100 + id,
        'first_name': name,
        'last_name': 'محمدی',
        'avatar': null,
      },
      'is_blue_verified': true,
      'courses_count': 1,
      'students_count': 10,
    };

/// A `UserPublic` row as the backend sends it.
Map<String, dynamic> studentJson({required int id, required String name}) =>
    <String, dynamic>{
      'id': id,
      'first_name': name,
      'last_name': null,
      'full_name': name,
      'avatar': null,
      'bio': null,
      'role': 'user',
    };

/// Answers the endpoints «هنرجوها» touches and records what was asked.
class FakeGalleryAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> students = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> teachers = const <Map<String, dynamic>>[];

  /// Single-page gallery. Ignored when [portfolioByPage] is set.
  List<Map<String, dynamic>> portfolio = const <Map<String, dynamic>>[];

  /// Multi-page gallery, keyed by page number.
  Map<int, List<Map<String, dynamic>>> portfolioByPage =
      const <int, List<Map<String, dynamic>>>{};

  String? portfolioPath;
  Map<String, dynamic>? portfolioQuery;
  Map<String, dynamic>? studentsQuery;

  final List<int> portfolioPagesRequested = <int>[];

  /// How many times the accounts endpoint was asked. Must stay 0.
  int studentsRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;
    final int page = _pageOf(options);

    if (path.contains('accounts/teacher-portfolios')) {
      portfolioPath = path;
      portfolioQuery = Map<String, dynamic>.of(options.queryParameters);
      portfolioPagesRequested.add(page);

      final List<Map<String, dynamic>> rows = portfolioByPage.isEmpty
          ? (page == 1 ? portfolio : const <Map<String, dynamic>>[])
          : (portfolioByPage[page] ?? const <Map<String, dynamic>>[]);

      return _page(rows, page: page);
    }

    // Only page 1 has rows. A screen that keeps paging has to be told to stop,
    // otherwise `_onScroll` would re-request the same rows forever.
    if (path.contains('accounts/users')) {
      studentsRequests++;
      studentsQuery = Map<String, dynamic>.of(options.queryParameters);
      return _page(
        page == 1 ? students : const <Map<String, dynamic>>[],
        page: page,
      );
    }

    if (path.contains('accounts/teachers')) {
      return _page(
        page == 1 ? teachers : const <Map<String, dynamic>>[],
        page: page,
      );
    }

    return _page(const <Map<String, dynamic>>[], page: page);
  }

  @override
  void close({bool force = false}) {}

  int _pageOf(RequestOptions options) =>
      int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;

  ResponseBody _page(
    List<Map<String, dynamic>> rows, {
    int page = 1,
  }) =>
      _json(200, <String, dynamic>{
        'count': rows.length,
        'next': null,
        'previous': page > 1 ? page - 1 : null,
        'results': rows,
      });

  ResponseBody _json(int status, Map<String, dynamic> payload) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
}
