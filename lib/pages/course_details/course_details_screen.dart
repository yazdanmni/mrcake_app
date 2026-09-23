import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/data/course_details_data.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/pages/authpage/login_screen.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';
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

    // داده آفلاین بلافاصله نمایش داده می‌شود، سپس پاسخ بک‌اند جایگزین می‌شود.
    details = CourseDetailsData.getByCourseId(widget.course.id);

    isLoggedIn = SessionManager.instance.isLoggedIn;
    isStudent = details.isEnrolled;

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final result = await RemoteLoader.value<CourseDetails>(
      label: 'course.details',
      seed: details,
      fetch: () => CatalogRepository.instance.fetchCourseDetails(
        widget.course.id,
      ),
    );

    if (!mounted) return;

    final loaded = result.data;
    if (loaded == null) return;

    setState(() {
      details = loaded;
      if (loaded.isEnrolled) isStudent = true;
    });
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
                  description: details.description,
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

      final controller = VideoPlayerController.networkUrl(uri);

      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
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

class _RegisterButton extends StatelessWidget {
  final bool isStudent;
  final bool isFree;
  final bool isLoggedIn;

  /// برای رفتن به صفحه ثبت‌نام / ورود
  final VoidCallback onGoToRegister;

  /// ثبت‌نام نهایی دوره رایگان
  /// بعداً این قسمت می‌تواند به API وصل شود.
  final VoidCallback? onFreeCourseRegistered;

  /// پرداخت دوره پولی
  /// فعلاً فقط دیالوگ نمایش داده می‌شود.
  /// بعداً API پرداخت اینجا قرار می‌گیرد.
  final VoidCallback? onPaymentSuccess;

  const _RegisterButton({
    required this.isStudent,
    required this.isFree,
    required this.isLoggedIn,
    required this.onGoToRegister,
    this.onFreeCourseRegistered,
    this.onPaymentSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64.h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isStudent
              ? null
              : () {
                  if (!isLoggedIn) {
                    _showLoginRequiredDialog(context);
                    return;
                  }

                  if (isFree) {
                    _showFreeCourseDialog(context);
                  } else {
                    _showPaidCourseDialog(context);
                  }
                },
          borderRadius: BorderRadius.circular(16.r),
          child: Ink(
            decoration: BoxDecoration(
              color: isStudent
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                isStudent ? 'شما دانشجوی این دوره هستید' : 'ثبت نام دوره',
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

  // ==========================================================================
  // LOGIN / REGISTER REQUIRED
  // ==========================================================================

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

                    onGoToRegister();
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

  // ==========================================================================
  // FREE COURSE DIALOG
  // ==========================================================================

  void _showFreeCourseDialog(BuildContext context) {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      'این دوره رایگان است. آیا می‌خواهید در این دوره ثبت نام کنید؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        height: 1.8,
                        color: AppColors.black.withValues(alpha: 0.65),
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // ----------------------------------------------------------
                    // CONFIRM CHECKBOX
                    // ----------------------------------------------------------
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
                                'بله، می‌خواهم در این دوره ثبت نام کنم',
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
                          ? () {
                              Navigator.of(dialogContext).pop();

                              // فعلاً ثبت‌نام را شبیه‌سازی می‌کنیم.
                              _showFreeSuccessDialog(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 
                          0.25,
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

  // ==========================================================================
  // FREE COURSE SUCCESS
  // ==========================================================================

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
                  'این دوره به حساب کاربری شما اضافه شد.',
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

                      onFreeCourseRegistered?.call();
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

  // ==========================================================================
  // PAID COURSE DIALOG
  // ==========================================================================

  void _showPaidCourseDialog(BuildContext context) {
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
              'خرید دوره',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 19.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            content: Text(
              'این دوره شامل هزینه است. برای ثبت نام باید ابتدا پرداخت دوره انجام شود.',
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

                    // ==========================================================
                    // فعلاً پرداخت را شبیه‌سازی می‌کنیم.
                    // بعداً API پرداخت اینجا قرار می‌گیرد.
                    // ==========================================================

                    _showPaymentSuccessDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'ادامه و پرداخت',
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

  // ==========================================================================
  // PAYMENT SUCCESS
  // ==========================================================================

  void _showPaymentSuccessDialog(BuildContext context) {
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
                  'پرداخت با موفقیت انجام شد',
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
                  'دوره به حساب کاربری شما اضافه شد و اکنون می‌توانید به محتوای آن دسترسی داشته باشید.',
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

                      onPaymentSuccess?.call();
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
