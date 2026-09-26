import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/course_intro_video.dart';
import '../../widgets/house_video_player.dart';
import '../course_details/course_details_screen.dart';

/// One course teaser, played the way a video site plays a video.
///
/// ## What this is
///
/// Tapping a card on «ویدیو های معرفی دوره» opens **this**, not the full-bleed
/// reels player: a `16:9` player pinned to the top of the page, the video's own
/// details laid out underneath, and the rest of the teasers listed below so the
/// user can keep watching without going back.
///
/// ## Why not [ReelsViewer]
///
/// `ReelsViewer` is a swipeable, full-bleed, cover-cropped vertical feed — right
/// for «اکسپلور» and the «هنرجوها» gallery, wrong here. A course trailer is
/// *content to watch*, not *content to scroll past*: it needs its title, its
/// teacher and a way through to the course, all of which the reels chrome hides
/// behind a gradient. This screen shows them.
///
/// ## Where the design comes from
///
/// Every measurement, colour and font is the app's own — `AppColors`,
/// `ScreenUtil`, `pinarb` / `bshabnam` — and the player chrome (progress bar,
/// play button, timestamp, mute, fullscreen) is the very same control set
/// [CourseDetailsScreen] already puts over its inline trailer. The layout is the
/// only thing that resembles YouTube; the surface is unmistakably Mr. Cake.
class IntroductionVideoPlayerScreen extends StatefulWidget {
  /// The teaser to open on.
  final CourseIntroVideo video;

  /// Every teaser the grid had, in grid order, so the list under the player is
  /// the same content the user just came from — and so tapping one plays it
  /// without another round trip.
  final List<CourseIntroVideo> playlist;

  /// The video's position inside [playlist]. Ignored when the video is not in
  /// the playlist; the first entry is played instead.
  final int initialIndex;

  const IntroductionVideoPlayerScreen({
    super.key,
    required this.video,
    this.playlist = const <CourseIntroVideo>[],
    this.initialIndex = 0,
  });

  @override
  State<IntroductionVideoPlayerScreen> createState() =>
      _IntroductionVideoPlayerScreenState();
}

