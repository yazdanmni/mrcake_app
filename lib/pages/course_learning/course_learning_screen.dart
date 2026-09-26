import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/course_details.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/house_video_player.dart';

/// One course, laid out as a **video page** rather than a chapter list.
///
/// The structure mirrors the YouTube-style trailer player
/// (`IntroductionVideoPlayerScreen`) and the shared house video surface
/// (`HouseVideoPlayer`), because this is the screen a lesson is watched on:
///
///   ┌─ course title + back pill
///   ├─ the lesson video                        ← [HouseVideoPlayer]
///   ├─ lesson title, chapter · «قسمت ۳ از ۱۲»
///   └─ «قسمت های بعدی»                        ← the rest of the course
///
/// Tapping a row in «قسمت های بعدی» replaces this screen with that lesson, so
/// the player is never more than one tap from the next episode and the back
/// stack does not grow by one entry per episode watched.
class CourseLearningScreen extends StatefulWidget {
  const CourseLearningScreen({super.key, required this.course, this.lesson});

  final Course course;

  /// The lesson to open first. `null` means "the first lesson of the course",
  /// resolved once the chapters arrive.
  final CourseLesson? lesson;

  /// Opens the learning screen for [course] from anywhere.
  ///
  /// [details] is optional because the two entry points differ: the course
  /// details screen already holds the real payload and hands it over, while the
  /// profile only has a [Course] from `GET v1/courses/my_courses/`. In the second
  /// case the screen loads the payload itself — so tapping a course in the
  /// profile goes straight to the content instead of detouring through a details
  /// screen.
  ///
  /// Returns when the screen is popped, so a caller can refresh afterwards.
  static Future<void> open(
    BuildContext context, {
    required Course course,
    CourseDetails? details,
    CourseLesson? lesson,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CourseLearningScreen(
            course: course,
            lesson: lesson ?? (details == null ? null : _firstLesson(details)),
          ),
        ),
      );

  static CourseLesson? _firstLesson(CourseDetails details) {
    for (final CourseChapter chapter in details.chapters) {
      if (chapter.lessons.isNotEmpty) return chapter.lessons.first;
    }
    return null;
  }

  @override
  State<CourseLearningScreen> createState() => _CourseLearningScreenState();
}

class _CourseLearningScreenState extends State<CourseLearningScreen> {
  CourseDetails? _details;

