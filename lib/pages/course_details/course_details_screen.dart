import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/currency_format.dart';
import 'package:mr_cake_project/models/coupon_model.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';
import 'package:mr_cake_project/repositories/support_repository.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/pages/authpage/login_screen.dart';
import 'package:mr_cake_project/core/media/resilient_video_loader.dart';
import 'package:mr_cake_project/pages/course_learning/course_learning_screen.dart';
import 'package:video_player/video_player.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  late CourseDetails details;

  bool isStudent = false;
  bool isLoggedIn = false;
  bool showFullDescription = false;

  @override
  void initState() {
    super.initState();

    // داده اولیه (seed) از اطلاعات پایه دوره‌ای که از لیست آمده ساخته می‌شود.
    // سپس پاسخ کامل بک‌اند با جزئیات، فصل‌ها و دروس جایگزین آن می‌شود.
    details = CourseDetails.seedFrom(widget.course);

    isLoggedIn = SessionManager.instance.isLoggedIn;
    isStudent = details.isEnrolled;

    _loadDetails();
  }

  String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&zwnj;', ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

  Future<void> _loadDetails() async {
    final result = await RemoteLoader.value<CourseDetails>(
      label: 'course.details',
      seed: details,
      fetch: () =>
          CatalogRepository.instance.fetchCourseDetails(widget.course.id),
    );

    if (!mounted) return;

    final loaded = result.data;
    if (loaded == null) return;

    setState(() {
      details = loaded;
      if (loaded.isEnrolled) isStudent = true;
    });
  }

  /// «بعد از صفحه جزئیات دوره» — the next screen is the course content.
  ///
  /// This screen is only ever the last stop for a **pending** request; a student
  /// goes on to [CourseLearningScreen]. The `details` already loaded here are
  /// handed over so the learning screen renders its first frame from real data
  /// instead of a seed.
  void _openLearning(BuildContext context) {
    CourseLearningScreen.open(
      context,
      course: widget.course,
      details: details,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _CourseSliverHeader(course: widget.course),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(height: 20.h),

                // ========================================================
                // TITLE
                // ========================================================
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.w),
                  child: Text(
                    widget.course.title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 20.sp,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),

                SizedBox(height: 4.h),

                // ========================================================
                // COURSE TYPE
                // ========================================================
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.w),
                  child: Text(
                    _courseTypeTitle(widget.course.type),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),

                SizedBox(height: 25.h),

                // ========================================================
                // STATS
                // ========================================================
                _CourseStats(course: widget.course),
                

                SizedBox(height: 23.h),

                // ========================================================
                // ABOUT COURSE
                // ========================================================
                const _SectionTitle(title: 'درباره دوره'),

                SizedBox(height: 9.h),

                _DescriptionBox(
                  description: _stripHtml(details.description ),
                  expanded: showFullDescription,
                  onMoreTap: () {
                    setState(() {
                      showFullDescription = !showFullDescription;
                    });
                  },
                ),

                SizedBox(height: 29.h),

                // ========================================================
                // CHAPTERS
                // ========================================================
                const _SectionTitle(title: 'سرفصل ها'),

                SizedBox(height: 20.h),

                if (details.chapters.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 25.w, right: 25.w),
                    child: Column(
                      children: details.chapters
                          .map((chapter) => _Chapter(chapter: chapter))
                          .toList(),
                    ),
                  ),

                SizedBox(height: 30.h),

                // ========================================================
                // INTRODUCTION
                // ========================================================
                const _SectionTitle(title: 'معرفی دوره'),

                SizedBox(height: 11.h),

                _IntroVideo(
                  imageUrl: details.introImage.isNotEmpty
                      ? details.introImage
                      : widget.course.image,
                  videoUrl: details.introVideo,
                ),

                SizedBox(height: 37.h),

                // ========================================================
                // PRICE
                // ========================================================
                if (!isStudent)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25.w),
                    child: _PriceRow(course: widget.course),
                  ),

                SizedBox(height: 13.h),

                // ================================================================
                // REGISTER BUTTON
                // ================================================================
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.w),
                  child: _RegisterButton(
                    course: widget.course,
                    isStudent: isStudent,

                    // نوع دسترسی واقعی دوره
                    isFree: widget.course.access == CourseAccess.free,

                    // فعلاً وضعیت لاگین تستی
                    isLoggedIn: isLoggedIn,

                    // ============================================================
                    // رفتن به صفحه ورود / ثبت نام
                    // ============================================================
                    onGoToRegister: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },

                    // ============================================================
                    // ثبت نام موفق دوره رایگان
                    // ============================================================
                    onFreeCourseRegistered: () {
                      setState(() {
                        isStudent = true;
                      });
                    },

                    // ============================================================
                    // پرداخت موفق دوره پولی
                    // ============================================================
                    onPaymentSuccess: () {
                      setState(() {
                        isStudent = true;
                      });
                    },

                    // ============================================================
                    // رفتن به محتوای دوره (course_learning_screen)
                    // ============================================================
                    onOpenCourse: () => _openLearning(context),
                  ),
                ),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _courseTypeTitle(CourseType type) {
    switch (type) {
      case CourseType.free:
        return 'دوره رایگان';

      case CourseType.professional:
        return 'دوره حرفه‌ای';

      case CourseType.single:
        return 'تک آموزشی';
    }
  }
}

// ============================================================================
// SLIVER HEADER
// ============================================================================

class _CourseSliverHeader extends StatelessWidget {
  final Course course;

  const _CourseSliverHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 310.h,
      collapsedHeight: 0,
      toolbarHeight: 0,
      floating: false,
      pinned: false,
      snap: false,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _CourseHeaderImage(course: course),
      ),
    );
  }
}