class _IntroductionVideoPlayerScreenState
    extends State<IntroductionVideoPlayerScreen> {
  /// The entry currently playing. Starts as the one that was tapped and changes
  /// when the user picks another from the list.
  late CourseIntroVideo _current;

  /// Position of [_current] inside the playlist, or `-1` when the grid passed no
  /// playlist (a deep link, or a single card opened on its own).
  late int _currentIndex;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _currentIndex = _resolveInitialIndex();
    _current = _currentIndex >= 0 ? widget.playlist[_currentIndex] : widget.video;
  }

  /// Where [widget.video] sits in [widget.playlist].
  ///
  /// Matched on `courseId` **and** title rather than on identity, because the
  /// two lists are built by separate `fetchCourseIntroVideos` calls and their
  /// elements are different objects. Falls back to [widget.initialIndex] and
  /// then to the first entry, so a card that somehow is not in the playlist
  /// still opens something playable rather than an empty page.
  int _resolveInitialIndex() {
    if (widget.playlist.isEmpty) return -1;

    final int found = widget.playlist.indexWhere(
      (CourseIntroVideo item) =>
          item.courseId == widget.video.courseId &&
          item.title == widget.video.title,
    );

    if (found != -1) return found;

    if (widget.initialIndex >= 0 &&
        widget.initialIndex < widget.playlist.length) {
      return widget.initialIndex;
    }

    return 0;
  }

  /// The list under the player: the playlist when there is one, otherwise the
  /// single video, so the page is never half-empty.
  List<CourseIntroVideo> get _queue => widget.playlist.isNotEmpty
      ? widget.playlist
      : <CourseIntroVideo>[widget.video];

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  /// Plays another teaser from the list, in place.
  ///
  /// Swapping the source rather than pushing a second player keeps the back
  /// stack honest: the user pressed "back" once and expects to land on the grid,
  /// not to walk back through every video they sampled.
  void _playFromQueue(CourseIntroVideo video) {
    if (video.courseId == _current.courseId && video.title == _current.title) {
      // Already playing — treat the tap as "show me the controls".
      _scrollToTop();
      return;
    }

    setState(() {
      _current = video;
      _currentIndex = _queue.indexOf(video);
    });

    _scrollToTop();
    // The surface reloads itself: it watches `videoUrl` and never hands a new
    // url to a controller mid-flight, which is what used to leave the previous
    // frame behind when tapping quickly.
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _openCourse() {
    final Course? course = _current.course;

    if (course == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailsScreen(course: course),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _buildPlayer(),
                  SizedBox(height: 18.h),
                  _buildDetails(),
                  SizedBox(height: 22.h),
                  _buildQueueHeader(),
                  SizedBox(height: 14.h),
                  ..._buildQueueTiles(),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PLAYER
  // ==========================================================================

  /// The shared house surface, fed this entry's url.
  ///
  /// Keyed on the **playlist slot**, not on the course: a slot is what the user
  /// is pointing at when they tap a row, so switching entries always rebuilds
  /// the surface rather than re-using a controller that is already holding
  /// another video. `_currentIndex` is `-1` when no playlist was passed, which
  /// is its own key.
  Widget _buildPlayer() {
    return HouseVideoPlayer(
      key: ValueKey<int>(_currentIndex),
      videoUrl: _current.videoUrl,
      posterUrl: _current.thumbnail,
      borderRadius: BorderRadius.circular(18.r),
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      autoPlay: true,
      // A trailer is a clip, not a programme — looping keeps the page alive
      // while the user reads the course details underneath.
    );
  }
  // ==========================================================================
  // TOP BAR
  // ==========================================================================

  /// A slim bar above the player: the raised back pill, and «مشاهده دوره» on the
  /// other side.
  /// The page needs no big `pinarb` heading — the video's own title is 20 px
  /// below it, and printing it twice is what makes a screen feel like a web
  /// view. It keeps the house geometry, though: the same `44.w` premium pill as
  /// every other pushed screen.
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.only(
        left: 25.w,
        right: 25.w,
        top: 14.h,
        bottom: 14.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          // The whole point of the page is the video; the way through to the
          // course sits right next to it instead of at the bottom of the list.
          Flexible(
            child: _CoursePill(
              enabled: _current.course != null,
              onTap: _openCourse,
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.premium.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.premium, width: 1.5.w),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ==========================================================================
  // DETAILS
  // ==========================================================================

  /// The block under the player: title, teacher, and the two facts the card in
  /// the grid shows. It is the same information as [CourseIntroVideoCard]'s text
  /// block, at page scale rather than card scale.
  Widget _buildDetails() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _current.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 19.sp,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                _TeacherAvatar(imageUrl: _current.teacherAvatar),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استاد ${_current.teacherLastName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${_toPersianDigits(_current.courseDuration)} ساعت'
                        '  •  '
                        '${_toPersianDigits(_current.studentsCount)} هنرجو',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                _DurationBadge(duration: _current.duration),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // QUEUE
  // ==========================================================================

  /// «ویدیو های دیگر» — the pill heading the rest of the app's lists use.
  Widget _buildQueueHeader() {
    // Nothing to head when the grid opened this page with no playlist.
    if (_queue.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          height: 33.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.premium,
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: Text(
            'ویدیو های دیگر',
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQueueTiles() {
    if (_queue.length <= 1) return const <Widget>[];

    return <Widget>[
      for (int index = 0; index < _queue.length; index++)
        Padding(
          padding: EdgeInsets.only(
            left: 25.w,
            right: 25.w,
            bottom: 12.h,
          ),
          child: _QueueTile(
            video: _queue[index],
            isPlaying: index == _currentIndex,
            onTap: () => _playFromQueue(_queue[index]),
          ),
        ),
    ];
  }
}

// ============================================================================
// PIECES
// ============================================================================

/// «مشاهده دوره» in the top bar — the house `primary` pill.
///
/// Greyed out rather than hidden when the card carried no [Course], so the bar
/// keeps its shape and the user can see the course is simply unavailable.
class _CoursePill extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _CoursePill({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(11.r),
        ),
        alignment: Alignment.center,
        child: Text(
          'مشاهده دوره',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 13.sp,
            color: AppColors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// The teacher's avatar, identical to the card's.
class _TeacherAvatar extends StatelessWidget {
  final String imageUrl;

  const _TeacherAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 40.w,
        height: 40.w,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 40.w,
          height: 40.w,
          color: AppColors.primary.withValues(alpha: 0.14),
          alignment: Alignment.center,
          child: Icon(
            Icons.person_outline_rounded,
            size: 22.sp,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// The trailer's length, in the card's own badge shape.
class _DurationBadge extends StatelessWidget {
  final String duration;

  const _DurationBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: AppColors.premium.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: AppColors.premium.withValues(alpha: 0.45),
              width: 0.8.w,
            ),
          ),
          child: Text(
            duration,
            style: TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.premium,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in «ویدیو های دیگر»: a small `16:9` still on the right, the title and
/// teacher beside it. The playing row is tinted rather than removed, so the list
/// never reorders under the user's finger.
class _QueueTile extends StatelessWidget {
  final CourseIntroVideo video;
  final bool isPlaying;
  final VoidCallback onTap;

  const _QueueTile({
    required this.video,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPlaying
          ? AppColors.premium.withValues(alpha: 0.10)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(
                // 16:9 at a thumbnail height derived from the width, so the row
                // keeps its shape on every screen.
                width: 108.w,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          video.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: AppColors.field,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 20.sp,
                              color: AppColors.placeholder,
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 26.w,
                            height: 26.w,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.white,
                              size: 17.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? AppColors.premium
                            : AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      'استاد ${video.teacherLastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _toPersianDigits(String value) {
  const String english = '0123456789';
  const String persian = '۰۱۲۳۴۵۶۷۸۹';

  String result = value;

  for (int i = 0; i < english.length; i++) {
    result = result.replaceAll(english[i], persian[i]);
  }

  return result;
}
