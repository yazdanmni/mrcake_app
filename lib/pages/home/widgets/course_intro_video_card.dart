import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/course_intro_video.dart';

class CourseIntroVideoCard extends StatelessWidget {
  final CourseIntroVideo video;

  /// Fired by the whole card. On the home carousel this opens the course; on
  /// the standalone teaser grid it plays the trailer.
  final VoidCallback? onTap;

  /// Optional second action, offered as a small «مشاهده دوره» control under the
  /// card. Only the standalone teaser grid passes it — the home carousel leaves
  /// it null and is **pixel-identical** to before, because a null means the
  /// control is not built at all.
  final VoidCallback? onCourseTap;

  const CourseIntroVideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? courseTap = onCourseTap;

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

            // ⚠️ **`Flexible`, not a plain child.** The card is laid out inside
            // a grid cell whose height the *grid* reserves, and that reservation
            // cannot be exact: the text here is sized in `.sp`, which in this
            // project scales with the screen **width**, while the cell's height
            // comes from `.h`, which scales with the **height**. On a wide screen
            // the two diverge and the text asks for more room than the cell
            // reserved — which used to be a `RenderFlex overflowed by 45 pixels`
            // at 1024×768, i.e. a visible striped stripe over a teaser card.
            //
            // A `Flexible` makes the block yield to whatever the cell actually
            // gave it: the text clips with an ellipsis instead of overflowing,
            // and on a phone — where the two scales agree — nothing changes at
            // all. See the `_cardInfoHeight` note on the grid for the other half
            // of this contract.
            Flexible(
              child: _VideoInformation(
                video: video,
              ),
            ),

            if (courseTap != null) ...[
              SizedBox(height: 8.h),
              _CourseButton(onTap: courseTap),
            ],
          ],
        ),
      ),
    );
  }
}

/// «مشاهده دوره» — the card's secondary action.
///
/// The house button shape: an `AppColors.primary` pill with `8.r` corners, the
/// same geometry as the home section headers, so it reads as part of the app
/// rather than a Material default.
class _CourseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CourseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 30.h,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8.r),
        ),
        alignment: Alignment.center,
        child: Text(
          'مشاهده دوره',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 13.sp,
            color: AppColors.white,
            height: 1,
          ),
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
    // `LayoutBuilder` + `SingleChildScrollView` would be the general answer, but
    // a teaser card has no business being scrollable. The card is instead
    // allowed to be shorter than the text would like — see the `Flexible` in
    // [CourseIntroVideoCard.build] — so this block must **clip** rather than
    // complain: a `Column` whose last line does not fit otherwise paints the
    // yellow-and-black overflow stripe over the card.
    //
    // The clip is invisible in practice. It only bites when the reservation in
    // `IntroductionVideosScreen._cardInfoHeight` is short, which happens on a
    // screen wide enough for `.sp` to outgrow `.h` — and there the alternative
    // is a visibly broken card.
    return ClipRect(
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeacherAvatar(
            imageUrl: video.teacherAvatar,
          ),

          SizedBox(width: 10.w),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              textDirection: TextDirection.rtl,
              children: [
                // Every line is capped and ellipsised on its own. The card can
                // be handed less height than the text would like; capping each
                // line means the block degrades by truncating a title rather
                // than by pushing the following lines out of the card.
                Text(
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

                SizedBox(height: 7.h),

                Text(
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

                SizedBox(height: 6.h),

                Text(
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
              ],
            ),
          ),
        ],
      ),
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