// ============================================================================
// HEADER IMAGE
// ============================================================================

class _CourseHeaderImage extends StatelessWidget {
  final Course course;

  const _CourseHeaderImage({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              course.image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Container(
                      color: AppColors.field,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 42.sp,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
            ),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            Positioned(
              left: 25.w,
              right: 25.w,
              top: MediaQuery.of(context).padding.top + 15.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                textDirection: TextDirection.ltr,
                children: [
                  const _BackButton(),

                  _TeacherCard(course: course),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BACK BUTTON
// ============================================================================

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
      },
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
          Icons.arrow_back_ios_new_rounded,
          size: 19.sp,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// TEACHER CARD
// ============================================================================

class _TeacherCard extends StatelessWidget {
  final Course course;

  const _TeacherCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 119.w,
      height: 37.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(18.5.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 0.7.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                SizedBox(
                  width: 31.w,
                  height: 31.w,
                  child: ClipOval(
                    child: Image.network(
                      course.instructorImage,
                      width: 31.w,
                      height: 31.w,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return Container(
                              width: 31.w,
                              height: 31.w,
                              color: AppColors.field,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.person_outline,
                                size: 18.sp,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                    ),
                  ),
                ),

                SizedBox(width: 5.w),

                Expanded(
                  child: Text(
                    'استاد ${course.instructorLastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COURSE STATS
// ============================================================================

class _CourseStats extends StatelessWidget {
  final Course course;

  const _CourseStats({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74.h,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.premium, width: 2.w),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.groups_rounded,
              value: _formatStudents(course.studentsCount),
            ),
          ),

          _StatDivider(),

          Expanded(
            child: _StatItem(
              icon: Icons.access_time_rounded,
              value: '${course.duration} ساعت',
            ),
          ),

          _StatDivider(),

          Expanded(
            child: _StatItem(
              icon: Icons.video_library_outlined,
              value: '${course.lessons} جلسه',
            ),
          ),
        ],
      ),
    );
  }

  String _formatStudents(int value) {
    if (value >= 1000) {
      final double result = value / 1000;

      if (result == result.roundToDouble()) {
        return '${result.toInt()}k هنرجو';
      }

      return '${result.toStringAsFixed(1)}k هنرجو';
    }

    return '$value هنرجو';
  }
}

// ============================================================================
// STAT ITEM
// ============================================================================

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19.sp, color: AppColors.textPrimary),
        SizedBox(height: 4.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 16.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STAT DIVIDER
// ============================================================================

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.w,
      height: 58.h,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      color: AppColors.premium,
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 104.w,
        height: 33.h,
        margin: EdgeInsets.only(right: 25.w),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.premium, width: 1.w),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 20.sp,
            color: AppColors.textPrimary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DESCRIPTION
// ============================================================================

class _DescriptionBox extends StatelessWidget {
  final String description;
  final bool expanded;
  final VoidCallback onMoreTap;

  const _DescriptionBox({
    required this.description,
    required this.expanded,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, expanded ? 14.h : 8.h),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.premium, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            description,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: expanded ? null : 3,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'shabnam',
              fontSize: 16.sp,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),

          if (!expanded && description.length > 100) ...[
            SizedBox(height: 2.h),

            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMoreTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'بیشتر',
                        style: TextStyle(
                          fontFamily: 'shabnam',
                          fontSize: 13.sp,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (expanded) ...[
            SizedBox(height: 4.h),

            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMoreTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'کمتر',
                        style: TextStyle(
                          fontFamily: 'shabnam',
                          fontSize: 13.sp,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18.sp,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// CHAPTER
// ============================================================================

class _Chapter extends StatelessWidget {
  final CourseChapter chapter;

  const _Chapter({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        children: [
          // ================================================================
          // CHAPTER HEADER
          // ================================================================

          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ------------------------------------------------------------
              // NUMBER
              // ------------------------------------------------------------

              Container(
                width: 33.w,
                height: 33.w,
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.premium, width: 1.w),
                ),
                alignment: Alignment.center,
                child: Text(
                  chapter.number.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 20.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // ------------------------------------------------------------
              // CHAPTER TITLE
              // ------------------------------------------------------------
              Expanded(
                child: Container(
                  height: 33.h,
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.primary, width: 1.w),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  alignment: Alignment.centerRight,
                  child: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 20.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          Column(
            children: List.generate(chapter.lessons.length, (index) {
              final lesson = chapter.lessons[index];

              return Padding(
                padding: EdgeInsets.only(right: 65.w, bottom: 3.h),
                child: _LessonItem(lesson: lesson),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LESSON
// ============================================================================

class _LessonItem extends StatelessWidget {
  final CourseLesson lesson;

  const _LessonItem({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 33.h,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.premium, width: 1.w),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      alignment: Alignment.centerRight,
      child: Text(
        lesson.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'shabnam',
          fontSize: 18.sp,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
// ============================================================================
// INTRO VIDEO
// ============================================================================

class _IntroVideo extends StatefulWidget {
  final String imageUrl;
  final String videoUrl;

  const _IntroVideo({required this.imageUrl, required this.videoUrl});

  @override
  State<_IntroVideo> createState() => _IntroVideoState();
}

class _IntroVideoState extends State<_IntroVideo> {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _hasError = false;
  bool _isLoading = true;

  // نمایش کنترل‌های ویدیو
  bool _showControls = true;

  // تایمر محو شدن کنترل‌ها
  Timer? _controlsTimer;

  // جلوگیری از pause شدن ویدیو هنگام buffering
  bool _wasPlayingBeforeBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

  Future<void> _initializeVideo() async {
    final url = widget.videoUrl.trim();

    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final uri = Uri.tryParse(url);

      if (uri == null || !uri.hasScheme) {
        throw Exception('Invalid video URL: $url');
      }

      // Not a bare `.initialize()`: on a weak device the first attempt can fail
      // for a reason a different display mode fixes, and the user would just see
      // an error where a video should be. See [ResilientVideoLoader].
      final controller = await ResilientVideoLoader.initialize(url);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      controller.addListener(_videoListener);

      setState(() {
        _initialized = true;
        _isLoading = false;
        _hasError = false;
      });

      // شروع تایمر محو شدن کنترل‌ها
      _startControlsTimer();
    } catch (e, stackTrace) {
      debugPrint('================================================');
      debugPrint('INTRO VIDEO ERROR');
      debugPrint('URL: $url');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('================================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ==========================================================================
  // VIDEO LISTENER
  // ==========================================================================

  void _videoListener() {
    final controller = _controller;

    if (!mounted || controller == null) {
      return;
    }

    final value = controller.value;

    // --------------------------------------------------------------------------
    // ERROR
    // --------------------------------------------------------------------------

    if (value.hasError) {
      debugPrint('VideoPlayer error: ${value.errorDescription}');

      if (!_hasError) {
        setState(() {
          _hasError = true;
        });
      }

      return;
    }

    // --------------------------------------------------------------------------
    // BUFFERING
    // --------------------------------------------------------------------------

    if (value.isBuffering) {
      // اگر ویدیو قبل از buffering در حال پخش بوده،
      // فقط وضعیت را ذخیره می‌کنیم.
      // خودمان pause نمی‌کنیم.
      if (value.isPlaying) {
        _wasPlayingBeforeBuffering = true;
      }
    } else {
      // وقتی buffering تمام شد،
      // اگر قبل از buffering در حال پخش بوده،
      // مطمئن می‌شویم دوباره play شده.
      if (_wasPlayingBeforeBuffering && !value.isPlaying) {
        controller.play();
      }

      _wasPlayingBeforeBuffering = false;
    }

    setState(() {});
  }

  // ==========================================================================
  // CONTROLS TIMER
  // ==========================================================================

  void _startControlsTimer() {
    _controlsTimer?.cancel();

    // اگر ویدیو در حال پخش نیست، کنترل‌ها باقی بمانند.
    final controller = _controller;

    if (controller == null || !controller.value.isPlaying) {
      return;
    }

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();

    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }

    _startControlsTimer();
  }

  // ==========================================================================
  // SCREEN TAP
  // ==========================================================================

  void _handleVideoTap() {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    // اگر کنترل‌ها مخفی هستند، با ضربه فقط نمایش داده شوند.
    if (!_showControls) {
      _showControlsTemporarily();
      return;
    }

    // اگر کنترل‌ها نمایش داده می‌شوند،
    // ضربه روی خود ویدیو آنها را دوباره پنهان می‌کند.
    setState(() {
      _showControls = false;
    });

    _controlsTimer?.cancel();
  }

  // ==========================================================================
  // PLAY / PAUSE
  // ==========================================================================

  Future<void> _togglePlay() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      _controlsTimer?.cancel();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }

      _startControlsTimer();
    }
  }

  // ==========================================================================
  // VOLUME
  // ==========================================================================

  Future<void> _toggleVolume() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    final newVolume = controller.value.volume > 0 ? 0.0 : 1.0;

    await controller.setVolume(newVolume);

    if (mounted) {
      setState(() {
        _showControls = true;
      });

      _startControlsTimer();
    }
  }

  // ==========================================================================
  // FULLSCREEN
  // ==========================================================================

  Future<void> _openFullscreen() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    _controlsTimer?.cancel();

    final wasPlaying = controller.value.isPlaying;

    // --------------------------------------------------------------------------
    // Landscape
    // --------------------------------------------------------------------------

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // --------------------------------------------------------------------------
    // Hide system bars
    // --------------------------------------------------------------------------

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenVideoPage(
            controller: controller,
            wasPlaying: wasPlaying,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    // --------------------------------------------------------------------------
    // Restore portrait
    // --------------------------------------------------------------------------

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!mounted) return;

    setState(() {
      _showControls = true;
    });

    _startControlsTimer();
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _controlsTimer?.cancel();

    _controller?.removeListener(_videoListener);
    _controller?.dispose();

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Container(
      height: 201.h,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ==================================================================
          // VIDEO / POSTER
          // ==================================================================

          if (_initialized && controller != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Container(
                      color: AppColors.field,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.video_library_outlined,
                        size: 40.sp,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
            ),

          // ==================================================================
          // TOUCH LAYER
          // ==================================================================
          if (_initialized && !_hasError)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleVideoTap,
              ),
            ),

          // ==================================================================
          // OVERLAY
          // ==================================================================
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.38),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ==================================================================
          // LOADING
          // ==================================================================
          if (_isLoading)
            Center(
              child: SizedBox(
                width: 28.w,
                height: 28.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2.w,
                  color: AppColors.white,
                ),
              ),
            ),

          // ==================================================================
          // BUFFERING
          // ==================================================================
          if (_initialized &&
              controller != null &&
              controller.value.isBuffering)
            Center(
              child: Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2.w,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),

          // ==================================================================
          // CENTER PLAY BUTTON
          // ==================================================================
          if (_initialized &&
              !_hasError &&
              !(_controller?.value.isPlaying ?? false))
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlay,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 58.w,
                        height: 58.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 1.w,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.white,
                          size: 32.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ==================================================================
          // VIDEO CONTROLS
          // ==================================================================
          if (_initialized && controller != null && !_hasError)
            Positioned(
              left: 14.w,
              right: 14.w,
              bottom: 10.h,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showControls ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Column(
                    children: [
                      // ------------------------------------------------------
                      // PROGRESS
                      // ------------------------------------------------------

                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: EdgeInsets.zero,
                        colors: VideoProgressColors(
                          playedColor: AppColors.premium,
                          bufferedColor: Colors.white.withValues(alpha: 0.35),
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),

                      SizedBox(height: 7.h),

                      // ------------------------------------------------------
                      // BOTTOM CONTROLS
                      // ------------------------------------------------------
                      Row(
                        textDirection: TextDirection.ltr,
                        children: [
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.white,
                              size: 21.sp,
                            ),
                          ),

                          SizedBox(width: 10.w),

                          Text(
                            _formatDuration(controller.value.position),
                            style: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 11.sp,
                              color: AppColors.white,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            _formatDuration(controller.value.duration),
                            style: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 11.sp,
                              color: AppColors.white,
                            ),
                          ),

                          SizedBox(width: 12.w),

                          // --------------------------------------------------
                          // VOLUME
                          // --------------------------------------------------
                          GestureDetector(
                            onTap: _toggleVolume,
                            child: Icon(
                              controller.value.volume > 0
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: AppColors.white,
                              size: 20.sp,
                            ),
                          ),

                          SizedBox(width: 12.w),

                          // --------------------------------------------------
                          // FULLSCREEN
                          // --------------------------------------------------
                          GestureDetector(
                            onTap: _openFullscreen,
                            child: Icon(
                              Icons.fullscreen_rounded,
                              color: AppColors.white,
                              size: 22.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ==================================================================
          // ERROR
          // ==================================================================
          if (_hasError)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.white,
                      size: 32.sp,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'پخش ویدیو امکان‌پذیر نیست',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'shabnam',
                        fontSize: 12.sp,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FORMAT DURATION
  // ==========================================================================

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// FULLSCREEN VIDEO
// ============================================================================

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool wasPlaying;

  const _FullscreenVideoPage({
    required this.controller,
    required this.wasPlaying,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;

  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();

    _startTimer();
  }

  void _startTimer() {
    _controlsTimer?.cancel();

    if (!widget.controller.value.isPlaying) {
      return;
    }

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _showControls = false;
      });
    });
  }

  void _toggleControls() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });

      _startTimer();
      return;
    }

    setState(() {
      _showControls = false;
    });

    _controlsTimer?.cancel();
  }

  Future<void> _togglePlay() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();

      _controlsTimer?.cancel();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    } else {
      await widget.controller.play();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }

      _startTimer();
    }
  }

  Future<void> _exitFullscreen() async {
    _controlsTimer?.cancel();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==================================================================
          // VIDEO
          // ==================================================================

          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // ==================================================================
          // TOUCH
          // ==================================================================
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),

          // ==================================================================
          // OVERLAY
          // ==================================================================
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ==================================================================
          // BUFFERING
          // ==================================================================
          if (controller.value.isBuffering)
            Center(
              child: SizedBox(
                width: 38.w,
                height: 38.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5.w,
                  color: AppColors.white,
                ),
              ),
            ),

          // ==================================================================
          // TOP BAR
          // ==================================================================
          Positioned(
            top: 20.h,
            left: 20.w,
            right: 20.w,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _exitFullscreen,
                    child: Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================================================================
          // CENTER PLAY
          // ==================================================================
          if (!controller.value.isPlaying)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1 : 0,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 62.w,
                    height: 62.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34.sp,
                    ),
                  ),
                ),
              ),
            ),

          // ==================================================================
          // BOTTOM CONTROLS
          // ==================================================================
          Positioned(
            left: 25.w,
            right: 25.w,
            bottom: 20.h,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors: VideoProgressColors(
                        playedColor: AppColors.premium,
                        bufferedColor: Colors.white.withValues(alpha: 0.35),
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    Row(
                      children: [
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Text(
                          _formatDuration(controller.value.position),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          _formatDuration(controller.value.duration),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
// ============================================================================
// PRICE
// ============================================================================

class _PriceRow extends StatelessWidget {
  final Course course;

  const _PriceRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final bool free = course.access == CourseAccess.free || course.price == '0';

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'قیمت دوره:',
          style: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 16.sp,
            color: AppColors.textPrimary,
          ),
        ),

        Text(
          free ? 'رایگان' : '${_formatPrice(course.price)} تومان',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 16.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatPrice(String value) {
    final number = int.tryParse(value.replaceAll(',', ''));

    if (number == null) {
      return value;
    }

    final String formatted = number.toString();

    return formatted.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}

// ============================================================================
// REGISTER BUTTON
// ============================================================================

// ============================================================================
// REGISTER BUTTON
// ============================================================================

class _RegisterButton extends StatefulWidget {
  final Course course;
  final bool isStudent;
  final bool isFree;
  final bool isLoggedIn;

  /// برای رفتن به صفحه ثبت‌نام / ورود
  final VoidCallback onGoToRegister;

  /// ثبت‌نام نهایی دوره رایگان
  final VoidCallback? onFreeCourseRegistered;

  /// پرداخت دوره پولی
  final VoidCallback? onPaymentSuccess;

  /// رفتن به صفحه محتوای دوره (`course_learning_screen.dart`).
  ///
  /// Supplied by the parent state because it owns the loaded `CourseDetails`,
  /// which the learning screen needs for its first frame.
  final VoidCallback? onOpenCourse;

  const _RegisterButton({
    required this.course,
    required this.isStudent,
    required this.isFree,
    required this.isLoggedIn,
    required this.onGoToRegister,
    this.onFreeCourseRegistered,
    this.onPaymentSuccess,
    this.onOpenCourse,
  });

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> {
  // ========================================================================
  // Helpers
  // ========================================================================

  /// Drops every cached value that depends on enrolment state so the next
  /// navigation to ProfileScreen -> My Courses or CourseDetails re-fetches
  /// from the server and shows the newly-purchased course.
  static void _invalidateEnrolmentCaches() {
    CatalogRepository.invalidateCatalogueCache();
    RemoteCache.invalidate('course-detail:');
    RemoteCache.invalidate('courses-enrollments');
    RemoteCache.invalidate('courses-my_courses');
  }

  /// Parses an integer amount into a user-friendly price label like
  /// `2,500,000 تومان`.
  ///
  /// Delegates to `core/utils/currency_format.dart` so the ticket body, the
  /// coupon breakdown and the orders screens never disagree on formatting.
  static String _formatToman(int amount) => formatToman(amount);

  /// Creates the order and reports what the backend says it costs.
  ///
  /// The **created order is the only source of truth** for "is this free or
  /// paid". It cannot be the client-side coupon maths: the validator
  /// (`POST v1/discounts/apply/validate/`) is documented with no response body,
  /// so a 100 % coupon can decode to an empty map and look exactly like "no
  /// discount at all". Deciding from that is how a registration whose final
  /// amount was zero used to end up filing a request it did not need.
  ///
  /// `course_ids` is the mandatory field and the only supported way to register
  /// a course — `v1/courses/enrollments/` is read-only, there is no POST on it.
  Future<({bool ok, int subtotal, int discount, int total})> _createOrder({
    required BuildContext context,
    String? couponCode,
  }) async {
    final String? code = (couponCode != null && couponCode.trim().isNotEmpty)
        ? couponCode.trim()
        : null;

    try {
      final Map<String, dynamic> order = await ShopRepository.instance
          .createOrder(
        courseIds: [widget.course.id],
        gateway: PaymentGateway.mock,
        couponCode: code,
        description: 'ثبت نام دوره: ${widget.course.title}',
      );

      final int subtotal =
          Json.asInt(order['subtotal']) ?? widget.course.priceAsInt;
      final int discount = Json.asInt(order['discount_amount']) ?? 0;
      // `total_amount` is already net of the discount (subtotal - discount).
      final int total = Json.asInt(order['total_amount']) ?? subtotal;

      return (
        ok: true,
        subtotal: subtotal < 0 ? 0 : subtotal,
        discount: discount < 0 ? 0 : discount,
        total: total < 0 ? 0 : total,
      );
    } catch (e, stack) {
      debugPrint('Order failed for course ${widget.course.id}: $e');
      debugPrintStack(stackTrace: stack);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16.w),
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            content: Text(
              'ثبت‌نام ناموفق بود. لطفاً دوباره تلاش کنید.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'BShabnam',
                fontSize: 13.sp,
                color: Colors.white,
              ),
            ),
          ),
        );
      }

      return (ok: false, subtotal: 0, discount: 0, total: 0);
    }
  }

  /// Runs the whole registration and branches on what the order actually costs.
  ///
  /// * **`total <= 0`** — the course is free, or a coupon covered it. The backend
  ///   turns the order into an enrollment, the course shows up in «دوره‌های من»
  ///   (read straight from `GET v1/courses/enrollments/`), and **nothing else is
  ///   sent**: no ticket, no cart row. The app never activates a course on the
  ///   device by itself.
  /// * **`total > 0`** — a paid request. The order is the record that shows up in
  ///   «سفارش ها» with status `pending`; a support ticket is filed on the user's
  ///   behalf so the admin can reach them, and the course waits in the cart.
  ///   Once the order is marked paid the backend creates the enrollment and the
  ///   course appears in the profile.
  Future<({bool ok, bool wasFree, int? ticketId})> _submitRegistration({
    required BuildContext context,
    String? couponCode,
  }) async {
    final order = await _createOrder(context: context, couponCode: couponCode);
    if (!order.ok) return (ok: false, wasFree: false, ticketId: null);

    // Drop the enrolment caches either way: the order changed what the profile
    // and this screen will read next.
    _invalidateEnrolmentCaches();

    if (order.total <= 0) {
      return (ok: true, wasFree: true, ticketId: null);
    }

    final int? ticketId = await _fileEnrollmentTicket(
      amount: order.total,
      discountAmount: order.discount,
      couponCode: couponCode,
    );

    return (ok: true, wasFree: false, ticketId: ticketId);
  }

  /// Files the support ticket that tells the admin who is asking, and parks the
  /// course in the cart.
  ///
  /// Both are **best-effort**: the order already exists by the time this runs, so
  /// a failure here must not turn a registered request into an error screen. The
  /// ticket is the only channel carrying the user's contact details, so its
  /// failure is logged and surfaces as a `null` id in the result dialog.
  Future<int?> _fileEnrollmentTicket({
    required int amount,
    required int discountAmount,
    String? couponCode,
  }) async {
    final user = SessionManager.instance.user;
    final String fullName = user?.displayName ?? '';
    final String phone = user?.phoneNumber ?? '';
    final String code = (couponCode ?? '').trim();

    // The name rides in the title as well as the body: the tickets list only
    // renders the title, and the user asked to see their identity there.
    final String title = _truncate(
      'ثبت نام دوره «${widget.course.title}»'
      '${fullName.isEmpty ? '' : ' — $fullName'}',
      250,
    );

    final String message = <String>[
      'درخواست ثبت نام در دوره «${widget.course.title}»',
      '',
      'نام و نام خانوادگی: ${fullName.isEmpty ? '—' : fullName}',
      'شماره تماس: ${phone.isEmpty ? '—' : phone}',
      '',
      'دوره: ${widget.course.title} (شناسه ${widget.course.id})',
      'قیمت دوره: ${_formatToman(widget.course.priceAsInt)}',
      if (code.isNotEmpty) 'کد تخفیف: $code',
      if (discountAmount > 0) 'مبلغ تخفیف: ${_formatToman(discountAmount)}',
      'مبلغ قابل پرداخت: ${_formatToman(amount)}',
    ].join('\n');

    try {
      final subjectId =
          await SupportRepository.instance.resolveNewPurchaseSubjectId();

      final created = await SupportRepository.instance.createTicket(
        title: title,
        message: message,
        subjectId: subjectId,
        priority: 'high',
      );

      try {
        await ShopRepository.instance.addToCart(courseId: widget.course.id);
      } catch (error) {
        debugPrint('addToCart failed for course ${widget.course.id}: $error');
      }

      return Json.asInt(created['id']);
    } catch (e, stack) {
      debugPrint('Enrollment ticket failed for course ${widget.course.id}: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  /// Clips [value] to [max] characters. The API caps a ticket title at 250.
  static String _truncate(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';

  /// A student tapping «شما دانشجوی این دوره هستید» opens the course content.
  ///
  /// The parent supplies [onOpenCourse] so the learning screen starts from the
  /// already-loaded `CourseDetails` instead of re-fetching them from scratch.
  /// The fallback keeps the button alive if the callback is ever omitted.
  void _openCourseScreen(BuildContext context) {
    final callback = widget.onOpenCourse;
    if (callback != null) {
      callback();
      return;
    }

    CourseLearningScreen.open(context, course: widget.course);
  }

  // ========================================================================
  // Build
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64.h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // A student re-opens the same screen (see [_openCourseScreen]);
            // everybody else starts a registration.
            if (widget.isStudent) {
              _openCourseScreen(context);
              return;
            }

            if (!widget.isLoggedIn) {
              _showLoginRequiredDialog(context);
              return;
            }

            if (widget.isFree) {
              _showFreeCourseConfirmDialog(context);
            } else {
              _showCouponAndCheckoutDialog(context);
            }
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Ink(
            decoration: BoxDecoration(
              color: widget.isStudent
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                widget.isStudent
                    ? 'شما دانشجوی این دوره هستید'
                    : 'ثبت نام دوره',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 18.sp,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // LOGIN / REGISTER REQUIRED
  // ========================================================================

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22.r),
            ),
            contentPadding: EdgeInsets.fromLTRB(24.w, 26.h, 24.w, 20.h),
            title: Text(
              'ورود به حساب کاربری',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 19.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            content: Text(
              'برای ثبت‌نام در دوره ابتدا باید وارد حساب کاربری خود شوید یا حساب جدیدی ایجاد کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 14.sp,
                height: 1.8,
                color: AppColors.black.withValues(alpha: 0.65),
              ),
            ),
            actionsPadding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 18.h),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    widget.onGoToRegister();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'ورود / ثبت نام',
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 15.sp,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========================================================================
  // FREE COURSE — confirmation then server-side order + enrollment
  //
  // This is the **single** "nothing to pay" registration flow. It is used for
  //   * a course whose access is `free`, and
  //   * a paid course whose discount code covered 100 % of the price
  //     ([couponCode] is then forwarded to the order so the backend can record
  //     which coupon was used).
  //
  // Keeping one implementation is what makes a 100 % coupon behave *exactly*
  // like a free course — same confirmation, same checkbox, same success dialog.
  // ========================================================================

  void _showFreeCourseConfirmDialog(
    BuildContext context, {
    String? couponCode,
  }) {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.r),
                ),
                contentPadding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 18.h),
                title: Text(
                  'ثبت نام در دوره',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // The wording has to be honest about *why* there is
                      // nothing to pay: a genuinely free course, or a coupon
                      // that covered the whole price.
                      couponCode == null
                          ? 'این دوره رایگان است. آیا می‌خواهید دانشجوی این دوره شوید؟'
                          : 'کد تخفیف شما کل هزینه این دوره را پوشش داد. آیا می‌خواهید دانشجوی این دوره شوید؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        height: 1.8,
                        color: AppColors.black.withValues(alpha: 0.65),
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // ------------------------------------------------------
                    // CONFIRM CHECKBOX
                    // ------------------------------------------------------
                    InkWell(
                      onTap: () {
                        setState(() {
                          isChecked = !isChecked;
                        });
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 4.h,
                          horizontal: 4.w,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26.w,
                              height: 26.w,
                              child: Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    isChecked = value ?? false;
                                  });
                                },
                              ),
                            ),

                            SizedBox(width: 8.w),

                            Expanded(
                              child: Text(
                                'بله، می‌خواهم دانشجوی این دوره شوم',
                                style: TextStyle(
                                  fontFamily: 'bshabnam',
                                  fontSize: 13.sp,
                                  color: AppColors.black.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                actionsPadding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 18.h),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: isChecked
                          ? () async {
                              Navigator.of(dialogContext).pop();
                              final result = await _submitRegistration(
                                context: ctx,
                                couponCode: couponCode,
                              );
                              if (!ctx.mounted) return;
                              if (!result.ok) return;

                              // The order has the last word: a coupon the client
                              // could not size may still have covered everything,
                              // and vice versa.
                              if (result.wasFree) {
                                _showFreeSuccessDialog(ctx);
                              } else {
                                _showEnrollmentRequestDialog(
                                  ctx,
                                  ticketId: result.ticketId,
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.25,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'تأیید و ثبت نام',
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 15.sp,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // PAID COURSE — coupon step → 100% free enroll → or payment
  // ========================================================================

  void _showCouponAndCheckoutDialog(BuildContext rootContext) {
    final TextEditingController couponController = TextEditingController();
    final FocusNode couponFocus = FocusNode();

    final int originalAmount = widget.course.priceAsInt;

    CouponValidation? couponResult;
    bool validatingCoupon = false;
    bool completingEnrollment = false;
    String? couponErrorMsg;

    showDialog(
      context: rootContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final CouponValidation cv = couponResult ??
                CouponValidation.invalid('').applyToAmount(originalAmount);

            final bool isFreeFinal = cv.isFree;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.r),
                ),
                contentPadding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 18.h),
                title: Text(
                  'خرید دوره',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ------------------------------------------------------
                      // Intro text
                      // ------------------------------------------------------
                      Text(
                        'برای ثبت نام، در صورت داشتن کد تخفیف آن را وارد کنید. اگر کد کل هزینه دوره را پوشش دهد، ثبت نام رایگان انجام می‌شود؛ در غیر این صورت درخواست شما برای بررسی ارسال و دوره تا تأیید در «سبد خرید» می‌ماند.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 13.5.sp,
                          height: 1.8,
                          color: AppColors.black.withValues(alpha: 0.65),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // ------------------------------------------------------
                      // Coupon field
                      // ------------------------------------------------------
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: couponController,
                          focusNode: couponFocus,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            fontFamily: 'BShabnam',
                            fontSize: 15.sp,
                            letterSpacing: 1.4,
                            color: AppColors.black,
                          ),
                          textAlign: TextAlign.left,
                          cursorColor: AppColors.primary,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.field,
                            hintText: 'کد تخفیف خود را وارد کنید',
                            hintStyle: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 13.sp,
                              letterSpacing: 0,
                              color: AppColors.textSecondary,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                            suffixIcon: IconButton(
                              icon: validatingCoupon
                                  ? SizedBox(
                                      width: 18.w,
                                      height: 18.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.w,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.local_activity_outlined,
                                      size: 21.sp,
                                      color: AppColors.primary,
                                    ),
                              onPressed: validatingCoupon
                                  ? null
                                  : () async {
                                      final code = couponController.text.trim();
                                      if (code.isEmpty) {
                                        setDialogState(() {
                                          couponResult = null;
                                          couponErrorMsg = null;
                                        });
                                        return;
                                      }
                                      couponFocus.unfocus();
                                      setDialogState(() {
                                        validatingCoupon = true;
                                        couponErrorMsg = null;
                                      });
                                      final CouponValidation res =
                                          await ShopRepository.instance
                                              .validateCouponForAmount(
                                        code: code,
                                        amount: originalAmount,
                                        courseId: widget.course.id,
                                      );
                                      if (!ctx.mounted) return;
                                      setDialogState(() {
                                        validatingCoupon = false;
                                        if (res.valid) {
                                          couponResult = res;
                                          couponErrorMsg = null;
                                        } else {
                                          couponResult = null;
                                          couponErrorMsg =
                                              'کد تخفیف وارد شده معتبر نیست یا منقضی شده است.';
                                        }
                                      });
                                    },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: AppColors.border,
                                width: 1.5.w,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: AppColors.border,
                                width: 1.5.w,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2.w,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: AppColors.error,
                                width: 1.5.w,
                              ),
                            ),
                            errorStyle: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 12.sp,
                              color: AppColors.error,
                            ),
                          ),
                          onSubmitted: (_) async {
                            if (validatingCoupon) return;
                            final code = couponController.text.trim();
                            if (code.isEmpty) {
                              setDialogState(() {
                                couponResult = null;
                                couponErrorMsg = null;
                              });
                              return;
                            }
                            couponFocus.unfocus();
                            setDialogState(() {
                              validatingCoupon = true;
                              couponErrorMsg = null;
                            });
                            final CouponValidation res = await ShopRepository
                                .instance
                                .validateCouponForAmount(
                              code: code,
                              amount: originalAmount,
                              courseId: widget.course.id,
                            );
                            if (!ctx.mounted) return;
                            setDialogState(() {
                              validatingCoupon = false;
                              if (res.valid) {
                                couponResult = res;
                                couponErrorMsg = null;
                              } else {
                                couponResult = null;
                                couponErrorMsg =
                                    'کد تخفیف وارد شده معتبر نیست یا منقضی شده است.';
                              }
                            });
                          },
                        ),
                      ),

                      if (couponErrorMsg != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          couponErrorMsg!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'shabnam',
                            fontSize: 12.5.sp,
                            color: AppColors.error,
                          ),
                        ),
                      ],

                      if (couponResult != null && couponResult!.valid) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 19.sp,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  couponResult!.is100Percent
                                      ? 'کد تخفیف شما کل هزینه دوره را پوشش می‌دهد.'
                                      : 'کد تخفیف ${couponResult!.code} با موفقیت اعمال شد.',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'BShabnam',
                                    fontSize: 12.5.sp,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 22.h),

                      // ------------------------------------------------------
                      // Price breakdown
                      // ------------------------------------------------------
                      _PriceLine(
                        label: 'قیمت دوره',
                        value: _formatToman(originalAmount),
                        isSubtracted: false,
                      ),

                      if (cv.discountAmount > 0) ...[
                        SizedBox(height: 10.h),
                        _PriceLine(
                          label: 'تخفیف اعمال شده',
                          value: '- ${_formatToman(cv.discountAmount)}',
                          isSubtracted: true,
                        ),
                      ],

                      const Divider(height: 26),

                      _PriceLine(
                        label: 'مبلغ قابل پرداخت',
                        value: _formatToman(cv.finalAmount),
                        emphasize: true,
                        isFinal: isFreeFinal,
                      ),
                    ],
                  ),
                ),
                actionsPadding: EdgeInsets.fromLTRB(18.w, 6.h, 18.w, 18.h),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: completingEnrollment
                          ? null
                          : () async {
                              couponFocus.unfocus();

                              // Validate first (if user typed a code but did
                              // not yet press the "apply" icon).
                              final String typed = couponController.text.trim();
                              CouponValidation? candidate = couponResult;

                              if (typed.isNotEmpty &&
                                  (candidate == null ||
                                      candidate.code != typed)) {
                                setDialogState(() {
                                  validatingCoupon = true;
                                });
                                candidate = await ShopRepository.instance
                                    .validateCouponForAmount(
                                  code: typed,
                                  amount: originalAmount,
                                  courseId: widget.course.id,
                                );
                                if (!ctx.mounted) return;
                                setDialogState(() {
                                  validatingCoupon = false;
                                  if (candidate!.valid) {
                                    couponResult = candidate;
                                    couponErrorMsg = null;
                                  } else {
                                    couponResult = null;
                                    couponErrorMsg =
                                        'کد تخفیف معتبر نیست. بدون کد ادامه می‌دهید؟';
                                    // Keep `candidate` as a zero-discount
                                    // validation so we can still proceed.
                                    candidate = CouponValidation.invalid(typed)
                                        .applyToAmount(originalAmount);
                                  }
                                });
                              }

                              candidate ??= CouponValidation.invalid('')
                                  .applyToAmount(originalAmount);

                              // Only a coupon the API accepted is forwarded to
                              // the order; an invalid code must never block the
                              // "continue without a coupon" path.
                              final String? appliedCode =
                                  candidate!.valid && candidate!.code.isNotEmpty
                                      ? candidate!.code
                                      : null;

                              // A coupon that covers the whole price turns the
                              // course into a free one, so it runs the exact
                              // same registration steps as a free course.
                              if (candidate!.isFree) {
                                Navigator.of(dialogContext).pop();
                                _showFreeCourseConfirmDialog(
                                  rootContext,
                                  couponCode: appliedCode,
                                );
                                return;
                              }

                              setDialogState(() {
                                completingEnrollment = true;
                              });

                              // One call decides everything: it creates the order
                              // and branches on what the backend says it costs.
                              // A zero total is a free enrollment and files
                              // nothing extra — that is what stops a coupon that
                              // covers the whole price from sending a request.
                              final result = await _submitRegistration(
                                context: ctx,
                                couponCode: appliedCode,
                              );

                              if (!ctx.mounted) return;
                              setDialogState(() {
                                completingEnrollment = false;
                              });

                              if (!result.ok) return;

                              Navigator.of(dialogContext).pop();

                              if (result.wasFree) {
                                _showFreeSuccessDialog(rootContext);
                              } else {
                                _showEnrollmentRequestDialog(
                                  rootContext,
                                  ticketId: result.ticketId,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: completingEnrollment
                          ? Center(
                              child: SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.w,
                                  color: AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              isFreeFinal
                                  ? 'ثبت نام رایگان فوری'
                                  : 'ارسال درخواست ثبت نام',
                              style: TextStyle(
                                fontFamily: 'bshabnam',
                                fontSize: 16.sp,
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // Success dialogs
  // ========================================================================

  void _showFreeSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22.r),
            ),
            contentPadding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 38.sp,
                    color: Colors.green,
                  ),
                ),

                SizedBox(height: 18.h),

                Text(
                  'ثبت نام با موفقیت انجام شد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),

                SizedBox(height: 10.h),

                Text(
                  'این دوره به حساب کاربری شما اضافه شد و اکنون در بخش «دوره‌های من» پروفایل شما قابل مشاهده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.sp,
                    height: 1.8,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),

                SizedBox(height: 20.h),

                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();

                      widget.onFreeCourseRegistered?.call();
                      widget.onPaymentSuccess?.call();

                      // The course is the user's now, so the flow continues into
                      // the course content (`course_learning_screen.dart`) — this
                      // is the "after the course details screen" step of a free
                      // or 100 % coupon registration. Nothing is activated
                      // on-device: the enrollment came from the backend.
                      widget.onOpenCourse?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'شروع یادگیری',
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shown after a **paid** registration request was filed.
  ///
  /// Deliberately not the green "payment succeeded" dialog: nothing was paid.
  /// The wording has to set the right expectation — the course is not in
  /// «دوره‌های من» yet, it is waiting in the cart.
  void _showEnrollmentRequestDialog(
    BuildContext context, {
    int? ticketId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22.r),
            ),
            contentPadding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 36.sp,
                    color: AppColors.primary,
                  ),
                ),

                SizedBox(height: 18.h),

                Text(
                  'درخواست ثبت نام ارسال شد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),

                SizedBox(height: 10.h),

                Text(
                  'درخواست شما همراه با نام و شماره تماس‌تان برای بررسی ارسال شد. این دوره تا تأیید پرداخت سفارش، در «سفارش‌ها» و «سبد خرید» شما باقی می‌ماند و پس از تأیید به «دوره‌های من» در پروفایل شما اضافه می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.sp,
                    height: 1.8,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),

                if (ticketId != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    'شماره پیگیری: #$ticketId',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],

                SizedBox(height: 20.h),

                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      widget.onPaymentSuccess?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'متوجه شدم',
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final bool isSubtracted;
  final bool isFinal;

  const _PriceLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.isSubtracted = false,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        emphasize ? AppColors.black : AppColors.black.withValues(alpha: 0.7);
    final FontWeight labelWeight =
        emphasize ? FontWeight.w700 : FontWeight.w500;

    Color valueColor;
    if (isFinal) {
      valueColor = AppColors.primary;
    } else if (isSubtracted) {
      valueColor = Colors.green;
    } else {
      valueColor = emphasize ? AppColors.black : AppColors.black.withValues(alpha: 0.85);
    }

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BShabnam',
            fontSize: emphasize ? 15.5.sp : 13.5.sp,
            fontWeight: labelWeight,
            color: labelColor,
          ),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'BShabnam',
            fontSize: emphasize ? 16.sp : 14.sp,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
