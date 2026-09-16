import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.width = 180,
    this.height = 267,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
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
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
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
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 28,
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
                          AppColors.sectionBackground.withOpacity(0.18),
                          AppColors.sectionBackground.withOpacity(0.52),
                          AppColors.sectionBackground.withOpacity(0.86),
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
                  left: 10,
                  right: 10,
                  bottom: 9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // TEACHER GLASS CARD
                      // ==================================================

                      _TeacherCard(course: course),

                      const SizedBox(height: 7),

                      // ==================================================
                      // COURSE TITLE
                      // ==================================================
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PinarB',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // ==================================================
                      // LESSONS + DURATION
                      // ==================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _InfoItem(
                            text: '${_toPersianDigits(course.lessons)} قسمت',
                            fontFamily: 'Shabnam',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),

                          const SizedBox(width: 9),

                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(width: 9),

                          _InfoItem(
                            text: '${_toPersianDigits(course.duration)} ساعت',
                            fontFamily: 'Shabnam',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // ==================================================
                      // PRICE
                      // ==================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatPrice(course.price),
                            style: const TextStyle(
                              fontFamily: 'Shabnam',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1,
                            ),
                          ),

                          const SizedBox(width: 4),

                          Text(
                            course.currency,
                            style: const TextStyle(
                              fontFamily: 'Pinar',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1,
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
        borderRadius: BorderRadius.circular(18.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            decoration: BoxDecoration(
              // رنگ اصلی برند با شفافیت
              color: AppColors.primary.withOpacity(0.30),

              borderRadius: BorderRadius.circular(18.5),

              // لبه شیشه‌ای
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 0.7,
              ),

              // سایه خیلی نرم
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.16),
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
                  height: 31.h,
                  child: ClipOval(
                    child: Image.network(
                      course.instructorImage,
                      width: 31.w,
                      height: 31.h,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return Container(
                              width: 31.w,
                              height: 31.h,
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

                const SizedBox(width: 5),

                // ==============================
                // TEACHER NAME
                // ==============================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
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
