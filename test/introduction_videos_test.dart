import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/models/course_intro_video.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/course_learning/introduction_video_player_screen.dart';
import 'package:mr_cake_project/pages/course_learning/introduction_videos_screen.dart';
import 'package:mr_cake_project/pages/home/home_screen.dart';
import 'package:mr_cake_project/pages/home/widgets/course_intro_video_card.dart';
import 'package:mr_cake_project/pages/home/widgets/course_intro_videos.dart';

import 'support/app_fonts.dart';

/// The two halves of the course-teaser feature:
///
///  1. the **home section** must show each course's teaser, in the very same
///     carousel and card the standalone screen uses — the existing home UI/UX
///     is untouched, the carousel is simply wired up;
///  2. the standalone «ویدیو های معرفی دوره» screen must look like the rest of
///     the app (house header, `AppColors`, shared empty state) instead of the
///     Material `AppBar` / `Card` / `ElevatedButton` layout it had, and must
///     **not** carry a «معرفی دوره ها» section pill — the screen's own title
///     already says it.
///
/// Tapping a card on that screen opens [IntroductionVideoPlayerScreen]: a `16:9`
/// player at the top of the page, the video's details underneath, and the rest of
/// the trailers listed below it. Built from the app's own palette and typography,
/// never `ReelsViewer` — that player is a full-bleed swipe feed for «اکسپلور».
///
/// Both read the same source: `GET v1/courses/` plus each course's
/// `GET v1/courses/{id}/` trailer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeIntroAdapter api;
  late HttpClientAdapter originalAdapter;
  late FakeVideoPlatform video;
  late VideoPlayerPlatform originalPlatform;

  setUp(() {
    RemoteCache.clear();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeIntroAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;

    // A test process has no decoder, so `initialize()` throws and a trailer
    // would look like a playback failure. Same stand-in the portfolio tests use.
    originalPlatform = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    VideoPlayerPlatform.instance = originalPlatform;
  });

  Future<void> pumpHome(
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
            const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(
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
            const MaterialApp(home: IntroductionVideosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the first teaser card and waits for the player page to arrive.
  ///
  /// **Two pumps, not one.** The first runs the tap handler that pushes the
  /// route; the second lets the page-transition frame build the player. With a
  /// single `pump()` the route is on the stack but its widget is not built yet,
  /// and every `find.byType(IntroductionVideoPlayerScreen)` fails with
  /// `Bad state: No element` — which reads like "the tap did nothing" and sends
  /// you hunting for a gesture problem that is not there.
  ///
  /// Not `pumpAndSettle`: the page builds a real `VideoPlayerController`, and
  /// the fake platform's repeating progress timer means the tree never settles.
  Future<void> openPlayer(WidgetTester tester) async {
    await tester.tap(find.byType(CourseIntroVideoCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  // ==========================================================================
  // HOME — «معرفی دوره ها»
  // ==========================================================================

  group('home «معرفی دوره ها» section', () {
    testWidgets('renders a teaser card per course that has a trailer', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 1),
        courseJson(id: 2),
        // No trailer -> not a teaser -> no card.
        courseJson(id: 3, trailer: ''),
      ];

      await pumpHome(tester);

      expect(find.byType(CourseIntroVideos), findsOneWidget);
      expect(find.byType(CourseIntroVideoCard), findsNWidgets(2));

      // Assert on the *cards*, not on bare text: the home screen also renders
      // the same courses in the «دوره های محبوب» carousel, so a `find.text`
      // would match more than one widget.
      expect(
        tester
            .widgetList<CourseIntroVideoCard>(
              find.byType(CourseIntroVideoCard),
            )
            .map((card) => card.video.courseId)
            .toSet(),
        <int>{1, 2},
        reason: 'a course without a `video_trailer` has no teaser to show',
      );
    });

    testWidgets('the section header and «مشاهده همه» are unchanged', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1)];

      await pumpHome(tester);

      // The pill the section has always had, plus its button. The header is
      // part of the existing home UI/UX and must survive untouched.
      expect(find.text('معرفی دوره ها'), findsOneWidget);
      expect(find.text('مشاهده همه'), findsOneWidget);
    });

    testWidgets('tapping a teaser opens the course behind it', (tester) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1)];

      await pumpHome(tester);

      final Finder card = find.byType(CourseIntroVideoCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(CourseDetailsScreen), findsOneWidget);
    });

    testWidgets('an empty teaser list drops the carousel, not the header', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 1, trailer: ''),
        courseJson(id: 2, trailer: ''),
      ];

      await pumpHome(tester);

      expect(
        find.byType(CourseIntroVideoCard),
        findsNothing,
        reason: 'no trailer anywhere means no cards at all',
      );
      // The carousel widget is deliberately not built when there is nothing to
      // show, so the section header never sits above an empty strip. The header
      // itself — the part of the existing home UI/UX — stays.
      expect(find.byType(CourseIntroVideos), findsNothing);
      expect(find.text('معرفی دوره ها'), findsOneWidget);
      expect(find.text('مشاهده همه'), findsOneWidget);
    });
  });

  // ==========================================================================
  // THE STANDALONE SCREEN
  // ==========================================================================

  group('«ویدیو های معرفی دوره» screen', () {
    testWidgets('is built in the house style, not with Material defaults', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1), courseJson(id: 2)];

      await pumpScreen(tester);

      // No `AppBar`, no `ElevatedButton` — the two things that made this the one
      // screen in the app that did not look like the app.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);

      // The house header is there instead.
      expect(find.text('ویدیو های معرفی دوره'), findsOneWidget);
    });

    testWidgets('carries no «معرفی دوره ها» box above the grid', (tester) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1), courseJson(id: 2)];

      await pumpScreen(tester);

      // The screen's own title already frames the grid, and every card on it is
      // a video — the pill heading was removed on request. `findsNothing`
      // deliberately, not "not in the header": it must not exist at all.
      expect(find.text('معرفی دوره ها'), findsNothing);
    });

    testWidgets('one card per teaser, the same card the home carousel uses', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 1),
        courseJson(id: 2),
        courseJson(id: 3),
      ];

      await pumpScreen(tester);

      expect(find.byType(CourseIntroVideoCard), findsNWidgets(3));
    });

    testWidgets('tapping a card opens the YouTube-style player page', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1), courseJson(id: 2)];

      await pumpScreen(tester);

      final Finder card = find.byType(CourseIntroVideoCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // The page is pushed synchronously; its first frame builds a real
      // `VideoPlayerController`, which has no platform in a test process, so
      // only one frame is pumped and the route is inspected rather than
      // settled.
      final IntroductionVideoPlayerScreen player =
          tester.widget<IntroductionVideoPlayerScreen>(
        find.byType(IntroductionVideoPlayerScreen),
      );

      expect(
        player.video.videoUrl,
        contains('trailer-1.mp4'),
        reason: 'the tapped teaser is handed to the player as a real url',
      );

      expect(
        player.playlist.length,
        2,
        reason: 'the whole grid travels with the tap so it can be listed below',
      );

      // A `16:9` stage pinned to the top — not the full-bleed reels feed.
      expect(find.byType(AspectRatio), findsWidgets);

      final Rect stage = tester.getRect(
        find
            .descendant(
              of: find.byType(IntroductionVideoPlayerScreen),
              matching: find.byType(ClipRRect),
            )
            .first,
      );

      expect(
        stage.width / stage.height,
        closeTo(16 / 9, 0.05),
        reason: 'the player stage is 16:9, like a video site',
      );
    });

    testWidgets('«مشاهده دوره» opens the course details screen', (tester) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1)];

      await pumpScreen(tester);

      final Finder button = find.text('مشاهده دوره');
      expect(button, findsOneWidget);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(CourseDetailsScreen), findsOneWidget);
    });

    testWidgets('an empty list explains itself instead of showing a bare gap', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = const <Map<String, dynamic>>[];

      await pumpScreen(tester);

      expect(find.text('هنوز ویدیوی معرفی دوره‌ای ثبت نشده.'), findsOneWidget);
      expect(find.byType(CourseIntroVideoCard), findsNothing);
    });
  });

  // ==========================================================================
  // THE PLAYER PAGE
  // ==========================================================================

  group('introduction video player page', () {
    /// The grid route stays mounted beneath the pushed player, so
    /// `find.text('مشاهده دوره')` would also match the card's own button.
    final Finder playerCourseButton = find.descendant(
      of: find.byType(IntroductionVideoPlayerScreen),
      matching: find.text('مشاهده دوره'),
    );

    testWidgets('lists the other trailers below the player', (tester) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[
        courseJson(id: 1),
        courseJson(id: 2),
        courseJson(id: 3),
      ];

      await pumpScreen(tester);

      await openPlayer(tester);

      // The heading, and a row per trailer.
      expect(find.text('ویدیو های دیگر'), findsOneWidget);
      expect(find.text('دوره شماره 2'), findsWidgets);
      expect(find.text('دوره شماره 3'), findsWidgets);
    });

    testWidgets('shows the video details in the app palette', (tester) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1)];

      await pumpScreen(tester);

      await openPlayer(tester);

      // Title, teacher, and the two facts the card carries.
      expect(find.text('دوره شماره 1'), findsWidgets);
      expect(find.text('استاد احمدی'), findsWidgets);
      expect(find.textContaining('هنرجو'), findsWidgets);

      // «مشاهده دوره» lives in the top bar rather than only on the card. The
      // grid route stays mounted underneath the pushed player, so its own
      // «مشاهده دوره» would match too — scope the finder to the player page.
      expect(playerCourseButton, findsOneWidget);
    });

    testWidgets('«مشاهده دوره» on the player opens the course details', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      api.courses = <Map<String, dynamic>>[courseJson(id: 1)];

      await pumpScreen(tester);

      await openPlayer(tester);

      await tester.tap(playerCourseButton);
      await tester.pumpAndSettle();

      expect(find.byType(CourseDetailsScreen), findsOneWidget);
    });

    testWidgets('a trailer with no url says so instead of spinning forever', (
      tester,
    ) async {
      ignoreNetworkImageErrors();

      // A card that reached the player with an empty trailer. The grid only
      // builds a card for a course whose *detail* payload has a trailer, and the
      // playlist it hands the player is its own list — so a url-less video can
      // only arrive from a race: the course is fetched for the grid, and by the
      // time the player renders, the trailer is gone.
      //
      // That race cannot be reproduced by tapping around inside the player — the
      // queue tiles all carry the urls the grid already resolved. It is driven
      // here by handing the player the url-less entry directly, which is exactly
      // the state the guard exists for.
      final CourseIntroVideo blank = CourseIntroVideo(
        courseId: 1,
        title: 'دوره شماره 1',
        thumbnail: '',
        teacherFirstName: 'جواد',
        teacherLastName: 'یادگاری',
        teacherAvatar: '',
        duration: '10:00',
        courseDuration: '5',
        studentsCount: '۱۲',
      );

      await loadAppFonts();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (BuildContext context, Widget? child) => MaterialApp(
            home: IntroductionVideoPlayerScreen(video: blank),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('پخش ویدیو امکان‌پذیر نیست'), findsOneWidget);
      expect(find.text('تلاش مجدد'), findsOneWidget);
    });
  });

  // ==========================================================================
  // RESPONSIVENESS
  // ==========================================================================

  group('layout at every supported size', () {
    const Map<String, Size> devices = <String, Size>{
      'Galaxy 360×640': Size(360, 640),
      'iPad mini 768×1024': Size(768, 1024),
      'phone landscape 844×390': Size(844, 390),
      'tablet landscape 1024×768': Size(1024, 768),
    };

    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('the home carousel fits on ${device.key}', (tester) async {
        ignoreNetworkImageErrors();

        api.courses = <Map<String, dynamic>>[
          for (var i = 1; i <= 4; i++) courseJson(id: i),
        ];

        await pumpHome(tester, size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the home teaser carousel must scale with ${device.key}',
        );
      });

      testWidgets('the teaser grid fits on ${device.key}', (tester) async {
        ignoreNetworkImageErrors();

        api.courses = <Map<String, dynamic>>[
          for (var i = 1; i <= 6; i++) courseJson(id: i),
        ];

        await pumpScreen(tester, size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the teaser grid must scale with ${device.key}',
        );

        // Every card must stay inside the viewport: a cell wider than half the
        // screen would run off the edge silently.
        final Finder cards = find.byType(CourseIntroVideoCard);

        for (var index = 0; index < cards.evaluate().length; index++) {
          final Rect rect = tester.getRect(cards.at(index));

          expect(
            rect.left,
            greaterThanOrEqualTo(-0.01),
            reason: 'a teaser card starts off-screen on ${device.key}',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(device.value.width + 0.01),
            reason: 'a teaser card runs off the right edge on ${device.key}',
          );
        }
      });

      testWidgets('the player page fits on ${device.key}', (tester) async {
        ignoreNetworkImageErrors();

        api.courses = <Map<String, dynamic>>[
          for (var i = 1; i <= 4; i++) courseJson(id: i),
        ];

        await pumpScreen(tester, size: device.value);

        await openPlayer(tester);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the player page must scale with ${device.key}',
        );
      });
    }
  });
}

