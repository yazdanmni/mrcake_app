import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/network/remote_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/course.dart';
import '../../../models/enrollment.dart';
import '../../../repositories/catalog_repository.dart';

class ProfileMyCoursesSection extends StatefulWidget {
  final int userId;

  final VoidCallback? onViewAll;
  final VoidCallback? onGoToCourses;
  final ValueChanged<Course>? onCourseTap;

  const ProfileMyCoursesSection({
    super.key,
    required this.userId,
    this.onViewAll,
    this.onGoToCourses,
    this.onCourseTap,
  });

  @override
  State<ProfileMyCoursesSection> createState() =>
      _ProfileMyCoursesSectionState();
}

class _ProfileMyCoursesSectionState extends State<ProfileMyCoursesSection> {
  late List<Enrollment> _enrollments = const [];
  List<Course> _courses = const [];

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    final enrollmentsRequest = RemoteLoader.list<Enrollment>(
      label: 'profile.enrollments',
      fetch: CatalogRepository.instance.fetchEnrollments,
    );

    final coursesRequest = RemoteLoader.list<Course>(
      label: 'profile.courses',
      fetch: CatalogRepository.instance.fetchCourses,
    );

    final enrollments = await enrollmentsRequest;
    final courses = await coursesRequest;

    if (!mounted) return;

    setState(() {
      _enrollments = enrollments.data;
      _courses = courses.data;
    });
  }

  // ================================================================
  // GET USER COURSES
  // ================================================================

  List<_UserCourseItem> _getUserCourses() {
    final List<_UserCourseItem> result = [];

    for (final enrollment in _enrollments) {
      // بک‌اند دوره را همراه ثبت‌نام می‌فرستد؛ در غیر این صورت از لیست
      // دوره‌ها پیدا می‌شود.
      final nested = enrollment.course;

      if (nested != null) {
        result.add(
          _UserCourseItem(
            course: nested,
            enrollment: enrollment,
          ),
        );

        continue;
      }

      for (final item in _courses) {
        if (item.id == enrollment.courseId) {
          result.add(
            _UserCourseItem(
              course: item,
              enrollment: enrollment,
            ),
          );

          break;
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final userCourses = _getUserCourses();

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
              ? _EmptyMyCourses(
                  onGoToCourses: widget.onGoToCourses,
                )
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
  final Enrollment enrollment;

  const _UserCourseItem({
    required this.course,
    required this.enrollment,
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
    final enrollment = item.enrollment;

    final double progress =
        enrollment.progress.clamp(0.0, 1.0).toDouble();

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
