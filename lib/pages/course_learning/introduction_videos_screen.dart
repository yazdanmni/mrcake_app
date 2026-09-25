import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/course_intro_video.dart';
import 'package:mr_cake_project/providers/introduction_videos_provider.dart';
import 'package:mr_cake_project/widgets/video_thumbnail_view.dart';

class IntroductionVideosScreen extends ConsumerWidget {
  const IntroductionVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final introductionVideosAsyncValue = ref.watch(introductionVideosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'ویدیوهای معرفی دوره',
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 18.sp,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: introductionVideosAsyncValue.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Text(
                'ویدیوی معرفی دوره‌ای یافت نشد.',
                style: TextStyle(
                  fontFamily: 'shabnam',
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Card(
                margin: EdgeInsets.only(bottom: 16.h),
                color: AppColors.field,
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: VideoThumbnailView(
                          imageUrl: video.thumbnail,
                          videoUrl: video.videoUrl,
                          placeholder: SizedBox(
                            width: double.infinity,
                            height: 200.h,
                            child: const ColoredBox(
                              color: Colors.grey,
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        video.title,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        'استاد: ${video.teacherFullName}',
                        style: TextStyle(
                          fontFamily: 'shabnam',
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: () => _openCourse(context, video),
                          child: const Text('مشاهده دوره'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text(
            'خطا در بارگذاری ویدیوها: $err',
            style: TextStyle(
              fontFamily: 'shabnam',
              fontSize: 14.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _openCourse(BuildContext context, CourseIntroVideo video) {
    final course = video.course;
    if (course != null) {
      AppRouter.toCourseDetails(context, course);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('شناسه دوره برای این ویدیو موجود نیست.'),
      ),
    );
  }
}
