import 'package:flutter/material.dart';

import '../../../models/course_intro_video.dart';
import 'course_intro_video_card.dart';

class CourseIntroVideos extends StatelessWidget {
  final ValueChanged<CourseIntroVideo>? onVideoTap;

  /// Cards built from the backend course list. When it is `null` or empty the
  /// bundled [defaultVideos] are used so the carousel is never blank.
  final List<CourseIntroVideo>? videos;

  const CourseIntroVideos({
    super.key,
    this.onVideoTap,
    this.videos,
  });

  List<CourseIntroVideo> get _items {
    final remote = videos;
    if (remote == null || remote.isEmpty) return const [];
    return remote;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double cardWidth =
            _getCardWidth(constraints.maxWidth);

        return SizedBox(
          height: _getSectionHeight(cardWidth),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics:
                  const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 25,
              ),
              itemCount: items.length,
              separatorBuilder: (
                BuildContext context,
                int index,
              ) {
                return const SizedBox(width: 15);
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final CourseIntroVideo video =
                    items[index];

                return SizedBox(
                  width: cardWidth,
                  child: CourseIntroVideoCard(
                    video: video,
                    onTap: () {
                      onVideoTap?.call(video);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  double _getCardWidth(double availableWidth) {
    if (availableWidth <= 320) {
      return 190;
    }

    if (availableWidth <= 360) {
      return 200;
    }

    if (availableWidth <= 390) {
      return 212;
    }

    return 222;
  }

  double _getSectionHeight(double cardWidth) {
    final double thumbnailHeight =
        cardWidth * 121 / 222;

    // حداکثر ارتفاع محتوای اطلاعات:
    // عنوان دو خط + فاصله‌ها + استاد + اطلاعات پایین
    const double informationHeight = 91;

    return thumbnailHeight +
        10 +
        informationHeight;
  }
}
