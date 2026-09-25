import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart'
    show VideoPlayer, VideoPlayerController, VideoViewType;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:mr_cake_project/core/media/resilient_video_loader.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/pages/teacher/widgets/teacher_portfolio_item.dart';
import 'package:mr_cake_project/pages/teacher/widgets/teacher_portfolio_viewer.dart';

import 'support/app_fonts.dart';

/// The teacher profile's «نمونه کارهای هنرجو های استاد» block.
///
/// The works come from `GET v1/accounts/teacher-portfolios/`, whose rows carry
/// **either** an `image` **or** a `video` url — and **no `type` field**. A video
/// work must therefore be recognised by its url and played; an image work must
/// render as a still and never touch the player.
///
/// Playback is asserted through a fake [VideoPlayerPlatform]: a test process has
/// no decoder, so without it `initialize()` throws and every work would look
/// like a playback failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform video;
  late VideoPlayerPlatform originalPlatform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
  });

  Future<void> pumpViewer(
    WidgetTester tester, {
    required List<TeacherPortfolioItem> items,
    int initialIndex = 0,
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
        builder: (BuildContext context, Widget? child) => MaterialApp(
          home: TeacherPortfolioViewer(
            teacher: teacher(),
            items: items,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );

    // Not `pumpAndSettle`: a playing controller runs a periodic position timer,
    // and settling would never finish. A handful of pumps is enough for the
    // `initialize()` awaits to resolve.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Lets the pending video futures resolve, then disposes the tree so the
  /// controller's timer is cancelled before the test ends.
  Future<void> settleAndTearDown(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    // A discarded controller is let go on a timeout, off the ladder's critical
    // path. Let that timeout elapse, or the test ends with a pending timer.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('a video work', () {
    testWidgets('builds a player for its url and starts playing', (
      tester,
    ) async {
      await pumpViewer(tester, items: <TeacherPortfolioItem>[videoWork()]);

      expect(
        video.createdUrls,
        <String>['https://example.test/work-2.mp4'],
        reason: 'the player must be handed the `video` url',
      );
      expect(
        video.playing,
        <int>{1},
        reason: 'a video work has to actually play, not sit on a still',
      );
      expect(
        find.byType(VideoPlayer),
        findsOneWidget,
        reason: 'the decoded frames are what the user sees',
      );

      await settleAndTearDown(tester);
    });

    testWidgets('is not reported as a playback failure', (tester) async {
      await pumpViewer(tester, items: <TeacherPortfolioItem>[videoWork()]);

      expect(
        find.byIcon(Icons.error_outline_rounded),
        findsNothing,
        reason: 'an empty `type` must not be read as a broken video',
      );

      await settleAndTearDown(tester);
    });
  });

  group('an image work', () {
    testWidgets('renders a still and never builds a player', (tester) async {
      await pumpViewer(tester, items: <TeacherPortfolioItem>[imageWork()]);

      expect(
        video.createdUrls,
        isEmpty,
        reason: 'an image work must not spin up a video decoder',
      );
      expect(video.playing, isEmpty);
      expect(find.byType(VideoPlayer), findsNothing);

      // The picture itself, drawn from `image`.
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Image &&
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url ==
                  'https://example.test/work-1.jpg',
        ),
        findsOneWidget,
      );

      await settleAndTearDown(tester);
    });

    testWidgets('does not request anything for a work with no url', (
      tester,
    ) async {
      // Neither url: it must fall back to the neutral panel rather than firing
      // a request for an empty url.
      await pumpViewer(
        tester,
        items: <TeacherPortfolioItem>[
          TeacherPortfolioItem.fromJson(<String, dynamic>{
            'id': 3,
            'image': null,
            'video': null,
            'description': 'خالی',
          }),
        ],
      );

      expect(video.createdUrls, isEmpty);
      expect(
        find.byIcon(Icons.image_outlined),
        findsOneWidget,
        reason: 'the neutral panel stands in for the missing picture',
      );

      await settleAndTearDown(tester);
    });
  });

  group('only the work on screen plays', () {
    testWidgets('a second video does not start until it is swiped to', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        items: <TeacherPortfolioItem>[
          videoWork(id: 2),
          videoWork(id: 3),
        ],
      );

      // A `PageView` only builds the page on screen, so the second work is not
      // even created yet — and a video only starts buffering once its page is
      // reached, so a gallery of videos does not download all of them at once.
      expect(
        video.createdUrls.length,
        1,
        reason: 'the second work is not built until it is swiped to',
      );
      expect(
        video.playing,
        <int>{1},
        reason: 'exactly one work may be making noise',
      );

      await settleAndTearDown(tester);
    });

    testWidgets('swiping pauses the one left behind and starts the next', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        items: <TeacherPortfolioItem>[
          videoWork(id: 2),
          videoWork(id: 3),
        ],
      );

      video.reset();

      await tester.drag(find.byType(PageView), const Offset(0, -600));

      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        video.playing,
        <int>{2},
        reason: 'the work that scrolled away must stop',
      );
      // ⚠️ This is where the `isActive` guard earns its keep: once the next page
      // is built the previous one is still in the tree, and without the guard it
      // would carry on playing underneath — two soundtracks at once.
      expect(
        video.pauseCalls,
        contains(1),
        reason: 'the page left behind has to be silenced, not just hidden',
      );
      expect(
        video.createdUrls,
        <String>['https://example.test/work-3.mp4'],
        reason: 'the next work is only built once it is reached',
      );

      await settleAndTearDown(tester);
    });
  });

  group('a weak device', () {
    // Plain `test`s, not `testWidgets`: the ladder's retries are separated by a
    // real delay, and inside `testWidgets` the body runs under `FakeAsync` where
    // a `Future.delayed` only advances if the test pumps the clock. Here it just
    // runs.
    test('walks past a display mode the device refuses', () async {
      // Exactly the low-end Android failure: the device cannot allocate a GPU
      // texture the size of the video, so `textureView` refuses to create a
      // player. Before the ladder existed this was the end of the story.
      video.failForViewTypes = <VideoViewType>{VideoViewType.textureView};

      final VideoPlayerController controller =
          await ResilientVideoLoader.initialize('https://example.test/a.mp4');

      expect(
        video.createdViewTypes,
        <VideoViewType>[
          VideoViewType.textureView,
          VideoViewType.platformView,
        ],
        reason: 'it must walk the ladder rather than give up on the first rung',
      );
      expect(
        controller.value.isInitialized,
        isTrue,
        reason: 'the returned controller has to be ready to play',
      );
      expect(
        video.mixWithOthersCalls,
        <bool>[true],
        reason:
            'the fallback rung relaxes audio focus, so a ROM that refuses '
            'focus cannot leave the recovered player sitting paused',
      );

      await controller.dispose();
    });

    test('the first rung keeps the app\'s existing audio behaviour', () async {
      // The ladder must not change how a healthy device behaves: rung 1 passes
      // no options at all, so `setMixWithOthers` is never called for it.
      await ResilientVideoLoader.initialize('https://example.test/a.mp4');

      expect(video.createdViewTypes, <VideoViewType>[VideoViewType.textureView]);
      expect(
        video.mixWithOthersCalls,
        isEmpty,
        reason: 'passing options on rung 1 would silently change audio focus',
      );
    });

    test('throws only when every display mode fails', () async {
      video.failForViewTypes = <VideoViewType>{
        VideoViewType.textureView,
        VideoViewType.platformView,
      };

      final List<Object> failures = <Object>[];

      await expectLater(
        ResilientVideoLoader.initialize(
          'https://example.test/a.mp4',
          onFailure: (Object error, StackTrace _) => failures.add(error),
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(
        video.createdViewTypes.length,
        ResilientVideoLoader.rungCount,
        reason: 'every rung was tried before giving up',
      );
      expect(
        failures.length,
        ResilientVideoLoader.rungCount,
        reason: 'the real reason is reported for every attempt, not swallowed',
      );
    });

    test('the ladder has two rungs', () {
      // Guards the shape of the ladder itself: losing the fallback would
      // silently make weak devices unplayable again, and gaining a rung that
      // differs only by `mixWithOthers` would add dead time to every failure.
      expect(ResilientVideoLoader.rungCount, 2);
    });

    testWidgets('a video plays even when the texture view is refused', (
      tester,
    ) async {
      video.failForViewTypes = <VideoViewType>{VideoViewType.textureView};

      await pumpViewer(tester, items: <TeacherPortfolioItem>[videoWork()]);

      // The ladder waits between rungs, so the clock has to move for it to
      // finish climbing.
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(
        video.playing,
        <int>{1},
        reason: 'the video has to end up playing, not merely be retried',
      );
      expect(
        find.byIcon(Icons.error_outline_rounded),
        findsNothing,
        reason: 'a recovered failure must not surface as an error',
      );

      await settleAndTearDown(tester);
    });

    testWidgets('the error state appears only when every mode fails', (
      tester,
    ) async {
      video.failForViewTypes = <VideoViewType>{
        VideoViewType.textureView,
        VideoViewType.platformView,
      };

      await pumpViewer(tester, items: <TeacherPortfolioItem>[videoWork()]);

      // Let the ladder climb and then let the discarded controllers' dispose
      // timeouts elapse, or the test ends with a pending timer.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(video.playing, isEmpty);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      await settleAndTearDown(tester);
    });
  });

  group('the grid card', () {
    Future<void> pumpCard(
      WidgetTester tester,
      TeacherPortfolioItem item,
    ) async {
      await loadAppFonts();

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (BuildContext context, Widget? child) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 150,
                child: TeacherPortfolioItemCard(item: item),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a video work is badged and asks for no picture', (
      tester,
    ) async {
      await pumpCard(tester, videoWork());

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'the url is empty, so no request should be made at all',
      );
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('an image work paints its picture and gets no badge', (
      tester,
    ) async {
      await pumpCard(tester, imageWork());

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });
}

/// A `TeacherProfilePublic` row, enough for the viewer's caption.
Teacher teacher() => Teacher.fromJson(<String, dynamic>{
  'id': 1,
  'user': <String, dynamic>{
    'id': 2,
    'first_name': 'جواد',
    'last_name': 'یادگاری',
    'avatar': null,
  },
  'is_blue_verified': true,
  'courses_count': 1,
  'students_count': 10,
});

/// An **image** work, as `accounts/teacher-portfolios/` sends it.
TeacherPortfolioItem imageWork({int id = 1}) =>
    TeacherPortfolioItem.fromJson(<String, dynamic>{
      'id': id,
      'student': 4,
      'student_name': 'یزدان منوچهری',
      'title': 'نمونه کار تست',
      'description': 'نمونه کار تست',
      'image': 'https://example.test/work-$id.jpg',
      'video': null,
      'is_active': true,
    });

/// A **video** work — `image` is null, `video` carries the url, and there is no
/// `type` field to say so.
TeacherPortfolioItem videoWork({int id = 2}) =>
    TeacherPortfolioItem.fromJson(<String, dynamic>{
      'id': id,
      'student': 8,
      'student_name': 'مهدی رضایی',
      'title': 'نتالبی',
      'description': 'نتالبی',
      'image': null,
      'video': 'https://example.test/work-$id.mp4',
      'is_active': true,
    });

/// Stands in for the platform channel so the viewer can be driven without a
/// decoder. Records what it was asked to do.
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
