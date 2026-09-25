import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/network/remote_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/course.dart';
import '../../../repositories/catalog_repository.dart';

class ProfileMyCoursesSection extends StatefulWidget {
  final int userId;

  final VoidCallback? onViewAll;
  final VoidCallback? onGoToCourses;
  final ValueChanged<Course>? onCourseTap;

  /// Bumped by the parent to force a reload.
  ///
  /// `ProfileScreen` lives inside a `MainBottomNavigation` `IndexedStack`, so its
  /// state — and therefore this list — survives every tab switch. Without a
  /// reload trigger the section would fetch exactly once and a course registered
  /// (or approved by an admin) afterwards would never appear, which reads to the
  /// user as "my courses are not in my profile".
  final int reloadToken;

  const ProfileMyCoursesSection({
    super.key,
    required this.userId,
    this.onViewAll,
    this.onGoToCourses,
    this.onCourseTap,
    this.reloadToken = 0,
  });

  @override
  State<ProfileMyCoursesSection> createState() =>
      _ProfileMyCoursesSectionState();
}

class _ProfileMyCoursesSectionState extends State<ProfileMyCoursesSection> {
  List<_UserCourseItem> _items = const <_UserCourseItem>[];

  /// True when the request failed and nothing is cached, so the empty state
  /// would be a lie ("you have no courses" vs "we could not ask").
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void didUpdateWidget(ProfileMyCoursesSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.reloadToken != oldWidget.reloadToken) {
      _load();
    }
  }

  /// Loads the courses the user owns.
  ///
  /// **`GET v1/courses/my_courses/` is the source of truth**, and it returns the
  /// full `CourseList` objects, so no second lookup is needed to name them.
  ///
  /// ⚠️ `GET v1/courses/enrollments/` is *declared* in the OpenAPI schema
  /// (`PaginatedEnrollmentList`) but **does not exist on the live server** — it
  /// answers `404 {"message":"یافت نشد."}`. Pointing this list at it is what made
  /// the profile report "دوره یافت نشد" and show an empty «دوره‌های من» while
  /// Postman happily returned the user's courses from `my_courses/`.
  ///
  /// Progress only exists on an enrollment, so `enrollments/` is still consulted
  /// **best-effort** to enrich the rows with `progress_percent`. Its failure is
  /// swallowed: a course with no progress bar beats no course at all.
  Future<void> _load() async {
    final myCoursesRequest = RemoteLoader.list<Course>(
      label: 'profile.my_courses',
      fetch: CatalogRepository.instance.fetchMyCourses,
      // Bypass the TTL: this list is refreshed precisely because something may
      // have changed on the server.
      refresh: widget.reloadToken > 0,
    );

    final progress = await _fetchProgress();
    final myCourses = await myCoursesRequest;

    if (!mounted) return;

    setState(() {
      _items = myCourses.data
          .map(
            (course) => _UserCourseItem(
              course: course,
              progress: progress[course.id] ?? 0,
            ),
          )
          .toList(growable: false);

      _failed = myCourses.hasError && myCourses.data.isEmpty;
    });
  }

  /// `courseId -> progress (0..1)`, or an empty map when the endpoint is
  /// unavailable (which is the case on the current backend).
  Future<Map<int, double>> _fetchProgress() async {
    try {
      final enrollments = await CatalogRepository.instance.fetchEnrollments();

      return <int, double>{
        for (final enrollment in enrollments)
          if (enrollment.courseId > 0) enrollment.courseId: enrollment.progress,
      };
    } catch (error) {
      debugPrint('[MyCourses] progress unavailable: $error');
      return <int, double>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCourses = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==========================================================
        // SECTION HEADER
        // ==========================================================

        Padding(
          padding: EdgeInsets.only(
            top: 30.h,
            left: 25.w,
            right: 25.w,
            bottom: 16.h,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              // ====================================================
              // COURSE TYPE
              // ====================================================

              Container(
                width: 123.w,
                height: 33.h,
                decoration: BoxDecoration(
                  color: AppColors.premium,
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.r),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'دوره‌های من',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: 'bshabnam',
                    color: AppColors.white,
                  ),
                ),
              ),

              // ====================================================
              // VIEW ALL
              // ====================================================

              if (userCourses.isNotEmpty)
                GestureDetector(
                  onTap: widget.onViewAll,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 95.w,
                    height: 33.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(
                        Radius.circular(8.r),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'مشاهده همه',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontFamily: 'bshabnam',
                        color: AppColors.white,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 95.w,
                  height: 33.h,
                ),
            ],
          ),
        ),

        // ==========================================================
        // CONTENT
        // ==========================================================

        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 25.w,
          ),
          child: userCourses.isEmpty
              ? (_failed
                    ? _FailedMyCourses(onRetry: _load)
                    : _EmptyMyCourses(
                        onGoToCourses: widget.onGoToCourses,
                      ))
              : Column(
                  children: userCourses
                      .map(
                        (item) => Padding(
                          padding: EdgeInsets.only(
                            bottom: 12.h,
                          ),
                          child: _MyCourseCard(
                            item: item,
                            onTap: () {
                              widget.onCourseTap?.call(
                                item.course,
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ===================================================================
// USER COURSE ITEM
// ===================================================================

class _UserCourseItem {
  final Course course;

  /// نسبت پیشرفت بین ۰ و ۱ — از `enrollments/` اگر در دسترس باشد، وگرنه ۰.
  final double progress;

  const _UserCourseItem({
    required this.course,
    this.progress = 0,
  });
}

// ===================================================================
// EMPTY STATE
// ===================================================================

class _EmptyMyCourses extends StatelessWidget {
  final VoidCallback? onGoToCourses;

  const _EmptyMyCourses({
    this.onGoToCourses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 24.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 25.sp,
              color: AppColors.primary,
            ),
          ),

          SizedBox(height: 14.h),

          Text(
            'هنوز دوره‌ای ندارید',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 7.h),

          Text(
            'شما هنوز در هیچ دوره‌ای ثبت‌نام نکرده‌اید',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),

          SizedBox(height: 18.h),

          SizedBox(
            height: 46.h,
            child: ElevatedButton(
              onPressed: onGoToCourses,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: 22.w,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                'رفتن به دوره‌ها',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// FAILED STATE
// ===================================================================

/// Shown when the enrollments call failed and there is nothing cached.
///
/// Deliberately **not** the empty state: telling a user who owns courses that
/// they own none is worse than admitting the request failed. The retry button
/// runs the same load again.
class _FailedMyCourses extends StatelessWidget {
  final VoidCallback onRetry;

  const _FailedMyCourses({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 24.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 25.sp,
              color: AppColors.error,
            ),
          ),

          SizedBox(height: 14.h),

          Text(
            'دریافت دوره‌های شما ناموفق بود',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 7.h),

          Text(
            'اتصال خود را بررسی کنید و دوباره تلاش کنید.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),

          SizedBox(height: 18.h),

          SizedBox(
            height: 46.h,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(
                Icons.refresh_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
              label: Text(
                'تلاش دوباره',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary, width: 1.5.w),
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// MY COURSE CARD
// ===================================================================

class _MyCourseCard extends StatelessWidget {
  final _UserCourseItem item;
  final VoidCallback? onTap;

  const _MyCourseCard({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final course = item.course;

    final double progress = item.progress.clamp(0.0, 1.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // =====================================================
              // COURSE IMAGE
              // =====================================================

              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SizedBox(
                  width: 92.w,
                  height: 92.w,
                  child: Image.network(
                    course.image,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 24.sp,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress
                                        .expectedTotalBytes !=
                                    null
                                ? loadingProgress
                                        .cumulativeBytesLoaded /
                                    loadingProgress
                                        .expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // =====================================================
              // COURSE INFORMATION
              // =====================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 7.h),

                    // =================================================
                    // INSTRUCTOR
                    // فقط نام خانوادگی
                    // =================================================

                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            'استاد ${course.instructorLastName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'bshabnam',
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // =================================================
                    // PROGRESS
                    // =================================================

                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(20.r),
                            child: SizedBox(
                              height: 5.h,
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    AppColors.border,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 8.w),

                        Text(
                          '${(progress * 100).round()}٪',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'bshabnam',
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // =====================================================
              // ARROW
              // =====================================================

              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15.sp,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
