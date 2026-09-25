import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/explore_video.dart';
import '../../../widgets/video_thumbnail_view.dart';

class ExploreVideoCard extends StatelessWidget {
  final ExploreVideo video;
  final VoidCallback? onTap;

  const ExploreVideoCard({
    super.key,
    required this.video,
    this.onTap,
  });

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
          child: SizedBox(
            width: double.infinity,
            height: 150.h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumbnailView(
                  imageUrl: video.thumbnail,
                  videoUrl: video.videoUrl,
                  placeholder: _Placeholder(),
                  // Explore already showed a determinate download indicator for a
                  // cover; it keeps it, byte-for-byte. A frame taken from the
                  // video shows the placeholder instead, because there is no
                  // download to report progress about.
                  loading: (
                    BuildContext context,
                    ImageChunkEvent? progress,
                  ) => _CoverLoading(progress: progress),
                ),

                // لایه خیلی ظریف روی تصویر
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                        ],
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

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.field,
      alignment: Alignment.center,
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 34.sp,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// The determinate download indicator the card has always shown while a cover
/// loads — unchanged, only moved behind [VideoThumbnailView].
class _CoverLoading extends StatelessWidget {
  final ImageChunkEvent? progress;

  const _CoverLoading({this.progress});

  @override
  Widget build(BuildContext context) {
    final int? total = progress?.expectedTotalBytes;

    return Container(
      color: AppColors.field,
      alignment: Alignment.center,
      child: SizedBox(
        width: 22.w,
        height: 22.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
          value: total != null && total > 0
              ? progress!.cumulativeBytesLoaded / total
              : null,
        ),
      ),
    );
  }
}