import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/course_intro_video.dart';

class CourseIntroVideoCard extends StatelessWidget {
  final CourseIntroVideo video;
  final VoidCallback? onTap;

  const CourseIntroVideoCard({
    super.key,
    required this.video,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Thumbnail(
              video: video,
            ),

            SizedBox(height: 10.h),

            _VideoInformation(
              video: video,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final CourseIntroVideo video;

  const _Thumbnail({
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 222 / 121,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              video.thumbnail,
              fit: BoxFit.cover,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? progress,
              ) {
                if (progress == null) {
                  return child;
                }

                return Container(
                  color: AppColors.field,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
              errorBuilder: (
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

            Positioned(
              right: 7.w,
              bottom: 7.h,
              child: _VideoDuration(
                duration: video.duration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDuration extends StatelessWidget {
  final String duration;

  const _VideoDuration({
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 7.w,
            vertical: 4.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.premium.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(7.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.6.w,
            ),
          ),
          child: Text(
            duration,
            style: TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoInformation extends StatelessWidget {
  final CourseIntroVideo video;

  const _VideoInformation({
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TeacherAvatar(
          imageUrl: video.teacherAvatar,
        ),

        SizedBox(width: 10.w),

        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              textDirection: TextDirection.rtl,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'BShabnam',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),

                SizedBox(height: 7.h),

                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'استاد ${video.teacherLastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Shabnam',
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),

                SizedBox(height: 6.h),

                SizedBox(
                  width: double.infinity,
                  child: Text(
                    '${_toPersianDigits(video.courseDuration)} ساعت'
                    '  •  '
                    '${_toPersianDigits(video.studentsCount)} هنرجو',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Shabnam',
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final String imageUrl;

  const _TeacherAvatar({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 36.w,
        height: 36.w,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 36.w,
            height: 36.w,
            color: AppColors.primary.withValues(alpha: 0.14),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline_rounded,
              size: 20.sp,
              color: AppColors.primary,
            ),
          );
        },
      ),
    );
  }
}

String _toPersianDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  String result = value;

  for (int i = 0; i < english.length; i++) {
    result = result.replaceAll(
      english[i],
      persian[i],
    );
  }

  return result;
}