import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/category_model.dart';
import 'package:mr_cake_project/models/course_intro_video.dart';
import 'package:mr_cake_project/pages/home/home_courses.dart';
import 'package:mr_cake_project/pages/home/widgets/course_intro_videos.dart';
import 'package:mr_cake_project/pages/home/widgets/home_banner.dart';
import 'package:mr_cake_project/pages/home/widgets/home_categories.dart';
import 'package:mr_cake_project/pages/home/widgets/home_header.dart';
import 'package:mr_cake_project/pages/home/widgets/home_hero.dart';
import 'package:mr_cake_project/pages/home/widgets/home_quick_actions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<CategoryModel> categories = [
    CategoryModel(
      id: 1,
      title: 'کیک',
      image:
          'https://img.icons8.com/?size=100&id=40786&format=png&color=000000',
    ),
    CategoryModel(
      id: 2,
      title: 'شیرینی',
      image: 'https://img.icons8.com/?size=100&id=9162&format=png&color=000000',
    ),
    CategoryModel(
      id: 3,
      title: 'دسر',
      image: 'https://img.icons8.com/?size=100&id=4047&format=png&color=000000',
    ),
    CategoryModel(
      id: 4,
      title: 'نان',
      image: 'https://img.icons8.com/?size=100&id=4043&format=png&color=000000',
    ),
    CategoryModel(
      id: 5,
      title: 'خامه',
      image: 'https://img.icons8.com/?size=100&id=9162&format=png&color=000000',
    ),
    CategoryModel(
      id: 6,
      title: 'کروسان',
      image:
          'https://img.icons8.com/?size=100&id=24596&format=png&color=000000',
    ),
    CategoryModel(
      id: 7,
      title: 'کاکائو',
      image: 'https://img.icons8.com/?size=100&id=2395&format=png&color=000000',
    ),
  ];
  // Temporary mock banners until the backend endpoint is ready.
  final List<BannerModel> banners = const [
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800',
      title: 'Welcome to\nSweet Delights Bakery!',
      subtitle: 'Discover our delightful selection of cakes',
    ),
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1486427944299-d1955d23e34d?w=800',
      title: 'Fresh Every\nMorning!',
      subtitle: 'Baked with love, served with a smile',
    ),
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?w=800',
      title: 'Special\nChocolate Cakes',
      subtitle: 'Handmade with premium ingredients',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            ClipPath(
              clipper: BottomCurveClipper(),
              child: Container(
                width: double.infinity,
                height: 510.h,
                color: AppColors.sectionBackground,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  HomeHeader(),
                  SizedBox(height: 22.h),
                  HomeHero(),
                  SizedBox(height: 22.h),
                  HomeCategories(categories: categories),
                  // Scrollable promo banner with glass page indicator.
                  SizedBox(height: 29.h),
                  HomeBanner(banners: banners),
                  SizedBox(height: 30.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: 123.w,
                          height: 33.h,
                          decoration: BoxDecoration(
                            color: AppColors.premium,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'دوره های محبوب',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'bshabnam',
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 95.w,
                          height: 33.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'مشاهده همه',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'bshabnam',
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 25.h),
                    child: HomeCourses(),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 25.h,
                      left: 25.w,
                      right: 25.w,
                      bottom: 25.h,
                    ),
                    child: HomeQuickActions(
                      onCoursesTap: () {
                        // TODO: رفتن به صفحه دوره‌ها
                      },
                      onTeachersTap: () {
                        // TODO: رفتن به صفحه استادها
                      },
                      onStudentsTap: () {
                        // TODO: رفتن به صفحه هنرجوها
                      },
                      onRecipesTap: () {
                        // TODO: رفتن به صفحه رسپی‌ها
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: 123.w,
                          height: 33.h,
                          decoration: BoxDecoration(
                            color: AppColors.premium,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'معرفی دوره ها',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'bshabnam',
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 95.w,
                          height: 33.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'مشاهده همه',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'bshabnam',
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding:  EdgeInsets.symmetric(vertical: 15.h),
                    child: CourseIntroVideos(
                      onVideoTap: (CourseIntroVideo video) {
                        debugPrint('Selected video: ${video.title}');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    final curveHeight = 40.h;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - curveHeight);

    path.quadraticBezierTo(
      size.width / 2,
      size.height + curveHeight * 0.5,
      0,
      size.height - curveHeight,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}