/// A `CourseList` row that carries the trailer fields the repository reads from
/// `GET v1/courses/{id}/`.
Map<String, dynamic> courseJson({required int id, String? trailer}) {
  final String url = trailer ?? '/media/trailer-$id.mp4';

  return <String, dynamic>{
    'id': id,
    'title': 'دوره شماره $id',
    'slug': 'course-$id',
    'image': '/media/cover-$id.jpg',
    'is_free': false,
    'price': 200000,
    'students_count': 100 + id,
    'lessons_count': 8,
    'total_duration_seconds': 7200,
    'teacher': <String, dynamic>{
      'id': 7,
      'first_name': 'مریم',
      'last_name': 'احمدی',
      'avatar': '/media/avatar.jpg',
    },
    // The detail endpoint's own fields, merged in so one adapter can answer
    // both `GET v1/courses/` and `GET v1/courses/{id}/`.
    'description': 'توضیح دوره $id',
    'video_trailer': url.isEmpty ? null : url,
    'intro_duration_seconds': 95,
    'chapters': const <dynamic>[],
  };
}

/// Answers the two endpoints the teaser pipeline reads, and records what was
/// asked.
///
/// The home screen also fires its own reads (categories, banners, hero). They
/// all get a **properly shaped empty DRF page** rather than `{}`: an empty map
/// is read by [PagedResult.from] as a single object and wrapped into a
/// one-item list, which would put a blank category tile on the home grid and
/// turn this test's failures into noise about a widget it does not cover.
class FakeIntroAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> courses = const <Map<String, dynamic>>[];

  /// Answers every `GET v1/courses/{id}/` with `video_trailer: null`, so a card
  /// reaches the grid with nothing to play. Only reachable through the real
  /// pipeline in a race, which is exactly why the player has to survive it.
  bool blankTrailers = false;

  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;
    paths.add(path);

    // `v1/courses/` — the page. `v1/courses/{id}/` — the trailer for one row.
    final RegExpMatch? detail = RegExp(r'courses/(\d+)/?$').firstMatch(path);

    if (detail != null) {
      final int id = int.parse(detail.group(1)!);
      final Map<String, dynamic>? row = courses
          .where((item) => item['id'] == id)
          .cast<Map<String, dynamic>?>()
          .firstOrNull;

      // A 404 rather than `{}`: an empty body would be read as one blank
      // course and quietly produce a teaser card for nothing.
      if (row == null) return _json(404, const <String, dynamic>{});

      if (blankTrailers) {
        return _json(200, <String, dynamic>{...row, 'video_trailer': null});
      }

      return _json(200, row);
    }

    if (path.contains('courses')) {
      return _page(courses);
    }

    // Categories, banners, hero: an empty page, never a bare `{}`.
    return _page(const <Map<String, dynamic>>[]);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _page(List<Map<String, dynamic>> rows) => _json(200, {
    'count': rows.length,
    'next': null,
    'previous': null,
    'results': rows,
  });

  ResponseBody _json(int status, Object payload) => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}


