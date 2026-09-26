import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/course_intro_video.dart';
import 'course_intro_video_card.dart';

/// The «معرفی دوره ها» carousel — a horizontal strip of [CourseIntroVideoCard]s.
///
/// Shared by the home section and nothing else: the standalone
/// «ویدیو های معرفی دوره» screen lays the *same* cards out as a grid instead,
/// so a change to a card appears in both places at once.
///
/// Renders **nothing** ([SizedBox.shrink]) when [videos] is null or empty. There
/// is no bundled fallback: only a course with a real `video_trailer` can produce
/// a card, and a fabricated one would open a player with nothing to play. The
/// home screen therefore also omits the section header in that case, rather than
/// leaving a title above an empty strip.
class CourseIntroVideos extends StatelessWidget {
  final ValueChanged<CourseIntroVideo>? onVideoTap;

  /// Cards built from the backend course list.
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

    return thumbnailHeight +
        10.h +
        informationHeight;
  }

  /// Height of the card's text block, in the same terms
  /// [CourseIntroVideoCard] lays it out.
  ///
  /// ⚠️ **Not a plain `double`.** This used to be a hardcoded `91`, which
  /// scales with nothing — while every line in that block is `14.sp`, and `.sp`
  /// in this project is `value * scaleWidth`. On a phone the two agree closely
  /// enough to hide it; at 1024×768 the text needed ~108 px more than the 91
  /// the strip had reserved and the card painted `RenderFlex overflowed` stripes
  /// over the home section.
  ///
  /// The text terms are therefore `.sp` (they follow the width) and only the
  /// gaps are `.h` (they follow the height). A `Flexible` inside the card is the
  /// second line of defence: this is a reservation, and a small mis-estimate
  /// truncates a title rather than overflowing.
  static double get informationHeight {
    const double slack = 1.25;

    final double titleLine = 14.sp * 1.35 * slack;
    final double metaLine = 14.sp * 1.2 * slack;

    return (titleLine * 2) + 7.h + metaLine + 6.h + metaLine;
  }
}
