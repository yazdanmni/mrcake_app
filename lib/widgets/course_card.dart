import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme/app_colors.dart';
import '../models/course.dart';

@Deprecated('Use CourseCard from lib/pages/home/widgets/course_card.dart instead. '
    'This widget is kept only for backwards compatibility.')
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
  });

  final Course course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isFree = course.isFree || course.isFreeByPrice;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      elevation: 2.h,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.title,
                style: TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              if (course.shortDescription != null &&
                  course.shortDescription!.isNotEmpty)
                Text(
                  course.shortDescription!,
                  style: TextStyle(
                    fontFamily: 'Shabnam',
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  isFree ? 'رایگان' : '${course.price} تومان',
                  style: TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 14.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
