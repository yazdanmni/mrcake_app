import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/video_thumbnail_view.dart';

class TeacherPortfolioItemCard extends StatelessWidget {
  final TeacherPortfolioItem item;
  final VoidCallback? onTap;

  const TeacherPortfolioItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  /// The neutral panel shown when there is no picture to paint.
  ///
  /// A **video** work reaches here only while its frame is still being pulled out
  /// of the file, or when that fails: the backend sends a video row with
  /// `image: null`, so there is no cover to fall back on. The play badge still
  /// marks it as playable.
  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.field,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textSecondary,
        size: 30.sp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A picture work draws its cover; a video work has none, so a frame
              // is pulled out of the video itself. Either way this is the same box
              // the plain `Image.network` used to fill, and it falls back to the
              // same panel.
              VideoThumbnailView(
                imageUrl: item.image,
                videoUrl: item.isVideo ? (item.videoUrl ?? '') : '',
                placeholder: _buildPlaceholder(),
              ),

              if (item.isVideo)
                Positioned(
                  left: 8.w,
                  top: 8.h,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withValues(alpha: 
                        0.45,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 19.sp,
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