  /// The lesson currently in the player.
  CourseLesson? _lesson;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _load();
    _watch();
  }

  /// Registers this lesson with [LessonWatchDog], so a lesson the user walks
  /// away from is reminded about later.
  void _watch() {
    final CourseLesson? lesson = _lesson;
    if (lesson == null) return;

    LessonWatchDog.instance.startWatching(
      courseId: widget.course.id,
      courseTitle: widget.course.title,
      lesson: lesson,
    );
  }

  Future<void> _load() async {
    final result = await RemoteLoader.value<CourseDetails?>(
      label: 'learning.details',
      fetch: () async {
        final CourseDetails? remote = await CatalogRepository.instance
            .fetchCourseDetails(widget.course.id);

        if (remote == null) return null;

        // Chapters sometimes arrive only from their own endpoint, so the
        // details payload alone can be lesson-less.
        if (remote.chapters.isNotEmpty) return remote;

        final List<CourseChapter> chapters = await CatalogRepository.instance
            .fetchChapters(courseId: widget.course.id);

        return chapters.isEmpty ? remote : remote.copyWithChapters(chapters);
      },
    );

    if (!mounted) return;

    final CourseDetails? details = result.data;

    setState(() {
      _details = details;
      _isLoading = false;

      // No lesson was handed in — start at the beginning of the course.
      if (_lesson == null && details != null) {
        _lesson = CourseLearningScreen._firstLesson(details);
        // The lesson is only known now, so register it here too.
        _watch();
      }
    });
  }

  /// Every lesson of the course in chapter/lesson order — the queue behind
  /// «قسمت های بعدی».
  List<CourseLesson> get _allLessons {
    final CourseDetails? details = _details;
    if (details == null) return const <CourseLesson>[];

    return <CourseLesson>[
      for (final CourseChapter chapter in details.chapters) ...chapter.lessons,
    ];
  }

  /// The lessons after the one playing. Empty on the last episode, which is what
  /// turns the section into its "you finished the course" state.
  List<CourseLesson> get _upNext {
    final CourseLesson? current = _lesson;
    if (current == null) return const <CourseLesson>[];

    final List<CourseLesson> all = _allLessons;
    final int index = all.indexWhere(
      (CourseLesson item) => item.id == current.id,
    );
    if (index == -1) return const <CourseLesson>[];

    return all.sublist(index + 1);
  }

  /// 1-based position of [_lesson] within the course, and the total.
  ({int position, int total}) get _progress {
    final CourseLesson? current = _lesson;
    final List<CourseLesson> all = _allLessons;

    if (current == null || all.isEmpty) {
      return (position: 0, total: all.length);
    }

    final int index = all.indexWhere(
      (CourseLesson item) => item.id == current.id,
    );

    return (position: index == -1 ? 0 : index + 1, total: all.length);
  }

  String get _chapterTitle {
    final CourseLesson? current = _lesson;
    if (current == null) return '';

    for (final CourseChapter chapter
        in _details?.chapters ?? const <CourseChapter>[]) {
      if (chapter.lessons.any((CourseLesson item) => item.id == current.id)) {
        return chapter.title;
      }
    }

    return '';
  }

  /// Switches the player to [lesson] **in place**.
  ///
  /// `pushReplacement` rather than `push`: watching six episodes in a row would
  /// otherwise leave six screens behind the back button. The header keeps its
  /// back pill because the route below is still the one that opened the course.
  void _playLesson(CourseLesson lesson) {
    if (_lesson?.id == lesson.id) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CourseLearningScreen(
          course: widget.course,
          lesson: lesson,
        ),
      ),
    );
  }

  /// End of a lesson means the lesson is watched; reported once per lesson.
  Future<void> _markCompleted() async {
    final CourseLesson? lesson = _lesson;
    if (lesson == null) return;

    // The watchdog is told first: it is what stops the "unfinished" reminder for
    // this lesson, and it must not depend on the network call succeeding.
    LessonWatchDog.instance.markCompleted(lesson.id);

    if (!SessionManager.instance.isLoggedIn) return;

    await RemoteLoader.action(
      'lesson.mark',
      () => CatalogRepository.instance.markLesson(
        courseId: widget.course.id,
        lessonId: lesson.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CourseLesson? lesson = _lesson;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _Header(courseTitle: widget.course.title),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 30.h),
                  children: <Widget>[
                    SizedBox(height: 6.h),

                    HouseVideoPlayer(
                      // A new key per lesson, so switching episodes rebuilds the
                      // surface instead of handing a different url to a
                      // controller mid-flight.
                      key: ValueKey<int>(lesson?.id ?? 0),
                      videoUrl: lesson?.video ?? '',
                      posterUrl: lesson?.thumbnail ?? widget.course.image,
                      onCompleted: _markCompleted,
                      margin: EdgeInsets.symmetric(horizontal: 25.w),
                      errorMessage: lesson == null
                          ? 'قسمتی برای پخش وجود ندارد.'
                          : null,
                    ),

                    SizedBox(height: 18.h),

                    if (_isLoading)
                      const _LoadingLine()
                    else if (lesson == null)
                      const _EmptyLessons()
                    else ...<Widget>[
                      _LessonHeading(
                        lesson: lesson,
                        chapterTitle: _chapterTitle,
                      ),
                      SizedBox(height: 16.h),
                      _ProgressCard(
                        position: _progress.position,
                        total: _progress.total,
                        duration: lesson.duration,
                      ),
                      SizedBox(height: 28.h),
                      _UpNextSection(
                        lessons: _upNext,
                        onLessonTap: _playLesson,
                      ),
                    ],
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

// ============================================================================
// HEADER
// ============================================================================

/// Course title + back pill, in the app's house header style.
///
/// The pill is unconditional: this screen is only ever *pushed*, so there is
/// always something to go back to.
class _Header extends StatelessWidget {
  const _Header({required this.courseTitle});

  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(25.w, 12.h, 25.w, 10.h),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Expanded(
            child: Text(
              courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 20.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 10.w),
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
                Icons.arrow_forward_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LESSON HEADING
// ============================================================================

class _LessonHeading extends StatelessWidget {
  const _LessonHeading({required this.lesson, required this.chapterTitle});

  final CourseLesson lesson;
  final String chapterTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            lesson.title,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (chapterTitle.isNotEmpty) ...<Widget>[
            SizedBox(height: 6.h),
            Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Icon(
                  Icons.playlist_play_rounded,
                  size: 18.sp,
                  color: AppColors.premium,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// PROGRESS CARD
// ============================================================================

/// «قسمت ۳ از ۱۲» — where this lesson sits in the course.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.position,
    required this.total,
    required this.duration,
  });

  final int position;
  final int total;
  final String duration;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    final double ratio = position / total;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.premium, width: 1.w),
        ),
        child: Column(
          children: <Widget>[
            Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Icon(
                  Icons.school_outlined,
                  size: 18.sp,
                  color: AppColors.premium,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'قسمت $position از $total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (duration.isNotEmpty && duration != '0')
                  Text(
                    duration,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(100.r),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6.h,
                backgroundColor: AppColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.premium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UP NEXT
// ============================================================================

/// «قسمت های بعدی» — the rest of the course, in the same shape as the trailer
/// player's queue: a row per lesson with its index, title and duration.
class _UpNextSection extends StatelessWidget {
  const _UpNextSection({required this.lessons, required this.onLessonTap});

  final List<CourseLesson> lessons;
  final ValueChanged<CourseLesson> onLessonTap;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) return const _FinishedCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 25.w),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.premium,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'قسمت های بعدی',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 14.sp,
                    color: AppColors.white,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Flexible(
                child: Text(
                  '${lessons.length} قسمت',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        for (int index = 0; index < lessons.length; index++)
          Padding(
            padding: EdgeInsets.only(
              left: 25.w,
              right: 25.w,
              bottom: index == lessons.length - 1 ? 0 : 8.h,
            ),
            child: _UpNextTile(
              index: index + 1,
              lesson: lessons[index],
              onTap: () => onLessonTap(lessons[index]),
            ),
          ),
      ],
    );
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({
    required this.index,
    required this.lesson,
    required this.onTap,
  });

  final int index;
  final CourseLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.premium.withValues(alpha: 0.55),
              width: 1.w,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              // The index badge, exactly like the trailer player's queue.
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.premium.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.premium, width: 1.w),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
              ),

              SizedBox(width: 10.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (lesson.duration.isNotEmpty &&
                        lesson.duration != '0') ...<Widget>[
                      SizedBox(height: 5.h),
                      Text(
                        lesson.duration,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              Icon(
                Icons.play_circle_outline_rounded,
                size: 26.sp,
                color: AppColors.premium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown after the last lesson: nothing is "next", the course is done.
class _FinishedCard extends StatelessWidget {
  const _FinishedCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.premium, width: 1.w),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.emoji_events_rounded,
              size: 46.sp,
              color: AppColors.premium,
            ),
            SizedBox(height: 14.h),
            Text(
              'این آخرین قسمت دوره بود.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 15.sp,
                color: AppColors.textPrimary,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PLACEHOLDERS
// ============================================================================

class _LoadingLine extends StatelessWidget {
  const _LoadingLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Center(
        child: SizedBox(
          width: 26.w,
          height: 26.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.2.w,
            color: AppColors.premium,
          ),
        ),
      ),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 40.h),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.video_library_outlined,
            size: 52.sp,
            color: AppColors.premium,
          ),
          SizedBox(height: 15.h),
          Text(
            'هنوز قسمتی برای این دوره منتشر نشده است.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