/// A stand-in for the platform video plugin.
///
/// Copied in shape from `teacher_portfolio_test.dart`: a test process has no
/// decoder, so `initialize()` throws `UnimplementedError` and every trailer
/// would be reported as a playback failure. `videoEventsFor` emits
/// `initialized` **on listen**, which is what `initialize()` waits for.
class FakeVideoPlatform extends VideoPlayerPlatform {
  /// The url of every player the viewer asked for, in creation order.
  final List<String> createdUrls = <String>[];

  /// The display mode of every player the viewer asked for, in creation order.
  final List<VideoViewType> createdViewTypes = <VideoViewType>[];

  /// Display modes that refuse to create a player, so the retry ladder can be
  /// exercised. A weak device fails on `textureView` — it cannot allocate a GPU
  /// texture the size of the video — and only succeeds on `platformView`.
  Set<VideoViewType> failForViewTypes = <VideoViewType>{};

  /// Every `setMixWithOthers` the plugin asked for, in order. Only a rung that
  /// passed `VideoPlayerOptions` produces one.
  final List<bool> mixWithOthersCalls = <bool>[];

  /// The players currently playing. Must never hold more than the visible work.
  final Set<int> playing = <int>{};

  final List<int> playCalls = <int>[];
  final List<int> pauseCalls = <int>[];
  final List<int> disposedPlayers = <int>[];

