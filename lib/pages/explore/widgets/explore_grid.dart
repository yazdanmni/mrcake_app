import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/explore_video.dart';
import 'explore_video_card.dart';

class ExploreGrid extends StatelessWidget {
  final List<ExploreVideo> videos;
  final ValueChanged<ExploreVideo>? onVideoTap;

  const ExploreGrid({
    super.key,
    required this.videos,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20.w,
        mainAxisSpacing: 20.h,

        // ارتفاع دقیق کارت
        mainAxisExtent: 150.h,
      ),
      itemCount: videos.length,
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final ExploreVideo video =
            videos[index];

        return ExploreVideoCard(
          video: video,
          onTap: () {
            onVideoTap?.call(video);
          },
        );
      },
    );
  }
}
