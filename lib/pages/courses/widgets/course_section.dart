import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/pages/home/widgets/course_card.dart';

import '../../../models/course.dart';

class CourseSection extends StatelessWidget {
  final String title;
  final List<Course> courses;
  final ValueChanged<Course>? onCourseTap;
  final VoidCallback? onViewAll;

  const CourseSection({
    super.key,
    required this.title,
    required this.courses,
    this.onCourseTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const SizedBox.shrink();
    }

    final double cardWidth = _getCardWidth(context);
    final double cardHeight = cardWidth * 267 / 180;

    return Column(
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
                  title,
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

              GestureDetector(
                onTap: onViewAll,
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
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontFamily: 'bshabnam',
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ==========================================================
        // HORIZONTAL COURSES
        // ==========================================================

        SizedBox(
          height: cardHeight,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: 25.w,
              ),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: courses.length,
              separatorBuilder: (
                BuildContext context,
                int index,
              ) {
                return SizedBox(
                  width: 12.w,
                );
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final Course course = courses[index];

                return CourseCard(
                  course: course,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () {
                    onCourseTap?.call(course);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // RESPONSIVE CARD WIDTH
  // ================================================================

  double _getCardWidth(BuildContext context) {
    final double width =
        MediaQuery.sizeOf(context).width;

    if (width <= 320) {
      return 145;
    }

    if (width <= 360) {
      return 155;
    }

    if (width <= 390) {
      return 165;
    }

    if (width <= 430) {
      return 175;
    }

    return 185;
  }
}