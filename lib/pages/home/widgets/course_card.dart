import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;

  /// `null` keeps the Figma default size. The values can not be written as
  /// `.w` / `.h` directly in the parameter list: an extension getter is not a
  /// constant expression, so the constructor would lose its `const`.
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 180.w,
      height: height ?? 267.h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ==================================================
                // COURSE IMAGE
                // ==================================================

                Image.network(
                  course.image,
                  fit: BoxFit.cover,
                  width: width,
                  height: height,
                  loadingBuilder:
                      (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return Container(
                          color: AppColors.field,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.w,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return Container(
                          color: AppColors.field,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 28.sp,
                            color: AppColors.placeholder,
                          ),
                        );
                      },
                ),

                // ==================================================
                // BOTTOM GRADIENT
                // ==================================================
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.10, 0.30, 0.48, 0.68, 0.84, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppColors.sectionBackground.withValues(alpha: 0.18),
                          AppColors.sectionBackground.withValues(alpha: 0.52),
                          AppColors.sectionBackground.withValues(alpha: 0.86),
                          AppColors.sectionBackground,
                        ],
                      ),
                    ),
                  ),
                ),
                // ==================================================
                // CONTENT
                // ==================================================

                Positioned(
                  left: 10.w,
                  right: 10.w,
                  bottom: 9.h,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // TEACHER GLASS CARD
                      // ==================================================

                      _TeacherCard(course: course),

                      SizedBox(height: 7.h),

                      // ==================================================
                      // COURSE TITLE
                      // ==================================================
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PinarB',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),

                      SizedBox(height: 5.h),

                      // ==================================================
                      // LESSONS + DURATION
                      // ==================================================
                      //
                      // ⚠️ Both items are `Flexible`. The card is a fixed
                      // `cardWidth` wide while these run at `14.sp`, which in
                      // this project scales with the screen **width** — so on a
                      // tablet (1024×768) «۸ قسمت • ۲ ساعت» is far wider than
                      // the 190 px card and the row used to overflow by 84 px.
                      // Shrinking lets the longer label ellipsise instead.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _InfoItem(
                              text: '${_toPersianDigits(course.lessons)} قسمت',
                              fontFamily: 'Shabnam',
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          SizedBox(width: 9.w),

                          Container(
                            width: 3.w,
                            height: 3.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          SizedBox(width: 9.w),

                          Flexible(
                            child: _InfoItem(
                              text: '${_toPersianDigits(course.duration)} ساعت',
                              fontFamily: 'Shabnam',
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4.h),

                      // ==================================================
                      // PRICE
                      // ==================================================
                      if (_isFreeCourse(course.price))
                        Text(
                          'رایگان',
                          style: TextStyle(
                            fontFamily: 'Shabnam',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1,
                          ),
                        )
                      else
                        // Same reason as the lessons/duration row above: a
                        // `16.sp` price inside a fixed-width card is wider than
                        // the card on a tablet, so the number and its currency
                        // both have to be able to shrink.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                _formatPrice(course.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Shabnam',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  height: 1,
                                ),
                              ),
                            ),

                            SizedBox(width: 4.w),

                            Flexible(
                              child: Text(
                                course.currency,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Pinar',
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
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

// ================================================================
// TEACHER CARD
// ================================================================

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
              // رنگ اصلی برند با شفافیت
              color: AppColors.primary.withValues(alpha: 0.30),

              borderRadius: BorderRadius.circular(18.5.r),

              // لبه شیشه‌ای
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 0.7.w,
              ),

              // سایه خیلی نرم
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
              children: [
                // ==============================
                // PROFILE
                // ==============================

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

                // ==============================
                // TEACHER NAME
                // ==============================
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: Text(
                      'استاد ${course.instructorLastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'bShabnam',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.1.h,
                      ),
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

// ================================================================
// INFO ITEM
// ================================================================

class _InfoItem extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;

  const _InfoItem({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        height: 1,
      ),
    );
  }
}

// ================================================================
// PRICE FORMATTER
// ================================================================

String _formatPrice(String value) {
  final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.isEmpty) {
    return '۰';
  }

  final String formatted = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (Match match) => '${match[1]},',
  );

  return _toPersianDigits(formatted);
}

// ================================================================
// PERSIAN DIGITS
// ================================================================

String _toPersianDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  String result = value;

  for (int i = 0; i < english.length; i++) {
    result = result.replaceAll(english[i], persian[i]);
  }

  return result;
}

bool _isFreeCourse(String value) {
  final digits = value.replaceAll(',', '').replaceAll('٬', '').trim();

  return digits == '0' || digits == '۰' || digits.isEmpty;
}
