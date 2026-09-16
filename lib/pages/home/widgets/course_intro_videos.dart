import 'package:flutter/material.dart';

import '../../../models/course_intro_video.dart';
import 'course_intro_video_card.dart';

class CourseIntroVideos extends StatelessWidget {
  final ValueChanged<CourseIntroVideo>? onVideoTap;

  const CourseIntroVideos({
    super.key,
    this.onVideoTap,
  });

  static const List<CourseIntroVideo> videos = [
    CourseIntroVideo(
      thumbnail:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=900',
      title: 'آموزش جامع کیک‌های حرفه‌ای',
      teacherFirstName: 'مریم',
      teacherLastName: 'احمدی',
      teacherAvatar:
          'https://i.pravatar.cc/300?img=47',
      duration: '08:42',
      courseDuration: '120',
      studentsCount: '600',
    ),
    CourseIntroVideo(
      thumbnail:
          'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=900',
      title: 'آموزش تخصصی دسر و شیرینی',
      teacherFirstName: 'سارا',
      teacherLastName: 'محمدی',
      teacherAvatar:
          'https://i.pravatar.cc/300?img=32',
      duration: '06:18',
      courseDuration: '95',
      studentsCount: '420',
    ),
    CourseIntroVideo(
      thumbnail:
          'https://images.unsplash.com/photo-1486427944299-d1955d23e34d?w=900',
      title: 'شیرینی‌های مدرن و خاص',
      teacherFirstName: 'نگار',
      teacherLastName: 'کریمی',
      teacherAvatar:
          'https://i.pravatar.cc/300?img=44',
      duration: '10:25',
      courseDuration: '105',
      studentsCount: '850',
    ),
    CourseIntroVideo(
      thumbnail:
          'https://images.unsplash.com/photo-1571115177098-24ec42ed204d?w=900',
      title: 'آموزش کیک‌های مجلسی و لوکس با تکنیک‌های حرفه‌ای',
      teacherFirstName: 'الهام',
      teacherLastName: 'رضایی',
      teacherAvatar:
          'https://i.pravatar.cc/300?img=49',
      duration: '07:56',
      courseDuration: '140',
      studentsCount: '720',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
              itemCount: videos.length,
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
                    videos[index];

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