  int _nextPlayerId = 1;

  void reset() {
    createdUrls.clear();
    createdViewTypes.clear();
    mixWithOthersCalls.clear();
    playCalls.clear();
    pauseCalls.clear();
  }

  @override
  Future<void> init() async {}

  /// Called by `initialize()` **before** `createWithOptions`, and only when the
  /// rung passed a `VideoPlayerOptions`. The base class throws
  /// `UnimplementedError`, and both real implementations override it, so leaving
  /// it out here would make a rung fail for a reason no device has.
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    mixWithOthersCalls.add(mixWithOthers);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    createdViewTypes.add(options.viewType);

    if (failForViewTypes.contains(options.viewType)) {
      throw PlatformException(
        code: 'VideoError',
        message: 'Decoder init failed for ${options.viewType.name}',
      );
    }

    final int playerId = _nextPlayerId++;
    createdUrls.add(options.dataSource.uri ?? '');
    return playerId;
  }

  /// Emitted **on listen**, which is what `initialize()` waits for. A broadcast
  /// controller would drop the event when it arrives before the subscription.
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return Stream<VideoEvent>.fromIterable(<VideoEvent>[
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1920, 1080),
      ),
    ]);
  }

  /// On a device this is a texture-backed platform view; here a plain box stands
  /// in so `VideoPlayer` can mount at all.
  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Color(0xFF000000));
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool prevents,
  ) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls.add(playerId);
    playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls.add(playerId);
    playing.remove(playerId);
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> dispose(int playerId) async {
    disposedPlayers.add(playerId);
    playing.remove(playerId);
  }
}
