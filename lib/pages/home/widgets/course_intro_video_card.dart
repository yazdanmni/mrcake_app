import 'dart:ui';

import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Thumbnail(
              video: video,
            ),

            const SizedBox(height: 10),

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
        borderRadius: BorderRadius.circular(11),
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
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
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
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 28,
                    color: AppColors.placeholder,
                  ),
                );
              },
            ),

            Positioned(
              right: 7,
              bottom: 7,
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
      borderRadius: BorderRadius.circular(7),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.premium.withOpacity(0.55),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 0.6,
            ),
          ),
          child: Text(
            duration,
            style: const TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 10,
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

        const SizedBox(width: 10),

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
                    style: const TextStyle(
                      fontFamily: 'BShabnam',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'استاد ${video.teacherLastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'Shabnam',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

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
                    style: const TextStyle(
                      fontFamily: 'Shabnam',
                      fontSize: 14,
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
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 36,
            height: 36,
            color: AppColors.primary.withOpacity(0.14),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline_rounded,
              size: 20,
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